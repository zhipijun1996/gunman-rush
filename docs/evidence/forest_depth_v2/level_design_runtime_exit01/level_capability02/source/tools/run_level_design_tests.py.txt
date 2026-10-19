"""Existing Harness specialty: real capability, formal Manifest and route evidence."""
import contextlib
import re
import sys
from pathlib import Path

from run_tests import run_engine
import level_design


def main():
    folder = Path("build/level_design_v2")
    folder.mkdir(parents=True, exist_ok=True)
    with (folder / "capability.log").open("w") as log, contextlib.redirect_stdout(log):
        run_engine(["--headless", "--path", ".", "--editor", "--quit"], 120)
        out = run_engine(["--headless", "--fixed-fps", "60", "--path", ".", "--script",
                          "tests/level_capability_runner.gd"], 120)
    if not re.search(r"^LEVEL CAPABILITY: [1-9]\d* assertions, 0 failures$", out, re.M):
        raise RuntimeError("Capability proof missing completion")
    if level_design.main(["capture", "--output", str(folder / "capture.json")]):
        raise RuntimeError("Capture failed")
    if level_design.main(["analyze", "--capture", str(folder / "capture.json"),
                          "--output", str(folder / "report.json")]):
        raise RuntimeError("Evidence rejected")
    report = level_design.read(folder / "report.json")
    if report["provenance"]["status"] != "passed":
        raise RuntimeError("Actual process provenance not verified")
    print("PASS: level design runtime capability, formal Manifest and continuous route evidence")


if __name__ == "__main__":
    main()
