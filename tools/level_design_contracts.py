"""Level Design V2 design-intent contract, consumed by the existing Harness extension.

This validates declarations and graph paths, never PlayerMotor reachability or fun.
No runtime parameter defaults are duplicated here. The fixtures are design-only.
"""
from __future__ import annotations

from collections import deque
import math
import re
from typing import Any

EXPERIENCE_CATEGORIES = (
    "safe_exploration", "teaching", "platforming", "action_combination",
    "combat_platforming", "reward_challenge", "hidden_master", "boss_space",
)
CHALLENGE_AXES = (
    "learned_mechanisms", "chain_depth", "mechanism_coupling", "route_choice",
    "air_control", "timing", "resource_management", "failure_cost",
    "combat_platforming", "ability_depth",
)
# Compact schema vocabulary: nonempty text, number, boolean, list, enum, object.
TEXT = "text"
NUMBER = "number"
BOOL = "bool"
MAX_CAPABILITY_STATES = 16384


def validate_region_production_proof(data, contract):
    """Validate native region proof identity, never turn shared regressions into it.

    File hashes, command completion and source freshness are checked by the
    production_loop consumer. This function alone is a declaration check.
    """
    errors = []
    if not isinstance(data, dict):
        return ["Missing region-specific native capture"]
    if (not contract.get("region_id") or data.get("region_id") != contract["region_id"]
            or data.get("proof_kind") != contract["kind"]
            or data.get("scope") != "actual_region_" + contract["scope"]
            or data.get("artifact_kind") != "region_production_capture"):
        errors.append("Region/kind/scope mismatch; shared Plains/Foundry captures are not regional proof")
    if (type(data.get("assertions")) is not int or data["assertions"] <= 0
            or data.get("failures") != [] or not isinstance(data.get("observations"), list) or not data["observations"]):
        errors.append("Region proof lacks nonempty native assertions/observations")
    consumer = data.get("consumer")
    if (not isinstance(consumer, str) or not consumer.startswith(("scripts/", "scenes/"))
            or ".." in consumer.split("/") or not re.fullmatch(r"[0-9a-f]{40}", str(data.get("source_commit", "")))):
        errors.append("Region proof lacks real consumer/source binding")
    capabilities = data.get("capability_snapshot", {})
    alternatives = contract.get("capability_gate", {}).get("alternatives", [])
    if (not isinstance(capabilities, dict) or not isinstance(capabilities.get("abilities"), list)
            or any(not isinstance(a, str) for a in capabilities.get("abilities", []))
            or not isinstance(capabilities.get("equipped_weapon"), str) or not capabilities.get("equipped_weapon")
            or type(capabilities.get("current_weapon_count")) is not int or capabilities.get("current_weapon_count") != 1
            or (alternatives and not any(set(a) <= set(capabilities.get("abilities", [])) for a in alternatives))):
        errors.append("Region proof lacks observed lawful single-weapon entry capabilities")
    allowed = contract.get("allowed_capabilities")
    if allowed is not None and (not isinstance(allowed, list) or any(not isinstance(a, str) for a in allowed)
            or not isinstance(capabilities, dict) or not isinstance(capabilities.get("abilities"), list)
            or any(not isinstance(a, str) or a not in allowed for a in capabilities["abilities"])):
        errors.append("Region proof contains capabilities outside the authorized prototype")
    if contract.get("region_id") == "thorn_forest" and contract.get("kind") == "golden" and contract.get("scope") == "prototype":
        errors.extend(_validate_forest_h_trace(data))
    return errors


def validate_forest_h_slice(data):
    """Check actual canopy trace semantics; native receipts are checked separately."""
    return validate_region_production_proof(data, {"region_id": "thorn_forest", "kind": "golden", "scope": "prototype",
                "capability_gate": {"alternatives": [["H"]]}, "allowed_capabilities": ["H"]})


def _forest_finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def _forest_pair(value):
    return isinstance(value, list) and len(value) == 2 and all(_forest_finite(v) for v in value)


