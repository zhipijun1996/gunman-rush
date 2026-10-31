"""Run existing integration consumers with their own strict completion markers.

This adapter adds no assertions or acceptance claims. run_engine enforces native
exit, script/shader errors, timeouts and clean teardown; each original consumer
must also print its actual nonzero-check, zero-failure summary.
"""
import argparse
import re
import subprocess
import sys

from run_tests import run_engine


# The five enemy fixtures use their original fixed 60fps simulation conditions;
# BGM probes actual MP3 playback/loop wrap and requires the normal engine clock.
# Save integration inherits the formal runner and its original completion line.
CASES = {
    "plains-motion-loot-02": (
        "tests/plains_motion_loot_02_runner.gd", r"PLAINS MOTION LOOT02: [1-9]\d* assertions, 0 failures", 240),
    "enemy-feedback-native": (
        "tests/enemy_feedback_01_tests.gd", r"ENEMY_FEEDBACK_01 checks=[1-9]\d* failures=0", 240),
    "enemy-feedback-formal": (
        "tests/enemy_feedback_01_formal.gd", r"ENEMY_FEEDBACK_01_FORMAL checks=[1-9]\d* failures=0", 240),
    "enemy-feedback-support": (
        "tests/enemy_feedback_01_support.gd", r"ENEMY_FEEDBACK_01_SUPPORT checks=[1-9]\d* failures=0", 180),
    "enemy-corpse-save": (
        "tests/enemy_corpse_save_integration.gd", r"ENEMY_FEEDBACK_01_FORMAL checks=[1-9]\d* failures=0", 240),
    "enemy-corpse-snapshot": (
        "tests/enemy_corpse_snapshot_cases.gd", r"ENEMY_CORPSE_SNAPSHOT checks=[1-9]\d* failures=0", 180),
    "bgm-integration": (
        "tests/bgm_integration/runner.gd", r"BGM INTEGRATION: [1-9]\d* checks, 0 failures", 360),
    "forest-v11-definition": (
        "tests/forest_v11_definition_runner.gd", r"FOREST V11 DEFINITION: [1-9]\d* assertions, 0 failures", 180),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", required=True, choices=CASES)
    case = parser.parse_args().case
    script, marker, timeout = CASES[case]
    run_engine(["--headless", "--audio-driver", "Dummy", "--path", ".", "--editor", "--quit"], 90)
    clock = [] if case == "bgm-integration" else ["--fixed-fps", "60"]
    output = run_engine(["--headless", "--audio-driver", "Dummy", *clock, "--path", ".", "--script", script], timeout)
    # Godot may emit this genuine GDScript lifecycle failure as ERROR rather
    # than SCRIPT ERROR, followed by an otherwise successful test summary.
    if re.search(r"^ERROR: Resumed function .*class instance is gone", output, re.MULTILINE):
        raise RuntimeError(f"{case}: resumed GDScript callback outlived its owner")
    if re.search("^" + marker + "$", output, re.MULTILINE) is None:
        raise RuntimeError(f"{case}: missing original successful completion marker")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"Integration consumer failed: {error}", file=sys.stderr)
        sys.exit(1)
