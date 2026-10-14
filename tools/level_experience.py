"""Q1–Q8 evidence from live formal captures; observations, never a fun score."""
import argparse
from collections import Counter
import hashlib
import json
import math
import re
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
POLICY = {"id": "formal-experience-observation-v1", "calibration": "uncalibrated_candidates",
          "walk_seconds": 2.0, "walk_distance": 400.0, "near_enemy_distance": 180.0}
DIMENSIONS = ["space_exploration", "platforming_actions", "enemy_terrain_encounters",
              "region_identity_learning", "pacing_emotion", "visual_audio_composition",
              "roguelike_replay", "fairness_controls_engineering"]


def read(path):
    from level_design import read as strict_read
    return strict_read(path)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, allow_nan=False).encode()).hexdigest()


def load_lessons(region_id, root=ROOT):
    """Load sourced, scoped experience; a review remains a review, never a rule."""
    if region_id is None:
        return []
    root = Path(root)
    path = root / "docs/quality/level_lessons.json"
    if not path.exists():
        return []
    data = read(path)
    if not isinstance(data, dict) or data.get("schema_version") != 1 or not isinstance(data.get("lessons"), list):
        raise ValueError("Invalid experience knowledge ledger")
    seen, applicable = set(), []
    for lesson in data["lessons"]:
        required = {"id", "source_kind", "source_commit", "region_ids", "capability_scope", "claim", "limits", "evidence"}
        if not isinstance(lesson, dict) or not required <= lesson.keys() or not isinstance(lesson["id"], str) or lesson["id"] in seen:
            raise ValueError("Invalid or duplicate sourced lesson")
        seen.add(lesson["id"])
        if lesson["source_kind"] not in {"engine_fact", "computed_proxy", "design_review", "player_feedback"}:
            raise ValueError("Knowledge must distinguish facts, proxies, reviews and player feedback")
        if not isinstance(lesson["region_ids"], list) or not lesson["region_ids"] or not isinstance(lesson["capability_scope"], str) or not lesson["capability_scope"].strip():
            raise ValueError("Knowledge needs explicit regional and capability scope")
        if not isinstance(lesson["claim"], str) or not lesson["claim"].strip() or not lesson["limits"] or not lesson["evidence"]:
            raise ValueError("Knowledge needs a bounded claim and evidence")
        for ref in lesson["evidence"]:
            file = (root / ref["path"]).resolve()
            if not file.is_relative_to(root.resolve()) or not file.is_file() or sha(file) != ref["sha256"]:
                raise ValueError("Stale/missing knowledge evidence: " + str(ref.get("path")))
        if region_id in lesson["region_ids"]:
            applicable.append(lesson)
    return applicable


def pair(value, label):
    if not isinstance(value, list) or len(value) != 2 or any(isinstance(x, bool) or not isinstance(x, (int, float)) or not math.isfinite(x) for x in value):
        raise ValueError("Invalid finite pair: " + label)
    return value


