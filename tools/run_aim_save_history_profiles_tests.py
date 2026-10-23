#!/usr/bin/env python3
"""Strict finite-history metadata and actual DemoApp ledger restoration checks."""
import re
from run_tests import run_engine


def main():
    output = run_engine([
        "--headless", "--audio-driver", "Dummy", "--path", ".", "--script",
        "tests/aim_save_history_profiles.gd",
    ], 120)
    if not re.search(r"^AIM HISTORY PROFILES: 72 assertions / 0 failures$", output, re.MULTILINE):
        raise RuntimeError("Missing complete finite historical-profile consumer result")
    print("PASS: Finite historical tuning profiles and current-rule App map restore")


if __name__ == "__main__":
    main()
