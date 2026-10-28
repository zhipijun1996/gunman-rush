"""Run the focused persistent-codex, snapshot-UI and formal-App contracts."""
import re
import subprocess
import sys

from run_tests import run_engine


def checked(arguments, timeout, marker=None):
    output = run_engine(arguments, timeout)
    if re.search(r"^ERROR:", output, re.MULTILINE):
        raise RuntimeError("Home codex emitted a native error")
    if marker and not re.search(rf"^{marker}: [1-9]\d* assertions, 0 failures$", output, re.MULTILINE):
        raise RuntimeError(f"Missing successful completion: {marker}")


def main():
    checked(["--headless", "--path", ".", "--editor", "--quit"], 90)
    for script, timeout, marker in [
        ("test_home_codex.gd", 30, "HOME ITEM CODEX"),
        ("test_home_item_codex_ui.gd", 35, "HOME ITEM CODEX UI"),
        ("test_home_codex_app.gd", 75, "HOME CODEX APP"),
    ]:
        checked(["--headless", "--path", ".", "--resolution", "1280x720", "--fixed-fps", "60", "--script", "tests/home_codex/" + script], timeout, marker)
    print("HOME CODEX CHECK: persistence, UI and formal App completed with 0 failures")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print("Home codex verification failed: " + str(error), file=sys.stderr)
        sys.exit(1)