def validate_capture(capture):
    if not isinstance(capture, dict) or capture.get("schema_version") != 1 or capture.get("artifact_kind") != "formal_level_capture":
        raise ValueError("Expected live formal capture, not terrain-only or design fixture")
    if capture.get("capture_errors") != [] or not isinstance(capture.get("frames"), list) or not capture["frames"]:
        raise ValueError("Empty/failed formal capture")
    scope = capture.get("captured_scope", {})
    for key in ("enemies_instantiated", "enemy_attacks_enabled", "enemy_contacts_enabled", "environment_damage_enabled", "production_camera_enabled", "production_rewards_enabled"):
        if scope.get(key) is not True:
            raise ValueError("Formal observation lacks consumer: " + key)
    for key in ("controller_manual_step", "actor_teleport_by_driver", "resource_injection", "enemy_disable"):
        if scope.get(key) is not False:
            raise ValueError("Formal observation changed runtime: " + key)
    if capture.get("map_index") not in (1, 2) or capture.get("strategy") not in ("fast", "growth", "deep", "return"):
        raise ValueError("Invalid formal strategy/map")
    if not isinstance(capture.get("manifest"), dict) or not capture["manifest"].get("areas") or not capture["manifest"].get("connections"):
        raise ValueError("Missing actual formal Manifest")
    if not re.fullmatch(r"[0-9a-f]{40}", str(capture.get("source_commit", ""))) or not re.fullmatch(r"[0-9a-f]{64}", str(capture.get("manifest_hash", ""))):
        raise ValueError("Missing source or Manifest fingerprint")
    if capture["manifest"].get("manifest_hash") != capture.get("manifest_hash"):
        raise ValueError("Capture/Manifest identity mismatch")
    allowed_edges = {str(e["id"]) for e in capture["manifest"]["connections"]} | {str(a["id"]) for a in capture["manifest"]["areas"]} | {"tutorial"}
    if not isinstance(capture.get("physics_hz"), (int, float)) or capture["physics_hz"] <= 0:
        raise ValueError("Missing actual tick rate")
    previous = 0
    global_events={fingerprint(e) for e in capture.get("events", [])}
    for frame in capture["frames"]:
        tick = frame.get("tick")
        if type(tick) is not int or tick != previous + 1:
            raise ValueError("Missing/discontinuous real observation frame")
        previous = tick
        if frame.get("edge") not in allowed_edges:
            raise ValueError("Frame references a different map/edge")
        pair(frame.get("position"), "position")
        pair(frame.get("velocity"), "velocity")
        for key in ("health", "shot_energy", "shots", "shot_cooldown", "recovery_count"):
            value = frame.get(key)
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
                raise ValueError("Invalid runtime state: " + key)
        if not isinstance(frame.get("accepted_events"), list) or not isinstance(frame.get("input_requests"), list):
            raise ValueError("Actions must separate requests and accepted events")
        if any(fingerprint(e) not in global_events for e in frame["accepted_events"]):
            raise ValueError("Accepted observation absent from actual event journal")
    for event in capture.get("events", []):
        if type(event.get("tick")) is not int or not 0 <= event["tick"] <= previous + 1 or not event.get("kind"):
            raise ValueError("Event outside recorded/terminal tick")
    if capture.get("tick_count") != previous:
        raise ValueError("Trace tick total differs from frames")
    if not isinstance(capture.get("edges"), list) or not capture["edges"] or type(capture.get("route_reached")) is not bool:
        raise ValueError("Missing actual route outcome")
    for edge in capture["edges"]:
        terminal_end = previous
        if edge.get("aborted") is True and edge.get("reached") is False:
            terminal = capture.get("terminal_observation", {})
            if terminal.get("tick") == previous + 1 and any(e["kind"] == "run_ended" and e["tick"] == previous + 1 for e in capture.get("events", [])):
                terminal_end = previous + 1
        if edge.get("id") not in allowed_edges or type(edge.get("reached")) is not bool or not 1 <= edge.get("start_tick",0) <= edge.get("end_tick",0) <= terminal_end:
            raise ValueError("Invalid actual route interval")
    return capture


def capability_basis(capture):
    capability = capture["initial_capability"]
    return {key: capability.get(key) for key in (
        "equipped_weapon", "granted_actions", "tuning", "config_hashes", "effective_max_jumps",
        "air_shot_flight_cap", "shot_energy", "combat_energy", "build", "air_shots", "physics_hz")}


def scenery_facts(capture):
    areas = capture["manifest"]["areas"]
    eligible = [a["id"] for a in areas if a.get("role") in {"rest", "camp", "junction", "entry", "merchant"}]
    rows = [row for scene in capture.get("initial_scenery_inventory", []) for row in scene.get("descendants", [])]
    props = [row for row in rows if row.get("class") == "Sprite2D" and (
        row.get("texture") or row.get("texture_class") not in (None, "GradientTexture2D") or row.get("landmark_id"))]
    return {"eligible_areas": eligible, "textured_prop_nodes": len(props),
            "prop_assets": dict(Counter(row.get("landmark_id", row.get("texture", row.get("texture_class", "unknown"))) for row in props)),
            "inventory_scope": "actual instantiated scenery, not GPU aesthetic approval"}


