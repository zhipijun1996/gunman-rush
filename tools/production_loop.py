"""Bounded, resumable Codex Skill production loop; harness remains the check authority."""
import argparse
import fcntl
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
import time
import os
import signal
import uuid
import runpy
import math
from contextlib import contextmanager

import harness
import quality

ROOT = harness.ROOT
RESULT_SCHEMA = {"type": "object", "additionalProperties": False, "properties": {
    "status": {"type": "string", "enum": ["ready_for_review", "accept", "reject", "rework", "rethink", "discard", "awaiting_acceptance", "blocked"]},
    "summary": {"type": "string"}, "findings": {"type": "array", "items": {"type": "string"}}},
    "required": ["status", "summary", "findings"]}


def validate_result(result, role):
    allowed = {"ready_for_review", "reject", "awaiting_acceptance", "blocked"} if role == "implement" else {"accept", "reject", "rework", "rethink", "discard", "awaiting_acceptance", "blocked"}
    if (not isinstance(result, dict) or set(result) != {"status", "summary", "findings"}
            or result.get("status") not in allowed or not isinstance(result.get("summary"), str)
            or not result["summary"].strip() or not isinstance(result.get("findings"), list)
            or any(not isinstance(item, str) for item in result["findings"])):
        raise ValueError(f"Invalid {role} result; role cannot grant its own acceptance")
    return result


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def validate(m):
    if m.get("schema_version") != 1 or not m.get("objective") or not m.get("tasks"):
        raise ValueError("Mission needs schema_version=1, objective and tasks")
    if type(m.get("max_calls")) is not int or type(m.get("max_rounds")) is not int or not 1 <= m["max_calls"] <= 100 or not 1 <= m["max_rounds"] <= 10:
        raise ValueError("Specify bounded max_calls (1..100), max_rounds (1..10)")
    if type(m.get("call_timeout_seconds")) is not int or not 1 <= m["call_timeout_seconds"] <= 3600:
        raise ValueError("Specify call_timeout_seconds (1..3600)")
    if "native_import_preflight" in m and type(m["native_import_preflight"]) is not bool:
        raise ValueError("native_import_preflight must be boolean")
    retry = m.get("transport_retry", {})
    if (not isinstance(retry, dict) or set(retry) - {"max_retries", "backoff_seconds"}
            or type(retry.get("max_retries", 0)) is not int or not 0 <= retry.get("max_retries", 0) <= 2
            or type(retry.get("backoff_seconds", 1)) is not int or not 1 <= retry.get("backoff_seconds", 1) <= 30):
        raise ValueError("Transport retry requires max_retries 0..2 and backoff_seconds 1..30")
    ids = [t["id"] for t in m["tasks"]]
    if any(not re.fullmatch(r"[A-Za-z0-9_-]+", value) for value in ids):
        raise ValueError("Task IDs must be safe directory names")
    if len(set(ids)) != len(ids):
        raise ValueError("Duplicate task id")
    done = set()
    for t in m["tasks"]:
        if not t.get("goal") or not t.get("skills") or not t.get("checks"):
            raise ValueError("Each task needs goal, skills and checks")
        if "max_calls" in t and (type(t["max_calls"]) is not int or not 2 <= t["max_calls"] <= m["max_calls"]):
            raise ValueError("Task max_calls must reserve implementation/review within mission max_calls")
        for path in t.get("allowed_paths", []) + ([t["quality_record"]] if t.get("quality_record") else []):
            if Path(path).is_absolute() or ".." in Path(path).parts or path in {".", ""}:
                raise ValueError("Task paths must be repository relative")
        for s in t["skills"]:
            quality.local_file(ROOT, f".agents/skills/{s}/SKILL.md")
        for c in t["checks"]:
            if c not in check_manifest_metadata()["checks"]:
                raise ValueError(f"Unknown harness check: {c}")
        if not set(t.get("depends_on", [])).issubset(done):
            raise ValueError("Tasks must be topologically ordered; unknown/cyclic dependency")
        if not t.get("read_only", False) and not t.get("quality_record"):
            raise ValueError("Production task must name its quality record")
        if "mechanism_review" in t and type(t["mechanism_review"]) is not bool:
            raise ValueError("mechanism_review must be an explicit boolean")
        completion = t.get("completion", "scope" if t.get("read_only") else "content")
        if completion not in {"scope", "stage", "content"} or (completion == "scope" and not t.get("read_only")):
            raise ValueError("Scope completion is read-only; production requires stage or content")
        if completion in {"stage", "content"} and not t.get("quality_record"):
            raise ValueError("Stage/content completion requires an existing quality record contract")
        if completion == "stage" and (not t.get("required_gates") or any(g not in quality.policy()["gates"] for g in t["required_gates"])):
            raise ValueError("Stage must declare existing required_gates")
        if t.get("quality_task_id", t["id"]) not in [t["id"], *t.get("depends_on", [])]:
            raise ValueError("Quality record must bind this task or a direct completed dependency")
        if t.get("creative_direction") and t["id"].endswith("-golden") and m.get("phase") != "prototype":
            joint = {"level-module-creator", "challenge-choreographer", "art-director", "visual-director", "scene-composer", "encounter-director", "animation-vfx"}
            if (t.get("requires_visual_admission") is not True or "G2" not in t.get("required_gates", [])
                    or not joint <= set(t["skills"])):
                raise ValueError("Creative production golden requires joint specialties and independent G2 visual admission")
        if "creative_stagnation_guard" in t and type(t["creative_stagnation_guard"]) is not bool:
            raise ValueError("creative_stagnation_guard must be boolean")
        if t.get("feedback_context", "full") not in ("full", "compact"):
            raise ValueError("feedback_context must be full or compact")
        done.add(t["id"])


def creative_direction_input(task):
    """Load the selected, version-bound creative authority; never imply user approval."""
    if "creative_direction" not in task:
        return None
    ref = task["creative_direction"]
    if (not isinstance(ref, dict) or set(ref) != {"path", "sha256", "region_id", "version"}
            or any(not isinstance(ref.get(k), str) or not ref[k].strip() for k in ref)
            or Path(ref["path"]).is_absolute() or ".." in Path(ref["path"]).parts
            or not re.fullmatch(r"[0-9a-f]{64}", ref["sha256"])):
        raise ValueError("Invalid creative_direction path/hash/region_id/version contract")
    path = ROOT / ref["path"]
    if any(p.is_symlink() for p in [path, *path.parents] if p == ROOT or p.is_relative_to(ROOT)):
        raise ValueError("Creative direction must be a regular repository file")
    path = quality.local_file(ROOT, ref["path"])
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != ref["sha256"]:
        raise ValueError("Creative direction SHA256 changed; return to pre-production and rebind tasks")
    data = json.loads(raw, object_pairs_hook=quality.unique_object)
    if (not isinstance(data, dict) or type(data.get("schema_version")) is not int or data["schema_version"] != 1
            or any(data.get(k) != ref[k] for k in ("region_id", "version"))
            or data.get("decision") != "selected"
            or data.get("acceptance") not in ("professional_recommendation", "user_confirmed")):
        raise ValueError("Creative direction must match region/version and be selected with explicit acceptance")
    # Hand-written missions must pass the same complete creative contract as the router.
    # Recheck authority bytes on every preflight and on both sides of worker calls.
    from region_creative_direction import load_direction
    loaded, bound = load_direction(ref["path"], ref["region_id"], root=ROOT)
    if bound != {**ref, "path": Path(ref["path"]).as_posix()} or loaded != data:
        raise ValueError("Creative direction changed during complete authority validation")
    return {"path": ref["path"], "sha256": ref["sha256"], "content": loaded}


def spatial_experiment_input(task):
    ref = task.get("spatial_experiment")
    if ref is None:
        return None
    direction = task.get("creative_direction", {})
    if not isinstance(ref, dict) or set(ref) != {"path", "sha256", "region_id", "allowed_paths"} or ref.get("region_id") != direction.get("region_id"):
        raise ValueError("Spatial experiment must bind selected region and exact design lease")
    from level_design import load_spatial_experiment
    data, bound = load_spatial_experiment(ref["path"], ref["region_id"], root=ROOT)
    if bound != ref:
        raise ValueError("Spatial experiment design/hash/write set changed; replan before execution")
    expected_records = {f"docs/quality/records/{task['id']}.json"}
    if task.get("quality_task_id") in [task["id"], *task.get("depends_on", [])]:
        expected_records.add(f"docs/quality/records/{task['quality_task_id']}.json")
    if task.get("quality_record") not in expected_records:
        raise ValueError("Spatial quality record must be the exact task-bound docs/quality/records JSON")
    record_path = ROOT / task["quality_record"]
    if any(path.is_symlink() for path in [record_path, *record_path.parents] if path == ROOT or path.is_relative_to(ROOT)):
        raise ValueError("Spatial quality record cannot be a symlink alias")
    if (data["design"].get("direction_path") != direction.get("path")
            or data["design"].get("direction_sha256") != direction.get("sha256")):
        raise ValueError("Spatial design belongs to a different creative direction path/hash; rethink before lease")
    permitted = set(ref["allowed_paths"]) | {task.get("quality_record"), "docs/tasks.md"}
    if set(task.get("allowed_paths", [])) != permitted:
        raise ValueError("Spatial experiment task must use the exact authorized file write set")
    return {"path": ref["path"], "sha256": ref["sha256"], "content": data}


def bound_source_inputs(task):
    sources = [value for value in (creative_direction_input(task), spatial_experiment_input(task)) if value]
    return [{key: source[key] for key in ("path", "sha256")} for source in sources]


def feedback_context(task, dependencies, history):
    """Keep disk evidence complete; creative workers receive only the latest causal index."""
    if task.get("feedback_context", "compact" if task.get("creative_direction") else "full") == "full":
        return {"dependencies": dependencies, "previous_rounds": history}
    def latest(records):
        if not records:
            return []
        record = records[-1]
        return [{"round": record["round"], "result": record.get("result"),
                 "evidence": record["evidence"],
                 "record_path": str(Path(record["evidence"]) / "checkpoint.json")}]
    return {"dependencies": {key: latest(records) for key, records in dependencies.items()},
            "previous_rounds": latest(history)}


def snapshot():
    result = subprocess.run(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                            cwd=ROOT, capture_output=True, check=True, timeout=30)
    return {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() if (ROOT / p).is_file() else "deleted"
            for p in result.stdout.decode().split("\0") if p}


def save(path, data):
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    tmp.replace(path)


def check_manifest_metadata():
    """Validate profile metadata; preflight owns missing entry-file diagnostics.

    Harness still checks its normal file/command contract when checks execute.
    Keeping file existence separate lets sparse inputs stop with calls0 evidence.
    """
    data = quality.read_json(harness.MANIFEST)
    if data.get("schema_version") != 1:
        raise ValueError("Unsupported harness schema")
    checks = data["checks"]
    for name, check in checks.items():
        if not check["argv"] or check["timeout_seconds"] <= 0:
            raise ValueError(f"Invalid check: {name}")
        re.compile(check["success_pattern"])
    for name, ids in data["profiles"].items():
        if not ids or len(set(ids)) != len(ids) or any(i not in checks for i in ids):
            raise ValueError(f"Invalid profile: {name}")
    return data


def resolved_check_contracts(task):
    """The selected Harness definitions, not similarly named auxiliary runners."""
    manifest = check_manifest_metadata()
    return {"manifest": "tools/harness/profiles.json",
            "manifest_sha256": hashlib.sha256(harness.MANIFEST.read_bytes()).hexdigest(),
            "cwd": str(ROOT), "checks": [{"id": name, **{key: manifest["checks"][name][key]
                for key in ("argv", "timeout_seconds", "success_pattern", "inputs", "artifact_paths")
                if key in manifest["checks"][name]}} for name in task["checks"]]}


