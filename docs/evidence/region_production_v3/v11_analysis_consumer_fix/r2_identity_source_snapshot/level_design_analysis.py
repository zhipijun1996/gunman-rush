"""Bounded diagnostics for captured level evidence; never a fun/quality score.

The producer validates production manifests and records real Motor state. This
consumer checks evidence consistency, then separates graph/intent observations
from runtime observations. It cannot authenticate a recording or replace replay.
"""
from collections import Counter, deque
from copy import deepcopy
import hashlib
import json
import math
import re


DEFAULT_POLICY = {
    "id": "level-design-observation-v1", "biome": "any", "category": "any",
    "device": "any", "calibration": "uncalibrated_baseline_candidates",
    "low_interaction_seconds": 2.0, "low_interaction_distance": 400.0,
    "static_join_distance": 400.0, "repeat_chain_count": 3,
    "pressure_intent_seconds": 20.0,
}

# Immutable source identity of the original plains-v8 label-folding consumer.
# Version alone cannot identify behavior after a consumer-only presentation fix.
LEGACY_PLAINS_SCENERY_SHA256 = "800c343e56fa721b0575ef3273e40fdb682ed4aa6b26d9b45c57b5f0c9bb7957"
PLAINS_ROOT_BELL_VERSION = "plains-region-v11-root-bell-v2"
SUPPORTED_PLAINS_VERSIONS = ("plains-region-v8", "plains-region-v9", "plains-region-v10", PLAINS_ROOT_BELL_VERSION)


def _plains_v11_errors(capture, manifest):
    """Finite v11 data adapter, not native regeneration or encounter proof."""
    problems = []
    admission = manifest.get("root_bell_admission")
    enemies = manifest.get("enemies")
    if not isinstance(admission, dict) or not isinstance(enemies, list) or any(not isinstance(e, dict) for e in enemies):
        return ["v11 requires RootBell admission and enemy records"]
    replaced = admission.get("replaced")
    roots = [e for e in enemies if e.get("behavior_id") == "root_bell"]
    if (admission.get("version") != "root-bell-encounter-v2" or type(replaced) is not int or replaced not in (0, 1)
            or len(roots) != replaced or admission.get("status") != ("one_candidate" if replaced == 1 else "no_physically_qualified_lane")):
        problems.append("v11 RootBell admission/version/count mismatch")
    if replaced == 1 and len(roots) == 1:
        root = roots[0]
        identities = [root.get("id"), root.get("area"), admission.get("id"), admission.get("module")]
        lanes = [n for n in manifest.get("nodes", []) if isinstance(n, dict) and n.get("id") == root.get("area")]
        if (not all(isinstance(value, str) and value.strip() for value in identities)
                or root.get("id") != admission.get("id") or root.get("area") != admission.get("module")
                or root.get("pattern") != "ground_mark_interrupt" or root.get("aerial") is not False
                or not _number(root.get("patrol_radius")) or root["patrol_radius"] != 0 or not _vector(root.get("position"))
                or len(lanes) != 1 or lanes[0].get("module_id") != "region_connection"):
            problems.append("v11 RootBell record does not bind its declared lane")
    formal = capture.get("formal_run_manifest")
    if not isinstance(formal, dict) or not isinstance(formal.get("versions"), dict) or not isinstance(formal.get("stages"), list) or not formal["stages"]:
        return problems + ["v11 requires the actual formal RunManifest version binding"]
    if any(formal["versions"].get(k) != PLAINS_ROOT_BELL_VERSION for k in ("generated_layout", "encounters")):
        problems.append("v11 formal root versions mismatch")
    matched = 0
    for stage in formal["stages"]:
        output = stage.get("outputs") if isinstance(stage, dict) else None
        if not isinstance(output, dict) or any(not isinstance(output.get(k), dict) for k in ("generated_layout", "stage_generator", "enemy_layout")):
            problems.append("v11 formal stage output missing")
            continue
        recorded = output["generated_layout"]
        if any(value != PLAINS_ROOT_BELL_VERSION for value in (recorded.get("version"), output["stage_generator"].get("version"), output["enemy_layout"].get("version"))):
            problems.append("v11 formal stage contains mixed versions")
        if recorded.get("seed") == manifest.get("seed") and recorded.get("manifest_hash") == manifest.get("manifest_hash"):
            matched += 1
            if recorded != manifest or output["enemy_layout"].get("enemies") != enemies:
                problems.append("v11 analyzed manifest/enemies differ from formal output")
    if matched != 1:
        problems.append("v11 needs one exact formal stage seed/hash match")
    if capture.get("scope") != "formal_manifest_and_assembler_shotlatch_traces_not_enemy_or_boss_completion":
        problems.append("v11 adapter supports the explicit assembler capture contract only")
    for trace in capture.get("traces", []):
        if not isinstance(trace, dict) or trace.get("enemies_instantiated") is not False or trace.get("scope") != "assembler_shotlatch_without_enemies_or_boss_fight":
            problems.append("v11 assembler traces cannot claim active enemy/Boss validation")
    return problems


def _canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)


def _signature(descriptor):
    return {"descriptor": descriptor,
            "sha256": hashlib.sha256(_canonical(descriptor).encode()).hexdigest()}


def _finite(value):
    if isinstance(value, float):
        return math.isfinite(value)
    if isinstance(value, dict):
        return all(_finite(v) for v in value.values())
    if isinstance(value, list):
        return all(_finite(v) for v in value)
    return True


def _number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def _vector(value):
    return isinstance(value, list) and len(value) == 2 and all(_number(x) for x in value)


