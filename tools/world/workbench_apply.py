#!/usr/bin/env python3
"""Prepare or atomically apply an accepted mobile workbench package.

Godot's WorldRoomDraft is the only scene serializer. This tool updates the
existing world inputs, compiles an isolated candidate, and publishes the exact
verified bytes only when --write is explicitly supplied.
"""
from __future__ import annotations

import argparse
import copy
import json
import math
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from build import build
from workbench_seed import CONFIG_FILES, ROOT, digest, load, make_seed, walk_rows
from workbench_scope import SCOPE_PATH, editable_room_ids, preview_navigation_geometry

SCHEMA = "gunman-workbench-change/v1"
CONNECTION_FIELDS = ("a", "b", "requires", "condition_text", "kind", "a_section", "b_section", "direction")
REWARD_TEXT_FIELDS = {"challenge": "challenge", "discovery": "approach_cue", "return_route": "return_path"}


class ImportRejected(ValueError):
    pass


class RollbackFailed(RuntimeError):
    """The original source bytes could not all be restored; never report success."""


def reject(message):
    raise ImportRejected(message)


def finite(value):
    return type(value) in (int, float) and math.isfinite(value) and abs(value) <= 1000000


def point(value):
    return isinstance(value, list) and len(value) == 2 and all(map(finite, value))


def rectangle(value):
    return isinstance(value, list) and len(value) == 4 and all(map(finite, value)) and value[2] > 0 and value[3] > 0


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def verify_baseline(root: Path, package: dict, construction: dict):
    if not isinstance(package, dict) or package.get("schema") != SCHEMA or not isinstance(package.get("rooms"), dict):
        reject("Unsupported workbench package schema")
    if type(package.get("revision")) is not int or package["revision"] < 0:
        reject("Invalid draft revision")
    baseline = package.get("baseline", "")
    if not re.fullmatch(r"[a-f0-9]{40}", baseline):
        reject("Missing source baseline commit")
    result = subprocess.run(["git", "merge-base", "--is-ancestor", baseline, "HEAD"], cwd=root, capture_output=True, timeout=30)
    if result.returncode:
        reject("Package baseline is not an ancestor of the checked-out work; do not silently rebase it")
    hashes = package.get("source_hashes", {})
    if not isinstance(hashes, dict):
        reject("Source hashes must be an object")
    required = {"config/world/" + name for name in CONFIG_FILES}
    scope = editable_room_ids(root, construction)
    if (root / SCOPE_PATH).exists():
        required.add(SCOPE_PATH)
    bindings = {r["room_id"]: r["scene_ref"].removeprefix("res://") for r in construction["rooms"]}
    for room_id, draft in package["rooms"].items():
        if room_id not in bindings or room_id not in scope:
            reject("Unknown or out-of-scope room: " + room_id)
        required.add(bindings[room_id])
        if not isinstance(draft, dict) or draft.get("schema") != 1 or draft.get("room_id") != room_id:
            reject(room_id + ": draft identity/schema does not match its room binding")
        if draft.get("base_content_version") != package.get("base_content_version") or draft.get("revision") != package["revision"]:
            reject(room_id + ": draft revision/content version does not match its package")
        if draft.get("source_hash") != hashes.get(bindings[room_id]):
            reject(room_id + ": draft scene hash differs from its source binding")
    if not required.issubset(hashes):
        reject("Package omits required source hashes: " + ", ".join(sorted(required - hashes.keys())))
    allowed = required | set(bindings.values()) | {"config/player_tuning.json"}
    for relative, expected in hashes.items():
        if relative not in allowed or not re.fullmatch(r"[a-f0-9]{64}", str(expected)):
            reject("Unknown source hash binding: " + relative)
        path = root / relative
        if not path.is_file() or digest(path) != expected:
            reject("Source changed since this draft: " + relative)
    runtime = load(root / "build/world/runtime.json")
    if package.get("base_content_version") != runtime.get("content_version"):
        reject("Compiled content version changed; export a fresh workbench baseline")
    return bindings


