# Android Export Pre-flight Check
param(
    [string]$ProjPath = "C:\Users\96967\Desktop\Marble Dominion Ricochet War\BallWar_v2_1_8(UI素材等重构)\BallWar"
)
$pg = Join-Path $ProjPath "project.godot"
$text = Get-Content $pg -Raw -Encoding UTF8
if ($text -notmatch "import_etc2_astc\s*=\s*true") {
    Write-Host "FAIL: ETC2/ASTC not enabled in project.godot" -ForegroundColor Red
    Write-Host "Fix: Project Settings > Rendering > Textures > VRAM Compression > Import ETC2 ASTC"
    exit 1
}
Write-Host "OK: ETC2/ASTC enabled"
exit 0
