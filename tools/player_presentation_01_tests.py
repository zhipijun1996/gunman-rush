#!/usr/bin/env python3
"""Focused formal player lifecycle/Preview checks; not a full-profile approval."""
import re
from run_tests import run_engine


def main():
    for script, marker in (
        ("tests/player_presentation_01_anchor_tests.gd", r"^PLAYER ANCHOR TESTS: checks=27 failures=0$"),
        ("tests/player_presentation_01_preview_smoke.gd", r"^PLAYER PREVIEW SMOKE: checks=11 failures=0$"),
    ):
        output = run_engine(["--headless", "--path", ".", "--fixed-fps", "60",
                             "--audio-driver", "Dummy", "--script", script], 120)
        if not re.search(marker, output, re.MULTILINE):
            raise RuntimeError("Missing complete actual consumer result: " + script)
    print("PASS: PLAYER-PRESENTATION-01 formal lifecycle and standalone Preview")


if __name__ == "__main__":
    main()