def update_geometry(construction: dict, package: dict, base_seed: dict):
    rooms = {r["room_id"]: r for r in construction["rooms"]}
    pairs = {p["edge_id"]: p for p in construction["door_pairs"]}
    for room_id, draft in package["rooms"].items():
        geometry = draft.get("geometry")
        if not geometry:
            continue
        row = rooms[room_id]
        bounds, spaces = geometry.get("bounds"), geometry.get("space_rects")
        if not rectangle(bounds) or bounds[:2] != [0, 0] or not isinstance(spaces, list) or not spaces or not all(map(rectangle, spaces)):
            reject(room_id + ": invalid physical room extent/space rectangles")
        # An interior-only edit must preserve authored recovery entries. Some
        # service rooms intentionally have no challenge recovery for quiet doors.
        # Only a changed geometry needs the explicit landing/recovery rewrite.
        baseline_room = base_seed["rooms"][room_id]
        if all(geometry.get(key) == baseline_room.get(key)
               for key in ("bounds", "space_rects", "doors", "map_position")):
            continue
        row["extent"] = copy.deepcopy(bounds[2:])
        row["space_rects"] = copy.deepcopy(spaces)
        old_doors = {d["id"]: d for d in row["doors"]}
        baseline_doors = {d["id"]: d for d in base_seed["rooms"][room_id]["doors"]}
        proposed = geometry.get("doors")
        if not isinstance(proposed, list):
            reject(room_id + ": explicit doors are required with geometry")
        if {d.get("id") for d in proposed} != set(old_doors) or len(proposed) != len(old_doors):
            reject(room_id + ": door identities must be preserved; topology changes require complete source contracts")
        ids = set()
        next_doors, spawns, recovery = [], [], []
        old_spawns = {s["entry_door"]: s for s in row["entry_spawns"]}
        old_recovery = {a["approach_door"]: a for a in row["terrain_failure"]["challenge_entries"]}
        for door in proposed:
            door_id = door.get("id", "")
            if not isinstance(door_id, str) or not door_id.endswith(":" + room_id) or door_id in ids:
                reject(room_id + ": invalid or duplicate door identity")
            ids.add(door_id)
            for key, value in door.items():
                if key not in ("position_candidate", "landing_contract", "direction") and value != baseline_doors[door_id].get(key):
                    reject(door_id + ": " + key + " belongs to the connection/compiler, not door placement")
            position, landing = door.get("position_candidate", {}), door.get("landing_contract", {})
            if not point(position.get("local_world_units")) or not point(landing.get("entry_position_world_units")) or not point(landing.get("safe_standing_position_world_units")):
                reject(door_id + ": explicit doorway, entry and safe standing positions are required")
            if not rectangle(landing.get("platform_candidate_rect_world_units")) or not isinstance(landing.get("id"), str):
                reject(door_id + ": explicit landing platform is required")
            # No coordinate guesses are made here. These are the values seen in preview.
            authored = copy.deepcopy(old_doors.get(door_id, {}))
            authored.update(id=door_id, position_candidate=copy.deepcopy(position), landing_contract=copy.deepcopy(landing))
            next_doors.append(authored)
            spawn = copy.deepcopy(old_spawns.get(door_id, {}))
            spawn.update(id="spawn:" + door_id, entry_door=door_id, section=landing.get("section", door.get("section", "main")),
                         position_candidate_world_units=copy.deepcopy(landing["entry_position_world_units"]),
                         eventual_standing_position_world_units=copy.deepcopy(landing["safe_standing_position_world_units"]),
                         landing_contract_ref=landing["id"], fake_grounded_reset_forbidden=True)
            spawns.append(spawn)
            if door_id in old_recovery:
                anchor = copy.deepcopy(old_recovery[door_id])
                anchor["position_candidate_world_units"] = copy.deepcopy(landing["safe_standing_position_world_units"])
                recovery.append(anchor)
            else:
                reject(door_id + ": new door needs an explicit recovery contract; endpoint rewiring cannot infer one")
            edge_id = door.get("edge_id", door_id.rsplit(":", 1)[0])
            if edge_id not in pairs or door.get("direction") not in ("left", "right", "up", "down"):
                reject(door_id + ": missing paired-door side")
            pairs[edge_id]["construction_sides"][room_id] = door["direction"]
        row["doors"], row["entry_spawns"] = next_doors, spawns
        row["terrain_failure"]["challenge_entries"] = recovery
        # Camera zones and links remain authored by the main game; geometry edits
        # must not recreate the retired per-space camera system.



