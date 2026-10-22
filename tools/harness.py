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
import stat
import subprocess
import sys
import time
import shutil
import tempfile
import uuid
import zipfile
import zlib
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
    versions = {"python": sys.version, "platform": sys.platform}
    for name, command in (("godot", ["bash", "tools/godot.sh", "--version"]), ("node", ["node", "--version"])):
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=30)
        versions[name] = {"exit_code": result.returncode, "version": (result.stdout + result.stderr).strip()}
    return versions


ARTIFACT_JSON_THRESHOLD = 8 * 1024 * 1024
ARTIFACT_ARCHIVE = 'large-json.zip'
ARTIFACT_INDEX = 'large-json.index.json'
ARTIFACT_CHUNK = 1024 * 1024


def _file_sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def _safe_member(name):
    if not isinstance(name, str):
        raise ValueError('Unsafe archived artifact path')
    p = Path(name)
    if (not name or '\\' in name or p.is_absolute()
            or '..' in p.parts or p.as_posix() != name or p.parts[0] != 'build'):
        raise ValueError('Unsafe archived artifact path')
    return name


def _unlinked_path(path):
    path = path.absolute()
    if any(p.is_symlink() for p in (path, *path.parents)):
        raise ValueError('Linked artifact path')
    return path


def _verify_artifact_archive(archive, index):
    _unlinked_path(archive)
    if (not isinstance(index, dict)
            or set(index) != {'schema_version', 'format', 'threshold_bytes', 'archive_sha256', 'members'}
            or index.get('schema_version') != 1 or index.get('format') != 'zip-deflate-level1'
            or index.get('threshold_bytes') != ARTIFACT_JSON_THRESHOLD
            or not isinstance(index.get('members'), list) or not index['members']
            or _file_sha(archive) != index.get('archive_sha256')):
        raise ValueError('Invalid archived artifact index or ZIP hash')
    expected = {}
    for row in index['members']:
        if (not isinstance(row, dict) or set(row) != {'path', 'sha256', 'size'}
                or type(row.get('size')) is not int or row['size'] < ARTIFACT_JSON_THRESHOLD
                or not isinstance(row.get('sha256'), str)
                or not re.fullmatch('[0-9a-f]{64}', row['sha256'])):
            raise ValueError('Invalid archived artifact member metadata')
        name = _safe_member(row['path'])
        if name in expected or not name.endswith('.json'):
            raise ValueError('Duplicate or non-JSON archived artifact member')
        expected[name] = row
    with zipfile.ZipFile(archive) as bundle:
        infos = bundle.infolist()
        if len(infos) != len(expected) or {i.filename for i in infos} != set(expected):
            raise ValueError('Incomplete or extra archived artifact members')
        for info in infos:
            row = expected[info.filename]
            mode = info.external_attr >> 16
            if (info.is_dir() or stat.S_ISLNK(mode) or info.file_size != row['size']
                    or info.compress_type != zipfile.ZIP_DEFLATED):
                raise ValueError('Invalid archived artifact member type/size')
            digest, size = hashlib.sha256(), 0
            with bundle.open(info) as source:
                while chunk := source.read(ARTIFACT_CHUNK):
                    digest.update(chunk); size += len(chunk)
            if size != row['size'] or digest.hexdigest() != row['sha256']:
                raise ValueError('Archived artifact member bytes differ')
    return expected


def _artifact_archive_index(directory):
    archive, index_path = directory / ARTIFACT_ARCHIVE, directory / ARTIFACT_INDEX
    if any(directory.glob('large-json*.partial')):
        raise ValueError('Partial artifact archive cannot be reused')
    if not archive.exists() and not index_path.exists() and not archive.is_symlink() and not index_path.is_symlink():
        return None
    _unlinked_path(index_path)
    index = json.loads(index_path.read_text())
    _verify_artifact_archive(archive, index)
    return index


def _open_artifact_source(root, name):
    # Walk actual directory descriptors so an ancestor/link swap cannot redirect
    # the stream outside the producer, even between pathname checks and open.
    _unlinked_path(root)
    descriptor = os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        parts = Path(_safe_member(name)).parts
        for part in parts[:-1]:
            child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=descriptor)
            os.close(descriptor); descriptor = child
        source = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW, dir_fd=descriptor)
    finally:
        os.close(descriptor)
    return os.fdopen(source, 'rb')


