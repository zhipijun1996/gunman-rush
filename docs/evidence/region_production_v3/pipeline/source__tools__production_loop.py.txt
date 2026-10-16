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

import harness
import quality

ROOT = harness.ROOT
RESULT_SCHEMA = {"type": "object", "additionalProperties": False, "properties": {
    "status": {"type": "string", "enum": ["ready_for_review", "accept", "reject", "awaiting_acceptance", "blocked"]},
    "summary": {"type": "string"}, "findings": {"type": "array", "items": {"type": "string"}}},
    "required": ["status", "summary", "findings"]}


def validate_result(result, role):
    allowed = {"ready_for_review", "reject", "awaiting_acceptance", "blocked"} if role == "implement" else {"accept", "reject", "awaiting_acceptance", "blocked"}
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
        for path in t.get("allowed_paths", []) + ([t["quality_record"]] if t.get("quality_record") else []):
            if Path(path).is_absolute() or ".." in Path(path).parts or path in {".", ""}:
                raise ValueError("Task paths must be repository relative")
        for s in t["skills"]:
            quality.local_file(ROOT, f".agents/skills/{s}/SKILL.md")
        for c in t["checks"]:
            if c not in harness.load_manifest()["checks"]:
                raise ValueError(f"Unknown harness check: {c}")
        if not set(t.get("depends_on", [])).issubset(done):
            raise ValueError("Tasks must be topologically ordered; unknown/cyclic dependency")
        if not t.get("read_only", False) and not t.get("quality_record"):
            raise ValueError("Production task must name its quality record")
        completion = t.get("completion", "scope" if t.get("read_only") else "content")
        if completion not in {"scope", "stage", "content"} or (completion == "scope" and not t.get("read_only")):
            raise ValueError("Scope completion is read-only; production requires stage or content")
        if completion in {"stage", "content"} and not t.get("quality_record"):
            raise ValueError("Stage/content completion requires an existing quality record contract")
        if completion == "stage" and (not t.get("required_gates") or any(g not in quality.policy()["gates"] for g in t["required_gates"])):
            raise ValueError("Stage must declare existing required_gates")
        if t.get("quality_task_id", t["id"]) not in [t["id"], *t.get("depends_on", [])]:
            raise ValueError("Quality record must bind this task or a direct completed dependency")
        done.add(t["id"])


def snapshot():
    result = subprocess.run(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                            cwd=ROOT, capture_output=True, check=True, timeout=30)
    return {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() if (ROOT / p).is_file() else "deleted"
            for p in result.stdout.decode().split("\0") if p}


def save(path, data):
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    tmp.replace(path)


def prepare_call(task, mission, role, folder, feedback):
    skill_names = list(dict.fromkeys((["gameplay-reviewer"] if role == "review" else []) + task["skills"]))
    skill_files = [quality.local_file(ROOT, f".agents/skills/{s}/SKILL.md") for s in skill_names]
    skills = "\n\n".join(f"Skill source: {p.relative_to(ROOT)}\n{p.read_text()}" for p in skill_files)
    prompt = (f"Repository mission: {mission['objective']}\nTask: {task['goal']}\nRole: {role}\n"
              f"Mission constraints: {json.dumps(mission.get('constraints', []), ensure_ascii=False)}\n"
              f"Prepared region context and lessons: {json.dumps(mission.get('preparation', {}), ensure_ascii=False)}\n"
              f"Task contract: {json.dumps(task, ensure_ascii=False)}\nPrevious evidence: {feedback}\n"
              "Follow AGENTS.md and these Skills. Do not commit, push, merge, publish or change task scope. "
              "Do not invent user approval, performance evidence or Skill execution. "
              "Stop as awaiting_acceptance for required creative/player/device decisions. "
              "Review must independently inspect and try counterexamples; never edit production files. "
              "Do not launch nested agents or another production loop. The parent owns budgets and harness execution. "
              "Return ready_for_review (never accept) as implementer, accept/reject as reviewer. "
              "Stage completion only addresses required_gates, not content completion; preserve future gates as unverified. "
              "Read-only scope outputs belong in the structured summary/findings; do not edit repository files.\n" + skills)
    (folder / "prompt.txt").write_text(prompt)
    schema = folder / "schema.json"
    schema.write_text(json.dumps(RESULT_SCHEMA))
    output = folder / "result.json"
    return prompt, skill_files, schema, output


