# Auto-fix ETC2/ASTC texture compression for Android export
param(
    [string]$ProjPath = "C:\Users\96967\Desktop\Marble Dominion Ricochet War\BallWar_v2_1_8(UI素材等重构)\BallWar"
)
$pg = Join-Path $ProjPath "project.godot"
$text = Get-Content $pg -Raw -Encoding UTF8
if ($text -match "import_etc2_astc\s*=\s*false") {
    $text = $text -replace "import_etc2_astc\s*=\s*false", "import_etc2_astc=true"
    Set-Content $pg $text -Encoding UTF8 -NoNewline
    Write-Host "Fixed: import_etc2_astc set to true"
} elseif ($text -notmatch "import_etc2_astc") {
    if ($text -match "\[rendering\]") {
        $text = $text -replace "\[rendering\]", "[rendering]`r`n`r`ntextures/vram_compression/import_etc2_astc=true"
    } else {
        $text += "`r`n[rendering]`r`n`r`ntextures/vram_compression/import_etc2_astc=true`r`n"
    }
    Set-Content $pg $text -Encoding UTF8 -NoNewline
    Write-Host "Added: import_etc2_astc=true"
} else {
    Write-Host "Already enabled"
}
