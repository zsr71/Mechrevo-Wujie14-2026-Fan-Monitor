param(
    [string]$Version = '0.1.0-alpha.1'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$distRoot = Join-Path $repoRoot 'dist'
$packageName = "Mechrevo-Wujie14-2026-Fan-Monitor-v$Version"
$stageRoot = Join-Path $distRoot $packageName
$zipPath = Join-Path $distRoot ($packageName + '.zip')
$hashPath = $zipPath + '.sha256'

function Assert-ChildPath([string]$Parent, [string]$Child) {
    $parentFull = [IO.Path]::GetFullPath($Parent).TrimEnd('\') + '\'
    $childFull = [IO.Path]::GetFullPath($Child)
    if (-not $childFull.StartsWith($parentFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to modify a path outside the repository: $childFull"
    }
}

Assert-ChildPath $repoRoot $distRoot
Assert-ChildPath $repoRoot $stageRoot
Assert-ChildPath $repoRoot $zipPath
Assert-ChildPath $repoRoot $hashPath

if (-not (Test-Path -LiteralPath $distRoot)) {
    New-Item -ItemType Directory -Path $distRoot | Out-Null
}
if (Test-Path -LiteralPath $stageRoot) {
    Remove-Item -LiteralPath $stageRoot -Recurse -Force
}
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
if (Test-Path -LiteralPath $hashPath) {
    Remove-Item -LiteralPath $hashPath -Force
}

New-Item -ItemType Directory -Path $stageRoot | Out-Null

$releaseFiles = @(
    'Fan RPM Monitor.cmd',
    'fan_rpm_monitor.ps1',
    'fan_rpm_live_worker.ps1',
    'README.md',
    'LICENSE',
    'CHANGELOG.md',
    'SECURITY.md',
    'FAN_CONTROL_RESEARCH_NOTES.md'
)

foreach ($relativePath in $releaseFiles) {
    $sourcePath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Release input is missing: $sourcePath"
    }
    Copy-Item -LiteralPath $sourcePath -Destination $stageRoot
}

[IO.File]::WriteAllText(
    (Join-Path $stageRoot 'VERSION.txt'),
    ($Version + [Environment]::NewLine),
    [Text.UTF8Encoding]::new($false)
)

Compress-Archive -LiteralPath $stageRoot -DestinationPath $zipPath -CompressionLevel Optimal
Remove-Item -LiteralPath $stageRoot -Recurse -Force

$hash = Get-FileHash -LiteralPath $zipPath -Algorithm SHA256
[IO.File]::WriteAllText(
    $hashPath,
    ($hash.Hash.ToLowerInvariant() + '  ' + [IO.Path]::GetFileName($zipPath) + [Environment]::NewLine),
    [Text.UTF8Encoding]::new($false)
)

[pscustomobject]@{
    Version = $Version
    Package = $zipPath
    Sha256 = $hash.Hash.ToLowerInvariant()
    HashFile = $hashPath
}
