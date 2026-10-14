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
import shutil
import tempfile
from concurrent.futures import ThreadPoolExecutor

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


def descendant_processes(parent):
    """Linux toolchain wrappers may put their engines in separate sessions."""
    rows = {}
    for entry in Path("/proc").glob("[0-9]*/stat"):
        try:
            fields = entry.read_text().rpartition(")")[2].split()
            rows[int(entry.parent.name)] = (int(fields[1]), fields[19])
        except (OSError, ValueError, IndexError):
            continue
    children = []
    frontier = [parent]
    while frontier:
        parent_id = frontier.pop()
        for pid, (ppid, start) in rows.items():
            if ppid == parent_id:
                children.append((pid, start))
                frontier.append(pid)
    return children


def signal_descendants(children, action):
    for pid, start in reversed(children):
        try:
            # Do not signal a PID reused since the snapshot.
            fields = Path(f"/proc/{pid}/stat").read_text().rpartition(")")[2].split()
            if fields[19] == start:
                os.kill(pid, action)
        except (OSError, IndexError):
            pass


def run_check(check, log_path, root=None, env=None):
    start = time.monotonic()
    argv = [sys.executable if value == "python3" else value for value in check["argv"]]
    status, code = "failed", None
    with log_path.open("wb") as output:
        try:
            process = subprocess.Popen(argv, cwd=root or ROOT, env=env, stdout=output,
                                       stderr=subprocess.STDOUT, start_new_session=True)
        except OSError as error:
            output.write(str(error).encode())
            return {"status": "failed", "exit_code": None, "duration_seconds": 0}
        try:
            code = process.wait(timeout=check["timeout_seconds"])
        except subprocess.TimeoutExpired:
            status = "timeout"
        finally:
            children = descendant_processes(process.pid)
            signal_descendants(children, signal.SIGTERM)
            # Also cover ordinary descendants in the same process group.
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                pass
            signal_descendants(children, signal.SIGKILL)
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=5)
    text = log_path.read_text(errors="replace")
    engine_error = re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script", text)
    if status != "timeout" and code == 0 and not engine_error and re.search(check["success_pattern"], text, re.MULTILINE):
        status = "passed"
    return {"status": status, "exit_code": code,
            "duration_seconds": round(time.monotonic() - start, 3)}



def source_files():
    """Include tracked files, deletions and untracked inputs, excluding ignored build output."""
    result = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
                            cwd=ROOT, check=True, capture_output=True)
    return sorted(set(p for p in result.stdout.decode().split("\0") if p))


def input_digest(check, files, toolchain, snapshot=None, root=None):
    prefixes = check.get("inputs")
    entries = []
    for path in files:
        if prefixes and not any(path == prefix or path.startswith(prefix.rstrip("/") + "/") for prefix in prefixes):
            continue
        target = (root or ROOT) / path
        entries.append((path, snapshot[path] if snapshot is not None else (hashlib.sha256(target.read_bytes()).hexdigest() if target.is_file() else "deleted")))
    payload = {"inputs": entries, "check": check, "toolchain": toolchain}
    return hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()


def toolchain_identity():
    versions = {"python": sys.version, "platform": sys.platform}
    for name, command in (("godot", ["bash", "tools/godot.sh", "--version"]), ("node", ["node", "--version"])):
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=30)
        versions[name] = {"exit_code": result.returncode, "version": (result.stdout + result.stderr).strip()}
    return versions


def cached_result(check, cache_file, log):
    """Completion text and log hash are checked again; missing/corrupt evidence is a cache miss."""
    try:
        item = json.loads(cache_file.read_text())
        text = item["log"]
        if item["result"]["status"] != "passed" or item["result"]["exit_code"] != 0:
            return None
        if hashlib.sha256(text.encode()).hexdigest() != item["log_sha256"]:
            return None
        if re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script", text):
            return None
        if not re.search(check["success_pattern"], text, re.MULTILINE):
            return None
        if not Path(item["artifact_directory"]).is_dir():
            return None
        log.write_text(text)
        return {**item["result"], "duration_seconds": 0, "reused": True,
                "verified_commit": item["commit"], "artifact_directory": item["artifact_directory"]}
    except (OSError, KeyError, ValueError, TypeError):
        return None


def isolated_workspace(destination, files):
    subprocess.run(["git", "clone", "--quiet", "--shared", "--no-hardlinks", str(ROOT), str(destination)],
                   check=True, capture_output=True, timeout=60)
    # Overlay the exact working source, including deletions and new files.
    for path in files:
        source, target = ROOT / path, destination / path
        if source.is_file():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
        elif target.is_file():
            target.unlink()
    if (ROOT / ".godot").is_dir():
        shutil.copytree(ROOT / ".godot", destination / ".godot", dirs_exist_ok=True)
    shared_toolchain = Path(os.environ.get("GUNMAN_TOOLCHAIN_ROOT", str(ROOT.parent / "toolchains"))).resolve()
    data = destination / "build/isolated-data"
    data.mkdir(parents=True, exist_ok=True)
    templates = shared_toolchain / "user-data/godot/export_templates"
    if templates.is_dir():
        (data / "godot").mkdir()
        (data / "godot/export_templates").symlink_to(templates, target_is_directory=True)
    env = os.environ.copy()
    env.update(GUNMAN_TOOLCHAIN_ROOT=str(shared_toolchain), GUNMAN_DATA_HOME=str(data),
               XDG_DATA_HOME=str(data), XDG_CONFIG_HOME=str(destination / "build/isolated-config"),
               XDG_CACHE_HOME=str(destination / "build/isolated-cache"))
    return env


