#!/usr/bin/env python3
"""Verify the ordinary main-game Title/Home departure into fixed seed 930001.

Native GUI, player, combat, settlement and cleanup are exercised. Explicit Meta,
loadout, Boss-arrival and fatal-request fixtures remain labelled in the report;
this is not a certificate of continuous traversal across the whole map.
"""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time

from run_mapgen_delivery_tests import ERROR, ROOT, Tee, git_identity, source_manifest
from run_tests import run_engine

MARKER = re.compile(r"^MAPGEN MAIN: ([1-9]\d*) checks, (\d+) failures$", re.M)
REQUIRED = {
    "pointer/title_begin", "pointer/home_shadow_weapon", "pointer/home_departure_begin",
    "pointer/abandon_enter_home", "pointer/home_pulse_weapon", "pointer/second_departure_begin",
    "pointer/summary_depart_again", "ordinary/title", "ordinary/home", "ordinary/permanent_upgrade",
    "ordinary/selected_weapon", "ordinary/fixed_map_profile", "ordinary/loaded/first",
    "ordinary/loaded/second", "ordinary/loaded/retry", "binding/resource_identity", "binding/no_reset",
    "binding/inventory/first", "binding/inventory/second", "binding/inventory/retry",
    "binding/single_host_services/first", "binding/single_host_services/second",
    "binding/single_host_services/retry", "natural/native_bell", "natural/M01_to_M02",
    "ordinary/map_open", "ordinary/map_close", "ordinary/pause_open", "ordinary/pause_close",
    "lifecycle/return_home", "lifecycle/fresh_run", "boss/hosted_arrival", "boss/hosted_native_victory",
    "lifecycle/native_boss_settled", "lifecycle/retry_fixed_map", "lifecycle/stale_epoch_refused",
    "lifecycle/native_fatal_submitted", "lifecycle/fatal_returns_home", "main/audio_teardown",
}

REQUIRED |= {
    "pointer/pause_journey_page", "pointer/pause_return_home", "pointer/confirm_leave_run",
    "manifest/actual_ready_roundtrip", "director/not_complete", "director/no_fake_gold_or_second_map",
    "director/stale_completion", "director/completion_idempotence", "director/formal_not_delivery",
    "bind_api/no_rebind", "bind_api/in_tree_refused", "ordinary/pause_M_guard", "ordinary/no_hidden_exit_keys",
    "ordinary/M29_native_W", "ordinary/M29_pause_owner", "pointer/M29_coin_choice", "ordinary/M29_mouse_OR_commit",
    "boss/v5_equipped_native", "boss/v5_native_policy_damage", "boss/v5_unequip_revokes", "boss/v5_no_hidden_regrant",
}
REQUIRED |= {"boss/v5_refuse/"+name for name in ("unregistered_flag","source_actor","session","amount")}
REQUIRED |= {"hud/single_visible_status/"+label for label in ("first","second","retry")}
REQUIRED |= {"manifest/refuse/"+name for name in (
    "root_seed","receipt_seed","map_sha","manifest_sha","profile_version","profile_count","profile_boss",
    "profile_development","stages_missing","second_stage","stage_type","stage_biome","stage_offers",
    "stage_outputs_array","delivery_output_array","tuning_gravity","tuning_type","capability_type",
    "item_fingerprint","physics_hash")}
REQUIRED |= {"bind_api/refuse/"+name for name in (
    "empty_services","empty_identity","null_player","wrong_policy","null_lifetime","wrong_wallet",
    "wrong_segment","wrong_meta","wrong_region","foreign_lifetime")}


def manifest():
    result = source_manifest()
    for name in ("tests/mapgen_main_runner.gd", "tools/run_mapgen_main_tests.py"):
        result[name] = hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
    return result