def analyze_capture(capture, policy=None):
    validate_capture(capture)
    policy = dict(POLICY if policy is None else policy)
    if set(policy) != set(POLICY) or not isinstance(policy["id"], str) or not policy["id"] or policy["calibration"] != "uncalibrated_candidates":
        raise ValueError("Observation policy must be explicit and bounded, not a quality score")
    for key in ("walk_seconds", "walk_distance", "near_enemy_distance"):
        if type(policy[key]) not in (int, float) or not math.isfinite(policy[key]) or policy[key] <= 0:
            raise ValueError("Invalid observation threshold")
    frames, events = capture["frames"], capture.get("events", [])
    diagnostics, walk, last_runtime = [], [], {}
    signatures, counts = [], Counter(e["kind"] for e in events)

    def finish_walk():
        if len(walk) > 1:
            duration = len(walk) / capture["physics_hz"]
            distance = sum(math.dist(a["position"], b["position"]) for a, b in zip(walk, walk[1:]))
            if duration >= policy["walk_seconds"] and distance >= policy["walk_distance"]:
                diagnostics.append({"kind": "low_interaction_candidate", "source_kind": "computed_proxy", "quality_dimension": "Q5",
                    "edge": walk[0]["edge"], "start_tick": walk[0]["tick"], "end_tick": walk[-1]["tick"], "seconds": duration,
                    "distance": distance, "position": walk[0]["position"], "reason": "continuous grounded movement without accepted action, nearby observed live enemy or resource change",
                    "limits": "May be intentional observation, recovery or story space; design intent and rendered footage must decide"})
        walk.clear()

    previous = None
    for frame in frames:
        if "runtime" in frame:
            last_runtime = frame["runtime"]
        meaningful = [e["kind"] for e in frame["accepted_events"] if e["kind"] in {
            "jump_accepted", "shot_accepted", "landed", "energy_recovered", "damage_committed", "segment_returned", "reward_modal_submission"}]
        signatures.extend(meaningful)
        near = any(not enemy.get("terminal") and math.dist(enemy["position"], frame["position"]) <= policy["near_enemy_distance"]
                   for enemy in last_runtime.get("enemies", []))
        resource_change = previous is not None and any(frame[k] != previous[k] for k in ("health", "shot_energy", "shots", "recovery_count"))
        if frame.get("grounded") and abs(frame.get("axis", 0)) > .1 and not meaningful and not near and not resource_change:
            if walk and walk[-1]["edge"] != frame["edge"]:
                finish_walk()
            walk.append(frame)
        else:
            finish_walk()
        previous = frame
    finish_walk()
    for event in events:
        if event["kind"] in ("died", "segment_returned", "damage_committed"):
            diagnostics.append({"kind": event["kind"], "source_kind": "engine_fact", "quality_dimension": "Q8", **event,
                                "limits": "Observed input-policy outcome; not proof all human strategies fail"})
    scenery = scenery_facts(capture)
    if scenery["eligible_areas"] and scenery["textured_prop_nodes"] == 0:
        diagnostics.append({"kind": "missing_instantiated_landmarks", "source_kind": "engine_fact", "quality_dimension": "Q6",
            "areas": scenery["eligible_areas"], "reason": "eligible authored landmarks but no textured prop instantiated in actual scenery",
            "limits": "Does not measure subjective beauty or other background consumers"})
    runtime_frames = [f for f in frames if "runtime" in f]
    enemy_ids = {e["id"] for f in runtime_frames for e in f["runtime"].get("enemies", [])}
    case = {"root_seed": capture["root_seed"], "map_index": capture["map_index"], "strategy": capture["strategy"], "phase_wait_ticks": capture["phase_wait_ticks"]}
    return {"case": case, "manifest_hash": capture["manifest_hash"], "source_commit": capture["source_commit"],
        "observer_basis": capture.get("capture_source_hashes", {}),
        "capability_basis": capability_basis(capture), "physics_hz": capture["physics_hz"], "captured_scope": capture["captured_scope"],
        "outcome": capture["outcome"], "route_reached": capture["route_reached"], "edges": capture["edges"],
        "stats": {"ticks": capture["tick_count"], "seconds": capture["tick_count"] / capture["physics_hz"],
            "observed_enemies": len(enemy_ids), "accepted_events": dict(counts), "reached_edges": sum(e.get("reached", False) for e in capture["edges"]),
            "low_interaction_candidates": sum(d["kind"] == "low_interaction_candidate" for d in diagnostics),
            "textured_prop_nodes": scenery["textured_prop_nodes"]},
        "scenery": scenery, "action_signature": signatures, "diagnostics": diagnostics, "screenshots": capture.get("screenshots", []),
        "unverified": ["Boss fight/campaign completion", "all possible player strategies", "device feel and performance", "subjective fun/beauty", "weapon builds not actually equipped"]}


