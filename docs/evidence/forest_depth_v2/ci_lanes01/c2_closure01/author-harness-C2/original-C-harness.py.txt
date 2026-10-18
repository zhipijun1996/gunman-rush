"""Run existing project checks with bounded execution and attributable evidence."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time
import shutil
import tempfile
import uuid
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



def tagged_processes(token):
    """Find owned engine sessions even after an exited wrapper is reparented."""
    marker = ("GUNMAN_CHECK_TOKEN=" + token).encode()
    found = []
    for entry in Path("/proc").glob("[0-9]*/environ"):
        try:
            if marker not in entry.read_bytes().split(b"\0"):
                continue
            fields = entry.with_name("stat").read_text().rpartition(")")[2].split()
            found.append((int(entry.parent.name), fields[19]))
        except (OSError, ValueError, IndexError):
            continue
    return found

def run_check(check, log_path, root=None, env=None):
    start = time.monotonic()
    started_at = time.time()
    status, code = "failed", None
    token = uuid.uuid4().hex
    # Only this explicit argv placeholder is supported; other braces are literal.
    argv = [value.replace("{check_token}", token) for value in check["argv"]]
    argv = [sys.executable if value == "python3" else value for value in argv]
    execution = {"expanded_argv": argv, "check_token": token}
    child_env = dict(os.environ if env is None else env)
    child_env["GUNMAN_CHECK_TOKEN"] = token
    with log_path.open("wb") as output:
        try:
            process = subprocess.Popen(argv, cwd=root or ROOT, env=child_env, stdout=output,
                                       stderr=subprocess.STDOUT, start_new_session=True)
        except OSError as error:
            output.write(str(error).encode())
            return {"status": "failed", "exit_code": None, "duration_seconds": round(time.monotonic() - start, 3),
                    "started_at_unix": started_at, "ended_at_unix": time.time(), "failure_reason": "launch_error", **execution}
        try:
            code = process.wait(timeout=check["timeout_seconds"])
        except subprocess.TimeoutExpired:
            status = "timeout"
        finally:
            children = list(set(descendant_processes(process.pid) + tagged_processes(token)))
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
            # TERM handlers may fork; rescan the owned scope before the final kill.
            children = list(set(children + tagged_processes(token)))
            signal_descendants(children, signal.SIGKILL)
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=5)
    text = log_path.read_text(errors="replace")
    engine_error = re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script", text)
    lifecycle_error = re.search(r"ObjectDB.*leaked|resources? still in use at exit", text)
    if status != "timeout" and code == 0 and not (engine_error or lifecycle_error) and re.search(check["success_pattern"], text, re.MULTILINE):
        status = "passed"
    reason = ("timeout" if status == "timeout" else "nonzero_exit" if code != 0 else
              "native_lifecycle_error" if lifecycle_error else "engine_error" if engine_error else "missing_completion" if status != "passed" else None)
    return {"status": status, "exit_code": code, "failure_reason": reason,
            "started_at_unix": started_at, "ended_at_unix": time.time(),
            "duration_seconds": round(time.monotonic() - start, 3), **execution}



def source_files(root=None):
    """Include tracked files, deletions and untracked inputs, excluding ignored build output."""
    result = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
                            cwd=root or ROOT, check=True, capture_output=True)
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


def artifact_fingerprint(directory):
    """Bind reusable proofs to their actual output bytes, including an empty set."""
    if not directory.is_dir() or directory.is_symlink():
        raise ValueError("Missing/linked artifact directory")
    entries = {}
    for path in sorted(directory.rglob("*")):
        if path.is_symlink():
            raise ValueError("Linked artifact cannot be reused")
        if path.is_file():
            entries[path.relative_to(directory).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    return entries


def verification_outputs(root, control_directory, directories=("build/verification",)):
    """Hash native output bytes, excluding Harness's own logs/cache/archive."""
    ignored = [control_directory.resolve(), root / "build/verification/harness", root / "build/verification/check-cache"]
    outputs = {}
    for name in directories:
        base = root / name
        if Path(name).is_absolute() or ".." in Path(name).parts or not base.is_relative_to(root / "build"):
            raise ValueError("Check artifact paths must be inside build")
        if (any(parent.is_symlink() for parent in (base, *base.parents)
                if parent == root or parent.is_relative_to(root))
                or not base.resolve().is_relative_to((root / "build").resolve())):
            raise ValueError("Linked verification directory cannot support cache reuse")
        for path in sorted(base.rglob("*")):
            if any(path.absolute().is_relative_to(item) for item in ignored):
                continue
            if path.is_symlink():
                raise ValueError("Linked verification output cannot support cache reuse")
            if path.is_file():
                outputs[path.relative_to(root).as_posix()] = {"sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                                                             "mtime_ns": path.stat().st_mtime_ns, "size": path.stat().st_size}
    return outputs


def cached_result(check, cache_file, log, expected_digest=None):
    """Completion text and log hash are checked again; missing/corrupt evidence is a cache miss."""
    try:
        item = json.loads(cache_file.read_text())
        if expected_digest is not None and item.get("input_digest") != expected_digest:
            return None
        text = item["log"]
        if item["result"]["status"] != "passed" or item["result"]["exit_code"] != 0:
            return None
        if hashlib.sha256(text.encode()).hexdigest() != item["log_sha256"]:
            return None
        if re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script|ObjectDB.*leaked|resources? still in use at exit", text):
            return None
        if not re.search(check["success_pattern"], text, re.MULTILINE):
            return None
        artifacts = Path(item["artifact_directory"])
        if artifact_fingerprint(artifacts) != item.get("artifact_fingerprint"):
            return None
        for name, expected in (item.get("live_output_fingerprint") or {}).items():
            path = Path(name)
            actual = (hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() and not path.is_symlink()
                      else "non_regular" if path.exists() or path.is_symlink() else "deleted")
            if actual != expected:
                return None
        log.write_text(text)
        return {**item["result"], "duration_seconds": 0, "reused": True,
                "started_at_unix": time.time(), "ended_at_unix": time.time(),
                "original_duration_seconds": item["result"].get("duration_seconds"),
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
            result = cached_result(check, cache_file, log, digest) if reuse and check.get("cacheable", False) else None
            print(f"Running {name} ({'reused' if result else 'fresh'}); log: {log.relative_to(ROOT)}", flush=True)
            if result is None:
                if input_digest({"argv": []}, source_files(root), identity, root=root) != source_before:
                    raise RuntimeError("Validation lane source differs from frozen snapshot")
                artifact_paths = ["build/verification", *check.get("artifact_paths", [])]
                collect_outputs = check.get("cacheable", False) or root != ROOT or bool(check.get("artifact_paths"))
                before_outputs = verification_outputs(root, folder, artifact_paths) if collect_outputs else {}
                result = run_check(check, log, root, env)
                if input_digest({"argv": []}, source_files(root), identity, root=root) != source_before:
                    result["status"] = "failed"
                    result["reason"] = "Check modified frozen source; result cannot approve later consumers"
                artifacts = folder / "artifacts" / name
                artifacts.mkdir(parents=True, exist_ok=True)
                # Keep the real log even for runners whose entire proof is stdout.
                shutil.copy2(log, artifacts / "check.log")
                live_outputs = {}
                if collect_outputs:
                    after_outputs = verification_outputs(root, folder, artifact_paths)
                    changed_outputs = {path: after_outputs[path]["sha256"] if path in after_outputs else "deleted"
                                       for path in set(before_outputs) | set(after_outputs)
                                       if before_outputs.get(path) != after_outputs.get(path)}
                    for path, fingerprint in changed_outputs.items():
                        if fingerprint != "deleted":
                            destination = artifacts / path
                            destination.parent.mkdir(parents=True, exist_ok=True)
                            shutil.copy2(root / path, destination)
                        if root == ROOT:
                            live_outputs[str(root / path)] = fingerprint
                result["artifact_directory"] = str(artifacts)
                result["reused"] = False
                if result["status"] == "passed" and check.get("cacheable", False):
                    text = log.read_text(errors="replace")
                    cached = {"input_digest": digest, "result": result, "commit": commit, "log": text,
                              "log_sha256": hashlib.sha256(text.encode()).hexdigest(),
                              "artifact_directory": str(artifacts),
                              "live_output_fingerprint": live_outputs,
                              "artifact_fingerprint": artifact_fingerprint(artifacts)}
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

def source_inventory():
    """Exact prepared working inputs, including deletions and untracked files."""
    return {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
            if (ROOT / path).is_file() else "deleted" for path in source_files()}


def git_metadata():
    values = {"working_files": {
        path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
        if (ROOT / path).is_file() else "deleted" for path in changed_paths("HEAD")}}
    for key, command in (("commit", ["rev-parse", "HEAD"]), ("git_status", ["status", "--porcelain"]),
                         ("diff", ["diff", "HEAD"]), ("untracked", ["ls-files", "--others", "--exclude-standard"])):
        values[key] = subprocess.run(["git", *command], cwd=ROOT, capture_output=True,
                                     text=True, check=True, timeout=30).stdout.strip()
    return values


def lane_checks(data, ids, lane):
    return [name for name in ids if bool(data["checks"][name].get("serial", False)) == (lane == "serial")]


def bind_lane_logs(data, checks, folder):
    for item in checks:
        item["success_pattern"] = data["checks"][item["id"]]["success_pattern"]
        item["log_sha256"] = hashlib.sha256((folder / item["log"]).read_bytes()).hexdigest()


def verify_lane_reports(data, profiles, paths, metadata, inventory):
    """Verify two fresh phase proofs against this checkout; never execute checks."""
    ids = resolve_checks(data, profiles)
    manifest_hash = hashlib.sha256(MANIFEST.read_bytes()).hexdigest()
    reports, references, results = {}, [], {}
    identity = None
    tokens = set()
    for path in paths:
        path = Path(path)
        raw = path.read_bytes()
        report = json.loads(raw)
        if not isinstance(report, dict):
            raise ValueError("Phase report must be an object")
        lane = report.get("lane")
        if lane not in ("parallel", "serial") or lane in reports:
            raise ValueError("Expected exactly one parallel and one serial report")
        if (report.get("schema_version") != 1 or report.get("profiles") != profiles
                or report.get("requested_checks") != ids or report.get("manifest_sha256") != manifest_hash
                or report.get("status") != "passed" or report.get("partial") is not True
                or report.get("approval_scope") != "partial" or report.get("release") is not True
                or type(report.get("jobs")) is not int or report["jobs"] != 1
                or report.get("targeted_checks") is not False or report.get("changed_paths") != []):
            raise ValueError("Phase scope, freshness or manifest mismatch")
        for key, value in metadata.items():
            if report.get(key) != value:
                raise ValueError(f"Phase Git metadata mismatch: {key}")
        if report.get("source_files") != inventory or report.get("source_files_after") != inventory:
            raise ValueError("Phase source inventory differs from current prepared checkout")
        toolchain = report.get("toolchain")
        if (not isinstance(toolchain, dict) or set(toolchain) != {"python", "platform", "godot", "node"}
                or not all(isinstance(toolchain.get(k), str) and toolchain[k] for k in ("python", "platform"))
                or report.get("toolchain_after") != toolchain):
            raise ValueError("Missing or changed phase toolchain identity")
        for name in ("godot", "node"):
            version = toolchain[name]
            if (not isinstance(version, dict) or type(version.get("exit_code")) is not int
                    or version["exit_code"] != 0 or not isinstance(version.get("version"), str)
                    or not version["version"]):
                raise ValueError("Phase toolchain version query failed")
        if identity is not None and toolchain != identity:
            raise ValueError("Phase toolchain identities differ")
        identity = toolchain
        checks = report.get("checks")
        expected = lane_checks(data, ids, lane)
        if (not isinstance(checks, list) or not all(isinstance(item, dict) for item in checks)
                or [item.get("id") for item in checks] != expected):
            raise ValueError("Phase check order/set differs from serial ownership")
        for item in checks:
            name = item["id"]
            check = data["checks"][name]
            if (item.get("argv") != check["argv"] or type(item.get("timeout_seconds")) is not int
                    or item["timeout_seconds"] != check["timeout_seconds"]
                    or item.get("success_pattern") != check["success_pattern"]
                    or item.get("input_digest") != input_digest(check, sorted(inventory), toolchain, inventory)
                    or item.get("status") != "passed" or type(item.get("exit_code")) is not int
                    or item["exit_code"] != 0 or item.get("failure_reason") is not None
                    or item.get("reason") is not None or item.get("reused") is not False):
                raise ValueError(f"Invalid fresh check contract/result: {name}")
            token = item.get("check_token")
            if not isinstance(token, str) or not re.fullmatch(r"[0-9a-f]{32}", token) or token in tokens:
                raise ValueError("Missing or duplicate fresh execution token")
            tokens.add(token)
            expanded = [value.replace("{check_token}", token) for value in check["argv"]]
            # Each phase records its own Python interpreter, which may be at a
            # different absolute location on another runner. The original argv
            # and dependency digest remain exact; all other arguments are exact.
            executable = report.get("python_executable")
            if (not isinstance(executable, str) or not Path(executable).is_absolute()
                    or not re.fullmatch(r"python(?:\d+(?:\.\d+)*)?(?:\.exe)?", Path(executable).name)):
                raise ValueError("Missing phase Python executable identity")
            expanded = [executable if value == "python3" else value for value in expanded]
            if item.get("expanded_argv") != expanded:
                raise ValueError("Expanded check argv mismatch")
            for field in ("started_at_unix", "ended_at_unix", "duration_seconds"):
                value = item.get(field)
                if type(value) not in (int, float) or not math.isfinite(value) or value < 0:
                    raise ValueError("Invalid actual check interval")
            elapsed = item["ended_at_unix"] - item["started_at_unix"]
            # run_check owns the original process timeout and cleanup limits.
            # Its duration also includes launch, process scanning and log I/O;
            # do not invent another wall cap during proof verification.
            if elapsed < 0 or abs(elapsed - item["duration_seconds"]) > 1:
                raise ValueError("Inconsistent actual check interval")
            log_name = item.get("log")
            if not isinstance(log_name, str) or log_name != name + ".log":
                raise ValueError("Invalid phase log path")
            log = path.parent / log_name
            if log.is_symlink() or not log.is_file():
                raise ValueError("Missing or linked phase check log")
            contents = log.read_bytes()
            text = contents.decode(errors="replace")
            if (hashlib.sha256(contents).hexdigest() != item.get("log_sha256")
                    or not re.search(check["success_pattern"], text, re.MULTILINE)
                    or re.search(r"SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script|ObjectDB.*leaked|resources? still in use at exit", text)):
                raise ValueError("Phase completion/log integrity failed")
            results[name] = item
        reports[lane] = report
        references.append({"lane": lane, "path": str(path), "sha256": hashlib.sha256(raw).hexdigest()})
    if set(reports) != {"parallel", "serial"} or set(results) != set(ids):
        raise ValueError("Missing selected-profile coverage")
    return {"checks": [results[name] for name in ids], "lane_reports": references,
            "toolchain": identity, "toolchain_after": identity}


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
    parser.add_argument("--lane", choices=("parallel", "serial"), help="Fresh partial profile phase; jobs=1 only")
    parser.add_argument("--verify-lanes", nargs=2, metavar=("PARALLEL_REPORT", "SERIAL_REPORT"),
                        help="Verify two fresh phase reports against current prepared source; no checks executed")
    args = parser.parse_args()
    if args.lane or args.verify_lanes:
        if (not args.profile or "auto" in args.profile or args.check or args.reuse or args.jobs != 1
                or (args.lane and (not args.release or args.verify_lanes))
                or (args.verify_lanes and args.plan)):
            parser.error("Phases/merge require explicit profiles, jobs=1, no check/reuse/auto; phases require release")
    profiles = args.profile or ([] if args.check else ["auto"])
    paths = changed_paths(args.base) if "auto" in profiles else []
    profiles = list(dict.fromkeys([p for p in profiles if p != "auto"] +
                                  (select_profiles(paths) if "auto" in profiles else [])))
    ids = list(dict.fromkeys(args.check)) if args.check else resolve_checks(data, profiles)
    requested_ids = ids[:]
    if args.lane:
        ids = lane_checks(data, ids, args.lane)
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
        if args.lane or args.verify_lanes:
            inventory = source_inventory()
            metadata = {key: report[key] for key in ("commit", "git_status", "diff", "untracked", "working_files")}
            report.update(requested_checks=requested_ids, source_files=inventory,
                          partial=bool(args.lane), approval_scope="partial" if args.lane else "selected_profiles_technical")
            if args.verify_lanes:
                report.update(verify_lane_reports(data, profiles, args.verify_lanes, metadata, inventory))
                for reference in report["lane_reports"]:
                    phase_path = Path(reference["path"])
                    for name in lane_checks(data, requested_ids, reference["lane"]):
                        destination = folder / (name + ".log")
                        shutil.copy2(phase_path.parent / (name + ".log"), destination)
                        item = next(item for item in report["checks"] if item["id"] == name)
                        if hashlib.sha256(destination.read_bytes()).hexdigest() != item["log_sha256"]:
                            raise RuntimeError("Phase log changed during verification")
                    if hashlib.sha256(phase_path.read_bytes()).hexdigest() != reference["sha256"]:
                        raise RuntimeError("Phase report changed during verification")
                report.update(source_files_after=source_inventory(), jobs=1, release=True)
                if report["source_files_after"] != inventory or git_metadata() != metadata:
                    raise RuntimeError("Source/Git changed during lane verification")
                report.update(status="passed", wall_seconds=round(time.monotonic() - started, 3))
                print("HARNESS LANES: verified complete fresh selected-profile coverage (technical only)", flush=True)
                return 0
            report.update(lane=args.lane, toolchain=toolchain_identity(), python_executable=sys.executable)
        report["checks"] = execute_checks(data, ids, folder, args.jobs, args.reuse and not args.release, report["commit"])
        if args.lane:
            bind_lane_logs(data, report["checks"], folder)
            report.update(source_files_after=source_inventory(), toolchain_after=toolchain_identity())
            if (report["source_files_after"] != inventory or report["toolchain_after"] != report["toolchain"]
                    or git_metadata() != metadata):
                raise RuntimeError("Source/Git/toolchain changed during phase validation")
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