def _validate_forest_causality(data, raw, final, frames, events, requests):
    """Consume accepted transitions, not a list of callback names or a reached flag."""
    errors = []
    states = ["hook_cast", "hook_fly", "hook_pull", "hook_contact_kick", "hook_kick", "free"]
    transitions, landings = [], []
    previous_state = raw.get("traversal_state")
    previous_position = raw.get("position")
    previous_grounded = raw.get("grounded")
    for frame in frames:
        state, tick = frame.get("traversal"), frame["tick"]
        expected_used = state in states[:4]
        if (state not in states or type(frame.get("hook_used")) is not bool
                or frame["hook_used"] != expected_used or type(frame.get("grounded")) is not bool):
            errors.append("Canopy observed traversal/hook token is not the accepted H-only state")
        if state != previous_state:
            transitions.append({"tick": tick, "kind": state, "position": previous_position})
        if frame.get("grounded") is True and previous_grounded is False:
            landings.append({"tick": tick, "kind": "landed", "position": frame["position"], "supports": frame["supports"]})
        previous_state, previous_position, previous_grounded = state, frame["position"], frame.get("grounded")
    if raw.get("traversal_state") != "free" or [t["kind"] for t in transitions] != states:
        errors.append("Canopy observed traversal state transitions lack the complete ordered accepted hook chain")
    if (final.get("traversal_state") != previous_state or final.get("position") != previous_position
            or final.get("grounded") != previous_grounded or final.get("hook_used") != frames[-1].get("hook_used")):
        errors.append("Canopy final snapshot is not the last actual observed state")
    expected = sorted(transitions + landings, key=lambda e: e["tick"])
    if (any(type(e.get("tick")) is not int or not 1 <= e["tick"] <= len(frames) for e in events)
            or events != expected):
        errors.append("Canopy events must equal actual frame-bound state transitions and landing edges")
    valid_request = (isinstance(requests, list) and len(requests) == 1 and isinstance(requests[0], dict)
                     and type(requests[0].get("tick")) is int and 1 <= requests[0]["tick"] <= len(frames))
    if not valid_request or not transitions or requests[0]["tick"] != transitions[0]["tick"] or transitions[0]["kind"] != "hook_cast":
        errors.append("Canopy Router request must causally enter the observed cast in the same actual tick")
    else:
        direction = requests[0].get("direction")
        if not _forest_pair(direction) or abs(math.hypot(*direction) - 1) > 1e-6:
            errors.append("Canopy Router request lacks finite normalized actual aim")
        else:
            for frame in frames[requests[0]["tick"] - 1:]:
                observed = frame.get("hook_direction")
                if not _forest_pair(observed) or any(abs(a - b) > 1e-6 for a, b in zip(direction, observed)):
                    errors.append("Canopy accepted hook direction is not the actual Router aim")
                    break
    # This deliberately no-shot/no-damage sample has no legal resource changes.
    # Bounds come from actual read-only state/Definition snapshots, never defaults.
    energy = raw["shot_energy"]
    health = raw.get("health")
    air = raw.get("air_shots")
    flight_cap = raw.get("air_shot_flight_cap")
    if (not _forest_finite(energy.get("capacity")) or energy["capacity"] <= 0
            or not _forest_finite(energy.get("current")) or not 0 <= energy["current"] <= energy["capacity"]
            or type(air) is not int or type(flight_cap) is not int or not 0 <= air <= flight_cap):
        errors.append("Canopy lacks lawful actual resource snapshot budgets")
    if (not isinstance(health, dict) or any(not _forest_finite(health.get(k)) for k in
            ("current", "capacity", "definition_capacity", "definition_initial"))
            or not 0 < health.get("current", 0) <= health.get("capacity", 0)
            or health.get("capacity") != health.get("definition_capacity")
            or health.get("current") != health.get("definition_initial")
            or not isinstance(health.get("definition_path"), str) or not health["definition_path"].startswith("res://resources/")
            or not re.fullmatch(r"[0-9a-f]{64}", str(health.get("definition_sha256", "")))):
        errors.append("Canopy lacks lawful observed HP and actual HealthDefinition budget")
    else:
        if final.get("health") != health:
            errors.append("Canopy changed HP or its Definition during the no-damage sample")
        for frame in frames:
            if (not _forest_finite(frame.get("health")) or not 0 < frame["health"] <= health["capacity"]
                    or frame["health"] != health["current"]):
                errors.append("Canopy HP trace violates actual initial/Definition no-damage budget")
                break
    for frame in frames:
        if (not _forest_finite(frame.get("energy")) or not _forest_finite(energy.get("capacity"))
                or not 0 <= frame["energy"] <= energy["capacity"] or frame["energy"] != energy.get("current")
                or type(frame.get("air_shots")) is not int or frame["air_shots"] != air):
            errors.append("Canopy per-frame resources violate the actual no-shot snapshot budget")
            break
    if (final.get("shot_energy") != energy or final.get("air_shots") != air
            or final.get("air_shot_flight_cap") != flight_cap or raw.get("active") is not True or final.get("active") is not True):
        errors.append("Canopy final resource/active state changed without an accepted cause")
    return list(dict.fromkeys(errors))


