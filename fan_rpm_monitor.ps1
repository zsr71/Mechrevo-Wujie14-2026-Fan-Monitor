param(
    [switch]$Elevated
)

$ErrorActionPreference = 'Stop'
$powershellPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$scriptPath = $MyInvocation.MyCommand.Path
$scriptRoot = Split-Path -Parent $scriptPath
$workerPath = Join-Path $scriptRoot 'fan_rpm_live_worker.ps1'
$resultPath = Join-Path $scriptRoot 'fan_rpm_live.json'
$temporaryResultPath = Join-Path $scriptRoot 'fan_rpm_live.tmp'
$heartbeatPath = Join-Path $scriptRoot 'fan_rpm_live.heartbeat'
$taskName = 'MechrevoFanRpmReadOnlyLive'
$taskDescription = 'MECHREVO WUJIE fan RPM read-only WMI worker'
$logPath = Join-Path $scriptRoot 'fan_rpm_monitor.log'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Write-LaunchLog([string]$Message) {
    try {
        Add-Content -LiteralPath $logPath `
            -Value ('{0:o} [PID {1}] {2}' -f [DateTimeOffset]::Now, $PID, $Message) `
            -Encoding UTF8
    }
    catch {
        # Logging must never prevent the monitor from starting.
    }
}

function Get-UiText([string]$Base64) {
    return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Base64))
}

