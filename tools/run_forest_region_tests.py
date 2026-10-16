"""Run the actual short-H Motor golden and real-node negative cases.

Whole-region traversal is reported separately; this golden cannot prove it.
"""
from __future__ import annotations
import argparse
import copy
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
CASES = ("positive", "mirror", "miss", "blocked", "dead-anchor", "no-hook")
ERRORS = re.compile(r"ERROR:|Parse Error:|ObjectDB.*leaked|resources? still in use at exit")


def validate_capture(data: dict) -> list[str]:
    errors = []
    frames = data.get("frames", [])
    events = data.get("events", [])
    snapshot = data.get("initial_snapshot", {})
    final = data.get("final_snapshot", {})
    if data.get("scope") != "real_short_H_golden_not_whole_region":
        errors.append("wrong proof scope")
    if data.get("midroute_position_or_resource_injection") is not False or data.get("manual_motor_step") is not False:
        errors.append("injected or manual Motor state")
    if not frames or any(f.get("tick") != i + 1 or f.get("motor_steps_this_tick") != 1 for i, f in enumerate(frames)):
        errors.append("noncontinuous normal Motor trace")
    for kind in ("hook_cast", "hook_fly", "hook_pull", "hook_contact_kick", "hook_kick"):
        matches = [e for e in events if e.get("kind") == kind]
        if not matches or any(not 1 <= e.get("tick", 0) <= len(frames) for e in matches):
            errors.append("missing accepted " + kind)
    rect = data.get("geometry", {}).get("branch", [])
    def actual_full_branch(frame):
        position = frame.get("position", [])
        return len(rect) == 4 and len(position) == 2 and position[0]-12 >= rect[0] and position[0]+12 <= rect[0]+rect[2] and abs(position[1]+18-rect[1]) < 1
    branches = [f for f in frames if f.get("grounded") and "CanopyBranch" in f.get("supports", []) and actual_full_branch(f)]
    if any(math.dist(a.get("position", [0, 0]), b.get("position", [0, 0])) > 30 for a, b in zip(frames, frames[1:])):
        errors.append("impossible continuous displacement")
    returns = [f for f in frames if f.get("phase") == "return" and f.get("grounded") and "RootLanding" in f.get("supports", [])]
    if len(branches) < 12 or not any(all(branches[i+j]["tick"] == branches[i]["tick"] + j for j in range(12)) for i in range(max(0, len(branches)-11))):
        errors.append("missing actual stable full-body branch landing")
    if len(returns) < 12 or not branches or max((f["tick"] for f in returns), default=0) <= branches[-1]["tick"]:
        errors.append("missing actual continuous return support")
    spawn = data.get("geometry", {}).get("spawn", [])
    if len(spawn) != 2 or len(frames) < 12 or any(not f.get("grounded") or "RootLanding" not in f.get("supports", []) or abs(f["position"][0]-spawn[0]) >= 8 for f in frames[-12:]):
        errors.append("missing final stable entry return")
    if not data.get("branch_landed") or not data.get("returned"):
        errors.append("incomplete route")
    if snapshot.get("granted_actions") != ["jump", "shot_recoil", "grapple"]:
        errors.append("not actual H-only capability")
    if snapshot.get("config_hashes") != final.get("config_hashes") or snapshot.get("tuning") != final.get("tuning"):
        errors.append("runtime configuration changed")
    if snapshot.get("traversal_definition", {}).get("hook_range") != 231.0:
        errors.append("not current short H resource")
    if snapshot.get("shot_energy") != final.get("shot_energy"):
        errors.append("unexpected shot-energy change")
    if data.get("failures"):
        errors.extend(data["failures"])
    return errors


