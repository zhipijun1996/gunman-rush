"""Run the complete Godot suite and fail on script errors or missing completion."""
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def run_engine(arguments, timeout):
    try:
        result = subprocess.run(["bash", str(REPO / "tools/godot.sh"), *arguments],
                                cwd=REPO, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        # Keep the engine diagnostic preceding a bounded timeout visible.
        # Otherwise an early script error can look like an unexplained hang.
        for captured in (error.stdout, error.stderr):
            if captured:
                print(captured.decode(errors="replace") if isinstance(captured, bytes) else captured, end="")
        raise
    output = result.stdout + result.stderr
    print(output, end="")
    if result.returncode:
        raise RuntimeError(f"Godot returned {result.returncode}")
    if re.search(r"SCRIPT ERROR:|Parse Error:|ERROR: Failed to load script", output):
        raise RuntimeError("Godot emitted a script error, even though the process returned zero")
    return output


def main():
    run_engine(["--headless", "--path", ".", "--editor", "--quit"], 90)
    # Dynamic and complete generated-stage routes run real fixed-step physics.
    # Bound the enlarged suite, including slower CI runners and new tall, reflected three-carrier routes and multiple terminal paths.
    output = run_engine(["--headless", "--path", ".", "--script", "tests/run_tests.gd"], 540)
    if not re.search(r"^ALL TESTS: [1-9]\d* assertions, 0 failures$", output, re.MULTILINE):
        raise RuntimeError("Complete suite did not report success; an early exit is a failure")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"Test verification failed: {error}", file=sys.stderr)
        sys.exit(1)
