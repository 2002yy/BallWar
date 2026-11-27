# Release Process / 发布流程

Role: packaging and release checklist / 打包与发布检查清单

## Prerequisites / 前置

- Use the engine version pinned in [CI](../.github/workflows/test.yml) (currently Godot 4.7.1-stable) and matching export templates, not 4.6 templates.
- Build from a dedicated clean checkout of the exact commit to be released. Do not clean or reset a developer's working directory.
- Android SDK/JDK and signing configuration as described in [ANDROID_EXPORT.md](ANDROID_EXPORT.md).
- GitHub CLI (`gh`) for release creation; no signing credentials in Git.

## 1. Freeze the release candidate / 冻结候选版本

- Record the commit SHA, Godot version and intended tag.
- Align `project.godot` application version, Android `version/name`, and Windows product/file version (if set) with the intended release. Android `version/code` must increase relative to the previously distributed APK when publishing an update. Verify the installed package/signing identity before selecting the next code; do not infer it from the Git tag.
- Update CHANGELOG and download references as appropriate. Do not advertise packages that have not been uploaded.
- Require all current correctness runners in CI to pass at the release commit (see [TESTING.md](TESTING.md)). CI is a source-level gate, not an exported-binary smoke test.

## 2. Build Windows package / 打包 Windows

The preset is named **Windows Desktop**, not Windows. It currently uses a separate PCK (`binary_format/embed_pck=false`). Export an executable, then ZIP the entire exported directory, including the PCK and any required DLLs. Do not mistake a resources-only ZIP/PCK export for a playable game.

Example in PowerShell from the clean project checkout (set `$godot` to the actual console executable and choose a fresh output directory outside the repository):

```powershell
$version = "X.Y.Z"
$out = Join-Path (Split-Path (Get-Location).Path -Parent) "BallWar-build-$version"
if (Test-Path $out) { throw "Choose a fresh output directory: $out" }
$win = Join-Path $out "Windows"
New-Item -ItemType Directory -Path $win -ErrorAction Stop | Out-Null
& $godot --headless --editor --import --path . --quit
if ($LASTEXITCODE -ne 0) { throw "Import failed" }
& $godot --headless --path . --export-release "Windows Desktop" (Join-Path $win "BallWar.exe")
if ($LASTEXITCODE -ne 0) { throw "Windows export failed" }
foreach ($file in @("BallWar.exe", "BallWar.pck")) {
    if (-not (Test-Path (Join-Path $win $file) -PathType Leaf)) { throw "Missing $file" }
}
Compress-Archive -Path (Join-Path $win "*") -DestinationPath (Join-Path $out "BallWar_v$version.zip") -ErrorAction Stop
```

Review export logs for errors even if the process exits successfully. Extract the ZIP into a new directory and launch the extracted executable without the editor or source tree.

## 3. Build Android APK / 打包 Android

Run the existing texture-compression preflight, then follow [ANDROID_EXPORT.md](ANDROID_EXPORT.md).

The checked-in preset currently has `package/signed=false`; a successful export alone is not evidence of an installable APK. Configure signing locally, verify the exported signature and manifest, and test installation. Label debug/trial builds accordingly. Do not distribute an unsigned APK as an installable release.

## 4. Verify the actual packages / 验收实际构建

- Windows: extract, launch, start a match, pause/resume, save/continue, return to menu, exit.
- Android: verify signature, package ID, version name/code and ABI; install and launch on a real supported device, check landscape/touch, start a match, pause/resume and save/continue. Test upgrade from the last distributed APK if claiming upgrade compatibility; never delete player data merely to make an upgrade pass.
- Record the tested SHA, build mode, engine version, device/OS, test results and any untested cases.
- Inspect export contents for unwanted developer fixtures or archived assets. Do not remove resources blindly.
- Record SHA-256 for the exact uploaded ZIP/APK (PowerShell: `Get-FileHash -Algorithm SHA256 <file>`).
- Do not mark a target passed if only the source tests or export command ran.

## 5. Publish / 发布

Only after acceptance, create a tag at the verified commit and a **draft** Release with the actual files. Example (replace placeholders; do not reuse an existing tag for a different build):

```powershell
git tag -a "vX.Y.Z" <verified-commit-sha> -m "BallWar vX.Y.Z"
git push origin "vX.Y.Z"
gh release create "vX.Y.Z" <windows-zip> <android-apk> --draft --verify-tag --title "BallWar vX.Y.Z" --notes-file <release-notes>
```

Include only verified packages. If one platform is not ready, explicitly label that platform unavailable rather than attach an older build. Review the draft assets, names, sizes and checksums before publishing. Record any trial build or platform limitations in the notes. After publication, verify the public download and README links. GitHub-generated source archives are not game packages.

The source/tag, exported artifacts and acceptance record must describe the same build.
