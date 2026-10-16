"""Current default v10 native maps/chains plus physical broken-bank counterexample."""
import copy
import hashlib
import math
import json
import re
import subprocess
import tempfile
from pathlib import Path

import harness
import level_formal
from run_tests import REPO


SEMANTIC_PATHS = {
    "short_technique": ["area_0_1", "area_1_1", "area_2_1"],
    "upper_discovery": ["area_0_1", "area_0_0", "area_1_0", "area_2_0", "area_2_1"],
    "creek_return": ["area_1_1", "area_1_2", "area_2_2", "area_2_1"],
}


def semantic_errors(record):
    errors = []
    declared = record.get("route_intents", {})
    edges = record.get("connections", [])
    for name, path in SEMANTIC_PATHS.items():
        if declared.get(name) != path: errors.append(name + ": incorrect authored route")
        for source, target in zip(path, path[1:]):
            valid = any(edge.get("condition") == "open" and not set(edge.get("required_capabilities", [])) - {"base_jump", "base_recoil", "shoot_mechanism"} and ((edge.get("a") == source and edge.get("b") == target) or (edge.get("bidirectional") is True and edge.get("b") == source and edge.get("a") == target)) for edge in edges)
            if not valid: errors.append(name + ": unavailable directed step " + source + " -> " + target)
    return errors


def validate_corpus(data):
    cases = data.get("semantic_cases", [])
    negatives = data.get("semantic_negatives", [])
    expected = {("corpus/%s/%s" % (family, i), family) for family in ("woven_layers", "linked_rings", "crossroads") for i in range(50)}
    actual = {(case.get("seed"), case.get("family")) for case in cases}
    return data.get("corpus_mode") is True and data.get("version") == "plains-region-v10" and data.get("failures") == 0 and len(cases) == 350 and len(actual) == 350 and expected <= actual and all(case.get("errors") == [] and not semantic_errors(case) for case in cases) and {n.get("kind") for n in negatives} == {"missing_step", "reversed_step", "unavailable_gate", "future_ability"} and len(negatives) == 4 and all(n.get("rejected") is True and n.get("direct_errors") for n in negatives)


def validate_route_runs(observation, manifest):
    frames = {frame["tick"]: frame for frame in observation["frames"]}
    areas = {area["id"]: area["position"] for area in manifest["areas"]}
    runs = observation.get("route_runs", [])
    names = {run.get("name") for run in runs}
    if not {"short_technique_to_camp", "short_technique_return"} <= names: return False
    worst = (observation["seed"], observation["map_index"]) in {("level-design-v2-baseline/03", 1), ("level-design-v2-baseline/04", 2)}
    if worst and (not {"upper_discovery", "creek_return", "high_reward_return", "reward_rejoins_camp", "final_return"} <= names or not observation.get("alternatives") or not observation.get("reward_return")): return False
    edges = {edge["id"]: edge for edge in manifest["connections"]}
    for run in runs:
        start, end = run.get("start_tick"), run.get("end_tick")
        path = run.get("path", [])
        if run.get("reached") is not True or start not in frames or end not in frames or start >= end or len(path) < 2: return False
        last = frames[end]
        if last.get("grounded") is not True or math.dist(last["position"], areas[path[-1]]) > 2 or math.dist(last["position"], run.get("end_position", [1e10, 1e10])) > .001: return False
        if run["name"] == "high_reward_return":
            reward = areas["deep_high"]
            if not any(frame["grounded"] and math.dist(frame["position"], reward) < 2 for tick, frame in frames.items() if start <= tick <= end): return False
            continue
        steps = run.get("steps", [])
        if len(steps) != len(path) - 1: return False
        for i, step in enumerate(steps):
            edge = edges.get(step.get("id"), {})
            source, target = path[i:i+2]
            if step.get("reached") is not True or step.get("source") != source or step.get("target") != target or edge.get("condition") != "open": return False
            if not ((step.get("forward") is True and edge.get("a") == source and edge.get("b") == target) or (step.get("forward") is False and edge.get("bidirectional") is True and edge.get("b") == source and edge.get("a") == target)): return False
            if not start <= step["start_tick"] < step["end_tick"] <= end or step["end_tick"] not in frames: return False
            at = frames[step["end_tick"]]
            if not at["grounded"] or math.dist(at["position"], areas[target]) > 2: return False
    return True