def update_connections(world: dict, construction: dict, package: dict, review_room_ids=None):
    sources = {c["id"]: c for c in world["connections"]}
    rows = package.get("connections")
    if not isinstance(rows, list):
        reject("Connection view is missing")
    scope = set(review_room_ids) if review_room_ids is not None else {
        room["room_id"] for room in construction["rooms"] if room["room_id"].startswith("P-R")}
    expected = {c["id"] for c in sources.values() if c["a"] in scope or c["b"] in scope}
    if {c.get("id") for c in rows} != expected or len(rows) != len(expected):
        reject("Connections must preserve source identities; topology expansion needs an explicit source edit")
    for proposed in rows:
        row = sources[proposed["id"]]
        if proposed.get("a") == proposed.get("b"):
            reject(row["id"] + ": cannot link a room to itself")
        for key in CONNECTION_FIELDS:
            if key in proposed and proposed[key] != row.get(key):
                if key in ("a", "b"):
                    reject(row["id"] + ": endpoint change needs new door/recovery and internal-route contracts; this importer does not guess them")
                row[key] = copy.deepcopy(proposed[key])
                if key == "requires":
                    row["effective_door_requires"] = copy.deepcopy(proposed[key])


def verify_map_positions(contracts: dict, package: dict, review_room_ids=None):
    """Map coordinates are consequences of door seams, never another editable layout."""
    scope = set(review_room_ids) if review_room_ids is not None else {
        room["room_id"] for room in contracts["rooms"] if room["room_id"].startswith("P-R")}
    rooms = {r["room_id"]: r for r in contracts["rooms"] if r["room_id"] in scope}
    geometry = preview_navigation_geometry(rooms, contracts["initial_state"]["room"])
    for room_id, draft in package["rooms"].items():
        declared = draft.get("geometry", {}).get("map_position")
        if not point(declared) or any(abs(a - b) > 0.001 for a, b in zip(declared, geometry[room_id]["origin"])):
            reject(room_id + ": map_position must equal the layout derived from the submitted paired doors")


def set_room_binding(record: dict, room_id: str, section_id: str, room: dict):
    record["room_id"] = room_id
    if "physical_room" in record: record["physical_room"] = room_id
    if "production_room_id" in record: record["production_room_id"] = room_id
    if "section_id" in record: record["section_id"] = section_id
    if "room_name" in record: record["room_name"] = room["name"]
    if "region" in record: record["region"] = room_id.split("-")[0]
    if "node" in record: record["node"] = room["parent_anchor"]
    if "map_anchor" in record:
        if record.get("position_scope") != "illustration_anchor_not_Godot_coordinates":
            reject("Unsupported source map anchor ownership")
        record["map_anchor"] = copy.deepcopy(room["map_centre"])
    if isinstance(record.get("access_binding"), dict):
        record["access_binding"].update(room_id=room_id, section_id=section_id)


