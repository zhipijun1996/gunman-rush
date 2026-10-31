"""Run the focused real-Player inventory/equipment/economy contract."""
import re
import subprocess
import sys
from run_tests import run_engine


def main():
    editor_output = run_engine(["--headless", "--path", ".", "--editor", "--quit"], 90)
    if re.search(r"^ERROR:", editor_output, re.MULTILINE):
        raise RuntimeError("Equipment editor import emitted an engine error")
    output = run_engine([
        "--headless", "--resolution", "1280x720", "--fixed-fps", "60",
        "--path", ".", "--script", "tests/gear_inventory_runner.gd",
    ], 90)
    if re.search(r"^ERROR:", output, re.MULTILINE):
        raise RuntimeError("Equipment suite emitted an engine error")
    if not re.search(r"^GEAR INVENTORY: [1-9]\d* assertions, 0 failures$", output, re.MULTILINE):
        raise RuntimeError("Equipment suite did not complete successfully")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print("Gear inventory verification failed: " + str(error), file=sys.stderr)
        sys.exit(1)