def collect_artifacts(root, artifacts, changed_outputs):
    """Preserve small paths; losslessly archive only newly changed large JSON."""
    large = []
    for name, expected in sorted(changed_outputs.items()):
        _safe_member(name)
        if expected == 'deleted':
            continue
        source = _unlinked_path(root / name)
        if source.suffix == '.json' and source.stat().st_size >= ARTIFACT_JSON_THRESHOLD:
            large.append((name, expected))
        else:
            destination = artifacts / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
    if not large:
        return
    archive, index_path = artifacts / ARTIFACT_ARCHIVE, artifacts / ARTIFACT_INDEX
    temporary, index_temporary = archive.with_suffix('.zip.partial'), index_path.with_suffix('.json.partial')
    if any(p.exists() or p.is_symlink() for p in (archive, index_path, temporary, index_temporary)):
        raise ValueError('Fresh artifact archive required')
    members = []
    try:
        with zipfile.ZipFile(temporary, 'x', compression=zipfile.ZIP_DEFLATED,
                             compresslevel=1, allowZip64=True) as bundle:
            for name, expected in large:
                source = _unlinked_path(root / name)
                with _open_artifact_source(root, name) as stream:
                    before = os.fstat(stream.fileno())
                    key = SourceHashCache._key(before)
                    if not stat.S_ISREG(before.st_mode) or SourceHashCache._key(source.stat()) != key:
                        raise ValueError('Artifact changed before collection')
                    digest, size = hashlib.sha256(), 0
                    with bundle.open(name, 'w', force_zip64=True) as target:
                        while chunk := stream.read(ARTIFACT_CHUNK):
                            target.write(chunk); digest.update(chunk); size += len(chunk)
                    _unlinked_path(source)
                    if (SourceHashCache._key(os.fstat(stream.fileno())) != key
                            or SourceHashCache._key(source.stat()) != key
                            or size != before.st_size or digest.hexdigest() != expected):
                        raise ValueError('Artifact changed during collection')
                members.append({'path': name, 'sha256': expected, 'size': size})
        index = {'schema_version': 1, 'format': 'zip-deflate-level1',
                 'threshold_bytes': ARTIFACT_JSON_THRESHOLD,
                 'archive_sha256': _file_sha(temporary), 'members': members}
        _verify_artifact_archive(temporary, index)
        index_temporary.write_text(json.dumps(index, indent=2) + '\n')
        temporary.replace(archive)
        index_temporary.replace(index_path)
    except BaseException:
        for p in (temporary, index_temporary, archive, index_path):
            p.unlink(missing_ok=True)
        raise


def restore_archived_artifact(artifacts, member, destination):
    """Explicitly recover exact recorded bytes to a fresh file, never live output."""
    _unlinked_path(artifacts)
    member = _safe_member(member)
    index = _artifact_archive_index(artifacts)
    if index is None:
        raise ValueError('No archived artifact bundle')
    rows = {row['path']: row for row in index['members']}
    if member not in rows:
        raise ValueError('Unknown archived artifact member')
    destination = _unlinked_path(Path(destination))
    with zipfile.ZipFile(artifacts / ARTIFACT_ARCHIVE) as bundle:
        with destination.open('xb') as target:
            try:
                digest, size = hashlib.sha256(), 0
                with bundle.open(member) as source:
                    while chunk := source.read(ARTIFACT_CHUNK):
                        target.write(chunk); digest.update(chunk); size += len(chunk)
                if size != rows[member]['size'] or digest.hexdigest() != rows[member]['sha256']:
                    raise ValueError('Restored artifact bytes differ')
            except BaseException:
                destination.unlink(missing_ok=True)
                raise
    return destination


