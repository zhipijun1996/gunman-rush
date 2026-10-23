#!/usr/bin/env python3
"""Strict targeted real-App default appearance/Timeweaver/lifecycle checks."""
import re
from run_tests import run_engine


def main():
    output = run_engine(["--headless", "--fixed-fps", "60", "--audio-driver", "Dummy",
                         "--path", ".", "--script", "tests/player_default_integration.gd"], 180)
    if not re.search(r"^PLAYER DEFAULT INTEGRATION: checks=235 failures=0$", output, re.MULTILINE):
        raise RuntimeError("Missing full actual default-player consumer completion")
    print("PASS: Formal default player, Timeweaver selection and feedback lifecycle")


if __name__ == "__main__":
    main()