def _reach(adjacency, start):
    seen, queue = {start}, deque([start])
    while queue:
        for target in adjacency.get(queue.popleft(), []):
            if target not in seen:
                seen.add(target)
                queue.append(target)
    return seen


def _path(adjacency, start, goal):
    queue, previous = deque([start]), {start: None}
    while queue:
        current = queue.popleft()
        if current == goal:
            result = []
            while current is not None:
                result.append(current)
                current = previous[current]
            return list(reversed(result))
        for target in adjacency.get(current, []):
            if target not in previous:
                previous[target] = current
                queue.append(target)
    return []


def seal_report(report):
    """Seal the complete report after CLI provenance/artifacts have been attached."""
    unsigned = {k: v for k, v in report.items() if k != "report_fingerprint"}
    report["report_fingerprint"] = hashlib.sha256(_canonical(unsigned).encode()).hexdigest()
    return report


def analyze_capture(capture, policy=None):
    """Reject malformed JSON structures without allowing an empty success report."""
    try:
        report = _analyze_capture(capture, policy)
        return seal_report(report)
    except (TypeError, ValueError, KeyError, IndexError, AttributeError) as exc:
        return {"schema_version": 1, "producer": "level_design_analysis_v1", "verdict": "REJECT",
                "subjective_quality": "unverified", "maps": [], "routes": [],
                "findings": [{"code": "malformed_capture", "severity": "error", "evidence_kind": "evidence_integrity",
                              "location": {}, "observed": type(exc).__name__,
                              "interpretation": "Invalid capture structure; regenerate evidence using the capture contract."}]}


