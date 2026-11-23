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
        godot("--import")
        output = godot("--fixed-fps", "60", "--script", "res://tests/ordinary_room.gd")
        if "ORDINARY ROOM failures=0" not in output:
            raise RuntimeError(output)
        equipment = godot("--fixed-fps", "60", "--script", "res://tests/equipment.gd")
        if "EQUIPMENT failures=0" not in equipment:
            raise RuntimeError(equipment)
        print(output.strip())
        print(equipment.strip())
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        sys.exit(str(error))
