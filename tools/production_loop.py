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
    if not 1 <= m.get("max_calls", 0) <= 100 or not 1 <= m.get("max_rounds", 0) <= 10:
        raise ValueError("Specify bounded max_calls (1..100), max_rounds (1..10)")
    if not 1 <= m.get("call_timeout_seconds", 0) <= 3600:
        raise ValueError("Specify call_timeout_seconds (1..3600)")
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
    try:
        while not response_path.exists():
            if time.monotonic() - started >= mission["call_timeout_seconds"]:
                metadata["timed_out"] = True
                raise RuntimeError("Host Codex worker timed out; lease expired, response cannot be reused")
            time.sleep(0.25)
        response = quality.read_json(response_path)
        fields = {"schema_version", "request_hash", "task_id", "attempt", "role", "agent_id", "result"}
        if not isinstance(response, dict) or set(response) != fields:
            raise ValueError("Invalid host response schema")
        if response["schema_version"] != 1 or any(response[k] != request[k] for k in ("request_hash", "task_id", "attempt", "role")):
            raise ValueError("Host response does not match this task/attempt/role/lease")
        if time.monotonic() - started >= mission["call_timeout_seconds"]:
            metadata["timed_out"] = True
            raise RuntimeError("Host response arrived after its lease expired")
        if not isinstance(response["agent_id"], str) or not re.fullmatch(r"/[A-Za-z0-9_/-]+", response["agent_id"]):
            raise ValueError("Host must identify the actual canonical Codex agent")
        result = validate_result(response["result"], role)
        save(output, result)
        metadata.update(exit_code=0, agent_id=response["agent_id"], response_sha256=hashlib.sha256(response_path.read_bytes()).hexdigest())
        return result
    except Exception as error:
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
        error_text = json.dumps(event_errors).lower()
        metadata["failure_kind"] = "authentication" if any(s in error_text for s in ("unauthorized", "access token", "sign in again")) else "timeout" if timed_out else "worker_error" if event_errors else None
        save(folder / "invocation.json", metadata)
    if timed_out:
        raise RuntimeError("Codex call timed out; partial evidence retained")
    if process.returncode or not output.is_file():
        raise RuntimeError(f"Codex invocation failed (exit {process.returncode}; {metadata['failure_kind'] or 'missing_result'}); see retained events.jsonl")
    if not metadata["turn_completed"] or len(metadata["thread_ids"]) != 1 or event_errors:
        raise RuntimeError("Codex missing successful turn completion or reported an error")
    result = quality.read_json(output)
    return validate_result(result, role)


