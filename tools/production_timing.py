"""Measure real production commands and summarize observed time without invented usage."""
import argparse
import fcntl
import hashlib
import json
import math
import re
from pathlib import Path
import subprocess
import time
import uuid

STAGES = ("model_implementation", "image_generation", "game_integration", "verification",
          "independent_review", "rework", "network_wait", "release")


def union_seconds(intervals):
    total, end = 0.0, None
    for start, stop in sorted(intervals):
        total += max(0, stop - max(start, end if end is not None else start))
        end = max(stop, end if end is not None else stop)
    return total


def validate_event(event):
    if event.get("stage") not in STAGES or not event.get("id") or not event.get("evidence"):
        raise ValueError("Timing event needs stage, id and original evidence")
    start, end = event.get("started_at_unix"), event.get("ended_at_unix")
    if any(type(value) not in (int, float) or not math.isfinite(value) for value in (start, end)) or end < start:
        raise ValueError("Timing event needs finite ordered observed timestamps")
    seconds = event.get("duration_seconds")
    if type(seconds) not in (int, float) or not math.isfinite(seconds) or seconds < 0:
        raise ValueError("Timing event needs observed nonnegative duration")
    return event


def summarize(events, unknown=()):
    unknown = list(unknown)
    for record in unknown:
        seconds = record.get("reported_seconds")
        if type(seconds) in (int, float) and (not math.isfinite(seconds) or seconds < 0):
            raise ValueError("Invalid original reported duration")
    unique = {}
    for event in events:
        validate_event(event)
        if event["id"] in unique and unique[event["id"]] != event:
            raise ValueError("Conflicting duplicate timing event")
        unique[event["id"]] = event
    events = list(unique.values())
    intervals = [(e["started_at_unix"], e["ended_at_unix"]) for e in events]
    measured = union_seconds(intervals)
    stages = {}
    for stage in STAGES:
        selected = [e for e in events if e["stage"] == stage]
        duration_only = [r for r in unknown if r.get("stage") == stage
                         and type(r.get("reported_seconds")) in (int, float)]
        stages[stage] = {"status": "observed" if selected else "unknown",
                         "events": len(selected), "summed_command_seconds": sum(e["duration_seconds"] for e in selected) if selected else None,
                         "interval_union_seconds": union_seconds([(e["started_at_unix"], e["ended_at_unix"]) for e in selected]) if selected else None,
                         "outputs": [o for e in selected for o in e.get("outputs", [])],
                         "duration_only_records": duration_only,
                         "reported_seconds_without_interval_sum": sum(r["reported_seconds"] for r in duration_only) if duration_only else None}
    return {"schema_version": 1, "stages": stages, "events": events, "unknown_records": list(unknown),
            "observed_interval_union_seconds": measured,
            "overlap_seconds": sum(end - start for start, end in intervals) - measured,
            "unobserved_gap_seconds": max(end for _, end in intervals) - min(start for start, _ in intervals) - measured if intervals else None,
            "usage": {"tokens": "not_exposed", "price": "not_exposed"},
            "interpretation": "Command envelopes may overlap or contain other stages; sums are not elapsed production time. Host worker time includes dispatch/wait and cannot isolate model compute. Unknown is not zero. No inference from leases, expiry, file mtimes or historical totals."}


