$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace([string]$monitorRoot)) {
    $monitorRoot = $PSScriptRoot
}
if ([string]::IsNullOrWhiteSpace([string]$monitorRoot)) {
    throw 'Monitor root path was not supplied.'
}

$resultPath = Join-Path $monitorRoot 'fan_rpm_live.json'
$temporaryResultPath = Join-Path $monitorRoot 'fan_rpm_live.tmp'
$heartbeatPath = Join-Path $monitorRoot 'fan_rpm_live.heartbeat'
$taskName = 'MechrevoFanRpmReadOnlyLive'
$maximumLifetime = [DateTime]::UtcNow.AddHours(12)
$modeEventWatcher = $null
$eventWatcherAvailable = $false
$eventWatcherError = $null
$lastModeCode = $null
$lastModeEvent = $null

function Write-JsonResult([object]$Value) {
    $json = $Value | ConvertTo-Json -Depth 6 -Compress
    [System.IO.File]::WriteAllText(
        $temporaryResultPath,
        $json,
        [System.Text.UTF8Encoding]::new($false)
    )

    if ([System.IO.File]::Exists($resultPath)) {
        try {
            [System.IO.File]::Replace($temporaryResultPath, $resultPath, $null)
            return
        }
        catch {
            # Fall back when the destination filesystem does not support Replace.
        }
    }

    [System.IO.File]::Copy($temporaryResultPath, $resultPath, $true)
    [System.IO.File]::Delete($temporaryResultPath)
}