def execute_checks(data, ids, folder, jobs=1, reuse=False, commit=""):
    """Each lane has its own Godot import cache, user data and generated artifacts."""
    files = source_files()
    identity = toolchain_identity()
    snapshot = {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() if (ROOT / path).is_file() else "deleted" for path in files}
    source_before = input_digest({"argv": []}, files, identity, snapshot)
    cache = ROOT / "build/verification/check-cache"
    cache.mkdir(parents=True, exist_ok=True)
    # Export and its bundle consumer must stay ordered on the real workspace.
    serial = [name for name in ids if data["checks"][name].get("serial", False)]
    parallel = [name for name in ids if name not in serial]
    lanes = [[] for _ in range(min(jobs, max(1, len(parallel))))]
    loads = [0] * len(lanes)
    for name in parallel:
        lane = min(range(len(lanes)), key=lambda i: loads[i])
        lanes[lane].append(name)
        loads[lane] += data["checks"][name].get("weight_seconds", 1)
    results = {}
    def lane_run(names, root, env):
        for name in names:
            check = data["checks"][name]
            digest = input_digest(check, files, identity, snapshot)
            cache_file = cache / (name + "-" + digest + ".json")
            log = folder / (name + ".log")
            result = cached_result(check, cache_file, log) if reuse and check.get("cacheable", False) else None
            print(f"Running {name} ({'reused' if result else 'fresh'}); log: {log.relative_to(ROOT)}", flush=True)
            if result is None:
                if input_digest({"argv": []}, files, identity, root=root) != source_before:
                    raise RuntimeError("Validation lane source differs from frozen snapshot")
                result = run_check(check, log, root, env)
                if input_digest({"argv": []}, files, identity, root=root) != source_before:
                    result["status"] = "failed"
                    result["reason"] = "Check modified frozen source; result cannot approve later consumers"
                artifacts = folder / "artifacts" / name
                artifacts.mkdir(parents=True, exist_ok=True)
                verification = root / "build/verification"
                if root != ROOT and verification.is_dir():
                    shutil.copytree(verification, artifacts, dirs_exist_ok=True)
                result["artifact_directory"] = str(artifacts)
                result["reused"] = False
                if result["status"] == "passed" and check.get("cacheable", False):
                    text = log.read_text(errors="replace")
                    cached = {"result": result, "commit": commit, "log": text,
                              "log_sha256": hashlib.sha256(text.encode()).hexdigest(),
                              "artifact_directory": str(artifacts)}
                    temporary = cache_file.with_suffix(".tmp")
                    temporary.write_text(json.dumps(cached))
                    temporary.replace(cache_file)
            results[name] = {"id": name, "argv": check["argv"], "timeout_seconds": check["timeout_seconds"],
                             "input_digest": digest, "log": log.name, **result}
            print(f"{name}: {result['status']}", flush=True)
            if result["status"] != "passed":
                break
    with tempfile.TemporaryDirectory(prefix="gunman-checks-") as temporary:
        if jobs > 1:
            workspaces = []
            for index, names in enumerate(lanes):
                root = Path(temporary) / str(index)
                env = isolated_workspace(root, files)
                workspaces.append((names, root, env))
            with ThreadPoolExecutor(max_workers=len(lanes)) as pool:
                futures = [pool.submit(lane_run, *workspace) for workspace in workspaces]
                for future in futures:
                    future.result()
        else:
            lane_run(parallel, ROOT, None)
    if all(result["status"] == "passed" for result in results.values()) and len(results) == len(parallel):
        lane_run(serial, ROOT, None)
    # Never attribute checks to a source that changed while they were running.
    if input_digest({"argv": []}, source_files(), identity) != source_before:
        raise RuntimeError("Source changed during validation; results cannot approve the current source")
    return [results[name] for name in ids if name in results]

def main():
    if "--mission" in sys.argv:
        import production_loop
        return production_loop.main(sys.argv[1:])
    data = load_manifest()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", action="append", choices=["auto", *data["profiles"]])
    parser.add_argument("--base", default="origin/main")
    parser.add_argument("--check", action="append", choices=list(data["checks"]), help="Targeted development checks; never a full-profile approval")
    parser.add_argument("--jobs", type=int, default=1, choices=range(1, 9), help="Isolated validation lanes")
    parser.add_argument("--reuse", action="store_true", help="Reuse identical dependency proofs during development")
    parser.add_argument("--release", action="store_true", help="Force fresh final checks; never reuse cached proofs")
    parser.add_argument("--plan", action="store_true", help="Print checks; do not execute or claim validation")
    args = parser.parse_args()
    profiles = args.profile or ([] if args.check else ["auto"])
    paths = changed_paths(args.base) if "auto" in profiles else []
    profiles = list(dict.fromkeys([p for p in profiles if p != "auto"] +
                                  (select_profiles(paths) if "auto" in profiles else [])))
    ids = list(dict.fromkeys(args.check)) if args.check else resolve_checks(data, profiles)
    print(json.dumps({"profiles": profiles, "changed_paths": paths, "checks": ids}, ensure_ascii=False), flush=True)
    if args.plan:
        return 0
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    folder = ROOT / "build/verification/harness" / stamp
    folder.mkdir(parents=True)
    report = {"schema_version": 1, "started_at": stamp, "profiles": profiles,
              "changed_paths": paths, "checks": [], "status": "running",
              "targeted_checks": bool(args.check),
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
        started = time.monotonic()
        report["checks"] = execute_checks(data, ids, folder, args.jobs, args.reuse and not args.release, report["commit"])
        report["wall_seconds"] = round(time.monotonic() - started, 3)
        report["jobs"] = args.jobs
        report["release"] = args.release
        if len(report["checks"]) != len(ids) or any(item["status"] != "passed" for item in report["checks"]):
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
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Harness failed: {error}", file=sys.stderr)
        sys.exit(1)
