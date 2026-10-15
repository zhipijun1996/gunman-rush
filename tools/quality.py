"""Validate quality declarations and evidence; never manufacture human approval."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate JSON field: {key}")
        result[key] = value
    return result


def read_json(path):
    return json.loads(path.read_text(), object_pairs_hook=unique_object)


def policy():
    return read_json(ROOT / "docs/quality/policy.json")


def local_file(root, name):
    if not isinstance(name, str) or not name or Path(name).is_absolute():
        raise ValueError("Expected a repository-relative evidence path")
    path = (root / name).resolve()
    if not path.is_relative_to(root.resolve()) or not path.is_file():
        raise ValueError(f"Missing or external evidence: {name}")
    return path


def populated(value):
    return isinstance(value, str) and bool(value.strip())


def initialize(task_id, kind, commit):
    p = policy()
    state = lambda: {"status": "unverified", "reason": "Awaiting actual evidence", "evidence": []}
    return {
        "schema_version": p["schema_version"], "task_id": task_id, "task_type": kind,
        "workflow": "planned", "baseline_commit": commit, "reviewed_commit": commit,
        "content_version": "candidate-v1", "owner": "implementer", "purpose": "Pending specification",
        "player_experience": "Pending specification", "constraints": ["Preserve existing gameplay contracts"],
        "affected_paths": [], "deliverables": [], "creative_decisions": [], "formal_impact": False,
        "gates": {g: state() for g in p["gates"]},
        "dimensions": {d: state() for d in p["dimensions"]},
        "criteria": [], "evidence": [], "consumer_coverage": None,
        "unverified_items": ["Design and all relevant acceptance remain unverified"],
    }


def validate_record(data, root=ROOT):
    p = policy()
    errors, blockers = [], []
    if not isinstance(data, dict):
        return {"errors": ["Record must be an object"], "blockers": [], "task_complete": False, "verdict": "REJECT"}
    for name in ("task_id", "task_type", "workflow", "baseline_commit", "reviewed_commit", "content_version", "owner", "purpose", "player_experience"):
        if not populated(data.get(name)):
            errors.append(f"Missing text field: {name}")
    if data.get("schema_version") != p["schema_version"]:
        errors.append("Quality schema version mismatch")
    for name in ("baseline_commit", "reviewed_commit"):
        if not re.fullmatch(r"[0-9a-f]{40}", str(data.get(name, ""))):
            errors.append(f"Expected full commit SHA: {name}")
    for name in ("constraints", "affected_paths", "deliverables", "creative_decisions", "criteria", "evidence", "unverified_items"):
        if not isinstance(data.get(name), list):
            errors.append(f"Expected list: {name}")
    if not isinstance(data.get("formal_impact"), bool):
        errors.append("formal_impact must be an explicit boolean")
    kind = data.get("task_type")
    if kind not in p["task_types"]:
        errors.append(f"Unknown task type: {kind}")
    if data.get("workflow") not in p["workflows"]:
        errors.append("Unknown workflow state")
    for group, keys in (("dimensions", p["dimensions"]), ("gates", list(p["gates"]))):
        if not isinstance(data.get(group), dict) or set(data[group]) != set(keys):
            errors.append(f"{group} must contain exactly the policy entries")
        elif any(not isinstance(entry, dict) for entry in data[group].values()):
            errors.append(f"{group} entries must be objects")
    if errors:
        return {"errors": errors, "blockers": blockers, "task_complete": False, "verdict": "REJECT"}

    required_gates = p["task_types"][kind]["gates"]
    required_dims = list(p["task_types"][kind]["dimensions"])
    if kind == "small_fix" and data["formal_impact"]:
        required_dims.append("formal_integration")
    if kind == "process" and data["formal_impact"]:
        errors.append("Process scope cannot declare runtime integration changes")
    production = ("scripts/", "scenes/", "resources/", "config/", "assets/", "shaders/")
    if kind == "process" and any(str(path).startswith(production) or path in {"project.godot", "export_presets.cfg"} for path in data["affected_paths"]):
        errors.append("Process scope cannot hide production changes")
    light = kind in {"process", "small_fix"}
    if not light:
        # Optional means explicitly inapplicable, not permission to ignore unfinished work.
        required_dims.extend(name for name, entry in data["dimensions"].items()
                             if name not in required_dims and entry.get("status") != "not_applicable")
    if data["workflow"] == "awaiting-device":
        if data["dimensions"]["technical"].get("status") != "passed" or data["dimensions"]["device"].get("status") == "passed":
            errors.append("awaiting-device requires technical pass and outstanding device acceptance")
    evidence = {}
    for item in data["evidence"]:
        if not isinstance(item, dict):
            errors.append("Evidence must be an object")
            continue
        for field in ("id", "path", "sha256", "kind", "producer", "source_commit", "content_version", "method", "observed"):
            if not populated(item.get(field)):
                errors.append(f"Evidence missing {field}: {item.get('id')}")
        eid = item.get("id")
        if not isinstance(eid, str) or eid in evidence:
            errors.append("Evidence IDs must be unique strings")
            continue
        evidence[eid] = item
        if item.get("kind") not in {"spec", "command", "runtime_trace", "screenshot", "video", "gui", "review", "user_feedback", "measurement", "device_measurement"}:
            errors.append(f"Unknown evidence kind: {eid}")
        try:
            file = local_file(root, item.get("path"))
            if hashlib.sha256(file.read_bytes()).hexdigest() != item.get("sha256"):
                errors.append(f"Evidence hash mismatch: {eid}")
            if file.stat().st_size == 0:
                errors.append(f"Empty evidence: {eid}")
            suffixes = {"video": {".mp4", ".webm", ".mov"}, "screenshot": {".png", ".jpg", ".jpeg", ".webp"}}
            if item.get("kind") in suffixes and file.suffix.lower() not in suffixes[item["kind"]]:
                errors.append(f"Wrong evidence media type: {eid}")
        except (OSError, ValueError) as error:
            errors.append(str(error))
        if not re.fullmatch(r"[0-9a-f]{40}", str(item.get("source_commit", ""))):
            errors.append(f"Evidence source commit invalid: {eid}")
        if item.get("kind") == "command":
            if not populated(item.get("command")) or type(item.get("exit_code")) is not int or not populated(item.get("environment")):
                errors.append(f"Command evidence needs command, integer exit_code and environment: {eid}")
        if item.get("kind") == "user_feedback":
            if item.get("producer") != "user" or not populated(item.get("source")) or not populated(item.get("quote")) or not isinstance(item.get("covers"), list):
                errors.append(f"User feedback requires user attribution, source, quote and covers: {eid}")
        if item.get("kind") in {"measurement", "device_measurement"}:
            for field in ("device", "environment", "scenario", "budget_source", "observed"):
                if not populated(item.get(field)):
                    errors.append(f"Measurement missing {field}: {eid}")
        if item.get("kind") == "review":
            if not populated(item.get("reviewer")) or not isinstance(item.get("implementers"), list) or not item["implementers"] or item.get("verdict") not in {"ACCEPT", "REJECT", "UNVERIFIED"}:
                errors.append(f"Review identity/verdict missing: {eid}")

    def refs(entry, label):
        if not isinstance(entry, dict):
            errors.append(f"Invalid state entry: {label}")
            return []
        if entry.get("status") not in p["states"] or not populated(entry.get("reason")) or not isinstance(entry.get("evidence"), list):
            errors.append(f"Invalid state/reason/evidence: {label}")
            return []
        result = []
        for eid in entry["evidence"]:
            if not isinstance(eid, str) or eid not in evidence:
                errors.append(f"Unknown evidence reference in {label}: {eid}")
            else:
                result.append(evidence[eid])
        if entry["status"] == "passed":
            if not result:
                errors.append(f"PASS without evidence: {label}")
            for item in result:
                if item.get("content_version") != data["content_version"]:
                    errors.append(f"Stale content evidence in {label}")
                if item.get("kind") in {"command", "review", "runtime_trace", "gui", "measurement", "device_measurement"} and item.get("source_commit") != data["reviewed_commit"]:
                    errors.append(f"Stale implementation evidence in {label}")
                if item.get("kind") == "command" and item.get("exit_code") != 0:
                    errors.append(f"Failed command used for PASS: {label}")
                if item.get("kind") == "review" and item.get("verdict") != "ACCEPT":
                    errors.append(f"Non-ACCEPT review used for PASS: {label}")
                if item.get("kind") == "user_feedback" and item.get("accepted") is not True:
                    errors.append(f"Unaccepted feedback used for PASS: {label}")
        return result

    dimension_kinds = {"design": {"spec"}, "technical": {"command"}, "formal_integration": {"gui"},
                       "visual": {"screenshot"}, "animation": {"video"}, "audio_vfx": {"video"},
                       "gameplay": {"user_feedback"}, "performance": {"measurement", "device_measurement"},
                       "independent_review": {"review"}, "device": {"device_measurement"}, "player_acceptance": {"user_feedback"}}
    for name, entry in data["dimensions"].items():
        items = refs(entry, name)
        status = entry.get("status") if isinstance(entry, dict) else None
        if name in required_dims and status != "passed":
            blockers.append(f"{name}: {status}")
        if status == "failed":
            blockers.append(f"Failed dimension: {name}")
        if status == "passed":
            if not dimension_kinds[name].intersection(item.get("kind") for item in items):
                errors.append(f"Wrong evidence kind for dimension: {name}")
            if name == "independent_review":
                valid = [i for i in items if i.get("kind") == "review" and i.get("independent") is True and i.get("reviewer") not in [data["owner"], *i.get("implementers", [])] and populated(i.get("independence_basis"))]
                if not valid:
                    errors.append("Self review cannot pass independent_review")
            if name == "device" and not any(i.get("kind") == "device_measurement" and i.get("physical") is True for i in items):
                errors.append("Device PASS requires physical-device evidence")
            if name == "player_acceptance":
                needed = set(required_dims) & {"visual", "animation", "audio_vfx", "gameplay"}
                covered = {d for i in items if i.get("kind") == "user_feedback" and i.get("producer") == "user" and i.get("accepted") is True for d in i.get("covers", [])}
                if not needed <= covered:
                    errors.append("Player acceptance does not cover applicable subjective dimensions")

    for gate, entry in data["gates"].items():
        items = refs(entry, gate)
        status = entry.get("status") if isinstance(entry, dict) else None
        if gate in required_gates and status != "passed":
            blockers.append(f"{gate}: {status}")
        if status == "failed":
            blockers.append(f"Failed gate: {gate}")
        if status == "passed":
            required_kinds = list(p["gate_evidence"][gate])
            if light and gate == "G4":
                required_kinds = ["command"]
            if not set(required_kinds) <= {i.get("kind") for i in items}:
                errors.append(f"Gate evidence incomplete: {gate}")
            for dimension in p["gates"][gate]:
                if dimension in required_dims and data["dimensions"][dimension].get("status") != "passed":
                    errors.append(f"Gate {gate} contradicts dimension {dimension}")
            for prior in required_gates:
                if prior < gate and data["gates"][prior].get("status") != "passed":
                    errors.append(f"Gate {gate} bypasses {prior}")

    # Older records retain their historical scope. New records explicitly carry
    # this field; formal PASS needs output evidence for each discovered consumer.
    if data["formal_impact"] and "consumer_coverage" in data:
        coverage = data["consumer_coverage"]
        if coverage is None:
            blockers.append("Formal consumer inventory has not been observed")
            if data["dimensions"]["formal_integration"]["status"] == "passed":
                errors.append("Formal PASS without consumer coverage")
        else:
            coverage_errors, coverage_blockers = validate_consumer_coverage(coverage, evidence, root)
            errors.extend(coverage_errors)
            blockers.extend(coverage_blockers)
            inventory = evidence.get(coverage.get("inventory_evidence"), {}) if isinstance(coverage, dict) else {}
            if inventory.get("source_commit") != data["reviewed_commit"] or inventory.get("content_version") != data["content_version"]:
                errors.append("Consumer inventory does not match reviewed implementation")
            if coverage_blockers and data["dimensions"]["formal_integration"]["status"] == "passed":
                errors.append("Formal PASS exceeds observed consumer scope")

    seen_criteria = set()
    for criterion in data["criteria"]:
        if not isinstance(criterion, dict):
            errors.append("Criterion must be an object")
            continue
        for key in ("id", "scenario", "method", "expected", "failure"):
            if not populated(criterion.get(key)):
                errors.append(f"Criterion missing {key}")
        cid = criterion.get("id")
        if not isinstance(cid, str) or cid in seen_criteria:
            errors.append("Criterion IDs must be unique strings")
        else:
            seen_criteria.add(cid)
        if criterion.get("gate") not in p["gates"] or criterion.get("dimension") not in p["dimensions"]:
            errors.append(f"Unknown criterion gate/dimension: {cid}")
        refs(criterion, f"criterion {cid}")
        if criterion.get("status") == "failed":
            blockers.append(f"Failed criterion: {cid}")
    for group in (required_gates, required_dims):
        for name in group:
            if not any(c.get("status") == "passed" and name in (c.get("gate"), c.get("dimension")) for c in data["criteria"] if isinstance(c, dict)):
                blockers.append(f"No passed scenario criterion for {name}")
    for decision in data["creative_decisions"]:
        if not isinstance(decision, dict) or decision.get("status") not in {"proposed", "user_confirmed", "not_required"} or not populated(decision.get("decision")) or not populated(decision.get("basis")):
            errors.append("Creative decision must declare status, decision and basis")
        elif decision["status"] == "proposed":
            blockers.append("Major creative decision remains proposed")
        elif decision["status"] == "user_confirmed":
            source = evidence.get(decision.get("evidence_id"), {})
            if source.get("kind") != "user_feedback" or source.get("producer") != "user" or source.get("accepted") is not True:
                errors.append("User-confirmed creative decision lacks linked original user approval")
    if not data["deliverables"] or not data["affected_paths"]:
        blockers.append("Deliverables and affected paths must be explicit")
    if data["workflow"] == "done" and blockers:
        errors.append("False done: applicable quality gates are incomplete")
    failed = any(isinstance(e, dict) and e.get("status") == "failed" for g in ("dimensions", "gates") for e in data[g].values()) or any(c.get("status") == "failed" for c in data["criteria"] if isinstance(c, dict))
    complete = not errors and not blockers
    return {"task_id": data["task_id"], "errors": errors, "blockers": blockers,
            "task_complete": complete, "content_complete": complete and not light,
            "verdict": "REJECT" if errors or failed else "ACCEPT" if complete else "UNVERIFIED",
            "scope": "record consistency and evidence attribution; not subjective quality or identity authentication"}


def validate_consumer_coverage(coverage, evidence, root=ROOT):
    """Match independently collected inventory to observed outputs, not helpers.

    This checks traceability, not whether the inventory/visual judgment is true.
    Inventory discovery scope and runtime call paths still require review.
    """
    errors, blockers = [], []
    if not isinstance(coverage, dict) or not populated(coverage.get("scope")):
        return ["Consumer coverage needs explicit bounded scope"], []
    try:
        inventory_ref = evidence[coverage["inventory_evidence"]]
        if inventory_ref["kind"] != "runtime_trace":
            raise ValueError("Consumer inventory must come from a runtime trace")
        inventory = read_json(local_file(root, inventory_ref["path"]))["consumers"]
        ids = [item["id"] for item in inventory]
        if not ids or len(set(ids)) != len(ids) or any(not populated(i) for i in ids):
            raise ValueError("Consumer inventory IDs must be nonempty and unique")
        observations = coverage["observations"]
        observed_ids = [item["consumer"] for item in observations]
        if len(set(observed_ids)) != len(observed_ids) or set(observed_ids) != set(ids):
            raise ValueError("Consumer coverage must account for every discovered consumer exactly once")
        for item in observations:
            cid = item["consumer"]
            if item.get("status") not in policy()["states"] or not populated(item.get("reason")):
                raise ValueError("Consumer observations require status and reason")
            if item.get("output") not in {"visual", "behavior"}:
                raise ValueError("Consumer observation output must be visual or behavior")
            if item["status"] in {"failed", "unverified"}:
                blockers.append(f"Consumer {cid}: {item['status']}")
            elif item["status"] == "passed":
                kinds = {"gui", "screenshot", "video"} if item.get("output") == "visual" else {"runtime_trace", "gui", "video"}
                refs = [evidence[eid] for eid in item.get("evidence", [])]
                if not refs or not any(r["kind"] in kinds and cid in r.get("consumers", []) for r in refs):
                    raise ValueError(f"Consumer {cid}: PASS needs attributed actual output, not a helper test")
                if any(r["source_commit"] != inventory_ref["source_commit"] or r["content_version"] != inventory_ref["content_version"] for r in refs):
                    raise ValueError(f"Consumer {cid}: stale output evidence")
            # not_applicable is an explicit exclusion, never an observed PASS.
    except (KeyError, TypeError, ValueError, OSError) as error:
        errors.append(f"Consumer coverage: {error}")
    return errors, blockers


def validate_asset(data, root=ROOT):
    errors = []
    if not isinstance(data, dict):
        return ["Asset metadata must be an object"]
    for key in ("asset_id", "content_version", "source_path", "source_sha256", "tool", "model", "prompt_or_reference", "processing", "usage_scope", "license_source"):
        if not populated(data.get(key)):
            errors.append(f"Asset metadata missing: {key}")
    disposition = data.get("disposition")
    non_runtime = disposition in {"rejected_evidence_only", "production_record_only"} if isinstance(disposition, str) else False
    runtime_disposition = disposition in {"runtime_candidate", "limited_preview", "legacy_fixture_only"} if isinstance(disposition, str) else False
    if disposition is not None and not (non_runtime or runtime_disposition):
        errors.append("Asset disposition invalid")
    runtime_paths = data.get("runtime_paths")
    if data.get("schema_version") != policy()["schema_version"] or not isinstance(runtime_paths, list) or (not runtime_paths and not non_runtime):
        errors.append("Asset version/runtime consumers missing")
    if non_runtime:
        if runtime_paths != [] or not populated(data.get("non_runtime_reason")):
            errors.append("Non-runtime asset needs empty runtime_paths and explicit non_runtime_reason")
        if data.get("visual_status") == "passed":
            errors.append("Non-runtime asset cannot claim visual passed")
    if data.get("license_status") not in {"verified", "unknown", "restricted"} or data.get("visual_status") not in policy()["states"]:
        errors.append("Asset license/visual status invalid")
    try:
        source = local_file(root, data.get("source_path"))
        if hashlib.sha256(source.read_bytes()).hexdigest() != data.get("source_sha256"):
            errors.append("Asset source hash mismatch")
        for path in runtime_paths if isinstance(runtime_paths, list) else []:
            local_file(root, path)
    except (ValueError, OSError) as error:
        errors.append(str(error))
    associated = data.get("associated_files", [])
    if not isinstance(associated, list):
        errors.append("Asset associated_files must be a list")
        associated = []
    seen_associated = set()
    roles = {"generation_record", "reference", "processing_record", "source_contract", "documentation"}
    for item in associated:
        try:
            if not isinstance(item, dict) or set(item) != {"path", "sha256", "role"}:
                raise ValueError("Associated file needs exact path, sha256 and role fields")
            name = item["path"]
            if not isinstance(name, str) or any(c in name for c in "*?[]") or ".." in Path(name).parts or Path(name).as_posix() != name:
                raise ValueError("Associated file path must be exact and repository-relative")
            local = local_file(root, name)
            if name in seen_associated:
                raise ValueError("Duplicate associated file path")
            seen_associated.add(name)
            if not isinstance(item["role"], str) or item["role"] not in roles:
                raise ValueError("Associated file role invalid")
            if not isinstance(item["sha256"], str) or not re.fullmatch(r"[0-9a-f]{64}", item["sha256"]):
                raise ValueError("Associated file sha256 invalid")
            if hashlib.sha256(local.read_bytes()).hexdigest() != item["sha256"]:
                raise ValueError("Associated file hash mismatch")
        except (ValueError, OSError) as error:
            errors.append(str(error))
    if data.get("visual_status") == "passed":
        if data.get("license_status") != "verified" or not data.get("user_acceptance_evidence"):
            errors.append("Final asset needs license and actual user acceptance evidence")
        for path in data.get("user_acceptance_evidence", []):
            try:
                local_file(root, path)
            except ValueError as error:
                errors.append(str(error))
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    init = commands.add_parser("init")
    init.add_argument("--id", required=True)
    init.add_argument("--type", choices=list(policy()["task_types"]), required=True)
    init.add_argument("--output", type=Path, required=True)
    check = commands.add_parser("check")
    check.add_argument("records", nargs="*", type=Path)
    check.add_argument("--require-complete", action="store_true")
    args = parser.parse_args()
    if args.action == "init":
        commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("x") as file:
            file.write(json.dumps(initialize(args.id, args.type, commit), ensure_ascii=False, indent=2) + "\n")
        print(f"Created unverified record: {args.output}")
        return 0
    paths = args.records or sorted((ROOT / "docs/quality/records").glob("*.json"))
    if args.require_complete and not paths:
        print("No quality records to certify", file=sys.stderr)
        return 1
    failed = False
    for path in paths:
        result = validate_record(read_json(path))
        print(json.dumps({"file": str(path), **result}, ensure_ascii=False))
        failed |= bool(result["errors"]) or (args.require_complete and not result["task_complete"])
    if not failed:
        print(f"PASS: {len(paths)} quality records consistent; this does not certify gameplay quality.")
    return int(failed)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(f"Quality validation failed: {error}", file=sys.stderr)
        sys.exit(1)