def _analyze_capture(capture, policy=None):
    """Return REJECT for invalid evidence, otherwise REVIEW, never aesthetic PASS."""
    chosen = deepcopy(DEFAULT_POLICY)
    if policy is not None and isinstance(policy, dict):
        chosen.update(policy)
    report = {"schema_version": 1, "producer": "level_design_analysis_v1",
              "source_commit": capture.get("source_commit") if isinstance(capture, dict) else None,
              "engine": capture.get("engine") if isinstance(capture, dict) else None,
              "policy": chosen, "verdict": "REVIEW", "subjective_quality": "unverified",
              "findings": [], "maps": [], "routes": [],
              "limitations": ["Graph reachability is not physical reachability.",
                              "Evidence consistency is not recording authentication; retain producer logs and replay.",
                              "Candidates require design review; observation and quiet exploration may be intentional.",
                              "Only recorded strategies and devices are covered."]}

    def finding(code, severity, kind, location, observed, interpretation):
        report["findings"].append(dict(code=code, severity=severity, evidence_kind=kind,
                                       location=location, observed=observed, interpretation=interpretation))
        if severity == "error":
            report["verdict"] = "REJECT"

    def error(code, location, observed):
        finding(code, "error", "evidence_integrity", location, observed,
                "Evidence is incomplete or inconsistent; rerun the matching producer/replay.")

    if not isinstance(capture, dict) or not _finite(capture):
        error("invalid_capture", {}, "Expected a finite JSON object")
        return report
    if policy is not None and not isinstance(policy, dict):
        error("invalid_policy", {}, "Expected object")
        return report
    if not _finite(chosen) or any(not _number(chosen.get(k)) or chosen[k] <= 0 for k in
            ["low_interaction_seconds", "low_interaction_distance", "static_join_distance",
             "repeat_chain_count", "pressure_intent_seconds"]):
        error("invalid_policy", {}, "Thresholds must be finite and positive")
        return report
    if any(not isinstance(chosen.get(k), str) or not chosen[k] for k in
           ["id", "biome", "category", "device", "calibration"]):
        error("invalid_policy", {}, "Policy needs identity, scope and calibration state")
        return report
    if capture.get("schema_version") != 1 or not re.fullmatch(r"[a-fA-F0-9]{40}", str(capture.get("source_commit", ""))) or not capture.get("engine"):
        error("capture_provenance", {}, "schema_version=1, full source commit and engine required")
    if capture.get("failures", 0) not in (0, []):
        error("capture_runtime_failures", {}, capture["failures"])
    report["source_basis"] = capture.get("source_basis")
    report["capture_source_hashes"] = capture.get("capture_source_hashes", {})
    manifests, traces = capture.get("manifests"), capture.get("traces")
    if not isinstance(manifests, list) or not manifests:
        error("missing_manifests", {}, "At least one manifest required")
        return report
    if not isinstance(traces, list) or not traces:
        error("missing_traces", {}, "At least one actual route recording required")
        return report
    indexed = {}
    for manifest in manifests:
        if not isinstance(manifest, dict):
            error("invalid_manifest", {}, "Expected object")
            continue
        seed, digest = manifest.get("seed"), manifest.get("manifest_hash")
        location = {"seed": seed, "manifest_hash": digest}
        if not isinstance(seed, str) or not seed or not isinstance(digest, str) or not digest:
            error("manifest_identity", location, "Seed and manifest hash required")
            continue
        if manifest.get("region") == "plains" and manifest.get("version") not in SUPPORTED_PLAINS_VERSIONS:
            error("unsupported_plains_version", location, "Only explicit Plains v8/v9/v10 and source-bound v11 RootBell analysis is supported")
            continue
        formal_versions = capture.get("formal_run_manifest", {}).get("versions", {}) if isinstance(capture.get("formal_run_manifest"), dict) else {}
        v11_declared = (manifest.get("version") == PLAINS_ROOT_BELL_VERSION or "root_bell_admission" in manifest
                        or any(isinstance(e, dict) and e.get("behavior_id") == "root_bell" for e in manifest.get("enemies", []))
                        or (isinstance(formal_versions, dict) and PLAINS_ROOT_BELL_VERSION in formal_versions.values()))
        if manifest.get("region") == "plains" and v11_declared:
            if manifest.get("version") != PLAINS_ROOT_BELL_VERSION:
                error("plains_v11_contract", location, "RootBell/formal v11 data cannot be relabeled as a legacy manifest")
            for issue in _plains_v11_errors(capture, manifest):
                error("plains_v11_contract", location, issue)
            if "Plains v11 enemy records are design data; assembler traces do not validate RootBell combat or Boss completion." not in report["limitations"]:
                report["limitations"].append("Plains v11 enemy records are design data; assembler traces do not validate RootBell combat or Boss completion.")
        key = (seed, digest)
        if key in indexed:
            error("duplicate_manifest", location, key)
            continue
        if chosen["biome"] not in ("any", manifest.get("region")):
            error("policy_scope", location, "Biome differs from policy")
        areas, connections = manifest.get("areas"), manifest.get("connections")
        if not isinstance(areas, list) or not areas or not isinstance(connections, list) or not connections:
            error("invalid_topology", location, "Nonempty areas and connections required")
            continue
        if any(not isinstance(a, dict) or not isinstance(a.get("id"), str) for a in areas):
            error("invalid_area", location, "Area ID required")
            continue
        ids = {a["id"] for a in areas}
        if len(ids) != len(areas):
            error("duplicate_area", location, len(areas) - len(ids))
        adjacency = {i: [] for i in ids}
        reverse = {i: [] for i in ids}
        edge_index, restricted = {}, []
        for edge in connections:
            if not isinstance(edge, dict) or not isinstance(edge.get("id"), str) or edge.get("a") not in ids or edge.get("b") not in ids or not isinstance(edge.get("bidirectional"), bool):
                error("invalid_connection", location, edge)
                continue
            if edge["id"] in edge_index:
                error("duplicate_connection", location, edge["id"])
                continue
            edge_index[edge["id"]] = edge
            if edge.get("condition") != "open":
                restricted.append({"id": edge["id"], "condition": edge.get("condition")})
                continue
            adjacency[edge["a"]].append(edge["b"])
            reverse[edge["b"]].append(edge["a"])
            if edge["bidirectional"]:
                adjacency[edge["b"]].append(edge["a"])
                reverse[edge["a"]].append(edge["b"])
        start = next((a["id"] for a in areas if a.get("role") in ("entry", "spawn")),
                     next((a["id"] for a in areas if a.get("role") == "tutorial"), areas[0]["id"]))
        reachable, returns = _reach(adjacency, start), _reach(reverse, start)
        if reachable != ids:
            finding("unreachable_areas", "review", "graph_only", location,
                    sorted(ids - reachable), "No open directed graph path from entry; inspect intended capability locks.")
        if returns != ids:
            finding("no_open_return", "review", "graph_only", location,
                    sorted(ids - returns), "No open return path; require a verified unlock or one-way evacuation contract.")
        role_routes = [{"area": a["id"], "role": a.get("role"), "path": _path(adjacency, start, a["id"])}
                       for a in areas if a.get("role") in ("boss", "prep", "merchant", "challenge_reward")]
        for reward in manifest.get("rewards", []):
            if isinstance(reward, dict):
                role_routes.append({"area": reward.get("area"), "reward": reward.get("id"),
                                    "tier": reward.get("tier"), "path": _path(adjacency, start, reward.get("area"))})
        # Undirected cycle rank, computed separately from directed reachability.
        undirected = {i: set(adjacency[i]) | set(reverse[i]) for i in ids}
        remaining, components = set(ids), 0
        while remaining:
            remaining -= _reach(undirected, next(iter(remaining)))
            components += 1
        open_edges = [e for e in edge_index.values() if e.get("condition") == "open"]
        topology = {"area_count": len(ids), "open_edge_count": len(open_edges),
                    "weak_components": components, "undirected_cycle_rank": len(open_edges) - len(ids) + components,
                    "branch_areas": sorted(i for i in ids if len(set(adjacency[i])) >= 3),
                    "entry": start, "reachable": sorted(reachable), "returnable": sorted(returns),
                    "restricted_edges": restricted, "role_routes": role_routes}
        descriptors = {"roles": sorted(str(a.get("role", "unknown")) for a in areas),
                       "degree_profile": sorted([len(set(adjacency[i])), len(set(reverse[i]))] for i in ids),
                       "edge_semantics": sorted([str(e.get("kind")), str(e.get("condition")), e["bidirectional"]] for e in edge_index.values())}
        map_report = {**location, "region": manifest.get("region"), "topology": topology,
                      "structure_signature": _signature(descriptors), "static_joins": []}
        for node in manifest.get("nodes", []):
            if not isinstance(node, dict):
                error("invalid_node", location, node)
                continue
            geometry = node.get("geometry", {})
            if node.get("module_id") == "region_connection" and isinstance(geometry, dict):
                slabs = geometry.get("platforms", [])
                if slabs and isinstance(slabs[0], list) and len(slabs[0]) == 4 and _number(slabs[0][2]):
                    width = slabs[0][2]
                    map_report["static_joins"].append({"node": node.get("id"), "width": width})
                    if width >= chosen["static_join_distance"]:
                        finding("static_join_candidate", "review", "generated_geometry", {**location, "node": node.get("id")},
                                {"width": width, "enemies": [e.get("id") for e in manifest.get("enemies", []) if e.get("area") == node.get("id")]},
                                "Long connector candidate; inspect actual route interaction and intended observation/recovery.")
        source_hashes = capture.get("capture_source_hashes", {})
        scenery_hash = source_hashes.get("res://scripts/art/plains_region_scenery.gd", source_hashes.get("scripts/art/plains_region_scenery.gd"))
        # Only an observed original consumer supports this historical projection.
        if (manifest.get("region") == "plains" and manifest.get("version") == "plains-region-v8"
                and scenery_hash == LEGACY_PLAINS_SCENERY_SHA256):
            landmarks = [{"area": a["id"], "declared": a.get("landmark"),
                          "rendered_if_supported": "windmill" if a.get("landmark") == "windmill" else "ruin_arch"}
                         for a in areas if a.get("role") in ("rest", "camp", "junction", "entry", "merchant")]
            map_report["scenery_projection"] = landmarks
            folded = [a for a in landmarks if a["declared"] and a["declared"] != a["rendered_if_supported"]]
            if folded:
                finding("scenery_identity_fold", "review", "consumer_source_projection", location, folded,
                        "PlainsRegionScenery maps these labels to ruin_arch if supporting ground exists; verify actual screenshots, not label counts.")
        elif manifest.get("region") == "plains" and not scenery_hash:
            finding("scenery_consumer_identity_unknown", "review", "missing_consumer_source", location,
                    {"version": manifest.get("version"), "status": "unverified"},
                    "No observed scenery consumer hash; landmark labels do not establish rendered asset identity. Inspect a formal inventory and screenshots.")
        report["maps"].append(map_report)
        indexed[key] = (manifest, edge_index)
    identities = set()
    used_manifests = set()
    for trace_index, trace in enumerate(traces):
        location = {"trace_index": trace_index}
        if not isinstance(trace, dict):
            error("invalid_trace", location, "Expected object")
            continue
        location.update({k: trace.get(k) for k in ("seed", "manifest_hash", "strategy")})
        key = (trace.get("seed"), trace.get("manifest_hash"))
        if key not in indexed:
            error("trace_manifest_mismatch", location, "No exact seed/hash pair")
            continue
        manifest, edge_index = indexed[key]
        used_manifests.add(key)
        required_strings = ("strategy", "scope", "device")
        hz = trace.get("physics_hz")
        capability = trace.get("capability")
        if any(not isinstance(trace.get(k), str) or not trace[k] for k in required_strings) or not isinstance(trace.get("enemies_instantiated"), bool) or not _number(hz) or hz <= 0 or not isinstance(capability, dict) or not capability:
            error("trace_contract", location, "Strategy/scope/device/enemy scope/physics Hz/nonempty capability required")
            continue
        if chosen["device"] not in ("any", trace["device"]):
            error("policy_scope", location, "Device differs from policy")
        weapon = capability.get("equipped_weapon")
        if not isinstance(weapon, dict) or not weapon.get("id") or not isinstance(capability.get("granted_actions"), list) or not capability["granted_actions"] or not isinstance(capability.get("tuning"), dict) or not capability["tuning"]:
            error("capability_contract", location, "Actual single equipped weapon, granted actions and tuning required")
            continue
        if trace.get("actions_semantics") != "router_input_requests_not_accepted_action_events":
            error("action_semantics", location, "This version consumes explicit router requests; accepted events need a separate producer contract")
            continue
        identity = (key, trace["strategy"], trace["device"], _canonical(capability), hz)
        if identity in identities:
            error("duplicate_trace", location, "Duplicate strategy/capability recording")
        identities.add(identity)
        failures = trace.get("failures")
        if not isinstance(failures, list) or failures:
            error("runtime_failures", location, failures)
        frames, edges = trace.get("frames"), trace.get("edges")
        if not isinstance(frames, list) or len(frames) < 2 or not isinstance(edges, list) or not edges:
            error("empty_trace", location, "At least two frames and one actual edge required")
            continue
        valid = True
        for index, frame in enumerate(frames):
            if not isinstance(frame, dict) or not isinstance(frame.get("tick"), int) or isinstance(frame["tick"], bool) or frame["tick"] < 0 or not _vector(frame.get("position")) or not _vector(frame.get("velocity")) or not isinstance(frame.get("grounded"), bool) or not _number(frame.get("shots")) or frame["shots"] < 0 or not _number(frame.get("shot_energy")) or frame["shot_energy"] < 0 or not _number(frame.get("axis")) or abs(frame["axis"]) > 1 or not isinstance(frame.get("actions"), list):
                error("invalid_frame", {**location, "frame": index}, "Missing or invalid runtime state")
                valid = False
                break
            for action in frame["actions"]:
                if not isinstance(action, dict) or not isinstance(action.get("type"), str) or not action["type"] or ("direction" in action and not _vector(action["direction"])):
                    error("invalid_action", {**location, "tick": frame["tick"]}, action)
                    valid = False
            if (frame["shots"] != int(frame["shots"]) or
                    (_number(capability.get("air_shot_flight_cap")) and frame["shots"] > capability["air_shot_flight_cap"]) or
                    (_number(capability.get("shot_energy", {}).get("capacity")) and frame["shot_energy"] > capability["shot_energy"]["capacity"] + 1e-6)):
                error("resource_capacity_exceeded", {**location, "tick": frame["tick"]},
                      {"remaining_air_shots": frame["shots"], "shot_energy": frame["shot_energy"]})
                valid = False
            if index:
                previous = frames[index - 1]
                if frame["tick"] != previous["tick"] + 1:
                    error("trace_time_or_counter", {**location, "tick": frame["tick"]}, "Ticks must be consecutive")
                    valid = False
                distance = math.dist(previous["position"], frame["position"])
                # Broad consistency guard, not a new movement capability envelope.
                bound = max(64.0, 2 * max(math.hypot(*previous["velocity"]), math.hypot(*frame["velocity"])) / hz + 16)
                if distance > bound:
                    error("position_discontinuity", {**location, "tick": frame["tick"]}, {"distance": distance, "consistency_bound": bound})
                    valid = False
            if frame.get("safe_trace") is False or frame.get("continuous_trace") is False:
                error("runtime_safety_failure", {**location, "tick": frame["tick"]}, "Producer reports hazard contact or discontinuity")
                valid = False
        if not valid:
            continue
        route = {**location, **{k: trace[k] for k in ("device", "physics_hz", "capability", "scope", "enemies_instantiated")},
                 "edges": [], "stats": {"duration_seconds": (frames[-1]["tick"] - frames[0]["tick"]) / hz,
                                         "frame_count": len(frames), "first_tick": frames[0]["tick"], "last_tick": frames[-1]["tick"],
                                         "distance": sum(math.dist(a["position"], b["position"]) for a, b in zip(frames, frames[1:])),
                                         "observed_air_shot_capacity_spent": sum(max(0, a["shots"] - b["shots"]) for a, b in zip(frames, frames[1:]))}}
        route["actions_semantics"] = trace["actions_semantics"]
        previous_end, seen_edges, recipes, chains = -1, Counter(), [], []
        input_chains, previous_destination = [], None
        area_positions = {a["id"]: a.get("position") for a in manifest["areas"]}
        pressure_seconds, pressure_max = 0.0, 0.0
        for ordinal, visit in enumerate(edges):
            edge_location = {**location, "edge_ordinal": ordinal}
            if not isinstance(visit, dict) or not isinstance(visit.get("forward"), bool):
                error("invalid_trace_edge", edge_location, visit)
                continue
            edge = edge_index.get(visit.get("id"))
            if edge is None and visit.get("kind") == "challenge_and_evacuation":
                areas = [a for a in manifest["areas"] if a["id"] == visit.get("id") and a.get("role") == "challenge_reward"]
                incoming = [e for e in edge_index.values() if e["b"] == visit.get("id") and e.get("kind") == "challenge" and e.get("condition") == "open"]
                outgoing = [e for e in edge_index.values() if e["a"] == visit.get("id") and e.get("kind") == "drop" and e.get("condition") == "open"]
                if len(areas) == len(incoming) == len(outgoing) == 1 and visit["forward"]:
                    edge = {"bidirectional": False, "kind": "challenge_and_evacuation",
                            "a": incoming[0]["a"], "b": outgoing[0]["b"],
                            "aggregate_connections": [incoming[0]["id"], outgoing[0]["id"]]}
            if edge is None:
                error("invalid_trace_edge", edge_location, visit)
                continue
            if visit.get("passed") is False:
                error("runtime_edge_failure", edge_location, visit)
            edge_location["edge"] = visit["id"]
            start, end = visit.get("start_tick"), visit.get("end_tick")
            if not isinstance(start, int) or not isinstance(end, int) or start < previous_end or end <= start or start < frames[0]["tick"] or end > frames[-1]["tick"]:
                error("edge_time_range", edge_location, visit)
                continue
            previous_end = end
            if not visit["forward"] and not edge["bidirectional"]:
                error("illegal_edge_direction", edge_location, visit)
                continue
            selected = frames[start - frames[0]["tick"]:end - frames[0]["tick"] + 1]
            source = edge["a"] if visit["forward"] else edge["b"]
            destination = edge["b"] if visit["forward"] else edge["a"]
            if previous_destination is not None and source != previous_destination:
                error("disconnected_recorded_itinerary", edge_location,
                      {"previous_destination": previous_destination, "next_source": source})
            previous_destination = destination
            for endpoint, frame in [(source, selected[0]), (destination, selected[-1])]:
                if _vector(area_positions.get(endpoint)) and math.dist(area_positions[endpoint], frame["position"]) > 64:
                    error("edge_position_mismatch", {**edge_location, "tick": frame["tick"]},
                          {"area": endpoint, "recorded_position": frame["position"], "area_position": area_positions[endpoint]})
            descriptor, requests, run_start, run_distance, longest = [], [], None, 0.0, {"seconds": 0.0, "distance": 0.0}
            for offset, frame in enumerate(selected):
                previous = selected[offset - 1] if offset else frame
                events = []
                for action in frame["actions"]:
                    direction = action.get("direction", [0, 0])
                    requests.append({"type": action["type"], "direction_octant": [0 if abs(v) < .2 else (1 if v > 0 else -1) for v in direction]})
                if frame["shots"] < previous["shots"]:
                    events.append("air_shot_capacity_spent")
                if frame["grounded"] and not previous["grounded"]:
                    events.append("land")
                if not frame["grounded"] and previous["grounded"]:
                    events.append("leave_ground")
                if frame["velocity"][0] * previous["velocity"][0] < -1:
                    events.append("turn")
                # A rejected jump/shoot request must not manufacture interaction.
                # Energy consumption is an observed effect even for grounded shots.
                if frame["shot_energy"] < previous["shot_energy"]:
                    events.append("shot_energy_spent")
                descriptor.extend(events)
                inactive = frame["grounded"] and previous["grounded"] and not events and abs(frame["velocity"][0]) > 1
                if inactive:
                    if run_start is None:
                        run_start = previous["tick"]
                        run_distance = 0.0
                    run_distance += math.dist(frame["position"], previous["position"])
                    seconds = (frame["tick"] - run_start) / hz
                    if seconds > longest["seconds"]:
                        longest = {"seconds": seconds, "distance": run_distance, "start_tick": run_start, "end_tick": frame["tick"]}
                else:
                    run_start = None
            duration = (end - start) / hz
            intent = {"recipe": edge.get("recipe"), "actions": edge.get("action_signature", edge.get("actions")),
                      "pressure": edge.get("pressure"), "decision": edge.get("decision")}
            if intent["pressure"]:
                pressure_seconds += duration
                pressure_max = max(pressure_max, pressure_seconds)
            else:
                pressure_seconds = 0.0
            data = {**visit, "duration_seconds": duration, "intent": intent, "actual_action_signature": _signature(descriptor),
                    "input_request_signature": _signature(requests), "aggregate_connections": edge.get("aggregate_connections", []),
                    "low_interaction_run": longest, "revisit": seen_edges[visit["id"]] > 0,
                    "energy_min": min(f["shot_energy"] for f in selected),
                    "observed_energy_recovered": sum(max(0, b["shot_energy"] - a["shot_energy"]) for a, b in zip(selected, selected[1:])),
                    "grounded_seconds": sum(f["grounded"] for f in selected[:-1]) / hz}
            route["edges"].append(data)
            seen_edges[visit["id"]] += 1
            recipes.append(intent["actions"])
            chains.append(descriptor)
            input_chains.append(requests)
            if longest["seconds"] >= chosen["low_interaction_seconds"] and longest["distance"] >= chosen["low_interaction_distance"]:
                finding("low_interaction_candidate", "review", "runtime_observation", edge_location, longest,
                        "Continuous grounded movement without recorded action/airborne/turn events; inspect observation, recovery and enemy scope before judging boredom.")
        if not route["edges"]:
            error("no_valid_edges", location, "No verified edge interval remains")
        counts = Counter(_canonical(chain) for chain in chains if chain)
        for chain, count in counts.items():
            if count >= chosen["repeat_chain_count"]:
                finding("repeated_actual_action_chain", "review", "runtime_observation", location,
                        {"descriptor": json.loads(chain), "count": count}, "Repeated observed state transitions on this itinerary; submitted input requests remain separate and route revisits may be intentional.")
        for phrase, count in Counter(_canonical(phrase) for phrase in recipes if phrase).items():
            if count >= chosen["repeat_chain_count"]:
                finding("repeated_action_intent", "review", "design_intent_on_recorded_route", location,
                        {"descriptor": json.loads(phrase), "count": count},
                        "The same authored action phrase recurs on this itinerary; compare actual input and state transitions before revising it.")
        if pressure_max >= chosen["pressure_intent_seconds"]:
            finding("continuous_pressure_intent", "review", "design_intent_on_recorded_route", location,
                    {"seconds": pressure_max}, "Adjacent recipe pressure tags persist; this is not measured enemy pressure or player fatigue.")
        route["stats"].update({"edge_visits": len(route["edges"]), "unique_edges": len(seen_edges),
                               "revisits": sum(max(0, n - 1) for n in seen_edges.values()),
                               "max_continuous_pressure_intent_seconds": pressure_max,
                               "low_interaction_candidates": sum(e["low_interaction_run"]["seconds"] >= chosen["low_interaction_seconds"] and e["low_interaction_run"]["distance"] >= chosen["low_interaction_distance"] for e in route["edges"])})
        covered_ticks = {tick for edge in route["edges"] for tick in range(edge["start_tick"], edge["end_tick"] + 1)}
        route["stats"]["frames_outside_recorded_edges"] = len(frames) - len(covered_ticks)
        route["interval_scope"] = "Edge diagnostics exclude unassigned frames (for example the tutorial prefix); aggregate challenge intervals have no inferred internal edge boundary."
        route["action_signature"] = _signature(chains)
        route["input_request_signature"] = _signature(input_chains)
        route["intent_signature"] = _signature(recipes)
        report["routes"].append(route)
    for key in indexed.keys() - used_manifests:
        error("manifest_without_trace", {"seed": key[0], "manifest_hash": key[1]}, "Manifest has no matched runtime trace")
    if not report["routes"]:
        error("no_analyzable_routes", {}, "No complete route evidence")
    return report


