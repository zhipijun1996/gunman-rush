#!/usr/bin/env python3
"""Extract a mobile editing view from the existing world sources and Godot codec.

This view is derived data. Authoring changes return to the original scenes and
config/world files through workbench_apply.py, not through a second world format.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
from pathlib import Path

from workbench_catalog import make_catalog
from workbench_review import make_review_context
from workbench_scope import SCOPE_PATH, editable_room_ids, preview_navigation_geometry

ROOT = Path(__file__).resolve().parents[2]
CONFIG_FILES = (
    "world.json", "construction.json", "collections.json", "collection_design.json",
    "player.json", "demo_services.json", "ui_texts.json",
)


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pointer_escape(value: str) -> str:
    return value.replace("~", "~0").replace("/", "~1")


def walk_rows(value, path=""):
    """Yield actual object locations, including nested source catalogs."""
    if isinstance(value, dict):
        yield path, value
        for key, item in value.items():
            if isinstance(item, (list, dict)):
                yield from walk_rows(item, path + "/" + pointer_escape(str(key)))
    elif isinstance(value, list):
        for index, item in enumerate(value):
            if isinstance(item, (list, dict)):
                yield from walk_rows(item, path + "/" + str(index))


def source_record(world, reward_id: str):
    """Prefer an existing source catalog entry, not an action or a display label."""
    roots = ["weapon_major_rewards", "important_markers", "clock_repairs", "collectibles", "shop_inventory"]
    for name in roots:
        for path, row in walk_rows(world.get(name, {}), "/" + name):
            if row.get("reward_id", row.get("id")) == reward_id and "room_id" in row:
                return path, row
    return None, None


def host_for_action(room: dict, action_id: str):
    matches = []
    for index, node in enumerate(room.get("nodes", [])):
        props = node.get("properties", {})
        if props.get("action_id") == action_id and node.get("type") in ("WorldRoomInteraction", "WorldReturnLatch"):
            matches.append((index, node))
    if len(matches) != 1:
        return None
    index, node = matches[0]
    point = node["properties"].get("position")
    if not isinstance(point, list) or len(point) != 2:
        return None
    return {
        "position": copy.deepcopy(point),
        "edit_path": f"/rooms/{pointer_escape(room['id'])}/nodes/{index}/properties/position",
        "object_id": "node:" + node["path"], "host_path": node["path"],
        "host_type": node["type"], "host_state": "authored_scene_node",
    }


def reward_view(world: dict, design: dict, rooms: dict) -> list[dict]:
    actions = {a["id"]: a for a in world["actions"]}
    by_reward = {}
    for action in actions.values():
        reward_id = action.get("reward_id")
        if reward_id:
            by_reward.setdefault(reward_id, []).append(action)
    source_contracts = {r["reward_id"]: r for r in design["acquisition_contracts"] if r["room_id"] in rooms}
    # Major abilities and clock interactions are also meaningful spatial goals.
    for action in actions.values():
        if action["room_id"] in rooms and action.get("type") in ("ability", "clock_repair"):
            rid = action.get("reward_id", action["id"])
            source_contracts.setdefault(rid, {"reward_id": rid, "room_id": action["room_id"], "section_id": action.get("section_id", "main")})
    for group in ("clock_repairs", "important_markers"):
        for row in world.get(group, []):
            if row.get("room_id") in rooms:
                rid = row.get("reward_id", row["id"])
                source_contracts.setdefault(rid, {"reward_id": rid, "room_id": row["room_id"], "section_id": row.get("section_id", "main")})
    result = []
    for reward_id, acquisition in source_contracts.items():
        path, source = source_record(world, reward_id)
        source = source or {}
        candidates = by_reward.get(reward_id, [])
        action_id = source.get("action_id")
        if not action_id and len(candidates) == 1:
            action_id = candidates[0]["id"]
        if not action_id:
            action_id = next((x for x in ("pickup_" + reward_id, reward_id) if x in actions), None)
        action = actions.get(action_id, {})
        room_id = acquisition["room_id"]
        row = {
            "id": reward_id,
            "name": source.get("name", source.get("map_label", action.get("description", reward_id))),
            "room_id": room_id, "section_id": acquisition.get("section_id", "main"),
            "action_id": action_id, "source_path": path,
            "category": acquisition.get("category", source.get("kind", action.get("type", "collectible"))),
            "source_channel": acquisition.get("source_channel", source.get("source", action.get("type", ""))),
            "requires": copy.deepcopy(action.get("requires", acquisition.get("requires", [[]]))),
            "challenge": acquisition.get("challenge", ""),
            "discovery": acquisition.get("approach_cue", ""),
            "return_route": acquisition.get("return_path", ""),
            "position": None, "edit_path": None,
            "host_state": "no_unique_authored_host",
        }
        host = host_for_action(rooms[room_id], action_id) if action_id else None
        if host:
            row.update(host)
        if row["source_channel"] != "map":
            reason = "商店、NPC、能力和剧情目标需同步完整用例，不能仅移动收集宿主。"
        elif not host or host["host_type"] != "WorldRoomInteraction":
            reason = "没有唯一的普通地图交互宿主，需先完成场景绑定。"
        elif acquisition.get("return_access_contract", {}).get("local_return_state_id"):
            reason = "该收集物关联独立返程机关，须与整套挑战和返程合同一起迁移。"
        else:
            reason = "可连同唯一交互宿主迁移；保留原奖励身份、领取资格和永久收据。"
        row["relocatable"] = bool(row["source_channel"] == "map" and host
                                  and host["host_type"] == "WorldRoomInteraction"
                                  and not acquisition.get("return_access_contract", {}).get("local_return_state_id"))
        row["relocation_reason"] = reason
        result.append(row)
    return result


def make_seed(root: Path, scenes: dict, *, runtime_available=False, baseline=None, review_base=None) -> dict:
    root = root.resolve()
    source = root / "config/world"
    world, construction, design = (load(source / n) for n in ("world.json", "construction.json", "collection_design.json"))
    contracts, runtime = (load(root / "build/world" / n) for n in ("contracts.json", "runtime.json"))
    if scenes.get("base_content_version") != runtime["content_version"]:
        raise ValueError("Scene dump and compiled runtime have different content versions; export scenes again")
    names = {r["id"]: r for r in world["rooms"]}
    scope = editable_room_ids(root, construction)
    source_rooms = {r["room_id"]: r for r in construction["rooms"] if r["room_id"] in scope}
    room_contracts = {r["room_id"]: r for r in contracts["rooms"] if r["room_id"] in source_rooms}
    if set(scenes["rooms"]) != set(source_rooms):
        raise ValueError("Scene export must cover the complete plains and explicitly registered review room set")
    origins = preview_navigation_geometry(room_contracts, contracts["initial_state"]["room"])
    rooms = {}
    hashes = {"config/world/" + name: digest(source / name) for name in CONFIG_FILES}
    if (root / SCOPE_PATH).exists():
        hashes[SCOPE_PATH] = digest(root / SCOPE_PATH)
    for room_id, row in source_rooms.items():
        scene = copy.deepcopy(scenes["rooms"][room_id])
        path = row["scene_ref"].removeprefix("res://")
        if scene["source_hash"] != digest(root / path):
            raise ValueError("Scene changed after export: " + room_id)
        contract = room_contracts[room_id]
        rooms[room_id] = {
            **scene, "id": room_id, "name": names[room_id]["name"], "region": names[room_id]["region"],
            "implemented": bool(row.get("implemented")),
            "bounds": [0, 0, *row["extent"]], "space_rects": copy.deepcopy(row["space_rects"]),
            "map_position": origins[room_id]["origin"],
            "map_component": origins[room_id]["map_component"],
            "doors": copy.deepcopy(contract["doors"]),
        }
        hashes[path] = scene["source_hash"]
    tuning = load(root / "config/player_tuning.json")
    hashes["config/player_tuning.json"] = digest(root / "config/player_tuning.json")
    if baseline is None:
        baseline = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
    catalog = make_catalog(root, scenes, world, rooms, baseline)
    return {
        "schema": 1, "baseline": baseline, "content_version": runtime["content_version"],
        "source_hashes": hashes, "node_types": catalog["node_types"], "catalog": catalog,
        "rooms": rooms,
        "review_context": make_review_context(root, world, construction, contracts, runtime, rooms, baseline, review_base),
        "connections": [dict(copy.deepcopy(c), external=c["a"] not in rooms or c["b"] not in rooms)
                        for c in world["connections"] if c["a"] in rooms or c["b"] in rooms],
        "rewards": reward_view(world, design, rooms),
        "player": {"collision_size": [24, 36], "reference_visual_height": 44,
                   "viewport": [1280, 720], "camera": runtime["player"]["camera"],
                   "tuning": tuning, "motion_owner": "PlayerMotor"},
        "runtime": {"url": "/play/index.html?workbench=1", "available": runtime_available},
    }


def preview_catalog(root: Path) -> dict:
    """Derive the preview view without changing the constructed formal room set."""
    from build import local_returns

    source = root / "config/world"
    world = load(source / "world.json")
    construction = load(source / "construction.json")
    scope = editable_room_ids(root, construction)
    contracts, runtime = (load(root / "build/world" / name) for name in ("contracts.json", "runtime.json"))
    rooms = {r["room_id"]: copy.deepcopy(r) for r in contracts["rooms"] if r["room_id"] in scope}
    for room_id, room in rooms.items():
        room["preview_only"] = room_id not in runtime["rooms"]
        for door in room["doors"]:
            door["target_implemented"] = door["target_room"] in rooms
    geometry = preview_navigation_geometry(rooms, contracts["initial_state"]["room"])
    services = load(source / "demo_services.json")
    services["pickups"] = [p for p in services.get("pickups", []) if p["room_id"] in rooms]
    return {
        "schema": 1, "base_content_version": runtime["content_version"],
        "construction_sha256": digest(source / "construction.json"),
        "scope_sha256": digest(root / SCOPE_PATH) if (root / SCOPE_PATH).exists() else "",
        "construction_scene_bindings": {row["room_id"]: row["scene_ref"] for row in construction["rooms"] if row["room_id"] in scope},
        "rooms": rooms,
        "actions": copy.deepcopy(world["actions"]) + local_returns(source, set(rooms)),
        "demo_services": services,
        "npcs": [copy.deepcopy(n) for n in world["npcs"] if n["room_id"] in rooms],
        "map_rooms": [{**{k: r[k] for k in ("id", "name", "region")}, **geometry[r["id"]]}
                      for r in world["rooms"] if r["id"] in rooms],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--scenes", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--runtime-available", action="store_true")
    parser.add_argument("--preview-output", type=Path, help="Isolated plains and registered review rooms; never changes formal implementation status")
    parser.add_argument("--review-output", type=Path, help="Optional standalone world review context, identical to the seed view")
    parser.add_argument("--review-base", type=Path, help="Preserve existing controller measurements only when their source hashes match")
    args = parser.parse_args()
    result = make_seed(args.root, load(args.scenes), runtime_available=args.runtime_available,
                       review_base=load(args.review_base) if args.review_base else None)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    if args.preview_output:
        args.preview_output.parent.mkdir(parents=True, exist_ok=True)
        args.preview_output.write_text(json.dumps(preview_catalog(args.root), ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    if args.review_output:
        args.review_output.parent.mkdir(parents=True, exist_ok=True)
        args.review_output.write_text(json.dumps(result["review_context"], ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(args.output), "rooms": len(result["rooms"]),
                      "implemented": sum(r["implemented"] for r in result["rooms"].values()),
                      "rewards": len(result["rewards"]), "bytes": args.output.stat().st_size,
                      "content_version": result["content_version"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
