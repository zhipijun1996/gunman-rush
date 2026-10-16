"""Actual formal composition routes and actual-node visibility counterexamples."""
import gzip
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

import harness
import level_formal
from run_tests import REPO, run_engine

MUTATIONS = ("hud_actor", "foreground_actor", "foreground_landing", "foreground_bell", "foreground_ferry", "heading_actor", "floating_landmark", "required_outside", "touch_controls_overlap", "info_actor")


def rect_intersects(a, b):
    return a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]


def errors(data):
    problems = []
    cases = data.get("cases", [])
    routes = [c for c in cases if "frames" in c]
    if data.get("failures") != 0 or data.get("assertions", 0) < 30 or len(routes) != 8:
        problems.append("actual eight-route native contract absent/failed")
    required = {(1, "fast", ""), (2, "growth", ""), (2, "return", "main_then_high"), (2, "fast", "outer_return"), (2, "fast", "outer_upper_alternative"), (1, "fast", "extra_upward_recoil"), (1, "fast", "touch_geometry")}
    if not required.issubset({(c.get("map"), c.get("strategy"), c.get("custom")) for c in routes}):
        problems.append("missing required route strategies")
    legacy = data.get("legacy_ui", {})
    if legacy.get("connected_region") is not False or legacy.get("info") != [434.0,10.0] or legacy.get("hud_width") != 500 or legacy.get("health_width") != 220 or any(abs(v-1.95)>.001 for v in legacy.get("camera_zoom", [0,0])):
        problems.append("actual original nonregion UI/camera compatibility absent")
    coverage = set()
    rolled_zero_tested = False
    for case in routes:
        if not case.get("finished") or case.get("outcome") != "route_target_reached" or case.get("issues"):
            problems.append("actual formal outcome/visibility failed")
        frames = case.get("frames", [])
        if len(frames) != case.get("ticks") or not frames or any(f.get("displacement", math.inf) > 28 or not isinstance(f.get("shot_energy"), (int, float)) for f in frames):
            problems.append("missing real continuous trajectory/resource observations")
        visual = case.get("visual_frames", [])
        if not visual or len(visual) < len(frames) // 8:
            problems.append("missing sufficiently sampled actual presentation")
        previous = 0
        for frame in visual:
            tick = frame.get("tick", 0)
            if tick <= previous or tick > len(frames) or frame.get("issues"):
                problems.append("invalid visual time/observed violation"); break
            previous = tick
            if frame["position"] != frames[tick - 1]["position"]:
                problems.append("presentation sample not bound to actual Motor frame"); break
            center, zoom = frame["camera_center"], frame["zoom"]
            if not any(ui.get("kind")=="info" for ui in frame.get("ui",[])):problems.append("actual INFO global inventory absent")
            for reserved in frame.get("touch_regions", []):
                if any(rect_intersects(reserved, ui["bounds"]) for ui in frame.get("ui", [])):
                    problems.append("actual enabled touch control overlapped by UI"); break
            for target in frame.get("targets", []):
                coverage.add(target["id"])
                world = target["world"]
                expected = [640 + (world[0] - center[0]) * zoom[0], 360 + (world[1] - center[1]) * zoom[1], world[2] * zoom[0], world[3] * zoom[1]]
                bounds = target["screen"]
                if any(abs(a - b) > .04 for a, b in zip(bounds, expected)):
                    problems.append("target projection disagrees with actual camera"); break
                if target.get("mandatory") and not (bounds[0] >= 6 and bounds[1] >= 6 and bounds[0] + bounds[2] <= 1274 and bounds[1] + bounds[3] <= 714):
                    problems.append("mandatory target outside observed window"); break
                if target["id"] != "elective_distant_receiver" and any(rect_intersects(bounds, ui["bounds"]) for ui in frame.get("ui", [])):
                    problems.append("actual UI/foreground occludes target"); break
        if case.get("custom") == "touch_geometry" and not any(frame.get("touch_regions") for frame in visual):
            problems.append("touch geometry fixture did not enable real overlay")
        if case.get("custom") == "extra_upward_recoil":
            receipts = case.get("elective_receipts", [])
            if len(receipts) != 1 or len(receipts[0].get("accepted_shots", [])) != 2 or not receipts[0].get("settled") or receipts[0]["apex_world_y"] >= receipts[0]["well_origin"][1] - 100:
                problems.append("missing legal actual extra upward recoil evidence")
        manifest = case.get("manifest", {})
        nodes = {n["id"]: n for n in manifest.get("nodes", [])}
        high = next((r for r in manifest.get("rewards", []) if r.get("tier") == "high"), {})
        high_ids = [nodes[n]["module_id"] for n in high.get("challenge_modules", [])]
        if case.get("map") == 2 and "plains_remote_sequence" in high_ids:
            problems.append("advanced main double-sightline duplicated in high")
        if high.get("variant") == 0 and case.get("map") == 2 and case.get("custom") == "main_then_high":
            rolled_zero_tested = high_ids == ["plains_recoil_step", "plains_windchime_rush"]
        outer = manifest.get("topology", {}).get("outer_return", {})
        if outer:
            for a, b in zip(outer["areas"], outer["areas"][1:]):
                if not any((e["a"] == a and e["b"] == b) or (e["a"] == b and e["b"] == a and e.get("bidirectional")) for e in manifest["connections"]):
                    problems.append("declared outer return missing actual directed edge")
        if case.get("custom") == "outer_return" and not outer:
            problems.append("expected canonical outer-return consumer absent")
        inventory = case.get("scenery", [])
        identities = {row.get("identity") for s in inventory for row in s.get("composition", [])} | {row.get("identity") for s in inventory for row in s.get("plan", {}).get("items", [])}
        if not {"windmill_plateau", "creek_well", "clock_court", "repair_gallery"}.issubset(identities):
            problems.append("missing actual four-identity composition consumer")
    if not {"actor", "well_receiver", "well_bell", "island_receiver"}.issubset(coverage):
        problems.append("missing actual critical target coverage")
    comparisons = {c.get("custom"): c.get("route_comparison", {}) for c in routes if c.get("custom") in {"outer_return", "outer_upper_alternative"}}
    if set(comparisons) != {"outer_return", "outer_upper_alternative"}:
        problems.append("missing actual shared-fork route comparison")
    else:
        lower, upper = comparisons["outer_return"], comparisons["outer_upper_alternative"]
        if any(not c.get("reached") or c.get("end_tick",0) <= c.get("start_tick",0) or len(c.get("actual_edges", [])) != 2 for c in (lower, upper)) or not lower.get("ferry_contacts"):
            problems.append("route comparison lacks actual edges/ferry collision/time")
        if math.dist(lower.get("start_position",[1e9,1e9]),upper.get("start_position",[0,0]))>2 or math.dist(lower.get("end_position",[1e9,1e9]),upper.get("end_position",[0,0]))>2:
            problems.append("route comparison fork/convergence differ")
        for case in routes:
            if case.get("custom") != "outer_return": continue
            e = next((e for e in case["manifest"]["connections"] if e.get("outer_return")), {})
            if e.get("purpose") != "outer_return" or e.get("recipe") != "ferry_dock": problems.append("authored outer ferry intent has no actual recipe consumer")
            expected_nodes = {case["manifest"]["nodes"][i]["id"] for i in e.get("modules", [])}
            modules = lower.get("carrier_modules", [])
            paths = lower.get("ferry_paths", [])
            if not modules or {m.get("node_id") for m in modules} != expected_nodes or any(m.get("module_id") != "plains_ferry_channel" for m in modules) or not paths or any(not any(p.startswith(m["path"]+"/") for m in modules) for p in paths):
                problems.append("new horizontal carrier provenance absent")
            indexed = {f["tick"]: f for f in case["frames"]}
            contacts = lower.get("ferry_contacts", [])
            if not contacts or any(row.get("collider") not in paths or not any(hit.get("collider")==row["collider"] for hit in indexed.get(row.get("tick"),{}).get("collisions",[])) for row in contacts):
                problems.append("new horizontal ferry has no matching actual Motor contact")
            if contacts and (not indexed.get(contacts[0]["tick"]-1) or not indexed.get(contacts[-1]["tick"]+1) or not lower["start_tick"]<contacts[0]["tick"]<=contacts[-1]["tick"]<lower["end_tick"]):
                problems.append("new ferry boarding/departure boundary observations absent")
            cycle = upper.get("cycle_return", {})
            if not cycle.get("reached") or len(cycle.get("actual_edges",[])) != 2 or math.dist(cycle.get("position",[1e9,1e9]),upper["start_position"])>2:
                problems.append("same-body actual upper-out lower-back cycle absent")
    if not rolled_zero_tested:
        problems.append("new rolled-zero high combination not physically tested after main")
    return problems


