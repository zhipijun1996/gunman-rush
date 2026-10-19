"""Current default-H technical sample; actual Router/Motor and physical negatives.

This is a development sample, never a complete forest, art approval or formal H grant.
Historical forest_h tests remain separate and unchanged.
"""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time
import uuid

import harness
from level_design import engine_log_matches, source_files
from level_region_context import build_region_context

ROOT = Path(__file__).resolve().parents[1]
ERRORS = r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR:|ObjectDB.*leaked|resources? still in use at exit|RID.*leaked"

def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def validate_current(data):
    errors = list(data.get("failures", []))
    raw = data.get("capability_snapshot", {}).get("raw", {})
    final = data.get("final_capability_snapshot", {})
    definition = raw.get("traversal_definition", {})
    path = "res://resources/player/traversal.tres"
    if definition.get("resource_path") != path or definition.get("sha256") != sha(ROOT / path[6:]):
        errors.append("current default TraversalDefinition identity absent")
    if final.get("traversal_definition") != definition:
        errors.append("traversal changed during real route")
    if raw.get("granted_actions") != ["jump", "shot_recoil", "grapple"] or raw.get("effective_max_jumps") != 1:
        errors.append("sample is not legal H-only / one ordinary jump")
    if not data.get("branch_landed") or not data.get("returned"):
        errors.append("continuous whole-body branch landing and return absent")
    frames = data.get("observations", [])
    if not frames or any(f.get("tick") != i or f.get("motor_steps_this_tick") != 1 for i, f in enumerate(frames, 1)):
        errors.append("continuous single-Motor physics absent")
    kinds = [e.get("kind") for e in data.get("events", [])]
    if not all(k in kinds for k in ["hook_cast", "hook_fly", "hook_pull", "hook_contact_kick", "hook_kick", "accepted_recoil_shot"]):
        errors.append("actual H plus accepted recoil chain absent")
    requests = data.get("input_requests", [])
    if [r.get("kind") for r in requests] != ["jump", "grapple", "shoot_release"] or not all(r.get("queued") for r in requests):
        errors.append("actual Router jump/H/recoil requests absent")
    health = raw.get("health", {}).get("current")
    if any(f.get("health") != health for f in frames):
        errors.append("health changed during technical route")
    return errors

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--skip-import", action="store_true")
    args = parser.parse_args()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S") + "_" + uuid.uuid4().hex[:8]
    folder = (args.output_dir or ROOT / "build/forest_current_slice" / stamp).resolve()
    if not folder.is_relative_to(ROOT / "build") or folder.exists():
        raise ValueError("Use a new repository build directory")
    folder.mkdir(parents=True)
    summary = {"schema_version": 1, "scope": "current_default_H_only_technical_sample_not_complete_forest",
               "default_short_hook_covered": True, "formal_region_opened": False, "formal_H_grant": False,
               "art_acceptance": "unverified", "status": "running", "cases": []}
    started = time.monotonic()
    try:
        context = build_region_context("thorn_forest")
        if context["design"]["stage"]["value"] != "S2" or context["design"]["gate"]["alternatives"] != [["H"]]:
            raise ValueError("Current forest authority is not S2 / H")
        summary["source_commit"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        if not args.skip_import:
            summary["import"] = harness.run_check({"argv": ["bash", "tools/godot.sh", "--headless", "--path", ".", "--editor", "--quit"], "timeout_seconds": 90, "success_pattern": r"Godot Engine v4\.7\.2"}, folder / "import.log", ROOT)
            if summary["import"]["status"] != "passed": raise RuntimeError("Current sample import failed")
        for case in ["positive", "missing-anchor", "no-hook"]:
            destination = folder / case; destination.mkdir()
            capture = destination / "capture.json"; log = destination / "capture.log"
            before = source_files(ROOT); case_start = time.monotonic()
            command = ["bash", "tools/godot.sh", "--headless", "--fixed-fps", "60", "--path", ".", "--script", "tests/forest_current_slice_runner.gd", "--", "--case=" + case, "--source-commit=" + summary["source_commit"], "--output=res://" + capture.relative_to(ROOT).as_posix()]
            receipt = {"case": case, "status": "failed", "started_at_utc": datetime.now(timezone.utc).isoformat(), "command": command, "source_before": before}
            try:
                result = harness.run_check({"argv": command, "timeout_seconds": 60, "success_pattern": r"^REGION PRODUCTION: [1-9]\d* assertions, 0 failures$"}, log, ROOT)
                receipt.update(result)
                if not capture.is_file(): raise RuntimeError("Native producer wrote no capture")
                data = json.loads(capture.read_text()); text = log.read_text(errors="replace")
                errors = validate_current(data)
                receipt.update(capture=str(capture.relative_to(ROOT)), capture_sha256=sha(capture), validation_errors=errors, assertions=data.get("assertions"), ticks=len(data.get("observations", [])))
                if source_files(ROOT) != before: raise RuntimeError("Source changed during current sample; fresh evidence rejected")
                if not engine_log_matches(data.get("engine"), text) or re.search(ERRORS, text): raise RuntimeError("Strict engine diagnostic / exit cleanup failure")
                if "CURRENT FOREST CLEANUP: released=true" not in text: raise RuntimeError("Actual world release not observed")
                expected = (case == "positive" and result["status"] == "passed" and result["exit_code"] == 0 and not errors or case != "positive" and result["exit_code"] == 1 and bool(errors) and bool(data.get("failures")))
                if case == "missing-anchor": expected = expected and data["geometry"]["anchor_present"] is False and not data["branch_landed"]
                if case == "no-hook": expected = expected and "grapple" not in data["capability_snapshot"]["raw"]["granted_actions"] and not data["branch_landed"]
                receipt.update(expected_outcome_observed=bool(expected))
                if not expected: raise RuntimeError("Actual current native outcome violated technical contract")
                receipt["status"] = "passed"
            except Exception as error:
                receipt.update(status="failed", error=str(error)); raise
            finally:
                receipt.update(source_after=source_files(ROOT), seconds=time.monotonic()-case_start, log_sha256=sha(log) if log.exists() else None)
                write(capture.with_suffix(".invocation.json"), receipt); summary["cases"].append(receipt)
        summary["status"] = "passed"
        print("PASS: current default H + recoil / landing recovery / return and actual node-capability negatives")
        return 0
    except Exception as error:
        summary.update(status="failed", error=str(error)); print("Current forest sample blocked: " + str(error)); return 1
    finally:
        summary["seconds"] = time.monotonic() - started
        write(folder / "summary.json", summary)
        print("CURRENT FOREST RECEIPT: " + str(folder / "summary.json"))

if __name__ == "__main__":
    raise SystemExit(main())
