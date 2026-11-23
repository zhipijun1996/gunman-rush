"""Check the rebuild's catalog, documentation and real standalone Godot room."""
from pathlib import Path
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "production"


def check_catalog():
    index = json.loads((PROJECT / "config/world_elements/index.json").read_text())
    for group in ("definitions", "behaviors"):
        directory = PROJECT / "config/world_elements" / group
        expected = {f"res://config/world_elements/{group}/{p.name}" for p in directory.glob("*.json")}
        if expected != set(index[group].values()):
            raise ValueError(f"{group} index differs from the tracked catalog")
        for identity, resource in index[group].items():
            row = json.loads((PROJECT / resource.removeprefix("res://")).read_text())
            if row["id"] != identity:
                raise ValueError(f"Identity mismatch in {resource}")
            if group == "definitions":
                doc = row["documentation"]
                if row["library"] == "mechanisms" and doc != f"docs/data/mechanisms/{identity}.md":
                    raise ValueError(f"Missing independent object documentation for {identity}")
                if not (ROOT / doc).is_file():
                    raise ValueError(f"Missing documentation {doc}")


def check_mechanism_libraries():
    elements = PROJECT / "config/world_elements"
    index = json.loads((elements / "index.json").read_text())
    terrain = json.loads((PROJECT / "config/terrain_materials.json").read_text())
    libraries = index["mechanism_libraries"]

    def load(resource):
        return json.loads((PROJECT / resource.removeprefix("res://")).read_text())

    if set(libraries["regions"]) != set(terrain["regions"]):
        raise ValueError("Mechanism libraries and terrain registry must cover the same regions")
    profiles = {f"res://{path.relative_to(PROJECT)}" for path in (elements / "mechanisms/regions").glob("*.json")}
    if profiles != set(libraries["regions"].values()):
        raise ValueError("Region index differs from the mechanism profiles on disk")
    definitions = {key: load(path) for key, path in index["definitions"].items()}
    owners = {}

    def register(ids, owner):
        for key in ids:
            if key in owners or definitions.get(key, {}).get("library") != "mechanisms":
                raise ValueError(f"Invalid or duplicate mechanism {key} in {owner}")
            owners[key] = owner

    register(load(libraries["common"])["definitions"], "common")
    for region, path in libraries["regions"].items():
        profile = load(path)
        if profile["region_id"] != region:
            raise ValueError(f"Region identity mismatch in {path}")
        register(profile["definitions"], region)
        for key, skin in profile["skins"].items():
            if owners.get(key) not in ("common", region):
                raise ValueError(f"Skin for inaccessible mechanism {key} in {region}")
            slots = definitions[key].get("region_skin_fields", {})
            for field, value in skin.items():
                if slots.get(field) == "terrain_material" and value in terrain["materials"]:
                    continue
                if slots.get(field) == "texture" and isinstance(value, str) and value.startswith("res://assets/"):
                    resource = PROJECT / value.removeprefix("res://")
                    if resource.suffix == ".png" and resource.is_file() and resource.resolve().is_relative_to(PROJECT / "assets"):
                        continue
                raise ValueError(f"Unknown visual field or resource {key}.{field} in {region}")
    if set(owners) != {key for key, definition in definitions.items() if definition["library"] == "mechanisms"}:
        raise ValueError("Each mechanism definition must belong to exactly one library")
    for key, definition in definitions.items():
        for member in definition.get("members", []):
            owner = owners.get(member["definition"], "common")
            if owner not in ("common", owners.get(key)):
                raise ValueError(f"{key} includes a mechanism restricted to {owner}")


def godot(*args):
    result = subprocess.run(["bash", "tools/godot.sh", "--headless", "--path", str(PROJECT), *args],
                            cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=180)
    errors = re.findall(r"^(?:SCRIPT ERROR|ERROR|FAIL).*$", result.stdout, re.MULTILINE)
    if result.returncode or errors:
        raise RuntimeError(result.stdout[-12000:])
    return result.stdout


if __name__ == "__main__":
    try:
        check_catalog()
        check_mechanism_libraries()
        godot("--import")
        output = godot("--fixed-fps", "60", "--script", "res://tests/ordinary_room.gd")
        if "ORDINARY ROOM failures=0" not in output:
            raise RuntimeError(output)
        equipment = godot("--fixed-fps", "60", "--script", "res://tests/equipment.gd")
        if "EQUIPMENT failures=0" not in equipment:
            raise RuntimeError(equipment)
        mechanisms = godot("--fixed-fps", "60", "--script", "res://tests/mechanism_libraries.gd")
        if "MECHANISM LIBRARIES failures=0" not in mechanisms:
            raise RuntimeError(mechanisms)
        print(mechanisms.strip())
        print(output.strip())
        print(equipment.strip())
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        sys.exit(str(error))
