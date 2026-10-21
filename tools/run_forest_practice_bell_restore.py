"""Practice-bell motion, atomic restore and actual App reload; no route admission."""
import argparse
import contextlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from run_tests import run_engine
from forest_bible_world_sources import inventory

ROOT = Path(__file__).resolve().parent.parent
SOURCE_PATHS = (
    "scripts/world/forest_practice_bell.gd",
    "scripts/world/grapple_anchor.gd",
    "scripts/run/plains_region_state.gd",
    "scripts/generation/thorn_forest_region_v2_v15.gd",
    "scripts/generation/forest_bible_v2_layout.gd",
    "scripts/generation/thorn_forest_region_assembler.gd",
    "scripts/demo/thorn_forest_region_stage.gd",
    "scripts/demo/demo_app.gd",
    "scripts/generation/thorn_forest_region_generator.gd",
    "scripts/presentation/forest_bible_presentation.gd",
    "scripts/audio/game_audio.gd",
    "tests/audio_teardown.gd",
    "tests/forest_practice_bell_restore_runner.gd",
    "tools/run_forest_practice_bell_restore.py",
    "tools/run_tests.py",
    "tools/godot.sh",
    "tools/forest_bible_world_sources.py",
)


def validate(data):
    if data.get("failures") != 0 or type(data.get("assertions")) is not int or data["assertions"] < 50:
        raise ValueError("Complete actual target restore assertions required")
    if len(data.get("checks", [])) != data["assertions"] or any(row.get("passed") is not True for row in data["checks"]):
        raise ValueError("Every native target/ledger observation must pass")
    rows = data.get("cases", [])
    expected = {"phase_continuity", "pause_resume", "ledger_unload", "atomic_rejections", "row_guards", "actual_app_reload"}
    if len(rows) != len(expected) or {row.get("id") for row in rows} != expected:
        raise ValueError("Every target lifecycle and refusal case is required")
    by_id = {row["id"]: row for row in rows}
    phase = by_id["phase_continuity"]
    if phase.get("identical") is not True or phase.get("frames") != 80 or phase.get("saved_clock", 0) <= 0 or phase.get("accepted_kicks") != 2:
        raise ValueError("Nonzero actual phase and accepted callback counter must survive reload")
    frames = data.get("motion_frames", [])
    if len(frames) != 80 or any(row.get("source") != row.get("restored") or row.get("clock") != row.get("restored_clock") for row in frames):
        raise ValueError("Continuous native target positions and clocks must remain identical")
    pause = by_id["pause_resume"]
    if pause.get("identical") is not True or pause.get("resumed_clock", 0) <= pause.get("frozen_clock", 0):
        raise ValueError("Actual pause/resume must retain and then advance target phase")
    ledger = by_id["ledger_unload"]
    if ledger.get("schema_version") != 2 or ledger.get("accepted_kicks") != 2 or ledger.get("identical") is not True:
        raise ValueError("Unchanged RegionState schema and exact rebuilt mechanism state required")
    rejected = by_id["atomic_rejections"]
    if rejected.get("missing_fields") != 6 or rejected.get("scalar_shapes") != 14 or rejected.get("inconsistencies") != 9 or rejected.get("state_unchanged") is not True:
        raise ValueError("Complete bounded atomic corruption refusals required")
    if by_id["row_guards"].get("rejected") != 8:
        raise ValueError("Authored identity/motion shape guards required")
    actual = by_id["actual_app_reload"]
    if actual.get("retained") is not True or actual.get("position_or_resource_injection") is not False:
        raise ValueError("Actual App unload/rebuild must preserve the original bell without player staging")
    before, resumed = actual.get("before", {}), actual.get("resumed", {})
    if (before.get("clock", 0) <= 0 or resumed.get("clock", 0) <= before["clock"]
            or resumed.get("accepted_kicks") != before.get("accepted_kicks")
            or resumed.get("authored_row") != before.get("authored_row")):
        raise ValueError("Actual App restored target must resume from its bound original phase")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", default="build/region_bible_v2/practice-bell/native")
    args = parser.parse_args()
    output = Path(args.output_dir)
    if not output.is_absolute(): output = ROOT / output
    output.mkdir(parents=True, exist_ok=True)
    before = inventory(ROOT)
    report = {"scope": __doc__, "sources_before": before,
              "explanatory_source_paths": list(SOURCE_PATHS), "source_stable": False,
              "source": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "status": "failed", "exit_code": 1}
    previous = {key: os.environ.get(key) for key in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS")}
    os.environ.update(OMP_NUM_THREADS="1", OPENBLAS_NUM_THREADS="1")
    try:
        with (output / "native.log").open("w") as stream, contextlib.redirect_stdout(stream):
            native = run_engine(["--headless", "--fixed-fps", "60", "--audio-driver", "Dummy", "--path", ".", "--script",
                                 "tests/forest_practice_bell_restore_runner.gd", "--", "--output-dir=" + str(output)], 90)
        if not re.search(r"^FOREST PRACTICE BELL RESTORE: [1-9]\d* assertions, 0 failures$", native, re.MULTILINE):
            raise ValueError("Complete practice target restore terminator missing")
        if re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR:|ObjectDB.*leaked|resources? still in use at exit", native):
            raise ValueError("Practice target restore emitted errors or leaks")
        data = json.loads((output / "capture.json").read_text())
        validate(data)
        report.update(status="passed", exit_code=0, assertions=data["assertions"])
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
        report["error"] = str(error)
        print(f"Forest practice target restore failed: {error}", file=sys.stderr)
    finally:
        try:
            after = inventory(ROOT)
            report["sources_after"] = after
            report["source_stable"] = before == after
            report["source_changes"] = {
                "added": sorted(after.keys() - before.keys()),
                "removed": sorted(before.keys() - after.keys()),
                "modified": sorted(path for path in before.keys() & after.keys() if before[path] != after[path]),
            }
            if before != after:
                report.update(status="failed", exit_code=1,
                              error=str(report.get("error", "")) + "; complete runtime/test/tool source inventory changed")
        except OSError as error:
            report.update(status="failed", exit_code=1, source_stable=False,
                          error=str(report.get("error", "")) + "; final source inventory failed: " + str(error))
        for key, value in previous.items():
            if value is None: os.environ.pop(key, None)
            else: os.environ[key] = value
        (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "exit_code": report["exit_code"],
                      "source_stable": report["source_stable"], "assertions": report.get("assertions"),
                      "source_paths": len(before), "error": report.get("error"),
                      "report": str(output / "report.json")}, ensure_ascii=False))
    return report["exit_code"]


if __name__ == "__main__":
    sys.exit(main())
