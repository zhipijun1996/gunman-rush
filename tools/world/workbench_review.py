"""Small, read-only world review projection of the original world contracts.

This does not add scene drafts, open an unbuilt boundary, or own a second graph.
Connection and door identities always come from the source and its compiler.
"""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path


CHECKS = [
    "出口及下个落点可预读", "反冲职责不能被普通跳跃绕过", "怪物、机关与地形形成组合",
    "每片可达空间有用途", "失败可返回，不产生软锁", "收集有挑战/能力锁/隐藏入口及回程",
    "相邻门缝、回环与能力阶段一致",
]


def _digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def make_review_context(root: Path, world: dict, construction: dict, contracts: dict,
                        runtime: dict, editable_rooms, baseline: str, previous=None) -> dict:
    editable = set(editable_rooms)
    implemented = set(runtime["rooms"])
    scope_path = "config/workbench/rooms.json"
    graybox = set(json.loads((root / scope_path).read_text()).get("graybox_room_ids", []))
    if not graybox <= editable: raise ValueError("Graybox status must refer to an editable room")
    sources = {"config/world/world.json", "config/world/construction.json", scope_path}
    designs = {}
    for region in world["regions"]:
        relative = f"game/world/regions/{region['code']}/room_design.json"
        path = root / relative
        if path.exists():
            sources.add(relative)
            data = json.loads(path.read_text(encoding="utf-8"))
            designs.update({row["room_id"]: row for row in data.get("rooms", [])})
    authored = {row["room_id"]: row for row in construction["rooms"]}
    compiled = {row["room_id"]: row for row in contracts["rooms"]}
    world_rooms = {row["id"]: row for row in world["rooms"]}
    if not editable <= world_rooms.keys() or not implemented <= world_rooms.keys():
        raise ValueError("Review contains unknown editable or implemented rooms")

    rooms = {}
    for room_id, room in world_rooms.items():
        design = designs.get(room_id, {})
        rooms[room_id] = {
            "name": room["name"], "region": room["region"], "purpose": room.get("purpose", ""),
            "role": room.get("primary_role_zh", ""), "route_class": room.get("route_class", ""),
            "rest": bool(room.get("rest_point")), "boss": room.get("play_mode") == "boss",
            "reward_ids": copy.deepcopy(room.get("reward_ids", [])),
            "internal_routes": copy.deepcopy(room.get("internal_routes", [])),
            "experience": copy.deepcopy(design.get("experience", {})),
            "spatial_intent": design.get("spatial_intent", ""),
            "extent": copy.deepcopy(authored[room_id]["extent"]),
            "implemented": room_id in implemented,
            "authoring_status": "graybox_review" if room_id in graybox else "unbuilt",
            "editor_available": room_id in editable, "preview_available": room_id in editable,
            "boundary_connection_ids": [],
        }

    def endpoint(connection, side):
        room_id = connection[side]
        target_room = connection["b" if side == "a" else "a"]
        matches = [door for door in compiled[room_id]["doors"] if door["edge_id"] == connection["id"]]
        if len(matches) != 1:
            raise ValueError("Cross-region connection lacks one compiled endpoint: " + connection["id"] + ":" + room_id)
        door = matches[0]
        if door["target_room"] != target_room:
            raise ValueError("Cross-region target disagrees with compiled door: " + door["id"])
        position = door["position_candidate"]
        landing = door["landing_contract"]
        return {
            "room_id": room_id, "room_name": rooms[room_id]["name"], "region": rooms[room_id]["region"],
            "door_id": door["id"], "section": door["section"],
            "target_room_id": target_room, "target_door_id": door["target_door_id"],
            "position": copy.deepcopy(position["local_world_units"]),
            "opening": copy.deepcopy(position["opening_candidate_world_units"]),
            "landing_position": copy.deepcopy(landing["safe_standing_position_world_units"]),
            "entry_position": copy.deepcopy(landing["entry_position_world_units"]),
            "direction": door["direction"], "requires": copy.deepcopy(door["requires"]),
            "outbound_allowed": bool(door["outbound_allowed"]),
            "implemented": room_id in implemented, "target_implemented": target_room in implemented,
            "editor_available": room_id in editable, "preview_available": room_id in editable,
            "coordinates_are_candidate": bool(landing.get("coordinates_are_candidate", True)),
            "position_status": position.get("status", ""),
        }

    connections = []
    for connection in world["connections"]:
        a, b = connection["a"], connection["b"]
        if rooms[a]["region"] == rooms[b]["region"]:
            continue
        endpoints = {side: endpoint(connection, side) for side in ("a", "b")}
        if (endpoints["a"]["target_door_id"] != endpoints["b"]["door_id"]
                or endpoints["b"]["target_door_id"] != endpoints["a"]["door_id"]):
            raise ValueError("Cross-region door pair disagrees: " + connection["id"])
        for room_id in (a, b):
            rooms[room_id]["boundary_connection_ids"].append(connection["id"])
        row = {key: copy.deepcopy(connection[key]) for key in (
            "id", "a", "b", "kind", "a_section", "b_section", "requires", "effective_door_requires",
            "direction", "condition_text", "ability_gate_in_door", "condition_format", "requirement_scope",
        ) if key in connection}
        row.update({
            "a_region": rooms[a]["region"], "b_region": rooms[b]["region"], "endpoints": endpoints,
            "implemented": a in implemented and b in implemented,
            "preview_available": a in editable and b in editable,
            "review_only": not (a in implemented and b in implemented),
        })
        connections.append(row)

    regions = []
    for region in world["regions"]:
        ids = [room_id for room_id, room in rooms.items() if room["region"] == region["code"]]
        regions.append({
            **{key: copy.deepcopy(region[key]) for key in ("id", "code", "name", "play", "reward_role", "pos", "color", "fill") if key in region},
            "room_count": len(ids), "implemented_room_count": sum(room_id in implemented for room_id in ids),
            "preview_room_count": sum(room_id in editable for room_id in ids),
            "graybox_room_count": sum(room_id in graybox for room_id in ids),
        })

    result = {
        "schema": 1, "source_commit": baseline, "content_version": runtime["content_version"],
        "source_hashes": {path: _digest(root / path) for path in sorted(sources)},
        "rooms": rooms, "regions": regions, "region_connections": connections,
        "tutorial_route": copy.deepcopy(world.get("tutorial", {}).get("route", [])),
        "coordinate_contract": "room-local world units + origins derived from paired door seams; map projection is display-only",
        "region_coordinate_contract": "world.regions.pos is a region relationship schematic, not room geometry or traversal distance",
        "availability_contract": "preview_available means included in the isolated workbench scene catalog; implemented means in the formal runtime; unbuilt cross-region boundaries remain closed",
        "checks": list(CHECKS),
        "counts": {"regions": len(regions), "rooms": len(rooms), "region_connections": len(connections),
                   "editable_rooms": len(editable), "implemented_rooms": len(implemented)},
    }
    # Existing controller samples are evidence, not something topology export
    # may synthesize or silently relabel as a new measurement.
    motion = (previous or {}).get("motion_reference")
    if motion:
        hashes = motion.get("source_hashes", {})
        matching = bool(hashes) and all((root / path).is_file() and _digest(root / path) == expected for path, expected in hashes.items())
        if matching:
            result["motion_reference"] = copy.deepcopy(motion)
            result["motion_reference"].setdefault("measured_source_commit", previous.get("source_commit"))
            result["motion_reference_status"] = "source_hashes_match_existing_measurement"
        else:
            result["motion_reference_status"] = "existing_measurement_has_stale_sources"
    return result
