"""The four daily CI checks. No impact planning, historical evidence or test expansion."""
import argparse
from pathlib import Path
import re
import subprocess
import sys
import time

from run_tests import REPO, run_engine

CHECKS = ("project", "import", "smoke", "contracts")


def script(path, marker, timeout=45):
    output = run_engine(["--headless", "--fixed-fps", "60", "--path", ".", "--script", path], timeout)
    if path == "tests/ci_smoke.gd" and re.search(r"(?m)^ERROR:", output):
        raise RuntimeError("Game startup reported engine errors")
    if not re.search(marker, output, re.MULTILINE):
        raise RuntimeError(f"Missing successful completion: {path}")


def run(name):
    if name == "project":
        subprocess.run([sys.executable, "tools/check_project.py"], cwd=REPO, check=True, timeout=30)
    elif name == "import":
        # On a fresh checkout Godot may report its custom font before importing it.
        # Accept only that recovered bootstrap error; all other errors fail.
        font = re.search(r'^theme/custom_font="res://([^"]+)"$',
                         (REPO / "project.godot").read_text(), re.MULTILINE)[1]
        font_data = list((REPO / ".godot/imported").glob(Path(font).name + "-*.fontdata"))
        output = run_engine(["--headless", "--path", ".", "--editor", "--quit"], 120)
        errors = [line for line in output.splitlines() if line.startswith("ERROR:")]
        if not font_data and list((REPO / ".godot/imported").glob(Path(font).name + "-*.fontdata")):
            imported = r"res://\.godot/imported/" + re.escape(Path(font).name) + r"-[0-9a-f]+\.fontdata"
            recovered = [
                r"ERROR: Cannot open file '" + imported + r"'\.",
                r"ERROR: Failed loading resource: " + imported + r"\.",
                "ERROR: Failed loading resource: res://" + font + ".",
                "ERROR: Error loading custom project font 'res://" + font + "'",
            ]
            errors = [line for line in errors if not any(re.fullmatch(pattern, line) for pattern in recovered)]
        if errors:
            raise RuntimeError("Godot import errors: " + "\n".join(errors))
    elif name == "smoke":
        script("tests/ci_smoke.gd", r"^CI SMOKE: [1-9]\d* assertions, 0 failures$")
    elif name == "contracts":
        script("tests/ci_contracts.gd", r"^CI CONTRACTS: [1-9]\d* assertions, 0 failures$")
        script("tests/meta_notes_save_tests.gd", r"^META NOTES SAVE: [1-9]\d* assertions, 0 failures$", 20)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", choices=CHECKS, action="append", help="Only run the named check (repeatable)")
    args = parser.parse_args()
    started = time.monotonic()
    for name in args.check or CHECKS:
        check_started = time.monotonic()
        run(name)
        print(f"PASS: {name} ({time.monotonic() - check_started:.2f}s)", flush=True)
    print(f"CI: {len(args.check or CHECKS)} checks passed in {time.monotonic() - started:.2f}s", flush=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"CI failed: {error}", file=sys.stderr)
        sys.exit(1)