def artifact_fingerprint(directory):
    """Bind reusable proofs to their actual output bytes, including an empty set."""
    if not directory.is_dir() or directory.is_symlink():
        raise ValueError("Missing/linked artifact directory")
    _artifact_archive_index(directory)
    entries = {}
    for path in sorted(directory.rglob("*")):
        if path.is_symlink():
            raise ValueError("Linked artifact cannot be reused")
        if path.is_file():
            entries[path.relative_to(directory).as_posix()] = _file_sha(path)
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
                outputs[path.relative_to(root).as_posix()] = {"sha256": _file_sha(path),
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
        archive_index = _artifact_archive_index(artifacts)
        recorded_archive = item.get("archived_output_fingerprint")
        if archive_index is not None:
            members = {row['path']: {'sha256': row['sha256'], 'size': row['size']}
                       for row in archive_index['members']}
            # This ledger comes from the native changed-output observation,
            # independently of ZIP/index metadata, including isolated lanes.
            if recorded_archive != members:
                return None
            live = item.get("live_output_fingerprint") or {}
            if live and any(live.get(str(ROOT / name)) != row['sha256']
                            for name, row in members.items()):
                return None
        elif recorded_archive:
            return None
        for name, expected in (item.get("live_output_fingerprint") or {}).items():
            path = Path(name)
            actual = (_file_sha(path) if path.is_file() and not path.is_symlink()
                      else "non_regular" if path.exists() or path.is_symlink() else "deleted")
            if actual != expected:
                return None
        log.write_text(text)
        return {**item["result"], "duration_seconds": 0, "reused": True,
                "started_at_unix": time.time(), "ended_at_unix": time.time(),
                "original_duration_seconds": item["result"].get("duration_seconds"),
                "verified_commit": item["commit"], "artifact_directory": item["artifact_directory"]}
    except (OSError, KeyError, ValueError, TypeError, zipfile.BadZipFile, zlib.error, EOFError, RuntimeError):
        return None


def isolated_workspace(destination, files, setup_log=None):
    diagnostics = bytearray()

    def git(root, *arguments, optional=False):
        result = subprocess.run(["git", "-C", str(root), *arguments],
                                capture_output=True, timeout=60,
                                env={**os.environ, "GIT_NO_LAZY_FETCH": "1"})
        diagnostics.extend(result.stdout + result.stderr)
        if result.returncode and not (optional and result.returncode == 1):
            raise subprocess.CalledProcessError(result.returncode, result.args,
                                                output=result.stdout, stderr=result.stderr)
        return result.stdout.decode().strip()

    def git_path(root, name):
        value = Path(git(root, "rev-parse", "--git-path", name))
        return value if value.is_absolute() else root / value

    try:
        # Git may disable local clone optimization for a promisor source even
        # with --shared --no-checkout, then upload-pack tries to fetch missing
        # historical blobs. Build only local metadata: no clone/pack transport
        # and no checkout is needed to borrow the parent's available objects.
        object_format = git(ROOT, "rev-parse", "--show-object-format")
        destination.mkdir(parents=True, exist_ok=False)
        git(destination, "init", "--quiet", "--object-format=" + object_format)
        objects = git_path(ROOT, "objects").resolve()
        if "\n" in str(objects) or "\r" in str(objects):
            raise ValueError("Isolation object directory cannot contain newlines")
        alternates = git_path(destination, "objects/info/alternates")
        alternates.parent.mkdir(parents=True, exist_ok=True)
        alternates.write_text(str(objects) + "\n")
        for line in git(ROOT, "for-each-ref", "--format=%(refname) %(objectname) %(symref)").splitlines():
            name, oid, *symbolic = line.split()
            reference = git_path(destination, name)
            reference.parent.mkdir(parents=True, exist_ok=True)
            reference.write_text(("ref: " + symbolic[0] if symbolic else oid) + "\n")
        for name in ("HEAD", "shallow"):
            source = git_path(ROOT, name)
            if source.is_file():
                shutil.copy2(source, git_path(destination, name))
        # Keep Git's missing-promised-object semantics without copying any
        # credential-bearing remote URL or contacting the original service.
        git(destination, "config", "remote.origin.url", str(ROOT))
        git(destination, "config", "remote.origin.fetch", "+refs/heads/*:refs/remotes/origin/*")
        promisors = git(ROOT, "config", "--type=bool", "--get-regexp", r"^remote\..*\.promisor$", optional=True)
        if any(line.endswith(" true") for line in promisors.splitlines()):
            git(destination, "config", "remote.origin.promisor", "true")
            git(destination, "config", "remote.origin.partialclonefilter", "blob:none")
        # The parent's real index retains staged additions/deletions/conflicts,
        # intent-to-add and skip-worktree bits. Rebuilding it from HEAD would
        # change Git semantics and resurrect a staged deletion in the lane.
        source_index = git_path(ROOT, "index")
        target_index = git_path(destination, "index")
        if source_index.is_file():
            shutil.copy2(source_index, target_index)
            shared_index = git(ROOT, "rev-parse", "--shared-index-path")
            if shared_index:
                shared_index = Path(shared_index)
                if not shared_index.is_absolute():
                    shared_index = ROOT / shared_index
                shutil.copy2(shared_index, target_index.parent / shared_index.name)
        else:
            git(destination, "read-tree", "--empty")
        for key in ("core.sparseCheckout", "core.sparseCheckoutCone", "index.sparse"):
            value = git(ROOT, "config", "--type=bool", "--get", key, optional=True)
            if value:
                git(destination, "config", key, value)
        for name in ("info/sparse-checkout", "info/exclude", "info/attributes"):
            source = git_path(ROOT, name)
            if source.is_file():
                target = git_path(destination, name)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
        excludes = git(ROOT, "config", "--path", "--get", "core.excludesFile", optional=True)
        if excludes:
            exclude_path = Path(excludes)
            if not exclude_path.is_absolute():
                exclude_path = ROOT / exclude_path
            # Preserve effective ignore bytes without pointing a lane at a
            # mutable file in the parent checkout or another lane.
            target = git_path(destination, "info/isolated-excludes")
            target.parent.mkdir(parents=True, exist_ok=True)
            if exclude_path.is_file():
                shutil.copy2(exclude_path, target)
            git(destination, "config", "core.excludesFile", str(target))
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        output = (getattr(error, "stdout", None) or b"") + (getattr(error, "stderr", None) or b"")
        if not diagnostics.endswith(output):
            diagnostics.extend(output)
        if setup_log is not None:
            Path(setup_log).write_bytes(diagnostics)
        raise RuntimeError("Isolation clone failed: " + diagnostics.decode(errors="replace")[-4000:]) from error
    if setup_log is not None:
        Path(setup_log).write_bytes(diagnostics)
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


def execute_checks(data, ids, folder, jobs=1, reuse=False, commit="", hash_cache=None):
    """Each lane has its own Godot import cache, user data and generated artifacts."""
    files = source_files()
    identity = toolchain_identity()
    source_hashes = hash_cache if hash_cache is not None else SourceHashCache()
    snapshot = {path: source_hashes.digest(ROOT / path) for path in files}
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
                if input_digest({"argv": []}, source_files(root), identity, root=root, hash_cache=source_hashes) != source_before:
                    raise RuntimeError("Validation lane source differs from frozen snapshot")
                artifact_paths = ["build/verification", *check.get("artifact_paths", [])]
                collect_outputs = check.get("cacheable", False) or root != ROOT or bool(check.get("artifact_paths"))
                before_outputs = verification_outputs(root, folder, artifact_paths) if collect_outputs else {}
                result = run_check(check, log, root, env)
                if input_digest({"argv": []}, source_files(root), identity, root=root, hash_cache=source_hashes) != source_before:
                    result["status"] = "failed"
                    result["reason"] = "Check modified frozen source; result cannot approve later consumers"
                artifacts = folder / "artifacts" / name
                artifacts.mkdir(parents=True, exist_ok=True)
                # Keep the real log even for runners whose entire proof is stdout.
                shutil.copy2(log, artifacts / "check.log")
                live_outputs = {}
                archived_outputs = {}
                if collect_outputs:
                    after_outputs = verification_outputs(root, folder, artifact_paths)
                    changed_outputs = {path: after_outputs[path]["sha256"] if path in after_outputs else "deleted"
                                       for path in set(before_outputs) | set(after_outputs)
                                       if before_outputs.get(path) != after_outputs.get(path)}
                    archived_outputs = {
                        path: {'sha256': fingerprint, 'size': after_outputs[path]['size']}
                        for path, fingerprint in changed_outputs.items()
                        if fingerprint != 'deleted' and Path(path).suffix == '.json'
                        and after_outputs[path]['size'] >= ARTIFACT_JSON_THRESHOLD}
                    collect_artifacts(root, artifacts, changed_outputs)
                    if root == ROOT:
                        live_outputs = {str(root / path): value for path, value in changed_outputs.items()}
                result["artifact_directory"] = str(artifacts)
                result["reused"] = False
                if result["status"] == "passed" and check.get("cacheable", False):
                    text = log.read_text(errors="replace")
                    cached = {"input_digest": digest, "result": result, "commit": commit, "log": text,
                              "log_sha256": hashlib.sha256(text.encode()).hexdigest(),
                              "artifact_directory": str(artifacts),
                              "live_output_fingerprint": live_outputs,
                              "archived_output_fingerprint": archived_outputs,
                              "artifact_fingerprint": artifact_fingerprint(artifacts)}
                    temporary = cache_file.with_suffix(".tmp")
                    temporary.write_text(json.dumps(cached))
                    temporary.replace(cache_file)
            results[name] = {"id": name, "argv": check["argv"], "timeout_seconds": check["timeout_seconds"],
                             "input_digest": digest, "log": log.name, **result}
            print(f"{name}: {result['status']}", flush=True)
            if result["status"] != "passed":
                break
    workspace_root = ROOT / "build/verification/workspaces"
    workspace_root.mkdir(parents=True, exist_ok=True)
    if jobs > 1:
        payload = sum((ROOT / name).stat().st_size for name in files if (ROOT / name).is_file())
        payload += sum(path.stat().st_size for path in (ROOT / ".godot").rglob("*") if path.is_file())
        required = int(payload * len(lanes) * 1.1) + 32 * 1024 * 1024 * len(lanes)
        available = shutil.disk_usage(workspace_root).free
        if available < required:
            raise RuntimeError(f"Isolation storage preflight: need {required} bytes, available {available}; no lane launched")
    with tempfile.TemporaryDirectory(prefix="gunman-checks-", dir=workspace_root) as temporary:
        if jobs > 1:
            workspaces = []
            for index, names in enumerate(lanes):
                root = Path(temporary) / str(index)
                env = isolated_workspace(root, files, setup_log=folder / f"lane-{index}-setup.log")
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
    # Final approval always reads every source byte again, independent of stat reuse.
    if input_digest({"argv": []}, source_files(), identity) != source_before:
        raise RuntimeError("Source changed during validation; results cannot approve the current source")
    return [results[name] for name in ids if name in results]

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


def lane_checks(data, ids, lane):
    return [name for name in ids if bool(data["checks"][name].get("serial", False)) == (lane == "serial")]


def bind_lane_logs(data, checks, folder):
    for item in checks:
        item["success_pattern"] = data["checks"][item["id"]]["success_pattern"]
        item["log_sha256"] = hashlib.sha256((folder / item["log"]).read_bytes()).hexdigest()


def proof_file(path):
    """Keep evidence inside ROOT/build; inspect links before resolving evidence.

    ROOT itself may be reached through an OS/workspace alias. Only its trusted
    root is resolved; every evidence component below it must be unlinked.
    """
    root = ROOT.resolve()
    path = Path(path)
    if ".." in path.parts:
        raise ValueError("Phase proof path must not traverse parents")
    if not path.is_absolute():
        path = ROOT.absolute() / path
    try:
        relative = path.relative_to(ROOT.absolute())
    except ValueError:
        try:
            relative = path.relative_to(root)
        except ValueError as error:
            raise ValueError("Phase proof path must be inside ROOT/build") from error
    if not relative.parts or relative.parts[0] != "build":
        raise ValueError("Phase proof path must be inside ROOT/build")
    current = root
    for part in relative.parts:
        current = current / part
        if current.is_symlink():
            raise ValueError("Linked phase proof path")
    try:
        regular = stat.S_ISREG(current.lstat().st_mode)
    except OSError as error:
        raise ValueError("Missing or non-regular phase proof file") from error
    if not regular:
        raise ValueError("Missing or non-regular phase proof file")
    return current


def verify_lane_reports(data, profiles, paths, metadata, inventory):
    """Verify two fresh phase proofs against this checkout; never execute checks."""
    ids = resolve_checks(data, profiles)
    manifest_hash = hashlib.sha256(MANIFEST.read_bytes()).hexdigest()
    reports, references, results = {}, [], {}
    identity = None
    tokens = set()
    for path in paths:
        path = proof_file(path)
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
            log = proof_file(path.parent / log_name)
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
    source_hashes = SourceHashCache()
    report["working_files"] = {
        path: source_hashes.digest(ROOT / path)
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
            inventory = source_inventory(hash_cache=source_hashes)
            metadata = {key: report[key] for key in ("commit", "git_status", "diff", "untracked", "working_files")}
            report.update(requested_checks=requested_ids, source_files=inventory,
                          partial=bool(args.lane), approval_scope="partial" if args.lane else "selected_profiles_technical")
            if args.verify_lanes:
                report.update(verify_lane_reports(data, profiles, args.verify_lanes, metadata, inventory))
                for reference in report["lane_reports"]:
                    phase_path = proof_file(reference["path"])
                    for name in lane_checks(data, requested_ids, reference["lane"]):
                        destination = folder / (name + ".log")
                        shutil.copy2(proof_file(phase_path.parent / (name + ".log")), destination)
                        item = next(item for item in report["checks"] if item["id"] == name)
                        if hashlib.sha256(destination.read_bytes()).hexdigest() != item["log_sha256"]:
                            raise RuntimeError("Phase log changed during verification")
                    if hashlib.sha256(proof_file(phase_path).read_bytes()).hexdigest() != reference["sha256"]:
                        raise RuntimeError("Phase report changed during verification")
                report.update(source_files_after=source_inventory(), jobs=1, release=True)
                if report["source_files_after"] != inventory or git_metadata() != metadata:
                    raise RuntimeError("Source/Git changed during lane verification")
                report.update(status="passed", wall_seconds=round(time.monotonic() - started, 3))
                print("HARNESS LANES: verified complete fresh selected-profile coverage (technical only)", flush=True)
                return 0
            report.update(lane=args.lane, toolchain=toolchain_identity(), python_executable=sys.executable)
        report["checks"] = execute_checks(data, ids, folder, args.jobs, args.reuse and not args.release, report["commit"], hash_cache=source_hashes)
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
