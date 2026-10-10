"""Bounded tests for the generated plains consumer; legacy suite stays separate."""
import re
import subprocess
import sys
from run_tests import run_engine

SUITES = [
    ("tests/painterly_skin_runner.gd", r"PAINTERLY SKIN: [1-9]\d* assertions, 0 failures; real raster appearance/device performance pending", 60),
    ("tests/meta_notes_save_tests.gd", r"META NOTES SAVE: [1-9]\d* assertions, 0 failures", 90),
    ("tests/plains_ten_app_tests.gd", r"PLAINS TEN APP: [1-9]\d* assertions / 0 failures", 120),
    ("tests/plains_weak_capabilities_runner.gd", r"PLAINS WEAK CAPABILITIES: [1-9]\d* assertions, 0 failures", 60),
    ("tests/plains_ten_generation_runner.gd", r"PLAINS TEN GENERATION: [1-9]\d* assertions, 0 failures", 450),
]

def main():
    run_engine(["--headless", "--path", ".", "--editor", "--quit"], 90)
    for script, summary, seconds in SUITES:
        print(f"Running {script}; timeout {seconds}s", flush=True)
        output = run_engine(["--headless", "--path", ".", "--script", script], seconds)
        pattern = "^" + summary + "$"
        if not re.search(pattern, output, re.MULTILINE):
            raise RuntimeError(f"{script}: missing success summary; early exit is a failure")
    print("PLAINS TEN SUITES: 5 suites passed", flush=True)

if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"Plains ten verification failed: {error}", file=sys.stderr)
        sys.exit(1)
