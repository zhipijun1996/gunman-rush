"""Explicit scene scope for the workbench, shared by export and source import.

The world review contains summaries of every room. All formal rooms and individually registered review rooms become editable
scene drafts, so a preview can retain every formal cross-room connection.
"""
from __future__ import annotations

import json
from pathlib import Path

try:
    from .spatial import component_navigation_geometry
except ImportError:  # CLI modules in tools/world are also imported directly.
    from spatial import component_navigation_geometry


SCOPE_PATH = "config/workbench/rooms.json"


def editable_room_ids(root: Path, construction: dict) -> set[str]:
    known = {room["room_id"] for room in construction["rooms"]}
    result = {room_id for room_id in known if room_id.startswith("P-R")}
    path = root / SCOPE_PATH
    if not path.exists():
        return result
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("Unsupported workbench room scope")
    additional = value.get("additional_room_ids")
    if value.get("schema") != 1 or not isinstance(additional, list):
        raise ValueError("Unsupported workbench room scope")
    if any(not isinstance(room_id, str) for room_id in additional):
        raise ValueError("Workbench room scope must contain room identities")
    if len(additional) != len(set(additional)) or set(additional) & result:
        raise ValueError("Workbench room scope contains duplicate rooms")
    unknown = set(additional) - known
    if unknown:
        raise ValueError("Unknown workbench review room: " + ", ".join(sorted(unknown)))
    return result | set(additional) | {r["room_id"] for r in construction["rooms"] if r.get("implemented")}



def preview_navigation_geometry(rooms: dict, initial_room: str) -> dict:
    """Explicitly registered trials may have no campaign connection."""
    return component_navigation_geometry(rooms, initial_room, allow_isolated=True)