def validate_receiver_fault(data, complete):
    fault = data.get("receiver_fault", {})
    if fault.get("complete") is not complete or data.get("platform_only") is not (not complete): return False
    receiver = fault.get("receiver", [])
    before, after, removed = fault.get("support_before", []), fault.get("support_after", []), fault.get("removed_fragments", [])
    if len(receiver) != 4 or receiver[2] <= 0 or receiver[3] <= 0 or not before: return False
    x, y, w, h = receiver
    expected = []
    expected_removed = []
    untouched_ids = set()
    for body in before:
        rect = body.get("rect", [])
        if len(rect) != 4 or body.get("collision_layer") != 1: return False
        left, top, width, depth = rect
        a, b = max(left, x), min(left + width, x + w)
        attached = abs(top - (y + h)) < .001 and b > a
        if not complete or not attached:
            expected.append(rect); untouched_ids.add(body["instance_id"]); continue
        expected_removed.append([a, top, b-a, depth])
        if a > left: expected.append([left, top, a-left, depth])
        if b < left+width: expected.append([b, top, left+width-b, depth])
    def normalized(rows): return sorted(tuple(round(v, 3) for v in row) for row in rows)
    if normalized(expected) != normalized([b.get("rect", []) for b in after]): return False
    if normalized(removed) != normalized(expected_removed) or (complete and not removed): return False
    if not untouched_ids.issubset({b.get("instance_id") for b in after}): return False
    if not complete:
        observations = data.get("observations", [])
        if len(observations) != 1 or not observations[0].get("frames"): return False
        frame = observations[0]["frames"][-1]
        actual_contacts = {row.get("instance_id") for row in frame.get("floor_colliders", [])}
        if frame.get("grounded") is not True or not actual_contacts.intersection(untouched_ids): return False
        # The original fall predicate MUST still reject this incomplete deletion.
        if frame["position"][1] > 500: return False
    return True

