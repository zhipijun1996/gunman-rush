#!/usr/bin/env python3
"""Run fixed seed 930001 through the native player and physics server.

Caller owns the sole Godot lease. Sweeps and fixture placements are explicitly
scoped diagnostics; passing them never claims whole-map continuous traversal.
A failed run always retains its native log and partial report in a new directory.
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

from run_tests import run_engine

ROOT = Path(__file__).resolve().parents[1]
SUITES = ("all", "inventory", "controls", "spawn", "seams", "seals", "mechanisms", "rewards", "boss")
MARKER = re.compile(r"^MAPGEN DELIVERY: ([1-9]\d*) checks, (\d+) failures$", re.M)
ERROR = re.compile(r"(?m)^(?:SCRIPT |SHADER )?ERROR:|Parse Error:|ObjectDB.*leaked|resources? still in use at exit")


class Tee:
    def __init__(self, terminal, log):
        self.terminal, self.log = terminal, log

    def write(self, value):
        self.log.write(value)
        self.log.flush()
        return self.terminal.write(value)

    def flush(self):
        self.log.flush()
        self.terminal.flush()


def source_manifest():
    """Hash actual runtime/test files, avoiding lazy history/media downloads."""
    paths = [ROOT / "project.godot", ROOT / "tools/run_mapgen_delivery_tests.py"]
    for directory in ("scripts", "scenes", "resources", "config", "assets", "shaders", "third_party/mapgen/0.1.0"):
        paths.extend(p for p in (ROOT / directory).rglob("*") if p.is_file()
                     and p.suffix not in (".uid", ".import", ".pyc") and ".godot" not in p.parts
                     and "__pycache__" not in p.parts)
    paths.extend((ROOT / "tests" / name) for name in ("mapgen_delivery_tests.gd", "audio_teardown.gd"))
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(set(paths))}


def git_identity():
    result = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True,
                            text=True, check=True)
    return result.stdout.strip()


def check_coverage(data, suite):
    rows = data.get("cases", [])
    ids = [row.get("id") for row in rows]
    if len(ids) != len(set(ids)):
        raise RuntimeError("Duplicate runtime case IDs")
    if data.get("suite") != suite or data.get("seed") != 930001:
        raise RuntimeError("Runtime suite/seed mismatch")
    if data.get("whole_map_continuous_traversal") != "NOT_RUN":
        raise RuntimeError("Diagnostic suite cannot certify whole-map traversal")
    required = {"host/audio_teardown"}
    if suite in ("all", "inventory"):
        required |= {"inventory/counts", "inventory/preserved_contents", "inventory/shared_player_identity"}
        required |= {f"inventory/origin/M{i:02}" for i in range(1, 47)}
        required |= {f"inventory/unique_terrain/M{i:02}" for i in range(1, 47)}
    if suite in ("all", "controls"):
        required |= {"controls/helper_input_isolation", "controls/map_native_open", "controls/map_native_close",
                     "controls/pause_native_open", "controls/pause_native_close", "controls/native_motor_resumes", "controls/fresh_key_after_resume", "controls/fresh_mouse_after_resume"}
    if suite in ("all", "spawn"):
        required |= {"spawn/settled", "spawn/native_bell_projectile", "spawn/M01.exit-to-M02.R"}
    fixed = json.loads((ROOT / "third_party/mapgen/0.1.0/maps/seed-930001.json").read_text())
    if suite in ("all", "seams"):
        required |= {f"seam/direction/{c['id']}" for c in fixed["connections"]}
        # Fixed-map receiver landings independently enumerated from the first
        # exact corridor sweep; all-dev01 preserves their original obstruction.
        landings = (("C003",1),("C008",0),("C011",1),("C015",1),("C021",1),("C025",1),("C029",1))
        required |= {f"seam/{probe}/{connection}/{direction}" for probe in ("landing","dropthrough") for connection,direction in landings}
        specs = {instance["id"]: instance for instance in fixed["instances"]}
        for c in fixed["connections"]:
            endpoints = (c["a"], c["b"])
            for index in range(2):
                source, dest = endpoints[index], endpoints[1 - index]
                a = next(p for p in specs[source["instance_id"]]["ports"] if p["id"] == source["port_id"])
                b = next(p for p in specs[dest["instance_id"]]["ports"] if p["id"] == dest["port_id"])
                if a["permission"] in ("OUTPUT", "INOUT") and b["permission"] in ("INPUT", "INOUT"):
                    required.add(f"seam/{c['id']}/{index}")
    if suite in ("all", "seals"):
        required |= {f"seal/{i['id']}/{s['port_id']}" for i in fixed["instances"] for s in i["seals"]}
    if suite in ("all", "rewards"):
        for instance in fixed["instances"]:
            content = json.loads((ROOT / "third_party/mapgen/0.1.0" / instance["content_ref"]).read_text())
            for reward in content["reward_sites"]:
                required.add(f"reward/supported_fixture/{instance['id']}/{reward['id']}")
                required.add(f"reward/physical_claim/{instance['id']}/{reward['id']}")
                required.add(f"reward/no_duplicate/{instance['id']}/{reward['id']}")
        required.add("reward/instance_isolation")
        required |= {f"reward/{probe}/{instance}" for probe in ("reload_saved","reload_scope_refusal","reload_bound","reload_no_regrant") for instance in ("M41","M43")}
        required.add("reward/reload_dynamic_rejected")
        required |= {f"reward/M29/{probe}/{kind}" for probe in ("native_W_offer", "modal_input_ownership", "native_OR_claim", "native_OR_idempotence") for kind in ("coin", "note")}
    if suite in ("all", "mechanisms"):
        for instance in fixed["instances"]:
            content = json.loads((ROOT / "third_party/mapgen/0.1.0" / instance["content_ref"]).read_text())
            required |= {f"mechanism/terrain/{instance['id']}/{index}" for index in range(len(content["platforms"]))}
            required |= {f"mechanism/latch/{instance['id']}/{latch['id']}" for latch in content["latches"]}
            required |= {f"mechanism/motion/{instance['id']}/{raw['platform_id']}/{sample}" for raw in content["moving_platforms"] for sample in range(3)}
        required.add("mechanism/mirrored_projectile/M20/return-catch")
    if suite in ("all", "boss"):
        required |= {"boss/bound_native_system", "boss/arrival_trigger", "boss/native_projectile_damage",
                     "boss/native_battle_victory", "boss/exit_stays_sealed_after_victory", "boss/same_frame_death_priority", "boss/exit_stays_sealed_after_cancel"}
    if required - set(ids):
        raise RuntimeError(f"Missing independently enumerated cases: {sorted(required - set(ids))}")
    by_id = {row["id"]: row for row in rows}
    incomplete = sorted(identity for identity in required if by_id[identity].get("status") != "passed")
    if incomplete:
        raise RuntimeError(f"Required probes failed or remain unverified: {incomplete}")
    actual_assertions = [r for r in rows if r.get("status") in ("passed", "failed")]
    if data.get("checks") != len(actual_assertions):
        raise RuntimeError("Runtime assertion count differs from case ledger")
    actual_failures = [r for r in rows if r.get("status") == "failed"]
    if data.get("failures") != len(actual_failures):
        raise RuntimeError("Runtime failure count differs from case ledger")
    if actual_failures:
        raise RuntimeError(f"{len(actual_failures)} actual runtime failures")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", choices=SUITES, default="all")
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--skip-import", action="store_true")
    args = parser.parse_args()
    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=False)
    report = {"schema":"gunman/mapgen-test-wrapper/v1", "suite":args.suite, "seed":930001,
              "status":"running", "import_budget_seconds":90, "runtime_budget_seconds":180,
              "whole_map_continuous_traversal":"NOT_RUN", "human_playtest":False,
              "scope":"Native player collision, scoped fixture probes and continuous spawn segment; no whole-map certification"}
    started = time.monotonic()
    try:
        with (output_dir / "native.log").open("w") as log, contextlib.redirect_stdout(Tee(sys.stdout, log)):
            report["source_commit"] = git_identity()
            if not args.skip_import:
                text = run_engine(["--headless", "--audio-driver", "Dummy", "--path", ".", "--editor", "--quit"], 90)
                if ERROR.search(text):
                    raise RuntimeError("Unexpected native import error")
            before = source_manifest()
            (output_dir / "source-before.json").write_text(json.dumps(before, indent=2) + "\n")
            runtime_error = None
            try:
                text = run_engine(["--headless", "--audio-driver", "Dummy", "--fixed-fps", "60", "--resolution", "1280x720",
                                   "--path", ".", "--script", "tests/mapgen_delivery_tests.gd", "--",
                                   "--suite=" + args.suite, "--output=" + str(output_dir / "runtime.json")], 180)
            except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
                runtime_error = error
                text = ""
            after = source_manifest()
            report["source_stable"] = before == after
            (output_dir / "source-after.json").write_text(json.dumps(after, indent=2) + "\n")
            if (output_dir / "runtime.json").is_file():
                data = json.loads((output_dir / "runtime.json").read_text())
                report.update(checks=data.get("checks"), failures=data.get("failures"),
                              unverified=[r["id"] for r in data.get("cases", []) if r.get("status") == "unverified"])
            else:
                data = {}
            if runtime_error:
                raise runtime_error
            if not report["source_stable"]:
                raise RuntimeError("Runtime/test source changed during native acceptance run")
            if ERROR.search(text):
                raise RuntimeError("Unexpected native runtime error")
            marker = MARKER.search(text)
            if marker is None or int(marker.group(2)) != 0:
                raise RuntimeError("Missing complete nonzero zero-failure completion marker")
            if data.get("checks") != int(marker.group(1)):
                raise RuntimeError("Marker differs from runtime report")
            check_coverage(data, args.suite)
            report["status"] = "passed"
            print("PASS: scoped mapgen delivery probes; whole-map end-to-end remains NOT_RUN")
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
        print(f"Mapgen delivery verification failed: {error}", file=sys.stderr)
        sys.exit(1)
