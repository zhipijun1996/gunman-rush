"""Run existing project checks with bounded execution and attributable evidence."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "tools/harness/profiles.json"


def load_manifest():
    data = json.loads(MANIFEST.read_text())
    if data.get("schema_version") != 1:
        raise ValueError("Unsupported harness schema")
    checks, profiles = data["checks"], data["profiles"]
    for name, check in checks.items():
        if not check["argv"] or check["timeout_seconds"] <= 0:
            raise ValueError(f"Invalid check: {name}")
        re.compile(check["success_pattern"])
        if not (ROOT / check["argv"][1]).is_file():
            raise ValueError(f"Missing check entry: {name}")
    for name, ids in profiles.items():
        if not ids or len(set(ids)) != len(ids) or any(i not in checks for i in ids):
            raise ValueError(f"Invalid profile: {name}")
    return data


def changed_paths(base):
    # Include committed changes, staged/unstaged edits, deletions and new files.
    paths = set()
    for args in (["diff", "--name-only", "-z", f"{base}...HEAD"],
                 ["diff", "--name-only", "-z", "HEAD"],
                 ["ls-files", "--others", "--exclude-standard", "-z"]):
        result = subprocess.run(["git", *args], cwd=ROOT, check=True,
                                capture_output=True, timeout=30)
        paths.update(p for p in result.stdout.decode().split("\0") if p)
    return sorted(paths)


def select_profiles(paths):
    selected = {"docs"}
    for path in paths:
        if path.startswith(("docs/", ".agents/skills/")) or path in {"AGENTS.md", "README.md"}:
            continue
        if path.startswith("assets/"):
            selected.update(("art", "gameplay"))
        elif path.startswith("tools/web/") or path.startswith(("tools/verify_web_", "tools/check_web_", "tools/test_web_")):
            selected.add("web")
        elif path.startswith(("tools/harness/", "tools/harness.py", "tools/check_project.py", "tests/test_harness.py")):
            continue
        elif path in {".gitignore", ".github/workflows/docs.yml", ".github/pull_request_template.md"}:
            continue
        else:
            # Runtime/config/build/CI and unknown changes require the full baseline.
            selected.update(("art", "gameplay", "web"))
    return sorted(selected)


def resolve_checks(data, profiles):
    return list(dict.fromkeys(check for profile in profiles for check in data["profiles"][profile]))


def run_check(check, log_path):
    start = time.monotonic()
    argv = [sys.executable if value == "python3" else value for value in check["argv"]]
    status, code = "failed", None
    with log_path.open("wb") as output:
        try:
            process = subprocess.Popen(argv, cwd=ROOT, stdout=output,
                                       stderr=subprocess.STDOUT, start_new_session=True)
        except OSError as error:
            output.write(str(error).encode())
            return {"status": "failed", "exit_code": None, "duration_seconds": 0}
        try:
            code = process.wait(timeout=check["timeout_seconds"])
        except subprocess.TimeoutExpired:
            status = "timeout"
        finally:
            # Clean up the entire group, including child engines on timeout.
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                pass
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=5)
    text = log_path.read_text(errors="replace")
    if status != "timeout" and code == 0 and re.search(check["success_pattern"], text, re.MULTILINE):
        status = "passed"
    return {"status": status, "exit_code": code,
            "duration_seconds": round(time.monotonic() - start, 3)}


def main():
    data = load_manifest()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", action="append", choices=["auto", *data["profiles"]])
    parser.add_argument("--base", default="origin/main")
    parser.add_argument("--plan", action="store_true", help="Print checks; do not execute or claim validation")
    args = parser.parse_args()
    profiles = args.profile or ["auto"]
    paths = changed_paths(args.base) if "auto" in profiles else []
    profiles = list(dict.fromkeys([p for p in profiles if p != "auto"] +
                                  (select_profiles(paths) if "auto" in profiles else [])))
    ids = resolve_checks(data, profiles)
    print(json.dumps({"profiles": profiles, "changed_paths": paths, "checks": ids}, ensure_ascii=False), flush=True)
    if args.plan:
        return 0
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    folder = ROOT / "build/verification/harness" / stamp
    folder.mkdir(parents=True)
    report = {"schema_version": 1, "started_at": stamp, "profiles": profiles,
              "changed_paths": paths, "checks": [], "status": "running",
              "device_acceptance": "unverified", "fun_acceptance": "unverified"}
    report["manifest_sha256"] = hashlib.sha256(MANIFEST.read_bytes()).hexdigest()
    report["working_files"] = {
        path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() if (ROOT / path).is_file() else "deleted"
        for path in changed_paths("HEAD")
    }
    for key, args_ in (("commit", ["rev-parse", "HEAD"]), ("git_status", ["status", "--porcelain"]),
                       ("diff", ["diff", "HEAD"]), ("untracked", ["ls-files", "--others", "--exclude-standard"])):
        report[key] = subprocess.run(["git", *args_], cwd=ROOT, capture_output=True,
                                     text=True, check=True, timeout=30).stdout.strip()
    report["python_version"] = sys.version
    report_path = folder / "report.json"
    try:
        for name in ids:
            log = folder / f"{name}.log"
            print(f"Running {name}; log: {log.relative_to(ROOT)}", flush=True)
            result = run_check(data["checks"][name], log)
            report["checks"].append({"id": name, "argv": data["checks"][name]["argv"],
                                    "timeout_seconds": data["checks"][name]["timeout_seconds"],
                                    "log": log.name, **result})
            report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
            print(f"{name}: {result['status']}", flush=True)
            if result["status"] != "passed":
                report["status"] = "failed"
                return 1
        report["status"] = "passed"
        return 0
    except BaseException:
        report["status"] = "interrupted"
        raise
    finally:
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
        print(f"Evidence: {report_path.relative_to(ROOT)}", flush=True)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"Harness failed: {error}", file=sys.stderr)
        sys.exit(1)
