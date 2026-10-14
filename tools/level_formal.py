"""Thin live-DemoApp capture runner for the existing Level Design Harness.

Process success means capture integrity. Route failure/death remains evidence and
is never translated to a passing traversal claim. No production gameplay edits.
"""
from __future__ import annotations
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import io
import tarfile
from functools import lru_cache
import json
from pathlib import Path
import re
import subprocess
import os
import signal
import time
from level_design import ROOT, read, write, file_hash, engine_log_matches


def source_files():
    paths = [ROOT / "project.godot", Path(__file__).resolve(), ROOT / "tools/level_formal_capture.gd", ROOT / "tools/level_capability_snapshot.gd"]
    for folder in ("scripts", "scenes", "resources", "config"):
        paths.extend(p for p in (ROOT / folder).rglob("*") if p.is_file() and p.suffix in {".gd", ".tscn", ".tres", ".json", ".gdshader"})
    paths.extend((ROOT / "tests").glob("*.gd"))
    return {p.relative_to(ROOT).as_posix(): file_hash(p) for p in sorted(set(paths))}


def command_for(data, output, frame_dir="", frame_stride=120, visible=False, realtime=False):
    command = ["bash", "tools/godot.sh"]
    if not visible: command += ["--headless"]
    if not realtime: command += ["--fixed-fps", "60"]
    command += ["--path", ".", "--script", "tools/level_formal_capture.gd", "--",
                f"--source-commit={data['source_commit']}", f"--seed={data['root_seed']}",
                f"--strategy={data['strategy']}", f"--map-index={data['map_index']}",
                f"--phase-wait-ticks={data['phase_wait_ticks']}", f"--max-ticks={data['max_ticks']}",
                "--output=res://" + output.relative_to(ROOT).as_posix()]
    if visible: command += ["--capture-visible"]
    if frame_dir: command += ["--frame-dir=" + str(frame_dir), "--frame-stride=" + str(frame_stride)]
    return command


def validate_capture(path, data, receipt, log, current_sources=None, legacy_migration=None):
    """Local consistency only, never external authentication or route acceptance."""
    errors = []
    path = Path(path).resolve(); log = Path(log)
    if receipt.get("schema_version") == 1:
        errors.extend(validate_legacy_migration(path, receipt, legacy_migration))
    elif receipt.get("schema_version") == 2:
        if receipt.get("status") != "accepted" or receipt.get("errors") != []:
            errors.append("receipt is not an accepted terminal capture")
        if not receipt.get("source_before") or receipt.get("source_before") != receipt.get("source_after") or receipt.get("source_before") != receipt.get("source_files"):
            errors.append("capture source drift or incomplete source snapshots")
    else:
        errors.append("wrong receipt schema")
    errors.extend(_validate_capture_payload(path, data, receipt, log, current_sources))
    return errors


def _validate_capture_payload(path, data, receipt, log, current_sources=None):
    """Producer finalization only: terminal status is checked by the public API."""
    errors = []
    if not path.is_relative_to(ROOT / "build"): errors.append("capture outside build")
    if data.get("artifact_kind") != "formal_level_capture" or data.get("schema_version") != 1: errors.append("wrong formal capture schema")
    if receipt.get("scope") != "actual_live_demo_app_capture": errors.append("wrong receipt scope")
    if type(receipt.get("exit_code")) is not int or receipt["exit_code"] != 0: errors.append("nonzero or missing process exit")
    if not path.is_file() or receipt.get("capture_sha256") != file_hash(path) or receipt.get("capture") != str(path.relative_to(ROOT)): errors.append("capture mismatch")
    if receipt.get("source_commit") != data.get("source_commit"): errors.append("source mismatch")
    if not receipt.get("source_files") or receipt.get("source_files") != (source_files() if current_sources is None else current_sources): errors.append("source snapshot mismatch")
    for source, digest in data.get("capture_source_hashes", {}).items():
        if receipt.get("source_files", {}).get(source.removeprefix("res://")) != digest:
            errors.append("observer source mismatch/" + source)
    request = receipt.get("request", {})
    for key in ("root_seed", "map_index", "strategy", "phase_wait_ticks"):
        if request.get(key) != data.get(key): errors.append("request mismatch/" + key)
    try:
        expected = command_for(request, path, receipt.get("frame_dir", ""), receipt.get("frame_stride", 120), receipt.get("visible", False), receipt.get("realtime", False))
        if receipt.get("command") != expected: errors.append("unexpected producer command")
    except (KeyError, TypeError, ValueError): errors.append("malformed producer request")
    frames = data.get("frames", [])
    if not frames or not isinstance(frames, list) or data.get("capture_errors") != []: errors.append("empty/incomplete capture")
    if not isinstance(data.get("manifest"), dict) or data.get("manifest_hash") != data.get("manifest", {}).get("manifest_hash"): errors.append("manifest identity mismatch")
    scope = data.get("captured_scope", {})
    if any(scope.get(k) is not True for k in ("enemies_instantiated", "enemy_attacks_enabled", "enemy_contacts_enabled", "production_rewards_enabled", "production_camera_enabled")): errors.append("missing formal systems")
    if any(scope.get(k) is not False for k in ("controller_manual_step", "actor_teleport_by_driver", "resource_injection", "enemy_disable")): errors.append("altered formal runtime")
    if data.get("outcome") == "route_target_reached" and data.get("route_reached") is not True: errors.append("route outcome mismatch")
    if not log.is_file() or receipt.get("log_sha256") != file_hash(log): errors.append("missing or changed log")
    else:
        text = log.read_text()
        marks = re.findall(r"^LEVEL FORMAL CAPTURE: (\d+) frames, (\d+) edges, outcome=(\S+), capture_errors=(\d+)$", text, re.M)
        if marks != [(str(len(frames)), str(len(data.get("edges", []))), str(data.get("outcome")), "0")]: errors.append("completion marker mismatch")
        if not engine_log_matches(data.get("engine"), text): errors.append("engine mismatch")
        if re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script", text): errors.append("script error")
    return errors


