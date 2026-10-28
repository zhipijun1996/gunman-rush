"""Execute one bounded real-Godot V5 family, with original strict engine guards.

These are focused fixtures; none is a claim of physical-device or full natural
route acceptance. The source-frozen Harness remains the acceptance envelope.
"""
import argparse
import re
import subprocess
import sys

from run_tests import run_engine

SUITES = {
    "catalog": ("tests/item_v5_catalog_suite.gd", 72),
    "pool": ("tests/item_v5_pool_suite.gd", 60),
    "inventory": ("tests/item_v5_inventory_runner.gd", 40),
    "combat": ("tests/item_v5_combat_runner.gd", 60),
    "actives": ("tests/item_v5_actives_runner.gd", 60),
    "economy": ("tests/item_v5_economy_runner.gd", 60),
    "defense": ("tests/item_v5_defense_time_runner.gd", 50),
    "ui": ("tests/item_v5_ui_input_runner.gd", 100),
    "formal": ("tests/item_v5_formal_runner.gd", 50),
    "review": ("tests/item_v5_review_runner.gd", 100),
    "boss-time": ("tests/item_v5_boss_time_runner.gd", 50),
    "core-effects": ("tests/item_v5_core_effects_runner.gd", 30),
    "synergy-economy": ("tests/item_v5_synergy_economy_runner.gd", 25),
    "pause-escape": ("tests/item_v5_pause_escape_runner.gd", 10),
    "random-context": ("tests/item_v5_random_context_runner.gd", 100),
    "manifest": ("tests/item_v5_manifest_runner.gd", 70),
    "authoring": ("tests/item_v5_authoring_runner.gd", 40),
    "art": ("tests/item_v5_art_runner.gd", 140),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", choices=SUITES, required=True)
    args = parser.parse_args()
    script, minimum = SUITES[args.suite]
    editor_output = run_engine(["--headless", "--path", ".", "--editor", "--quit"], 90)
    if re.search(r"(?m)^ERROR:|^SCRIPT ERROR:|^SHADER ERROR:", editor_output):
        raise RuntimeError("V5 editor emitted an engine error; diagnostic output is not a pass")
    argv = [
        "--headless", "--resolution", "1280x720", "--audio-driver", "Dummy",
        "--path", ".", "--script", script,
    ]
    if args.suite == "pause-escape": argv += ["--fixed-fps", "60"]
    if args.suite == "art": argv += ["--", "--require-all-icons"]
    output = run_engine(argv, 120)
    if re.search(r"(?m)^ERROR:|^SCRIPT ERROR:|^SHADER ERROR:", output):
        raise RuntimeError("V5 family emitted an engine error; diagnostic output is not a pass")
    label = {"ui": "UI INPUT", "defense": "DEFENSE TIME", "review": "INDEPENDENT REVIEW", "boss-time": "BOSS TIME", "core-effects": "CORE EFFECTS", "synergy-economy": "SYNERGY ECONOMY", "pause-escape": "PAUSE ESCAPE", "random-context": "RANDOM CONTEXT"}.get(args.suite, args.suite.upper())
    matches = re.findall(
        rf"^ITEM V5 {label}: (\d+) (?:assertions|checks), (\d+) failures$",
        output, re.MULTILINE,
    )
    if len(matches) != 1 or int(matches[0][0]) < minimum or matches[0][1] != "0":
        raise RuntimeError(f"V5 {args.suite} did not complete its required family coverage")
    print(f"PASS: item-v5-{args.suite} original native fixture and clean teardown")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Item V5 verification failed: {error}", file=sys.stderr)
        sys.exit(1)
