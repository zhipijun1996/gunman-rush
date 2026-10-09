"""Build a debug artifact; export and device execution are separate evidence."""
import argparse
import hashlib
import json
import subprocess
import sys
import zipfile
from pathlib import Path

from check_environment import REPO, SDK, environment
from run_tests import run_engine


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", choices=["android", "windows", "web"])
    args = parser.parse_args()
    check = [sys.executable, str(REPO / "tools/check_environment.py")]
    if args.platform in ("windows", "web"):
        check.append("--godot-only")
    subprocess.run(check, check=True, timeout=120, env=environment())
    wrapper = ["bash", str(REPO / "tools/godot.sh"), "--headless", "--path", str(REPO)]
    run_engine(["--headless", "--path", str(REPO), "--editor", "--quit"], 90)
    preset = {"android": "Android", "windows": "Windows Desktop", "web": "Web Playtest"}[args.platform]
    name = {"android": "gunman-rush-debug.apk", "windows": "gunman-rush.exe", "web": "index.html"}[args.platform]
    artifact = REPO / "build" / args.platform / name
    artifact.parent.mkdir(parents=True, exist_ok=True)
    # Remove stale artifacts so a failed export cannot be mistaken for this build.
    artifact.unlink(missing_ok=True)
    subprocess.run(wrapper + ["--export-debug", preset, str(artifact)], check=True, timeout=180)
    files = [artifact]
    if args.platform == "windows":
        files.append(artifact.with_suffix(".pck"))
    elif args.platform == "web":
        files.extend(artifact.with_suffix(suffix) for suffix in (".pck", ".js", ".wasm"))
    if not all(p.is_file() and p.stat().st_size for p in files):
        raise RuntimeError("Export returned success without all expected artifacts")
    if args.platform == "android":
        with zipfile.ZipFile(artifact) as package:
            for required in ("assets/config/player_tuning.json", "assets/config/input_profile.json"):
                if required not in package.namelist():
                    raise RuntimeError(f"APK missing required runtime configuration: {required}")
        subprocess.run([str(SDK / "build-tools/35.0.1/apksigner"), "verify", str(artifact)],
                       check=True, env=environment(), timeout=60)
    report = {"platform": args.platform, "export_exit_code": 0,
              "device_execution": "unverified", "artifacts": [
                  {"path": str(p.relative_to(REPO)), "bytes": p.stat().st_size,
                   "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in files]}
    output = artifact.parent / "build_report.json"
    output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(f"Build failed: command exited {error.returncode}", file=sys.stderr)
        sys.exit(error.returncode or 1)
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"Build failed: {error}", file=sys.stderr)
        sys.exit(1)