def run(m, folder, worker=invoke):
    validate(m)
    folder.mkdir(parents=True, exist_ok=True)
    with (folder / "lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return _run_locked(m, folder, worker)


def check_task_quality(task):
    completion = task.get("completion", "scope" if task.get("read_only") else "content")
    if completion == "scope":
        return {"scope_complete": True, "content_complete": False, "completion": completion}
    record = quality.read_json(quality.local_file(ROOT, task["quality_record"]))
    acceptance = quality.validate_record(record)
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


def _run_locked(m, folder, worker):
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
    if state["status"] in {"complete", "awaiting_acceptance", "blocked", "budget_exhausted"}:
        return state  # Terminal states never silently retry or relabel acceptance.
    if state.get("active_call"):
        state.update(status="blocked", error="Interrupted worker lease requires inspection; use a new evidence directory")
        save(state_path, state)
        return state
    try:
        for task in m["tasks"]:
            entry = state["tasks"].setdefault(task["id"], {"status": "pending", "rounds": 0, "history": []})
            if entry["status"] == "complete":
                continue
            if any(state["tasks"].get(dep, {}).get("status") != "complete" for dep in task.get("depends_on", [])):
                state["status"] = "blocked"
                break
            while entry["rounds"] < m["max_rounds"]:
                if state["calls"] + 2 > m["max_calls"]:
                    state["status"] = "budget_exhausted"
                    break
                entry["rounds"] += 1
                before = snapshot()
                attempt = folder / task["id"] / str(entry["rounds"])
                attempt.mkdir(parents=True)
                dependencies = {dep: state["tasks"][dep]["history"] for dep in task.get("depends_on", [])}
                context = {"dependencies": dependencies, "previous_rounds": entry["history"]}
                feedback = json.dumps(context, ensure_ascii=False)
                round_record = {"round": entry["rounds"], "evidence": str(attempt), "roles": {}, "checks": []}
                checks = []
                for role in ["implement", "review"]:
                    if role == "review" and any(c["status"] != "passed" for c in checks):
                        result = {"status": "reject", "summary": "Harness failure; repair required", "findings": ["Failed check: " + c["id"] for c in checks if c["status"] != "passed"]}
                        break
                    call_dir = attempt / role
                    call_dir.mkdir()
                    state["calls"] += 1
                    state["source_hash"] = digest(snapshot())
                    state["active_call"] = {"task_id": task["id"], "round": entry["rounds"], "role": role, "evidence": str(call_dir)}
                    save(state_path, state)  # Crash consumes the call budget; never loses invocation history.
                    frozen = snapshot()
                    result = worker(task, m, role, call_dir, feedback)
                    after = snapshot()
                    if (role == "review" or task.get("read_only")) and after != frozen:
                        raise RuntimeError("Read-only worker modified repository; retained changes require inspection")
                    if role == "implement":
                        allowed = task.get("allowed_paths", [])
                        changed = [p for p in set(before) | set(after) if before.get(p) != after.get(p)]
                        if any(not any(p == a or (a.endswith("/") and p.startswith(a)) for a in allowed) for p in changed):
                            raise RuntimeError("Worker modified paths outside task contract; no automatic rollback")
                    validate_result(result, role)
                    round_record["roles"][role] = result
                    save(call_dir / "result.json", result)
                    state.pop("active_call", None)
                    state["source_hash"] = digest(after)
                    save(state_path, state)
                    if role == "review":
                        metas = [quality.read_json(attempt / r / "invocation.json") for r in ("implement", "review")
                                 if (attempt / r / "invocation.json").exists()]
                        if len(metas) == 2:
                            actors = [meta.get("agent_id") or meta.get("thread_ids") for meta in metas]
                            if actors[0] and actors[0] == actors[1]:
                                raise RuntimeError("Implementation and independent review used the same agent/session")
                    if result["status"] in {"awaiting_acceptance", "blocked"}:
                        break
                    if role == "implement":
                        if result["status"] == "reject":
                            break
                        checks = []
                        for check in task["checks"]:
                            checks.append({"id": check, **harness.run_check(harness.load_manifest()["checks"][check], attempt / f"{check}.log")})
                        if snapshot() != after:
                            raise RuntimeError("Source changed during harness checks; evidence is not fresh")
                        round_record["checks"] = checks
                        feedback = json.dumps({**context, "implementation": result, "checks": checks}, ensure_ascii=False)
                round_record["result"] = result
                entry["history"].append(round_record)
                state["source_hash"] = digest(snapshot())
                if result["status"] in {"awaiting_acceptance", "blocked"}:
                    state["status"] = entry["status"] = result["status"]
                    break
                if result["status"] == "accept":
                    acceptance = check_task_quality(task)
                    entry["history"][-1]["quality"] = acceptance
                    if not acceptance["scope_complete"]:
                        state["status"] = entry["status"] = "awaiting_acceptance"
                        break
                    state["content_complete"] = acceptance["content_complete"]
                    entry["status"] = "complete"
                    break
                if snapshot() == before:
                    state["status"] = entry["status"] = "blocked"
                    entry["history"][-1]["stop_reason"] = "No source progress after rejected round"
                    break
                save(state_path, state)
            if entry["status"] != "complete":
                if state["status"] == "running": state["status"] = "budget_exhausted"
                break
        else:
            state["status"] = "complete"
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
    args = p.parse_args(argv)
    mission = quality.read_json(Path(args.mission))
    validate(mission)
    if not args.execute:
        print(json.dumps({"mode": "plan_only", "mission": mission}, ensure_ascii=False, indent=2))
        return 0
    evidence = Path(args.evidence_dir).resolve()
    if not evidence.is_relative_to((ROOT / "build/verification").resolve()):
        raise ValueError("Evidence directory must be inside ignored build/verification")
    state = run(mission, evidence, invoke_host if args.worker_mode == "host" else invoke)
    print(json.dumps(state, ensure_ascii=False, indent=2))
    return 0 if state["status"] == "complete" else 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Production loop stopped: {error}", file=sys.stderr)
        sys.exit(1)