def required_input_preflight(task):
    """Check materialization edges in existing indexes, never judge their quality.

    Only tracked inputs can block. New untracked evidence is a future output.
    A sparse S entry is infrastructure, while an ordinary deletion explicitly
    named in allowed_paths can be the repair this implementation is meant to do.
    """
    direction_error = None
    try:
        creative_direction_input(task)
    except (ValueError, OSError) as error:
        direction_error = str(error)
    spatial_error = None
    try:
        spatial_experiment_input(task)
    except (ValueError, OSError, TypeError) as error:
        spatial_error = str(error)
    contracts = resolved_check_contracts(task)
    entries = subprocess.check_output(["git", "ls-files", "-v", "-z"], cwd=ROOT).decode().split("\0")
    tracked = {line[2:]: line[0] for line in entries if line}
    files = harness.source_files(ROOT)
    required = {}
    warnings = []
    uncertain = ([{"path": task["creative_direction"].get("path", "") if isinstance(task.get("creative_direction"), dict) else "",
                   "reason": "creative_direction_invalid", "error": direction_error}] if direction_error else [])
    if spatial_error:
        ref = task.get("spatial_experiment")
        uncertain.append({"path": ref.get("path", "") if isinstance(ref, dict) else "",
                          "reason": "spatial_experiment_invalid", "error": spatial_error})

    lexical_paths = {}
    relative_names = {}
    root_parts = ROOT.parts

    def file_state(name):
        key = (ROOT, name)
        if key not in lexical_paths:
            path = ROOT / name
            # This is lexical containment, deliberately not resolve(): symlinks
            # must remain visible to every subsequent filesystem check. Comparing
            # component prefixes avoids rebuilding relative paths for each parent.
            lexical_paths[key] = (path, tuple(parent for parent in [path, *path.parents]
                                              if ((parent == ROOT or parent.is_relative_to(ROOT)) if os.name == "nt"
                                                  else parent.parts[:len(root_parts)] == root_parts)))
        path, parents = lexical_paths[key]
        try:
            if any(parent.is_symlink() for parent in parents):
                return "symlink_input"
            path.stat()
            if not path.is_file():
                return "not_regular_file"
            with path.open("rb") as handle:
                handle.read(1)
            return "readable"
        except FileNotFoundError:
            return "missing"
        except OSError as error:
            return f"unreadable:{type(error).__name__}"

    def require(name, source):
        if not isinstance(name, str) or not name:
            return
        # Preserve the Git index identity before touching the filesystem. resolve
        # would erase a broken/external symlink from the tracked dependency set.
        key = (ROOT, name)
        if key not in relative_names:
            path = Path(os.path.abspath(ROOT / name))
            parts = path.parts
            if os.name == "nt":
                # Windows drive/case semantics stay with pathlib's original rule.
                relative_names[key] = path.relative_to(ROOT).as_posix() if path.is_relative_to(ROOT) else None
            else:
                relative_names[key] = ("/".join(parts[len(root_parts):]) or ".") if parts[:len(root_parts)] == root_parts else None
        relative = relative_names[key]
        if relative in tracked:
            required.setdefault(relative, set()).add(source)

    def json_index(name):
        require(name, "selected quality index")
        if file_state(name) != "readable":
            return {}
        try:
            data = quality.read_json(ROOT / name)
            if not isinstance(data, dict):
                raise ValueError("Expected a JSON object index")
            return data
        except (ValueError, OSError) as error:
            # An unreadable/malformed index conceals required dependency edges.
            warnings.append({"index": name, "error": str(error)})
            if name in tracked:
                uncertain.append({"path": name, "reason": "index_dependencies_unknown", "error": str(error)})
            return {}

    def markdown_links(name):
        require(name, "selected Markdown consumer")
        if file_state(name) == "readable":
            try:
                content = (ROOT / name).read_text()
            except (OSError, ValueError) as error:
                if name in tracked:
                    uncertain.append({"path": name, "reason": "markdown_dependencies_unknown", "error": str(error)})
                return
            for link in re.findall(r"\[[^\]]*\]\(([^)]+)\)", content):
                if not link.startswith(("https:", "http:", "#", "mailto:")):
                    require(str(Path(name).parent / link.split("#")[0]), name)

    commands = {item["argv"][1] for item in contracts["checks"] if len(item["argv"]) > 1}
    # The existing Harness loader checks every registered runner before running
    # even one selected check. These tracked entry files are shared execution
    # infrastructure; this does not select their global content indexes.
    for name, check in check_manifest_metadata()["checks"].items():
        if len(check["argv"]) > 1:
            require(check["argv"][1], f"Harness manifest entry {name}")
    for item in contracts["checks"]:
        for argument in item["argv"]:
            require(argument, f"selected check {item['id']} argv")
        for declared in item.get("inputs", []):
            if not any(marker in declared for marker in ("*", "?", "[")):
                # Directory inputs are contracts over their existing Git-tracked
                # members, including sparse entries absent from the filesystem.
                # Reuse require/file_state so permissions and scope rules match
                # literal files; do not scan untracked future output directories.
                prefix = declared.rstrip("/") + "/"
                members = [name for name in tracked if name.startswith(prefix)]
                require(declared, f"selected check {item['id']} literal input")
                for name in members:
                    require(name, f"selected check {item['id']} directory input {declared}")
                if not members and declared.rstrip("/") not in tracked:
                    warnings.append({"index": declared, "warning": "declared_input_has_no_tracked_match"})
    if "tools/check_quality.py" in commands:
        policy = json_index("docs/quality/policy.json")
        for path in policy.get("templates", []):
            require(path, "docs/quality/policy.json templates")
        for path in ("docs/tasks.md", "docs/development_quality.md", "docs/quality/README.md"):
            require(path, "global quality index")
        for name in files:
            if name.startswith(".agents/skills/") and name.endswith("/SKILL.md"):
                markdown_links(name)
            if name.startswith(("docs/quality/records/", "docs/quality/asset_records/")) and name.endswith(".json"):
                data = json_index(name)
                if not isinstance(data, dict):
                    continue
                # Same canonical evidence/source/runtime fields as quality.py.
                for ref in data.get("evidence", []):
                    if isinstance(ref, dict): require(ref.get("path"), name)
                for key in ("runtime_paths", "user_acceptance_evidence"):
                    for path in data.get(key, []): require(path, name)
                require(data.get("source_path"), name)
                coverage = data.get("consumer_coverage")
                if isinstance(coverage, dict):
                    ref = coverage.get("inventory_evidence")
                    if isinstance(ref, dict): require(ref.get("path"), name)
    if "tools/check_docs.py" in commands:
        for name in files:
            if name.endswith(".md"):
                markdown_links(name)
    # These real registered consumers call route_request/load_lessons. Sparse
    # knowledge must stop before a worker, not during its downstream test.
    lesson_consumers = {"tests/test_visual_director.py", "tests/test_production_loop.py",
                        "tests/test_level_design_routing.py"}
    if commands & lesson_consumers:
        ledger = json_index("docs/quality/level_lessons.json")
        for lesson in ledger.get("lessons", []):
            for ref in lesson.get("evidence", []):
                require(ref.get("path"), "docs/quality/level_lessons.json")
    # Godot editor imports create repository-visible sidecars even when a worker
    # only intended to run a selected native check. Detect this before spending
    # a call, using an explicit native input contract rather than runner names.
    native = [item["id"] for item in contracts["checks"]
              if {"project.godot", "assets/**"}.issubset(item.get("inputs", []))]
    imports = []
    generated_import_repairs = set()
    if native:
        for name in sorted(tracked):
            path = ROOT / name
            if not name.startswith("assets/") or path.suffix.lower() not in {".png", ".svg"}:
                continue
            try:
                ignored = any((parent / ".gdignore").is_file() for parent in [path.parent, *path.parents]
                              if parent == ROOT or parent.is_relative_to(ROOT))
            except OSError as error:
                uncertain.append({"path": name, "reason": "ancestor_ignore_unknown", "error": str(error)})
                continue
            if ignored:
                continue
            require(name, "selected native asset input")
            if file_state(name) != "readable":
                continue
            sidecar = name + ".import"
            require(sidecar, "selected native import metadata")
            allowed = not task.get("read_only", False) and any(
                sidecar == item or (item.endswith("/") and sidecar.startswith(item))
                for item in task.get("allowed_paths", []))
            if allowed:
                generated_import_repairs.add(sidecar)
            if file_state(sidecar) != "readable" and not allowed:
                imports.append({"path": sidecar, "source_asset": name,
                                "required_by": native, "reason": "native_import_outside_allowed_paths"})
    missing, repairs = [], []
    for name, sources in sorted(required.items()):
        state = file_state(name)
        if state == "readable":
            continue
        sparse = tracked[name].upper() == "S"
        item = {"path": name, "git_index_state": tracked[name], "required_by": sorted(sources),
                "reason": ("sparse_unmaterialized" if sparse else "tracked_missing") if state == "missing" else state}
        if (state == "missing" and not sparse and not task.get("read_only", False)
                and (name in task.get("allowed_paths", []) or name in generated_import_repairs)):
            repairs.append({**item, "reason": "allowed_generated_import_repair" if name in generated_import_repairs else "explicit_deleted_file_repair"})
        else:
            missing.append(item)
    return {"status": "blocked" if missing or imports or uncertain else "passed", "kind": "tracked_required_input_materialization",
            "missing_tracked_inputs": missing, "explicit_deleted_repairs": repairs, "index_warnings": warnings,
            "import_metadata_risks": imports,
            "uncertain_inputs": uncertain,
            "resolved_checks": contracts,
            "limits": "Existence preflight only; no quality PASS, hydration or inference that untracked future outputs already exist."}


def prepare_call(task, mission, role, folder, feedback, *, check_contracts=None):
    check_contracts = check_contracts or resolved_check_contracts(task)
    skill_names = list(dict.fromkeys((["gameplay-reviewer"] if role == "review" else []) + task["skills"]))
    skill_files = [quality.local_file(ROOT, f".agents/skills/{s}/SKILL.md") for s in skill_names]
    direction = creative_direction_input(task)
    experiment = spatial_experiment_input(task)
    direction_text = ("\nVersioned selected creative authority (all specialties must explain contribution, collaboration, conflicts and live validation): "
                      + json.dumps(direction, ensure_ascii=False) + "\n") if direction else ""
    if experiment:
        direction_text += "\nFrozen playable spatial experiment and exact file lease: " + json.dumps(experiment, ensure_ascii=False) + "\n"
    skills = "\n\n".join(f"Skill source: {p.relative_to(ROOT)}\n{p.read_text()}" for p in skill_files)
    prompt = (f"Repository mission: {mission['objective']}\nTask: {task['goal']}\nRole: {role}\n"
              f"Mission constraints: {json.dumps(mission.get('constraints', []), ensure_ascii=False)}\n"
              f"Prepared region context and lessons: {json.dumps(mission.get('preparation', {}), ensure_ascii=False)}\n"
              f"Task contract: {json.dumps(task, ensure_ascii=False)}\nPrevious evidence: {feedback}\n"
              f"Resolved selected Harness checks (use these exact commands, never guess a similarly named runner): {json.dumps(check_contracts, ensure_ascii=False)}\n"
              "Follow AGENTS.md and these Skills. Do not commit, push, merge, publish or change task scope. "
              "Do not invent user approval, performance evidence or Skill execution. "
              "Stop as awaiting_acceptance for required creative/player/device decisions. "
              "Review must independently inspect and try counterexamples; never edit production files. "
              "Do not launch nested agents or another production loop. The parent owns budgets and harness execution. "
              "Return ready_for_review (never accept) as implementer; reviewer chooses accept, rework (bounded local repair), "
              "rethink (return to pre-production), discard (stop and quarantine candidate), reject (legacy repair), or blocked. "
              "Stage completion only addresses required_gates, not content completion; preserve future gates as unverified. "
              "Read-only scope outputs belong in the structured summary/findings; do not edit repository files.\n" + direction_text + skills)
    save(folder / "context_metrics.json", {"prompt_bytes": len(prompt.encode()), "feedback_bytes": len(feedback.encode()),
         "creative_direction": {k: direction[k] for k in ("path", "sha256")} if direction else None})
    (folder / "prompt.txt").write_text(prompt)
    schema = folder / "schema.json"
    schema.write_text(json.dumps(RESULT_SCHEMA))
    output = folder / "result.json"
    return prompt, skill_files, schema, output


