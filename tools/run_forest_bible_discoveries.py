"""Forest-local reader transactions with actual viewport button dispatch.

This verifies no physical route, rendered art, permanent story save or device.
The caller owns the shared engine lease, as for other repository runners.
"""
from __future__ import annotations

import argparse
import re

from run_tests import run_engine


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skip-import", action="store_true")
    args = parser.parse_args()
    if not args.skip_import:
        run_engine(["--headless", "--path", ".", "--editor", "--quit"], 90)
    output = run_engine([
        "--headless", "--audio-driver", "Dummy", "--path", ".",
        "--script", "tests/forest_bible_discoveries_tests.gd",
    ], 90)
    if not re.search(r"^FOREST BIBLE DISCOVERIES: [1-9]\d* assertions, 0 failures$", output, re.M):
        raise RuntimeError("Forest discovery reader did not finish its contract tests")
    if "FOREST BIBLE DISCOVERIES CLEANUP: released=true" not in output:
        raise RuntimeError("Forest discovery fixture cleanup was not observed")
    if re.search(r"SCRIPT ERROR:|Parse Error:|ERROR:|RID.*leaked", output):
        raise RuntimeError("Forest discovery consumer emitted an engine error")
    print("PASS: Forest Bible optional reader, real rewards and cancellation; routes/art/device unverified")


if __name__ == "__main__":
    main()
