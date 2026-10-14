"""Thin live-DemoApp capture runner for the existing Level Design Harness.

Process success means capture integrity. Route failure/death remains evidence and
is never translated to a passing traversal claim. No production gameplay edits.
"""
from __future__ import annotations
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
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


def validate_capture(path, data, receipt, log, current_sources=None):
    """Local consistency only, never external authentication or route acceptance."""
    errors = []
    path = Path(path).resolve(); log = Path(log)
    if not path.is_relative_to(ROOT / "build"): errors.append("capture outside build")
    if data.get("artifact_kind") != "formal_level_capture" or data.get("schema_version") != 1: errors.append("wrong formal capture schema")
    if receipt.get("scope") != "actual_live_demo_app_capture" or receipt.get("schema_version") != 1: errors.append("wrong receipt scope")
    if type(receipt.get("exit_code")) is not int or receipt["exit_code"] != 0: errors.append("nonzero or missing process exit")
    if receipt.get("capture_sha256") != file_hash(path) or receipt.get("capture") != str(path.relative_to(ROOT)): errors.append("capture mismatch")
    if receipt.get("source_commit") != data.get("source_commit"): errors.append("source mismatch")
    if not receipt.get("source_files") or receipt.get("source_files") != (source_files() if current_sources is None else current_sources): errors.append("source snapshot mismatch")
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


def capture_one(seed, map_index, strategy, output, phase_wait_ticks=0, max_ticks=18000, visible=False, frame_dir="", frame_stride=120, realtime=False, timeout=240):
    output = Path(output).resolve()
    if not output.is_relative_to(ROOT / "build"): raise ValueError("Write captures under repository build/")
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists(): raise ValueError("Do not overwrite retained capture; choose a new output path")
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    request = dict(source_commit=commit, root_seed=seed, map_index=map_index, strategy=strategy, phase_wait_ticks=phase_wait_ticks, max_ticks=max_ticks)
    command = command_for(request, output, frame_dir, frame_stride, visible, realtime)
    receipt = dict(schema_version=1, scope="actual_live_demo_app_capture", source_commit=commit, source_files=source_files(), request=request, command=command, capture=str(output.relative_to(ROOT)), visible=visible, realtime=realtime, frame_dir=str(frame_dir), frame_stride=frame_stride)
    log = output.with_suffix(".log"); started=time.monotonic()
    with log.open("w") as stream:
        process = subprocess.Popen(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
        deadline = started + timeout
        try:
            while process.poll() is None:
                text = log.read_text(errors="replace")
                if re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script", text):
                    receipt["error"] = "script/shader failure; terminated immediately"
                    break
                if time.monotonic() >= deadline:
                    receipt["error"] = "process timeout"
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
    receipt.update(wall_seconds=time.monotonic()-started, log_sha256=file_hash(log), capture_sha256=file_hash(output) if output.exists() else None)
    write(output.with_suffix(".invocation.json"), receipt)
    if receipt["exit_code"] != 0 or not output.exists():
        return {"capture":str(output.relative_to(ROOT)), "captured":False, "errors":[receipt.get("error", "capture process failed")], "wall_seconds":receipt["wall_seconds"]}
    data = read(output)
    errors = validate_capture(output, data, receipt, log)
    return {"capture":str(output.relative_to(ROOT)), "captured":not errors, "errors":errors, "outcome":data["outcome"], "route_reached":data.get("route_reached",False), "seed":seed, "map_index":map_index, "strategy":strategy, "phase_wait_ticks":phase_wait_ticks, "frames":len(data["frames"]), "wall_seconds":receipt["wall_seconds"]}


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
