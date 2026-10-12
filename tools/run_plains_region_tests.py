"""Bounded region topology, input-only itineraries and real lifecycle checks."""
import re
from run_tests import run_engine

SUITES = [
    ("tests/plains_cohesion_drops_runner.gd", r"PLAINS COHESION DROPS: [1-9]\d* assertions, 0 failures", 120),
    ("tests/plains_cohesion_lifecycle_runner.gd", r"PLAINS COHESION LIFECYCLE: [1-9]\d* assertions, 0 failures", 120),
    ("tests/plains_cohesion_runner.gd", r"PLAINS COHESION: [1-9]\d* assertions, 0 failures", 120),
    ("tests/plains_interactive_platforms_runner.gd", r"PLAINS INTERACTIVE PLATFORMS: [1-9]\d* assertions, 0 failures", 120),
    ("tests/plains_interactive_lifecycle_runner.gd", r"PLAINS INTERACTIVE LIFECYCLE: [1-9]\d* assertions, 0 failures", 90),
    ("tests/plains_platform_boss_runner.gd", r"PLAINS PLATFORM BOSS: [1-9]\d* assertions, 0 failures", 90),
    ("tests/plains_exploration_pressure_runner.gd", r"PLAINS EXPLORATION PRESSURE: [1-9]\d* assertions, 0 failures", 120),
    ("tests/plains_exploration_module_runner.gd", r"PLAINS EXPLORATION MODULES: [1-9]\d* assertions, 0 failures", 90),
    ("tests/plains_exploration_expansion_runner.gd", r"PLAINS EXPLORATION EXPANSION: [1-9]\d* assertions, 0 failures", 150),
    ("tests/plains_experience_energy_runner.gd", r"PLAINS EXPERIENCE ENERGY: [1-9]\d* assertions, 0 failures", 90),
    ("tests/plains_pressure_boss_runner.gd", r"PLAINS PRESSURE BOSS: [1-9]\d* assertions, 0 failures", 90),
    ("tests/plains_campaign_map_runner.gd", r"PLAINS CAMPAIGN MAP: [1-9]\d* assertions, 0 failures", 90),
    ("tests/plains_region_runner.gd", r"REGION ASSERTIONS: [1-9]\d* FAILED: 0", 300),
    ("tests/plains_region_lifecycle_runner.gd", r"REGION LIFECYCLE: [1-9]\d* assertions, 0 failures", 90),
    ("tests/plains_region_boss_runner.gd", r"REGION BOSS: [1-9]\d* assertions, 0 failures", 90),
]

if __name__ == "__main__":
    run_engine(["--headless", "--path", ".", "--editor", "--quit"], 90)
    for script, expected, timeout in SUITES:
        print(f"Running {script}; timeout {timeout}s", flush=True)
        output = run_engine(["--headless", "--fixed-fps", "60", "--path", ".", "--script", script], timeout)
        if not re.search("^" + expected + "$", output, re.MULTILINE):
            raise RuntimeError(f"{script}: missing completion summary")
    print("PLAINS REGION SUITES: 15 suites passed", flush=True)
