"""Test a candidate in an isolated project before changing the formal recipe."""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
import tarfile
from pathlib import Path

import harness
import level_formal
from run_tests import REPO

OLD = ' {"id":"thorn_gap","modules":["plains_thorn_cells","plains_gear_brook"],"actions":"safe_cell_hop>land>observe_gear>second_hop","pressure":"safe_footprint","decision":"choose_takeoff"},'
NEW = ' {"id":"thorn_gap","modules":["plains_thorn_bridge","plains_low_arch"],"actions":"held_gap_jump>land_recover>read_low_ceiling>tap_jump>release>land","pressure":"gap_commitment_then_headroom","decision":"change_jump_hold_after_landing"},'
OLD_VERSION = 'const VERSION := "plains-region-v8"'
NEW_VERSION = 'const VERSION := "plains-region-v9"'
OLD_JOIN = '\t\t_add_inline(m, e.id + "_join", Vector2(x, a.y), _floor_definition("region_connection", Rect2(0,18,b.x-HALF-x,32)))'
NEW_JOIN = '\t\tvar remaining := b.x - HALF - x\n\t\tvar overlap := 0.0\n\t\t# This overlap only repairs the certified bridge/arch join into the solid arch floor only; preserve the receiving one-way floor.\n\t\tif remaining == 20.0 and recipe.id == "thorn_gap" and ids == ["plains_thorn_bridge", "plains_low_arch"] and a.y == b.y:\n\t\t\tvar arch := definition(m.nodes[int(e.modules[-1])])\n\t\t\tvar receiving_nodes: Array = m.nodes.filter(func(n: Dictionary): return n.id == e.b)\n\t\t\tif receiving_nodes.size() == 1:\n\t\t\t\tvar receiving := definition(receiving_nodes[0])\n\t\t\t\tvar arch_floor := arch.platforms[0]\n\t\t\t\tvar receiving_floor := receiving.platforms[0]\n\t\t\t\tif not arch.one_way_platform_indices.has(0) and arch_floor == Rect2(0,300,640,32) and receiving_floor == Rect2(-HALF,18,HALF*2,32):\n\t\t\t\t\toverlap = 20.0\n\t\tvar join := _floor_definition("region_connection", Rect2(-overlap,18,remaining + overlap,32))\n\t\tif overlap > 0.0:\n\t\t\tjoin.anchors.assign([Vector2(-4,0), Vector2(4,0)])\n\t\t\tjoin.entry_port = _port("entry", join.anchors[0])\n\t\t\tjoin.exit_port = _port("exit", join.anchors[1])\n\t\t_add_inline(m, e.id + "_join", Vector2(x, a.y), join)\n\t\tif overlap > 0.0: m.nodes[-1].geometry.standing_margin = 16.0'
OLD_HYDRATE = '\td.anchors.assign([Vector2(floor_rect.position.x+20,floor_rect.position.y-18),Vector2(floor_rect.end.x-20,floor_rect.position.y-18)])'
NEW_HYDRATE = '\tvar standing_margin := float(g.get("standing_margin", 20.0))\n\td.anchors.assign([Vector2(floor_rect.position.x+standing_margin,floor_rect.position.y-18),Vector2(floor_rect.end.x-standing_margin,floor_rect.position.y-18)])'


def restore_frozen_assets(repo, project, basis, manifest):
    """Reuse identical current assets; restore changed bytes from portable Git blobs."""
    restored = []
    for relative, expected in manifest["asset_blobs"].items():
        if (not re.fullmatch(r"[0-9a-f]{40}", expected) or
                Path(relative).is_absolute() or ".." in Path(relative).parts):
            raise RuntimeError("Unsafe frozen v9 asset identity: " + relative)
        current = repo / relative
        data = current.read_bytes() if current.is_file() else None
        def identity(raw):
            return hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
        if data is None or identity(data) != expected:
            retained = basis / "asset_blobs" / expected
            if not retained.is_file():
                raise RuntimeError("Frozen v9 asset differs and exact portable Git blob is missing: " + relative + " (" + expected + ")")
            data = retained.read_bytes()
            restored.append({"path": relative, "git_blob": expected})
        if identity(data) != expected:
            raise RuntimeError("Frozen v9 asset mismatch: " + relative)
        destination = project / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
    return {"asset_count": len(manifest["asset_blobs"]), "reused_count": len(manifest["asset_blobs"]) - len(restored), "restored": restored}


