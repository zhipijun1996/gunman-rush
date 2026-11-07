#!/usr/bin/env python3
"""Restore and check the portable Godot room-art bundle using explicit local dependencies.

Examples (run from the extracted bundle/repository):
  python3 tools/art_bundle.py inspect
  python3 tools/art_bundle.py setup render godot
  python3 tools/art_bundle.py prepare-godot
  python3 tools/art_bundle.py smoke --html --godot

No command installs Godot, ffmpeg, system packages, or image-generation tools.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def inside(root, relative):
    path = (root / relative).resolve()
    if not path.is_relative_to(root) or Path(relative).is_absolute():
        raise ValueError(f"Path leaves the bundle: {relative}")
    return path


def child_env():
    env = os.environ.copy()
    # Dependencies must come from npm ci / the selected Python, not host-only fallbacks.
    for name in ("NODE_PATH", "CODEX_PRIMARY_RUNTIME_NODE_MODULES"):
        env.pop(name, None)
    env["PYTHONNOUSERSITE"] = "1"
    return env


def run(command, cwd, timeout=180):
    result = subprocess.run([str(v) for v in command], cwd=cwd, env=child_env(),
                            capture_output=True, text=True, timeout=timeout)
    if result.returncode:
        detail = (result.stdout + result.stderr)[-6000:]
        raise RuntimeError(f"Command failed ({result.returncode}): {command[0]}\n{detail}")
    return result


def executable(value):
    resolved = shutil.which(value)
    if resolved:
        return resolved
    path = Path(value).expanduser()
    if path.is_file() and os.access(path, os.X_OK):
        return str(path.resolve())
    raise RuntimeError(f"Executable unavailable: {value}")


def bundle_paths(root):
    metadata = read_json(root / "bundle-manifest.json")
    art = inside(root, metadata.get("asset_root", metadata.get("art_root", "art/world-art-v2")))
    skill = inside(root, metadata.get("skill_root", ".agents/skills/godot-room-art"))
    return metadata, art, skill


def inspect_bundle(root, skip_hashes=False):
    metadata, art, skill = bundle_paths(root)
    records = metadata["files"]
    if not isinstance(records, list) or not records:
        raise ValueError("bundle-manifest.json requires a nonempty files array")
    errors, names = [], set()
    for record in records:
        relative = record["path"]
        if relative in names:
            errors.append(f"Duplicate manifest path: {relative}")
        names.add(relative)
        path = inside(root, relative)
        if not path.is_file():
            errors.append(f"Missing: {relative}")
            continue
        if not skip_hashes and path.stat().st_size != record["bytes"]:
            errors.append(f"Size differs: {relative}")
        if not skip_hashes and digest(path) != record["sha256"]:
            errors.append(f"SHA-256 differs: {relative}")
    if errors:
        return {"passed": False, "files_checked": len(records), "errors": errors}
    spec = importlib.util.spec_from_file_location("room_art_inspector", skill / "scripts/inspect_pack.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    art_report = module.inspect(argparse.Namespace(pack=str(art), region=None, complete=True,
                                                 hashes=not skip_hashes))
    return {"passed": not art_report["errors"], "bundle_version": metadata.get("bundle_version", metadata.get("version")),
            "files_checked": len(records), "hashes_checked": not skip_hashes,
            "regions": art_report["canonical_region_count"],
            "terrain47_regions": art_report["terrain47_region_count"],
            "used_assets_checked": art_report["checked_file_count"],
            "errors": art_report["errors"], "warnings": art_report["warnings"],
            "scope": "Bundle integrity and asset/configuration checks; no aesthetic or gameplay approval."}


def python_path(root, explicit=None):
    if explicit:
        return executable(explicit)
    candidate = root / ".venv-art" / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
    if not candidate.is_file():
        raise RuntimeError("Run 'setup godot' / 'setup bake', or explicitly select --python /path/to/python")
    return str(candidate)


def pillow_python(root, explicit=None):
    interpreter = python_path(root, explicit)
    run([interpreter, "-c", "from PIL import Image; print(Image.__version__)"], root)
    return interpreter


def setup(root, modes, interpreter):
    _, art, _ = bundle_paths(root)
    if set(modes) - {"minimal", "render", "godot", "bake"}:
        raise ValueError("Setup modes: minimal, render, godot, bake")
    report = {"passed": True, "modes": modes, "installed": [], "tools": {}}
    for name in ("node", "npm", "godot", "godot4", "ffmpeg"):
        report["tools"][name] = shutil.which(name)
    if "render" in modes:
        node, npm = executable("node"), executable("npm")
        if not (art / "package-lock.json").is_file():
            raise RuntimeError("Missing package-lock.json")
        run([npm, "ci", "--no-audit", "--no-fund", "--fetch-retries=0", "--fetch-timeout=30000"], art, 300)
        result = run([node, "-e", "console.log(JSON.stringify({canvas:require('@napi-rs/canvas/package.json').version,sharp:require('sharp').versions.sharp}))"], art)
        report["installed"].append({"node": json.loads(result.stdout)})
    if "godot" in modes or "bake" in modes:
        venv = root / ".venv-art"
        target_python = venv / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
        if not target_python.is_file():
            run([executable(interpreter), "-m", "venv", str(venv)], root)
        filename = "requirements-bake.txt" if "bake" in modes else "requirements-godot.txt"
        run([target_python, "-m", "pip", "install", "--disable-pip-version-check", "--retries", "0", "--timeout", "30", "-r", str(art / filename)], root, 300)
        modules = ["Pillow", "numpy", "scipy"] if "bake" in modes else ["Pillow"]
        result = run([target_python, "-c", "import importlib.metadata,json; print(json.dumps({n:importlib.metadata.version(n) for n in " + repr(modules) + "}))"], root)
        report["installed"].append({"python": json.loads(result.stdout), "venv": ".venv-art"})
    report["notes"] = ["Godot, ffmpeg and image-generation tools are not installed by this command.",
                       "Use the project's Godot version; the supplied sample was tested with 4.6.3.",
                       "Chinese preview labels use Noto Sans CJK when available; fonts do not alter raster artwork."]
    return report


def prepare_godot(root, interpreter=None):
    _, art, _ = bundle_paths(root)
    python = pillow_python(root, interpreter)
    project = art / "godot"
    atlas_manifest = art / "assets/terrain47/manifest.json"
    atlas = read_json(atlas_manifest)
    target_manifest = project / "terrain47/manifest.json"
    target_manifest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(atlas_manifest, target_manifest)
    for rid, region in atlas["regions"].items():
        target = region["godotTexture"]
        if not target.startswith("res://"):
            raise ValueError(f"Invalid Godot texture path for {rid}")
        destination = inside(project.resolve(), target[6:])
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(inside(art, region["atlas"]), destination)
        resource = inside(project.resolve(), region["godotResource"][6:])
        if not resource.is_file():
            raise RuntimeError(f"Missing packaged TileSet: {resource.name}")
    result = run([python, str(project / "build_scene.py")], art, 240)
    missing = []
    for source in [project / "study.tscn", *sorted((project / "terrain47").glob("*.tres"))]:
        for reference in re.findall(r'path="(res://[^"]+)"', source.read_text(encoding="utf-8")):
            if not inside(project.resolve(), reference[6:]).is_file():
                missing.append(reference)
    if missing:
        raise RuntimeError("Unresolved Godot resources: " + ", ".join(sorted(set(missing))))
    return {"passed": True, "terrain_atlases_restored": len(atlas["regions"]),
            "builder": json.loads(result.stdout),
            "entry": str(project / "project.godot"),
            "scope": "Generated editable scene/resources; opening or rendering the engine is separate."}


SMOKE_JS = r'''
const fs=require('fs'),path=require('path'),crypto=require('crypto'),assert=require('assert');
const [art,out,selection]=process.argv.slice(1),ids=selection.split(','),renderer=require(path.join(art,'render-study.cjs'));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
(async()=>{
  const data=JSON.parse(fs.readFileSync(path.join(art,'study.json'),'utf8'));
  data.regions=ids.map(id=>{const r=data.regions.find(r=>r.id===id);if(!r)throw new Error('Unknown region '+id);return r;});
  data.defaultRegion=ids[0];
  const study=await renderer.createStudy({data});study.demo.setPaused(true);study.demo.setCameraOffset(0);study.demo.seek(1200);
  const used=study.demo.usedAssets();assert.equal(study.demo.getState().loaded,used.sprites.length+used.backgrounds.length);
  const frames=[],checks=['all_selected_assets_loaded'];fs.mkdirSync(out,{recursive:true});
  for(const id of ids){
    study.demo.setRegion(id);study.demo.setDepth(true);study.demo.setLighting(false);
    const unlit=study.canvases[id].toBuffer('image/png');
    study.demo.setLighting(true);const lit=study.canvases[id].toBuffer('image/png');
    assert.notEqual(sha(lit),sha(unlit),'Lighting has no visible effect: '+id);
    study.demo.setDepth(false);assert.notEqual(sha(lit),sha(study.canvases[id].toBuffer('image/png')),'Depth has no visible effect: '+id);study.demo.setDepth(true);
    const file=path.join(out,id+'.png');fs.writeFileSync(file,lit);
    const reference=path.join(art,'previews',id+'-lit.png');let matches_reference=null;
    if(fs.existsSync(reference)){matches_reference=sha(lit)===sha(fs.readFileSync(reference));assert(matches_reference,'Restored frame differs from packaged reference: '+id);}
    frames.push({region:id,file,sha256:sha(lit),matches_packaged_reference:matches_reference});
    checks.push(id+':lighting_changes_pixels',id+':depth_changes_pixels');
  }
  for(const offset of [-32,0,32]){
    study.demo.setCameraOffset(offset);
    for(const r of study.demo.getSnapshot().regions)for(const layer of r.layers||[]){assert(Number.isInteger(layer.screenOffset));assert(Number.isInteger(layer.drawBounds.x)&&Number.isInteger(layer.drawBounds.y));}
  }
  checks.push('integer_depth_placements_at_camera_minus32_zero_plus32');study.demo.setCameraOffset(0);
  const result={passed:true,renderer:'Canvas/Skia, not Godot',regions:ids,checks,frames,scope:'Restore smoke test on the existing shared sample and ±32px horizontal camera offsets; no new room-layout or gameplay acceptance.'};
  fs.writeFileSync(path.join(out,'canvas-smoke.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));
})().catch(e=>{console.error(e);process.exitCode=1;});
'''


def smoke(root, regions, output, html=False, godot=None):
    _, art, _ = bundle_paths(root)
    output.mkdir(parents=True, exist_ok=True)
    result = run([executable("node"), "-e", SMOKE_JS, str(art), str(output), ",".join(regions)], art)
    report = {"passed": True, "canvas": json.loads(result.stdout)}
    if html:
        result = run([executable("node"), str(art / "build-preview.cjs"), "--out", str(output / "world-art-preview.html"), "--inline", str(output / "world-art-inline.html")], art, 240)
        report["html"] = json.loads(result.stdout)
    if godot is not None:
        engine, project = executable(godot), art / "godot"
        if not (project / "assets/geometry.json").is_file():
            raise RuntimeError("Run prepare-godot before smoke --godot")
        report["godot"] = {"version": run([engine, "--version"], root).stdout.strip()}
        runtime_report = project / "lighting-checks.json"
        runtime_report.unlink(missing_ok=True)
        for label, args in [("import", ["--editor", "--quit"]),
                            ("runtime", ["--script", "res://verify_lighting.gd"])]:
            command = [engine, "--headless", "--path", str(project), *args]
            result = run(command, root, 240)
            (output / ("godot-" + label + ".log")).write_text(result.stdout + result.stderr, encoding="utf-8")
            if "SCRIPT ERROR:" in result.stderr or "ERROR:" in result.stderr:
                raise RuntimeError(f"Godot {label} logged errors; inspect {output / ('godot-' + label + '.log')}")
        validated = read_json(runtime_report)
        if not validated.get("passed"):
            raise RuntimeError("Godot runtime checks failed")
        shutil.copyfile(runtime_report, output / "godot-runtime.json")
        report["godot"].update({"passed": True, "checks": len(validated["checks"]),
                                "regions": validated["regions"], "rendering": "headless dummy renderer; no GPU frame acceptance"})
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1], help="Bundle/repository root (normally detected from tools/art_bundle.py)")
    parser.add_argument("--report", type=Path, help="Optional JSON report path")
    sub = parser.add_subparsers(dest="command", required=True)
    check = sub.add_parser("inspect", help="Check delivery files and all 16 regional asset contracts")
    check.add_argument("--structure-only", "--skip-hashes", dest="skip_hashes", action="store_true", help="After intentional edits, check required paths/current asset contracts instead of frozen delivery sizes/hashes")
    install = sub.add_parser("setup", help="Install only explicitly selected project-local dependencies")
    install.add_argument("modes", nargs="*", metavar="MODE", help="minimal (default), render, godot, bake; multiple modes may be combined")
    install.add_argument("--python", default=sys.executable, help="Base Python used to create .venv-art")
    prepare = sub.add_parser("prepare-godot", help="Restore duplicate engine resources and rebuild the editable Godot sample")
    prepare.add_argument("--python", help="Explicit existing Python with Pillow; otherwise .venv-art is required")
    test = sub.add_parser("smoke", help="Render two existing regions; optionally build offline HTML and run Godot headless checks")
    test.add_argument("--regions", default="windchime_plains,thorn_forest", help="Comma-separated canonical region IDs")
    test.add_argument("--output", type=Path, help="Default: runtime-output/smoke under the bundle")
    test.add_argument("--html", action="store_true")
    test.add_argument("--godot", nargs="?", const="godot", help="Include engine checks; optionally provide Godot executable path")
    args = parser.parse_args()
    started = time.monotonic()
    try:
        root = args.root.expanduser().resolve()
        if args.command == "inspect":
            report = inspect_bundle(root, args.skip_hashes)
        elif args.command == "setup":
            report = setup(root, args.modes or ["minimal"], args.python)
        elif args.command == "prepare-godot":
            report = prepare_godot(root, args.python)
        else:
            output = (args.output or root / "runtime-output/smoke").expanduser().resolve()
            regions = [rid.strip() for rid in args.regions.split(",") if rid.strip()]
            if not regions:
                raise ValueError("Select at least one region")
            report = smoke(root, regions, output, args.html, args.godot)
        report["elapsed_seconds"] = round(time.monotonic() - started, 3)
    except (OSError, ValueError, KeyError, TypeError, RuntimeError, subprocess.TimeoutExpired) as exc:
        report = {"passed": False, "error": str(exc), "elapsed_seconds": round(time.monotonic() - started, 3)}
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0 if report.get("passed") else 1


if __name__ == "__main__":
    raise SystemExit(main())
