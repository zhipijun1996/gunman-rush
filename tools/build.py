"""Build a debug artifact; export and device execution are separate evidence."""
import argparse
import hashlib
import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path

from check_environment import REPO, SDK, environment
from run_tests import run_engine


def prepare_web_playtest(html):
    """Name gameplay data by content so a phone never reuses an older pack."""
    pack = html.with_suffix(".pck")
    build_id = hashlib.sha256(pack.read_bytes()).hexdigest()[:12]
    versioned = pack.with_name(f"index.{build_id}.pck")
    for previous in html.parent.glob("index.*.pck"):
        previous.unlink()
    pack.rename(versioned)
    page = html.read_text()
    match = re.search(r"const GODOT_CONFIG = (\{[^\n]+\});", page)
    if not match:
        raise RuntimeError("Web template config not found; refusing an unstamped playtest")
    config = json.loads(match.group(1))
    config["mainPack"] = versioned.name
    config["fileSizes"][versioned.name] = config["fileSizes"].pop(pack.name)
    config["ensureCrossOriginIsolationHeaders"] = False
    page = page[:match.start(1)] + json.dumps(config, separators=(",", ":")) + page[match.end(1):]
    # A stale cached HTML page redirects at most once to the current build.
    freshness = """<script>
fetch('build-info.json', {cache: 'no-store'}).then(r => r.json()).then(live => {
 const next = new URL(location.href);
 if (live.build_id !== BUILD_ID && next.searchParams.get('v') !== live.build_id) {
  next.searchParams.set('v', live.build_id);
  location.replace(next.href);
 }
}).catch(() => {});
</script>""".replace("BUILD_ID", json.dumps(build_id))
    page = page.replace("</head>", freshness + "\n</head>")
    badge = (f'<div id="playtest-version" data-build-id="{build_id}" '
             'style="position:fixed;bottom:3px;left:5px;z-index:9;pointer-events:none;'
             f'font:10px sans-serif;color:#9ba7b6">试玩 {build_id[:8]}</div>')
    page = page.replace("</body>", badge + "\n</body>")
    html.write_text(page)
    metadata = html.parent / "build-info.json"
    metadata.write_text(json.dumps({"build_id": build_id, "pack": versioned.name,
                                   "jump": "tap/hold", "playtest": "web"}) + "\n")
    return [html, versioned, html.with_suffix(".js"), html.with_suffix(".wasm"), metadata]


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
    if args.platform == "web":
        files = prepare_web_playtest(artifact)
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