def verify(data, text):
    marker = MARKER.search(text)
    if marker is None or int(marker.group(2)) != 0:
        raise RuntimeError("Missing complete zero-failure main-game test marker")
    if data.get("seed") != 930001 or data.get("schema") != "gunman/mapgen-main-tests/v1":
        raise RuntimeError("Main-game report seed/schema mismatch")
    if data.get("whole_map_continuous_traversal") != "NOT_RUN":
        raise RuntimeError("Scoped main integration cannot certify whole-map traversal")
    rows = data.get("cases", [])
    ids = [row.get("id") for row in rows]
    if len(ids) != len(set(ids)):
        raise RuntimeError("Duplicate main-game case IDs")
    by_id = {row["id"]: row for row in rows}
    missing = REQUIRED - set(ids)
    if missing:
        raise RuntimeError(f"Missing required main-game consumers: {sorted(missing)}")
    if any(by_id[identity].get("status") != "passed" for identity in REQUIRED):
        raise RuntimeError("Required main-game consumer failed or was not exercised")
    failures = sum(row.get("status") != "passed" for row in rows)
    if failures or data.get("failures") != 0 or data.get("checks") != len(rows) or len(rows) != int(marker.group(1)):
        raise RuntimeError("Runtime main-game assertion ledger disagrees with completion marker")
    ends = data.get("ends", [])
    if len(ends) != 3 or [row.get("reason") for row in ends] != ["failure", "delivery_complete", "failure"]:
        raise RuntimeError("Actual abandon/native-victory/fatal lifecycle sequence incomplete")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--skip-import", action="store_true")
    args = parser.parse_args()
    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=False)
    report = {"schema":"gunman/mapgen-main-wrapper/v1", "status":"running", "seed":930001,
              "import_budget_seconds":90, "runtime_budget_seconds":180,
              "whole_map_continuous_traversal":"NOT_RUN", "human_playtest":False,
              "scope":"Ordinary main-game Title/Home/BEGIN/retry GUI and native hosted-player lifecycle; explicit fixtures labelled"}
    started = time.monotonic()
    try:
        with (output_dir / "native.log").open("w") as log, contextlib.redirect_stdout(Tee(sys.stdout, log)):
            report["source_commit"] = git_identity()
            if not args.skip_import:
                imported = run_engine(["--headless", "--audio-driver", "Dummy", "--path", ".", "--editor", "--quit"], 90)
                if ERROR.search(imported):
                    raise RuntimeError("Unexpected main-game import error")
            before = manifest()
            (output_dir / "source-before.json").write_text(json.dumps(before, indent=2) + "\n")
            error = None
            try:
                text = run_engine(["--headless", "--audio-driver", "Dummy", "--fixed-fps", "60",
                                   "--resolution", "1280x720", "--path", ".", "--script", "tests/mapgen_main_runner.gd",
                                   "--", "--output=" + str(output_dir / "runtime.json")], 180)
            except (OSError, RuntimeError, subprocess.TimeoutExpired) as caught:
                error, text = caught, ""
            after = manifest()
            (output_dir / "source-after.json").write_text(json.dumps(after, indent=2) + "\n")
            report["source_stable"] = before == after
            if (output_dir / "runtime.json").is_file():
                data = json.loads((output_dir / "runtime.json").read_text())
                report.update(checks=data.get("checks"), failures=data.get("failures"))
            else:
                data = {}
            if error is not None:
                raise error
            if not report["source_stable"]:
                raise RuntimeError("Actual runtime/test/assets source changed during main-game acceptance run")
            if ERROR.search(text):
                raise RuntimeError("Unexpected main-game runtime or teardown error")
            verify(data, text)
            report["status"] = "passed"
            print("PASS: ordinary main-game fixed-map route and scoped native lifecycle; whole-map continuous traversal NOT_RUN")
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        report.update(status="failed", error=str(error))
        raise
    finally:
        report["elapsed_seconds"] = time.monotonic() - started
        (output_dir / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"Main-game fixed-map verification failed: {error}", file=sys.stderr)
        sys.exit(1)
