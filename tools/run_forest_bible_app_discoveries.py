"""Actual v15 App colocation/reader UI fixture, not physical route admission."""
import argparse
import contextlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from run_forest_bible_integration import SOURCE_PATHS as INTEGRATION_SOURCES
from run_tests import run_engine
from forest_bible_world_sources import inventory

ROOT = Path(__file__).resolve().parent.parent
SOURCE_PATHS = tuple(dict.fromkeys((*INTEGRATION_SOURCES,
    "tests/forest_bible_app_discoveries_runner.gd",
    "tools/run_forest_bible_app_discoveries.py",
    "scripts/world/forest_bible_discoveries.gd",
    "scripts/world/forest_bible_discovery_catalog.gd",
    "resources/items/forest_old_badge.tres",
    "scripts/ui/stage_reward_modal.gd",
    "scripts/ui/item_card.gd",
    "scripts/rewards/reward_service.gd",
    "scripts/shops/run_wallet.gd",
    "scripts/input/keyboard_mouse_adapter.gd",
)))


def validate(data):
    if data.get("failures") != 0 or type(data.get("assertions")) is not int or data["assertions"] < 70:
        raise ValueError("Complete actual App UI assertions required")
    if len(data.get("checks", [])) != data["assertions"] or any(row.get("passed") is not True for row in data["checks"]):
        raise ValueError("Every actual App UI assertion must pass")
    rows = data.get("cases", [])
    if len(rows) != 3 or {row.get("id") for row in rows} != {"read_then_cache", "cache_then_read", "fatal_confirm"}:
        raise ValueError("Both real interaction orders and lethal confirmation control required")
    for row in rows:
        if row.get("id") != "fatal_confirm" and row.get("accepted_both") is not True:
            raise ValueError("Both colocated rewards must be acquired by actual GUI in either order")
    dead = next(row for row in rows if row["id"] == "fatal_confirm")
    if dead.get("denied") is not True or dead.get("acquired") != []:
        raise ValueError("Same-frame death must prevent discovery acquisition")
    enqueue, outcomes = dead.get("enqueue", []), dead.get("outcomes", [])
    if (len(enqueue) != 1 or enqueue[0].get("damage_accepted") is not True or enqueue[0].get("queued_claims") != 1
            or len(outcomes) != 1 or outcomes[0].get("lethal") is not True or outcomes[0].get("health") != 0):
        raise ValueError("Original damage batch and queued claim must be observed together")
    clicks = data.get("clicks", [])
    required = {label + suffix for label in ("read_then_cache", "cache_then_read")
                for suffix in ("/read", "/confirm", "/cache", "/pick_coin", "/repeat")} | {"fatal_confirm/read", "fatal_confirm/confirm"}
    if len(clicks) != len(required) or {row.get("label") for row in clicks} != required or any(row.get("pressed_count") != 1 for row in clicks):
        raise ValueError("Every intended viewport button needs exactly one real native pressed dispatch")
    staged = data.get("staged", [])
    if len(staged) != 3 or any(row.get("prior_motor_steps") != 0 or row.get("position") != [-525, 250] for row in staged):
        raise ValueError("Explicit App UI staging must occur before the first Motor step")
    if data.get("viewport") != [1280, 720] or data.get("shots") != [] or data.get("resource_injection") is not False:
        raise ValueError("Production-size UI fixture must not shoot or inject resources")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", default="build/region_bible_v2/discoveries/app")
    args = parser.parse_args()
    output = Path(args.output_dir)
    if not output.is_absolute(): output = ROOT / output
    output.mkdir(parents=True, exist_ok=True)
    sources_before = inventory()
    report = {"scope": __doc__, "sources": {path: sources_before[path] for path in SOURCE_PATHS},
              "sources_before": sources_before, "source_stable": False,
              "source": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "status": "failed", "exit_code": 1}
    previous = {key: os.environ.get(key) for key in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS")}
    os.environ.update(OMP_NUM_THREADS="1", OPENBLAS_NUM_THREADS="1")
    try:
        with (output / "native.log").open("w") as stream, contextlib.redirect_stdout(stream):
            native = run_engine(["--headless", "--audio-driver", "Dummy", "--path", ".", "--script",
                                 "tests/forest_bible_app_discoveries_runner.gd", "--", "--output-dir=" + str(output)], 150)
        if not re.search(r"^FOREST BIBLE APP DISCOVERIES: [1-9]\d* assertions, 0 failures$", native, re.MULTILINE):
            raise ValueError("Complete actual App discovery terminator missing")
        if re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR:|ObjectDB.*leaked|resources? still in use at exit", native):
            raise ValueError("Actual App discovery emitted engine errors or leaks")
        data = json.loads((output / "capture.json").read_text())
        validate(data)
        report.update(status="passed", exit_code=0, assertions=data["assertions"])
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
        report["error"] = str(error)
        print(f"Forest Bible App discovery failed: {error}", file=sys.stderr)
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
        for key, value in previous.items():
            if value is None: os.environ.pop(key, None)
            else: os.environ[key] = value
        (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({key: report[key] for key in
                      ("status", "exit_code", "source_stable", "assertions", "error") if key in report},
                     ensure_ascii=False))
    return report["exit_code"]


if __name__ == "__main__":
    sys.exit(main())
