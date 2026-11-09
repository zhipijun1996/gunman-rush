"""Export the real fixed-world runtime with an explicit mobile-workbench closure.

The editable world remains in its existing scenes/configuration. This command
builds a derived resource list, exports the dedicated preset, and verifies the
actual PCK. Known data changes then travel through the workbench bridge without
another export or engine download.
"""
from __future__ import annotations

import argparse
import fnmatch
import gzip
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
NAME = "Web Workbench"
ENTRY = "game/application/world/fixed_world.tscn"
TEXT = {".gd", ".tscn", ".tres", ".json", ".gdshader", ".gdshaderinc"}
RESOURCE = {".gd", ".tscn", ".tres", ".png", ".svg", ".webp", ".jpg", ".jpeg",
            ".wav", ".ogg", ".mp3", ".otf", ".ttf", ".gdshader", ".gdshaderinc"}
COMPONENTS = ["game/world/components/world_moving_platform.gd",
              "game/world/components/world_room_interaction.gd",
              "game/world/components/world_return_latch.gd",
              "game/world/components/world_flag_presentation.gd", "game/npcs/world_npc.gd",
              "game/presentation/audio/world_audio_lifecycle.gd"]
# These current consumers form filenames from manifests/IDs. Keep their admitted
# resource families, not the project's historical all_resources export.
DYNAMIC_FAMILIES = ["assets/underworld_plains", "assets/plains_v07/native",
                    "assets/player_presentation_01/motion_v1",
                    "assets/enemy_feedback_01/frames_v8", "assets/actor_actions",
                    "assets/world_interactions", "assets/items/v5",
                    "assets/plains_v3/background_layers", "assets/audio/kenney",
                    "resources/player",
                    "resources/actors", "resources/weapons", "resources/items"]
MANIFESTS = ["assets/plains_v07/manifest.json", "assets/actor_actions/weapon_catalog.json",
             "game/presentation/actors/resources/art/avatars.json",
             "config/player_tuning.json", "config/input_profile.json"]
RES_PATH = re.compile(r"[\"'](res://[^\"'\r\n]+)[\"']")
CLASS = re.compile(r"^class_name\s+(\w+)", re.M)


def sha(path: Path) -> str:
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def ignored(path: Path) -> bool:
    return any((parent / ".gdignore").is_file() for parent in [path.parent, *path.parents]
               if parent != ROOT and parent.is_relative_to(ROOT))


