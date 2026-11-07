#!/usr/bin/env python3
"""Import and test only the terrain47 package in an isolated minimal Godot project."""
import json
import shutil
import subprocess
from pathlib import Path

BASE = Path(__file__).resolve().parents[1]
OUTPUT = BASE / "godot/terrain47"
PROJECT = BASE / "autotile/godot-validation-project"
PROJECT.mkdir(parents=True, exist_ok=True)
(PROJECT / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Terrain47 validation"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/default_filters/use_nearest_mipmap_filter=false\ntextures/canvas_textures/default_texture_filter=0\n')
shutil.copytree(OUTPUT, PROJECT / "terrain47", dirs_exist_ok=True, ignore=shutil.ignore_patterns("*.import", "*.uid"))
godot = shutil.which("godot")
if not godot:
    raise RuntimeError("Godot is required for actual terrain resource generation and validation.")
results = []
for stage, args in (
    ("import", ["--editor", "--quit"]),
    ("build", ["--script", "res://terrain47/build_resources.gd"]),
    ("verify", ["--script", "res://terrain47/verify_resources.gd"]),
):
    result = subprocess.run([godot, "--headless", "--path", str(PROJECT)] + args, capture_output=True, text=True, timeout=90)
    (BASE / "autotile" / f"godot-{stage}.log").write_text(result.stdout + result.stderr)
    print(stage, "exit", result.returncode)
    results.append({"stage": stage, "exitCode": result.returncode})
    if result.returncode:
        print(result.stdout + result.stderr)
        raise SystemExit(result.returncode)
for resource in (PROJECT / "terrain47").glob("*.tres"):
    shutil.copy2(resource, OUTPUT / resource.name)
shutil.copy2(PROJECT / "terrain47/godot-validation.json", OUTPUT / "godot-validation.json")
shutil.copy2(PROJECT / "terrain47/godot-validation.json", BASE / "autotile/godot-validation.json")
report = json.loads((OUTPUT / "godot-validation.json").read_text())
print(json.dumps({"status": report["status"], "regions": report["regionCount"], "tiles": report["tileCount"], "rawMaskMatches": report["allRawMaskEngineMatches"]}))
shutil.rmtree(PROJECT)
