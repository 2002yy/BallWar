# Android 导出要点

## 必须设置

`project.godot` → `[rendering]` 段必须包含：

```ini
textures/vram_compression/import_etc2_astc=true
```

否则 Android 导出报 `configuration errors`，Godot Export 面板红字：
"目标平台需要 ETC2/ASTC 纹理压缩。请在项目设置中启用导入 ETC2 ASTC。"

## 导出前检查

```powershell
.\tools\check_android_export_config.ps1
```

## 自动修复

```powershell
.\tools\fix_android_export_config.ps1
```

## 命令行导出

```powershell
$godot_console --headless --path "<项目路径>" --export-release "领土战争" "C:\Builds\BallWar_vX.Y.Z.apk"
```
