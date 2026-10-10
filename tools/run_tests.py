"""Run the complete Godot suite and fail on script errors or missing completion."""
import re
import argparse
import os
import selectors
import signal
import time
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def run_engine(arguments, timeout):
    command = ["bash", str(REPO / "tools/godot.sh"), *arguments]
    process = subprocess.Popen(command, cwd=REPO, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, start_new_session=True)
    chunks = []
    deadline = time.monotonic() + timeout
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    try:
        while selector.get_map():
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise subprocess.TimeoutExpired(command, timeout, output=b"".join(chunks))
            for key, _ in selector.select(min(0.25, remaining)):
                chunk = os.read(key.fd, 65536)
                if not chunk:
                    selector.unregister(key.fileobj)
                    continue
                chunks.append(chunk)
                print(chunk.decode(errors="replace"), end="", flush=True)
                # A SceneTree callback can abort on a script error without quitting
                # the engine. Diagnose it now rather than waiting for the deadline.
                if re.search(rb"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script", b"".join(chunks)):
                    raise RuntimeError("Godot emitted a script/shader error; aborted immediately")
        process.wait(timeout=max(0.01, deadline - time.monotonic()))
        output = b"".join(chunks).decode(errors="replace")
        if process.returncode:
            raise RuntimeError(f"Godot returned {process.returncode}")
        return output
    finally:
        selector.close()
        process.stdout.close()
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait(timeout=5)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--real-time", action="store_true", help="pace headless simulation at wall time")
    args = parser.parse_args()
    run_engine(["--headless", "--path", ".", "--editor", "--quit"], 90)
    # Dynamic and complete generated-stage routes run real fixed-step physics.
    # Bound the enlarged suite, including slower CI runners and new tall, reflected three-carrier routes and multiple terminal paths.
    clock_args = [] if args.real_time else ["--fixed-fps", "60"]
    output = run_engine(["--headless", *clock_args, "--path", ".", "--script", "tests/run_tests.gd"], 540)
    if not re.search(r"^ALL TESTS: [1-9]\d* assertions, 0 failures$", output, re.MULTILINE):
        raise RuntimeError("Complete suite did not report success; an early exit is a failure")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"Test verification failed: {error}", file=sys.stderr)
        sys.exit(1)
