"""Build the isolated editor preview catalog from authoritative game sources."""
from pathlib import Path
import copy,hashlib,json
from editor_scope import SCOPE_PATH,editable_room_ids,preview_navigation_geometry
def load(path): return json.loads(path.read_text())
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
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