def _validate_forest_h_trace(data):
    errors = []
    if not isinstance(data, dict):
        return ["Missing native forest trace"]
    snapshot = data.get("capability_snapshot", {})
    raw = snapshot.get("raw", {}) if isinstance(snapshot, dict) else None
    final = data.get("final_capability_snapshot", {})
    if (not isinstance(raw, dict) or not isinstance(final, dict)
            or any(not isinstance(state.get(key), dict) for state in (raw, final)
                   for key in ("equipped_weapon", "shot_energy", "config_hashes", "tuning"))):
        return ["Missing actual initial/final capability snapshots"]
    if (raw.get("granted_actions") != ["jump", "shot_recoil", "grapple"]
            or raw.get("effective_max_jumps") != 1 or final.get("effective_max_jumps") != 1
            or raw.get("equipped_weapon", {}).get("tier") != 1
            or raw.get("equipped_weapon", {}).get("id") != "pulse_gun"
            or final.get("equipped_weapon", {}).get("id") != "pulse_gun"):
        errors.append("Canopy requires actual base actions plus H only and single PulseLv1")
    scope = data.get("captured_scope", {})
    if not isinstance(scope, dict):
        return [*errors, "Canopy captured scope malformed"]
    if (scope.get("normal_controller_physics") is not True or any(scope.get(k) is not False for k in
            ("manual_motor_or_controller_step", "midroute_position_or_resource_injection", "formal_region_opened", "formal_H_grant"))):
        errors.append("Canopy execution scope is not isolated normal-physics input")
    events = data.get("events", [])
    order = ["hook_cast", "hook_fly", "hook_pull", "hook_contact_kick", "hook_kick"]
    if not isinstance(events, list):
        return [*errors, "Canopy events malformed"]
    cursor, previous_event = 0, 0
    for event in events:
        if not isinstance(event, dict) or type(event.get("tick")) is not int or event["tick"] < previous_event:
            return [*errors, "Canopy event order malformed"]
        previous_event = event["tick"]
        if cursor < len(order) and event.get("kind") == order[cursor]:
            cursor += 1
    if cursor != len(order):
        errors.append("Missing accepted hook flight/pull/contact/kick chain")
    requests = data.get("input_requests", [])
    if (not isinstance(requests, list) or len(requests) != 1 or not isinstance(requests[0], dict)
            or requests[0].get("kind") != "grapple" or requests[0].get("queued") is not True
            or type(requests[0].get("tick")) is not int):
        errors.append("Canopy must retain its actual Router request")
    geometry = data.get("geometry", {})
    if not isinstance(geometry, dict):
        return [*errors, "Canopy geometry malformed"]
    branch = geometry.get("branch", [])
    body_size = data.get("body_size", [])
    frames = data.get("observations", [])
    branch_count, return_count, branch_tick, return_tick = 0, 0, None, None
    last_steps = None
    if (not isinstance(branch, list) or len(branch) != 4 or not isinstance(frames, list) or not frames
            or not isinstance(body_size, list) or len(body_size) != 2
            or any(type(v) not in (int, float) or not math.isfinite(v) for v in branch)
            or branch[2] <= 0 or branch[3] <= 0
            or any(type(v) not in (int, float) or not math.isfinite(v) or v <= 0 for v in body_size)):
        return [*errors, "Canopy geometry/frames malformed"]
    half_width, half_height = body_size[0] / 2, body_size[1] / 2
    for tick, frame in enumerate(frames, 1):
        if (not isinstance(frame, dict) or type(frame.get("tick")) is not int or frame.get("tick") != tick
                or type(frame.get("motion_steps")) is not int or type(frame.get("motor_steps_this_tick")) is not int
                or frame.get("motor_steps_this_tick") != 1 or not isinstance(frame.get("supports"), list)
                or (last_steps is not None and frame.get("motion_steps") != last_steps + 1)):
            return [*errors, "Canopy trace lacks contiguous sole-Motor steps"]
        last_steps = frame.get("motion_steps")
        position = frame.get("position", [])
        if not isinstance(position, list) or len(position) != 2 or any(type(v) not in (int, float) or not math.isfinite(v) for v in position):
            return [*errors, "Canopy position is invalid"]
        x, y = position
        grounded = frame.get("grounded") is True
        supports = frame.get("supports", [])
        full_branch = grounded and "CanopyBranch" in supports and branch[0] <= x - half_width and x + half_width <= branch[0] + branch[2] and abs(y + half_height - branch[1]) < 1
        branch_count = branch_count + 1 if full_branch else 0
        if branch_count >= 12 and branch_tick is None:
            branch_tick = tick
        safe_return = branch_tick is not None and tick > branch_tick and grounded and "RootLanding" in supports and 70 <= x <= 115 and abs(y + half_height - 600) < 1
        return_count = return_count + 1 if safe_return else 0
        if return_count >= 12 and return_tick is None:
            return_tick = tick
    errors.extend(_validate_forest_causality(data, raw, final, frames, events, requests))
    if branch_tick is None or return_count < 12:
        errors.append("No observed whole-body branch landing and continuous safe return")
    # Callback presence alone is insufficient: bind actual contact to its frame,
    # body position and a sustained support window. Removing either landing fails.
    for support, end_tick in (("CanopyBranch", branch_tick), ("RootLanding", return_tick)):
        contacts = [e for e in events if isinstance(e, dict) and e.get("kind") == "landed"
                    and isinstance(e.get("supports"), list) and support in e["supports"]
                    and type(e.get("tick")) is int and 1 <= e["tick"] <= len(frames)
                    and end_tick is not None and e["tick"] <= end_tick
                    and frames[e["tick"] - 1].get("grounded") is True
                    and support in frames[e["tick"] - 1].get("supports", [])
                    and e.get("position") == frames[e["tick"] - 1].get("position")
                    and (support != "RootLanding" or branch_tick is not None and e["tick"] > branch_tick)]
        if not contacts:
            errors.append("Missing actual frame-bound landing on " + support)
    if (final.get("granted_actions") != raw.get("granted_actions")
            or final.get("equipped_weapon") != raw.get("equipped_weapon")
            or raw.get("config_hashes") != final.get("config_hashes") or raw.get("tuning") != final.get("tuning")
            or raw.get("shot_energy", {}).get("current") != final.get("shot_energy", {}).get("current")):
        errors.append("Canopy changed configuration/resources during route")
    return errors

