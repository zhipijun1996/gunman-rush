"""Opt-in Bible F06 real-input local golden; never substitutes formal map travel."""
import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from run_tests import run_engine

ROOT = Path(__file__).resolve().parent.parent
SOURCE_PATHS = (
    "scripts/enemies/forest_bible_weaver_behavior.gd",
    "scripts/enemies/forest_bible_weaver_definition.gd",
    "resources/enemies/forest_bible_weaver.tres",
    "scenes/enemies/forest_bible_weaver.tscn",
    "tests/forest_bible_weaver_runner.gd",
    "tools/run_forest_bible_weaver.py",
    "scripts/enemies/forest_thread_spider_behavior.gd",
    "scripts/enemies/forest_enemy_definition.gd",
    "resources/enemies/forest_thread_spider.tres",
    "scenes/enemies/forest_thread_spider.tscn",
    "scripts/enemies/enemy_attack_behavior.gd",
    "scripts/enemies/enemy_actor.gd",
    "scripts/enemies/enemy_motor.gd",
    "scripts/demo/demo_app.gd",
    "scripts/demo/thorn_forest_region_stage.gd",
    "scripts/damage/frame_damage_policy.gd",
    "tests/forest_depth_enemy_runner.gd",
    "tests/audio_teardown.gd",
    "tools/run_tests.py",
    "tools/godot.sh",
)


def validate(data):
    if data.get("failures") != 0 or data.get("assertions", 0) < 60:
        raise ValueError("Complete bounded native assertions required")
    checks = data.get("checks", [])
    if len(checks) != data["assertions"] or any(row.get("passed") is not True for row in checks):
        raise ValueError("Every native assertion must be retained and pass")
    expected = {"alternation_restore", "occupied_body", "wait_retract",
                "preview_cross", "fixed_fruit_bypass", "shoot_dead_pass", "body_edge", "lifecycle"}
    rows = data.get("cases", [])
    if len(rows) != len(expected) or {row.get("id") for row in rows} != expected:
        raise ValueError("Every phase, strategy, and lifecycle control required")
    by_id = {row["id"]: row for row in rows}
    if by_id["alternation_restore"].get("holds") != [0, 1, 0]:
        raise ValueError("The same host must alternate both actual entrance holds")
    frames = data.get("phase_frames", [])
    if not frames or any(row.get("active") != (row.get("state") == "hold") for row in frames):
        raise ValueError("Only the real hold phase may expose active danger")
    for index in (0, 1):
        phases = {row.get("state") for row in frames if row.get("strand") == index}
        if not {"telegraph", "extend", "hold", "retract", "recovery"} <= phases:
            raise ValueError("Both entrance phase timelines must be observed")
    occupied = by_id["occupied_body"]
    if occupied["hp_before"] - occupied["hp_after"] != 1:
        raise ValueError("Occupied body crossing must commit original line damage")
    edge = by_id["body_edge"]
    if edge["hp_before"] - edge["hp_after"] != 1 or edge.get("position", [0, 0])[1] <= 260:
        raise ValueError("Finite endpoint must damage the actual grazing body despite clear center")
    for key in ("preview_cross", "wait_retract", "fixed_fruit_bypass", "shoot_dead_pass"):
        row = by_id[key]
        if row.get("hp_before") != row.get("hp_after") or row.get("position", [0])[0] <= 180:
            raise ValueError(f"{key}: legal actual input passage must preserve HP")
    if not by_id["fixed_fruit_bypass"].get("caught_fixed") or not by_id["fixed_fruit_bypass"].get("crossed"):
        raise ValueError("Side-fruit route needs actual hook capture and body passage")
    events = data.get("events", [])
    occupied_hits = [row for row in events
                     if row.get("kind") == "policy_result" and row.get("target") == "player"
                     and row.get("source") == "forest_bible_weaver"
                     and ":thread:" in str(row.get("event_id", ""))
                     and occupied["start_tick"] <= row.get("tick", -1) <= occupied["end_tick"]]
    if len(occupied_hits) != 1:
        raise ValueError("Occupied crossing must retain exactly one original thread policy commit")
    strategy_frames = data.get("strategy_frames", [])
    for key in ("occupied_body", "preview_cross", "wait_retract", "fixed_fruit_bypass", "shoot_dead_pass", "body_edge"):
        observed = [frame for frame in strategy_frames if frame.get("case") == key]
        threshold = 115 if key == "body_edge" else 180
        if not observed or observed[-1].get("position", [0])[0] <= threshold:
            raise ValueError(f"{key}: actual continuous passage frames missing")
    if not any(frame.get("caught_fixed") for frame in strategy_frames
               if frame.get("case") == "fixed_fruit_bypass"):
        raise ValueError("Side-fruit path must expose the actual hooked target during traversal")
    dead = by_id["shoot_dead_pass"]
    if not any(row.get("kind") == "accepted_shot" and row.get("projectiles", 0) > 0
               and dead["start_tick"] <= row.get("tick", -1) <= dead["end_tick"] for row in events):
        raise ValueError("Kill strategy requires accepted real shots and spawned projectiles")
    if not dead.get("dead") or not any(
        row.get("kind") == "policy_result" and row.get("target") == "forest_bible_weaver"
        and row.get("hp") == 0 and str(row.get("source", "")).startswith("player_projectile:")
        and dead["start_tick"] <= row.get("tick", -1) <= dead["end_tick"]
        for row in events
    ):
        raise ValueError("Dead-host passage requires actual projectile-policy lethal outcome")
    for key in ("pause_preserved", "epoch_cancelled", "inactive_cancelled", "moved_cancelled", "unload_cancelled"):
        if by_id["lifecycle"].get(key) is not True:
            raise ValueError(f"Missing lifecycle observation: {key}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", default="build/region_bible_v2/ecology/native")
    args = parser.parse_args()
    output = Path(args.output_dir)
    if not output.is_absolute():
        output = ROOT / output
    output.mkdir(parents=True, exist_ok=True)
    hashes = {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in SOURCE_PATHS}
    report = {"scope": "local F06 actual actor/input/policy; formal v15 routes separate", "sources": hashes,
              "source": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "status": "failed", "command": ["tests/forest_bible_weaver_runner.gd"], "exit_code": 1}
    old_environment = {key: os.environ.get(key) for key in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS")}
    os.environ.update(OMP_NUM_THREADS="1", OPENBLAS_NUM_THREADS="1")
    try:
        with (output / "native.log").open("w") as stream, contextlib.redirect_stdout(stream):
            native = run_engine(["--headless", "--fixed-fps", "60", "--path", ".", "--script",
                                 "tests/forest_bible_weaver_runner.gd", "--", "--output-dir=" + str(output)], 150)
        if not re.search(r"^FOREST BIBLE WEAVER: [1-9]\d* assertions, 0 failures$", native, re.MULTILINE):
            raise ValueError("Complete native terminator missing")
        if re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR:", native):
            raise ValueError("Native error output is not a clean success")
        data = json.loads((output / "capture.json").read_text())
        validate(data)
        current_hashes = {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in SOURCE_PATHS}
        if hashes != current_hashes:
            raise ValueError("Consumer source changed during native execution")
        report.update(status="passed", exit_code=0, assertions=data["assertions"])
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
        report["error"] = str(error)
        print(f"Forest Bible weaver failed: {error}", file=sys.stderr)
    finally:
        for key, value in old_environment.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False))
    return report["exit_code"]


if __name__ == "__main__":
    sys.exit(main())
