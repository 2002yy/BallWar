"""Build a Windows trial/release candidate from a clean BallWar checkout.

Requires Python 3.9+, Git, Godot editor console executable and matching templates.
Usage: python tools/build_windows.py --godot "D:/Godot/godot_console.exe"
No tag creation, release upload, signing, or runtime acceptance is performed.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()


def require_clean(root):
    if git(root, "status", "--porcelain", "--untracked-files=normal"):
        raise RuntimeError("Use a clean, dedicated checkout; no files will be reset.")


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def run_godot(exe, root, log, *args):
    with log.open("wb") as stream:
        result = subprocess.run(
            [exe, "--headless", "--path", str(root), *args],
            cwd=root, stdout=stream, stderr=subprocess.STDOUT,
        )
    if result.returncode or re.search(
        r"SCRIPT ERROR|^ERROR:", log.read_text(encoding="utf-8", errors="replace"), re.M
    ):
        raise RuntimeError(f"Godot failed or logged an error; inspect {log}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, help="Godot editor console executable")
    parser.add_argument("--out", type=Path, help="New output directory outside checkout")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    require_clean(root)
    commit = git(root, "rev-parse", "HEAD")
    project = (root / "project.godot").read_text(encoding="utf-8")
    workflow = (root / ".github/workflows/test.yml").read_text(encoding="utf-8")
    version_match = re.search(r'^config/version="([0-9]+(?:\.[0-9]+)+)"$', project, re.M)
    engine_match = re.search(r"^\s*GODOT_VERSION:\s*([0-9.]+)-stable\s*$", workflow, re.M)
    if not version_match or not engine_match:
        raise RuntimeError("Cannot identify project version or pinned stable Godot version.")
    version = version_match[1]
    exe = shutil.which(args.godot)
    if exe is None:
        raise RuntimeError("Godot executable not found.")
    exe = str(Path(exe).resolve())
    engine = subprocess.check_output([exe, "--version"], text=True).strip()
    if not (engine == engine_match[1] + ".stable" or engine.startswith(engine_match[1] + ".stable.")):
        raise RuntimeError(f"Godot version mismatch: {engine}")
    presets = (root / "export_presets.cfg").read_text(encoding="utf-8")
    if 'name="Windows Desktop"' not in presets:
        raise RuntimeError("Windows Desktop export preset missing.")
    out = (args.out or root.parent / f"BallWar-build-{version}-{commit[:8]}").resolve()
    if out == root or root in out.parents:
        raise RuntimeError("Output must be outside the checkout.")
    out.mkdir(parents=True, exist_ok=False)
    win = out / "Windows"
    win.mkdir()
    run_godot(exe, root, out / "import.log", "--editor", "--import", "--quit")
    run_godot(exe, root, out / "export.log", "--export-release", "Windows Desktop", str(win / "BallWar.exe"))
    require_clean(root)
    if git(root, "rev-parse", "HEAD") != commit:
        raise RuntimeError("Source commit changed during export.")
    for name in ("BallWar.exe", "BallWar.pck"):
        path = win / name
        if not path.is_file() or path.stat().st_size == 0:
            raise RuntimeError(f"Missing or empty export: {path}")
    files = sorted(p for p in win.rglob("*") if p.is_file())
    package = out / f"BallWar_v{version}_{commit[:8]}.zip"
    with zipfile.ZipFile(package, "x", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in files:
            archive.write(path, path.relative_to(win).as_posix())
    with zipfile.ZipFile(package) as archive:
        if archive.testzip() is not None:
            raise RuntimeError("ZIP CRC verification failed.")
    manifest = {
        "source_commit": commit, "project_version": version, "godot_version": engine,
        "preset": "Windows Desktop", "build_mode": "release",
        "runtime_acceptance": "not_tested",
        "package": {"name": package.name, "bytes": package.stat().st_size, "sha256": sha256(package)},
        "files": [{"name": p.relative_to(win).as_posix(), "bytes": p.stat().st_size,
                   "sha256": sha256(p)} for p in files],
    }
    (out / "build-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Built {package}\nSHA256: {manifest['package']['sha256']}\nRuntime acceptance: NOT TESTED")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.SubprocessError) as exc:
        print(f"Build failed: {exc}", file=sys.stderr)
        sys.exit(1)