def arr(schema: Any, minimum: int = 0) -> tuple:
    return ("list", schema, minimum)
def enum(*values: str) -> tuple:
    return ("enum", values)
STRINGS = arr(TEXT)
NONEMPTY_STRINGS = arr(TEXT, 1)
RANGE = {"min": NUMBER, "max": NUMBER}
STATE = {
    "position": {"x": RANGE, "y": RANGE}, "velocity": {"x": RANGE, "y": RANGE},
    "grounded": BOOL, "resources_ref": TEXT, "cooldowns_ref": TEXT,
}
BUILD = {
    "id": TEXT, "equipped_weapon": TEXT, "weapon_level": NUMBER,
    "available_weapons": NONEMPTY_STRINGS, "abilities": NONEMPTY_STRINGS,
    "equipment_capacity_ref": TEXT, "modifiers": STRINGS, "resources_ref": TEXT,
    "cooldowns_ref": TEXT, "air_limits_ref": TEXT, "recovery_ref": TEXT,
}
ACTION = {
    "id": TEXT, "capability": TEXT, "implementation_ref": TEXT,
    "requires_grounded": BOOL, "resource_effect_ref": TEXT,
    "input_intent": TEXT, "dual_use": STRINGS,
}
PHRASE = {
    "id": TEXT, "actions": arr(TEXT, 2), "transitions": arr({
        "from": TEXT, "to": TEXT, "condition": TEXT, "resource_rule_ref": TEXT,
    }, 1),
}
CHALLENGE = {
    "id": TEXT, "tier": enum("ordinary", "advanced", "master"),
    "route_role": enum("main", "reward", "hidden"), "tags": NONEMPTY_STRINGS,
    "intent": TEXT, "phrases": arr(TEXT, 1), "alternative_phrases": arr(arr(TEXT, 1)),
    "required_capabilities": NONEMPTY_STRINGS, "supported_builds": NONEMPTY_STRINGS,
    "entry": STATE, "exit": STATE, "resource_constraints": NONEMPTY_STRINGS,
    "cooldown_constraints": NONEMPTY_STRINGS, "phase_contract": TEXT,
    "observation": TEXT, "recovery": TEXT, "failure_modes": NONEMPTY_STRINGS,
    "camera_preview": TEXT, "tolerance": {"status": enum("uncalibrated", "measured"), "evidence_ref": TEXT},
    "device_constraints": {"keyboard_mouse": TEXT, "gamepad": TEXT, "touch": TEXT},
    "reward": TEXT, "foundry": {"kind": enum("template", "itinerary"), "template_id": TEXT, "phrase_count": NUMBER}, "module_ids": NONEMPTY_STRINGS,
    "admission": enum("technical_slice", "design_only"), "missing_acceptance": NONEMPTY_STRINGS,
}
SCENE = {
    "id": TEXT, "theme": TEXT, "focal_point": TEXT, "silhouette": TEXT,
    "depth_layers": {"foreground": TEXT, "midground": TEXT, "background": TEXT},
    "landmarks": NONEMPTY_STRINGS, "density_contrast": TEXT, "guidance": TEXT,
    "seams": NONEMPTY_STRINGS, "anchors": NONEMPTY_STRINGS,
    "occlusion_check": TEXT, "interactive_priority": TEXT, "atmosphere": TEXT,
    "camera": {"resolution_ref": TEXT, "character_scale_ref": TEXT, "preview": TEXT},
    "assets": arr({"id": TEXT, "source": TEXT, "license": TEXT, "version": TEXT,
                   "reuse": TEXT, "status": enum("existing", "planned")}, 1),
}
SCHEMA = {
    "schema_version": 1, "artifact_kind": enum("level_design_intent"),
    "id": TEXT, "status": enum("design_only", "technical_slice"), "source_refs": NONEMPTY_STRINGS,
    "biome": {"id": TEXT, "identity": TEXT, "spatial_grammar": TEXT,
              "behavior_goal": TEXT, "visual_motifs": NONEMPTY_STRINGS,
              "mechanisms": NONEMPTY_STRINGS, "enemy_ecology": TEXT,
              "exploration_reward": TEXT, "narrative_landmark": TEXT,
              "experience_categories": arr(TEXT, 8),
              "challenge_axes": {key: TEXT for key in CHALLENGE_AXES},
              "learning_order": arr({"mechanism": TEXT, "show": TEXT, "practice": TEXT, "combine": TEXT}, 1)},
    "capabilities": {
        "catalog": arr({"id": TEXT, "implemented": BOOL, "source": TEXT}, 1),
        "guaranteed": NONEMPTY_STRINGS, "optional": STRINGS, "future": STRINGS,
        "supported_builds": arr(BUILD, 1),
    },
    "topology": {
        "entry": TEXT, "goal": TEXT,
        "nodes": arr({"id": TEXT, "identity": TEXT, "position": {"x": NUMBER, "y": NUMBER},
                      "grants": STRINGS, "reward": TEXT, "return_policy": enum("return", "one_way_exit"),
                      "rooms": NONEMPTY_STRINGS}, 2),
        "edges": arr({"id": TEXT, "from": TEXT, "to": TEXT, "requires": STRINGS,
                      "weapon_ids": STRINGS, "role": enum("main", "reward", "hidden", "shortcut"),
                      "challenge_ids": STRINGS, "choice_value": TEXT}, 1),
    },
    "atomic_actions": arr(ACTION, 1), "phrases": arr(PHRASE, 1), "challenges": arr(CHALLENGE, 1),
    "rooms": arr({"id": TEXT, "identity": TEXT, "tags": NONEMPTY_STRINGS,
                  "challenge_ids": STRINGS, "encounter_ids": NONEMPTY_STRINGS, "scene_id": TEXT}, 1),
    "encounters": arr({"id": TEXT, "purpose": TEXT, "terrain_relation": TEXT,
                       "enemy_relation": TEXT, "hazard_phase": TEXT, "counterplay": NONEMPTY_STRINGS,
                       "safe_landing": TEXT, "pressure": enum("quiet", "learning", "high"),
                       "recovery": TEXT, "reward": TEXT}, 1),
    "pacing": {"strategies": arr({"id": TEXT, "node_ids": arr(TEXT, 2),
                                  "pressure_budget": TEXT, "interaction_budget": TEXT,
                                  "return_cost": TEXT}, 1), "calibration": TEXT},
    "scene_compositions": arr(SCENE, 1),
    "evidence_boundary": {key: enum("unverified") for key in ("generated", "runtime", "physics", "subjective")},
}


