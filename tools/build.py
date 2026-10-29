"""Build a debug artifact; export and device execution are separate evidence."""
import argparse
import hashlib
import gzip
import json
import re
import shutil
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
    # The official runtime is immutable across gameplay-only changes. Name all
    # engine files together so JS/WASM/audio worklets can never cross versions.
    engine_files = [html.with_suffix(suffix) for suffix in
                    (".js", ".wasm", ".audio.worklet.js", ".audio.position.worklet.js")]
    engine_id = hashlib.sha256(b"".join(path.read_bytes() for path in engine_files if path.exists())).hexdigest()[:12]
    engine_base = f"index.{engine_id}.engine"
    for source in engine_files[:2]:
        if not source.is_file():
            raise RuntimeError(f"Required official runtime missing: {source.name}")
    # Local rebuilds must not upload obsolete engine binaries indefinitely.
    for previous in html.parent.glob("index.*.engine.*"):
        previous.unlink()
    runtime_files = []
    # Independently hashed small files survive interrupted downloads and can be
    # reused across builds. Raw official resources remain the compatibility path.
    chunk_dir = html.parent / "chunks"
    if chunk_dir.exists():
        shutil.rmtree(chunk_dir)
    chunk_dir.mkdir()
    chunk_files = []
    resources = {}
    for target in (versioned, engine_files[1]):
        data = target.read_bytes()
        chunks = []
        for offset in range(0, len(data), 512 * 1024):
            block = data[offset:offset + 512 * 1024]
            digest = hashlib.sha256(block).hexdigest()
            compressed = chunk_dir / (digest + ".gz")
            compressed.write_bytes(gzip.compress(block, compresslevel=9, mtime=0))
            chunk_files.append(compressed)
            chunks.append({"url": "chunks/" + compressed.name, "sha256": digest,
                           "bytes": len(block), "gzip_bytes": compressed.stat().st_size})
        resources[target.name] = {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
                                  "chunks": chunks,
                                  "mime": "application/wasm" if target.suffix == ".wasm" else "application/octet-stream"}

    for source in engine_files:
        if not source.exists():
            continue
        target = source.with_name(engine_base + source.name[len(html.stem):])
        source.rename(target)
        runtime_files.append(target)
        resources[target.name] = resources.pop(source.name, {"bytes": target.stat().st_size})
        if target.suffix == ".wasm":
            compressed = target.with_suffix(".wasm.gz")
            compressed.write_bytes(gzip.compress(target.read_bytes(), compresslevel=9, mtime=0))
            runtime_files.append(compressed)
            resources[target.name].update(gzip=compressed.name,
                                         sha256=hashlib.sha256(target.read_bytes()).hexdigest())
    config["executable"] = engine_base
    config["fileSizes"][engine_base + ".wasm"] = config["fileSizes"].pop(html.with_suffix(".wasm").name)
    match = re.search(r"const GODOT_CONFIG = (\{[^\n]+\});", page)
    page = page[:match.start(1)] + json.dumps(config, separators=(",", ":")) + page[match.end(1):]
    page = page.replace('<script src="index.js"></script>', f'<script src="{engine_base}.js"></script>')
    # Wait for cache control before the first WASM fetch. Unsupported/denied
    # service workers fall back in <=4s; the standard runtime remains exported.
    worker_template = (REPO / "tools/web/cache_worker.js").read_text().replace(
        "__RESOURCE_MAP__", json.dumps(resources, separators=(",", ":")))
    startup_template = (REPO / "tools/web/cache_startup.js").read_text()
    worker_id = hashlib.sha256((worker_template + startup_template).encode()).hexdigest()[:12]
    startup = startup_template.replace("__BUILD_ID__", json.dumps(build_id)).replace("__WORKER_ID__", json.dumps(worker_id))
    # Render the canvas at device density; keep nearest composition for the
    # selected pixel art. UI geometry is shared logical canvas space.
    page = page.replace("</head>", '<style id="playtest-pixel-canvas">#canvas { image-rendering: pixelated; }</style>\n<script>\n' + startup + "\n</script>\n</head>")
    start_marker = "engine.startGame({"
    end_marker = "}).then(() => {\n\t\t\tsetStatusMode('hidden');"
    if start_marker not in page or end_marker not in page:
        raise RuntimeError("Official Web startup changed; refusing an unverified loader")
    page = page.replace(start_marker, "window.PLAYTEST_CACHE_READY.then(() => engine.startGame({")
    page = page.replace("}).then(() => {\n\t\t\tsetStatusMode('hidden');", "})).then(() => {\n\t\t\twindow.PLAYTEST_LOADING_DONE = true; document.getElementById('playtest-download')?.remove();\n\t\t\tsetStatusMode('hidden');")
    worker = html.parent / "index.cache-sw.js"
    worker.write_text(worker_template.replace("__WORKER_ID__", json.dumps(worker_id)))
    badge = (f'<div id="playtest-version" data-build-id="{build_id}" '
             'style="position:fixed;bottom:3px;left:5px;z-index:9;pointer-events:none;'
             f'font:10px sans-serif;color:#9ba7b6">试玩 {build_id[:8]}</div>')
    page = page.replace("</body>", badge + "\n</body>")
    html.write_text(page)
    metadata = html.parent / "build-info.json"
    metadata.write_text(json.dumps({"build_id": build_id, "pack": versioned.name,
                                   "engine_id": engine_id, "cache_schema": 2, "loader_id": worker_id,
                                   "pack_bytes": versioned.stat().st_size,
                                   "download_bytes": sum(c["gzip_bytes"] for r in resources.values() for c in r.get("chunks", [])),
                                   "chunk_bytes": 512 * 1024,
                                   "wasm_bytes": resources[engine_base + ".wasm"]["bytes"],
                                   "wasm_gzip_bytes": next(p.stat().st_size for p in runtime_files if p.name.endswith(".wasm.gz")),
                                   "jump": "tap/hold", "playtest": "web",
                                   "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip()}) + "\n")
    mirror_config = html.parent / "nginx-playtest.conf.example"
    shutil.copyfile(REPO / "tools/web/nginx-playtest.conf", mirror_config)
    return [html, versioned, *runtime_files, *sorted(set(chunk_files)), worker, metadata, mirror_config]


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
    if (REPO / "resources/foundry/batch.json").exists():
        run_engine(["--headless", "--path", str(REPO), "--script", "tools/foundry_export_stamp.gd"], 30)
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
    if args.platform in ("windows", "web"):
        font_license = artifact.parent / "NotoSansSC-OFL.txt"
        shutil.copyfile(REPO / "assets/fonts/OFL.txt", font_license)
        files.append(font_license)
        for source_license in sorted((REPO / "assets/audio/kenney").glob("*-LICENSE.txt")):
            audio_license = artifact.parent / ("Kenney-" + source_license.name)
            shutil.copyfile(source_license, audio_license)
            files.append(audio_license)
        provenance = artifact.parent / "Kenney-audio-sources.json"
        shutil.copyfile(REPO / "assets/audio/kenney/sources.json", provenance)
        files.append(provenance)
        # Keep source terms with this isolated audio candidate export.
        director_sources = REPO / "config/audio_director/sources.json"
        if director_sources.is_file():
            destination = artifact.parent / "Audio-Director-sources.json"
            shutil.copyfile(director_sources, destination)
            files.append(destination)
        freedoom_license = REPO / "assets/player_presentation_01/weapon_audio_v2/sources/COPYING.adoc"
        if freedoom_license.is_file():
            destination = artifact.parent / "Freedoom-COPYING.adoc"
            shutil.copyfile(freedoom_license, destination)
            files.append(destination)
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