def move_index_value(rows, room_key, list_key, value, source_room, target_room):
    """Move an existing identity in source indexes without inventing new rewards."""
    source = next((r for r in rows if r[room_key] == source_room), None)
    target = next((r for r in rows if r[room_key] == target_room), None)
    if source is None or target is None:
        reject("Missing source index room for " + value)
    if value not in source.get(list_key, []):
        return
    source[list_key] = [x for x in source[list_key] if x != value]
    if value not in target.setdefault(list_key, []):
        target[list_key].append(value)


def update_rewards(world: dict, design: dict, package: dict, base_seed: dict):
    baseline = {r["id"]: r for r in base_seed["rewards"]}
    requested = package.get("rewards", [])
    if {r.get("id") for r in requested} != set(baseline) or len(requested) != len(baseline):
        reject("Reward identities must remain unique and preserve the existing budget")
    catalog = {r["reward_id"]: r for r in design["acquisition_contracts"]}
    source_rooms = {r["id"]: r for r in world["rooms"]}
    final_rooms = copy.deepcopy(base_seed["rooms"])
    for room_id, draft in package["rooms"].items():
        final_rooms[room_id].update(properties=draft["properties"], nodes=draft["nodes"])
    for proposed in requested:
        old = baseline[proposed["id"]]
        reward_id = old["id"]
        for field in ("name", "category", "source_path", "action_id", "source_channel", "requires"):
            if field in proposed and proposed[field] != old.get(field):
                reject(reward_id + ": acquisition identity/eligibility cannot be changed as a placement edit")
        target, section = proposed.get("room_id"), proposed.get("section_id", "main")
        if target not in final_rooms or not isinstance(section, str):
            reject(reward_id + ": target room/section is invalid")
        if section not in {s["id"] for s in source_rooms[target].get("sections", [])}:
            reject(reward_id + ": target section is not a canonical room section")
        acquisition = catalog.get(reward_id)
        if target != old["room_id"] or section != old["section_id"]:
            if not old.get("relocatable"):
                reject(reward_id + ": " + old.get("relocation_reason", "Only a unique authored map pickup can be relocated"))
            action_id = old["action_id"]
            hosts = [(rid, n) for rid, room in final_rooms.items() for n in room.get("nodes", [])
                     if n.get("properties", {}).get("action_id") == action_id]
            if len(hosts) != 1 or hosts[0][0] != target or hosts[0][1].get("type") != "WorldRoomInteraction":
                reject(reward_id + ": move the unique physical interaction host in the same patch")
            host = hosts[0][1]
            if host["properties"].get("section_id", "main") != section:
                reject(reward_id + ": host and acquisition section differ")
            for _, record in walk_rows(world):
                if record.get("reward_id", record.get("id")) == reward_id and "room_id" in record:
                    set_room_binding(record, target, section, source_rooms[target])
            if target != old["room_id"]:
                move_index_value(list(source_rooms.values()), "id", "reward_ids", reward_id, old["room_id"], target)
                move_index_value(design["room_index"], "room_id", "source_ids", reward_id, old["room_id"], target)
                move_index_value(design["room_index"], "room_id", "source_cue_ids", reward_id, old["room_id"], target)
                move_index_value(design["room_index"], "room_id", "world_action_refs", action_id, old["room_id"], target)
                for key in ("source_ids", "source_cue_ids"):
                    views = [{"room_id": r["id"], key: r.get("collection_design_refs", {}).get(key, [])}
                             for r in source_rooms.values()]
                    move_index_value(views, "room_id", key, reward_id, old["room_id"], target)
                    for rid in (old["room_id"], target):
                        source_rooms[rid].setdefault("collection_design_refs", {})[key] = next(r[key] for r in views if r["room_id"] == rid)
            if acquisition:
                set_room_binding(acquisition, target, section, source_rooms[target])
                acquisition["local_route_refs"] = []
                if isinstance(acquisition.get("cue_room_ids"), list):
                    acquisition["cue_room_ids"] = [target if x == old["room_id"] else x for x in acquisition["cue_room_ids"]]
        if acquisition:
            for visible, owned in REWARD_TEXT_FIELDS.items():
                if visible in proposed:
                    if not isinstance(proposed[visible], str) or len(proposed[visible]) > 8000:
                        reject(reward_id + ": invalid design text")
                    return_contract = acquisition.get("return_access_contract", {})
                    if visible == "return_route" and return_contract.get("physical_design") == acquisition.get("return_path"):
                        return_contract["physical_design"] = proposed[visible]
                    acquisition[owned] = proposed[visible]
        if old.get("host_path"):
            hosts = [(rid, n) for rid, room in final_rooms.items() for n in room.get("nodes", [])
                     if n.get("properties", {}).get("action_id") == old["action_id"]]
            if (len(hosts) != 1 or hosts[0][0] != target or hosts[0][1].get("type") != old["host_type"]
                    or hosts[0][1]["properties"].get("section_id", "main") != section
                    or hosts[0][1]["properties"].get("position") != proposed.get("position")):
                reject(reward_id + ": reward binding/position must match its unique actual scene host")
        elif proposed.get("position") != old.get("position"):
            reject(reward_id + ": this source has no independently editable scene position")


