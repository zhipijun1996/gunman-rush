"""Bounded Bellstrider regressions through the project's strict native guard.

Component and controlled App fixtures are not natural battle or art acceptance.
The continuous original-audio recording is produced separately.
"""
import json
from pathlib import Path
import re

from run_tests import run_engine

CASES = (
    ("combat", "tests/bellstrider_rework_01/combat_runner.gd", r"BELLSTRIDER_REWORK_COMBAT assertions=\d+ failures=0"),
    ("effects", "tests/bellstrider_rework_01/effect_targets.gd", r"BELLSTRIDER_EFFECT_TARGETS assertions=\d+ failures=0"),
    ("policy", "tests/bellstrider_rework_01/damage_policy.gd", r"BELLSTRIDER DAMAGE POLICY: \d+ checks, 0 failures"),
    ("weapons", "tests/bellstrider_rework_01/weapon_routes.gd", r"BELLSTRIDER WEAPON ROUTES: \d+ checks, 0 failures"),
    ("intro", "tests/bellstrider_rework_01/intro_pose.gd", r"BELLSTRIDER_INTRO_POSE assertions=\d+ failures=0"),
    ("rewards", "tests/bellstrider_rework_01/rewards_runner.gd", r"BELLSTRIDER_REWARDS checks=\d+ failures=0"),
    ("audio", "tests/bellstrider_rework_01/audio_pool.gd", r"BELLSTRIDER_AUDIO_POOL assertions=\d+ failures=0"),
)


def main():
    folder = Path("build/bellstrider_rework_01/regression")
    folder.mkdir(parents=True, exist_ok=True)
    # A fresh isolated Harness checkout has no editor class/import cache.
    # Match the existing native runners instead of relying on this workstation.
    imported = run_engine(["--headless", "--path", ".", "--editor", "--import", "--quit"], 90)
    (folder / "editor.log").write_text(imported)
    if re.search(r"(?m)^ERROR:", imported):
        raise RuntimeError("Editor import emitted a native engine error")
    rows = []
    for name, script, marker in CASES:
        output = run_engine(["--headless", "--path", ".", "--script", script], 90)
        (folder / (name + ".log")).write_text(output)
        if re.search(r"(?m)^ERROR:|RID allocations.*leaked", output):
            raise RuntimeError("Native engine error in Bellstrider consumer: " + name)
        if not re.search("^" + marker + "$", output, re.MULTILINE):
            raise RuntimeError("Missing complete Bellstrider result: " + name)
        rows.append({"case": name, "script": script, "status": "passed"})
    (folder / "report.json").write_text(json.dumps({
        "status": "passed", "cases": rows,
        "scope": "real component and controlled App regressions; no visual, natural fight, listening, device or user acceptance",
    }, indent=2) + "\n")
    print("BELLSTRIDER REWORK REGRESSION: seven native consumers, 0 failures")


if __name__ == "__main__":
    main()
