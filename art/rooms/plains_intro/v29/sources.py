"""Identify the published world lock, room document and directly authored scenery by content."""
import hashlib
import json
import sys
from pathlib import Path

production = Path(__file__).resolve().parents[4] / "production"
room_path = Path("rooms/world") / f"{sys.argv[1]}.json"
document = json.loads((production / room_path).read_text())
lock = json.loads((production / "config/imported_world/current.lock.json").read_text())


def resources(value):
    if isinstance(value, str) and value.startswith("res://"):
        yield Path(value.removeprefix("res://"))
    elif isinstance(value, dict):
        for child in value.values():
            yield from resources(child)
    elif isinstance(value, list):
        for child in value:
            yield from resources(child)


files = sorted({room_path, *resources(document)})
print(json.dumps({
    "room": sys.argv[1],
    "world_bundle": lock["bundle_sha256"],
    "content_version": lock["content_version"],
    "authored_inputs_sha256": {
        str(path): hashlib.sha256((production / path).read_bytes()).hexdigest() for path in files
    },
}, ensure_ascii=False, indent=2))