def run_codec(root: Path, output: Path, *, package=None, godot=None):
    command = ["bash", str(root / "tools/godot.sh")]
    environment = os.environ.copy()
    if godot:
        environment["GODOT_BIN"] = str(godot.resolve())
    command += ["--headless", "--path", str(root), "--script", "tools/world/workbench_scene_io.gd", "--"]
    if package is None:
        command += ["--export=" + str(output)]
    else:
        command += ["--apply=" + str(package), "--output-dir=" + str(output)]
    result = subprocess.run(command, cwd=root, env=environment, text=True, capture_output=True, timeout=180)
    if result.returncode or "SCRIPT ERROR:" in result.stderr or "ERROR:" in result.stderr:
        reject("Godot scene adapter failed: " + (result.stdout + result.stderr)[-8000:])


def prepare(root: Path, package: dict, output: Path, *, godot=None):
    source = root / "config/world"
    world, construction, design = (load(source / n) for n in ("world.json", "construction.json", "collection_design.json"))
    bindings = verify_baseline(root, package, construction)
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()): reject("Output directory must be empty; preserve previous prepared revisions")
    base_dump = output / "base-scenes.json"
    run_codec(root, base_dump, godot=godot)
    base_seed = make_seed(root, load(base_dump), baseline=package["baseline"])
    if package.get("editor_catalog_hash") and package["editor_catalog_hash"] != base_seed.get("catalog", {}).get("source_hash"):
        reject("Game component definitions changed since this draft; update the workbench game version before importing")
    update_geometry(construction, package, base_seed)
    update_connections(world, construction, package, base_seed["rooms"])
    update_rewards(world, design, package, base_seed)
    stage = output / "candidate"
    shutil.copytree(source, stage / "config/world")
    changed_sources = {}
    for name, value in (("world.json", world), ("construction.json", construction), ("collection_design.json", design)):
        if value != load(source / name):
            write_json(stage / "config/world" / name, value)
            changed_sources["config/world/" + name] = stage / "config/world" / name
    for row in construction["rooms"]:
        if row.get("implemented") or row["room_id"] in package["rooms"]:
            relative = bindings[row["room_id"]]
            destination = stage / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(root / relative, destination)
    ui = root / "game/presentation/ui/world"
    if ui.is_dir(): shutil.copytree(ui, stage / "game/presentation/ui/world")
    draft_file = output / "accepted-drafts.json"
    write_json(draft_file, {"drafts": list(package["rooms"].values())})
    scene_dir = output / "scenes"
    run_codec(root, scene_dir, package=draft_file, godot=godot)
    scene_receipt = load(scene_dir / "receipt.json")
    saved = scene_receipt.get("scenes", [])
    if (len(saved) != len(package["rooms"]) or {r.get("room_id") for r in saved} != set(package["rooms"])
            or any(r.get("roundtrip_verified") is not True for r in saved)):
        reject("Godot did not return an exact verified scene set for the accepted room drafts")
    for row in scene_receipt["scenes"]:
        relative = bindings[row["room_id"]]
        shutil.copyfile(Path(row["candidate"]), stage / relative)
        changed_sources[relative] = stage / relative
    try:
        contracts, runtime = build(stage)
        verify_map_positions(contracts, package, base_seed["rooms"])
    except Exception as error:
        reject("Original world compiler rejected the candidate: " + str(error))
    receipt = {
        "schema": 1, "status": "prepared", "baseline": package["baseline"],
        "revision": package["revision"], "base_content_version": package["base_content_version"],
        "candidate_content_version": runtime["content_version"],
        "source_hashes": package["source_hashes"],
        "changes": [{"path": p, "candidate": str(file), "sha256": digest(file)} for p, file in sorted(changed_sources.items())],
        "scenes": scene_receipt["scenes"],
        "verification": {"same_godot_codec_roundtrip": all(r.get("roundtrip_verified") for r in scene_receipt["scenes"]),
                         "original_world_compiler": True, "actual_controller_playtest": False},
    }
    write_json(output / "receipt.json", receipt)
    return receipt


