"""Actual local ForestBibleAmbience/GameAudio lifecycle, with Dummy audio.

This does not verify listening, rendered animation, campaign events or devices.
The caller owns the repository's shared engine lease.
"""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

from run_tests import run_engine

ROOT = Path(__file__).resolve().parents[1]
BASE_SOURCES = (
    "tests/forest_bible_ambience_runner.gd",
    "tools/run_forest_bible_ambience.py",
    "game/presentation/world/presentation/forest_bible_ambience.gd",
    "game/presentation/audio/game_audio.gd",
    "tools/generate_forest_bible_sfx.py",
    "assets/forest_bible_v2/audio/provenance.json",
    "docs/creative_direction/bibles/2-thorn_forest_region_bible_v2.md",
    "tools/run_tests.py",
    "tools/godot.sh",
)


def source_hashes() -> dict[str, str]:
    paths = [ROOT / path for path in BASE_SOURCES]
    paths += sorted((ROOT / "assets/forest_bible_v2/audio").glob("*.wav"))
    paths += sorted((ROOT / "assets/audio/kenney").glob("*.ogg"))
    return {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}


def validate(data: dict) -> None:
    checks = data.get("checks", [])
    if data.get("failures") != 0 or data.get("assertions", 0) < 60 or len(checks) != data["assertions"]:
        raise ValueError("Complete native assertions and zero failures are required")
    if any(row.get("passed") is not True or not isinstance(row.get("label"), str) for row in checks):
        raise ValueError("Every actual native observation must be retained and pass")
    cases = data.get("cases", [])
    expected = {"pool", "pause", "events", "historical_disabled", "selective_stop_unload", "actor_release"}
    if len(cases) != len(expected) or {row.get("id") for row in cases} != expected:
        raise ValueError("All six actual node/audio cases are required exactly once")
    by_id = {row["id"]: row for row in cases}
    pool = by_id["pool"]
    tags = pool.get("tags", [])
    if pool.get("voices") != 12 or pool.get("loaded_regional") != 3 or len(tags) != 12 or len(set(tags)) != 12 or "" in tags:
        raise ValueError("Actual twelve-voice pool, regional loads and occupied cue tags missing")
    if any(pool.get("played", {}).get(key) != 1 for key in ("forest_wind", "forest_fruit", "forest_web")):
        raise ValueError("All three real regional streams must play and be counted")
    pause = by_id["pause"]
    if not 2.85 <= pause.get("frozen_clock", -1) < 3 or pause.get("resume_clock", -1) < 3:
        raise ValueError("Actual pause and resume must span the first due wind")
    if pause.get("wind_count") != 1 or pause.get("ui_click_count") != 1:
        raise ValueError("Paused UI and resumed world audio observations missing")
    events = by_id["events"]
    if events.get("fruit_count") != 3 or events.get("web_count") != 1 or events.get("remaining_bursts") != 0:
        raise ValueError("Actual distance/repetition/reduced/expiry event outcome missing")
    historical = by_id["historical_disabled"]
    if historical.get("clock") != 0 or historical.get("played_unchanged") is not True:
        raise ValueError("Historical layout must stay disabled through actual frames")
    stop = by_id["selective_stop_unload"]
    if stop.get("regional_refs") != 3 or stop.get("unload_refs") != 3:
        raise ValueError("Stop and unload require actual backend playback weak references")
    if any(stop.get(key) is not True for key in ("released", "ambience_released", "old_stream_preserved")):
        raise ValueError("Actual unload/release must preserve original cue ownership")
    actor = by_id["actor_release"]
    if actor.get("actor_released") is not True or actor.get("played") != {}:
        raise ValueError("Freed actor must leave no retained actor or stale ambient audio")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skip-import", action="store_true")
    parser.add_argument("--output-dir", default="build/region_bible_v2/ambience/native")
    args = parser.parse_args()
    output = Path(args.output_dir)
    if not output.is_absolute():
        output = ROOT / output
    output.mkdir(parents=True, exist_ok=True)
    if (output / "capture.json").exists() or (output / "report.json").exists():
        parser.error("Use a fresh output directory; previous native evidence is preserved")
    before = source_hashes()
    command = ["--headless", "--audio-driver", "Dummy", "--fixed-fps", "60", "--path", ".",
               "--script", "tests/forest_bible_ambience_runner.gd", "--", "--output-dir=" + str(output)]
    report = {"status": "failed", "exit_code": 1, "source_sha256": before,
              "sourceguard_scope": "listed local dependencies only; full source snapshot belongs to root harness",
              "source": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "command": ["bash", "tools/godot.sh", *command], "native_timeout_seconds": 90,
              "scope": "actual local Node/GameAudio; listening, rendered AV, formal campaign and device unverified"}
    previous = {key: os.environ.get(key) for key in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS")}
    os.environ.update(OMP_NUM_THREADS="1", OPENBLAS_NUM_THREADS="1")
    started = time.monotonic()
    try:
        with (output / "native.log").open("w") as stream, contextlib.redirect_stdout(stream):
            if not args.skip_import:
                run_engine(["--headless", "--path", ".", "--editor", "--quit"], 90)
            native = run_engine(command, 90)
        if not re.search(r"^FOREST BIBLE AMBIENCE: [1-9]\d* assertions, 0 failures$", native, re.M):
            raise ValueError("Native completion marker missing")
        if "FOREST BIBLE AMBIENCE CLEANUP: released=true" not in native:
            raise ValueError("Actual final fixture cleanup marker missing")
        if re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR:|RID.*leaked", native):
            raise ValueError("Native errors cannot be accepted as success")
        data = json.loads((output / "capture.json").read_text())
        validate(data)
        if source_hashes() != before:
            raise ValueError("Listed consumer source or audio changed during native execution")
        report.update(status="passed", exit_code=0, assertions=data["assertions"])
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
        report["error"] = str(error)
        print(f"Forest Bible ambience failed: {error}", file=sys.stderr)
    finally:
        for key, value in previous.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        report["elapsed_seconds"] = round(time.monotonic() - started, 4)
        report["source_stable"] = source_hashes() == before
        (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False))
    return report["exit_code"]


if __name__ == "__main__":
    sys.exit(main())