try {
    Add-Type -AssemblyName System.Management
    $scope = [System.Management.ManagementScope]::new('\\.\root\wmi')
    $scope.Connect()

    $query = [System.Management.ObjectQuery]::new('SELECT * FROM OemWMIMethod')
    $searcher = [System.Management.ManagementObjectSearcher]::new($scope, $query)
    $instances = @($searcher.Get())
    if ($instances.Count -eq 0) {
        throw 'OemWMIMethod has no instances.'
    }

    $instance = $instances | Where-Object { $_['Active'] -eq $true } | Select-Object -First 1
    if ($null -eq $instance) {
        $instance = $instances[0]
    }

    try {
        # This is a subscription only. OemWMIEvent is raised by the BIOS after
        # an EC hot-key mode change; no ACPI method is invoked to enable it.
        $eventQuery = [System.Management.WqlEventQuery]::new('SELECT * FROM OemWMIEvent')
        $modeEventWatcher = [System.Management.ManagementEventWatcher]::new($scope, $eventQuery)
        $modeEventWatcher.Options.Timeout = [TimeSpan]::FromMilliseconds(75)
        $modeEventWatcher.Start()
        $eventWatcherAvailable = $true
    }
    catch {
        $eventWatcherError = $_.Exception.Message
        if ($null -ne $modeEventWatcher) {
            $modeEventWatcher.Dispose()
            $modeEventWatcher = $null
        }
    }

    while ([DateTime]::UtcNow -lt $maximumLifetime) {
        $heartbeat = Get-Item -LiteralPath $heartbeatPath -ErrorAction SilentlyContinue
        if ($null -eq $heartbeat -or ([DateTime]::UtcNow - $heartbeat.LastWriteTimeUtc).TotalSeconds -gt 10) {
            break
        }

        try {
            $firmwareModeEventThisCycle = $null
            if ($eventWatcherAvailable) {
                try {
                    $eventObject = $modeEventWatcher.WaitForNextEvent()
                    $eventCode = [int]$eventObject['Force']
                    # DSDT _QF4 stores 0x41 for PPMD=1 and 0x42 for PPMD=2,
                    # then raises OemWMIEvent. Other event codes are unrelated.
                    if ($eventCode -eq 0x41 -or $eventCode -eq 0x42) {
                        $firmwareModeEventThisCycle = [pscustomobject]@{
                            timestamp = [DateTimeOffset]::Now.ToString('o')
                            eventCode = $eventCode
                            modeCode = $eventCode - 0x40
                            source = 'firmware'
                        }
                    }
                }
                catch [System.Management.ManagementException] {
                    if ($_.Exception.ErrorCode -ne [System.Management.ManagementStatus]::Timedout) {
                        $eventWatcherAvailable = $false
                        $eventWatcherError = $_.Exception.Message
                    }
                }
                catch {
                    $eventWatcherAvailable = $false
                    $eventWatcherError = $_.Exception.Message
                }
            }

            $readings = foreach ($fanIndex in 0, 1) {
                # DSDT route: OemWMIfun -> WMCD -> GFNS.
                # MAFD=2 selects fan information, SUFD=1 selects get/read,
                # and FNIN selects fan 0 or 1. No write branch is reachable.
                $request = [byte[]]::new(64)
                $request[0] = 2
                $request[1] = 1
                $request[2] = [byte]$fanIndex

                $input = $instance.GetMethodParameters('OemWMIfun')
                $input['u8Input'] = $request
                $output = $instance.InvokeMethod('OemWMIfun', $input, $null)
                $response = [byte[]]$output['u8Output']
                if ($response.Length -lt 3) {
                    throw "Fan $($fanIndex + 1) returned fewer than three bytes."
                }

                $status = [int]$response[0]
                $low = [int]$response[1]
                $high = [int]$response[2]
                [pscustomobject]@{
                    fan = $fanIndex + 1
                    status = $status
                    rpm = (($high -shl 8) -bor $low)
                    lowByte = $low
                    highByte = $high
                }
            }

            # DSDT route: OemWMIfun -> WMCD -> GPFM -> ECRD(PPMD).
            # MAFD=3 selects platform functions and SUFD=9 is get mode.
            # SPFM (SUFD=10), the setting branch, is never called.
            $modeRequest = [byte[]]::new(64)
            $modeRequest[0] = 3
            $modeRequest[1] = 9
            $modeRequest[2] = 0
            $modeInput = $instance.GetMethodParameters('OemWMIfun')
            $modeInput['u8Input'] = $modeRequest
            $modeOutput = $instance.InvokeMethod('OemWMIfun', $modeInput, $null)
            $modeResponse = [byte[]]$modeOutput['u8Output']
            if ($modeResponse.Length -lt 2) {
                throw 'Performance mode returned fewer than two bytes.'
            }

            $modeStatus = [int]$modeResponse[0]
            $modeCode = [int]$modeResponse[1]
            if ($null -ne $firmwareModeEventThisCycle) {
                $firmwareModeEventThisCycle.modeCode = $modeCode
                $lastModeEvent = $firmwareModeEventThisCycle
            }
            elseif ($null -ne $lastModeCode -and $modeCode -ne $lastModeCode) {
                # This fallback is still read-only and records a detected state
                # transition if Windows drops a firmware notification.
                $lastModeEvent = [pscustomobject]@{
                    timestamp = [DateTimeOffset]::Now.ToString('o')
                    eventCode = $null
                    modeCode = $modeCode
                    source = 'polling'
                }
            }
            $lastModeCode = $modeCode

            Write-JsonResult ([pscustomobject]@{
                ok = $true
                timestamp = [DateTimeOffset]::Now.ToString('o')
                readings = @($readings)
                performanceMode = [pscustomobject]@{
                    status = $modeStatus
                    code = $modeCode
                }
                modeEvent = $lastModeEvent
                eventSubscription = [pscustomobject]@{
                    available = $eventWatcherAvailable
                    error = $eventWatcherError
                }
            })
        }
        catch {
            Write-JsonResult ([pscustomobject]@{
                ok = $false
                timestamp = [DateTimeOffset]::Now.ToString('o')
                error = $_.Exception.Message
            })
        }

        Start-Sleep -Milliseconds 1000
    }
}
catch {
    Write-JsonResult ([pscustomobject]@{
        ok = $false
        timestamp = [DateTimeOffset]::Now.ToString('o')
        error = $_.Exception.ToString()
    })
}
finally {
    if ($null -ne $modeEventWatcher) {
        try { $modeEventWatcher.Stop() } catch {}
        $modeEventWatcher.Dispose()
    }
    [System.IO.File]::Delete($temporaryResultPath)
    # If the UI was closed forcibly, remove the now-stale task after the
    # heartbeat timeout. Normal UI shutdown removes it first.
    & "$env:SystemRoot\System32\schtasks.exe" /Delete /TN $taskName /F 2>$null | Out-Null
}