def publish(root: Path, package: dict, receipt: dict):
    verify_baseline(root, package, load(root / "config/world/construction.json"))
    backups = {}
    try:
        for change in receipt["changes"]:
            destination, candidate = root / change["path"], Path(change["candidate"])
            if digest(candidate) != change["sha256"]: reject("Prepared candidate changed: " + change["path"])
            backups[destination] = destination.read_bytes()
            temporary = destination.with_name(destination.name + ".workbench-tmp")
            temporary.write_bytes(candidate.read_bytes())
            os.replace(temporary, destination)
        _, actual = build(root)
        if actual["content_version"] != receipt["candidate_content_version"]:
            reject("Published content differs from the prepared candidate")
    except BaseException as error:
        failures = []
        for destination, original in backups.items():
            try:
                temporary = destination.with_name(destination.name + ".workbench-rollback")
                temporary.write_bytes(original)
                os.replace(temporary, destination)
            except OSError as failure:
                failures.append(str(destination) + ": " + str(failure))
        if failures:
            raise RollbackFailed("Source rollback incomplete: " + "; ".join(failures)) from error
        try:
            build(root)
        except Exception as failure:
            reject("Original source bytes restored, but derived build must be regenerated: " + str(failure))
        raise
    receipt["status"] = "applied"
    receipt["applied_content_version"] = actual["content_version"]
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--godot", type=Path, help="Explicit locked engine binary; tools/godot.sh is the default")
    parser.add_argument("--write", action="store_true", help="Apply only after successful source/codec/compiler verification")
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        package = load(args.package)
        (root / "build").mkdir(exist_ok=True)
        output = args.output_dir.resolve() if args.output_dir else Path(tempfile.mkdtemp(prefix="workbench-", dir=root / "build"))
        receipt = prepare(root, package, output, godot=args.godot)
        if args.write:
            receipt = publish(root, package, receipt)
            write_json(output / "receipt.json", receipt)
        print(json.dumps({"status": receipt["status"], "receipt": str(output / "receipt.json"),
                          "changed_files": len(receipt["changes"]), "content_version": receipt["candidate_content_version"],
                          "actual_controller_playtest": False}, ensure_ascii=False))
        return 0
    except RollbackFailed as error:
        print(json.dumps({"status": "rollback_failed", "error": str(error), "formal_sources_changed": True}, ensure_ascii=False))
        return 2
    except (ImportRejected, OSError, KeyError, ValueError, subprocess.SubprocessError) as error:
        print(json.dumps({"status": "rejected", "error": str(error), "formal_sources_changed": False}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
