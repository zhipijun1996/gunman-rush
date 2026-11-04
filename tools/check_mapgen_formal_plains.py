"""Verify the real main entrance and native campaign integration."""
import re
from run_tests import run_engine


def main():
    output = run_engine([
        "--headless", "--audio-driver", "Dummy", "--fixed-fps", "60", "--path", ".",
        "--script", "tests/mapgen_formal_plains_runner.gd",
    ], 240)
    if re.search(r"(?m)^ERROR:", output):
        raise RuntimeError("Formal integration emitted an engine error")
    if not re.search(r"(?m)^MAPGEN FORMAL PLAINS: [1-9]\d* assertions, 0 failures$", output):
        raise RuntimeError("Missing complete formal campaign result")

    route = run_engine([
        "--headless", "--audio-driver", "Dummy", "--fixed-fps", "60", "--path", ".",
        "--script", "tests/mapgen_formal_route_runner.gd",
    ], 180)
    if not re.search(r"(?m)^MAPGEN FORMAL ROUTE: ticks=[1-9]\d* accepted_boss_damage=[1-9][\d.]* failures=0$", route):
        raise RuntimeError("Missing input-only start-to-Boss combat result")

    seams = run_engine([
        "--headless", "--audio-driver", "Dummy", "--fixed-fps", "60", "--path", ".",
        "--script", "tests/mapgen_plains_vertical_runner.gd",
    ], 180)
    if not re.search(r"(?m)^MAPGEN NATIVE SEAMS: [1-9]\d* assertions, 0 failures$", seams):
        raise RuntimeError("Missing native vertical / horizontal one-way seam result")


if __name__ == "__main__":
    main()