def frozen_project(folder):
    """Rebuild exact v9 consumer bytes; only matching asset bytes may be shared."""
    basis = REPO / "docs/evidence/plains_redesign/frozen_v9"
    manifest = json.loads((basis / "manifest.json").read_text())
    archive = basis / "source.tar.gz"
    if hashlib.sha256(archive.read_bytes()).hexdigest() != manifest["archive_sha256"]:
        raise RuntimeError("Frozen v9 source archive corrupt")
    folder.mkdir(parents=True, exist_ok=True)
    (folder / ".gdignore").touch()
    project = folder / "project"
    project.mkdir()
    with tarfile.open(archive, "r:gz") as bundle:
        names = [member.name for member in bundle.getmembers() if member.isfile()]
        if set(names) != set(manifest["members"]):
            raise RuntimeError("Frozen v9 archive members mismatch")
        for member in bundle.getmembers():
            if member.isdir(): continue
            if not member.isfile() or Path(member.name).is_absolute() or ".." in Path(member.name).parts:
                raise RuntimeError("Unsafe frozen v9 archive")
            destination = project / member.name
            destination.parent.mkdir(parents=True, exist_ok=True)
            data = bundle.extractfile(member).read()
            if hashlib.sha256(data).hexdigest() != manifest["members"][member.name]:
                raise RuntimeError("Frozen v9 member fingerprint mismatch")
            destination.write_bytes(data)
    assets = restore_frozen_assets(REPO, project, basis, manifest)
    (folder / "asset_restoration.json").write_text(json.dumps(assets, indent=2) + "\n")
    # Copy imported resources for runtime dependencies; source and raw asset identities
    # were checked above, importer revalidates these against the exact old project.
    if (REPO / ".godot").is_dir():
        shutil.copytree(REPO / ".godot", project / ".godot", ignore=shutil.ignore_patterns("editor", "shader_cache"))
    return project, manifest


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate", action="store_true", help="isolated candidate; repository recipe stays unchanged")
    args = parser.parse_args()
    base = REPO / "build/level_autonomy/action_golden"
    base.mkdir(parents=True, exist_ok=True)
    folder = Path(tempfile.mkdtemp(prefix="run_", dir=base))
    before = level_formal.source_files()
    recipe = REPO / "scripts/generation/plains_route_recipes.gd"
    source = recipe.read_text()
    generator = REPO / "scripts/generation/plains_region_generator.gd"
    generator_source = generator.read_text()
    historical = REPO / "docs/evidence/level_autonomy/action_baseline_capture.json"
    if not historical.is_file():
        historical = REPO / "build/level_formal/baseline_80_v2/seed_02/map_2/deep/capture.json"
    if not historical.is_file():
        raise RuntimeError("Retained actual baseline capture is required for version rejection")
    report = {"status": "failed", "scope": "candidate isolation" if args.candidate else "current formal recipe", "source_before": before, "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(), "recipe_before": OLD, "recipe_after": NEW, "runs": []}
    report["historical_capture"] = {"path": str(historical.relative_to(REPO)), "sha256": hashlib.sha256(historical.read_bytes()).hexdigest()}
    project = REPO
    frozen = "plains-region-v10" in generator_source
    try:
        if frozen and not args.candidate:
            project, frozen_basis = frozen_project(folder / "frozen_v9")
            report["scope"] = "unchanged exact v9 layout-specific regression; current v10 separately tested by plains-redesign-spatial"
            report["frozen_basis"] = frozen_basis
        if args.candidate:
            if source.count(OLD) != 1:
                raise RuntimeError("Candidate must start from the exact original thorn_gap recipe")
            project = folder / "project"
            project.mkdir()
            for name in ("scripts", "scenes", "resources", "assets", "shaders", "config", "tests", ".godot"):
                shutil.copytree(REPO / name, project / name)
            shutil.copy2(REPO / "project.godot", project / "project.godot")
            (project / "scripts/generation/plains_route_recipes.gd").write_text(source.replace(OLD, NEW))
            if generator_source.count(OLD_VERSION) != 1:
                raise RuntimeError("Candidate must start from the exact original generation version")
            if generator_source.count(OLD_JOIN) != 1 or generator_source.count(OLD_HYDRATE) != 1:
                raise RuntimeError("Candidate must start from the original horizontal join")
            (project / "scripts/generation/plains_region_generator.gd").write_text(generator_source.replace(OLD_VERSION, NEW_VERSION).replace(OLD_JOIN, NEW_JOIN).replace(OLD_HYDRATE, NEW_HYDRATE))
        elif not frozen and source.count(NEW) != 1:
            raise RuntimeError("Formal recipe must contain the exact golden candidate")
        command = ["bash", str(REPO / "tools/godot.sh"), "--headless", "--path", str(project), "--editor", "--quit"]
        imported = harness.run_check({"argv": command, "timeout_seconds": 120, "success_pattern": r"^Godot Engine v4\.7\.2\.stable\.official"}, folder / "import.log", REPO)
        if imported["status"] != "passed":
            raise RuntimeError("Candidate import failed")
        project_sources = {}
        for relative in before:
            path = project / relative
            if path.is_file():
                project_sources[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
        report["tested_source_files"] = project_sources
        for negative in (False, True):
            name = "deleted_bank_negative" if negative else "positive"
            output = folder / (name + ".json")
            log = folder / (name + ".log")
            command = ["bash", str(REPO / "tools/godot.sh"), "--headless", "--fixed-fps", "60", "--path", str(project), "--script", "tests/plains_action_golden_runner.gd", "--", "--output=" + str(output), "--historical-capture=" + str(historical)]
            if negative:
                command.append("--delete-far-bank")
            process = harness.run_check({"argv": command, "timeout_seconds": 180, "success_pattern": r"^PLAINS ACTION GOLDEN: [1-9]\d* assertions, 0 failures$"}, log, REPO)
            text = log.read_text()
            data = json.loads(output.read_text()) if output.is_file() else {}
            if negative:
                valid = process["exit_code"] == 1 and data.get("broken_bank") is True and data.get("failures", 0) > 0 and len(data.get("observations", [])) == 1 and data["observations"][0]["legs"][0]["reached"] is False and "FAIL: negative deletes" not in text and data["observations"][0]["final"]["tick"] > 10
            else:
                valid = process["status"] == "passed" and data.get("failures") == 0 and len(data.get("observations", [])) == 4 and all(o["initial"]["energy"] == (0.0 if o["low_initial_energy"] else o["initial"]["energy_capacity"]) and len(o["legs"]) == 2 and all(l["reached"] for l in o["legs"]) for o in data["observations"])
            if re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script|ObjectDB.*leaked|resources? still in use at exit", text):
                valid = False
            report["runs"].append({"command": command, "process": process, "expected_exit_code": 1 if negative else 0, "expected_rejection": negative, "validated": bool(valid), "output": str(output.relative_to(REPO)), "output_sha256": hashlib.sha256(output.read_bytes()).hexdigest() if output.is_file() else None, "log": str(log.relative_to(REPO)), "log_sha256": hashlib.sha256(log.read_bytes()).hexdigest()})
            if not valid:
                raise RuntimeError(f"{name}: real Motor proof failed; retained {folder}")
            print(f"PLAINS ACTION {name}: validated, exit={process['exit_code']}", flush=True)
        report["source_after"] = level_formal.source_files()
        if before != report["source_after"]:
            raise RuntimeError("Repository source changed during golden")
        report["status"] = "passed"
        return 0
    finally:
        (folder / "receipt.json").write_text(json.dumps(report, indent=2) + "\n")
        print("PLAINS ACTION RECEIPT: " + str((folder / "receipt.json").relative_to(REPO)), flush=True)


if __name__ == "__main__":
    raise SystemExit(main())
