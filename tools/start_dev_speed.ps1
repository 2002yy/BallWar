# Launch an isolated Windows debug session. Every invocation gets a new profile.
param(
    [Parameter(Mandatory = $true)]
    [string]$Godot,
    [string]$OutputRoot = (Join-Path $env:LOCALAPPDATA 'BallWar Dev Sessions'),
    [switch]$CheckControls,
    [switch]$CheckBattleTools,
    [switch]$FortressLab,
    [switch]$FortressFixture,
    [switch]$BreachLab,
    [switch]$BreachFixture,
    [switch]$CollisionLab,
    [switch]$CollisionFixture,
    [switch]$VelocityLab,
    [switch]$VelocityFixture
)
$ErrorActionPreference = 'Stop'
if ($CheckControls -and $CheckBattleTools) {
    throw 'Select one verification mode at a time.'
}
$fortressMode = $FortressLab -or $FortressFixture
$breachMode = $BreachLab -or $BreachFixture
if ($fortressMode -and $breachMode) {
    throw 'Select one experimental map at a time.'
}
$velocityMode = $VelocityLab -or $VelocityFixture
if ($velocityMode -and ($CollisionLab -or $CollisionFixture)) {
    throw 'Select one experimental weapon ruleset at a time.'
}
$collisionMode = $CollisionLab -or $CollisionFixture -or $velocityMode
if ($collisionMode -and ($fortressMode -or $breachMode)) {
    throw 'The collision experiment uses the classic map.'
}
if (($CheckControls -or $CheckBattleTools) -and ($fortressMode -or $breachMode -or $collisionMode)) {
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
if ($fortressMode) {
    $gameArgs += '--fortress-lab'
}
if ($breachMode) {
    $gameArgs += '--breach-lab'
}
if ($FortressFixture -or $BreachFixture) {
    $gameArgs += '--construction-fixture'
}
if ($velocityMode) {
    $gameArgs += '--velocity-lab'
} elseif ($collisionMode) {
    $gameArgs += '--collision-lab'
}
if ($CollisionFixture) {
    $gameArgs += '--collision-fixture'
}
if ($VelocityFixture) {
    $gameArgs += '--velocity-fixture'
}
& $engine --path $project @flags -- @gameArgs
exit $LASTEXITCODE