def collect(ledgers=(), production_dirs=(), harness_reports=(), reported=()):
    events, unknown = [], []
    def add_check(check, evidence, identity):
        if check.get("reused"):
            return
        if not all(key in check for key in ("started_at_unix", "ended_at_unix", "duration_seconds")):
            unknown.append({"evidence": str(evidence), "check": check["id"], "stage": "verification", "reason": "historical check lacks observed interval", "reported_seconds": check.get("duration_seconds", "unknown")})
            return
        events.append({"id": identity, "stage": "verification", "evidence": str(evidence),
                       **{key: check[key] for key in ("started_at_unix", "ended_at_unix", "duration_seconds", "exit_code")},
                       "outputs": [{"path": str(evidence), "check": check["id"], "status": check["status"]}]})
    for path in ledgers:
        events.extend(json.loads(line) for line in Path(path).read_text().splitlines() if line.strip())
    for folder in production_dirs:
        for role_dir in sorted(Path(folder).glob("*/*/*")):
            if not role_dir.is_dir() or not role_dir.parent.name.isdecimal() or not re.fullmatch(r"(?:implement|review)(?:_retry_[1-9]\d*)?", role_dir.name):
                continue
            path = role_dir / "invocation.json"
            stage = "independent_review" if role_dir.name.startswith("review") else "rework" if int(role_dir.parent.name) > 1 else "model_implementation"
            if not path.is_file():
                unknown.append({"evidence": str(role_dir), "stage": stage, "reason": "allocated call has no observed invocation", "reported_seconds": "unknown"})
                continue
            data = json.loads(path.read_text())
            if not all(key in data for key in ("started_at_unix", "ended_at_unix", "seconds")):
                unknown.append({"evidence": str(path), "stage": stage, "reason": "historical invocation lacks observed interval", "reported_seconds": data.get("seconds", "unknown")})
                continue
            events.append({"id": str(path.resolve()), "stage": stage, "evidence": str(path),
                           "started_at_unix": data["started_at_unix"], "ended_at_unix": data["ended_at_unix"],
                           "duration_seconds": data["seconds"], "measurement_scope": "inclusive_worker_envelope; inner stages not separately observed",
                           "exit_code": data.get("exit_code"), "outputs": []})
        for path in sorted(Path(folder).glob("*/*/checkpoint.json")):
            for check in json.loads(path.read_text())["round_record"]["checks"]:
                add_check(check, path, str(path.resolve()) + ":" + check["id"])
    for name in harness_reports:
        path = Path(name)
        for check in json.loads(path.read_text())["checks"]:
            add_check(check, path, str(path.resolve()) + ":" + check["id"])
    for reference in reported:
        stage, separator, name = reference.partition("=")
        if not separator or stage not in STAGES:
            raise ValueError("Reported duration requires STAGE=JSON_FILE")
        data = json.loads(Path(name).read_text())
        seconds = data.get("seconds", data.get("duration_seconds"))
        if type(seconds) not in (int, float) or not math.isfinite(seconds) or seconds < 0:
            raise ValueError("Reported JSON needs an actual nonnegative seconds/duration_seconds field")
        unknown.append({"evidence": name, "stage": stage, "reason": "original command reported elapsed only; interval unknown",
                        "reported_seconds": seconds, "exit_code": data.get("exit_code"),
                        "measurement_scope": "original inclusive command duration; no inferred interval or exclusive cost"})
    return summarize(events, unknown)


def run_command(args):
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        raise ValueError("Specify a real command after --")
    started_at, started = time.time(), time.monotonic()
    code, error, log_handle = None, None, None
    try:
        if args.log_file:
            args.log_file.parent.mkdir(parents=True, exist_ok=True)
            log_handle = args.log_file.open("xb")
        code = subprocess.run(command, stdout=log_handle,
                              stderr=subprocess.STDOUT if log_handle else None).returncode
        return code
    except BaseException as exc:
        error = type(exc).__name__ + ": " + str(exc)
        raise
    finally:
        if log_handle:
            log_handle.close()
        ended_at, duration = time.time(), time.monotonic() - started
        outputs = []
        for name in args.output:
            path = Path(name)
            outputs.append({"path": name, "status": "present" if path.is_file() else "missing",
                            "sha256": hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None})
        captured_log = None
        if args.log_file:
            captured_log = {"path": str(args.log_file), "status": "present" if log_handle else "not_created",
                            "sha256": hashlib.sha256(args.log_file.read_bytes()).hexdigest() if log_handle else None,
                            "streams": "actual merged stdout/stderr; existing files are never overwritten"}
            outputs.append({**captured_log, "kind": "captured_log"})
        event = {"id": uuid.uuid4().hex, "stage": args.stage, "label": args.label, "evidence": str(args.ledger),
                 "command": command, "measurement_scope": "inclusive_command_envelope", "started_at_unix": started_at, "ended_at_unix": ended_at,
                 "duration_seconds": duration, "exit_code": code, "error": error, "outputs": outputs}
        if captured_log:
            event["captured_log"] = captured_log
        validate_event(event)
        args.ledger.parent.mkdir(parents=True, exist_ok=True)
        with args.ledger.open("a") as handle:
            fcntl.flock(handle, fcntl.LOCK_EX)
            handle.write(json.dumps(event, ensure_ascii=False) + "\n")
            handle.flush()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="operation", required=True)
    run = sub.add_parser("run")
    run.add_argument("--ledger", type=Path, required=True)
    run.add_argument("--stage", choices=STAGES, required=True)
    run.add_argument("--label", required=True)
    run.add_argument("--output", "--artifact", action="append", default=[], help="Record an artifact after command; this does NOT redirect stdout/stderr")
    run.add_argument("--log-file", type=Path, help="Capture actual merged stdout/stderr to a NEW file; command exit status is preserved, not validated")
    run.add_argument("command", nargs=argparse.REMAINDER)
    report = sub.add_parser("report")
    report.add_argument("--ledger", action="append", default=[])
    report.add_argument("--production-dir", action="append", default=[])
    report.add_argument("--harness-report", action="append", default=[])
    report.add_argument("--reported-duration", action="append", default=[], help="STAGE=JSON_FILE with actual seconds but no observed interval")
    report.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.operation == "run":
        return run_command(args)
    data = collect(args.ledger, args.production_dir, args.harness_report, args.reported_duration)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print(f"Production timing: {len(data['events'])} observed events, {len(data['unknown_records'])} unknown records; {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