def manifest() -> dict:
    world = json.loads((ROOT / "build/world/runtime.json").read_text())
    construction = json.loads((ROOT / "config/world/construction.json").read_text())
    editable = {row["room_id"]: row for row in construction["rooms"] if row["room_id"].startswith("P-R")}
    presets = (ROOT / "export_presets.cfg").read_text()
    base = re.search(r'\[preset\.2\]\n(.*?)\[preset\.2.options\]', presets, re.S)[1]
    exclusions = json.loads(re.search(r'^exclude_filter=(.*)$', base, re.M)[1]).split(",")
    exclusions += ["resources/mapgen/*", "resources/levels/mapgen*", "config/mapgen*",
                   "assets/audio/bgm/vines_beneath_the_canopy.mp3", "assets/audio/bgm/beyond_the_knotted_vines.mp3"]
    # The real FixedWorldApp owns GameMusic and PlayerWeaponFeelAudioV2, not the
    # legacy DemoApp's optional ambience director. Its mechanism bell is the one
    # current consumer from this family; preserve that exact original sample.
    exclusions += [p.relative_to(ROOT).as_posix() for p in (ROOT / "assets/audio/ambience_v1").rglob("*")
                   if p.suffix in {".ogg", ".wav"} and p.name != "plains_chime_a.wav"]
    def excluded(name):
        return any(fnmatch.fnmatchcase(name, pattern) for pattern in exclusions)
    classes = {}
    for folder in ["game", "scripts", "resources", "scenes", "addons", "experiments"]:
        for path in (ROOT / folder).rglob("*.gd"):
            if ignored(path):
                continue
            found = CLASS.search(path.read_text())
            if found:
                classes[found[1]] = path.relative_to(ROOT).as_posix()
    pending = [ENTRY, "game/presentation/ui/demo_ui_01/game_typography.gd", *COMPONENTS, *MANIFESTS]
    pending += [row["scene_ref"].removeprefix("res://") for row in editable.values()]
    art = json.loads((ROOT / "art/world-art-v2/assets/pixel/manifest.json").read_text())
    props = json.loads((ROOT / "assets/plains_v07/manifest.json").read_text())["props"]
    sprite_ids = {key for key in art["sprites"] if key.startswith(("plains_", "windchime_plains_", "gear_city_"))}
    for row in editable.values():
        source = (ROOT / row["scene_ref"].removeprefix("res://")).read_text()
        sprite_ids.update(re.findall(r'"asset"\s*:\s*"([^"\n]+)"', source))
    for key in sprite_ids:
        if key in props:
            pending.append(props[key]["image"].removeprefix("res://"))
        else:
            pending.append("art/world-art-v2/" + art["sprites"][key]["file"])
    pending.append("art/world-art-v2/" + art["backgrounds"]["windchime_plains_v2"]["file"])
    for folder in DYNAMIC_FAMILIES:
        parent = ROOT / folder
        if not parent.is_dir():
            raise ValueError("Missing admitted dynamic family: " + folder)
        pending += [p.relative_to(ROOT).as_posix() for p in parent.rglob("*")
                    if p.is_file() and p.suffix in RESOURCE | {".json"} and not ignored(p)]
    # The finite gameplay registry owns these IDs and paths. Every registered
    # species offered by the game-derived editor catalog must exist in this pack.
    registry = (ROOT / "game/enemies/enemy_behavior_registry.gd").read_text()
    enemies = set()
    behavior_table = registry.split("const BEHAVIORS := {", 1)[1].split("\n}", 1)[0]
    for line in behavior_table.splitlines():
        match = re.match(r'\s*&"([a-z_]+)":', line)
        if match:
            enemies.add(match[1])
            pending += [p.removeprefix("res://") for p in RES_PATH.findall(line)]
    if not enemies:
        raise ValueError("Gameplay enemy registry is empty or changed its declaration format")
    seen, unresolved = set(), set()
    while pending:
        name = pending.pop()
        if name in seen:
            continue
        if excluded(name):
            continue
        path = (ROOT / name).resolve()
        if not path.is_relative_to(ROOT) or not path.is_file() or ignored(path):
            raise ValueError("Missing/unsafe workbench dependency: " + name)
        seen.add(name)
        if path.suffix not in TEXT:
            continue
        source = path.read_text()
        if path.suffix == ".gd":
            # Global script symbols are implicit Godot dependencies. Resolve only
            # code tokens; prose comments and resource strings do not add classes.
            code = re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|#[^\n]*', "", source)
            pending += [classes[token] for token in set(re.findall(r"\b[A-Za-z_]\w*\b", code))
                        if token in classes and classes[token] not in seen]
        if name == "game/enemies/enemy_behavior_registry.gd":
            # Registered rows above are complete; development-only candidate
            # recipes remain outside the editing catalog.
            pending.append("game/enemies/behaviors/enemy_attack_strategy.gd")
            continue
        for resource in RES_PATH.findall(source):
            child = resource.removeprefix("res://")
            candidate = ROOT / child
            if candidate.is_file() and candidate.suffix in RESOURCE | {".json"}:
                if child != "build/world/runtime.json":
                    pending.append(child)
            elif candidate.is_dir() or not candidate.suffix or any(x in child for x in ["%", "*", "{"]):
                # Data-dependent paths must belong to the admitted families or
                # registered resources. Keep them visible in the build report.
                unresolved.add(resource)
            elif candidate.suffix in RESOURCE | {".json"}:
                # Shared validators also contain deliberate negative fixtures.
                # Immediate preload references are mandatory; other dynamic
                # strings remain visible and must pass the real package probe.
                if re.search(r'preload\(\s*[\"\']' + re.escape(resource), source):
                    raise ValueError("Missing preload in " + name + ": " + resource)
                unresolved.add(resource)
    # This derived catalog admits preview-only rooms without changing the formal
    # six-room runtime bundle. Its sources are checked by preview_catalog().
    seen.add("build/workbench/preview-world.json")
    # FileAccess byte contracts: retain source bytes beside normal Godot imports.
    exporter = (ROOT / "addons/runtime_raw_export/raw_exporter.gd").read_text()
    underworld = re.search(r"const UNDERWORLD_SOURCES:.*?=\s*\[(.*?)\]", exporter, re.S)
    raw = {name for name in seen if name.endswith(".json") or name.startswith("resources/enemies/legacy/")}
    if underworld:
        raw.update(p for p in re.findall(r'"([^\"]+)"', underworld[1]) if p in seen)
    audio = re.search(r"const SELECTED_AUDIO_SOURCES:.*?=\s*\[(.*?)\]", exporter, re.S)
    if audio:
        raw.update(p for p in re.findall(r'"([^\"]+)"', audio[1]) if p in seen)
    rows = [{"path": name, "sha256": sha(ROOT / name), "bytes": (ROOT / name).stat().st_size}
            for name in sorted(seen)]
    identity = hashlib.sha256(json.dumps(rows, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return {"schema": 1, "entry": "res://" + ENTRY, "content_version": world["content_version"],
            "source_tree_sha256": identity, "rooms": sorted(editable), "formal_rooms": sorted(world["rooms"]), "enemy_ids": sorted(enemies),
            "files": rows, "raw_files": sorted(raw), "dynamic_prefixes": sorted(unresolved), "exclusions": exclusions}


def run(command: list[str], log: Path, timeout=300) -> str:
    log.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, timeout=timeout)
    log.write_text(result.stdout)
    if result.returncode or re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|^ERROR:", result.stdout, re.I | re.M):
        raise RuntimeError("Command failed; see " + str(log))
    return result.stdout


def configured_preset(original: str, plan: dict) -> str:
    found = re.search(r'\[preset\.(\d+)\]\n(?:(?!\[preset\.).)*?name="Web Workbench"', original, re.S)
    if not found:
        raise ValueError("Missing Web Workbench preset")
    number = found[1]
    start = original.index("[preset." + number + "]")
    options = original.index("[preset." + number + ".options]", start)
    header = original[start:options]
    names = ["res://" + row["path"] for row in plan["files"] if Path(row["path"]).suffix in RESOURCE]
    header = re.sub(r'^export_files=.*$', "export_files=PackedStringArray(" + ", ".join(json.dumps(p) for p in names) + ")", header, flags=re.M)
    # The export plugin adds the byte-checked raw list. Including it here too
    # would create duplicate PCK directory entries for JSON files.
    header = re.sub(r'^include_filter=.*$', 'include_filter=""', header, flags=re.M)
    header = re.sub(r'^exclude_filter=.*$', "exclude_filter=" + json.dumps(",".join(plan["exclusions"])), header, flags=re.M)
    return original[:start] + header + original[options:]


def verify_pack(pack_path: Path, plan: dict) -> dict:
    from check_web_bundle import Pack, check_fixed_world_payload
    pack = Pack(pack_path)
    fixed = check_fixed_world_payload(pack, ROOT)
    for name in plan["raw_files"]:
        if pack.read(name) != (ROOT / name).read_bytes():
            raise ValueError("Raw runtime bytes changed in pack: " + name)
    for row in plan["files"]:
        name = row["path"]
        if name in pack.entries:
            continue
        remap = name + (".remap" if Path(name).suffix in {".gd", ".tscn", ".tres"} else ".import")
        mapping = pack.read(remap).decode()
        targets = re.findall(r'^path(?:\.[A-Za-z0-9_]+)?="res://([^"\n]+)"$', mapping, re.M)
        if not targets or any(target not in pack.entries for target in targets):
            raise ValueError("Missing imported dependency: " + name)
    if any(name.startswith(("resources/mapgen/", "docs/", "assets/visual_development/")) for name in pack.entries):
        raise ValueError("Workbench pack contains unrelated generator/evidence payload")
    return {"files_checked": len(plan["files"]), "raw_files_checked": len(plan["raw_files"]), "fixed_world": fixed}


def probe_pack(pack_path: Path, log: Path) -> dict:
    with tempfile.TemporaryDirectory(prefix="workbench-pack-") as isolated:
        probe = Path(isolated) / "probe.gd"
        shutil.copyfile(ROOT / "tools/workbench/pack_probe.gd", probe)
        output = run(["bash", "tools/godot.sh", "--headless", "--path", isolated,
                      "--main-pack", str(pack_path), "--script", str(probe), "--fixed-fps", "60"], log, 180)
    match = re.search(r"WORKBENCH PACK failures=0 formal_rooms=(\d+) editable_scenes=(\d+) species=(\d+)", output)
    if match is None:
        raise RuntimeError("Isolated package probe did not finish; see " + str(log))
    return {"result": "pass", "formal_rooms": int(match[1]), "editable_scenes": int(match[2]), "species": int(match[3])}


def site_copy(source: Path, target: Path) -> dict:
    """Publish the verified chunk transport within a 25 MiB static-file limit.

    Raw PCK/WASM remain in the build output for other hosts and native probes.
    This copy requires the matching cache worker and gzip-stream support before
    starting Godot: unsupported/denied workers show an error, never a missing raw
    URL. Interrupted chunk downloads retain the normal checked-cache retries.
    """
    target = target.resolve()
    if target == source.resolve() or source.is_relative_to(target) or target.is_relative_to(source):
        raise ValueError("Site destination must be separate from the complete build output")
    info = json.loads((source / "build-info.json").read_text())
    if not info.get("workbench") or info.get("threads_enabled"):
        raise ValueError("Site copy requires the verified single-thread Workbench build")
    worker = (source / "index.cache-sw.js").read_text()
    resource_map = json.loads(re.search(r"^const RESOURCE_MAP = (.*);$", worker, re.M)[1])
    wasm = "index." + info["engine_id"] + ".engine.wasm"
    names = {"index.html", "index.png", "index.cache-sw.js", "build-info.json", "workbench-build.json"}
    virtual = {info["pack"], wasm}
    for name, resource in resource_map.items():
        if name not in virtual:
            if resource.get("chunks"):
                raise ValueError("Unexpected chunked resource: " + name)
            names.add(name)
            continue
        if not resource.get("chunks"):
            raise ValueError("Oversized virtual resource has no chunk transport: " + name)
        whole = hashlib.sha256()
        amount = 0
        for part in resource["chunks"]:
            chunk = part["url"]
            if chunk != "chunks/" + part["sha256"] + ".gz" or not re.fullmatch(r"[a-f0-9]{64}", part["sha256"]):
                raise ValueError("Unsafe chunk identity")
            compressed = (source / chunk).read_bytes()
            decoded = gzip.decompress(compressed)
            if len(compressed) != part["gzip_bytes"] or len(decoded) != part["bytes"] or hashlib.sha256(decoded).hexdigest() != part["sha256"]:
                raise ValueError("Published chunk differs from its manifest: " + chunk)
            whole.update(decoded)
            amount += len(decoded)
            names.add(chunk)
        if whole.hexdigest() != resource["sha256"] or amount != resource["bytes"]:
            raise ValueError("Published chunks do not reconstruct " + name)
    if not virtual.issubset(resource_map):
        raise ValueError("Virtual PCK/WASM absent from worker manifest")
    page = (source / "index.html").read_text()
    marker = "\tawait window.PLAYTEST_CACHE_READY;\n\tconst missing = Engine.getMissingFeatures({"
    if page.count(marker) != 1:
        raise ValueError("Verified Godot startup marker changed")
    gate = '''\tconst transportReady = await window.PLAYTEST_CACHE_READY;
\tif (!transportReady || typeof DecompressionStream === 'undefined') {
\t\tconst detail = '试玩加载未就绪。请刷新重试，或在最新版 Chrome 中打开此页。';
\t\tdocument.getElementById('playtest-download')?.remove();
\t\tdisplayFailureNotice(detail);
\t\treturn;
\t}
\tconst missing = Engine.getMissingFeatures({'''
    page = page.replace(marker, gate)
    failure_marker = "\t\tsetStatusMode('notice');\n\t\tinitializing = false;"
    if page.count(failure_marker) != 1:
        raise ValueError("Verified Godot startup failure handler changed")
    # Forward only the engine's real startup failure callback. Keep its original
    # diagnostic visible in the iframe; never substitute a fake playable scene.
    page = page.replace(failure_marker, failure_marker + '''
\t\tdocument.getElementById('playtest-download')?.remove();
\t\tconst diagnostic = statusNotice.textContent || String(err);
\t\tconst detail = diagnostic.includes('WebGL2')
\t\t\t? '当前浏览器未提供 WebGL 2，真实 Godot 试玩无法启动。请在支持 WebGL 2 的浏览器中重试。'
\t\t\t: '真实试玩启动失败：' + diagnostic;
\t\tif (window.parent !== window) window.parent.postMessage({channel:'gunman-workbench',type:'error',code:'runtime_startup_failed',detail,diagnostic}, location.origin);''')
    for name in names:
        path = source / name
        if not path.is_file() or path.stat().st_size > 25 * 1048576:
            raise ValueError("Missing/oversized Site artifact: " + name)
    if target.exists() and any(target.iterdir()):
        previous = target / "build-info.json"
        if not previous.is_file() or not json.loads(previous.read_text()).get("workbench"):
            raise ValueError("Refusing to replace a directory without Workbench build identity")
    target.mkdir(parents=True, exist_ok=True)
    for name in names:
        destination = target / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source / name, destination)
    (target / "index.html").write_text(page)
    # Prune only known generated names; do not remove unrelated authored files.
    removed = []
    for path in target.rglob("*"):
        if not path.is_file():
            continue
        name = path.relative_to(target).as_posix()
        generated = re.fullmatch(r"index\.[a-f0-9]{12}(?:\.engine)?\.(?:pck|wasm(?:\.gz)?|js|audio(?:\.position)?\.worklet\.js)", name) or re.fullmatch(r"chunks/[a-f0-9]{64}\.gz", name)
        if name not in names and generated:
            path.unlink()
            removed.append(name)
    if any(p.is_file() and p.stat().st_size > 25 * 1048576 for p in target.rglob("*")):
        raise ValueError("Unrelated oversized file remains in the Site directory")
    published_info = dict(info, transport="verified-worker-chunks", raw_runtime_files=False)
    (target / "build-info.json").write_text(json.dumps(published_info) + "\n")
    report = {"build_id": info["build_id"], "transport": published_info["transport"],
              "virtual_resources": sorted(virtual), "files": len(names),
              "bytes": sum((target / name).stat().st_size for name in names),
              "largest_file_bytes": max((target / name).stat().st_size for name in names),
              "removed_generated_files": len(removed), "target": str(target)}
    (target / "site-build.json").write_text(json.dumps(report, indent=2) + "\n")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan-only", action="store_true")
    parser.add_argument("--skip-import", action="store_true", help="Use an already completed, single-writer editor import")
    parser.add_argument("--output", type=Path, default=ROOT / "build/workbench/web")
    parser.add_argument("--max-pack-mib", type=float, default=128)
    parser.add_argument("--site-copy", type=Path, help="Copy the verified split transport to a Site public/play directory")
    parser.add_argument("--site-copy-only", action="store_true", help="Publish the already verified --output without another Godot export")
    args = parser.parse_args()
    output = args.output.resolve()
    if args.site_copy_only:
        if args.site_copy is None:
            parser.error("--site-copy-only requires --site-copy")
        print(json.dumps(site_copy(output, args.site_copy)))
        return
    output.mkdir(parents=True, exist_ok=True)
    work = ROOT / "build/workbench"
    run([sys.executable, "tools/world/build.py"], work / "logs/world.log")
    # tools/build.py and tools/world/build.py intentionally have separate
    # responsibilities and the same module basename; isolate their imports.
    run([sys.executable, "-c", "import json,sys; from pathlib import Path; "
         "sys.path.insert(0,'tools/world'); from workbench_seed import preview_catalog; "
         "Path('build/workbench/preview-world.json').write_text(json.dumps(preview_catalog(Path.cwd()),ensure_ascii=False,separators=(',',':'))+'\\n')"],
        work / "logs/preview-catalog.log")
    plan = manifest()
    (work / "export-closure.json").write_text(json.dumps(plan, indent=2) + "\n")
    if args.plan_only:
        print(json.dumps({"files": len(plan["files"]), "source_bytes": sum(r["bytes"] for r in plan["files"]),
                          "rooms": plan["rooms"], "dynamic_prefixes": plan["dynamic_prefixes"]}))
        return
    from godot_identity import verified_engine, verify_templates
    from build import prepare_web_playtest
    identity = verified_engine()
    verify_templates()
    engine = ["bash", "tools/godot.sh", "--headless", "--path", str(ROOT)]
    if not args.skip_import:
        run(engine + ["--editor", "--quit"], work / "logs/import.log", 600)
    presets = ROOT / "export_presets.cfg"
    original = presets.read_text()
    try:
        presets.write_text(configured_preset(original, plan))
        run(engine + ["--export-debug", NAME, str(output / "index.html")], work / "logs/export.log", 600)
    finally:
        presets.write_text(original)
    pack = output / "index.pck"
    checked = verify_pack(pack, plan)
    if pack.stat().st_size > args.max_pack_mib * 1048576:
        raise ValueError(f"Workbench PCK {pack.stat().st_size} bytes exceeds the {args.max_pack_mib:g} MiB budget")
    native_probe = probe_pack(pack, work / "logs/pack-probe.log")
    files = prepare_web_playtest(output / "index.html", {k: v for k, v in identity.items() if k != "binary"})
    info = json.loads((output / "build-info.json").read_text())
    info.update(workbench=True, source_tree_sha256=plan["source_tree_sha256"], content_version=plan["content_version"])
    (output / "build-info.json").write_text(json.dumps(info) + "\n")
    report = {"schema": 1, "preset": NAME, "entry": "res://" + ENTRY, "engine": info["godot_toolchain"],
              "pack_bytes": info["pack_bytes"], "download_bytes": info["download_bytes"],
              "source_tree_sha256": plan["source_tree_sha256"], "content_version": plan["content_version"],
              "closure": checked, "native_pack_probe": native_probe, "web_device_execution": "unverified", "artifacts": len(files)}
    workbench_report = output / "workbench-build.json"
    workbench_report.write_text(json.dumps(report, indent=2) + "\n")
    files.append(workbench_report)
    (output / "build_report.json").write_text(json.dumps({"platform": "web", "preset": NAME,
        "export_exit_code": 0, "godot_toolchain": report["engine"], "device_execution": "unverified",
        "native_pack_probe": native_probe, "artifacts": [{"path": str(p.relative_to(ROOT)) if p.is_relative_to(ROOT) else str(p),
        "bytes": p.stat().st_size, "sha256": sha(p)} for p in files]}, indent=2) + "\n")
    if args.site_copy is not None:
        report["site"] = site_copy(output, args.site_copy)
    print(json.dumps(report))


if __name__ == "__main__":
    main()
