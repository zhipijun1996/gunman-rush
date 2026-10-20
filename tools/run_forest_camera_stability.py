"""Observe real jump/recoil camera stability with strict engine exit handling."""
import re
from run_tests import run_engine


def main():
    output = run_engine([
        "--headless", "--path", ".", "--script",
        "tests/forest_camera_stability_runner.gd",
    ], 60)
    if not re.search(r"^FOREST CAMERA STABILITY: [1-9]\d* assertions, 0 failures$", output, re.M):
        raise RuntimeError("Camera scenario did not complete all real motion checks")


if __name__ == "__main__":
    main()