def main():
    base = REPO / "build/plains_redesign/scene"
    base.mkdir(parents=True, exist_ok=True)
    folder = Path(tempfile.mkdtemp(prefix="run_", dir=base))
    run_engine(["--headless", "--path", ".", "--editor", "--quit"], 90)
    before = level_formal.source_files()
    wrapper_sha = level_formal.file_hash(Path(__file__))
    report = {"schema_version": 1, "status": "failed", "source_files": before, "producer_sha256": wrapper_sha,
              "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
              "scope": "actual formal routes and actual-node falsification; projection proxy, separate rendered evidence, no player/device/aesthetic acceptance", "runs": []}
    (folder / "source_snapshot.json").write_text(json.dumps(before, indent=2) + "\n")
    env = os.environ.copy(); env["LP_NUM_THREADS"] = "1"
    try:
        positive = None
        for mutation in ("",) + MUTATIONS:
            name = mutation or "positive"
            output, log = folder / (name + ".json"), folder / (name + ".log")
            argv = ["bash", "tools/godot.sh", "--headless", "--fixed-fps", "60", "--path", ".", "--script", "tests/plains_redesign_scene_runner.gd", "--", "--output=" + str(output)]
            if mutation: argv.append("--mutation=" + mutation)
            process = harness.run_check({"argv": argv, "timeout_seconds": 180, "success_pattern": r"^PLAINS REDESIGN SCENE NATIVE: [1-9]\d* assertions, 0 failures$"}, log, REPO, env)
            text = log.read_text()
            data = json.loads(output.read_text()) if output.exists() else {}
            malformed = re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script", text)
            if mutation:
                case = data.get("cases", [{}])[0]
                valid = process["exit_code"] == 1 and data.get("failures") == 1 and bool(case.get("mutation")) and bool(case.get("issues"))
            else:
                positive = data
                issues = errors(data)
                valid = process["status"] == "passed" and not issues
                report["positive_errors"] = issues
            valid = bool(valid and not malformed)
            report["runs"].append({"mutation": mutation, "process": process, "command": argv, "validated": valid,
                                   "output": str(output.relative_to(REPO)), "output_sha256": level_formal.file_hash(output) if output.exists() else None,
                                   "log": str(log.relative_to(REPO)), "log_sha256": level_formal.file_hash(log)})
            if not valid: raise RuntimeError(name + ": actual scene contract failed; preserved " + str(folder))
        # Real output counterexamples prevent a pretty but empty/forged acceptance.
        import copy
        mutations = {}
        broken = copy.deepcopy(positive); broken["cases"] = []; mutations["empty_routes"] = broken
        broken = copy.deepcopy(positive); broken["cases"][0]["frames"] = []; mutations["empty_trajectory"] = broken
        broken = copy.deepcopy(positive); broken["cases"][0]["outcome"] = "frame_budget_exhausted"; mutations["movie_presence_not_completion"] = broken
        broken = copy.deepcopy(positive); broken["cases"][0]["visual_frames"] = []; mutations["no_visual_observations"] = broken
        broken = copy.deepcopy(positive); broken["cases"][0]["visual_frames"][0]["targets"][0]["screen"][0] += 20; mutations["false_projection"] = broken
        broken = copy.deepcopy(positive); c=next(c for c in broken["cases"] if c.get("custom")=="outer_return"); route=c["manifest"]["topology"]["outer_return"]["areas"]; c["manifest"]["connections"]=[e for e in c["manifest"]["connections"] if {e["a"],e["b"]}!={route[0],route[1]}]; mutations["deleted_actual_outer_connection"] = broken
        broken = copy.deepcopy(positive); c=next(c for c in broken["cases"] if c.get("map")==2); high=next(r for r in c["manifest"]["rewards"] if r["tier"]=="high"); node=next(n for n in c["manifest"]["nodes"] if n["id"]==high["challenge_modules"][-1]); node["module_id"]="plains_remote_sequence"; mutations["restored_duplicate_high"] = broken
        broken = copy.deepcopy(positive); broken["legacy_ui"] = {}; mutations["missing_actual_legacy_compatibility"] = broken
        broken = copy.deepcopy(positive); c=next(c for c in broken["cases"] if c.get("custom")=="touch_geometry"); [v.update(touch_regions=[]) for v in c["visual_frames"]]; mutations["disabled_touch_geometry"] = broken
        broken = copy.deepcopy(positive); c=next(c for c in broken["cases"] if c.get("custom")=="touch_geometry"); v=c["visual_frames"][0]; v["ui"][0]["bounds"] = v["touch_regions"][0]; mutations["restored_touch_ui_overlap"] = broken
        broken = copy.deepcopy(positive); c=next(c for c in broken["cases"] if c.get("custom")=="outer_return"); c["route_comparison"]["ferry_contacts"][0]["collider"]="unrelated/well_lift"; mutations["substituted_vertical_lift_for_horizontal_boat"] = broken
        broken = copy.deepcopy(positive); c=next(c for c in broken["cases"] if c.get("custom")=="outer_upper_alternative"); c["route_comparison"]["cycle_return"]={}; mutations["missing_actual_closed_cycle"] = broken
        report["acceptance_counterexamples"] = {name: bool(errors(data)) for name, data in mutations.items()}
        if not all(report["acceptance_counterexamples"].values()): raise RuntimeError("scene acceptance silently accepted corrupted evidence")
        if before != level_formal.source_files() or wrapper_sha != level_formal.file_hash(Path(__file__)):
            raise RuntimeError("source changed during actual scene verification")
        report["status"] = "passed"
        print("PLAINS REDESIGN SCENE: actual composition and visibility counterexamples validated", flush=True)
        return 0
    finally:
        (folder / "receipt.json").write_text(json.dumps(report, indent=2) + "\n")
        print("PLAINS REDESIGN SCENE RECEIPT: " + str(folder.relative_to(REPO)), flush=True)

if __name__ == "__main__":
    raise SystemExit(main())