def validate_native(data, negative=False):
    expected = 1 if negative else 20
    observations = data.get("observations", [])
    manifests = data.get("manifests", [])
    if data.get("version") != "plains-region-v10" or data.get("deleted_receiver") is not negative or len(observations) != expected or len(manifests) != expected:
        return False
    if negative:
        return validate_receiver_fault(data, True) and data.get("failures", 0) > 0 and observations[0].get("forward") is False and len(observations[0].get("frames", [])) > 10 and observations[0]["frames"][-1]["position"][1] > 500
    if data.get("failures") != 0 or data.get("assertions", 0) < 700 or len(data.get("semantic_cases", [])) != 20 or any(case.get("errors") or semantic_errors(case) for case in data.get("semantic_cases", [])):
        return False
    seen = set()
    zeros = 0
    for observation, manifest in zip(observations, manifests):
        key = (observation.get("seed"), observation.get("map_index"))
        if key in seen or key[1] not in (1, 2): return False
        seen.add(key)
        if not all(observation.get(name) is True for name in ("forward", "camp_forward", "reverse", "safe", "continuous")) or observation.get("shots", 0) < 1:
            return False
        first=observation.get("first_shots", [])
        begin,end=observation.get("first_begin"),observation.get("first_end")
        if not observation.get("first_door_open") or not isinstance(begin,int) or not isinstance(end,int) or begin>=end:return False
        if len(first)!=(1 if key[1]==1 else 2) or any(not begin<e.get("tick",-1)<=end for e in first):return False
        fm={f["tick"]:f for f in observation["frames"]}
        if any(e["tick"]-1 not in fm or math.dist(e["position"],fm[e["tick"]-1]["position"])>.001 for e in first):return False
        if key[1]==2 and not(first[0]["tick"]<first[1]["tick"] and first[1]["position"][1]<first[0]["position"][1]-80 and first[1]["position"][0]>first[0]["position"][0]+300):return False
        first_edge=next((e for e in manifest['connections'] if e['a']=='area_0_1' and e['b']=='area_1_1'),{})
        camp_edge=next((e for e in manifest['connections'] if e['a']=='area_1_1' and e['b']=='area_2_1'),{})
        if first_edge.get('recipe')!=('well_arch_phrase' if key[1]==1 else 'remote_sequence'):return False
        if camp_edge.get('recipe') in (['well_arch_phrase','low_arch','thorn_gap','bell_pit'] if key[1]==1 else ['remote_sequence','remote_bell','bell_order']):return False
        if semantic_errors(manifest): return False
        if manifest.get("version") != "plains-region-v10" or manifest.get("manifest_hash") != observation.get("manifest_hash") or manifest.get("fallback_id") != "":
            return False
        frames = observation.get("frames", [])
        if len(frames) < 200: return False
        session = (frames[0].get("session"), frames[0].get("motor"))
        previous = None
        for frame in frames:
            if (frame.get("session"), frame.get("motor")) != session or frame.get("safe") is not True or frame.get("continuous") is not True:
                return False
            values = frame.get("position", []) + frame.get("normal_velocity", []) + frame.get("recoil_velocity", []) + [frame.get("energy")]
            if len(values) != 7 or not all(isinstance(v, (int, float)) and math.isfinite(v) for v in values): return False
            if not isinstance(frame.get("energy_capacity"), (int, float)) or not 0 < frame["energy_capacity"] or not 0 <= frame["energy"] <= frame["energy_capacity"]: return False
            if previous:
                if frame["tick"] != previous["tick"] + 1: return False
                # Independent artifact continuity envelope, deliberately far above the
                # unchanged native Motor speed; native fullbody sweep is stricter.
                if math.dist(frame["position"], previous["position"]) > 35: return False
            previous = frame
        if frames[-1].get("grounded") is not True or math.dist(frames[-1]["position"], [0, 0]) > 2: return False
        if not validate_route_runs(observation, manifest): return False
        if observation.get("entry_energy") == 0: zeros += 1
    return len(seen) == 20 and zeros == 10


