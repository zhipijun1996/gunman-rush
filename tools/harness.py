"""Run explicitly selected manual tests. Daily CI lives in tools/ci.py.

No automatic impact expansion, result reuse, workspace lanes, or evidence bundles.
The small source helpers below are used by existing manual capture/release tools;
the runner itself does not hash the repository.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import stat
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "tools/harness/profiles.json"


def load_manifest():
    data = json.loads(MANIFEST.read_text())
    if data.get("schema_version") != 1:
        raise ValueError("Unsupported harness schema")
    for name, check in data["checks"].items():
        if not check["argv"] or check["timeout_seconds"] <= 0 or check.get("mode") != "manual":
            raise ValueError(f"Invalid manual check: {name}")
        re.compile(check["success_pattern"])
        if len(check["argv"]) < 2 or not (ROOT / check["argv"][1]).is_file():
            raise ValueError(f"Missing check entry: {name}")
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


class SourceHashCache:
    """Reuse source bytes only within one execution; every lookup rechecks metadata."""
    def __init__(self):
        self._entries = {}
        # Windows ctime can mean creation time. Reuse only Linux change-time;
        # other platforms retain full byte reads at every source guard.
        self._reuse_stat = sys.platform.startswith("linux")

    @staticmethod
    def _key(info):
        return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns)

    def digest(self, path):
        path = path.absolute()
        try:
            before = path.stat()
        except FileNotFoundError:
            self._entries.pop(path, None)
            return "deleted"
        if not stat.S_ISREG(before.st_mode):
            self._entries.pop(path, None)
            return "deleted"
        key = self._key(before)
        cached = self._entries.get(path)
        try:
            if self._reuse_stat and cached is not None and cached[0] == key:
                digest = cached[1]
            else:
                with path.open("rb") as source:
                    if self._key(os.fstat(source.fileno())) != key:
                        raise RuntimeError(f"Source changed while hashing: {path}")
                    digest = hashlib.file_digest(source, "sha256").hexdigest()
                    if self._key(os.fstat(source.fileno())) != key:
                        raise RuntimeError(f"Source changed while hashing: {path}")
            # Also catch pathname replacement during the read or a cache hit.
            if self._key(path.stat()) != key:
                raise RuntimeError(f"Source changed while hashing: {path}")
        except (OSError, RuntimeError):
            self._entries.pop(path, None)
            raise
        if self._reuse_stat:
            self._entries[path] = (key, digest)
        return digest


def input_digest(check, files, toolchain, snapshot=None, root=None, hash_cache=None):
    prefixes = check.get("inputs")
    entries = []
    source_hashes = hash_cache if hash_cache is not None else SourceHashCache()
    for path in files:
        if prefixes and not any(path == prefix or path.startswith(prefix.rstrip("/") + "/") for prefix in prefixes):
            continue
        target = (root or ROOT) / path
        entries.append((path, snapshot[path] if snapshot is not None else source_hashes.digest(target)))
    payload = {"inputs": entries, "check": check, "toolchain": toolchain}
    return hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()


def toolchain_identity():
    from godot_identity import verified_engine
    versions = {"python": sys.version, "platform": sys.platform}
    try:
        engine = verified_engine(repo=ROOT)
        versions["godot"] = {"exit_code": 0, **{key:value for key,value in engine.items() if key != "binary"}}
    except (OSError, RuntimeError, KeyError, ValueError, subprocess.SubprocessError) as error:
        versions["godot"] = {"exit_code": 1, "version": str(error)}
    result = subprocess.run(["node", "--version"], cwd=ROOT, capture_output=True, text=True, timeout=30)
    versions["node"] = {"exit_code": result.returncode, "version": (result.stdout + result.stderr).strip()}
    return versions


def source_inventory(hash_cache=None):
    """Exact prepared working inputs, including deletions and untracked files."""
    source_hashes = hash_cache if hash_cache is not None else SourceHashCache()
    return {path: source_hashes.digest(ROOT / path) for path in source_files()}


def git_metadata():
    values = {"working_files": {
        path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
        if (ROOT / path).is_file() else "deleted" for path in changed_paths("HEAD")}}
    for key, command in (("commit", ["rev-parse", "HEAD"]), ("git_status", ["status", "--porcelain"]),
                         ("diff", ["diff", "HEAD"]), ("untracked", ["ls-files", "--others", "--exclude-standard"])):
        values[key] = subprocess.run(["git", *command], cwd=ROOT, capture_output=True,
                                     text=True, check=True, timeout=30).stdout.strip()
    return values


def main(argv=None):
    data = load_manifest()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="append", choices=list(data["checks"]), help="Run this manual test; repeat to select several")
    parser.add_argument("--list", action="store_true", help="List available manual tests (also the default)")
    parser.add_argument("--plan", action="store_true", help="Print selected commands without running them")
    args = parser.parse_args(argv)
    ids = list(dict.fromkeys(args.check or []))
    if args.list or not ids:
        for name in data["checks"]:
            print(f"{name}: {' '.join(data['checks'][name]['argv'])}")
        return 0
    if args.plan:
        print(json.dumps({name: data["checks"][name] for name in ids}, indent=2))
        return 0
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    folder = ROOT / "build/verification/harness" / stamp
    folder.mkdir(parents=True)
    results = []
    started = time.monotonic()
    try:
        for name in ids:
            result = run_check(data["checks"][name], folder / f"{name}.log")
            results.append({"id": name, **result})
            print(f"{name}: {result['status']}", flush=True)
            if result["status"] != "passed":
                print((folder / f"{name}.log").read_text(errors="replace"), end="")
                return 1
        return 0
    finally:
        report = {"checks": results, "seconds": round(time.monotonic() - started, 3)}
        (folder / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(f"Logs: {folder}", flush=True)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Harness failed: {error}", file=sys.stderr)
        sys.exit(1)