def _report_errors(report):
    """Validate this producer's complete report, including its content binding.

    This fingerprint detects accidental edits/truncation, not malicious forgery.
    Replay and capture provenance remain the external evidence authority.
    """
    errors = []
    def require(ok, message):
        if not ok:
            errors.append(message)
    def signature(value, label):
        require(isinstance(value, dict) and set(value) == {"descriptor", "sha256"}, label + " signature shape")
        if isinstance(value, dict) and "descriptor" in value:
            require(value.get("sha256") == _signature(value["descriptor"])["sha256"], label + " descriptor/hash mismatch")
            require(isinstance(value["descriptor"], dict if label == "map structure" else list), label + " descriptor type")
    def nonempty(value):
        return isinstance(value, str) and bool(value)
    require(isinstance(report, dict) and _finite(report), "finite report object required")
    if not isinstance(report, dict) or not _finite(report):
        return errors
    require(report.get("schema_version") == 1 and report.get("producer") == "level_design_analysis_v1", "report schema/producer")
    require(report.get("verdict") == "REVIEW" and report.get("subjective_quality") == "unverified", "valid bounded evidence verdict required")
    require(bool(re.fullmatch(r"[a-fA-F0-9]{40}", str(report.get("source_commit", "")))), "full source commit required")
    require(nonempty(report.get("engine")), "engine required")
    require("source_basis" in report and isinstance(report.get("capture_source_hashes"), dict), "source basis/hash metadata required")
    if report.get("source_basis") is not None:
        require(bool(re.fullmatch(r"[a-fA-F0-9]{64}", str(report["source_basis"]))), "invalid source basis")
    for path, digest in report.get("capture_source_hashes", {}).items():
        require(nonempty(path) and bool(re.fullmatch(r"[a-fA-F0-9]{64}", str(digest))), "invalid capture source hash")
    unsigned = {k: v for k, v in report.items() if k != "report_fingerprint"}
    require(report.get("report_fingerprint") == hashlib.sha256(_canonical(unsigned).encode()).hexdigest(), "report content fingerprint mismatch")
    require(isinstance(report.get("limitations"), list) and bool(report["limitations"]), "report limitations required")
    require(isinstance(report.get("policy"), dict) and all(k in report["policy"] for k in DEFAULT_POLICY), "complete policy required")
    if isinstance(report.get("policy"), dict):
        for key, default in DEFAULT_POLICY.items():
            value = report["policy"].get(key)
            require(nonempty(value) if isinstance(default, str) else _number(value) and value > 0, "invalid policy field " + key)
    findings = report.get("findings")
    require(isinstance(findings, list), "findings required")
    if isinstance(findings, list):
        for item in findings:
            require(isinstance(item, dict) and all(k in item for k in ("code", "severity", "evidence_kind", "location", "observed", "interpretation")) and item.get("severity") != "error", "failed or incomplete finding")
    maps, routes = report.get("maps"), report.get("routes")
    require(isinstance(maps, list) and bool(maps), "nonempty maps required")
    require(isinstance(routes, list) and bool(routes), "nonempty routes required")
    if not isinstance(maps, list) or not isinstance(routes, list):
        return errors
    map_keys = set()
    for item in maps:
        require(isinstance(item, dict), "map object required")
        if not isinstance(item, dict):
            continue
        seed, digest = item.get("seed"), item.get("manifest_hash")
        require(nonempty(seed) and bool(re.fullmatch(r"[a-fA-F0-9]{64}", str(digest))), "map seed/full manifest hash required")
        if not nonempty(seed) or not nonempty(digest):
            continue
        require((seed, digest) not in map_keys, "duplicate map identity")
        map_keys.add((seed, digest))
        require(nonempty(item.get("region")), "map biome required")
        topology = item.get("topology")
        require(isinstance(topology, dict) and all(k in topology for k in ("area_count", "open_edge_count", "weak_components", "undirected_cycle_rank", "branch_areas", "entry", "reachable", "returnable", "restricted_edges", "role_routes")), "complete topology required")
        if isinstance(topology, dict):
            require(all(type(topology.get(k)) is int and topology[k] >= 0 for k in ("area_count", "open_edge_count", "weak_components", "undirected_cycle_rank")) and topology.get("area_count", 0) > 0, "invalid topology counts")
            require(all(isinstance(topology.get(k), list) for k in ("branch_areas", "reachable", "returnable", "restricted_edges", "role_routes")) and nonempty(topology.get("entry")), "invalid topology descriptors")
        require(isinstance(item.get("static_joins"), list), "static joins required")
        signature(item.get("structure_signature"), "map structure")
    required_stats = ("duration_seconds", "frame_count", "first_tick", "last_tick", "distance", "observed_air_shot_capacity_spent", "edge_visits", "unique_edges", "revisits", "max_continuous_pressure_intent_seconds", "low_interaction_candidates", "frames_outside_recorded_edges")
    route_keys = set()
    matched_maps = set()
    for route in routes:
        require(isinstance(route, dict), "route object required")
        if not isinstance(route, dict):
            continue
        require(all(nonempty(route.get(k)) for k in ("seed", "manifest_hash", "strategy", "scope", "device", "interval_scope")), "route identity/scope required")
        identity = (route.get("seed"), route.get("manifest_hash"))
        require(identity in map_keys, "route must match map identity")
        matched_maps.add(identity)
        hz = route.get("physics_hz")
        require(_number(hz) and hz > 0 and isinstance(route.get("enemies_instantiated"), bool), "route physics/enemy scope required")
        capability = route.get("capability")
        require(isinstance(capability, dict) and isinstance(capability.get("equipped_weapon"), dict) and nonempty(capability["equipped_weapon"].get("id")) and isinstance(capability.get("granted_actions"), list) and bool(capability["granted_actions"]) and isinstance(capability.get("tuning"), dict) and bool(capability["tuning"]), "complete single-weapon capability required")
        require(route.get("actions_semantics") == "router_input_requests_not_accepted_action_events", "input semantics required")
        key = _canonical({k: route.get(k) for k in ("seed", "strategy", "device", "physics_hz", "capability", "scope", "enemies_instantiated")})
        require(key not in route_keys, "duplicate route identity")
        route_keys.add(key)
        stats, edges = route.get("stats"), route.get("edges")
        require(isinstance(stats, dict) and all(_number(stats.get(k)) and stats[k] >= 0 for k in required_stats), "complete finite nonnegative route statistics required")
        require(isinstance(edges, list) and bool(edges), "nonempty route edges required")
        for name in ("action_signature", "input_request_signature", "intent_signature"):
            signature(route.get(name), "route " + name)
        if not isinstance(stats, dict) or any(not _number(stats.get(k)) for k in required_stats) or not isinstance(edges, list) or not _number(hz) or hz <= 0:
            continue
        require(stats["frame_count"] >= 2 and stats["frame_count"] == stats["last_tick"] - stats["first_tick"] + 1, "frame range/count inconsistency")
        require(all(type(stats[k]) is int for k in ("frame_count", "first_tick", "last_tick", "edge_visits", "unique_edges", "revisits", "low_interaction_candidates", "frames_outside_recorded_edges")), "integer counters required")
        require(math.isclose(stats["duration_seconds"], (stats["last_tick"] - stats["first_tick"]) / hz), "duration/frame inconsistency")
        require(stats["edge_visits"] == len(edges) and stats["frames_outside_recorded_edges"] <= stats["frame_count"], "edge/frame count inconsistency")
        observed, requests, intents, visits, intervals = [], [], [], Counter(), []
        for edge in edges:
            require(isinstance(edge, dict), "edge object required")
            if not isinstance(edge, dict):
                continue
            require(nonempty(edge.get("id")) and isinstance(edge.get("forward"), bool), "edge identity/direction")
            start, end = edge.get("start_tick"), edge.get("end_tick")
            require(type(start) is int and type(end) is int and stats["first_tick"] <= start < end <= stats["last_tick"], "edge tick interval")
            if type(start) is int and type(end) is int:
                require(_number(edge.get("duration_seconds")) and math.isclose(edge["duration_seconds"], (end - start) / hz), "edge duration mismatch")
                if stats["first_tick"] <= start < end <= stats["last_tick"]:
                    intervals.append((start, end))
            require(isinstance(edge.get("intent"), dict) and all(k in edge["intent"] for k in ("recipe", "actions", "pressure", "decision")), "edge intent required")
            require(isinstance(edge.get("low_interaction_run"), dict) and all(_number(edge["low_interaction_run"].get(k)) and edge["low_interaction_run"][k] >= 0 for k in ("seconds", "distance")), "edge observation required")
            for name in ("actual_action_signature", "input_request_signature"):
                signature(edge.get(name), "edge " + name)
            observed.append(edge.get("actual_action_signature", {}).get("descriptor"))
            requests.append(edge.get("input_request_signature", {}).get("descriptor"))
            intents.append(edge.get("intent", {}).get("actions"))
            visits[edge.get("id")] += 1
        require(route.get("action_signature", {}).get("descriptor") == observed and route.get("input_request_signature", {}).get("descriptor") == requests and route.get("intent_signature", {}).get("descriptor") == intents, "route signatures must match edge descriptors")
        require(stats["unique_edges"] == len(visits) and stats["revisits"] == sum(max(0, n - 1) for n in visits.values()), "visit statistics mismatch")
        covered_count, last = 0, -1
        for start, end in sorted(intervals):
            covered_count += max(0, end - max(start, last + 1) + 1)
            last = max(last, end)
        require(stats["frames_outside_recorded_edges"] == stats["frame_count"] - covered_count, "unassigned frame statistics mismatch")
    require(matched_maps == map_keys, "all maps need matched route evidence")
    return errors