def source_snapshot():
    result = level_formal.source_files()
    result["tools/run_plains_redesign_spatial_tests.py"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    return result


def main():
    base = REPO / "build/plains_redesign/spatial"
    base.mkdir(parents=True, exist_ok=True)
    folder = Path(tempfile.mkdtemp(prefix="run_", dir=base))
    before = source_snapshot()
    receipt = {"status": "failed", "source_before": before, "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(), "scope": "default v10 20 directed semantic route graphs; real samebody shortchain to camp and return, two worst-seed upper/creek/reward reunions,350original corpus contracts plus four directed/gate/ability negatives; no formal enemy or subjective/device completion", "runs": []}
    try:
        for mode in ("positive", "deleted_receiver", "platform_only_control", "corpus"):
            negative = mode in ("deleted_receiver", "platform_only_control")
            name = mode
            output = folder / (name + ".json")
            command = ["bash", "tools/godot.sh", "--headless", "--fixed-fps", "60", "--path", ".", "--script", "tests/plains_redesign_spatial_runner.gd", "--", "--output=" + str(output)]
            if negative:
                command.append("--delete-receiver-platform-only" if mode == "platform_only_control" else "--delete-receiver")
            if mode == "corpus":
                command.append("--corpus")
            result = harness.run_check({"argv": command, "timeout_seconds": 180, "success_pattern": r"^PLAINS REDESIGN SPATIAL: [1-9]\d* assertions, 0 failures$"}, folder / (name + ".log"), REPO)
            text = (folder / (name + ".log")).read_text()
            data = json.loads(output.read_text()) if output.is_file() else {}
            valid = (result["exit_code"] == 1 if negative else result["status"] == "passed") and (validate_corpus(data) if mode == "corpus" else (validate_receiver_fault(data, False) and not validate_native(data, True)) if mode == "platform_only_control" else validate_native(data, negative))
            valid = bool(valid and not re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script", text))
            receipt["runs"].append({"argv": command, "process": result, "validated": valid, "expected_exit": 1 if negative else 0, "output": str(output.relative_to(REPO)), "output_sha256": hashlib.sha256(output.read_bytes()).hexdigest() if output.is_file() else None})
            if not valid:
                raise RuntimeError("Actual default spatial proof failed: " + str(folder))
        receipt["source_after"] = source_snapshot()
        if before != receipt["source_after"]:
            raise RuntimeError("Source changed during spatial proof")
        positive = json.loads((folder / "positive.json").read_text())
        refusals = []
        for name in ("empty_frames", "duplicate_map", "teleport", "missing_energy", "wrong_version", "missing_second_step", "reverse_second_step", "unavailable_gate", "future_ability", "forged_camp_position", "missing_alternative", "repeated_action_family"):
            corrupt = copy.deepcopy(positive)
            if name == "repeated_action_family":
                next(e for e in corrupt["manifests"][0]["connections"] if e["a"]=="area_1_1" and e["b"]=="area_2_1")["recipe"]="low_arch"
            elif name == "empty_frames": corrupt["observations"][0]["frames"] = []
            elif name == "duplicate_map": corrupt["observations"][1]["seed"] = corrupt["observations"][0]["seed"]; corrupt["observations"][1]["map_index"] = corrupt["observations"][0]["map_index"]
            elif name == "teleport": corrupt["observations"][0]["frames"][20]["position"][0] += 1000
            elif name == "missing_energy": del corrupt["observations"][0]["frames"][20]["energy"]
            elif name == "wrong_version": corrupt["version"] = "plains-region-v999"
            elif name in ("missing_second_step", "reverse_second_step", "unavailable_gate", "future_ability"):
                connections = corrupt["manifests"][0]["connections"]
                edge = next(e for e in connections if e["a"] == "area_1_1" and e["b"] == "area_2_1")
                if name == "missing_second_step": connections.remove(edge)
                elif name == "reverse_second_step": edge.update(a="area_2_1", b="area_1_1", bidirectional=False)
                elif name == "unavailable_gate": edge["condition"] = "backside"
                else: edge["required_capabilities"] = ["hook"]
            elif name == "forged_camp_position": corrupt["observations"][0]["route_runs"][0]["end_position"][0] += 200
            elif name == "missing_alternative":
                worst = next(o for o in corrupt["observations"] if o["seed"].endswith("/03") and o["map_index"] == 1)
                worst["route_runs"] = [run for run in worst["route_runs"] if run["name"] != "upper_discovery"]
            refused = not validate_native(corrupt)
            refusals.append({"case": name, "refused": refused})
            if not refused: raise RuntimeError("Artifact validator accepted corruption: " + name)
        complete = json.loads((folder / "deleted_receiver.json").read_text())
        residue = json.loads((folder / "platform_only_control.json").read_text())
        for name in ("all_earth_deleted", "neighbor_body_deleted", "foreign_removed_fragment", "platform_only_declared_complete"):
            corrupt = copy.deepcopy(residue if name=="platform_only_declared_complete" else complete)
            fault = corrupt["receiver_fault"]
            if name=="all_earth_deleted": fault["support_after"]=[]
            elif name=="neighbor_body_deleted": fault["support_after"].pop()
            elif name=="foreign_removed_fragment": fault["removed_fragments"].append([0,0,10,10])
            else: fault["complete"]=True;corrupt["platform_only"]=False
            refused = not validate_receiver_fault(corrupt, True)
            refusals.append({"case":name,"refused":refused})
            if not refused:raise RuntimeError("Receiver fault validator accepted unrelated deletion: "+name)
        (folder / "validator_refusals.json").write_text(json.dumps(refusals, indent=2) + "\n")
        receipt["status"] = "passed"
        print("PLAINS REDESIGN SPATIAL: actual default semantic maps and physical counterexamples validated", flush=True)
    finally:
        (folder / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
        print("PLAINS SPATIAL RECEIPT: " + str(folder / "receipt.json"), flush=True)


if __name__ == "__main__":
    main()