def invoke_host(task, mission, role, folder, feedback):
    """Transport one bounded worker call to the current Codex host, not a second loop."""
    prompt, skill_files, _, output = prepare_call(task, mission, role, folder, feedback)
    started = time.monotonic()
    request = {"schema_version": 1, "nonce": uuid.uuid4().hex, "task_id": task["id"],
               "attempt": folder.parent.name, "role": role, "prompt": prompt, "task_contract": task,
               "source_hash": digest(snapshot()), "feedback": feedback,
               "skills": [{"path": str(p.relative_to(ROOT)), "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in skill_files],
               "expires_at": time.time() + mission["call_timeout_seconds"]}
    request["request_hash"] = digest(request)
    request_path = folder / "host_request.json"
    response_path = folder / "host_response.json"
    if request_path.exists() or response_path.exists():
        raise RuntimeError("Host worker lease path already exists; never reuse a prior response")
    save(request_path, request)
    metadata = {"kind": "actual_host_codex_agent", "request_hash": request["request_hash"], "role": role,
                "exit_code": None, "timed_out": False, "agent_id": None, "skills": request["skills"]}

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
        metadata["lease_status"] = "completed" if metadata["exit_code"] == 0 else "expired" if metadata["timed_out"] else "failed"
        save(folder / "invocation.json", metadata)


def invoke(task, mission, role, folder, feedback):
    prompt, skill_files, schema, output = prepare_call(task, mission, role, folder, feedback)
    argv = ["codex", "exec", "--json", "-c", 'approval_policy="never"', "--output-schema", str(schema), "-o", str(output),
            "-C", str(ROOT), "-s", "read-only" if role == "review" or task.get("read_only") else "workspace-write", "-"]
    start = time.monotonic()
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
        metadata = {"argv": argv, "exit_code": process.returncode if process else None,
                                          "seconds": time.monotonic()-start, "kind": "actual_codex_exec",
                                          "role": role, "timed_out": timed_out, "launch_error": launch_error,
                                          "skills": [{"path": str(p.relative_to(ROOT)), "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in skill_files]}
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


def check_task_quality(task):
    completion = task.get("completion", "scope" if task.get("read_only") else "content")
    if completion == "scope":
        return {"scope_complete": True, "content_complete": False, "completion": completion}
    record = quality.read_json(quality.local_file(ROOT, task["quality_record"]))
    acceptance = quality.validate_record(record)
    if task.get("region_proof"):
        from level_design_contracts import validate_region_production_proof
        from level_design import source_files, engine_log_matches
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
    return {"scope_complete": bool(complete), "content_complete": bool(acceptance["task_complete"] and completion == "content"),
            "completion": completion, "quality": acceptance}


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


def _call_with_retries(task, m, role, attempt, feedback, state, state_path, worker):
    limit = m.get("transport_retry", {}).get("max_retries", 0)
    existing = [p for p in attempt.iterdir() if p.is_dir() and
                re.fullmatch(role + r"(?:_retry_[1-9]\d*)?", p.name)]
    index = len(existing)
    # Explicit recovery allocates a new role directory even without automatic retries.
    automatic = 0
    while True:
        if state["calls"] >= m["max_calls"]:
            return None, None
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
                    or state["calls"] >= m["max_calls"]):
                return {"status": "blocked", "summary": "Worker transport stopped: " + failure,
                        "findings": [str(error)]}, call_dir
            delay = min(30, m.get("transport_retry", {}).get("backoff_seconds", 1) * 2 ** automatic)
            failed["retry_delay_seconds"] = delay
            save(state_path, state)
            time.sleep(delay)
            automatic += 1
            index += 1


def _run_locked(m, folder, worker, *, recover_interrupted=False, stop_after_phase=None):
    if stop_after_phase not in {None, "implement", "checks"}:
        raise ValueError("stop_after_phase must be implement or checks")
    state_path = folder / "state.json"
    current = digest(snapshot())
    state = quality.read_json(state_path) if state_path.exists() else {
        "schema_version": 1, "mission_hash": digest(m), "source_hash": current,
        "calls": 0, "tasks": {}, "status": "running", "worker_mode": worker.__name__,
        "content_complete": False}
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
            if entry["status"] in {"complete", "blocked", "awaiting_acceptance", "budget_exhausted"}:
                continue
            missing = [dep for dep in task.get("depends_on", []) if state["tasks"].get(dep, {}).get("status") != "complete"]
            if missing:
                entry.update(status="dependency_blocked", blocked_by=missing)
                continue
            while entry["rounds"] < m["max_rounds"] or entry.get("checkpoint"):
                if entry.get("checkpoint"):
                    checkpoint = _restore_checkpoint(task, entry, folder, worker_mode=state.get("worker_mode"))
                    round_record, before = checkpoint["round_record"], checkpoint["before"]
                    phase = checkpoint["phase"]
                    attempt = folder / task["id"] / str(entry["rounds"])
                else:
                    if state["calls"] + 2 > m["max_calls"]:
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
                context = {"dependencies": dependencies, "previous_rounds": entry["history"]}
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
                    for check in task["checks"][len(checks):]:
                        checks.append({"id": check, **harness.run_check(harness.load_manifest()["checks"][check], attempt / f"{check}.log")})
                        if snapshot() != frozen:
                            raise RuntimeError("Source changed during harness checks; evidence is not fresh")
                        _checkpoint(entry, round_record, before, "checks", state, state_path, attempt)
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
                if result["status"] in {"awaiting_acceptance", "blocked"}:
                    entry["status"] = result["status"]
                    break
                if result["status"] == "accept":
                    acceptance = check_task_quality(task)
                    round_record["quality"] = acceptance
                    if not acceptance["scope_complete"]:
                        entry["status"] = "awaiting_acceptance"
                        break
                    state["content_complete"] = acceptance["content_complete"]
                    entry["status"] = "complete"
                    entry["completion_checkpoint"] = final_checkpoint
                    break
                if snapshot() == before:
                    entry["status"] = "blocked"
                    round_record["stop_reason"] = "No source progress after rejected round"
                    break
                save(state_path, state)
            if entry["status"] not in {"complete", "blocked", "awaiting_acceptance"}:
                entry["status"] = "budget_exhausted"
            save(state_path, state)
        statuses = {e["status"] for e in state["tasks"].values()}
        state["status"] = ("complete" if statuses == {"complete"} else "blocked" if statuses & {"blocked", "dependency_blocked"}
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
    args = p.parse_args(argv)
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
