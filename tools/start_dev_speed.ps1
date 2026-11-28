# Launch an isolated Windows debug session. Every invocation gets a new profile.
param(
    [Parameter(Mandatory = $true)]
    [string]$Godot,
    [string]$OutputRoot = (Join-Path $env:LOCALAPPDATA 'BallWar Dev Sessions'),
    [switch]$CheckControls,
    [switch]$CheckBattleTools
)
$ErrorActionPreference = 'Stop'
$engine = (Get-Item -LiteralPath $Godot).FullName
$project = (Get-Item -LiteralPath (Join-Path $PSScriptRoot '..')).FullName
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
$token = 'ballwar-dev-' + [guid]::NewGuid().ToString('N')
$profile = (New-Item -ItemType Directory -Path (Join-Path $OutputRoot $token)).FullName
[IO.File]::WriteAllText((Join-Path $profile '.ballwar-dev-speed'), $token)
$env:APPDATA = $profile
$env:BALLWAR_DEV_TOKEN = $token
Write-Host "DEV-SPEED profile: $profile"
if ($CheckControls -and $CheckBattleTools) {
    throw 'Select one verification mode at a time.'
}
$flags = @()
if ($CheckControls) {
    $flags = @('--headless', '--audio-driver', 'Dummy', '--script', 'res://scripts/tests/DevSpeedControlsTestRunner.gd')
}
if ($CheckBattleTools) {
    $flags = @('--headless', '--audio-driver', 'Dummy', '--script', 'res://scripts/tests/DevBattleToolsTestRunner.gd')
}
& $engine --path $project @flags -- --ballwar-dev-speed
exit $LASTEXITCODE
