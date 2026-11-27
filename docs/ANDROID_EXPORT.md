# Android Export / Android 导出

## Environment / 环境

Use the Godot version pinned in [CI](../.github/workflows/test.yml) and its matching export templates. Install/configure the Android SDK and JDK for that version using the [official Android export guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html).

The checked-in `Android` preset currently targets arm64-v8a, uses the default non-Gradle APK path, and has `package/signed=false`. These are development settings, not a completed distribution configuration.

## Required Setting / 必须设置

`project.godot` must have ETC2/ASTC texture compression enabled:

```ini
[rendering]
textures/vram_compression/import_etc2_astc=true
```

Run the existing preflight (it checks texture compression only):

```powershell
.\tools\check_android_export_config.ps1
```

If the setting is missing, use the editor or `.\tools\fix_android_export_config.ps1` in a dedicated checkout, then reimport resources.

## Trial build / 试玩包

Start with a debug export. Configure a local debug signing key and enable signing in the export preset used for the build if the APK will be installed. Keep secrets outside Git.

```powershell
& $godot --headless --editor --import --path . --quit
& $godot --headless --path . --export-debug "Android" "C:\Builds\BallWar_debug.apk"
```

Set `$godot` to the console executable and create the output directory first. Check the logs and exit status of both commands. An unsigned APK is not an installable trial package.

## Release build / 正式包

For a signed release, configure a persistent release key locally and enable signing. Do not commit the key, passwords or private editor credentials. Preserve the package identity and signing key for upgrades; increment Android versionCode relative to the previous distributed build and align versionName with the game release.

```powershell
& $godot --headless --path . --export-release "Android" "C:\Builds\BallWar_vX.Y.Z.apk"
```

Use Android SDK build-tools `apksigner verify --print-certs <apk>` and `aapt dump badging <apk>` (or equivalent SDK tooling) to inspect the resulting artifact. Verify package name, version code/name, supported ABI and signature; then test installation and actual gameplay on a supported Android device. Verify update installation from the previous package when claiming upgrade compatibility.

## Troubleshooting / 排错

- Confirm the engine/template versions, SDK/JDK settings and ETC2/ASTC import.
- Use the exact preset name `Android` and an existing output directory.
- If a debug APK exports but will not install, inspect its signature and compare the installed application's signing identity and versionCode. Do not automatically uninstall a player's existing app or erase their data.
- Only enable Gradle/custom templates if a concrete Android feature requires them.

The last documented public APK (v2.1.11) was described as a debug/trial build. Its actual signature and installation status have not been revalidated by this documentation update. See [RELEASE_PROCESS.md](RELEASE_PROCESS.md) for the release gate.
