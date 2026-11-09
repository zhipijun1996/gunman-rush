#!/usr/bin/env python3
"""Read-only review context. Geometry remains in construction/scenes, never here."""
from __future__ import annotations
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def review_context(root: Path = ROOT, source_commit: str | None = None) -> dict:
    world_path = root / "config/world/world.json"
    design_path = root / "game/world/regions/P/room_design.json"
    world = json.loads(world_path.read_text())
    design = {r["room_id"]: r for r in json.loads(design_path.read_text())["rooms"]}
    boss_rooms = {b.get("physical_room", b.get("room_id")) for b in world["boss_plan"]["bosses"]}
    rooms = {}
    for row in world["rooms"]:
        authored = design.get(row["id"], {})
        rooms[row["id"]] = {
            "name": row["name"], "region": row["region"],
            "purpose": authored.get("purpose", row.get("purpose", "待设计职责")),
            "role": row.get("primary_role_zh", ""),
            "route_class": row.get("route_class", ""),
            "rest": bool(row.get("rest_point")),
            "boss": row["id"] in boss_rooms,
            "reward_ids": row.get("reward_ids", []),
            "internal_routes": row.get("internal_routes", []),
            "experience": authored.get("experience", {}),
            "spatial_intent": authored.get("spatial_intent", ""),
        }
    motion_path = root / "build/workbench/motion-reference.json"
    motion = json.loads(motion_path.read_text()) if motion_path.exists() else None
    if motion and (motion.get("failures") != 0 or not motion.get("source_hashes") or any(
        not (root / name).exists() or hashlib.sha256((root / name).read_bytes()).hexdigest() != value
        for name, value in motion["source_hashes"].items()
    )):
        motion = None
    return {
        "schema": 1,
        "source_commit": source_commit or subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
        "source_hashes": {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in (world_path, design_path)},
        "rooms": rooms,
        "regions": [{k: r.get(k, "") for k in ("id", "code", "name", "play", "reward_role")}
                    for r in world["regions"]],
        "tutorial_route": world["tutorial"]["route"],
        "motion_reference": motion,
        "coordinate_contract": "room-local world units + origins derived from paired door seams; map projection is display-only",
        "checks": ["出口及下个落点可预读", "反冲职责不能被普通跳跃绕过", "怪物、机关与地形形成组合",
                   "每片可达空间有用途", "失败可返回，不产生软锁", "收集有挑战/能力锁/隐藏入口及回程", "相邻门缝、回环与能力阶段一致"],
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(review_context(), ensure_ascii=False, separators=(",", ":")) + "\n")