def report(capture_paths, policy=None):
    cases, artifacts = [], []
    for path in capture_paths:
        capture = read(path)
        # Baseline evidence remains analyzable after a change. Validate against
        # its recorded source snapshot, never relabel it as current/fresh proof.
        from level_formal import validate_capture as validate_invocation
        path = Path(path)
        receipt_path = path.with_suffix(".invocation.json")
        receipt = read(receipt_path)
        errors = validate_invocation(path, capture, receipt, path.with_suffix(".log"), current_sources=receipt.get("source_files"))
        for source, value in capture.get("capture_source_hashes", {}).items():
            if receipt.get("source_files", {}).get(source.removeprefix("res://")) != value:
                errors.append("observer source differs from invocation receipt")
        if errors:
            raise ValueError("Formal invocation inconsistent: " + "; ".join(errors))
        cases.append(analyze_capture(capture, policy))
        artifacts.append({"path": str(path), "sha256": sha(path), "kind": "formal_capture", "receipt": str(receipt_path), "receipt_sha256": sha(receipt_path)})
    if not cases or len({fingerprint(c["case"]) for c in cases}) != len(cases):
        raise ValueError("Experience report needs nonempty unique actual cases")
    dimensions = {"Q" + str(i + 1): {"dimension": name, "status": "review", "evidence_basis": "engine facts and bounded proxies; independent design review required"}
                  for i, name in enumerate(DIMENSIONS)}
    result = {"schema_version": 1, "artifact_kind": "level_experience_report", "verdict": "REVIEW",
              "policy": dict(POLICY if policy is None else policy), "dimensions": dimensions,
              "cases": cases, "artifacts": artifacts, "player_acceptance": "unverified", "device_acceptance": "unverified",
              "provenance": "local_invocation_consistency_not_external_authentication; historical source snapshots retained",
              "worst_candidates": [c["case"] for c in sorted(cases, key=lambda c: (c["route_reached"], -c["stats"]["accepted_events"].get("damage_committed", 0), -c["stats"]["low_interaction_candidates"]))[:10]]}
    result["fingerprint"] = fingerprint(result)
    return result


def validate_report(value):
    if not isinstance(value, dict) or value.get("artifact_kind") != "level_experience_report" or value.get("schema_version") != 1 or not value.get("cases") or not value.get("artifacts"):
        raise ValueError("Empty or wrong experience report")
    payload = {k: v for k, v in value.items() if k != "fingerprint"}
    if value.get("fingerprint") != fingerprint(payload):
        raise ValueError("Experience report fingerprint mismatch")
    if len({fingerprint(c["case"]) for c in value["cases"]}) != len(value["cases"]):
        raise ValueError("Duplicate experience cases")
    if len(value["artifacts"]) != len(value["cases"]) or set(value.get("dimensions", {})) != {"Q"+str(i) for i in range(1,9)}:
        raise ValueError("Incomplete case evidence or Q1–Q8 coverage declarations")
    for case in value["cases"]:
        basis = case.get("capability_basis", {})
        if not case.get("stats", {}).get("ticks") or not case.get("edges") or not basis.get("equipped_weapon") or not basis.get("config_hashes") or not basis.get("granted_actions"):
            raise ValueError("Incomplete experience case")
        if not re.fullmatch(r"[0-9a-f]{40}", str(case.get("source_commit", ""))) or not re.fullmatch(r"[0-9a-f]{64}", str(case.get("manifest_hash", ""))):
            raise ValueError("Incomplete experience source identity")
        if type(case.get("route_reached")) is not bool or not isinstance(case.get("diagnostics"), list) or not isinstance(case.get("action_signature"), list):
            raise ValueError("Missing outcomes, observations or diagnostic evidence")
        for key in ("ticks", "seconds", "observed_enemies", "reached_edges", "low_interaction_candidates", "textured_prop_nodes"):
            n=case["stats"].get(key)
            if type(n) not in (int,float) or not math.isfinite(n) or n<0:
                raise ValueError("Invalid experience statistic")
    for artifact in value["artifacts"]:
        if not re.fullmatch(r"[0-9a-f]{64}",str(artifact.get("sha256",""))) or not re.fullmatch(r"[0-9a-f]{64}",str(artifact.get("receipt_sha256",""))) or not artifact.get("path") or not artifact.get("receipt"):
            raise ValueError("Missing artifact/receipt bindings")
    return value


