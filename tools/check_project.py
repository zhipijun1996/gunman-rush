"""Fast checks for the current project, without historical quality/evidence gates."""
import json
from pathlib import Path
import re
import sys

from project_dependencies import inspect

ROOT = Path(__file__).resolve().parents[1]


def main():
    errors = inspect(ROOT)["errors"]
    project = (ROOT / "project.godot").read_text()
    main_scene = re.search(r'^run/main_scene="res://([^"]+)"$', project, re.MULTILINE)
    if not main_scene or not (ROOT / main_scene[1]).is_file():
        errors.append("Missing project main scene")
    for name in ("player_tuning", "input_profile", "gear_capacity", "meta_upgrades", "toolchain"):
        path = ROOT / "config" / (name + ".json")
        try:
            if not isinstance(json.loads(path.read_text()), dict):
                errors.append(f"Expected a JSON object: {path.relative_to(ROOT)}")
        except (OSError, ValueError) as error:
            errors.append(str(error))
    for folder in ("docs", "preview", "build"):
        if not (ROOT / folder / ".gdignore").is_file():
            errors.append(f"Missing import isolation: {folder}/.gdignore")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print("PASS: project entry, runtime dependencies and configuration")
    return 0


if __name__ == "__main__":
    sys.exit(main())
