"""Four-layer, offline design sidecars for existing Godot consumers.

This validates declarations and evidence bindings. It never grants runtime pool
admission, proves novelty, simulates a player, or signs human approval.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re


def obj(properties, required=None):
    return {"type": "object", "properties": properties,
            "required": list(properties) if required is None else required,
            "additionalProperties": False}


def arr(items, minimum=0):
    return {"type": "array", "items": items, "minItems": minimum}


TEXT = {"type": "string", "minLength": 1}
STRING = {"type": "string"}
NUMBER = {"type": "number"}
POSITIVE = {"type": "integer", "minimum": 1}
HASH = {"type": "string", "pattern": "^[0-9a-f]{64}$"}
COMMIT = {"type": "string", "pattern": "^[0-9a-f]{40}$"}
PAIR = {"type": "array", "items": NUMBER, "minItems": 2, "maxItems": 2}
RANGE = PAIR
STRINGS = arr(TEXT)
LAYER = {"enum": ["cell", "module", "macro_module", "map"]}
ARTIFACT = obj({"path": TEXT, "sha256": HASH})
REQUIREMENTS = obj({"status": {"enum": ["unspecified", "partial", "defined"]},
                    "all_of": STRINGS, "any_of_groups": arr(arr(TEXT, 1)),
                    "resources": {"type": "object", "additionalProperties": RANGE},
                    "note": STRING})
PORT = obj({"id": TEXT, "direction": {"enum": ["entry", "exit", "both"]},
            "position": PAIR, "velocity_x": RANGE, "velocity_y": RANGE,
            "states": arr(TEXT, 1), "resources": {"type": "object", "additionalProperties": RANGE},
            "capabilities": STRINGS, "phase": STRING, "coordinate_frame": TEXT})
PART = obj({"id": TEXT, "content_id": TEXT, "layer": LAYER, "version": POSITIVE,
            "offset": PAIR, "source": ARTIFACT},
           ["id", "content_id", "layer", "version", "offset"])
ELEMENT = obj({"id": TEXT, "kind": TEXT, "parameters": {"type": "object"}})
ACTION = obj({"id": TEXT, "verb": TEXT, "target": STRING, "depends_on": STRINGS,
              "decision": STRING, "success": TEXT, "failure": TEXT})
EDGE = obj({"from": TEXT, "to": TEXT, "role": {"enum": ["main", "branch", "reward", "return", "loop"]},
            "requirements": REQUIREMENTS, "grants": STRINGS, "risk_reward": STRING})
TOPOLOGY = obj({"nodes": STRINGS, "edges": arr(EDGE), "entry": STRINGS, "goals": STRINGS,
                "return_policy": STRING, "available_capabilities": STRINGS})
EVIDENCE = obj({
    "technical": obj({"status": {"enum": ["unverified", "passed", "failed"]},
                      "method": {"enum": ["unverified", "structural", "real_motor"]},
                      "scope": STRING, "artifacts": arr(ARTIFACT)}),
    "ai": obj({"status": {"enum": ["unreviewed", "reviewed"]}, "reviewer": STRING,
               "findings": STRINGS, "artifacts": arr(ARTIFACT)}),
    "human": obj({"status": {"enum": ["unverified", "accepted", "rejected"]},
                  "scope": STRING, "artifacts": arr(ARTIFACT)})})
CONTENT = obj({
    "id": TEXT, "version": POSITIVE, "layer": LAYER, "region": TEXT,
    "identity": obj({"name": TEXT, "player_experience": TEXT, "gameplay_genes": STRINGS,
                     "composition_status": {"enum": ["decomposed", "legacy_atomic"]},
                     "elements": arr(ELEMENT)}),
    "parts": arr(PART), "ports": arr(PORT), "requirements": REQUIREMENTS,
    "design": obj({"goals": STRINGS, "actions": arr(ACTION),
                   "interactions": arr(obj({"from": TEXT, "to": TEXT, "relation": TEXT})),
                   "difficulty": obj({"scale": TEXT, "score": {"type": ["integer", "null"], "minimum": 1, "maximum": 10},
                                      "basis": STRING}),
                   "tolerance": STRING, "rhythm": STRINGS, "recovery": STRING,
                   "alternative_solutions": STRINGS}),
    "topology": TOPOLOGY,
    "provenance": obj({"repository": TEXT, "commit": COMMIT, "artifacts": arr(ARTIFACT, 1), "license_note": STRING}),
    "runtime": obj({"consumer": TEXT, "format": TEXT, "binding": TEXT,
                    "integration": {"enum": ["formal_source", "development_source", "unverified"]},
                    "note": STRING}),
    "evidence": EVIDENCE,
    "quality": obj({"admission": {"enum": ["candidate", "review", "rework", "discard"]},
                    "reason": TEXT, "quality_record": {"oneOf": [ARTIFACT, {"type": "null"}]}}),
    "lineage": obj({"parents": STRINGS, "variant_family": STRING, "changes": STRINGS,
                    "failure_refs": arr(ARTIFACT)})})
ENDPOINT = obj({"content": TEXT, "port": TEXT, "offset": PAIR})
SCHEMA = {"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "urn:disordered-clock:level-content:1",
          **obj({"schema_version": {"const": 1}, "artifact_kind": {"const": "level_content_bundle"},
                 "capability_catalog": STRINGS, "contents": arr(CONTENT, 1),
                 "connections": arr(obj({"from": ENDPOINT, "to": ENDPOINT}))})}


def _shape(value, schema, path, errors):
    """Small stdlib interpreter for exactly the published schema vocabulary."""
    if "oneOf" in schema:
        matches = 0
        for option in schema["oneOf"]:
            local = []
            _shape(value, option, path, local)
            matches += not local
        if matches != 1:
            errors.append(f"{path}: must match exactly one allowed shape")
        return
    kinds = schema.get("type")
    if kinds:
        kinds = kinds if isinstance(kinds, list) else [kinds]
        predicates = {"object": lambda x: isinstance(x, dict), "array": lambda x: isinstance(x, list),
                      "string": lambda x: isinstance(x, str), "number": lambda x: type(x) in (int, float) and math.isfinite(x),
                      "integer": lambda x: type(x) is int, "null": lambda x: x is None}
        if not any(predicates[k](value) for k in kinds):
            errors.append(f"{path}: expected {'/'.join(kinds)}")
            return
    if "const" in schema and (value != schema["const"] or type(value) is not type(schema["const"])):
        errors.append(f"{path}: unsupported constant/version")
    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{path}: unsupported value {value!r}")
    if isinstance(value, str):
        if len(value.strip()) < schema.get("minLength", 0):
            errors.append(f"{path}: nonempty text required")
        if "pattern" in schema and not re.fullmatch(schema["pattern"], value):
            errors.append(f"{path}: invalid digest/commit")
    if type(value) in (int, float):
        if not math.isfinite(value) or value < schema.get("minimum", -math.inf) or value > schema.get("maximum", math.inf):
            errors.append(f"{path}: nonfinite/out-of-range number")
    if isinstance(value, list):
        if not schema.get("minItems", 0) <= len(value) <= schema.get("maxItems", math.inf):
            errors.append(f"{path}: invalid list size")
        for i, item in enumerate(value):
            _shape(item, schema.get("items", {}), f"{path}[{i}]", errors)
    if isinstance(value, dict):
        properties = schema.get("properties", {})
        for key in schema.get("required", []):
            if key not in value:
                errors.append(f"{path}.{key}: missing")
        for key, item in value.items():
            if key in properties:
                _shape(item, properties[key], f"{path}.{key}", errors)
            elif schema.get("additionalProperties") is False:
                errors.append(f"{path}.{key}: unknown field")
            elif isinstance(schema.get("additionalProperties"), dict):
                _shape(item, schema["additionalProperties"], f"{path}.{key}", errors)


def _unique(values, path, errors):
    if len(values) != len(set(values)):
        errors.append(f"{path}: duplicate identifiers")


def _range(value, path, errors):
    if value[0] > value[1]:
        errors.append(f"{path}: reversed interval")


def _artifact(artifact, root, path, errors):
    relative = Path(artifact["path"].removeprefix("res://"))
    if relative.is_absolute() or ".." in relative.parts:
        errors.append(f"{path}: artifact must stay inside repository")
        return None
    if root is None:
        return None
    base = Path(root).resolve()
    target = (base / relative).resolve()
    if not target.is_relative_to(base) or not target.is_file():
        errors.append(f"{path}: artifact unavailable")
        return None
    if hashlib.sha256(target.read_bytes()).hexdigest() != artifact["sha256"]:
        errors.append(f"{path}: artifact hash mismatch")
        return None
    return target


def _satisfied(requirements, available):
    return (set(requirements["all_of"]) <= available
            and all(set(group) & available for group in requirements["any_of_groups"]))


def _requirements(req, catalog, path, errors):
    _unique(req["all_of"], path + ".all_of", errors)
    for i, group in enumerate(req["any_of_groups"]):
        _unique(group, f"{path}.any_of_groups[{i}]", errors)
    mentioned = set(req["all_of"]) | {c for group in req["any_of_groups"] for c in group}
    if not mentioned <= catalog:
        errors.append(f"{path}: unknown capability {sorted(mentioned - catalog)}")
    if req["status"] == "unspecified" and (mentioned or req["resources"]):
        errors.append(f"{path}: unspecified requirements cannot contain known constraints; use partial")
    for key, interval in req["resources"].items():
        _range(interval, path + ".resources." + key, errors)
        if interval[0] < 0:
            errors.append(f"{path}: negative resource requirement")


PILOT_SCOPE = "isolated_existing_Module_Router_Controller_Motor_reachability_only"


def _physics_receipt(target, content, evidence, root):
    """Only a bound native observation is eligible; a green label is not one.

    This is an evidence-format guard, not an independent physics verifier. The
    original Godot runner/Harness must still validate its own receipt semantics.
    """
    try:
        data = json.loads(target.read_text())
    except (ValueError, OSError, UnicodeError):
        return False
    if not isinstance(data, dict) or root is None:
        return False
    # Explicitly registered adapter for the real pilot native format. Other
    # producers remain unverified until their own narrow adapter is reviewed.
    if (data.get("schema_version") != 1 or type(data.get("schema_version")) is not int
            or data.get("id") != content["id"] or data.get("candidate") != content["id"]
            or data.get("runtime_consumer") != content["runtime"]["consumer"]
            or data.get("scope") != PILOT_SCOPE or evidence["scope"] != PILOT_SCOPE
            or data.get("strategy") not in ("main", "reward", "direct", "near_reward", "no_jump")
            or data.get("condition") != data.get("strategy")
            or type(data.get("variant")) is not int or data["variant"] < 0
            or type(data.get("exit_code")) is not int or data["exit_code"] != 0
            or data.get("failures") != [] or data.get("danger_contacts") != []
            or any(data.get(k) is not True for k in
                   ("passed", "ok", "real_motor", "driver_reached", "actual_goal", "entry_contract", "audio_released"))
            or any(data.get(k) is not False for k in
                   ("midroute_injection", "resource_override", "manual_motor_step", "production_pool"))
            or data.get("manual_controller_tick") is not True
            or not re.fullmatch(r"[0-9a-f]{64}", str(data.get("source_fingerprint", "")))):
        return False
    if data["strategy"] not in ("direct", "near_reward") and data.get("exit_contract") is not True:
        return False
    if data["strategy"] == "reward" and (data.get("visited_reward_location") is not True
                                           or data.get("returned_after_reward") is not True):
        return False
    frames = data.get("frames")
    if not isinstance(frames, list) or not frames:
        return False
    for i, frame in enumerate(frames, 1):
        if (not isinstance(frame, dict) or type(frame.get("frame")) is not int or frame["frame"] != i
                or type(frame.get("motion_steps")) is not int or frame["motion_steps"] != i
                or type(frame.get("grounded")) is not bool
                or not isinstance(frame.get("requested_actions"), list)
                or not isinstance(frame.get("accepted_actions"), list)
                or type(frame.get("shots")) is not int or frame["shots"] < 0
                or type(frame.get("stamina")) not in (int, float)
                or not math.isfinite(frame["stamina"]) or frame["stamina"] < 0):
            return False
        for key in ("position", "velocity"):
            pair = frame.get(key)
            if (not isinstance(pair, list) or len(pair) != 2
                    or any(type(n) not in (int, float) or not math.isfinite(n) for n in pair)):
                return False
    if not frames[-1]["grounded"]:
        return False
    # Main/return termination uses the actual final main-route anchor. A direct
    # shortcut has a different reward target, already checked by actual_goal;
    # no reward-index defaults are guessed here.
    if data["strategy"] not in ("direct", "near_reward"):
        try:
            index = data["routes"]["main"][-1]
            if type(index) is not int or index < 0:
                return False
            terminal = data["anchors"][index]
            if (not isinstance(terminal, list) or len(terminal) != 2
                    or any(type(n) not in (int, float) or not math.isfinite(n) for n in terminal)):
                return False
            if math.dist(frames[-1]["position"], terminal) >= 14.0:
                return False
        except (KeyError, IndexError, TypeError, ValueError):
            return False
    local = []
    # Old pilot receipts predate catalog_path and have exactly the default
    # catalogue. Custom generated catalogues must record their actual path.
    catalog_path = data.get("catalog_path", "config/level_pilot_candidates.json")
    if not isinstance(catalog_path, str):
        return False
    catalog_artifact = {"path": catalog_path, "sha256": data.get("catalog_sha256")}
    native_artifact = {"path": "tools/level_pilot_validate.gd", "sha256": data.get("source_hash")}
    catalog_file = _artifact(catalog_artifact, root, "pilot.catalog", local)
    _artifact(native_artifact, root, "pilot.producer", local)
    tuning = data.get("tuning")
    if not isinstance(tuning, dict):
        return False
    _artifact({"path": "config/player_tuning.json", "sha256": tuning.get("source_sha256")}, root, "pilot.tuning", local)
    if local or catalog_file is None or native_artifact not in content["provenance"]["artifacts"]:
        return False
    try:
        catalog = json.loads(catalog_file.read_text())
        selected = [c for c in catalog["candidates"] if c["id"] == content["id"]]
        if len(selected) != 1 or data["strategy"] not in selected[0]["strategies"]:
            return False
        identity = {"catalog_item": selected[0], "candidate": data["candidate"], "strategy": data["strategy"],
                    "variant": data["variant"], "tuning": tuning}
        # Godot JSON.stringify uses sorted keys and compact output here; this
        # exact representation is checked against real r1 native files.
        encoded = json.dumps(identity, sort_keys=True, ensure_ascii=False, separators=(",", ":"), allow_nan=False).encode()
        return hashlib.sha256(encoded).hexdigest() == data.get("input_fingerprint")
    except (KeyError, TypeError, ValueError, OSError):
        return False


def _current_ledger(target, evidence_targets, root):
    """Bind standalone sidecar acceptance to the original complete run ledger."""
    if root is None: return False
    try:
        from level_content_pilot import snapshot, cached_valid
        root = Path(root).resolve()
        ledger = target.with_name('receipt.json')
        if ledger not in evidence_targets: return False
        receipt = json.loads(ledger.read_text())
        source, request = receipt['runtime_source'], receipt['request']
        if (source != snapshot(root, request.get('catalog')) or receipt.get('source_fingerprint') != hashlib.sha256(
                json.dumps(source, sort_keys=True, ensure_ascii=False, separators=(',', ':')).encode()).hexdigest()
                or receipt.get('raw_path') != str(target.relative_to(root))
                or receipt.get('raw_sha256') != hashlib.sha256(target.read_bytes()).hexdigest()
                or receipt.get('technical_pass') is not True):
            return False
        identity = hashlib.sha256(json.dumps({'request': request, 'runtime_bytes': source}, sort_keys=True,
                                            ensure_ascii=False, separators=(',', ':')).encode()).hexdigest()
        return cached_valid(receipt, target, target.with_name('native.log'), identity, request, root)
    except (KeyError, ValueError, OSError, TypeError):
        return False


def validate_bundle(data, root=None):
    """Return errors. Pass repository root to verify referenced byte identities.

    Passing without root validates draft declarations only: it cannot accept a
    technical passed claim or a human acceptance because artifacts were not read.
    """
    errors = []
    _shape(data, SCHEMA, "$", errors)
    if errors:
        return errors
    catalog = set(data["capability_catalog"])
    _unique(data["capability_catalog"], "capability_catalog", errors)
    records = {c["id"]: c for c in data["contents"]}
    _unique([c["id"] for c in data["contents"]], "contents", errors)
    allowed_parts = {"cell": set(), "module": {"cell"}, "macro_module": {"cell", "module"},
                     "map": {"cell", "module", "macro_module"}}
    for content in data["contents"]:
        cid = content["id"]
        parts, ports, design = content["parts"], content["ports"], content["design"]
        _unique([p["id"] for p in parts], cid + ".parts", errors)
        _unique([p["id"] for p in ports], cid + ".ports", errors)
        elements = content["identity"]["elements"]
        _unique([e["id"] for e in elements], cid + ".elements", errors)
        if content["identity"]["composition_status"] == "decomposed" and content["layer"] != "cell" and not parts:
            errors.append(f"{cid}: decomposed parent requires actual parts")
        for part in parts:
            if part["layer"] not in allowed_parts[content["layer"]]:
                errors.append(f"{cid}: invalid layer composition {part['layer']}")
            child = records.get(part["content_id"])
            if child:
                if child["version"] != part["version"] or child["layer"] != part["layer"]:
                    errors.append(f"{cid}: part version/layer mismatch")
            elif "source" not in part:
                errors.append(f"{cid}: dangling part {part['content_id']}")
            if "source" in part:
                _artifact(part["source"], root, cid + ".part.source", errors)
        _requirements(content["requirements"], catalog, cid + ".requirements", errors)
        for port in ports:
            for key in ("velocity_x", "velocity_y"):
                _range(port[key], cid + ".port." + key, errors)
            for key, value in port["resources"].items():
                _range(value, cid + ".port.resources." + key, errors)
                if value[0] < 0:
                    errors.append(f"{cid}: negative port resource")
            if not set(port["capabilities"]) <= catalog:
                errors.append(f"{cid}: unknown port capability")
        actions = {a["id"]: a for a in design["actions"]}
        _unique([a["id"] for a in design["actions"]], cid + ".actions", errors)
        pending = set(actions)
        while pending:
            ready = {a for a in pending if set(actions[a]["depends_on"]) <= set(actions) - pending}
            if not ready:
                errors.append(f"{cid}: dangling/cyclic action dependency")
                break
            pending -= ready
        subjects = set(actions) | {e["id"] for e in elements} | {p["id"] for p in parts}
        for interaction in design["interactions"]:
            if interaction["from"] not in subjects or interaction["to"] not in subjects:
                errors.append(f"{cid}: dangling interaction endpoint")
        topology = content["topology"]
        nodes = set(topology["nodes"])
        _unique(topology["nodes"], cid + ".topology.nodes", errors)
        if not set(topology["entry"] + topology["goals"]) <= nodes:
            errors.append(f"{cid}: dangling topology entry/goal")
        available = set(topology["available_capabilities"])
        if not available <= catalog:
            errors.append(f"{cid}: unknown granted capability")
        for edge in topology["edges"]:
            if edge["from"] not in nodes or edge["to"] not in nodes:
                errors.append(f"{cid}: dangling topology edge")
            _requirements(edge["requirements"], catalog, cid + ".edge.requirements", errors)
            if not set(edge["grants"]) <= catalog:
                errors.append(f"{cid}: unknown edge grant")
        # Explore legal capability states; grants occur only after traversing an edge.
        states = {(n, frozenset(available)) for n in topology["entry"]}
        frontier = list(states)
        while frontier and len(states) <= 16384:
            node, abilities = frontier.pop()
            for edge in topology["edges"]:
                if edge["from"] == node and _satisfied(edge["requirements"], abilities):
                    state = edge["to"], abilities | frozenset(edge["grants"])
                    if state not in states:
                        states.add(state)
                        frontier.append(state)
        if len(states) > 16384:
            errors.append(f"{cid}: topology capability-state budget exceeded")
        if set(topology["goals"]) - {n for n, _ in states}:
            errors.append(f"{cid}: goal blocked by absent path/ungranted capability")
        for artifact in content["provenance"]["artifacts"] + content["lineage"]["failure_refs"]:
            _artifact(artifact, root, cid + ".artifact", errors)
        if content["quality"]["quality_record"]:
            _artifact(content["quality"]["quality_record"], root, cid + ".quality_record", errors)
        for kind, evidence in content["evidence"].items():
            targets = [_artifact(a, root, cid + ".evidence." + kind, errors) for a in evidence["artifacts"]]
            if kind == "technical" and evidence["status"] == "passed":
                if evidence["method"] != "real_motor" or not any(
                        t and _physics_receipt(t, content, evidence, root) and _current_ledger(t, targets, root)
                        for t in targets):
                    errors.append(f"{cid}: technical passed requires bound real Motor observations; labels are insufficient")
            if kind == "ai" and evidence["status"] == "reviewed" and (not evidence["reviewer"] or not evidence["findings"]):
                errors.append(f"{cid}: AI review requires attributed findings")
            if kind == "human" and evidence["status"] in ("accepted", "rejected") and not any(targets):
                errors.append(f"{cid}: human verdict requires actual attributed source artifact")
    for connection in data["connections"]:
        ends = []
        for side in ("from", "to"):
            endpoint = connection[side]
            record = records.get(endpoint["content"])
            port = next((p for p in record["ports"] if p["id"] == endpoint["port"]), None) if record else None
            if port is None:
                errors.append("connection: dangling content/port")
                break
            ends.append((endpoint, port))
        if len(ends) != 2:
            continue
        (a, out), (b, into) = ends
        if out["direction"] not in ("exit", "both") or into["direction"] not in ("entry", "both"):
            errors.append("connection: wrong port direction")
        if out["coordinate_frame"] != into["coordinate_frame"]:
            errors.append("connection: coordinate frame mismatch")
        if any(abs(out["position"][i] + a["offset"][i] - into["position"][i] - b["offset"][i]) > 1e-6 for i in range(2)):
            errors.append("connection: positions do not meet in instance frame")
        for key in ("velocity_x", "velocity_y"):
            if not into[key][0] <= out[key][0] <= out[key][1] <= into[key][1]:
                errors.append("connection: exit velocity is not contained in entry envelope")
        if not set(out["states"]) <= set(into["states"]):
            errors.append("connection: exit character states unsupported")
        if not set(into["capabilities"]) <= set(out["capabilities"]):
            errors.append("connection: next port requires ungranted capability")
        for resource, interval in into["resources"].items():
            previous = out["resources"].get(resource)
            if not previous or not interval[0] <= previous[0] <= previous[1] <= interval[1]:
                errors.append("connection: exit resources do not satisfy entry envelope")
        if into["phase"] and out["phase"] != into["phase"]:
            errors.append("connection: dynamic phase requires separate proof")
    return errors


def make_content(content_id, layer, region, runtime_path, source_commit, source_hash):
    """Create an honest unassessed legacy sidecar; caller supplies observations."""
    return {"id": content_id, "version": 1, "layer": layer, "region": region,
            "identity": {"name": content_id, "player_experience": "待提取并评价", "gameplay_genes": [],
                         "composition_status": "legacy_atomic", "elements": []},
            "parts": [], "ports": [],
            "requirements": {"status": "unspecified", "all_of": [], "any_of_groups": [], "resources": {}, "note": ""},
            "design": {"goals": [], "actions": [], "interactions": [],
                       "difficulty": {"scale": "gunman-rush/module-difficulty/v1", "score": None, "basis": ""},
                       "tolerance": "", "rhythm": [], "recovery": "", "alternative_solutions": []},
            "topology": {"nodes": [], "edges": [], "entry": [], "goals": [], "return_policy": "", "available_capabilities": []},
            "provenance": {"repository": "zhipijun1996/gunman-rush", "commit": source_commit,
                           "artifacts": [{"path": runtime_path, "sha256": source_hash}], "license_note": "沿用来源，未授予额外许可"},
            "runtime": {"consumer": "existing_godot_consumer", "format": "existing_definition", "binding": runtime_path,
                        "integration": "unverified", "note": "设计sidecar，不自动导入或准入正式池"},
            "evidence": {"technical": {"status": "unverified", "method": "unverified", "scope": "", "artifacts": []},
                         "ai": {"status": "unreviewed", "reviewer": "", "findings": [], "artifacts": []},
                         "human": {"status": "unverified", "scope": "", "artifacts": []}},
            "quality": {"admission": "candidate", "reason": "尚未完成分级评价及准入", "quality_record": None},
            "lineage": {"parents": [], "variant_family": "", "changes": [], "failure_refs": []}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", type=Path)
    parser.add_argument("--root", type=Path, help="Verify actual source/evidence artifacts under this repository")
    args = parser.parse_args()
    try:
        errors = validate_bundle(json.loads(args.file.read_text()), args.root)
    except (OSError, ValueError) as error:
        errors = [str(error)]
    print(json.dumps({"schema_version": 1, "status": "invalid" if errors else "valid_design_declaration",
                      "artifact_verification": "performed" if args.root else "not_requested", "errors": errors,
                      "limit": "声明验证不证明物理通关、创新、趣味或正式准入"}, ensure_ascii=False, indent=2))
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