def compare(before, after):
    validate_report(before); validate_report(after)
    if before["policy"] != after["policy"]:
        raise ValueError("Observation policy changed; comparison cannot infer improvement")
    left, right = ({fingerprint(c["case"]): c for c in r["cases"]} for r in (before, after))
    if left.keys() != right.keys():
        raise ValueError("Seed/map/strategy/phase cohort mismatch")
    comparisons = []
    for key, a in left.items():
        b = right[key]
        if a["capability_basis"] != b["capability_basis"] or a["physics_hz"] != b["physics_hz"] or a["captured_scope"] != b["captured_scope"] or a.get("observer_basis") != b.get("observer_basis"):
            raise ValueError("Capability, device/consumer scope or physics mismatch")
        comparisons.append({"case": a["case"], "before_source": a["source_commit"], "after_source": b["source_commit"],
            "manifest_changed": a["manifest_hash"] != b["manifest_hash"], "actual_action_changed": a["action_signature"] != b["action_signature"],
            "outcome": [a["outcome"], b["outcome"]], "stats_delta": {k: b["stats"][k] - a["stats"][k] for k in a["stats"] if k != "accepted_events"},
            "event_delta": {k: b["stats"]["accepted_events"].get(k, 0) - a["stats"]["accepted_events"].get(k, 0) for k in set(a["stats"]["accepted_events"]) | set(b["stats"]["accepted_events"])}})
    return {"schema_version": 1, "artifact_kind": "level_experience_comparison", "verdict": "REVIEW", "cases": comparisons,
            "before_fingerprint": before["fingerprint"], "after_fingerprint": after["fingerprint"],
            "limits": "Differences are measured effects; subjective fun and visual appeal still require review/player evidence"}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    analyze = sub.add_parser("analyze"); inputs=analyze.add_mutually_exclusive_group(required=True); inputs.add_argument("--captures", nargs="+"); inputs.add_argument("--batch"); analyze.add_argument("--output", required=True)
    comparator = sub.add_parser("compare"); comparator.add_argument("--before", required=True); comparator.add_argument("--after", required=True); comparator.add_argument("--output", required=True)
    args = parser.parse_args(argv)
    if args.command == "analyze":
        paths=args.captures
        if args.batch:
            batch=read(args.batch)
            if batch.get("artifact_kind")!="formal_capture_batch" or not batch.get("cases") or batch.get("captured_cases")!=len(batch["cases"]) or batch.get("requested_cases")!=len(batch["cases"]) or not all(c.get("captured") for c in batch["cases"]):
                raise ValueError("Incomplete formal batch; preserve failed cases rather than filtering them away")
            paths=[ROOT/c["capture"] for c in batch["cases"]]
        result=report(paths)
    else:
        result=compare(read(args.before),read(args.after))
    output = Path(args.output); output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False) + "\n")
    print("EXPERIENCE REVIEW:", len(result["cases"]), "actual cases; subjective acceptance unverified;", output)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, KeyError, OSError, TypeError) as error:
        print("Experience rejected:", error, file=sys.stderr); sys.exit(1)
