# Launch an isolated Windows debug session. Every invocation gets a new profile.
param(
    [Parameter(Mandatory = $true)]
    [string]$Godot,
    [string]$OutputRoot = (Join-Path $env:LOCALAPPDATA 'BallWar Dev Sessions'),
    [switch]$CheckControls,
    [switch]$CheckBattleTools,
    [switch]$FortressLab,
    [switch]$FortressFixture
)
$ErrorActionPreference = 'Stop'
if ($CheckControls -and $CheckBattleTools) {
    throw 'Select one verification mode at a time.'
}
if (($CheckControls -or $CheckBattleTools) -and ($FortressLab -or $FortressFixture)) {
    throw 'The standard control checks start from the ordinary menu.'
}
$engine = (Get-Item -LiteralPath $Godot).FullName
$project = (Get-Item -LiteralPath (Join-Path $PSScriptRoot '..')).FullName
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
$token = 'ballwar-dev-' + [guid]::NewGuid().ToString('N')
$profile = (New-Item -ItemType Directory -Path (Join-Path $OutputRoot $token)).FullName
[IO.File]::WriteAllText((Join-Path $profile '.ballwar-dev-speed'), $token)
$env:APPDATA = $profile
$env:BALLWAR_DEV_TOKEN = $token
Write-Host "DEV-SPEED profile: $profile"
$flags = @()
if ($CheckControls) {
    $flags = @('--headless', '--audio-driver', 'Dummy', '--script', 'res://scripts/tests/DevSpeedControlsTestRunner.gd')
}
if ($CheckBattleTools) {
    $flags = @('--headless', '--audio-driver', 'Dummy', '--script', 'res://scripts/tests/DevBattleToolsTestRunner.gd')
}
$gameArgs = @('--ballwar-dev-speed')
if ($FortressLab -or $FortressFixture) {
    $gameArgs += '--fortress-lab'
}
if ($FortressFixture) {
    $gameArgs += '--construction-fixture'
}
& $engine --path $project @flags -- @gameArgs
exit $LASTEXITCODE
