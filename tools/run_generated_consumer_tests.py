"""Shared generated-level consumers; the eight-room application is retired."""
import re
import json
from pathlib import Path
import argparse
import subprocess
import sys
from run_tests import run_engine

# Fail fast on short input/policy/manifest/capability checks before long physics.
SUITES = [
    ("tests/plains_room_grammar_runner.gd", r"PLAINS ROOM GRAMMAR: [1-9]\d* assertions, 0 failures", 300),
    ("tests/plains_feedback_runner.gd", r"PLAINS FEEDBACK: [1-9]\d* assertions, 0 failures", 90),
    ("tests/plains_core_access_runner.gd", r"PLAINS CORE ACCESS: [1-9]\d* assertions, 0 failures", 90),
    ("tests/plains_final_pier_repro.gd", r"FINAL PIER REPRO: rewinds=0 final_pier=2 x=[0-9.]+ assertions=[1-9]\d* failures=0", 120),
    ("tests/plains_polish_boss_runner.gd", r"PLAINS POLISH BOSS: [1-9]\d* assertions, 0 failures", 150),
    ("tests/plains_camera_trace_runner.gd", r"PLAINS CAMERA TRACE: [1-9]\d* assertions, 0 failures", 180),
    ("tests/plains_polish_routes_runner.gd", r"PLAINS POLISH ROUTES: [1-9]\d* assertions, 0 failures", 420),
    ("tests/windkeeper_runner.gd", r"WINDKEEPER: [1-9]\d* assertions, 0 failures", 180),
    ("tests/plains_terrain_cohesion_runner.gd", r"PLAINS TERRAIN COHESION: [1-9]\d* assertions, 0 failures", 90),
    ("tests/generated_latch_trajectory_runner.gd", r"GENERATED LATCH TRAJECTORIES: [1-9]\d* assertions, 0 failures", 100),
    ("tests/plains_ground_support_runner.gd", r"PLAINS GROUND SUPPORT: [1-9]\d* assertions, 0 failures", 90),
    ("tests/plains_recoil_margin_runner.gd", r"PLAINS RECOIL MARGIN: [1-9]\d* assertions, 0 failures", 420),
    ("tests/camera_comfort_runner.gd", r"CAMERA COMFORT: [1-9]\d* assertions, 0 failures", 45),
    ("tests/plains_blueprint_runner.gd", r"PLAINS BLUEPRINT: [1-9]\d* assertions, 0 failures", 240),
    ("tests/recoil_recovery_runner.gd", r"RECOIL RECOVERY: [1-9]\d* assertions, 0 failures", 100),
    ("tests/plains_blueprint_schedule_runner.gd", r"BLUEPRINT SCHEDULE: [1-9]\d* assertions, 0 failures", 90),
    ("tests/jump_chain_measurement_runner.gd", r"JUMP CHAIN: [1-9]\d* assertions, 0 failures", 30),
    ("tests/floating_touch_runner.gd", r"FLOATING TOUCH: [1-9]\d* assertions, 0 failures", 60),
    ("tests/plains_weak_capabilities_runner.gd", r"PLAINS WEAK CAPABILITIES: [1-9]\d* assertions, 0 failures", 60),
    ("tests/plains_branch_runner.gd", r"PLAINS BRANCH: [1-9]\d* assertions, 0 failures", 300),
    ("tests/branch_library_runner.gd", r"BRANCH LIBRARY: [1-9]\d* assertions, 0 failures", 540),
    ("tests/plains_refresh_art_runner.gd", r"PLAINS REFRESH ART: [1-9]\d* assertions, 0 failures; actual GPU/device visual review pending", 60),
    ("tests/plains_spatial_runner.gd", r"PLAINS SPATIAL: [1-9]\d* assertions, 0 failures", 240),
    ("tests/jump_height_measurement_runner.gd", r"JUMP MEASUREMENT: 3 assertions, 0 failures", 100),
    ("tests/plains_exit_routes_runner.gd", r"PLAINS EXIT ROUTES: [1-9]\d* assertions, 0 failures", 90),
    ("tests/home_app_runner.gd", r"HOME APP: [1-9]\d* assertions, 0 failures", 90),
    ("tests/home_ui_tests.gd", r"HOME UI TESTS: [1-9]\d* assertions, 0 failures", 60),
    ("tests/player_feedback_runner.gd", r"PLAYER FEEDBACK: [1-9]\d* assertions, 0 failures", 60),
    ("tests/painterly_skin_runner.gd", r"PAINTERLY SKIN: [1-9]\d* assertions, 0 failures; real raster appearance/device performance pending", 60),
    ("tests/meta_notes_save_tests.gd", r"META NOTES SAVE: [1-9]\d* assertions, 0 failures", 90),
    ("tests/plains_ten_generation_runner.gd", r"PLAINS TEN GENERATION: [1-9]\d* assertions, 0 failures", 540),
]

FIXED_STEP_SCRIPTS = {"tests/plains_room_grammar_runner.gd","tests/plains_feedback_runner.gd", "tests/plains_core_access_runner.gd", "tests/plains_final_pier_repro.gd", "tests/plains_polish_boss_runner.gd", "tests/plains_polish_lifecycle_runner.gd", "tests/plains_camera_trace_runner.gd", "tests/plains_polish_routes_runner.gd", "tests/windkeeper_app_runner.gd", "tests/windkeeper_runner.gd", "tests/generated_latch_trajectory_runner.gd", "tests/plains_recoil_margin_runner.gd", "tests/plains_blueprint_runner.gd", "tests/plains_branch_runner.gd", "tests/branch_library_runner.gd",
                      "tests/plains_spatial_runner.gd", "tests/plains_ten_generation_runner.gd"}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--real-time", action="store_true", help="pace all headless physics at wall time")
    parser.add_argument("--grammar-phase-sweep", action="store_true", help="also run the existing optional quarter-phase routes in every template shard")
    args = parser.parse_args()
    run_engine(["--headless", "--path", ".", "--editor", "--quit"], 90)
    for script, summary, seconds in SUITES:
        print(f"Running {script}; timeout {seconds}s", flush=True)
        clock_args = ["--fixed-fps", "60"] if script in FIXED_STEP_SCRIPTS and not args.real_time else []
        shard_args = [[]]
        if script == "tests/plains_room_grammar_runner.gd":
            catalog = json.loads((Path(__file__).resolve().parents[1] / "config/plains_room_templates.json").read_text())
            ids = [entry["id"] for entry in catalog["templates"]]
            if not ids or any(not isinstance(item, str) or not item for item in ids) or len(ids) != len(set(ids)):
                raise RuntimeError("Grammar shard catalog is empty or contains invalid/duplicate IDs")
            # Baseline includes both real coin-room branches; never replace it
            # with contracts-only. Each selected template retains its own ascent
            # eligibility, all variants, and both terminal paths.
            shard_args = [["--", "--baseline-only"]] + [
                ["--", f"--template={item}", *(["--phase-sweep"] if args.grammar_phase_sweep else [])]
                for item in ids
            ]
        for extra in shard_args:
            print(f"Running {script} shard {extra or 'whole'}; timeout {seconds}s", flush=True)
            output = run_engine(["--headless", *clock_args, "--path", ".", "--script", script, *extra], seconds)
            pattern = "^" + summary + "$"
            if not re.search(pattern, output, re.MULTILINE):
                raise RuntimeError(f"{script} {extra}: missing success summary; early exit is a failure")
    print("GENERATED CONSUMER SUITES: %s suites passed" % len(SUITES), flush=True)

if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"Generated consumer verification failed: {error}", file=sys.stderr)
        sys.exit(1)
