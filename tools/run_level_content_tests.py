#!/usr/bin/env python3
"""Original Harness entry for content contracts and a bounded Motor pilot.

Pure tests are the default. The explicit --pilot lane runs nine serial native
cases through the existing pilot/strict engine runner; expected no-jump refusal
is evidence for the negative control, never a physical pass or fun approval.
"""
import argparse
import json
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[1]
OLD = ("plains_low_arch", "plains_long_meadow", "forest_root_meadow")
NEW = ("plains_overlook_choice", "forest_crown_root_choice")


def verify_pilot_summary(summary, expected, root=ROOT):
    """Check the exact matrix and bound native observations, not green labels."""
    import level_content_contract as contract
    import level_content_pilot as pilot
    from level_content import digest, sha
    root = Path(root).resolve()
    if summary.get("blocked") != []:
        raise ValueError("Pilot contains blocked or incomplete cases")
    receipts = summary.get("receipts")
    if not isinstance(receipts, list) or len(receipts) != len(expected):
        raise ValueError("Missing or duplicate pilot cases")
    seen = set()
    for receipt in receipts:
        request = receipt.get("request", {})
        key = (request.get("candidate"), request.get("strategy"), request.get("variant"))
        if key not in expected or key in seen:
            raise ValueError("Unexpected or duplicate pilot condition")
        seen.add(key)
        if receipt.get("terminal") != "completed" or receipt.get("source_stable") is not True:
            raise ValueError("Pilot source or completion failure")
        source = receipt.get("runtime_source")
        if (not isinstance(source, dict) or not source
                or source != pilot.snapshot(root, request.get("catalog"))
                or digest(source) != receipt.get("source_fingerprint")
                or receipt["source_fingerprint"] != summary.get("source_fingerprint")
                or receipt.get("identity") != digest({"request": request, "runtime_bytes": source})):
            raise ValueError("Pilot source/input identity mismatch")
        for name, expected_hash in source.items():
            target = (root / name).resolve()
            if not target.is_relative_to(root) or not target.is_file() or sha(target) != expected_hash:
                raise ValueError("Pilot runtime source changed")
        raw_name = receipt.get("raw_path")
        if not isinstance(raw_name, str):
            raise ValueError("Missing pilot native evidence")
        raw_path = (root / raw_name).resolve()
        if (not raw_path.is_relative_to(root) or not raw_path.is_file()
                or sha(raw_path) != receipt.get("raw_sha256")):
            raise ValueError("Pilot raw hash mismatch")
        raw = json.loads(raw_path.read_text())
        log = raw_path.with_name("native.log")
        if not log.is_file() or sha(log) != receipt.get("log_sha256") or pilot.ERROR.search(log.read_text()):
            raise ValueError("Pilot log missing, changed or dirty")
        if not pilot.cached_valid(receipt, raw_path, log, receipt["identity"], request, root):
            raise ValueError("Pilot native/log/receipt consistency rejected")
        if (raw.get("candidate") != key[0] or raw.get("strategy") != key[1]
                or raw.get("variant") != key[2] or not raw.get("frames")):
            raise ValueError("Pilot native condition/trace mismatch")
        if key[1] == "no_jump":
            # This matrix uses two jumping candidates with a deliberately
            # disabled action. Other content (e.g. a rest meadow) may correctly
            # be traversable with no jump and is not assigned this assertion.
            if (receipt.get("technical_pass") is not False or receipt.get("expected_ablation") is not True
                    or raw.get("passed") is not False or raw.get("ok") is not False
                    or raw.get("exit_code") != 1 or raw.get("audio_released") is not True
                    or not raw.get("failures") or "LEVEL PILOT: FAIL" not in log.read_text()):
                raise ValueError("Expected no-jump refusal was not observed")
            frames = raw["frames"]
            if (raw.get("scope") != contract.PILOT_SCOPE or raw.get("real_motor") is not True
                    or raw.get("manual_motor_step") is not False
                    or raw.get("manual_controller_tick") is not True
                    or raw.get("midroute_injection") is not False or raw.get("resource_override") is not False
                    or raw.get("production_pool") is not False
                    or not any(f.get("jump_suppressed") is True for f in frames)
                    or any(f.get("frame") != i or f.get("motion_steps") != i for i, f in enumerate(frames, 1))
                    or any(e.get("type") == "jump_executed" for f in frames
                           for e in f.get("accepted_actions", []) if isinstance(e, dict))):
                raise ValueError("No-jump control lacks actual suppressed single-Motor-step observations")
        else:
            if receipt.get("technical_pass") is not True or receipt.get("strict_runner_error") is not None:
                raise ValueError("Required main/reward route failed")
            content = contract.make_content(key[0], "module", "pilot", "tools/level_pilot_validate.gd",
                                            summary.get("source_commit", "0" * 40),
                                            sha(root / "tools/level_pilot_validate.gd"))
            content["runtime"]["consumer"] = "scripts/generation/platforming_module.gd"
            evidence = {"scope": contract.PILOT_SCOPE}
            if not contract._physics_receipt(raw_path, content, evidence, root):
                raise ValueError("Native positive receipt rejected by content contract")
    if seen != set(expected):
        raise ValueError("Incomplete pilot matrix")
    return len(seen)


def run_pilot(output):
    import level_content_pilot as pilot
    from run_tests import run_engine
    folder = Path(output)
    if folder.is_absolute() or ".." in folder.parts or not folder.parts or folder.parts[0] != "build":
        raise ValueError("Pilot output must be a new path inside build")
    # Use the original engine import guard and preserve the original 90s cap.
    run_engine(["--headless", "--path", ".", "--editor", "--quit"], 90)
    cases = (("existing", OLD, ["main"]), ("new", NEW, ["main", "reward", "no_jump"]))
    count = 0
    for name, ids, strategies in cases:
        target = folder / name
        pilot.execute(SimpleNamespace(output=str(target), catalog="config/level_pilot_candidates.json",
                                      only=list(ids), strategies=strategies, variants=[0], reuse=False))
        summary = json.loads((ROOT / target / "experiment.json").read_text())
        expected = {(cid, strategy, 0) for cid in ids for strategy in strategies}
        count += verify_pilot_summary(summary, expected)
    print(f"PASS: AI level pilot / {count} bounded conditions; player and fun unverified")


def run_pure():
    suite = unittest.TestSuite()
    for name in ("test_level_content_contract.py", "test_level_content_pipeline.py"):
        suite.addTests(unittest.defaultTestLoader.discover(str(ROOT / "tests"), pattern=name))
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if not result.wasSuccessful() or result.testsRun == 0:
        return 1
    print(f"PASS: AI level content / {result.testsRun} contract and pipeline counterexamples")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pilot", action="store_true")
    parser.add_argument("--output", default="build/verification/ai-level-pilot/manual")
    args = parser.parse_args(argv)
    if not args.pilot:
        return run_pure()
    try:
        run_pilot(args.output)
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        print("AI level pilot rejected: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