function Show-ErrorAndExit([string]$Message) {
    [void][System.Windows.Forms.MessageBox]::Show(
        $Message,
        (Get-UiText '6aOO5omHIFJQTSDnm5Hop4blmag='),
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 1
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
$isAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-LaunchLog "Started. Administrator=$isAdministrator ElevatedSwitch=$Elevated"

if (-not $isAdministrator) {
    try {
        $arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Elevated' -f $scriptPath
        # Do not hide this interactive process: some Windows configurations also
        # hide the first WinForms window when STARTF_USESHOWWINDOW is SW_HIDE.
        $elevatedProcess = Start-Process `
            -FilePath $powershellPath `
            -Verb RunAs `
            -ArgumentList $arguments `
            -PassThru `
            -Wait
        Write-LaunchLog "Elevated process exited with code $($elevatedProcess.ExitCode)."
        exit $elevatedProcess.ExitCode
    }
    catch {
        Write-LaunchLog "Elevation failed: $($_.Exception.Message)"
        Show-ErrorAndExit (Get-UiText '6ZyA6KaB566h55CG5ZGY5o6I5p2D5omN6IO95ZCv5Yqo5Li05pe2IFNZU1RFTSDlj6ror7vku7vliqHjgII=')
    }
}

if (-not (Test-Path -LiteralPath $workerPath -PathType Leaf)) {
    Show-ErrorAndExit ((Get-UiText '5om+5LiN5Yiw6K+75Y+W56iL5bqP77ya') + $workerPath)
}

$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($null -ne $existingTask) {
    if ($existingTask.Description -ne $taskDescription) {
        Show-ErrorAndExit ((Get-UiText '5a2Y5Zyo5ZCM5ZCN5L2G5p2l5rqQ5LiN5piO55qE6K6h5YiS5Lu75Yqh77ya') + $taskName)
    }
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

[System.IO.File]::WriteAllText(
    $heartbeatPath,
    [DateTimeOffset]::Now.ToString('o'),
    [System.Text.UTF8Encoding]::new($false)
)

# Embed the reviewed worker in the task action. The SYSTEM task does not load
# executable code from a user-writable path after it has been registered.
$workerSource = [System.IO.File]::ReadAllText($workerPath)
$workerRootLiteral = $scriptRoot.Replace("'", "''")
$workerSource = "`$monitorRoot = '$workerRootLiteral'`r`n" + $workerSource
$encodedWorker = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($workerSource))
$taskAction = New-ScheduledTaskAction `
    -Execute $powershellPath `
    -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $encodedWorker"
$taskPrincipal = New-ScheduledTaskPrincipal `
    -UserId 'SYSTEM' `
    -LogonType ServiceAccount `
    -RunLevel Highest
$taskSettings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Hours 12) `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries

try {
    Register-ScheduledTask `
        -TaskName $taskName `
        -Description $taskDescription `
        -Action $taskAction `
        -Principal $taskPrincipal `
        -Settings $taskSettings | Out-Null
    Start-ScheduledTask -TaskName $taskName
    Write-LaunchLog 'Temporary SYSTEM reader task started.'
}
catch {
    $failedTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($null -ne $failedTask -and $failedTask.Description -eq $taskDescription) {
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    }
    [System.IO.File]::Delete($heartbeatPath)
    Write-LaunchLog "Reader task failed: $($_.Exception.Message)"
    Show-ErrorAndExit ((Get-UiText '5peg5rOV5ZCv5Yqo5Y+q6K+76K+75Y+W5Lu75Yqh77ya') + $_.Exception.Message)
}

[System.Windows.Forms.Application]::EnableVisualStyles()
$form = [System.Windows.Forms.Form]::new()
$form.Text = Get-UiText '5peg55WMIDE0IDIwMjYgwrcg6aOO5omH6L2s6YCf'
$form.ClientSize = [Drawing.Size]::new(470, 330)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.BackColor = [Drawing.Color]::FromArgb(24, 27, 34)

$title = [System.Windows.Forms.Label]::new()
$title.Text = Get-UiText '5a6e5pe26aOO5omH6L2s6YCf'
$title.Font = [Drawing.Font]::new('Microsoft YaHei UI', 16, [Drawing.FontStyle]::Bold)
$title.ForeColor = [Drawing.Color]::White
$title.Location = [Drawing.Point]::new(24, 18)
$title.AutoSize = $true
$form.Controls.Add($title)

$fan1Name = [System.Windows.Forms.Label]::new()
$fan1Name.Text = Get-UiText '6aOO5omHIDE='
$fan1Name.Font = [Drawing.Font]::new('Microsoft YaHei UI', 10)
$fan1Name.ForeColor = [Drawing.Color]::Silver
$fan1Name.Location = [Drawing.Point]::new(30, 78)
$fan1Name.AutoSize = $true
$form.Controls.Add($fan1Name)

$fan2Name = [System.Windows.Forms.Label]::new()
$fan2Name.Text = Get-UiText '6aOO5omHIDI='
$fan2Name.Font = [Drawing.Font]::new('Microsoft YaHei UI', 10)
$fan2Name.ForeColor = [Drawing.Color]::Silver
$fan2Name.Location = [Drawing.Point]::new(252, 78)
$fan2Name.AutoSize = $true
$form.Controls.Add($fan2Name)

$fan1Value = [System.Windows.Forms.Label]::new()
$fan1Value.Text = Get-UiText '562J5b6F4oCm'
$fan1Value.Font = [Drawing.Font]::new('Consolas', 22, [Drawing.FontStyle]::Bold)
$fan1Value.ForeColor = [Drawing.Color]::FromArgb(88, 196, 221)
$fan1Value.Location = [Drawing.Point]::new(27, 105)
$fan1Value.Size = [Drawing.Size]::new(175, 42)
$form.Controls.Add($fan1Value)

$fan2Value = [System.Windows.Forms.Label]::new()
$fan2Value.Text = Get-UiText '562J5b6F4oCm'
$fan2Value.Font = [Drawing.Font]::new('Consolas', 22, [Drawing.FontStyle]::Bold)
$fan2Value.ForeColor = [Drawing.Color]::FromArgb(125, 207, 130)
$fan2Value.Location = [Drawing.Point]::new(249, 105)
$fan2Value.Size = [Drawing.Size]::new(195, 42)
$form.Controls.Add($fan2Value)

$modeName = [System.Windows.Forms.Label]::new()
$modeName.Text = Get-UiText '5b2T5YmN5oCn6IO95qih5byP'
$modeName.Font = [Drawing.Font]::new('Microsoft YaHei UI', 10)
$modeName.ForeColor = [Drawing.Color]::Silver
$modeName.Location = [Drawing.Point]::new(30, 165)
$modeName.AutoSize = $true
$form.Controls.Add($modeName)

$modeValue = [System.Windows.Forms.Label]::new()
$modeValue.Text = Get-UiText '5q2j5Zyo6K+75Y+W4oCm'
$modeValue.Font = [Drawing.Font]::new('Microsoft YaHei UI', 18, [Drawing.FontStyle]::Bold)
$modeValue.ForeColor = [Drawing.Color]::FromArgb(242, 188, 80)
$modeValue.Location = [Drawing.Point]::new(176, 155)
$modeValue.Size = [Drawing.Size]::new(265, 40)
$form.Controls.Add($modeValue)

$modeEventLabel = [System.Windows.Forms.Label]::new()
$modeEventLabel.Text = Get-UiText '5pyA6L+R5YiH5o2i77ya5bCa5pyq5pS25Yiw'
$modeEventLabel.Font = [Drawing.Font]::new('Microsoft YaHei UI', 9)
$modeEventLabel.ForeColor = [Drawing.Color]::FromArgb(170, 170, 170)
$modeEventLabel.Location = [Drawing.Point]::new(30, 215)
$modeEventLabel.Size = [Drawing.Size]::new(410, 45)
$form.Controls.Add($modeEventLabel)

$statusLabel = [System.Windows.Forms.Label]::new()
$statusLabel.Text = Get-UiText '5q2j5Zyo6L+e5o6lIEJJT1MgV01J4oCm'
$statusLabel.Font = [Drawing.Font]::new('Microsoft YaHei UI', 9)
$statusLabel.ForeColor = [Drawing.Color]::Gray
$statusLabel.Location = [Drawing.Point]::new(28, 282)
$statusLabel.Size = [Drawing.Size]::new(415, 35)
$form.Controls.Add($statusLabel)

$sessionStarted = [DateTimeOffset]::Now
$timer = [System.Windows.Forms.Timer]::new()
$timer.Interval = 750
$timer.Add_Tick({
    try {
        [System.IO.File]::WriteAllText(
            $heartbeatPath,
            [DateTimeOffset]::Now.ToString('o'),
            [System.Text.UTF8Encoding]::new($false)
        )

        if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) {
            return
        }

        $data = [System.IO.File]::ReadAllText($resultPath) | ConvertFrom-Json
        $sampleTime = [DateTimeOffset]::Parse([string]$data.timestamp)
        if ($sampleTime -lt $sessionStarted) {
            return
        }

        if (-not $data.ok) {
            $statusLabel.Text = (Get-UiText '6K+75Y+W6ZSZ6K+v77ya') + $data.error
            $statusLabel.ForeColor = [Drawing.Color]::Salmon
            return
        }

        $fan1 = $data.readings | Where-Object fan -eq 1 | Select-Object -First 1
        $fan2 = $data.readings | Where-Object fan -eq 2 | Select-Object -First 1
        if ($null -ne $fan1) { $fan1Value.Text = ('{0} RPM' -f [int]$fan1.rpm) }
        if ($null -ne $fan2) { $fan2Value.Text = ('{0} RPM' -f [int]$fan2.rpm) }

        if ($null -ne $data.performanceMode) {
            $modeValue.Text = (Get-UiText '5qih5byP5Luj56CBIHswfQ==') -f [int]$data.performanceMode.code
        }

        if ($null -ne $data.modeEvent) {
            $modeEventTime = [DateTimeOffset]::Parse([string]$data.modeEvent.timestamp)
            if ([string]$data.modeEvent.source -eq 'firmware') {
                $modeEventLabel.Text = (Get-UiText '5pyA6L+R5YiH5o2i77yaezA6SEg6bW06c3N9IMK3IOaooeW8j+S7o+eggSB7MX0gwrcg5Zu65Lu25LqL5Lu2IDB4ezI6WDJ9') -f `
                    $modeEventTime.LocalDateTime, [int]$data.modeEvent.modeCode, [int]$data.modeEvent.eventCode
                $modeEventLabel.ForeColor = [Drawing.Color]::FromArgb(242, 188, 80)
            }
            else {
                $modeEventLabel.Text = (Get-UiText '5pyA6L+R5Y+Y5YyW77yaezA6SEg6bW06c3N9IMK3IOaooeW8j+S7o+eggSB7MX0gwrcg6L2u6K+i56Gu6K6k') -f `
                    $modeEventTime.LocalDateTime, [int]$data.modeEvent.modeCode
                $modeEventLabel.ForeColor = [Drawing.Color]::FromArgb(170, 170, 170)
            }
        }
        elseif ($null -ne $data.eventSubscription -and -not $data.eventSubscription.available) {
            $modeEventLabel.Text = Get-UiText '5Zu65Lu25LqL5Lu26K6i6ZiF5LiN5Y+v55So77yb5LuN5Lya5qOA5rWL5qih5byP5Y+Y5YyW'
            $modeEventLabel.ForeColor = [Drawing.Color]::Salmon
        }

        $statusLabel.Text = (Get-UiText '5pu05paw77yaezA6SEg6bW06c3N9IMK3IEJJT1Mg5Y+q6K+7') -f $sampleTime.LocalDateTime
        $statusLabel.ForeColor = [Drawing.Color]::Gray
    }
    catch {
        # A file replacement may overlap this tick; retry on the next tick.
    }
})

$form.Add_Shown({
    Write-LaunchLog 'Monitor window shown.'
    $timer.Start()
})

try {
    [System.Windows.Forms.Application]::Run($form)
}
finally {
    $timer.Stop()
    $currentTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($null -ne $currentTask -and $currentTask.Description -eq $taskDescription) {
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    }
    [System.IO.File]::Delete($heartbeatPath)
    [System.IO.File]::Delete($temporaryResultPath)
    [System.IO.File]::Delete($resultPath)
    Write-LaunchLog 'Monitor stopped and temporary task cleaned up.'
}