def _write_receipt(path, receipt):
    """Atomic local state replacement; interrupted producers remain running."""
    temp = path.with_suffix(path.suffix + ".tmp")
    write(temp, receipt)
    temp.replace(path)


def capture_one(seed, map_index, strategy, output, phase_wait_ticks=0, max_ticks=18000, visible=False, frame_dir="", frame_stride=120, realtime=False, timeout=240):
    output = Path(output).resolve()
    if not output.is_relative_to(ROOT / "build"): raise ValueError("Write captures under repository build/")
    output.parent.mkdir(parents=True, exist_ok=True)
    receipt_path = output.with_suffix(".invocation.json")
    log = output.with_suffix(".log")
    if any(p.exists() for p in (output, receipt_path, log)):
        raise ValueError("Do not overwrite retained capture/receipt/log; choose a new output path")
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    request = dict(source_commit=commit, root_seed=seed, map_index=map_index, strategy=strategy, phase_wait_ticks=phase_wait_ticks, max_ticks=max_ticks)
    command = command_for(request, output, frame_dir, frame_stride, visible, realtime)
    before = source_files()
    receipt = dict(schema_version=2, status="running", errors=["capture has not completed"], scope="actual_live_demo_app_capture", source_commit=commit,
                   source_files=before, source_before=before, source_after=None, request=request, command=command,
                   capture=str(output.relative_to(ROOT)), visible=visible, realtime=realtime, frame_dir=str(frame_dir), frame_stride=frame_stride)
    _write_receipt(receipt_path, receipt)
    started = time.monotonic(); errors = []; data = {}
    try:
        with log.open("w") as stream:
            process = subprocess.Popen(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
            deadline = started + timeout
            try:
                while process.poll() is None:
                    text = log.read_text(errors="replace")
                    if re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script", text):
                        errors.append("script/shader failure; terminated immediately")
                        break
                    if time.monotonic() >= deadline:
                        errors.append("process timeout")
                        break
                    time.sleep(0.1)
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    try: process.wait(timeout=2)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait(timeout=5)
                receipt["exit_code"] = process.returncode
        receipt.update(log_sha256=file_hash(log), capture_sha256=file_hash(output) if output.is_file() else None)
        if receipt["exit_code"] != 0 or not output.is_file():
            errors.append("capture process failed or output missing")
        else:
            data = read(output)
            if not isinstance(data, dict) or not data: raise ValueError("capture must be a nonempty object")
    except BaseException as exc:
        errors.append("capture exception: " + type(exc).__name__ + ": " + str(exc))
        if not isinstance(exc, Exception): raise
    finally:
        try:
            receipt["source_after"] = source_files()
            if before != receipt["source_after"]: errors.append("source snapshot changed during capture")
            if data:
                errors.extend(_validate_capture_payload(output, data, receipt, log, receipt["source_after"]))
        except Exception as exc:
            errors.append("capture validation exception: " + str(exc))
        receipt.update(wall_seconds=time.monotonic()-started, status="rejected" if errors else "accepted", errors=errors)
        _write_receipt(receipt_path, receipt)
    return {"capture":str(output.relative_to(ROOT)), "captured":not errors, "errors":errors, "outcome":data.get("outcome"), "route_reached":data.get("route_reached",False), "seed":seed, "map_index":map_index, "strategy":strategy, "phase_wait_ticks":phase_wait_ticks, "frames":len(data.get("frames",[])), "wall_seconds":receipt["wall_seconds"]}


@lru_cache(maxsize=8)
def _frozen_sources(commit, paths):
    """Hash actual immutable Git blobs; never bless receipt-provided digests."""
    if not re.fullmatch(r"[0-9a-f]{40}", commit): raise ValueError("full frozen commit required")
    tree_paths = subprocess.check_output(["git", "ls-tree", "-r", "--name-only", commit], cwd=ROOT, text=True).splitlines()
    fixed = {"project.godot", "tools/level_formal.py", "tools/level_formal_capture.gd", "tools/level_capability_snapshot.gd"}
    expected = {name for name in tree_paths if name in fixed or
                (name.split("/")[0] in ("scripts", "scenes", "resources", "config") and Path(name).suffix in {".gd", ".tscn", ".tres", ".json", ".gdshader"}) or
                (Path(name).parent.as_posix() == "tests" and name.endswith(".gd"))}
    if set(paths) != expected: raise ValueError("incomplete frozen source inventory")
    raw = subprocess.check_output(["git", "archive", "--format=tar", commit, "--", *paths], cwd=ROOT)
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        found = {member.name: hashlib.sha256(archive.extractfile(member).read()).hexdigest()
                 for member in archive.getmembers() if member.isfile()}
    if set(found) != set(paths): raise ValueError("frozen tree source files missing")
    return found


def find_legacy_migration(path):
    path = Path(path).resolve()
    if not path.is_relative_to(ROOT / "build"): return None
    for parent in path.parents:
        candidate = parent / "batch.migration.json"
        if candidate.is_file(): return candidate
        if parent == ROOT / "build": break
    return None


def _legacy_entry(path, batch_case, frozen_sources):
    receipt_path = path.with_suffix(".invocation.json"); log = path.with_suffix(".log")
    receipt = read(receipt_path); data = read(path)
    if receipt.get("schema_version") != 1: raise ValueError("migration only accepts original schema1 receipts")
    if receipt.get("error") or receipt.get("status") in ("rejected", "running") or receipt.get("errors", []) != []:
        raise ValueError("legacy receipt records failure/incompletion")
    if batch_case.get("captured") is not True or batch_case.get("errors") != []:
        raise ValueError("batch did not accept this original capture")
    for field, capture_field in (("seed", "root_seed"), ("map_index", "map_index"), ("strategy", "strategy"), ("phase_wait_ticks", "phase_wait_ticks"), ("outcome", "outcome"), ("route_reached", "route_reached")):
        if batch_case.get(field) != data.get(capture_field): raise ValueError("legacy batch result mismatch/" + field)
    if batch_case.get("frames") != len(data.get("frames", [])): raise ValueError("legacy batch frame count mismatch")
    errors = _validate_capture_payload(path, data, receipt, log, frozen_sources)
    observers = data.get("capture_source_hashes")
    required = {"res://tools/level_formal_capture.gd", "res://tests/level_formal_trace.gd"}
    if not isinstance(observers, dict) or not required.issubset(observers): errors.append("missing legacy observer source hashes")
    if errors: raise ValueError("; ".join(errors))
    return {"capture": str(path.relative_to(ROOT)), "capture_sha256": file_hash(path), "receipt_sha256": file_hash(receipt_path), "log_sha256": file_hash(log), "source_commit": receipt["source_commit"]}


def _migration_context(batch_path, frozen_commit):
    batch_path = Path(batch_path).resolve()
    if not batch_path.is_relative_to(ROOT / "build"): raise ValueError("legacy batch outside build")
    batch = read(batch_path); cases = batch.get("cases")
    if batch.get("artifact_kind") != "formal_capture_batch" or batch.get("schema_version") != 1 or not isinstance(cases, list) or not cases:
        raise ValueError("missing original completed batch")
    if batch.get("requested_cases") != len(cases) or batch.get("captured_cases") != len(cases): raise ValueError("legacy batch incomplete")
    paths = [(ROOT / case["capture"]).resolve() for case in cases]
    if len(set(paths)) != len(paths) or any(not path.is_relative_to(batch_path.parent) for path in paths): raise ValueError("invalid or duplicate batch capture path")
    receipt = read(paths[0].with_suffix(".invocation.json"))
    expected = receipt.get("source_files")
    if not isinstance(expected, dict) or not expected: raise ValueError("empty legacy source snapshot")
    frozen = _frozen_sources(frozen_commit, tuple(sorted(expected)))
    if expected != frozen: raise ValueError("legacy source does not match frozen Git tree")
    return batch, paths, frozen


def migrate_legacy_batch(batch_path, frozen_commit, output=None):
    """Explicit local evidence migration; original captures and receipts stay intact."""
    batch_path = Path(batch_path).resolve()
    output = Path(output).resolve() if output else batch_path.with_name("batch.migration.json")
    if output.exists(): raise ValueError("do not overwrite a retained migration sidecar")
    if output != batch_path.with_name("batch.migration.json"): raise ValueError("migration belongs beside its original batch")
    frozen_commit = subprocess.check_output(["git", "rev-parse", frozen_commit + "^{commit}"], cwd=ROOT, text=True).strip()
    batch, paths, frozen = _migration_context(batch_path, frozen_commit)
    entries = [_legacy_entry(path, case, frozen) for path, case in zip(paths, batch["cases"])]
    result = {"schema_version":1, "artifact_kind":"formal_capture_legacy_migration", "status":"accepted", "errors":[],
              "scope":"Historical capture integrity only; original source_commit and schema1 receipts retained, not a new engine run",
              "batch":str(batch_path.relative_to(ROOT)), "batch_sha256":file_hash(batch_path), "frozen_source_commit":frozen_commit,
              "source_snapshot":frozen, "cases":entries}
    write(output, result)
    return result


def validate_legacy_migration(path, receipt, migration):
    if migration is None: return ["schema1 receipt requires explicit validated legacy migration"]
    try:
        sidecar = read(Path(migration))
        if sidecar.get("artifact_kind") != "formal_capture_legacy_migration" or sidecar.get("schema_version") != 1 or sidecar.get("status") != "accepted" or sidecar.get("errors") != []:
            raise ValueError("migration is not an accepted terminal record")
        batch_path = (ROOT / sidecar["batch"]).resolve()
        if Path(migration).resolve() != batch_path.with_name("batch.migration.json"): raise ValueError("migration path mismatch")
        if file_hash(batch_path) != sidecar.get("batch_sha256"): raise ValueError("original batch changed")
        batch, paths, frozen = _migration_context(batch_path, sidecar["frozen_source_commit"])
        if sidecar.get("source_snapshot") != frozen or receipt.get("source_files") != frozen: raise ValueError("migration source snapshot mismatch")
        entries = sidecar.get("cases")
        if not isinstance(entries, list) or [entry.get("capture") for entry in entries] != [case["capture"] for case in batch["cases"]]: raise ValueError("migration membership mismatch")
        if path not in paths: raise ValueError("capture was not in validated legacy batch")
        index = paths.index(path)
        if entries[index] != _legacy_entry(path, batch["cases"][index], frozen): raise ValueError("original capture, receipt or log changed")
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as exc:
        return ["legacy migration rejected: " + str(exc)]
    return []


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", default="level-design-v2-baseline")
    parser.add_argument("--seed-count", type=int, default=1)
    parser.add_argument("--maps", nargs="+", type=int, choices=(1,2), default=[1])
    parser.add_argument("--strategies", nargs="+", choices=("fast","growth","deep","return"), default=["fast"])
    parser.add_argument("--phase-wait-ticks", type=int, default=0)
    parser.add_argument("--max-ticks", type=int, default=18000)
    parser.add_argument("--output", default="build/level_formal/baseline")
    parser.add_argument("--jobs", type=int, default=1)
    parser.add_argument("--capture-visible", action="store_true")
    parser.add_argument("--frame-stride", type=int, default=120)
    parser.add_argument("--real-time", action="store_true")
    parser.add_argument("--timeout", type=int, default=240)
    args=parser.parse_args(argv)
    if not 1<=args.seed_count<=100 or not 1<=args.jobs<=4: parser.error("bounded seed-count 1..100 and jobs 1..4 required")
    if args.capture_visible and args.jobs!=1: parser.error("visible capture is serial")
    folder=Path(args.output).resolve();folder.mkdir(parents=True,exist_ok=True)
    requests=[]
    for index in range(args.seed_count):
        seed=args.seed if index==0 else f"{args.seed}/{index:02d}"
        for m in args.maps:
            for strategy in args.strategies:
                target=folder/f"seed_{index:02d}"/f"map_{m}"/strategy/"capture.json"
                requests.append((seed,m,strategy,target))
    def run(item):
        seed,m,strategy,target=item
        value=capture_one(seed,m,strategy,target,args.phase_wait_ticks,args.max_ticks,args.capture_visible,str(target.parent/"frames") if args.capture_visible else "",args.frame_stride,args.real_time,args.timeout)
        print(json.dumps(value,ensure_ascii=False),flush=True)
        return value
    with ThreadPoolExecutor(max_workers=args.jobs) as executor: results=list(executor.map(run,requests))
    summary={"schema_version":1,"artifact_kind":"formal_capture_batch","requested_cases":len(requests),"captured_cases":sum(x['captured'] for x in results),"routes_reached":sum(x.get('route_reached',False) for x in results),"cases":results,"scope":"Live formal runtime observations; failed policy/death retained; not all-player reachability or fun"}
    write(folder/"batch.json",summary)
    print(f"FORMAL CAPTURE BATCH: {summary['captured_cases']}/{len(results)} captured; {summary['routes_reached']} route targets reached")
    return 0 if all(x['captured'] for x in results) else 1

if __name__=="__main__": raise SystemExit(main())