def invoke_host(task, mission, role, folder, feedback):
    """Transport one bounded worker call to the current Codex host, not a second loop."""
    contracts = resolved_check_contracts(task)
    prompt, skill_files, _, output = prepare_call(task, mission, role, folder, feedback, check_contracts=contracts)
    started = time.monotonic()
    started_at = time.time()
    request = {"schema_version": 1, "nonce": uuid.uuid4().hex, "task_id": task["id"],
               "attempt": folder.parent.name, "role": role, "prompt": prompt, "task_contract": task,
               "source_hash": digest(snapshot()), "feedback": feedback,
               "resolved_checks": contracts,
               "skills": [{"path": str(p.relative_to(ROOT)), "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in skill_files],
               "expires_at": time.time() + mission["call_timeout_seconds"]}
    if task.get("creative_direction"):
        direction = creative_direction_input(task)
        request["source_inputs"] = bound_source_inputs(task)
    request["request_hash"] = digest(request)
    request_path = folder / "host_request.json"
    response_path = folder / "host_response.json"
    if request_path.exists() or response_path.exists():
        raise RuntimeError("Host worker lease path already exists; never reuse a prior response")
    save(request_path, request)
    metadata = {"kind": "actual_host_codex_agent", "request_hash": request["request_hash"], "role": role,
                "exit_code": None, "timed_out": False, "agent_id": None, "skills": request["skills"]}

    if "source_inputs" in request:
        metadata["source_inputs"] = request["source_inputs"]

    def require_live_lease():
        if (folder / "lease_revoked.json").exists():
            metadata["revoked"] = True
            raise RuntimeError("Host lease revoked; late responses cannot be accepted")
        if (time.monotonic() - started >= mission["call_timeout_seconds"]
                or time.time() >= request["expires_at"]):
            metadata["timed_out"] = True
            raise RuntimeError("Host Codex worker timed out; lease expired, response cannot be reused")

    try:
        while not response_path.exists():
            require_live_lease()
            time.sleep(0.25)
        # Response arrival can race revocation in the very same polling interval.
        # Check on both sides of parsing, then again around result publication.
        require_live_lease()
        response = quality.read_json(response_path)
        require_live_lease()
        fields = {"schema_version", "request_hash", "task_id", "attempt", "role", "agent_id", "result"}
        if not isinstance(response, dict) or set(response) != fields:
            raise ValueError("Invalid host response schema")
        if response["schema_version"] != 1 or any(response[k] != request[k] for k in ("request_hash", "task_id", "attempt", "role")):
            raise ValueError("Host response does not match this task/attempt/role/lease")
        if not isinstance(response["agent_id"], str) or not re.fullmatch(r"/[A-Za-z0-9_/-]+", response["agent_id"]):
            raise ValueError("Host must identify the actual canonical Codex agent")
        result = validate_result(response["result"], role)
        require_live_lease()
        save(output, result)
        require_live_lease()
        metadata.update(exit_code=0, agent_id=response["agent_id"], response_sha256=hashlib.sha256(response_path.read_bytes()).hexdigest())
        return result
    except Exception as error:
        if output.is_file() and metadata["exit_code"] is None:
            # Keep the rejected bytes as evidence, outside the accepted result path.
            output.replace(folder / "rejected_result.json")
        metadata["error"] = str(error)
        raise
    finally:
        metadata["seconds"] = time.monotonic() - started
        metadata.update(started_at_unix=started_at, ended_at_unix=time.time())
        metadata["lease_status"] = "completed" if metadata["exit_code"] == 0 else "expired" if metadata["timed_out"] else "failed"
        save(folder / "invocation.json", metadata)


def invoke(task, mission, role, folder, feedback):
    prompt, skill_files, schema, output = prepare_call(task, mission, role, folder, feedback)
    argv = ["codex", "exec", "--json", "-c", 'approval_policy="never"', "--output-schema", str(schema), "-o", str(output),
            "-C", str(ROOT), "-s", "read-only" if role == "review" or task.get("read_only") else "workspace-write", "-"]
    start = time.monotonic()
    started_at = time.time()
    process = None
    timed_out = False
    launch_error = None
    try:
        with (folder / "events.jsonl").open("w") as log:
            # No shell expansion and no bypass-approval/sandbox flags.
            process = subprocess.Popen(argv, cwd=ROOT, stdin=subprocess.PIPE, stdout=log,
                                       stderr=subprocess.STDOUT, text=True, start_new_session=True)
            try:
                process.communicate(prompt, timeout=mission["call_timeout_seconds"])
            except subprocess.TimeoutExpired:
                timed_out = True
                os.killpg(process.pid, signal.SIGKILL)
                process.wait(timeout=5)
    except OSError as error:
        launch_error = str(error)
        raise
    finally:
        # A returned parent must not leave background workers past the call budget.
        if process is not None and not timed_out:
            try: os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError: pass
            process.wait(timeout=5)
        metadata = {"started_at_unix": started_at, "ended_at_unix": time.time(), "argv": argv, "exit_code": process.returncode if process else None,
                                          "seconds": time.monotonic()-start, "kind": "actual_codex_exec",
                                          "role": role, "timed_out": timed_out, "launch_error": launch_error,
                                          "skills": [{"path": str(p.relative_to(ROOT)), "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in skill_files]}
        if task.get("creative_direction"):
            metadata["source_inputs"] = bound_source_inputs(task)
        events = []
        if (folder / "events.jsonl").exists():
            for line in (folder / "events.jsonl").read_text().splitlines():
                try: value = json.loads(line)
                except ValueError: continue
                if isinstance(value, dict): events.append(value)
        metadata["thread_ids"] = [e.get("thread_id") for e in events if e.get("type") == "thread.started"]
        metadata["turn_completed"] = any(e.get("type") == "turn.completed" for e in events)
        event_errors = [e for e in events if e.get("type") in {"error", "turn.failed"}]
        metadata["event_errors"] = event_errors
        metadata["events_sha256"] = hashlib.sha256((folder / "events.jsonl").read_bytes()).hexdigest()
        error_text = json.dumps(event_errors).lower()
        metadata["failure_kind"] = ("authentication" if any(s in error_text for s in ("unauthorized", "access token", "sign in again", "401", "token refresh"))
                                    else "timeout" if timed_out else "transport" if any(s in error_text for s in
                                    ("stream disconnected", "connection reset", "temporarily unavailable", "502", "503", "504"))
                                    else "worker_error" if event_errors else None)
        save(folder / "invocation.json", metadata)
    if timed_out:
        raise RuntimeError("Codex call timed out; partial evidence retained")
    if process.returncode or not output.is_file():
        raise RuntimeError(f"Codex invocation failed (exit {process.returncode}; {metadata['failure_kind'] or 'missing_result'}); see retained events.jsonl")
    if not metadata["turn_completed"] or len(metadata["thread_ids"]) != 1 or event_errors:
        raise RuntimeError("Codex missing successful turn completion or reported an error")
    result = quality.read_json(output)
    return validate_result(result, role)


def run(m, folder, worker=invoke, *, recover_interrupted=False, stop_after_phase=None):
    validate(m)
    folder.mkdir(parents=True, exist_ok=True)
    with (folder / "lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return _run_locked(m, folder, worker, recover_interrupted=recover_interrupted,
                           stop_after_phase=stop_after_phase)


@contextmanager
def _collection_worktree(worktree):
    """Read target bytes with this tool; never copy new tools into a frozen tree."""
    global ROOT
    target = Path(worktree).resolve()
    original = (ROOT, harness.ROOT, harness.MANIFEST, quality.ROOT)
    common = lambda path: subprocess.check_output(
        ["git", "-C", str(path), "rev-parse", "--path-format=absolute", "--git-common-dir"], text=True).strip()
    registered = subprocess.check_output(["git", "-C", str(ROOT), "worktree", "list", "--porcelain"], text=True)
    if common(target) != common(ROOT) or str(target) not in [
            line.removeprefix("worktree ") for line in registered.splitlines() if line.startswith("worktree ")]:
        raise ValueError("Collector target must be a registered worktree of the same Git common directory")
    try:
        ROOT = harness.ROOT = quality.ROOT = target
        harness.MANIFEST = target / "tools/harness/profiles.json"
        yield target
    finally:
        ROOT, harness.ROOT, harness.MANIFEST, quality.ROOT = original


def collect_completed_review(mission_path, folder, worktree, controller_pid):
    """Collect one still-live completed review after controller loss, never invoke work.

    Deliberately bounded to one task, one round and its two allocated host calls.
    The original request/response stay intact. Collection metadata explicitly
    identifies this recovery tool, rather than pretending the old controller ran.
    """
    tool_path = Path(__file__).resolve()
    tool_bytes = tool_path.read_bytes()
    tool_sha = hashlib.sha256(tool_bytes).hexdigest()
    with _collection_worktree(worktree) as target:
        mission_path, folder = Path(mission_path).resolve(), Path(folder).resolve()
        if (not mission_path.is_relative_to(target) or not mission_path.is_file()
                or not folder.is_relative_to(target / "build/verification") or not folder.is_dir()):
            raise ValueError("Collector mission/evidence must belong to the target worktree")
        if type(controller_pid) is not int or controller_pid <= 1:
            raise ValueError("Collector needs the actual vanished controller PID")
        with (folder / "lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            ps = subprocess.run(["ps", "-p", str(controller_pid), "-o", "pid=,lstart=,args="],
                                capture_output=True, text=True, timeout=10)
            if ps.returncode != 1 or ps.stdout.strip() or ps.stderr.strip() or Path(f"/proc/{controller_pid}").exists():
                raise ValueError("Original controller is not proven absent; inspect it instead")
            frozen = {}

            def read_original(path):
                if path.is_symlink() or not path.is_file():
                    raise ValueError("Collector evidence must be regular original files")
                frozen[path] = path.read_bytes()
                return json.loads(frozen[path], object_pairs_hook=quality.unique_object)

            m = read_original(mission_path)
            validate(m)
            state_path = folder / "state.json"
            state = read_original(state_path)
            if (len(m["tasks"]) != 1 or m["max_rounds"] != 1 or m["max_calls"] != 2
                    or state.get("worker_mode") != "invoke_host" or state.get("status") not in {"running", "blocked"}
                    or state.get("mission_hash") != digest(m) or state.get("source_hash") != digest(snapshot())
                    or state.get("content_complete") is not False):
                raise ValueError("Collector requires unchanged single-task/single-round two-call host mission")
            validate_restored_budget(m, state, folder)
            task = m["tasks"][0]
            entry = state["tasks"].get(task["id"], {})
            active = state.get("active_call", {})
            attempt = folder / task["id"] / "1"
            call_dir = attempt / "review"
            if (state["calls"] != 2 or entry.get("rounds") != 1 or entry.get("history") != []
                    or entry.get("status") != "pending" or task.get("depends_on", [])
                    or active != {"task_id": task["id"], "round": 1, "role": "review", "evidence": str(call_dir)}):
                raise ValueError("Collector only handles the current first review; inspect/recover other states")
            for path in [attempt / "checkpoint.json", *attempt.glob("*.log"), *attempt.glob("implement*/*.json")]:
                if path.is_symlink() or not path.is_file():
                    raise ValueError("Collector evidence must be regular original files")
                frozen[path] = path.read_bytes()
            checkpoint = _restore_checkpoint(task, entry, folder, worker_mode="invoke_host")
            record = checkpoint["round_record"]
            if (checkpoint["phase"] != "review" or set(record["roles"]) != {"implement"}
                    or record["roles"]["implement"]["status"] != "ready_for_review"
                    or [c.get("id") for c in record["checks"]] != task["checks"]
                    or any(c.get("status") != "passed" for c in record["checks"])):
                raise ValueError("Collector requires the completed pre-review checkpoint and passed checks")
            request_path, response_path = call_dir / "host_request.json", call_dir / "host_response.json"
            if not response_path.is_file():
                raise ValueError("No completed response; use existing inspection/interrupted recovery")
            if any((call_dir / name).exists() for name in ("invocation.json", "result.json", "host_cancellation.json")):
                raise ValueError("Review was already consumed or cancelled; inspect existing evidence")
            request, response = read_original(request_path), read_original(response_path)
            prompt_path = call_dir / "prompt.txt"
            if prompt_path.is_symlink() or not prompt_path.is_file():
                raise ValueError("Collector requires the original review prompt")
            frozen[prompt_path] = prompt_path.read_bytes()
            request_fields = {"schema_version", "nonce", "task_id", "attempt", "role", "prompt", "task_contract",
                              "source_hash", "feedback", "skills", "expires_at", "request_hash"}
            if (not isinstance(request, dict) or set(request) not in (request_fields, request_fields | {"resolved_checks"}, request_fields | {"resolved_checks", "source_inputs"})
                    or request.get("request_hash") != digest({k: v for k, v in request.items() if k != "request_hash"})
                    or type(request.get("schema_version")) is not int or request["schema_version"] != 1
                    or request.get("prompt") != frozen[prompt_path].decode() or request.get("task_contract") != task
                    or request.get("source_hash") != state["source_hash"] or request.get("task_id") != task["id"]
                    or request.get("attempt") != "1" or request.get("role") != "review"
                    or not isinstance(request.get("nonce"), str) or not re.fullmatch(r"[0-9a-f]{32}", request["nonce"])
                    or type(request.get("expires_at")) not in {int, float}
                    or not math.isfinite(request["expires_at"])):
                raise ValueError("Current review request binding/nonce changed")
            if "resolved_checks" in request and request["resolved_checks"] != resolved_check_contracts(task):
                raise ValueError("Current review selected check command contract changed")
            direction = creative_direction_input(task)
            expected_inputs = bound_source_inputs(task) if direction else None
            for source in expected_inputs or []:
                source_path = target / source["path"]
                frozen[source_path] = source_path.read_bytes()
                if hashlib.sha256(frozen[source_path]).hexdigest() != source["sha256"]:
                    raise ValueError("Creative source changed while binding collector inputs")
            if request.get("source_inputs") != expected_inputs:
                raise ValueError("Current review creative source inputs changed")
            expected_skills = [{"path": f".agents/skills/{name}/SKILL.md",
                                "sha256": hashlib.sha256((target / f".agents/skills/{name}/SKILL.md").read_bytes()).hexdigest()}
                               for name in dict.fromkeys(["gameplay-reviewer", *task["skills"]])]
            feedback = json.loads(request["feedback"])
            if (request.get("skills") != expected_skills or feedback.get("implementation") != record["roles"]["implement"]
                    or feedback.get("checks") != record["checks"] or feedback.get("dependencies") != {}
                    or feedback.get("previous_rounds") != []):
                raise ValueError("Review request skills/checkpoint context changed")
            fields = {"schema_version", "request_hash", "task_id", "attempt", "role", "agent_id", "result"}
            if (not isinstance(response, dict) or set(response) != fields or type(response.get("schema_version")) is not int
                    or any(response.get(k) != request.get(k)
                    for k in ("schema_version", "request_hash", "task_id", "attempt", "role"))
                    or not isinstance(response.get("agent_id"), str)
                    or not re.fullmatch(r"/[A-Za-z0-9_/-]+", response["agent_id"])):
                raise ValueError("Completed response does not match current review lease/identity")
            result = validate_result(response["result"], "review")
            reviewer = {("agent", response["agent_id"])}
            for previous in folder.glob("*/*/implement*/invocation.json"):
                if reviewer & invocation_identities(quality.read_json(previous)):
                    raise ValueError("Completed reviewer is not independent of implementation")
            # Bind every input byte before publishing any recovered metadata.
            expected_source = state["source_hash"]
            checkpoint_path = attempt / "checkpoint.json"
            controller_outputs = {state_path, checkpoint_path}
            publications = {}
            serialized = lambda value: (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode()

            def guard(*, finalizing=False):
                if ((call_dir / "lease_revoked.json").exists() or (call_dir / "host_cancellation.json").exists()
                        or not time.time() < request["expires_at"]):
                    raise ValueError("Completed review lease expired/revoked/cancelled; cannot collect")
                if (digest(snapshot()) != expected_source
                        or any(p.is_symlink() or p.read_bytes() != contents for p, contents in frozen.items()
                               if not finalizing or p not in controller_outputs)
                        or any(p.is_symlink() or p.read_bytes() != contents for p, contents in publications.items())
                        or tool_path.read_bytes() != tool_bytes):
                    raise ValueError("Collector source/evidence changed during collection")

            guard()
            collection = folder / "completed_review_collection" / uuid.uuid4().hex
            collection.mkdir(parents=True)
            (collection / "state.before.json").write_bytes(frozen[state_path])
            (collection / "checkpoint.before.json").write_bytes(frozen[checkpoint_path])
            (collection / "collector_tool.py.source").write_bytes(tool_bytes)
            receipt = {"schema_version": 1, "operation": "collect_existing_completed_host_review",
                       "tool": str(tool_path), "tool_sha256": tool_sha, "target_worktree": str(target),
                       "controller_pid": controller_pid, "controller_ps": {"argv": ps.args, "exit_code": ps.returncode,
                       "stdout": ps.stdout, "stderr": ps.stderr}, "exclusive_original_controller_lock": str(folder / "lock"),
                       "request_hash": request["request_hash"], "request_nonce": request["nonce"],
                       "request_sha256": hashlib.sha256(frozen[request_path]).hexdigest(),
                       "response_sha256": hashlib.sha256(frozen[response_path]).hexdigest(),
                       "source_hash": state["source_hash"], "collected_at": time.time(), "new_calls": 0,
                       "new_workers": 0, "new_checks": 0, "original_controller_did_not_consume": True}
            save(collection / "receipt.json", receipt)
            publications.update({collection / "receipt.json": serialized(receipt),
                                 collection / "collector_tool.py.source": tool_bytes,
                                 collection / "state.before.json": frozen[state_path],
                                 collection / "checkpoint.before.json": frozen[checkpoint_path]})
            meta = {"kind": "actual_host_codex_agent", "request_hash": request["request_hash"], "role": "review",
                    "exit_code": 0, "timed_out": False, "agent_id": response["agent_id"], "skills": request["skills"],
                    "response_sha256": receipt["response_sha256"], "lease_status": "completed",
                    "recovered_completed_response": True, "original_controller_seconds": "not_observed",
                    "collection_receipt": str(collection / "receipt.json"),
                    "collection_receipt_sha256": hashlib.sha256((collection / "receipt.json").read_bytes()).hexdigest()}
            if "source_inputs" in request:
                meta["source_inputs"] = request["source_inputs"]
            guard()
            try:
                publications.update({call_dir / "result.json": serialized(result),
                                     call_dir / "invocation.json": serialized(meta)})
                save(call_dir / "result.json", result)
                save(call_dir / "invocation.json", meta)
                guard()
                _verify_invocation(call_dir, "review", "invoke_host")
                _independent_reviewer(attempt, call_dir, folder, m)
                guard()
                record["roles"]["review"] = record["result"] = result
                record.setdefault("role_directories", {})["review"] = "review"
                state.pop("active_call")
                state.pop("error", None)
                _checkpoint(entry, record, checkpoint["before"], "quality", state, state_path, attempt)
                guard(finalizing=True)
                published_checkpoint = checkpoint_path.read_bytes()
                # Reuse original finalization, but the whole operation remains
                # provisional until all original inputs pass the final guard.
                def no_new_worker(*unused):
                    raise RuntimeError("Completed review collector cannot dispatch any new worker")
                no_new_worker.__name__ = "invoke_host"
                state = _run_locked(m, folder, no_new_worker)
                publications.update({state_path: serialized(state), checkpoint_path: published_checkpoint})
                guard(finalizing=True)
                if (checkpoint_path.read_bytes() != published_checkpoint
                        or quality.read_json(state_path) != state or state["source_hash"] != expected_source):
                    raise ValueError("Collector final state/checkpoint changed during finalization")
                validate_restored_budget(m, state, folder)
                validate_restored_completion(m, state, folder)
                _restore_checkpoint(task, {"rounds": 1, "checkpoint": {
                    "path": str(checkpoint_path), "sha256": hashlib.sha256(published_checkpoint).hexdigest()}},
                    folder, worker_mode="invoke_host")
                _verify_invocation(call_dir, "review", "invoke_host")
                publications[collection / "state.after.json"] = serialized(state)
                save(collection / "state.after.json", state)
                # Linearization point: all original inputs, lease and exact
                # published outputs are valid under the exclusive lock here.
                # Changes by external writers after this return are not covered.
                guard(finalizing=True)
                return state
            except BaseException as error:
                # Guard failures even inside original finalization roll back
                # this transaction's state/checkpoint, never external source or
                # response changes. Keep provisional bytes for investigation.
                for path in controller_outputs:
                    if path.is_file():
                        (collection / ("rejected_" + path.name)).write_bytes(path.read_bytes())
                    temporary = path.with_name(path.name + ".collector-rollback.tmp")
                    temporary.write_bytes(frozen[path])
                    temporary.replace(path)
                for name in ("result.json", "invocation.json"):
                    path = call_dir / name
                    if path.is_file():
                        path.replace(collection / ("rejected_" + name))
                after = collection / "state.after.json"
                if after.exists():
                    after.replace(collection / "rejected_state.after.json")
                save(collection / "failure.json", {"status": "rejected_and_rolled_back", "error": str(error),
                                                   "original_calls": 2, "new_calls": 0})
                raise


def current_region_validation():
    # Workers may repair these contracts between rounds. A normal import here
    # would keep the rejected first-round validator alive in this controller.
    contracts = runpy.run_path(str(ROOT / "tools/level_design_contracts.py"))
    design = runpy.run_path(str(ROOT / "tools/level_design.py"))
    return (contracts["validate_region_production_proof"],
            design["source_files"], design["engine_log_matches"])


def visual_capture_admission(record, g2_media, evidence, reviewer_identity=None):
    """Consume existing native capture and pixel-review contracts, never suffix claims."""
    import visual_director as visual
    from PIL import Image
    ref = record.get("visual_capture")
    if not isinstance(ref, dict):
        raise ValueError("Golden requires visual_capture receipt and pixel review attestation")
    def bound(item):
        if not isinstance(item, dict):
            raise ValueError("Missing visual capture path/hash")
        path = quality.local_file(ROOT, item.get("path"))
        if hashlib.sha256(path.read_bytes()).hexdigest() != item.get("sha256"):
            raise ValueError("Visual capture/attestation hash changed")
        return path
    report, data = visual.load_capture(bound(ref))
    if report["source_before"] != visual.sources(report.get("request", {}).get("capture_script")):
        raise ValueError("Golden capture does not match current production sources")
    if data.get("route_reached") is not True or data.get("outcome") != "route_target_reached":
        raise ValueError("Golden capture route is not complete")
    known_frames = {(item["path"], item["sha256"]) for item in report["video_frames"]}
    movie = report["movie"]
    for eid in g2_media:
        item = evidence[eid]
        binding = (item.get("path"), item.get("sha256"))
        if item["kind"] == "screenshot":
            if binding not in known_frames:
                raise ValueError("G2 screenshot is not an actual frame from this capture")
            with Image.open(bound(item)) as image:
                image.verify()
        elif binding != (movie["path"], movie["sha256"]):
            raise ValueError("G2 video is not this native capture movie")
    actual = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(bound(movie))], timeout=30))
    def streams(media):
        video = next(item for item in media["streams"] if item["codec_type"] == "video")
        audio = next(item for item in media["streams"] if item["codec_type"] == "audio")
        return (video["width"], video["height"], video["avg_frame_rate"], int(video["nb_frames"]), int(audio["sample_rate"]), audio["channels"])
    if streams(actual) != streams(report["media"]):
        raise ValueError("Actual movie streams differ from native receipt/normal-speed coverage")
    review = quality.read_json(bound(ref.get("review_attestation")))
    attestation = visual.validate_review(review, report)
    observed = {(item["path"], item["sha256"]) for item in attestation["observed_frames"]}
    screenshots = {(evidence[eid].get("path"), evidence[eid].get("sha256")) for eid in g2_media if evidence[eid]["kind"] == "screenshot"}
    indices = {item["video_frame_index_zero_based"] for item in attestation["observed_frames"]}
    available = {item["video_frame_index_zero_based"] for item in report["video_frames"]}
    watched = review.get("observed_movie", {})
    if (not screenshots <= observed or len(indices) < 2 or not {min(available), max(available)} <= indices
            or not isinstance(watched, dict) or (watched.get("path"), watched.get("sha256")) != (movie["path"], movie["sha256"])
            or watched.get("normal_speed") is not True or watched.get("route_complete") is not True
            or not all(isinstance(review.get(key), str) and review[key].strip() for key in ("review_method", "limits"))):
        raise ValueError("Golden requires normal-speed movie evidence, full sampled time span, all G2 images and honest review method/limits")
    reviewers = [item for item in evidence.values() if item.get("kind") == "review" and item.get("verdict") == "ACCEPT"
                 and g2_media <= set(item.get("reviewed_evidence", []))]
    if (attestation["verdict"] != "ACCEPT" or not any(item.get("reviewer") == attestation["reviewer"] for item in reviewers)
            or (reviewer_identity is not None and attestation["reviewer"] != reviewer_identity)):
        raise ValueError("Pixel attestation/card does not match the current independent review lease")
    return attestation["reviewer"]


def actual_reviewer_identity(directory):
    meta = quality.read_json(directory / "invocation.json")
    if meta.get("agent_id"):
        return meta["agent_id"]
    threads = meta.get("thread_ids", [])
    if len(threads) == 1:
        return threads[0]
    raise ValueError("Golden acceptance requires the actual independent reviewer identity")


def check_task_quality(task, *, reviewer_identity=None):
    completion = task.get("completion", "scope" if task.get("read_only") else "content")
    if completion == "scope":
        return {"scope_complete": True, "content_complete": False, "completion": completion}
    record = quality.read_json(quality.local_file(ROOT, task["quality_record"]))
    acceptance = quality.validate_record(record, root=ROOT)
    if task.get("mechanism_review", False):
        from level_design_contracts import validate_mechanism_comparisons
        problems = validate_mechanism_comparisons(record)
        acceptance["errors"].extend(problems)
        if problems: acceptance["task_complete"] = False
    if task.get("region_proof"):
        validate_region_production_proof, source_files, engine_log_matches = current_region_validation()
        contract = task["region_proof"]
        problems = []
        proofs = record.get("region_proofs", [])
        matched = False
        for ref in proofs:
            try:
                capture = quality.local_file(ROOT, ref["path"])
                if hashlib.sha256(capture.read_bytes()).hexdigest() != ref["sha256"]:
                    raise ValueError("Region proof capture hash mismatch")
                data = quality.read_json(capture)
                if data.get("proof_kind") != contract["kind"]:
                    continue
                problems.extend(validate_region_production_proof(data, contract))
                receipt_path = capture.with_suffix(".invocation.json")
                receipt = quality.read_json(receipt_path)
                log = capture.with_suffix(".log")
                sources = source_files(ROOT)
                command = receipt.get("command", [])
                if (receipt.get("scope") != "actual_godot_process" or type(receipt.get("exit_code")) is not int
                        or receipt["exit_code"] != 0 or receipt.get("capture") != str(capture.relative_to(ROOT))
                        or receipt.get("capture_sha256") != ref["sha256"] or receipt.get("source_files") != sources
                        or receipt.get("source_commit") != data.get("source_commit")
                        or data.get("consumer") not in sources
                        or receipt.get("log_sha256") != hashlib.sha256(log.read_bytes()).hexdigest()
                        or command[:2] != ["bash", "tools/godot.sh"] or "--script" not in command
                        or command[command.index("--script") + 1] not in sources):
                    problems.append("Region proof lacks current actual Godot process/consumer receipt")
                text = log.read_text()
                marker = f"REGION PRODUCTION: {data.get('assertions')} assertions, 0 failures"
                if marker not in text.splitlines() or not engine_log_matches(data.get("engine"), text) or re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:", text):
                    problems.append("Region proof native log has no valid completion")
                matched = True
            except (KeyError, ValueError, OSError, IndexError) as error:
                problems.append("Invalid region proof: " + str(error))
        if not matched:
            problems.append("Missing region-specific native proof; shared checks cannot grant admission")
        acceptance["errors"].extend(problems)
        if problems:
            acceptance["task_complete"] = False
    content_hash = digest({p: h for p, h in snapshot().items() if not p.startswith("docs/quality/records/")})
    expected_id = task.get("quality_task_id", task["id"])
    if record["task_id"] != expected_id or record.get("production_snapshot") != content_hash:
        acceptance["errors"].append("Quality record lacks current production_snapshot/task binding")
        acceptance["task_complete"] = False
    complete = acceptance["task_complete"]
    if completion == "stage":
        gates = task["required_gates"]
        complete = (not acceptance["errors"] and acceptance["verdict"] != "REJECT"
                    and bool(record["deliverables"]) and bool(record["affected_paths"])
                    and all(record["gates"][gate]["status"] == "passed" for gate in gates)
                    and all(any(c.get("gate") == gate and c.get("status") == "passed" for c in record["criteria"]) for gate in gates)
                    and not any(c.get("status") == "proposed" for c in record["creative_decisions"]))
    visual_admitted = None
    if task.get("requires_visual_admission"):
        evidence = {item["id"]: item for item in record.get("evidence", [])}
        g2_media = {eid for eid in record.get("gates", {}).get("G2", {}).get("evidence", [])
                    if evidence.get(eid, {}).get("kind") in {"screenshot", "video"}}
        review_dimension = record.get("dimensions", {}).get("independent_review", {})
        reviews = [evidence.get(eid, {}) for eid in review_dimension.get("evidence", [])]
        visual_admitted = (record.get("gates", {}).get("G2", {}).get("status") == "passed"
            and {evidence[eid]["kind"] for eid in g2_media} == {"screenshot", "video"}
            and review_dimension.get("status") == "passed"
            and any(review.get("kind") == "review" and review.get("verdict") == "ACCEPT"
                    and review.get("independent") is True and review.get("reviewer") not in [record.get("owner"), *review.get("implementers", [])]
                    and bool(review.get("independence_basis")) and isinstance(review.get("reviewed_evidence"), list)
                    and all(isinstance(eid, str) for eid in review["reviewed_evidence"])
                    and g2_media <= set(review["reviewed_evidence"])
                    for review in reviews))
        visual_reviewer = None
        if visual_admitted:
            try:
                visual_reviewer = visual_capture_admission(record, g2_media, evidence, reviewer_identity)
            except (ValueError, OSError, KeyError, TypeError, StopIteration, subprocess.SubprocessError) as error:
                visual_admitted = False
                acceptance["errors"].append("Golden native visual evidence: " + str(error))
        if not visual_admitted:
            acceptance["errors"].append("Golden expansion requires G2 screenshot/video and independent ACCEPT review of those media")
            complete = False
    return {"scope_complete": bool(complete), "content_complete": bool(complete and acceptance["task_complete"] and completion == "content"),
            "completion": completion, "quality": acceptance, "visual_admission_passed": visual_admitted,
            "visual_reviewer_identity": visual_reviewer if task.get("requires_visual_admission") else None}


def validate_restored_budget(m, state, folder):
    """Reject edited counters; allocated role directories consume the budget."""
    calls = state.get("calls")
    if type(calls) is not int or not 0 <= calls <= m["max_calls"]:
        raise ValueError("Restored calls must be a nonnegative integer within max_calls")
    tasks = state.get("tasks")
    task_ids = {task["id"] for task in m["tasks"]}
    if not isinstance(tasks, dict) or not set(tasks) <= task_ids:
        raise ValueError("Restored task counters do not match the mission")
    for entry in tasks.values():
        rounds = entry.get("rounds") if isinstance(entry, dict) else None
        if type(rounds) is not int or not 0 <= rounds <= m["max_rounds"]:
            raise ValueError("Restored rounds must be a nonnegative integer within max_rounds")
    allocated = []
    for path in folder.glob("*/*/*"):
        if not re.fullmatch(r"(?:implement|review)(?:_retry_[1-9]\d*)?", path.name):
            continue
        if not path.parent.name.isdecimal():
            raise ValueError("Allocated worker directory has a malformed round")
        task_id, round_id = path.parent.parent.name, int(path.parent.name)
        if (not path.is_dir() or any(p.is_symlink() for p in (path, path.parent, path.parent.parent))
                or task_id not in tasks or path.parent.name != str(round_id)
                or not 1 <= round_id <= tasks[task_id]["rounds"]):
            raise ValueError("Allocated worker directory disagrees with restored task/round counters")
        allocated.append(path)
    if calls != len(allocated):
        raise ValueError("Restored calls do not equal allocated worker role directories")
    for task in m["tasks"]:
        if sum(path.parent.parent.name == task["id"] for path in allocated) > task.get("max_calls", m["max_calls"]):
            raise ValueError("Restored task calls exceed its bounded direction budget")


def invocation_identities(metadata):
    identities = set()
    agent = metadata.get("agent_id")
    if agent is not None:
        if not isinstance(agent, str) or not agent:
            raise ValueError("Malformed invocation agent identity")
        identities.add(("agent", agent))
    threads = metadata.get("thread_ids", [])
    if not isinstance(threads, list) or any(not isinstance(t, str) or not t for t in threads):
        raise ValueError("Malformed invocation thread identity")
    identities.update(("thread", thread) for thread in threads)
    return identities


def validate_restored_completion(m, state, folder):
    """A saved completion must bind complete task history to actual role results."""
    entries = state["tasks"]
    if state.get("status") == "complete" and any(
            entries.get(task["id"], {}).get("status") != "complete" for task in m["tasks"]):
        raise ValueError("Restored complete mission lacks completed declared tasks")
    completed = []
    for task in m["tasks"]:
        entry = entries.get(task["id"], {})
        if entry.get("status") != "complete":
            continue
        creative_direction_input(task)
        spatial_experiment_input(task)
        if any(entries.get(dep, {}).get("status") != "complete" for dep in task.get("depends_on", [])):
            raise ValueError("Restored complete task has an incomplete dependency")
        history = entry.get("history")
        if (not isinstance(history, list) or not history
                or any(not isinstance(item, dict) or type(item.get("round")) is not int for item in history)
                or [item["round"] for item in history] != list(range(1, entry["rounds"] + 1))):
            raise ValueError("Restored complete task has incomplete round history")
        last = history[-1]
        attempt = folder / task["id"] / str(last["round"])
        if last.get("evidence") != str(attempt):
            raise ValueError("Restored completion evidence does not match its task/round")
        roles = last.get("roles")
        if not isinstance(roles, dict) or set(roles) != {"implement", "review"}:
            raise ValueError("Restored completion lacks implementation and independent review")
        for role, expected in (("implement", "ready_for_review"), ("review", "accept")):
            result = validate_result(roles[role], role)
            directory = last.get("role_directories", {}).get(role, role)
            if not isinstance(directory, str) or not re.fullmatch(role + r"(?:_retry_[1-9]\d*)?", directory):
                raise ValueError("Restored role result directory is invalid")
            path = attempt / directory / "result.json"
            if result["status"] != expected or not path.is_file() or path.is_symlink():
                raise ValueError("Restored completion lacks an accepted actual role result")
            if quality.read_json(path) != result:
                raise ValueError("Restored completion role result differs from saved worker response")
        if last.get("result") != roles["review"]:
            raise ValueError("Restored completion does not match its review verdict")
        checks = last.get("checks")
        if (not isinstance(checks, list) or any(not isinstance(check, dict) for check in checks)
                or [check.get("id") for check in checks] != task["checks"]
                or any(check.get("status") != "passed" for check in checks)):
            raise ValueError("Restored completion lacks all declared passed checks")
        acceptance = last.get("quality")
        if task.get("requires_visual_admission") and state.get("worker_mode") in {"invoke", "invoke_host"}:
            directory = attempt / last.get("role_directories", {}).get("review", "review")
            if not isinstance(acceptance, dict) or acceptance.get("visual_reviewer_identity") != actual_reviewer_identity(directory):
                raise ValueError("Restored visual admission differs from the actual review lease")
        if task.get("requires_visual_admission") and (not isinstance(acceptance, dict) or acceptance.get("visual_admission_passed") is not True):
            raise ValueError("Restored golden lacks independent G2 visual admission")
        if not isinstance(acceptance, dict) or acceptance.get("scope_complete") is not True:
            raise ValueError("Restored completion lacks scope quality acceptance")
        if not entry.get("completion_checkpoint"):
            raise ValueError("Restored completion lacks bound final phase checkpoint")
        checkpoint = _restore_checkpoint(task, entry, folder, reference="completion_checkpoint", verify_source=False,
                                         worker_mode=state.get("worker_mode"))
        if checkpoint["phase"] != "quality" or any(
                checkpoint["round_record"].get(key) != last.get(key)
                for key in ("round", "evidence", "roles", "checks", "result", "role_directories")):
            raise ValueError("Restored completion differs from its final checkpoint")
        review_dir = attempt / last.get("role_directories", {}).get("review", "review")
        try:
            _independent_reviewer(attempt, review_dir, folder, m)
        except RuntimeError as error:
            raise ValueError("Restored completion independent invocation failed: " + str(error)) from error
        completed.append(task)
    if state.get("status") == "complete":
        # Earlier design stages have historical source snapshots: subsequent
        # authorized implementation can legitimately change them. Revalidate
        # the final completed scope against the current source, not old stages.
        acceptance = check_task_quality(completed[-1]) if completed else {}
        if acceptance.get("scope_complete") is not True:
            raise ValueError("Restored final completion no longer meets current scope quality")
        if state.get("content_complete") is not acceptance.get("content_complete", False):
            raise ValueError("Restored content completion exceeds current scope quality")


def _checkpoint(entry, record, before, phase, state, state_path, attempt):
    """Commit a phase before allocating its successor; no accepted work is replayed."""
    metadata = {}
    for role in record["roles"]:
        path = attempt / record.get("role_directories", {}).get(role, role) / "invocation.json"
        if path.is_file():
            metadata[role] = hashlib.sha256(path.read_bytes()).hexdigest()
    check_logs = {c["id"]: hashlib.sha256((attempt / (c["id"] + ".log")).read_bytes()).hexdigest()
                  for c in record["checks"] if (attempt / (c["id"] + ".log")).is_file()}
    data = {"schema_version": 1, "phase": phase, "round_record": record,
            "role_metadata": metadata, "check_logs": check_logs,
            "before": before, "source_hash": state["source_hash"]}
    path = attempt / "checkpoint.json"
    save(path, data)
    entry["checkpoint"] = {"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    state["source_hash"] = data["source_hash"]
    save(state_path, state)


def _verify_invocation(call_dir, role, worker_mode=None):
    path = call_dir / "invocation.json"
    real_mode = worker_mode in {"invoke", "invoke_host"}
    if not path.is_file():
        if real_mode:
            raise ValueError("Real worker checkpoint lacks invocation metadata")
        return
    meta = quality.read_json(path)
    kind = meta.get("kind")
    if real_mode and kind != ("actual_host_codex_agent" if worker_mode == "invoke_host" else "actual_codex_exec"):
        raise ValueError("Restored invocation kind does not match real worker transport")
    if kind not in {"actual_host_codex_agent", "actual_codex_exec"}:
        return  # Explicit unit-test workers are not evidence of actual execution.
    invocation_identities(meta)
    if meta.get("exit_code") != 0 or type(meta.get("exit_code")) is not int or meta.get("timed_out") is not False or meta.get("role") != role:
        raise ValueError("Restored real invocation did not successfully complete this role")
    if kind == "actual_host_codex_agent":
        request = quality.read_json(call_dir / "host_request.json")
        response_path = call_dir / "host_response.json"
        response = quality.read_json(response_path)
        if meta.get("source_inputs") != request.get("source_inputs"):
            raise ValueError("Restored creative input hashes differ from bound request")
        if (not re.fullmatch(r"/[A-Za-z0-9_/-]+", str(meta.get("agent_id", "")))
                or meta.get("lease_status") != "completed" or (call_dir / "lease_revoked.json").exists()
                or request.get("request_hash") != digest({k:v for k,v in request.items() if k != "request_hash"})
                or meta.get("request_hash") != request.get("request_hash")
                or meta.get("response_sha256") != hashlib.sha256(response_path.read_bytes()).hexdigest()
                or any(response.get(key) != request.get(key) for key in ("schema_version", "request_hash", "task_id", "attempt", "role"))
                or response.get("agent_id") != meta.get("agent_id")
                or response.get("result") != quality.read_json(call_dir / "result.json")):
            raise ValueError("Restored host invocation lease/response/identity binding failed")
    else:
        events_path = call_dir / "events.jsonl"
        events = []
        for line in events_path.read_text().splitlines():
            try:
                event = json.loads(line)
            except ValueError:
                continue
            if isinstance(event, dict):
                events.append(event)
        if (meta.get("turn_completed") is not True or len(meta.get("thread_ids", [])) != 1
                or meta.get("event_errors") or meta.get("launch_error")
                or meta.get("events_sha256") != hashlib.sha256(events_path.read_bytes()).hexdigest()
                or [e.get("thread_id") for e in events if e.get("type") == "thread.started"] != meta["thread_ids"]
                or not any(e.get("type") == "turn.completed" for e in events)
                or any(e.get("type") in {"error", "turn.failed"} for e in events)):
            raise ValueError("Restored CLI invocation lacks successful independent turn completion")


def _restore_checkpoint(task, entry, folder, *, reference="checkpoint", verify_source=True, worker_mode=None):
    ref = entry[reference]
    path = folder / task["id"] / str(entry["rounds"]) / "checkpoint.json"
    if (ref.get("path") != str(path) or path.is_symlink() or not path.is_file()
            or ref.get("sha256") != hashlib.sha256(path.read_bytes()).hexdigest()):
        raise ValueError("Checkpoint bytes/path changed; cannot recover stage")
    data = quality.read_json(path)
    record = data["round_record"]
    if (verify_source and data["source_hash"] != digest(snapshot())) or record["round"] != entry["rounds"]:
        raise ValueError("Checkpoint source/round changed; revalidate in a new evidence directory")
    if data["phase"] not in {"implement", "checks", "review", "quality"}:
        raise ValueError("Unknown checkpoint phase")
    if worker_mode in {"invoke", "invoke_host"} and (
            set(data.get("role_metadata", {})) != set(record["roles"])
            or set(data.get("check_logs", {})) != {c["id"] for c in record["checks"]}):
        raise ValueError("Real checkpoint lacks complete invocation/check-log bindings")
    for role, result in record["roles"].items():
        validate_result(result, role)
        directory = record.get("role_directories", {}).get(role, role)
        if not isinstance(directory, str) or not re.fullmatch(role + r"(?:_retry_[1-9]\d*)?", directory):
            raise ValueError("Checkpoint role evidence directory is invalid")
        result_path = path.parent / directory / "result.json"
        if result_path.is_symlink() or not result_path.is_file() or quality.read_json(result_path) != result:
            raise ValueError("Checkpoint role result changed")
        if role in data.get("role_metadata", {}):
            metadata = result_path.parent / "invocation.json"
            if not metadata.is_file() or metadata.is_symlink() or hashlib.sha256(metadata.read_bytes()).hexdigest() != data["role_metadata"][role]:
                raise ValueError("Checkpoint invocation metadata changed")
        try:
            _verify_invocation(result_path.parent, role, worker_mode)
        except (OSError, KeyError, TypeError) as error:
            raise ValueError("Checkpoint invocation evidence missing/malformed") from error
    for check, expected in data.get("check_logs", {}).items():
        log = path.parent / (check + ".log")
        if not log.is_file() or log.is_symlink() or hashlib.sha256(log.read_bytes()).hexdigest() != expected:
            raise ValueError("Checkpoint harness log changed")
        result = next((c for c in record["checks"] if c["id"] == check), {})
        text = log.read_text(errors="replace")
        if result.get("status") == "passed" and (result.get("exit_code") != 0
                or not re.search(harness.load_manifest()["checks"][check]["success_pattern"], text, re.MULTILINE)
                or re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script", text)):
            raise ValueError("Checkpoint harness log has no successful completion")
    checks = record["checks"]
    if [c.get("id") for c in checks] != task["checks"][:len(checks)]:
        raise ValueError("Checkpoint checks differ from declared order")
    if (data["phase"] == "review" or "review" in record["roles"]) and (len(checks) != len(task["checks"]) or any(c.get("status") != "passed" for c in checks)):
        raise ValueError("Checkpoint lacks passed checks before review")
    return data


def _recover_call(state, folder):
    active = state["active_call"]
    if not state["tasks"].get(active.get("task_id"), {}).get("checkpoint"):
        raise ValueError("Interrupted legacy call has no verified phase checkpoint; use new evidence")
    call_dir = Path(active["evidence"])
    expected = folder / active["task_id"] / str(active["round"]) / call_dir.name
    if call_dir != expected or call_dir.is_symlink() or not call_dir.is_dir():
        raise ValueError("Interrupted call evidence path is invalid")
    request_path = call_dir / "host_request.json"
    if not request_path.is_file():
        raise ValueError("Only inspected host leases support interrupted recovery; CLI requires new evidence")
    request = quality.read_json(request_path)
    if request.get("request_hash") != digest({k: v for k, v in request.items() if k != "request_hash"}):
        raise ValueError("Interrupted host request hash changed")
    if time.time() < request["expires_at"]:
        cancellation = call_dir / "host_cancellation.json"
        receipt = quality.read_json(cancellation) if cancellation.is_file() else {}
        evidence = Path(receipt.get("host_evidence", ""))
        if (receipt.get("request_hash") != request["request_hash"] or receipt.get("cancelled") is not True
                or not re.fullmatch(r"/[A-Za-z0-9_/-]+", receipt.get("agent_id", ""))
                or not evidence.is_file() or evidence.is_symlink() or not evidence.stat().st_size):
            raise ValueError("Active lease requires actual host interruption receipt before recovery")
    save(call_dir / "lease_revoked.json", {"request_hash": request["request_hash"],
         "revoked_at": time.time(), "reason": "Explicit interrupted recovery; consumed invocation retained"})
    state.setdefault("recoveries", []).append({**active, "request_hash": request["request_hash"],
                                                "recovered_at": time.time()})
    state.pop("active_call")
    state.pop("error", None)
    state["status"] = "running"
    state["tasks"][active["task_id"]]["status"] = "pending"


def _independent_reviewer(attempt, call_dir, folder, m):
    metas = [quality.read_json(attempt / r / "invocation.json") for r in ("implement", "review")
             if (attempt / r / "invocation.json").exists()]
    if len(metas) == 2:
        actors = [meta.get("agent_id") or meta.get("thread_ids") for meta in metas]
        if actors[0] and actors[0] == actors[1]:
            raise RuntimeError("Implementation and independent review used the same agent/session")
    if (call_dir / "invocation.json").exists():
        reviewer = invocation_identities(quality.read_json(call_dir / "invocation.json"))
        task_ids = {item["id"] for item in m["tasks"]}
        for previous in folder.glob("*/*/implement*/invocation.json"):
            if previous.parents[2].name in task_ids and previous.parents[1].name.isdecimal():
                if reviewer & invocation_identities(quality.read_json(previous)):
                    raise RuntimeError("Reviewer previously implemented content in this mission; independent review required")


def task_calls(task, folder):
    """Allocated failed/interrupted calls still consume this direction's limit."""
    return sum(1 for path in (folder / task["id"]).glob("*/*")
               if path.is_dir() and re.fullmatch(r"(?:implement|review)(?:_retry_[1-9]\d*)?", path.name))


def _call_with_retries(task, m, role, attempt, feedback, state, state_path, worker):
    limit = m.get("transport_retry", {}).get("max_retries", 0)
    existing = [p for p in attempt.iterdir() if p.is_dir() and
                re.fullmatch(role + r"(?:_retry_[1-9]\d*)?", p.name)]
    index = len(existing)
    # Explicit recovery allocates a new role directory even without automatic retries.
    automatic = 0
    while True:
        if (state["calls"] >= m["max_calls"]
                or task_calls(task, state_path.parent) >= task.get("max_calls", m["max_calls"])):
            return None, None
        creative_direction_input(task)
        spatial_experiment_input(task)
        name = role if index == 0 else role + "_retry_" + str(index)
        call_dir = attempt / name
        call_dir.mkdir()
        state["calls"] += 1
        state["source_hash"] = digest(snapshot())
        state["active_call"] = {"task_id": task["id"], "round": int(attempt.name),
                                "role": role, "evidence": str(call_dir)}
        save(state_path, state)
        frozen = snapshot()
        try:
            result = worker(task, m, role, call_dir, feedback)
            creative_direction_input(task)
            spatial_experiment_input(task)
            return result, call_dir
        except Exception as error:
            meta_path = call_dir / "invocation.json"
            meta = quality.read_json(meta_path) if meta_path.is_file() else {}
            failure = meta.get("failure_kind")
            if failure not in {"authentication", "transport", "timeout"}:
                raise
            state.pop("active_call", None)
            failed = {"role": role, "evidence": str(call_dir), "failure_kind": failure,
                      "error": str(error), "source_hash": digest(snapshot())}
            state.setdefault("transport_failures", []).append(failed)
            save(state_path, state)
            if (failure == "authentication" or snapshot() != frozen or automatic >= limit
                    or state["calls"] >= m["max_calls"]
                    or task_calls(task, state_path.parent) >= task.get("max_calls", m["max_calls"])):
                return {"status": "blocked", "summary": "Worker transport stopped: " + failure,
                        "findings": [str(error)]}, call_dir
            delay = min(30, m.get("transport_retry", {}).get("backoff_seconds", 1) * 2 ** automatic)
            failed["retry_delay_seconds"] = delay
            save(state_path, state)
            time.sleep(delay)
            automatic += 1
            index += 1


def native_import_preflight(folder):
    """Materialize only new Godot UID sidecars before creating any worker lease."""
    log = folder / "native_import_preflight.log"
    check = {"argv": ["bash", "tools/godot.sh", "--headless", "--path", ".", "--editor", "--quit"],
             "timeout_seconds": 120, "success_pattern": r"^Godot Engine v4\.7\.2\.stable\.official"}
    record = {"status": "blocked", "check": check, "log": str(log), "started_at_unix": time.time(),
              "before": None, "after": None, "changes": [], "allowed_new_uids": [], "rejected_changes": []}
    try:
        record["before"] = snapshot()
        record["result"] = harness.run_check(check, log, root=ROOT)
    except Exception as error:
        record["error"] = str(error)
        if not log.exists():
            log.write_text(str(error) + "\n")
    finally:
        try:
            record["after"] = snapshot()
            if record["before"] is not None:
                before, after = record["before"], record["after"]
                for name in sorted(set(before) | set(after)):
                    if before.get(name) == after.get(name):
                        continue
                    record["changes"].append({"path": name, "before": before.get(name), "after": after.get(name)})
                    source = name[:-4] if name.endswith(".uid") else ""
                    path = ROOT / name
                    allowed = (name not in before and after.get(name) != "deleted"
                               and Path(source).suffix in {".gd", ".gdshader"}
                               and source in before and before[source] != "deleted" and after.get(source) == before[source]
                               and path.is_file() and not path.is_symlink()
                               and (ROOT / source).is_file() and not (ROOT / source).is_symlink()
                               and re.fullmatch(r"uid://[a-z0-9]+", path.read_text().strip()))
                    record["allowed_new_uids" if allowed else "rejected_changes"].append(name)
                record["engine_log_error"] = bool(log.is_file() and re.search(r"(?m)^\s*(?:ERROR:|SCRIPT ERROR:|Parse Error:|SHADER ERROR:)", log.read_text(errors="replace")))
                if (record.get("result", {}).get("status") == "passed" and record["result"].get("exit_code") == 0
                        and not record["rejected_changes"] and not record["engine_log_error"] and "error" not in record):
                    record["status"] = "passed"
        except Exception as error:
            record["error"] = str(error)
            record["status"] = "blocked"
        record["ended_at_unix"] = time.time()
        record["duration_seconds"] = record["ended_at_unix"] - record["started_at_unix"]
        if log.is_file():
            record["log_sha256"] = hashlib.sha256(log.read_bytes()).hexdigest()
        save(folder / "native_import_preflight.json", record)
    return record


def _run_locked(m, folder, worker, *, recover_interrupted=False, stop_after_phase=None):
    if stop_after_phase not in {None, "implement", "checks"}:
        raise ValueError("stop_after_phase must be implement or checks")
    state_path = folder / "state.json"
    imported = None
    if m.get("native_import_preflight") and not state_path.exists():
        imported = native_import_preflight(folder)
        if imported["status"] != "passed":
            state = {"schema_version": 1, "mission_hash": digest(m),
                     "source_hash": digest(imported["after"]) if imported["after"] is not None else None,
                     "calls": 0, "tasks": {task["id"]: {"status": "blocked", "rounds": 0, "history": []}
                                           for task in m["tasks"]},
                     "status": "blocked", "worker_mode": worker.__name__, "content_complete": False,
                     "infrastructure_blocked": True, "native_import_preflight": imported}
            save(state_path, state)
            return state
    try:
        current = digest(snapshot())
    except OSError as error:
        if state_path.exists():
            # Never overwrite an existing source-bound checkpoint with unknown
            # bytes, nor treat an unreadable resume as the same source.
            raise
        state = {"schema_version": 1, "mission_hash": digest(m), "source_hash": None,
                 "calls": 0, "tasks": {}, "status": "blocked", "worker_mode": worker.__name__,
                 "content_complete": False, "infrastructure_blocked": True,
                 "source_snapshot_error": {"type": type(error).__name__, "error": str(error)}}
        for task in m["tasks"]:
            state["tasks"][task["id"]] = {"status": "blocked", "rounds": 0, "history": [],
                "input_preflight": required_input_preflight(task), "source_snapshot_unknown": True}
        save(state_path, state)
        return state
    state = quality.read_json(state_path) if state_path.exists() else {
        "schema_version": 1, "mission_hash": digest(m), "source_hash": current,
        "calls": 0, "tasks": {}, "status": "running", "worker_mode": worker.__name__,
        "content_complete": False}
    if imported is not None:
        state["native_import_preflight"] = imported
    if state.get("worker_mode", "invoke") != worker.__name__:
        raise ValueError("Worker transport changed; use a new evidence directory")
    if state["mission_hash"] != digest(m) or state["source_hash"] != current:
        raise ValueError("Mission/source changed outside loop; use a new evidence directory and revalidate dependencies")
    validate_restored_budget(m, state, folder)
    validate_restored_completion(m, state, folder)
    for task in m["tasks"]:
        entry = state["tasks"].get(task["id"], {})
        if entry.get("checkpoint"):
            _restore_checkpoint(task, entry, folder, worker_mode=state.get("worker_mode"))
    if recover_interrupted and state.get("active_call"):
        _recover_call(state, folder)
        save(state_path, state)
    elif state["status"] in {"complete", "awaiting_acceptance", "blocked", "budget_exhausted"}:
        return state
    if state.get("active_call"):
        state.update(status="blocked", error="Interrupted worker lease requires inspection; use a new evidence directory or explicit recovery")
        save(state_path, state)
        return state
    state["status"] = "running"
    try:
        for task in m["tasks"]:
            entry = state["tasks"].setdefault(task["id"], {"status": "pending", "rounds": 0, "history": []})
            if entry["status"] in {"complete", "blocked", "awaiting_acceptance", "budget_exhausted", "rethink", "discard"}:
                continue
            missing = [dep for dep in task.get("depends_on", []) if state["tasks"].get(dep, {}).get("status") != "complete"]
            if missing:
                entry.update(status="dependency_blocked", blocked_by=missing)
                continue
            if not entry.get("checkpoint"):
                admission_failed = []
                for dependency in task.get("depends_on", []):
                    contract = next(candidate for candidate in m["tasks"] if candidate["id"] == dependency)
                    if contract.get("requires_visual_admission"):
                        admission = check_task_quality(contract)
                        if not admission.get("scope_complete") or admission.get("visual_admission_passed") is not True:
                            admission_failed.append(dependency)
                if admission_failed:
                    entry.update(status="dependency_blocked", blocked_by=admission_failed, visual_admission_blocked=True)
                    save(state_path, state)
                    continue
            # No role directory or budget is allocated for missing tracked
            # infrastructure. Existing interrupted/finished phases remain under
            # their original checkpoint/recovery contracts.
            if not entry.get("checkpoint"):
                preflight = required_input_preflight(task)
                entry["input_preflight"] = preflight
                if preflight["status"] == "blocked":
                    entry.update(status="blocked", infrastructure_blocked=True)
                    save(state_path, state)
                    continue
            while entry["rounds"] < m["max_rounds"] or entry.get("checkpoint"):
                if entry.get("checkpoint"):
                    checkpoint = _restore_checkpoint(task, entry, folder, worker_mode=state.get("worker_mode"))
                    round_record, before = checkpoint["round_record"], checkpoint["before"]
                    phase = checkpoint["phase"]
                    attempt = folder / task["id"] / str(entry["rounds"])
                else:
                    if (state["calls"] + 2 > m["max_calls"]
                            or task_calls(task, folder) + 2 > task.get("max_calls", m["max_calls"])):
                        entry["status"] = "budget_exhausted"
                        break
                    entry["rounds"] += 1
                    before = snapshot()
                    state["source_hash"] = digest(before)
                    attempt = folder / task["id"] / str(entry["rounds"])
                    attempt.mkdir(parents=True)
                    round_record = {"round": entry["rounds"], "evidence": str(attempt), "roles": {}, "checks": []}
                    phase = "implement"
                    _checkpoint(entry, round_record, before, phase, state, state_path, attempt)
                dependencies = {dep: state["tasks"][dep]["history"] for dep in task.get("depends_on", [])}
                context = feedback_context(task, dependencies, entry["history"])
                if task.get("creative_direction") or task.get("feedback_context") == "compact":
                    full_context = {"dependencies": dependencies, "previous_rounds": entry["history"]}
                    round_record["context_metrics"] = {
                        "historical_full_bytes": len(json.dumps(full_context, ensure_ascii=False).encode()),
                        "historical_delivered_bytes": len(json.dumps(context, ensure_ascii=False).encode()),
                        "unit": "UTF-8 bytes; excludes current role implementation/checks and Skill prompt"}
                checks = round_record["checks"]
                result = round_record["roles"].get("implement")
                if phase == "implement":
                    result, call_dir = _call_with_retries(task, m, "implement", attempt,
                        json.dumps(context, ensure_ascii=False), state, state_path, worker)
                    if result is None:
                        entry["status"] = "budget_exhausted"
                        break
                    after = snapshot()
                    if task.get("read_only") and after != before:
                        raise RuntimeError("Read-only worker modified repository; retained changes require inspection")
                    allowed = task.get("allowed_paths", [])
                    changed = [p for p in set(before) | set(after) if before.get(p) != after.get(p)]
                    if not task.get("read_only") and any(not any(p == a or (a.endswith("/") and p.startswith(a)) for a in allowed) for p in changed):
                        raise RuntimeError("Worker modified paths outside task contract; no automatic rollback")
                    validate_result(result, "implement")
                    state["source_hash"] = digest(after)
                    round_record["roles"]["implement"] = result
                    round_record.setdefault("role_directories", {})["implement"] = call_dir.name
                    save(call_dir / "result.json", result)
                    state.pop("active_call", None)
                    phase = "checks" if result["status"] == "ready_for_review" else "quality"
                    round_record["result"] = result
                    _checkpoint(entry, round_record, before, phase, state, state_path, attempt)
                    if stop_after_phase == "implement" and phase == "checks":
                        state["status"] = "paused"
                        return state
                if phase == "checks":
                    frozen = snapshot()
                    # A resumed failed prefix must not start expensive successors.
                    remaining = [] if any(c["status"] != "passed" for c in checks) else task["checks"][len(checks):]
                    for check in remaining:
                        checks.append({"id": check, **harness.run_check(harness.load_manifest()["checks"][check], attempt / f"{check}.log")})
                        if snapshot() != frozen:
                            raise RuntimeError("Source changed during harness checks; evidence is not fresh")
                        _checkpoint(entry, round_record, before, "checks", state, state_path, attempt)
                        if checks[-1]["status"] != "passed":
                            break
                    if any(c["status"] != "passed" for c in checks):
                        result = {"status": "reject", "summary": "Harness failure; repair required",
                                  "findings": ["Failed check: " + c["id"] for c in checks if c["status"] != "passed"]}
                        phase = "quality"
                    else:
                        phase = "review"
                    round_record["result"] = result
                    _checkpoint(entry, round_record, before, phase, state, state_path, attempt)
                    if stop_after_phase == "checks" and phase == "review":
                        state["status"] = "paused"
                        return state
                if phase == "review":
                    frozen = snapshot()
                    result, call_dir = _call_with_retries(task, m, "review", attempt,
                        json.dumps({**context, "implementation": round_record["roles"]["implement"], "checks": checks}, ensure_ascii=False),
                        state, state_path, worker)
                    if result is None:
                        entry["status"] = "budget_exhausted"
                        break
                    if snapshot() != frozen:
                        raise RuntimeError("Read-only worker modified repository; retained changes require inspection")
                    validate_result(result, "review")
                    _independent_reviewer(attempt, call_dir, folder, m)
                    round_record["roles"]["review"] = result
                    round_record["result"] = result
                    round_record.setdefault("role_directories", {})["review"] = call_dir.name
                    save(call_dir / "result.json", result)
                    state.pop("active_call", None)
                    _checkpoint(entry, round_record, before, "quality", state, state_path, attempt)
                elif phase == "quality":
                    result = round_record.get("result", round_record["roles"].get("review", result))
                round_record["result"] = result
                entry["history"].append(round_record)
                final_checkpoint = entry.pop("checkpoint", None)
                state["source_hash"] = digest(snapshot())
                if result["status"] in {"rethink", "discard"}:
                    entry["status"] = result["status"]
                    entry["preproduction_required"] = result["status"] == "rethink"
                    entry["quarantine_required"] = result["status"] == "discard"
                    round_record["stop_reason"] = ("Creative direction requires pre-production redesign" if result["status"] == "rethink"
                                                   else "Candidate discarded; isolate from production manually before reuse")
                    break
                if result["status"] in {"awaiting_acceptance", "blocked"}:
                    entry["status"] = result["status"]
                    break
                if result["status"] == "accept":
                    if task.get("requires_visual_admission") and state.get("worker_mode") in {"invoke", "invoke_host"}:
                        review_directory = attempt / round_record.get("role_directories", {}).get("review", "review")
                        acceptance = check_task_quality(task, reviewer_identity=actual_reviewer_identity(review_directory))
                    else:
                        acceptance = check_task_quality(task)
                    round_record["quality"] = acceptance
                    if not acceptance["scope_complete"]:
                        entry["status"] = "awaiting_acceptance"
                        break
                    state["content_complete"] = acceptance["content_complete"]
                    entry["status"] = "complete"
                    entry["completion_checkpoint"] = final_checkpoint
                    break
                if (task.get("creative_stagnation_guard", bool(task.get("creative_direction")))
                        and result["status"] in {"rework", "reject"} and "review" in round_record["roles"]):
                    normalize = lambda findings: sorted({re.sub(r"\s+", " ", item).strip() for item in findings if item.strip()})
                    findings = normalize(result["findings"])
                    prior = next((record for record in reversed(entry["history"][:-1]) if "review" in record["roles"]), None)
                    previous = prior["roles"]["review"] if prior else {}
                    if (findings and previous.get("status") in {"rework", "reject"}
                            and findings == normalize(previous.get("findings", []))):
                        entry.update(status="rethink", preproduction_required=True)
                        round_record["creative_stagnation"] = {"normalized_findings": findings, "previous_review_round": prior["round"]}
                        round_record["stop_reason"] = "Repeated independent review findings despite source edits; return to pre-production"
                        break
                if snapshot() == before:
                    entry["status"] = "blocked"
                    round_record["stop_reason"] = "No source progress after rejected round"
                    break
                save(state_path, state)
            if entry["status"] not in {"complete", "blocked", "awaiting_acceptance", "rethink", "discard"}:
                entry["status"] = "budget_exhausted"
            save(state_path, state)
        statuses = {e["status"] for e in state["tasks"].values()}
        state["status"] = ("complete" if statuses == {"complete"} else "blocked" if statuses & {"blocked", "dependency_blocked", "rethink", "discard"}
                           else "budget_exhausted" if "budget_exhausted" in statuses else "awaiting_acceptance")
    except Exception as error:
        state["status"] = "blocked"
        state["error"] = str(error)
        raise
    finally:
        state["source_hash"] = digest(snapshot())
        save(state_path, state)
    return state


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--mission", required=True)
    p.add_argument("--execute", action="store_true", help="Actually invoke Codex; otherwise print plan")
    p.add_argument("--evidence-dir", default="build/verification/production-loop")
    p.add_argument("--worker-mode", choices=["codex", "host"], default="codex",
                   help="codex exec login, or bounded requests handled by the active Codex host")
    p.add_argument("--recover-interrupted", action="store_true",
                   help="Explicitly revoke an expired/cancelled host lease and retry only its unfinished phase")
    p.add_argument("--stop-after-phase", choices=["implement", "checks"],
                   help="Persist a clean phase checkpoint and pause before the next worker call")
    p.add_argument("--collect-completed-review", action="store_true",
                   help="Collect existing live review after vanished controller; one task/round, no new work")
    p.add_argument("--collector-worktree", type=Path,
                   help="Collector-only target registered worktree; frozen target tools remain unchanged")
    p.add_argument("--controller-pid", type=int, help="Collector-only original vanished controller PID")
    args = p.parse_args(argv)
    if args.collect_completed_review:
        if not args.execute or args.worker_mode != "host" or args.recover_interrupted or args.stop_after_phase:
            raise ValueError("Completed-review collection requires --execute --worker-mode host, no retry/pause")
        state = collect_completed_review(args.mission, args.evidence_dir, args.collector_worktree or ROOT,
                                         args.controller_pid)
        print(json.dumps(state, ensure_ascii=False, indent=2))
        return 0 if state["status"] == "complete" else 2
    if args.collector_worktree is not None or args.controller_pid is not None:
        raise ValueError("Collector worktree/PID are only valid with --collect-completed-review")
    mission = quality.read_json(Path(args.mission))
    validate(mission)
    if not args.execute:
        print(json.dumps({"mode": "plan_only", "mission": mission}, ensure_ascii=False, indent=2))
        return 0
    evidence = Path(args.evidence_dir).resolve()
    if not evidence.is_relative_to((ROOT / "build/verification").resolve()):
        raise ValueError("Evidence directory must be inside ignored build/verification")
    state = run(mission, evidence, invoke_host if args.worker_mode == "host" else invoke,
                recover_interrupted=args.recover_interrupted, stop_after_phase=args.stop_after_phase)
    print(json.dumps(state, ensure_ascii=False, indent=2))
    return 0 if state["status"] == "complete" else 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Production loop stopped: {error}", file=sys.stderr)
        sys.exit(1)
