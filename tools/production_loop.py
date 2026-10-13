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

import harness
import quality

ROOT = harness.ROOT
RESULT_SCHEMA = {"type": "object", "additionalProperties": False, "properties": {
    "status": {"type": "string", "enum": ["ready_for_review", "accept", "reject", "awaiting_acceptance", "blocked"]},
    "summary": {"type": "string"}, "findings": {"type": "array", "items": {"type": "string"}}},
    "required": ["status", "summary", "findings"]}


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


def invoke(task, mission, role, folder, feedback):
    skill_names = ["gameplay-reviewer"] if role == "review" else task["skills"]
    skills = "\n\n".join(quality.local_file(ROOT, f".agents/skills/{s}/SKILL.md").read_text() for s in skill_names)
    prompt = (f"Repository mission: {mission['objective']}\nTask: {task['goal']}\nRole: {role}\n"
              f"Task contract: {json.dumps(task, ensure_ascii=False)}\nPrevious evidence: {feedback}\n"
              "Follow AGENTS.md and these Skills. Do not commit, push, merge, publish or change task scope. "
              "Do not invent user approval, performance evidence or Skill execution. "
              "Stop as awaiting_acceptance for required creative/player/device decisions. "
              "Review must independently inspect and try counterexamples; never edit production files.\n" + skills)
    (folder / "prompt.txt").write_text(prompt)
    schema = folder / "schema.json"
    schema.write_text(json.dumps(RESULT_SCHEMA))
    output = folder / "result.json"
    argv = ["codex", "exec", "--json", "--output-schema", str(schema), "-o", str(output),
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
                import os, signal
                timed_out = True
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
    except OSError as error:
        launch_error = str(error)
        raise
    finally:
        save(folder / "invocation.json", {"argv": argv, "exit_code": process.returncode if process else None,
                                          "seconds": time.monotonic()-start, "kind": "actual_codex_exec",
                                          "timed_out": timed_out, "launch_error": launch_error})
    if timed_out:
        raise RuntimeError("Codex call timed out; partial evidence retained")
    if process.returncode or not output.is_file():
        raise RuntimeError(f"Codex invocation failed (exit {process.returncode})")
    result = quality.read_json(output)
    if result.get("status") not in RESULT_SCHEMA["properties"]["status"]["enum"]:
        raise ValueError("Invalid worker result")
    return result


def run(m, folder, worker=invoke):
    validate(m)
    folder.mkdir(parents=True, exist_ok=True)
    with (folder / "lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return _run_locked(m, folder, worker)


def _run_locked(m, folder, worker):
    state_path = folder / "state.json"
    current = digest(snapshot())
    state = quality.read_json(state_path) if state_path.exists() else {
        "schema_version": 1, "mission_hash": digest(m), "source_hash": current,
        "calls": 0, "tasks": {}, "status": "running"}
    if state["mission_hash"] != digest(m) or state["source_hash"] != current:
        raise ValueError("Mission/source changed outside loop; use a new evidence directory and revalidate dependencies")
    if state["status"] in {"complete", "awaiting_acceptance", "blocked", "budget_exhausted"}:
        return state  # Terminal states never silently retry or relabel acceptance.
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
                feedback = json.dumps(entry["history"][-1:] if entry["history"] else [])
                for role in ["implement", "review"]:
                    if role == "review" and any(c["status"] != "passed" for c in checks):
                        result = {"status": "reject", "summary": "Harness failure; repair required", "findings": checks}
                        break
                    call_dir = attempt / role
                    call_dir.mkdir()
                    state["calls"] += 1
                    state["source_hash"] = digest(snapshot())
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
                    if result["status"] in {"awaiting_acceptance", "blocked"}:
                        break
                    if role == "implement":
                        checks = []
                        for check in task["checks"]:
                            checks.append({"id": check, **harness.run_check(harness.load_manifest()["checks"][check], attempt / f"{check}.log")})
                        feedback = json.dumps({"implementation": result, "checks": checks})
                entry["history"].append({"round": entry["rounds"], "result": result, "evidence": str(attempt)})
                state["source_hash"] = digest(snapshot())
                if result["status"] in {"awaiting_acceptance", "blocked"}:
                    state["status"] = entry["status"] = result["status"]
                    break
                if result["status"] == "accept":
                    if not task.get("read_only"):
                        record = quality.read_json(quality.local_file(ROOT, task["quality_record"]))
                        acceptance = quality.validate_record(record)
                        content_hash = digest({p: h for p, h in snapshot().items() if not p.startswith("docs/quality/records/")})
                        if record["task_id"] != task["id"] or record.get("production_snapshot") != content_hash:
                            acceptance["task_complete"] = False
                            acceptance["blockers"].append("Quality record lacks current production_snapshot/task binding")
                        if not acceptance["task_complete"]:
                            entry["history"][-1]["quality"] = acceptance
                            state["status"] = entry["status"] = "awaiting_acceptance"
                            break
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
    args = p.parse_args(argv)
    mission = quality.read_json(Path(args.mission))
    validate(mission)
    if not args.execute:
        print(json.dumps({"mode": "plan_only", "mission": mission}, ensure_ascii=False, indent=2))
        return 0
    evidence = Path(args.evidence_dir).resolve()
    if not evidence.is_relative_to((ROOT / "build/verification").resolve()):
        raise ValueError("Evidence directory must be inside ignored build/verification")
    state = run(mission, evidence)
    print(json.dumps(state, ensure_ascii=False, indent=2))
    return 0 if state["status"] == "complete" else 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Production loop stopped: {error}", file=sys.stderr)
        sys.exit(1)