def compare_reports(before, after):
    try:
        return _compare_reports(before, after)
    except (TypeError, ValueError, KeyError, IndexError, AttributeError):
        return {"schema_version": 1, "verdict": "REJECT", "subjective_quality": "unverified",
                "mismatches": ["Malformed report structure"], "routes": []}


def _compare_reports(before, after):
    """Compare matching recorded scopes. Different source/manifest hashes are explicit."""
    result = {"schema_version": 1, "verdict": "REJECT", "subjective_quality": "unverified", "mismatches": [], "routes": []}
    if not isinstance(before, dict) or not isinstance(after, dict):
        result["mismatches"].append("Both reports must be objects")
        return result
    for label, report in (("before", before), ("after", after)):
        result["mismatches"].extend(label + ": " + issue for issue in _report_errors(report))
    if result["mismatches"]:
        return result
    if before.get("verdict") != "REVIEW" or after.get("verdict") != "REVIEW":
        result["mismatches"].append("Both captures must have valid evidence")
    for key in ("policy", "engine"):
        if before.get(key) != after.get(key):
            result["mismatches"].append(key)
    def indexed(report):
        value = {}
        for route in report.get("routes", []):
            key = _canonical({k: route.get(k) for k in ("seed", "strategy", "device", "physics_hz", "capability", "scope", "enemies_instantiated")})
            if key in value:
                result["mismatches"].append("duplicate comparison identity")
            value[key] = route
        return value
    try:
        old, new = indexed(before), indexed(after)
    except (TypeError, ValueError):
        result["mismatches"].append("Invalid report structure")
        return result
    if not old or old.keys() != new.keys():
        result["mismatches"].append("seed/strategy/device/physics/capability/scope route set")
    if result["mismatches"]:
        return result
    for key in sorted(old):
        first, second = old[key], new[key]
        result["routes"].append({"identity": json.loads(key),
            "manifest_changed": first["manifest_hash"] != second["manifest_hash"],
            "before_manifest_hash": first["manifest_hash"], "after_manifest_hash": second["manifest_hash"],
            "stats_delta": {k: second["stats"][k] - first["stats"][k] for k in first["stats"] if k in second["stats"]},
            "actual_action_changed": first["action_signature"]["descriptor"] != second["action_signature"]["descriptor"]})
    result.update(verdict="REVIEW", source_changed=any(before.get(k) != after.get(k) for k in ("source_commit", "source_basis", "capture_source_hashes")),
                  interpretation="Paired observations only; changes are not an automatic quality improvement.")
    return result