def validate_design(data: Any) -> list[dict[str, str]]:
    """Return deterministic falsifiable errors; an empty list means design-valid only."""
    errors: list[dict[str, str]] = []
    def fail(code: str, path: str, message: str) -> None:
        errors.append({"code": code, "path": path, "message": message})
    def finite(value: Any, path: str) -> None:
        if isinstance(value, float) and not math.isfinite(value):
            fail("non_finite", path, "Numbers must be finite")
        elif isinstance(value, dict):
            for k, v in value.items(): finite(v, f"{path}.{k}")
        elif isinstance(value, list):
            for i, v in enumerate(value): finite(v, f"{path}[{i}]")
    def shape(value: Any, schema: Any, path: str) -> None:
        if isinstance(schema, dict):
            if not isinstance(value, dict):
                fail("schema_type", path, "Expected object"); return
            for key in schema:
                if key not in value: fail("required_field", f"{path}.{key}", "Missing required field")
                else: shape(value[key], schema[key], f"{path}.{key}")
            for key in value.keys() - schema.keys():
                fail("unknown_field", f"{path}.{key}", "Unknown field; migrate the versioned contract explicitly")
        elif isinstance(schema, tuple):
            if schema[0] == "enum":
                if value not in schema[1]: fail("enum_value", path, f"Expected one of {schema[1]}")
            elif not isinstance(value, list): fail("schema_type", path, "Expected array")
            else:
                if len(value) < schema[2]: fail("empty_contract", path, f"Expected at least {schema[2]} entries")
                for i, item in enumerate(value): shape(item, schema[1], f"{path}[{i}]")
        elif schema == TEXT:
            if not isinstance(value, str) or not value.strip(): fail("schema_type", path, "Expected nonempty string")
        elif schema == NUMBER:
            if isinstance(value, bool) or not isinstance(value, (int, float)): fail("schema_type", path, "Expected number")
        elif schema == BOOL:
            if not isinstance(value, bool): fail("schema_type", path, "Expected boolean")
        elif type(value) is not type(schema) or value != schema:
            fail("schema_version", path, f"Expected {schema!r}")
    finite(data, "$")
    shape(data, SCHEMA, "$")
    if errors: return errors

    def index(items: list[dict], path: str) -> dict:
        result = {}
        for i, item in enumerate(items):
            if item["id"] in result: fail("duplicate_id", f"{path}[{i}].id", item["id"])
            result[item["id"]] = item
        return result
    def refs(values: list[str], known: dict | set, path: str) -> None:
        for i, value in enumerate(values):
            if value not in known: fail("unknown_reference", f"{path}[{i}]", value)
        if len(set(values)) != len(values): fail("duplicate_reference", path, "Repeated reference")
    caps = data["capabilities"]
    catalog = index(caps["catalog"], "$.capabilities.catalog")
    builds = index(caps["supported_builds"], "$.capabilities.supported_builds")
    actions = index(data["atomic_actions"], "$.atomic_actions")
    phrases = index(data["phrases"], "$.phrases")
    challenges = index(data["challenges"], "$.challenges")
    rooms = index(data["rooms"], "$.rooms")
    encounters = index(data["encounters"], "$.encounters")
    scenes = index(data["scene_compositions"], "$.scene_compositions")
    topology = data["topology"]
    nodes = index(topology["nodes"], "$.topology.nodes")
    index(topology["edges"], "$.topology.edges")
    partitions = []
    for group in ("guaranteed", "optional", "future"):
        refs(caps[group], catalog, f"$.capabilities.{group}")
        partitions.extend(caps[group])
        for cid in caps[group]:
            if cid in catalog and catalog[cid]["implemented"] != (group != "future"):
                fail("capability_status", f"$.capabilities.{group}", f"{cid}: implemented status conflicts with partition")
    if len(set(partitions)) != len(partitions) or set(partitions) != set(catalog):
        fail("capability_partition", "$.capabilities", "Every capability must have exactly one partition")
    cats = set(EXPERIENCE_CATEGORIES)
    if set(data["biome"]["experience_categories"]) != cats or len(data["biome"]["experience_categories"]) != 8:
        fail("experience_categories", "$.biome.experience_categories", "Declare all eight experience categories exactly once")
    all_weapons = {w for build in builds.values() for w in build["available_weapons"]}
    for bid, build in builds.items():
        path = f"$.capabilities.supported_builds.{bid}"
        refs(build["abilities"], catalog, path + ".abilities")
        if build["equipped_weapon"] not in build["available_weapons"]:
            fail("single_weapon", path, "The single equipped weapon must be in available_weapons")
        if build["weapon_level"] not in (1, 2, 3): fail("weapon_level", path, "Weapon level must be 1, 2 or 3")
        if not set(caps["guaranteed"]).issubset(build["abilities"]) or set(build["abilities"]) & set(caps["future"]):
            fail("baseline_capabilities", path, "Baseline must include guarantees and exclude future abilities")
    for aid, action in actions.items(): refs([action["capability"]], catalog, f"$.atomic_actions.{aid}.capability")
    for pid, phrase in phrases.items():
        path = f"$.phrases.{pid}"
        # Repeated actions are intentional; only reference existence is checked.
        for aid in phrase["actions"]: refs([aid], actions, path + ".actions")
        pairs = [(t["from"], t["to"]) for t in phrase["transitions"]]
        if pairs != list(zip(phrase["actions"], phrase["actions"][1:])):
            fail("action_transition", path, "Each consecutive action needs its ordered state/resource transition")
    def range_check(value: Any, path: str) -> None:
        if isinstance(value, dict):
            if set(value) == {"min", "max"} and value["min"] > value["max"]:
                fail("state_range", path, "Minimum exceeds maximum")
            for key, item in value.items(): range_check(item, path + "." + key)
        elif isinstance(value, list):
            for i, item in enumerate(value): range_check(item, f"{path}[{i}]")
    range_check(data, "$")
    for cid, challenge in challenges.items():
        path = f"$.challenges.{cid}"
        refs(challenge["tags"], cats, path + ".tags")
        binding = challenge["foundry"]
        count = binding["phrase_count"]
        # Current adapter contract: foundry_validate.gd connection proofs compose
        # three different templates. This is not a universal design length limit.
        expected_count = 1 if binding["kind"] == "template" else 3
        if type(count) is not int or count != expected_count or (binding["kind"] == "itinerary" and binding["template_id"] != "mixed"):
            fail("foundry_card", path + ".foundry", "Current Foundry adapter requires template/1 or itinerary/mixed/3; changing it requires explicit migration")
        refs(challenge["required_capabilities"], catalog, path + ".required_capabilities")
        refs(challenge["supported_builds"], builds, path + ".supported_builds")
        chains = [challenge["phrases"]] + challenge["alternative_phrases"]
        for chain in chains:
            for pid in chain: refs([pid], phrases, path + ".phrases")
            needed = {actions[aid]["capability"] for pid in chain if pid in phrases
                      for aid in phrases[pid]["actions"] if aid in actions}
            if not needed.issubset(challenge["required_capabilities"]):
                fail("action_capabilities", path, "Sequence uses capabilities absent from its requirements")
        if challenge["route_role"] == "main":
            if challenge["tier"] == "master": fail("main_master", path, "Master challenges cannot be mandatory")
            if set(challenge["required_capabilities"]) & set(caps["future"]):
                fail("future_main", path, "Future capabilities cannot be required by the main route")
        if challenge["tolerance"]["status"] == "measured":
            fail("design_evidence_claim", path + ".tolerance", "Attach measurements to separate physics evidence, not design intent")
    for rid, room in rooms.items():
        refs(room["tags"], cats, f"$.rooms.{rid}.tags")
        refs(room["challenge_ids"], challenges, f"$.rooms.{rid}.challenge_ids")
        refs(room["encounter_ids"], encounters, f"$.rooms.{rid}.encounter_ids")
        refs([room["scene_id"]], scenes, f"$.rooms.{rid}.scene_id")
    refs([topology["entry"], topology["goal"]], nodes, "$.topology.endpoints")
    for nid, node in nodes.items():
        refs(node["grants"], catalog, f"$.topology.nodes.{nid}.grants")
        refs(node["rooms"], rooms, f"$.topology.nodes.{nid}.rooms")
        if node["return_policy"] == "one_way_exit" and nid != topology["goal"]:
            fail("invalid_exit", f"$.topology.nodes.{nid}", "One-way exit must be the declared goal")
        if set(node["grants"]) & set(caps["future"]):
            fail("future_grant", f"$.topology.nodes.{nid}", "A design graph cannot claim an unimplemented grant")
    for edge in topology["edges"]:
        path = f"$.topology.edges.{edge['id']}"
        refs([edge["from"], edge["to"]], nodes, path)
        refs(edge["requires"], catalog, path + ".requires")
        refs(edge["weapon_ids"], all_weapons, path + ".weapon_ids")
        refs(edge["challenge_ids"], challenges, path + ".challenge_ids")
        for cid in edge["challenge_ids"]:
            if cid in challenges and edge["role"] == "main" and challenges[cid]["tier"] == "master":
                fail("main_master", path, "Main edge attaches a master challenge")
        if edge["role"] == "main" and set(edge["requires"]) & set(caps["future"]):
            fail("future_main", path, "Main edge requires a future capability")
    for strategy in data["pacing"]["strategies"]:
        refs(list(dict.fromkeys(strategy["node_ids"])), nodes, f"$.pacing.{strategy['id']}")
        for a, b in zip(strategy["node_ids"], strategy["node_ids"][1:]):
            if not any(e["from"] == a and e["to"] == b for e in topology["edges"]):
                fail("strategy_path", f"$.pacing.{strategy['id']}", f"No directed edge {a} -> {b}")
    if errors: return errors
    # State-space exploration keeps each equipped weapon separate. Abilities are
    # monotonic grants; equipment swapping and consumable resources need Motor evidence.
    adjacency: dict[str, list[dict]] = {nid: [] for nid in nodes}
    for edge in topology["edges"]: adjacency[edge["from"]].append(edge)
    geometric_reached = set()
    geometric_queue = deque([topology["entry"]])
    while geometric_queue:
        node_id = geometric_queue.popleft()
        if node_id in geometric_reached: continue
        geometric_reached.add(node_id)
        geometric_queue.extend(edge["to"] for edge in adjacency[node_id])
    for node_id in sorted(nodes.keys() - geometric_reached):
        fail("disconnected_node", f"$.topology.nodes.{node_id}", "No directed graph path from entry, even ignoring ability locks")
    def explore(start: str, abilities: frozenset, bid: str, *, exclude_master: bool = False) -> set[tuple[str, frozenset]]:
        weapon = builds[bid]["equipped_weapon"]
        queue = deque([(start, abilities | frozenset(nodes[start]["grants"]))])
        seen: set[tuple[str, frozenset]] = set()
        while queue:
            state = queue.popleft()
            if state in seen: continue
            seen.add(state)
            if len(seen) > MAX_CAPABILITY_STATES:
                fail("state_budget", "$.topology", "Capability graph exceeds bounded analysis; simplify or split it")
                return seen
            nid, have = state
            for edge in adjacency[nid]:
                if exclude_master and any(challenges[c]["tier"] == "master" for c in edge["challenge_ids"]): continue
                if not set(edge["requires"]).issubset(have): continue
                if edge["weapon_ids"] and weapon not in edge["weapon_ids"]: continue
                if any(bid not in challenges[c]["supported_builds"] or
                       not set(challenges[c]["required_capabilities"]).issubset(have)
                       for c in edge["challenge_ids"]): continue
                target = edge["to"]
                queue.append((target, have | frozenset(nodes[target]["grants"])))
        return seen
    for bid, build in builds.items():
        reached = explore(topology["entry"], frozenset(build["abilities"]), bid)
        reached_nodes = {n for n, _ in reached}
        if topology["goal"] not in reached_nodes:
            fail("goal_unreachable", f"$.capabilities.supported_builds.{bid}", "No declared path to goal for this single-weapon build")
        else:
            # Role labels cannot make an unavoidable master challenge optional.
            # Re-run from the original baseline, so abilities obtained behind a
            # master challenge cannot leak into the guaranteed non-master path.
            ordinary_reached = explore(topology["entry"], frozenset(build["abilities"]), bid, exclude_master=True)
            if topology["goal"] not in {n for n, _ in ordinary_reached}:
                fail("mandatory_master", f"$.capabilities.supported_builds.{bid}", "Every declared goal path depends on a master challenge, regardless of hidden/reward role labels")
        for nid, node in nodes.items():
            if node["grants"] and nid not in reached_nodes:
                fail("grant_unreachable", f"$.topology.nodes.{nid}", f"Grant unreachable for {bid}; check circular locks")
        for nid, have in sorted(reached, key=lambda s: (s[0], sorted(s[1]))):
            if nodes[nid]["return_policy"] == "one_way_exit":
                continue
            back = explore(nid, have, bid)
            if topology["entry"] not in {n for n, _ in back}:
                fail("return_unreachable", f"$.topology.nodes.{nid}", f"No declared return path for {bid} with {sorted(have)}")
    return errors