def validate_region_capture(data: dict) -> list[str]:
    errors = list(data.get("failures", []))
    frames, events = data.get("frames", []), data.get("events", [])
    itinerary, completed = data.get("itinerary", []), data.get("completed_legs", [])
    manifest = data.get("manifest", {})
    if data.get("scope") != "formal_DemoApp_continuous_route": errors.append("not formal DemoApp route")
    if data.get("midroute_position_or_resource_injection") is not False or data.get("manual_motor_step") is not False: errors.append("injected route")
    if not frames or any(f.get("tick") != i+1 or f.get("motor_steps_this_tick") != 1 for i,f in enumerate(frames)): errors.append("noncontinuous normal Motor trace")
    if any(math.dist(a.get("position",[0,0]), b.get("position",[0,0])) > 30 for a,b in zip(frames,frames[1:])): errors.append("impossible or respawn displacement")
    if not itinerary or len(completed) != len(itinerary): errors.append("incomplete itinerary")
    if manifest.get("region") != "thorn_forest" or manifest.get("map_index") != data.get("map_index"): errors.append("wrong formal map")
    expected_itinerary = []
    edges = {e["id"]: e for e in manifest.get("connections",[])}
    for edge_id in manifest.get("routes",{}).get(data.get("route"),[]):
        edge = edges.get(edge_id,{})
        if edge.get("kind")=="hook_steps":
            expected_itinerary += [{**step,"edge_id":edge_id,"kind":"hook"} for step in edge.get("steps",[])]
        elif edge.get("path"):
            expected_itinerary.append({"edge_id":edge_id,"kind":edge["kind"],"landing":edge["path"][-1]})
    if itinerary != expected_itinerary: errors.append("driver itinerary differs from actual manifest route")
    platforms = {p["id"]:p["rect"] for p in manifest.get("platforms", [])}
    for index, leg in enumerate(itinerary):
        receipts = [c for c in completed if c.get("leg")==index]
        if len(receipts)!=1:
            errors.append(f"leg {index} missing unique actual completion")
            continue
        receipt = receipts[0]
        end = receipt.get("tick", 0)
        window = [f for f in frames if end-11 <= f.get("tick",0) <= end]
        if len(window)!=12 or any(not f.get("grounded") or not f.get("supports") for f in window): errors.append(f"leg {index} not 12-tick actual stable support")
        if leg.get("kind")=="hook":
            rect = platforms.get(leg.get("support_id"), [])
            for frame in window:
                x,y = frame.get("position", [math.inf,math.inf])
                if len(rect)!=4 or leg.get("support_id") not in frame.get("supports",[]) or x-12 < rect[0] or x+12 > rect[0]+rect[2] or abs(y+18-rect[1]) >= 1:
                    errors.append(f"leg {index} actual full-body support differs from manifest")
                    break
            for kind in ("jumped","hook_cast","hook_fly","hook_pull","hook_contact_kick","hook_kick"):
                if not any(e.get("leg")==index and e.get("kind")==kind and 0 < e.get("tick",0) < end for e in events): errors.append(f"leg {index} missing accepted {kind}")
        else:
            x,y = leg.get("landing", [math.inf,math.inf])
            if any(abs(f["position"][0]-x)>=8 or abs(f["position"][1]-y)>=2 for f in window): errors.append(f"leg {index} arrived flag lacks actual destination")
    initial, final = data.get("initial_snapshot",{}), data.get("final_snapshot",{})
    if initial.get("granted_actions") != ["jump","shot_recoil","grapple"]: errors.append("not actual H-only entry")
    if initial.get("config_hashes") != final.get("config_hashes") or initial.get("tuning") != final.get("tuning"): errors.append("configuration changed midroute")
    if initial.get("equipped_weapon",{}).get("id") != "pulse_gun" or initial.get("equipped_weapon",{}).get("tier") != 1: errors.append("not actual single Pulse Lv1")
    if data.get("route")=="high_return":
        expected_cache = f"thorn_forest/map_{data.get('map_index')}/crown_cache"
        modal = data.get("modal_frames",[])
        pointer = data.get("reward_input_events",[])
        if not data.get("cache_interacted") or not data.get("cache_claimed") or expected_cache not in data.get("claimed_ids",[]): errors.append("cache not actually claimed and persisted")
        if len(modal)<5 or any(not f.get("paused") or not f.get("supports") or f.get("position")!=modal[0].get("position") or f.get("motor_steps")!=modal[0].get("motor_steps") for f in modal): errors.append("reward modal lacks actual frozen supported player")
        if [e.get("kind") for e in pointer] != ["mouse_button_press","mouse_button_release"]: errors.append("reward missing real pointer press/release")
        elif pointer:
            rect = pointer[0].get("actual_button_rect",[])
            x,y = pointer[0].get("position",[math.inf,math.inf])
            if len(rect)!=4 or not rect[0] <= x <= rect[0]+rect[2] or not rect[1] <= y <= rect[1]+rect[3]: errors.append("reward pointer outside actual control")
    if data.get("route") in ("fast","growth"):
        if not data.get("gate_saved_open") or not data.get("gate_shape_disabled"): errors.append("actual vine gate not open and saved")
        if not any(e.get("kind")=="hook_kick" and e.get("hook_target")=="crown_approach_ring_0" for e in events): errors.append("missing accepted actual vine anchor kick")
    reload = data.get("state_reload",{})
    if not reload.get("passed") or not reload.get("restored") or not reload.get("fresh_stage_assembled"): errors.append("fresh stage JSON persistence not proved")
    if bool(reload.get("actual_gate_shape_disabled")) != bool(reload.get("json_snapshot",{}).get("opened",{}).get("crown_vine")): errors.append("restored gate disagrees with actual saved ledger")
    if data.get("route")=="high_return":
        expected_cache = f"thorn_forest/map_{data.get('map_index')}/crown_cache"
        if not reload.get("actual_chest_claimed") or not reload.get("json_snapshot",{}).get("claimed",{}).get(expected_cache): errors.append("cache claim not restored on actual fresh stage")
    if not data.get("safe_trace"): errors.append("unsafe body sweep")
    if frames and any(f.get("enemy_count",0)<2 for f in frames): errors.append("missing actual formal enemies")
    return errors


