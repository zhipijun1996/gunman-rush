"""Check the rebuild's catalog, documentation and real standalone Godot room."""
from pathlib import Path
import hashlib
import os
import tempfile
import struct
import json
import re
import subprocess
import sys

from check_production_android import run as check_production_android

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
    for filename, assemblies in (("失序之钟_基本机关库.md", False), ("失序之钟_预组与组合推荐.md", True)):
        reference = (ROOT / "docs/data" / filename).read_text().split("定义 ID 对照")[-1]
        specified = {identity for line in reference.splitlines() if line.startswith("| ")
                     for identity in re.findall(r"`([a-z_]+\.[a-z_]+)`", line)}
        registered = {key for key, definition in definitions.items()
                      if definition["library"] == "mechanisms" and ("members" in definition) == assemblies}
        if specified != registered:
            raise ValueError(f"{filename} and public catalog differ: {sorted(specified ^ registered)}")
    regions = set(libraries["regions"])
    scopes = {}
    for key, definition in definitions.items():
        allowed = definition.get("usable_regions", ["*"])
        if not isinstance(allowed, list) or not allowed or any(not isinstance(item, str) for item in allowed):
            raise ValueError(f"Invalid usable_regions in {key}")
        if len(allowed) != len(set(allowed)) or (allowed != ["*"] and not set(allowed) <= regions):
            raise ValueError(f"Unknown, repeated or mixed usable_regions in {key}")
        scopes[key] = regions.copy() if allowed == ["*"] else set(allowed)
    for key, definition in definitions.items():
        for member in definition.get("members", []):
            child = definitions.get(member["definition"])
            if not child or "members" in child:
                raise ValueError(f"Invalid assembly member in {key}")
            scopes[key] &= scopes[child["id"]]
        if not scopes[key]:
            raise ValueError(f"No usable region for {key}")
    hardware_hashes = set()
    for region, path in libraries["regions"].items():
        profile = load(path)
        if profile["region_id"] != region:
            raise ValueError(f"Region identity mismatch in {path}")
        expected_atlas = f"res://assets/mechanisms/regional/{region}.png"
        if profile.get("hardware_atlas") != expected_atlas or not re.fullmatch(r"#[0-9a-fA-F]{6}",profile.get("hardware_light","")):
            raise ValueError(f"Invalid hardware atlas or light for {region}")
        data = (PROJECT / expected_atlas.removeprefix("res://")).read_bytes()
        signature = hashlib.sha256(data).digest()
        if data[:8] != b"\x89PNG\r\n\x1a\n" or struct.unpack(">II",data[16:24]) != (148,36) or signature in hardware_hashes:
            raise ValueError(f"Invalid or duplicate regional material for {region}")
        hardware_hashes.add(signature)
        for key, skin in profile["skins"].items():
            if key not in scopes or region not in scopes[key] or definitions[key]["library"] != "mechanisms":
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


def godot(*args, env=None):
    result = subprocess.run(["bash", "tools/godot.sh", "--headless", "--path", str(PROJECT), *args],
                            cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=180)
    errors = re.findall(r"^(?:SCRIPT ERROR|ERROR|FAIL).*$", result.stdout, re.MULTILINE)
    if result.returncode or errors:
        raise RuntimeError(result.stdout[-12000:])
    return result.stdout


def check_player_settings_restart():
    with tempfile.TemporaryDirectory(prefix="gunman-settings-restart-") as home:
        env = {**os.environ, "GUNMAN_DATA_HOME": home}
        for stage in ("write", "read"):
            result = godot("--fixed-fps", "60", "--script", "res://tests/player_settings_restart.gd",
                           "--", stage, home, env=env)
            if "SETTINGS RESTART failures=0" not in result:
                raise RuntimeError(result)
            print(result.strip())


if __name__ == "__main__":
    try:
        check_catalog()
        check_mechanism_libraries()
        godot("--import")
        check_player_settings_restart()
        check_production_android()
        suites = {
            "world_shell_flow": "WORLD SHELL",
            "world_gamepad": "WORLD GAMEPAD",
            "world_play_hud": "WORLD PLAY HUD",
            "playable_world_audio": "PLAYABLE WORLD AUDIO",
            "player_settings": "PLAYER SETTINGS",
            "world_recovery_presentation": "WORLD RECOVERY PRESENTATION",
            "ordinary_room": "ORDINARY ROOM",
            "room_camera_contract": "ROOM CAMERA CONTRACT",
            "world_camera_migration": "WORLD CAMERA MIGRATION",
            "world_room_passages": "WORLD ROOM PASSAGES",
            "authored_world_rooms": "AUTHORED WORLD",
            "world_persistence": "WORLD PERSISTENCE",
            "world_save_compatibility": "WORLD SAVE COMPATIBILITY",
            "world_station_travel": "WORLD STATION travel",
            "thorn_forest_routes": "THORN FOREST ROUTES",
            "world_encounters": "WORLD ENCOUNTERS",
            "sky_world_trials": "SKY WORLD TRIALS",
            "gear_city": "GEAR CITY",
            "machine_bosses": "MACHINE BOSSES",
            "world_content_sites": "WORLD CONTENT SITES",
            "world_weapon_workshop": "WORLD WEAPON WORKSHOP",
            "world_interior_doors": "WORLD INTERIOR DOORS",
            "plains_p02_terrace": "P02 TERRACE",
            "p02_death_recovery": "P02 DEATH RECOVERY",
            "p02_connections": "P02 CONNECTIONS",
            "plains_intro_rooms": "PLAINS INTRO",
            "world_shortcuts": "WORLD SHORTCUTS",
            "room_touch_controls": "ROOM TOUCH CONTROLS",
            "p01_loft_chest": "P01 LOFT CHEST",
            "p01_opening": "P01 OPENING",
            "equipment": "EQUIPMENT",
            "mechanism_libraries": "MECHANISM LIBRARIES",
            "bell_gate": "BELL GATE",
            "crossing_sensor": "CROSSING SENSOR",
            "mechanism_integration": "MECHANISM INTEGRATION",
            "mechanism_editor": "MECHANISM EDITOR",
            "carrier_library": "CARRIER LIBRARY",
            "hazard_library": "HAZARD LIBRARY",
            "perception_library": "PERCEPTION LIBRARY",
            "projectile_library": "PROJECTILE LIBRARY",
            "traversal_library": "TRAVERSAL LIBRARY",
            "mechanism_services_showcase": "MECHANISM SERVICES SHOWCASE",
            "regional_mechanism_art": "REGIONAL MECHANISM ART",
            "beam_library": "BEAM LIBRARY",
        }
        for script, label in suites.items():
            output = godot("--fixed-fps", "60", "--script", f"res://tests/{script}.gd")
            if not re.search(rf"^{re.escape(label)} (?:checks=\d+ )?failures=0\b", output, re.MULTILINE):
                raise RuntimeError(output)
            print(output.strip())
        touch = godot("--fixed-fps", "60", "--script", "res://tests/plains_intro_rooms.gd", "--", "--touch")
        if "PLAINS INTRO failures=0" not in touch:
            raise RuntimeError(touch)
        print(touch.strip())
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        sys.exit(str(error))
