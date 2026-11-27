"""Check content-lock fidelity, published room roles and isolated economy transactions."""
from pathlib import Path
import subprocess
import sys

from check_ordinary_rooms import godot

ROOT = Path(__file__).resolve().parents[1]


def main():
    subprocess.run([sys.executable, "tools/check_content_channel_integration.py"],
                   cwd=ROOT, check=True, timeout=180)
    godot("--import")
    for name, marker in (
        ("content_channel_catalog", "CONTENT CHANNEL CATALOG failures=0"),
        ("content_channel_economy", "CONTENT CHANNEL ECONOMY failures=0"),
        ("content_channel_room", "CONTENT CHANNEL ROOM failures=0"),
    ):
        output = godot("--fixed-fps", "60", "--script", f"res://tests/{name}.gd")
        if marker not in output:
            raise RuntimeError(output)
        print(output.strip())


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        sys.exit(str(error))
