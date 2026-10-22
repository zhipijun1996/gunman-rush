"""Actual v15 App wiring and outer restore-field refusal; not route admission."""
import argparse
from collections import Counter
import contextlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from run_forest_bible_weaver import SOURCE_PATHS as WEAVER_SOURCES
from run_tests import run_engine
from forest_bible_world_sources import inventory

ROOT = Path(__file__).resolve().parent.parent
SOURCE_PATHS = tuple(dict.fromkeys((*WEAVER_SOURCES,
    "tests/forest_bible_integration_runner.gd",
    "tools/run_forest_bible_integration.py",
    "scripts/generation/thorn_forest_region_generator.gd",
    "scripts/generation/thorn_forest_region_v2_v15.gd",
    "scripts/generation/forest_bible_v2_layout.gd",
    "scripts/generation/thorn_forest_region_assembler.gd",
    "scripts/run/plains_region_state.gd",
)))
MISSING = {"health", "position", "state", "state_time", "cooldown", "serial", "home", "direction", "depth_state"}
REFUSALS = {"missing_" + field for field in MISSING} | {"serial_fraction", "serial_string", "state_time_string", "cooldown_string"}
ERROR_BY_CASE = {key: "Recorded rooted actor phase rejected" for key in REFUSALS}
ERROR_BY_CASE.update({
    "missing_position": "Recorded migration actor shape rejected",
    "missing_depth_state": "Recorded migration actor shape rejected",
    "missing_health": "Recorded migration actor number rejected",
    **{key: "Recorded rooted actor phase number rejected" for key in
       ("missing_state_time", "missing_cooldown", "state_time_string", "cooldown_string")},
})


def validate(data, native):
    if data.get("failures") != 0 or type(data.get("assertions")) is not int or data["assertions"] < 50:
        raise ValueError("Complete bounded integration assertions required")
    checks = data.get("checks", [])
    if len(checks) != data["assertions"] or any(row.get("passed") is not True for row in checks):
        raise ValueError("Every native integration assertion must pass")
    rows = data.get("cases", [])
    expected = REFUSALS | {"app_configure", "app_reload", "outer_positive_control"}
    if len(rows) != len(expected) or {row.get("id") for row in rows} != expected:
        raise ValueError("Every shared positive consumer and exact outer refusal required")
    by_id = {row["id"]: row for row in rows}
    configured = by_id["app_configure"]
    if (configured.get("layout") != "forest-bible-world-v15"
            or configured.get("scene") != "res://scenes/enemies/forest_bible_weaver.tscn"
            or configured.get("behavior") != "forest_bible_weaver"
            or configured.get("configured") is not True
            or [row.get("id") for row in configured.get("strands", [])] != ["upper", "lower"]):
        raise ValueError("Actual v15 source, actor dispatch and authored strand configuration required")
    if by_id["app_reload"].get("retained") is not True or by_id["outer_positive_control"].get("accepted") is not True:
        raise ValueError("Unmodified real App reload and stage restore must pass")
    for key in REFUSALS:
        if by_id[key].get("rejected") is not True or by_id[key].get("expected_error") != ERROR_BY_CASE[key]:
            raise ValueError(f"Actual stage accepted damaged outer record: {key}")
    # Expected push_error remains visible. No generic ERROR, script error,
    # resource leak, extra refusal or missing refusal can become a green run.
    expected_errors = Counter(ERROR_BY_CASE.values())
    actual_errors = Counter(re.findall(r"^ERROR: (.+)$", native, re.MULTILINE))
    if actual_errors != expected_errors:
        raise ValueError(f"Native refusal errors differ: {dict(actual_errors)} != {dict(expected_errors)}")
    if re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ObjectDB.*leaked|resources? still in use at exit", native):
        raise ValueError("Native integration emitted an unexpected engine error or leak")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", default="build/region_bible_v2/ecology/integration")
    args = parser.parse_args()
    output = Path(args.output_dir)
    if not output.is_absolute():
        output = ROOT / output
    output.mkdir(parents=True, exist_ok=True)
    sources_before = inventory()
    report = {"scope": __doc__, "sources": {path: sources_before[path] for path in SOURCE_PATHS},
              "sources_before": sources_before, "source_stable": False,
              "source": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "status": "failed", "exit_code": 1}
    old_environment = {key: os.environ.get(key) for key in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS")}
    os.environ.update(OMP_NUM_THREADS="1", OPENBLAS_NUM_THREADS="1")
    try:
        with (output / "native.log").open("w") as stream, contextlib.redirect_stdout(stream):
            native = run_engine(["--headless", "--fixed-fps", "60", "--path", ".", "--script",
                                 "tests/forest_bible_integration_runner.gd", "--", "--output-dir=" + str(output)], 150)
        if not re.search(r"^FOREST BIBLE INTEGRATION: [1-9]\d* assertions, 0 failures$", native, re.MULTILINE):
            raise ValueError("Complete integration native terminator missing")
        data = json.loads((output / "capture.json").read_text())
        validate(data, native)
        report.update(status="passed", exit_code=0, assertions=data["assertions"], expected_refusals=len(REFUSALS))
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
        report["error"] = str(error)
        print(f"Forest Bible integration failed: {error}", file=sys.stderr)
    finally:
        try:
            report["sources_after"] = inventory()
            report["source_stable"] = sources_before == report["sources_after"]
            if not report["source_stable"]:
                report.update(status="failed", exit_code=1,
                              error="Runtime/test/tool/assets source closure changed during execution")
        except OSError as error:
            report.update(status="failed", exit_code=1, source_stable=False,
                          error="Complete source inventory failed: " + str(error))
        for key, value in old_environment.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({key: report[key] for key in
                      ("status", "exit_code", "source_stable", "assertions", "error") if key in report},
                     ensure_ascii=False))
    return report["exit_code"]


if __name__ == "__main__":
    sys.exit(main())
