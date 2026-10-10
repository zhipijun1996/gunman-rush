"""Bounded tests for the generated plains consumer; legacy suite stays separate."""
import re
import argparse
import subprocess
import sys
from run_tests import run_engine

# Fail fast on short input/policy/manifest/capability checks before long physics.
SUITES = [
    ("tests/plains_ground_support_runner.gd", r"PLAINS GROUND SUPPORT: [1-9]\d* assertions, 0 failures", 90),
    ("tests/plains_recoil_margin_runner.gd", r"PLAINS RECOIL MARGIN: [1-9]\d* assertions, 0 failures", 420),
    ("tests/plains_v3_runner.gd", r"PLAINS V3: [1-9]\d* assertions, 0 failures", 60),
    ("tests/camera_comfort_runner.gd", r"CAMERA COMFORT: [1-9]\d* assertions, 0 failures", 45),
    ("tests/plains_blueprint_runner.gd", r"PLAINS BLUEPRINT: [1-9]\d* assertions, 0 failures", 240),
    ("tests/recoil_recovery_runner.gd", r"RECOIL RECOVERY: [1-9]\d* assertions, 0 failures", 100),
    ("tests/plains_blueprint_schedule_runner.gd", r"BLUEPRINT SCHEDULE: [1-9]\d* assertions, 0 failures", 90),
    ("tests/branch_risk_rewards_runner.gd", r"BRANCH RISK REWARDS: [1-9]\d* assertions, 0 failures", 90),
    ("tests/route_signpost_runner.gd", r"ROUTE SIGNPOST: [1-9]\d* assertions, 0 failures", 60),
    ("tests/jump_chain_measurement_runner.gd", r"JUMP CHAIN: [1-9]\d* assertions, 0 failures", 30),
    ("tests/floating_touch_runner.gd", r"FLOATING TOUCH: [1-9]\d* assertions, 0 failures", 60),
    ("tests/enemy_drops_runner.gd", r"ENEMY DROPS: [1-9]\d* assertions, 0 failures", 120),
    ("tests/stage_batch_epoch_runner.gd", r"STAGE BATCH EPOCH: [1-9]\d* assertions, 0 failures", 90),
    ("tests/plains_ten_app_tests.gd", r"PLAINS TEN APP: [1-9]\d* assertions / 0 failures", 120),
    ("tests/plains_weak_capabilities_runner.gd", r"PLAINS WEAK CAPABILITIES: [1-9]\d* assertions, 0 failures", 60),
    ("tests/plains_branch_runner.gd", r"PLAINS BRANCH: [1-9]\d* assertions, 0 failures", 300),
    ("tests/branch_library_runner.gd", r"BRANCH LIBRARY: [1-9]\d* assertions, 0 failures", 540),
    ("tests/plains_refresh_art_runner.gd", r"PLAINS REFRESH ART: [1-9]\d* assertions, 0 failures; actual GPU/device visual review pending", 60),
    ("tests/plains_spatial_runner.gd", r"PLAINS SPATIAL: [1-9]\d* assertions, 0 failures", 240),
    ("tests/generated_exit_confirmation_runner.gd", r"GENERATED EXIT CONFIRMATION: [1-9]\d* assertions, 0 failures", 90),
    ("tests/jump_height_measurement_runner.gd", r"JUMP MEASUREMENT: 3 assertions, 0 failures", 100),
    ("tests/plains_exit_routes_runner.gd", r"PLAINS EXIT ROUTES: [1-9]\d* assertions, 0 failures", 90),
    ("tests/home_app_runner.gd", r"HOME APP: [1-9]\d* assertions, 0 failures", 90),
    ("tests/home_ui_tests.gd", r"HOME UI TESTS: [1-9]\d* assertions, 0 failures", 60),
    ("tests/player_feedback_runner.gd", r"PLAYER FEEDBACK: [1-9]\d* assertions, 0 failures", 60),
    ("tests/painterly_skin_runner.gd", r"PAINTERLY SKIN: [1-9]\d* assertions, 0 failures; real raster appearance/device performance pending", 60),
    ("tests/meta_notes_save_tests.gd", r"META NOTES SAVE: [1-9]\d* assertions, 0 failures", 90),
    ("tests/plains_ten_generation_runner.gd", r"PLAINS TEN GENERATION: [1-9]\d* assertions, 0 failures", 540),
]

FIXED_STEP_SCRIPTS = {"tests/plains_recoil_margin_runner.gd", "tests/plains_blueprint_runner.gd", "tests/plains_branch_runner.gd", "tests/branch_library_runner.gd",
                      "tests/plains_spatial_runner.gd", "tests/plains_ten_generation_runner.gd"}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--real-time", action="store_true", help="pace all headless physics at wall time")
    args = parser.parse_args()
    run_engine(["--headless", "--path", ".", "--editor", "--quit"], 90)
    for script, summary, seconds in SUITES:
        print(f"Running {script}; timeout {seconds}s", flush=True)
        clock_args = ["--fixed-fps", "60"] if script in FIXED_STEP_SCRIPTS and not args.real_time else []
        output = run_engine(["--headless", *clock_args, "--path", ".", "--script", script], seconds)
        pattern = "^" + summary + "$"
        if not re.search(pattern, output, re.MULTILINE):
            raise RuntimeError(f"{script}: missing success summary; early exit is a failure")
    print("PLAINS EIGHT SUITES: %s suites passed" % len(SUITES), flush=True)

if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"Plains eight verification failed: {error}", file=sys.stderr)
        sys.exit(1)