def runtime_fingerprint() -> dict:
    paths = set()
    for directory in ("scripts","scenes","resources","config"):
        paths.update(p for p in (ROOT/directory).rglob("*") if p.is_file() and p.suffix in {".gd",".tscn",".tres",".json"})
    paths.update((ROOT/"assets").rglob("*.gd"))
    paths.update(ROOT/p for p in ("project.godot","tests/forest_region_trace.gd","tests/forest_region_runner.gd","tools/run_forest_region_tests.py","tests/test_forest_vine_gate.gd"))
    return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--skip-import", action="store_true")
    parser.add_argument("--region-matrix", action="store_true")
    parser.add_argument("--seed-count", type=int, default=10)
    parser.add_argument("--seed-prefix", default="forest-playable-")
    parser.add_argument("--case", choices=CASES, action="append")
    args = parser.parse_args()
    if not 1 <= args.seed_count <= 10: parser.error("seed-count must be 1..10")
    folder = (args.output_dir or ROOT / "build/forest_playable/traversal" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%f")).resolve()
    if not folder.is_relative_to(ROOT / "build") or folder.exists():
        raise ValueError("output must be a fresh build directory")
    folder.mkdir(parents=True)
    summary = {"scope": "real_short_H_golden_not_whole_region", "cases": [], "status": "running", "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()}
    def save():
        (folder / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    def run(argv, logfile, timeout):
        started = time.monotonic()
        with logfile.open("w") as log:
            try:
                result = subprocess.run(argv, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
                code = result.returncode
            except subprocess.TimeoutExpired:
                code = 124
        return {"argv": argv, "exit_code": code, "seconds": round(time.monotonic()-started, 3), "log": str(logfile.relative_to(ROOT)), "log_sha256": hashlib.sha256(logfile.read_bytes()).hexdigest()}
    save()
    lock_path = ROOT / "build/verification/engine.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if not args.skip_import:
            receipt = run(["bash","tools/godot.sh","--headless","--path",".","--editor","--quit"],folder / "import.log",120)
            summary["import"] = receipt
            if receipt["exit_code"] != 0 or ERRORS.search((folder/"import.log").read_text(errors="replace")):
                summary["status"]="failed"
                save()
                print("FAIL: native import; original log retained",file=sys.stderr)
                return 1
        probe = run(["bash","tools/godot.sh","--headless","--path",".","--script","tests/test_forest_vine_gate.gd","--","--log-error-probe"],folder/"strict-log-error-counterexample.log",20)
        probe_text = (folder/"strict-log-error-counterexample.log").read_text(errors="replace")
        probe["expected_rejection_observed"] = probe["exit_code"] == 0 and "FOREST LOG GUARD PROBE: emitted plain ERROR with exit 0" in probe_text and bool(ERRORS.search(probe_text)) and "SCRIPT ERROR:" not in probe_text
        summary["strict_log_counterexample"] = probe
        if not probe["expected_rejection_observed"]:
            summary["status"]="failed"
            save()
            print("FAIL: plain engine ERROR counterexample not rejected",file=sys.stderr)
            return 1
        if args.region_matrix:
            jobs = [(f"seed{seed:02d}-map{map_index}-{route}",args.seed_prefix+f"{seed:02d}",map_index,route) for seed in range(args.seed_count) for map_index in (1,2) for route in ("fast","growth","high_return")]
            summary["scope"] = "formal_DemoApp_10roots_two_maps_three_routes" if args.seed_count==10 else "formal_DemoApp_bounded_route_sample"
        else:
            jobs = [(case,None,None,None) for case in args.case or CASES]
        for case,seed,map_index,route_name in jobs:
            output = folder / (case+".json")
            argv = ["bash","tools/godot.sh","--headless","--fixed-fps","60","--path",".","--script","tests/forest_region_runner.gd","--","--output=res://"+output.relative_to(ROOT).as_posix()]
            argv += ["--mode=region","--seed="+seed,"--map="+str(map_index),"--route="+route_name] if seed else ["--case="+case]
            before = runtime_fingerprint()
            fingerprint_id = hashlib.sha256(json.dumps(before,sort_keys=True).encode()).hexdigest()
            summary.setdefault("runtime_source_snapshots",{})[fingerprint_id] = before
            receipt = run(argv,folder / (case+".log"),45 if seed else 30)
            after = runtime_fingerprint()
            receipt["runtime_source_snapshot"] = fingerprint_id
            receipt["runtime_sources_unchanged"] = before == after
            if before != after: receipt["changed_sources"] = [p for p in before.keys()|after.keys() if before.get(p)!=after.get(p)]
            data = json.loads(output.read_text()) if output.exists() else {}
            errors = validate_region_capture(data) if seed else validate_capture(data)
            log_errors = bool(ERRORS.search((folder / (case+".log")).read_text(errors="replace")))
            positive = bool(seed) or case in ("positive", "mirror")
            native_expected = bool(data) and ((receipt["exit_code"] == 0 and not errors) if positive else (receipt["exit_code"] == 1 and bool(errors)))
            expected = native_expected and not log_errors and receipt["runtime_sources_unchanged"]
            if seed:
                mutation_receipts = {}
                if native_expected:
                    for name in ("delete_H_events_keep_completed_legs","delete_supports_keep_completed_legs","delete_final_leg_frames_keep_receipts","forge_shortened_itinerary","erase_persisted_ledger_keep_passed_flag"):
                        altered = copy.deepcopy(data)
                        if name.startswith("delete_H"):
                            altered["events"] = [e for e in altered["events"] if not e.get("kind","").startswith("hook_")]
                        elif name.startswith("delete_supports"):
                            for frame in altered["frames"]: frame["supports"] = []
                        elif name.startswith("delete_final"):
                            final_leg = len(altered["itinerary"])-1
                            altered["frames"] = [f for f in altered["frames"] if f.get("leg",0)<final_leg]
                        elif name.startswith("forge_shortened"):
                            altered["itinerary"] = altered["itinerary"][:1]
                            altered["completed_legs"] = altered["completed_legs"][:1]
                        else:
                            altered["state_reload"]["json_snapshot"]["claimed"] = {}
                            altered["state_reload"]["json_snapshot"]["opened"] = {}
                        mutation_receipts[name] = validate_region_capture(altered)
                    expected = expected and all(mutation_receipts.values())
                summary["cases"].append({"case":case,"seed":seed,"map_index":map_index,"route":route_name,**receipt,"validation_errors":errors,"native_expected_outcome_observed":native_expected,"strict_engine_errors":log_errors,"expected_outcome_observed":expected,"evidence_mutation_counterexamples":mutation_receipts,"completed_legs":len(data.get("completed_legs",[])),"frames":len(data.get("frames",[])),"capture_sha256":hashlib.sha256(output.read_bytes()).hexdigest() if output.exists() else None})
                save()
                continue
            if positive and native_expected:
                mutations = {}
                altered = copy.deepcopy(data)
                altered["events"] = [e for e in altered["events"] if not e.get("kind", "").startswith("hook_")]
                mutations["delete_accepted_H_events"] = altered
                altered = copy.deepcopy(data)
                for frame in altered["frames"]:
                    frame["supports"] = []
                    frame["full_branch_support"] = False
                mutations["delete_actual_support_keep_success_flags"] = altered
                altered = copy.deepcopy(data)
                altered["frames"] = [f for f in altered["frames"] if f.get("phase") != "return"]
                mutations["delete_return_keep_success_flags"] = altered
                altered = copy.deepcopy(data)
                altered["frames"].pop(10)
                mutations["delete_middle_continuity_frame"] = altered
                altered = copy.deepcopy(data)
                altered["initial_snapshot"]["granted_actions"].append("double_jump")
                mutations["hidden_second_ability"] = altered
                mutation_receipts = {name: validate_capture(value) for name, value in mutations.items()}
                summary.setdefault("evidence_mutation_counterexamples", {})[case] = mutation_receipts
                expected = expected and all(mutation_receipts.values())
            summary["cases"].append({"case": case, **receipt, "validation_errors": errors, "native_expected_outcome_observed": native_expected, "strict_engine_errors": log_errors, "expected_outcome_observed": expected, "capture_sha256": hashlib.sha256(output.read_bytes()).hexdigest() if output.exists() else None})
            save()
        summary["status"] = "passed" if all(c["expected_outcome_observed"] for c in summary["cases"]) else "failed"
        save()
    print(summary["status"].upper() + ": " + summary["scope"])
    print("Evidence: " + str(folder / "summary.json"))
    return 0 if summary["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
