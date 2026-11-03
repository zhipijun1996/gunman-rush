#!/usr/bin/env python3
"""Plan and explicitly hydrate selected Harness inputs using its existing preflight.

This is an availability plan, not a new dependency scanner or a test PASS.
Only absent skip-worktree files from the exact HEAD/index can be restored.
"""
import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import time

import harness
import production_loop as production

ROOT = Path(__file__).resolve().parents[1]


class InputError(ValueError):
    def __init__(self, message, details=None):
        super().__init__(message)
        self.details = details or {}


def git(root, *args, lazy=False, input=None):
    command = ['git', *([] if lazy else ['--no-lazy-fetch']), '-C', str(root), *args]
    return subprocess.check_output(command, input=input, stderr=subprocess.PIPE, timeout=60)


@contextmanager
def preflight_root(root):
    # The existing preflight reads these same worktree globals. No check runs.
    previous = (production.ROOT, harness.ROOT, harness.MANIFEST, production.quality.ROOT)
    try:
        production.ROOT = harness.ROOT = production.quality.ROOT = root
        harness.MANIFEST = root / 'tools/harness/profiles.json'
        yield
    finally:
        production.ROOT, harness.ROOT, harness.MANIFEST, production.quality.ROOT = previous


def safe_path(root, name):
    if (not isinstance(name, str) or not name or '\\' in name or ':' in name
            or any(ord(c) < 32 for c in name) or Path(name).is_absolute()
            or any(part in ('', '.', '..', '.git') for part in name.split('/'))):
        raise InputError('Unsafe required input path: ' + repr(name))
    path = root / name
    for parent in (path, *path.parents):
        if parent == root.parent:
            break
        if parent.is_symlink():
            raise InputError('Symlink input or ancestor: ' + name)
    return path


def selected_checks(manifest, checks, profiles):
    if not checks and not profiles:
        raise InputError('Select at least one explicit --check or --profile')
    if any(name not in manifest['checks'] for name in checks):
        raise InputError('Unknown Harness check')
    if any(name not in manifest['profiles'] for name in profiles):
        raise InputError('Unknown Harness profile; auto is not an explicit input contract')
    return list(dict.fromkeys([*harness.resolve_checks(manifest, profiles), *checks]))


def repository_state(root, commit, paths=()):
    actual = git(root, 'rev-parse', '--show-toplevel').decode().strip()
    if Path(actual).resolve() != root:
        raise InputError('--root must name the Git worktree root')
    head = git(root, 'rev-parse', '--verify', 'HEAD^{commit}').decode().strip()
    requested = git(root, 'rev-parse', '--verify', commit + '^{commit}').decode().strip()
    if head != requested or not re.fullmatch(r'[0-9a-f]{40}', head):
        raise InputError('Requested commit must be the exact current SHA-1 HEAD')
    tree = {}
    tree_paths = ['--', *paths] if paths else []
    index_paths = ['--', *(':(literal)' + name for name in paths)] if paths else []
    for entry in git(root, 'ls-tree', '-r', '-z', '--full-tree', head, *tree_paths).split(b'\0'):
        if entry:
            metadata, name = entry.split(b'\t', 1)
            mode, kind, oid = metadata.decode().split()
            tree[name.decode()] = {'mode': mode, 'type': kind, 'blob': oid}
    index = {}
    for entry in git(root, 'ls-files', '--stage', '-z', *index_paths).split(b'\0'):
        if entry:
            metadata, name = entry.split(b'\t', 1)
            mode, oid, stage = metadata.decode().split()
            index.setdefault(name.decode(), []).append((mode, oid, stage))
    flags = {entry[2:].decode(): chr(entry[0]) for entry in git(root, 'ls-files', '-v', '-z', *index_paths).split(b'\0') if entry}
    return head, tree, index, flags


def blob_sizes(root, oids):
    oids = sorted(set(oids))
    if not oids:
        return {}
    # Metadata only for selected objects. --no-lazy-fetch prevents this plan
    # from implicitly downloading evidence bytes from a promisor remote.
    raw = git(root, 'cat-file', '--batch-check=%(objectname) %(objecttype) %(objectsize)', input=('\n'.join(oids) + '\n').encode())
    result = {}
    for line in raw.decode().splitlines():
        parts = line.split()
        if len(parts) == 3 and parts[1] == 'blob':
            result[parts[0]] = int(parts[2])
        elif len(parts) == 2 and parts[1] == 'missing':
            result[parts[0]] = None
        else:
            raise InputError('Required input object is not a readable Git blob: ' + line)
    return result


def sparse_enabled(root):
    try:
        return git(root, 'config', '--bool', '--get', 'core.sparseCheckout').strip() == b'true'
    except subprocess.CalledProcessError as error:
        if error.returncode == 1:
            return False
        raise


def make_plan(root=ROOT, checks=(), profiles=(), commit='HEAD'):
    root = Path(root).resolve()
    head, tree, index, flags = repository_state(root, commit)
    structure = sorted(set(tree) ^ set(index))
    if structure or any(len(entries) != 1 or entries[0][2] != '0' for entries in index.values()):
        raise InputError('HEAD/index path structure changed or has unmerged entries; commit or resolve it before input hydration: ' + ', '.join(structure[:20]))
    sparse = sparse_enabled(root)
    with preflight_root(root):
        manifest = production.check_manifest_metadata()
        selected = selected_checks(manifest, checks, profiles)
        preflight = production.required_input_preflight({'checks': selected, 'read_only': True, 'allowed_paths': []})
    rows, blockers = [], []
    for item in preflight['missing_tracked_inputs']:
        name = item['path']
        path = safe_path(root, name)
        record = tree.get(name)
        if not record or record['type'] != 'blob' or record['mode'] not in ('100644', '100755'):
            raise InputError('Required input is not a regular file in exact HEAD: ' + name)
        if index.get(name) != [(record['mode'], record['blob'], '0')]:
            raise InputError('Required input index differs from exact HEAD: ' + name)
        eligible = (sparse and item['reason'] == 'sparse_unmaterialized' and flags.get(name, '').upper() == 'S'
                    and not path.exists() and not path.is_symlink())
        row = {'commit': head, 'path': name, 'blob': record['blob'], 'mode': record['mode'],
               'git_index_state': flags.get(name), 'required_by': item['required_by'],
               'reason': item['reason'], 'materializable': eligible}
        rows.append(row)
        if not eligible:
            blockers.append({'path': name, 'reason': 'not_an_absent_sparse_input', 'detail': item['reason']})
    sizes = blob_sizes(root, [row['blob'] for row in rows])
    for row in rows:
        row['size'] = sizes[row['blob']]
        row['object_available'] = row['size'] is not None
    blockers.extend(preflight['uncertain_inputs'])
    blockers.extend(preflight['import_metadata_risks'])
    return {'status': 'blocked' if blockers else ('needs_materialization' if rows else 'ready'),
            'approval_scope': 'input_availability_only', 'tests_executed': False, 'commit': head, 'checks': selected,
            'inputs': rows, 'known_bytes': sum(row['size'] or 0 for row in rows),
            'unknown_size_objects': sorted({row['blob'] for row in rows if row['size'] is None}),
            'blockers': blockers, 'preflight': preflight,
            'limits': 'Missing-input plan from the existing preflight, not a complete static dependency graph. No checks ran. Unknown object sizes stay explicit until --materialize obtains only those selected blobs.'}


def restore_input(root, row):
    root = Path(root).resolve()
    name, commit = row['path'], row['commit']
    path = safe_path(root, name)
    head, tree, index, flags = repository_state(root, commit, (name,))
    expected = (row['mode'], row['blob'], '0')
    if (not sparse_enabled(root) or head != commit or index.get(name) != [expected] or tree.get(name, {}).get('blob') != row['blob']
            or flags.get(name, '').upper() != 'S' or path.exists() or path.is_symlink()):
        raise InputError('Input changed, is locally present, or is no longer an absent sparse file: ' + name)
    path.parent.mkdir(parents=True, exist_ok=True)
    safe_path(root, name)
    descriptor, temporary = tempfile.mkstemp(prefix='.cloud-input-', dir=path.parent)
    temporary = Path(temporary)
    try:
        with os.fdopen(descriptor, 'wb') as target:
            # Explicit materialization is the only operation permitting lazy
            # object retrieval. Git is asked for one exact committed blob.
            result = subprocess.run(['git', '-C', str(root), 'cat-file', 'blob', row['blob']], stdout=target, stderr=subprocess.PIPE, timeout=300)
        if result.returncode:
            raise InputError('Required blob retrieval failed: ' + name + ': ' + result.stderr.decode(errors='replace')[-1000:])
        amount = temporary.stat().st_size
        digest = hashlib.sha1(('blob ' + str(amount) + '\0').encode())
        with temporary.open('rb') as stream:
            while block := stream.read(1024 * 1024):
                digest.update(block)
        if digest.hexdigest() != row['blob'] or (row['size'] is not None and amount != row['size']):
            raise InputError('Retrieved input blob SHA/size differs from the plan: ' + name)
        # Recheck after the download, then publish with a no-overwrite primitive.
        head, tree, index, flags = repository_state(root, commit, (name,))
        safe_path(root, name)
        if not sparse_enabled(root) or index.get(name) != [expected] or flags.get(name, '').upper() != 'S':
            raise InputError('Input index changed during retrieval: ' + name)
        temporary.chmod(0o755 if row['mode'] == '100755' else 0o644)
        os.link(temporary, path)
        return {**row, 'size': amount, 'status': 'materialized'}
    finally:
        temporary.unlink(missing_ok=True)


def emit_progress(callback, phase, **fields):
    if callback:
        callback({'phase': phase, **fields})


def materialize(root=ROOT, checks=(), profiles=(), commit='HEAD', *, progress=None):
    root = Path(root).resolve()
    started = time.monotonic()
    emit_progress(progress, 'input_plan_started')
    initial = make_plan(root, checks, profiles, commit)
    emit_progress(progress, 'input_plan_complete', files=len(initial['inputs']), seconds=round(time.monotonic() - started, 3))
    pinned = initial['commit']
    rounds, restored, fetches = [], [], []
    plan = initial
    # Each round only restores missing inputs discovered by the real preflight.
    # Newly readable indexes can expose further selected dependency edges.
    while plan['inputs'] and not plan['blockers']:
        rounds.append(plan)
        if plan['unknown_size_objects']:
            try:
                fetches.extend(prefetch_blobs(root, plan['unknown_size_objects'], progress=progress))
            except InputError as error:
                error.details.update(materialized=restored, rounds=rounds)
                raise
        for number, row in enumerate(plan['inputs'], 1):
            restored.append(restore_input(root, row))
            if number % 100 == 0 or number == len(plan['inputs']):
                emit_progress(progress, 'input_restore_progress', round=len(rounds), files=number,
                              total=len(plan['inputs']), bytes=sum(item['size'] for item in restored),
                              wall_seconds=round(time.monotonic() - started, 3))
        plan = make_plan(root, checks, profiles, pinned)
    return {**plan, 'materialized': restored, 'rounds': rounds, 'prefetch': fetches,
            'materialized_bytes': sum(row['size'] for row in restored),
            'sparse_patterns_changed': False, 'tests_executed': False}


def prefetch_blobs(root, oids, batch_size=32, *, progress=None):
    """Fetch only selected absent blobs, with bounded wants per Git request."""
    if not 1 <= batch_size <= 64 or any(not re.fullmatch(r'[0-9a-f]{40}', oid) for oid in oids):
        raise InputError('Invalid bounded blob prefetch request')
    try:
        configured = git(root, 'config', '--get-regexp', r'^remote\..*\.promisor$').decode().splitlines()
    except subprocess.CalledProcessError as error:
        if error.returncode != 1:
            raise
        configured = []
    remotes = [line.split()[0][len('remote.'):-len('.promisor')] for line in configured if line.split()[-1] == 'true']
    if len(remotes) != 1:
        raise InputError('Selected missing blobs require exactly one configured promisor remote; no full fetch is attempted')
    unknown = [oid for oid, size in blob_sizes(root, oids).items() if size is None]
    events = []
    for offset in range(0, len(unknown), batch_size):
        batch = unknown[offset:offset + batch_size]
        # Match Git's promisor lazy-fetch transport: ordinary negotiation may
        # declare a reachable missing blob unnecessary and then fail its
        # connectivity check. Noop requests precisely these explicit wants.
        command = ['git', '-c', 'fetch.negotiationAlgorithm=noop', '-c', 'fetch.bundleURI=',
                   '-C', str(root), 'fetch', '--no-tags', '--no-write-fetch-head',
                   '--recurse-submodules=no', '--filter=blob:none', '--stdin', remotes[0]]
        event = {'remote': remotes[0], 'objects': batch, 'status': 'running', 'argv': command}
        events.append(event)
        started = time.monotonic()
        emit_progress(progress, 'input_fetch_started', batch=offset // batch_size + 1, objects=len(batch))
        try:
            result = subprocess.run(command,
                                    input=('\n'.join(batch) + '\n').encode(), capture_output=True, timeout=300)
            event['exit_code'] = result.returncode
            if result.returncode:
                raise InputError('Bounded selected-blob fetch failed: ' + result.stderr.decode(errors='replace')[-1500:])
            if any(size is None for size in blob_sizes(root, batch).values()):
                raise InputError('Selected blob still absent after bounded prefetch')
            event['status'] = 'fetched'
            event['seconds'] = round(time.monotonic() - started, 3)
            emit_progress(progress, 'input_fetch_complete', batch=offset // batch_size + 1,
                          objects=len(batch), seconds=event['seconds'])
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            event.update(status='failed', error=str(error))
            raise InputError(str(error), {'prefetch': events}) from error
    return events


def regular_file(path):
    path = Path(path).absolute()
    if any(parent.is_symlink() for parent in (path, *path.parents)):
        raise InputError('Symlink bundle input or ancestor: ' + str(path))
    if not stat.S_ISREG(path.stat().st_mode):
        raise InputError('Bundle input is not a regular file: ' + str(path))
    return path


def file_hashes(path, *, progress=None):
    path = regular_file(path)
    size = path.stat().st_size
    blob = hashlib.sha1(('blob ' + str(size) + '\0').encode())
    digest = hashlib.sha256()
    count = 0
    last_progress = time.monotonic()
    with path.open('rb') as stream:
        while block := stream.read(1024 * 1024):
            count += len(block)
            blob.update(block)
            digest.update(block)
            if progress and time.monotonic() - last_progress >= 10:
                emit_progress(progress, 'bundle_archive_verify_progress', bytes=count, total=size)
                last_progress = time.monotonic()
    if count != size:
        raise InputError('Bundle input size changed while reading: ' + str(path))
    return size, blob.hexdigest(), digest.hexdigest()


def tar_required_bytes(rows):
    """Exact logical size of the uncompressed PAX archive written below."""
    total = 0
    for row in rows:
        info = tarfile.TarInfo(row['path'])
        info.size, info.mode, info.mtime = row['size'], (0o755 if row['mode'] == '100755' else 0o644), 0
        total += len(info.tobuf(format=tarfile.PAX_FORMAT)) + ((row['size'] + 511) // 512) * 512
    total += 1024  # two end-of-archive blocks, then the writer's record padding.
    return ((total + tarfile.RECORDSIZE - 1) // tarfile.RECORDSIZE) * tarfile.RECORDSIZE


def bundle_disk_snapshot(path, phase, required_bytes, *, progress=None, started=None, **fields):
    """Report the actual destination volume; reject only a proved byte deficit.

    Required bytes are an allocation lower bound: metadata, block rounding,
    concurrent users and later test output can require more. This is not a claim
    that the runner has adequate capacity merely because this check passes.
    """
    volume = Path(path)
    while not volume.exists():
        volume = volume.parent
    usage = shutil.disk_usage(volume)
    report = {'volume_path': str(volume), 'total_bytes': usage.total, 'used_bytes': usage.used,
              'free_bytes': usage.free, 'required_additional_bytes': required_bytes,
              'allocation_lower_bound': True, **fields}
    if started is not None:
        report['wall_seconds'] = round(time.monotonic() - started, 3)
    emit_progress(progress, phase, **report)
    if usage.free < required_bytes:
        raise InputError('Insufficient disk space for selected input bundle: ' + phase, report)
    return report


def bundle_contract(root, checks, profiles, commit, execution_plan, run_id):
    if not re.fullmatch(r'[1-9][0-9]*', str(run_id)):
        raise InputError('A concrete positive GitHub run_id is required')
    head, tree, index, flags = repository_state(root, commit)
    if set(tree) != set(index) or any(index[name] != [(row['mode'], row['blob'], '0')]
                                     for name, row in tree.items()):
        raise InputError('HEAD/index structure changed before bundle operation')
    plan_path = Path(execution_plan)
    plan_path = plan_path if plan_path.is_absolute() else root / plan_path
    try:
        plan_name = plan_path.relative_to(root).as_posix()
    except ValueError:
        raise InputError('Execution plan must be under this worktree build/') from None
    safe_path(root, plan_name)
    if not plan_name.startswith('build/'):
        raise InputError('Execution plan must be under this worktree build/')
    plan_path = regular_file(plan_path)
    plan_bytes = plan_path.read_bytes()
    plan = json.loads(plan_bytes)
    with preflight_root(root):
        manifest = production.check_manifest_metadata()
        selected = selected_checks(manifest, checks, profiles)
    # The existing planner puts portable/docs checks first. Input coverage must
    # equal the complete profile, while the actual plan/CLI order stays bound
    # exactly below and by the original plan bytes' SHA; lane execution is owned
    # by the unchanged Harness profile, not by this input transport.
    full = manifest['profiles']['full']
    if (not isinstance(plan, dict) or plan.get('source_commit') != head or plan.get('ci_route') != 'full_lanes'
            or plan.get('checks') != selected or len(selected) != len(full) or set(selected) != set(full)):
        raise InputError('Bundle requires the same-source exact full execution plan')
    return head, tree, index, flags, selected, hashlib.sha256(plan_bytes).hexdigest()


def receipt_inputs(root, receipt, head, selected):
    """Read the original materializer's successful receipt, never a new scanner."""
    checks = receipt.get('checks') if isinstance(receipt, dict) else None
    if (not isinstance(receipt, dict) or receipt.get('commit') != head or receipt.get('status') != 'ready'
            or receipt.get('approval_scope') != 'input_availability_only'
            or receipt.get('tests_executed') is not False
            or not isinstance(checks, list) or not all(isinstance(item, str) for item in checks)
            or len(checks) != len(set(checks)) or not set(checks) <= set(selected)
            or not isinstance(receipt.get('materialized'), list)):
        raise InputError('Receipt is not a successful same-source selected materialization')
    rows = {}
    for item in receipt['materialized']:
        if not isinstance(item, dict):
            raise InputError('Invalid materialized input receipt row')
        row = {key: item.get(key) for key in ('path', 'mode', 'blob', 'size')}
        safe_path(root, row['path'])
        if (item.get('commit') != head or item.get('status') != 'materialized'
                or row['mode'] not in ('100644', '100755')
                or not isinstance(row['blob'], str) or not re.fullmatch(r'[0-9a-f]{40}', row['blob'])
                or type(row['size']) is not int or row['size'] < 0 or row['path'] in rows):
            raise InputError('Invalid or duplicate materialized input receipt row')
        rows[row['path']] = row
    return rows


def validate_bundle_row(root, row, head, tree, index):
    if not isinstance(row, dict):
        raise InputError('Bundle input entry must be an object')
    name = row.get('path')
    safe_path(root, name)
    if (set(row) != {'path', 'mode', 'blob', 'size', 'sha256'}
            or row['mode'] not in ('100644', '100755')
            or type(row['size']) is not int or row['size'] < 0
            or not isinstance(row['sha256'], str) or not re.fullmatch(r'[0-9a-f]{64}', row['sha256'])
            or tree.get(name) != {'mode': row['mode'], 'type': 'blob', 'blob': row['blob']}
            or index.get(name) != [(row['mode'], row['blob'], '0')]):
        raise InputError('Bundle path/mode/blob differs from current HEAD/index: ' + str(name))


def verify_present_bundle_file(root, row):
    path = safe_path(root, row['path'])
    size, blob, sha256 = file_hashes(path)
    mode = path.stat().st_mode
    if (size != row['size'] or blob != row['blob'] or sha256 != row['sha256']
            or bool(mode & 0o111) != (row['mode'] == '100755') or mode & 0o7000):
        raise InputError('Existing bundle input differs; never overwritten: ' + row['path'])


def verify_archive_end(path, offset, size):
    # tarfile stops at the first end marker. Do not silently admit a second
    # archive or hidden payload after that marker when outer hashes are rebound.
    if size - offset < 1024:
        raise InputError('Bundle archive is missing its complete end marker')
    read = 0
    with path.open('rb') as stream:
        stream.seek(offset)
        while block := stream.read(1024 * 1024):
            read += len(block)
            if block.strip(b'\0'):
                raise InputError('Unexpected data after final bundle member')
    if read != size - offset:
        raise InputError('Bundle archive size changed during validation')


class DigestWriter:
    def __init__(self, stream):
        self.stream, self.digest, self.size = stream, hashlib.sha256(), 0

    def write(self, block):
        count = self.stream.write(block)
        if count != len(block):
            raise OSError('Incomplete bundle archive write')
        self.digest.update(block)
        self.size += count
        return count


class BlobReader:
    def __init__(self, stream, size):
        self.stream, self.size, self.count = stream, size, 0
        self.blob = hashlib.sha1(('blob ' + str(size) + '\0').encode())
        self.digest = hashlib.sha256()

    def read(self, count):
        data = self.stream.read(count)
        self.count += len(data)
        self.blob.update(data)
        self.digest.update(data)
        return data


def export_bundle(root, checks, profiles, commit, execution_plan, run_id, receipts, destination, *, progress=None):
    """Transport only files restored by the original prepare preflight receipts."""
    root = Path(root).resolve()
    started = time.monotonic()
    head, tree, index, flags, selected, plan_sha = bundle_contract(root, checks, profiles, commit, execution_plan, run_id)
    destination = Path(destination)
    destination = destination if destination.is_absolute() else root / destination
    try:
        relative = destination.relative_to(root).as_posix()
    except ValueError:
        raise InputError('Bundle output must be a new directory under build/') from None
    if not relative.startswith('build/'):
        raise InputError('Bundle output must be a new directory under build/')
    safe_path(root, relative)
    if destination.exists():
        raise InputError('Bundle output already exists')
    rows, sources, source_bytes = {}, [], {}
    if not receipts:
        raise InputError('Bundle export requires original materialization receipts')
    for receipt_path in receipts:
        receipt_path = Path(receipt_path)
        receipt_path = receipt_path if receipt_path.is_absolute() else root / receipt_path
        receipt_path = regular_file(receipt_path)
        raw = receipt_path.read_bytes()
        receipt = json.loads(raw)
        try:
            receipt_name = receipt_path.relative_to(root).as_posix()
        except ValueError:
            raise InputError('Prepare receipt must be under this worktree build/') from None
        safe_path(root, receipt_name)
        if not receipt_name.startswith('build/') or any(item['path'] == receipt_name for item in sources):
            raise InputError('Prepare receipt path must be a unique worktree build/ file')
        receipt_rows = receipt_inputs(root, receipt, head, selected)
        for name, row in receipt_rows.items():
            if name in rows and rows[name] != row:
                raise InputError('Conflicting receipt entries')
            rows[name] = row
        digest = hashlib.sha256(raw).hexdigest()
        source_bytes[digest] = raw
        sources.append({'path': receipt_name, 'sha256': digest,
                        'commit': head, 'checks': receipt['checks'], 'files': len(receipt['materialized'])})
    # Read the original preflight, rather than inventing a second dependency scanner.
    if make_plan(root, selected, (), head)['status'] != 'ready':
        raise InputError('Original selected input preflight is not ready for export')
    archive_required = tar_required_bytes(rows.values())
    disk_before = bundle_disk_snapshot(destination, 'bundle_export_disk_before',
                                       archive_required + sum(map(len, source_bytes.values())),
                                       progress=progress, started=started,
                                       archive_required_bytes=archive_required,
                                       input_bytes=sum(row['size'] for row in rows.values()))
    destination.mkdir(parents=True)
    receipt_directory = destination / 'receipts'
    receipt_directory.mkdir()
    for digest, raw in source_bytes.items():
        (receipt_directory / (digest + '.json')).write_bytes(raw)
    archive_path = destination / 'inputs.tar'
    emitted = []
    emit_progress(progress, 'bundle_export_started', files=len(rows), bytes=sum(row['size'] for row in rows.values()))
    with archive_path.open('xb') as output:
        writer = DigestWriter(output)
        with tarfile.open(fileobj=writer, mode='w|', format=tarfile.PAX_FORMAT) as archive:
            for number, row in enumerate(sorted(rows.values(), key=lambda row: row['path']), 1):
                row = {**row, 'sha256': '0' * 64}
                validate_bundle_row(root, row, head, tree, index)
                path = regular_file(safe_path(root, row['path']))
                mode = path.stat().st_mode
                if path.stat().st_size != row['size'] or bool(mode & 0o111) != (row['mode'] == '100755') or mode & 0o7000:
                    raise InputError('Prepared input size/mode changed: ' + row['path'])
                info = tarfile.TarInfo(row['path'])
                info.size, info.mode, info.mtime = row['size'], (0o755 if row['mode'] == '100755' else 0o644), 0
                with path.open('rb') as source:
                    reader = BlobReader(source, row['size'])
                    archive.addfile(info, reader)
                    if reader.count != row['size'] or reader.blob.hexdigest() != row['blob']:
                        raise InputError('Prepared input bytes differ from committed Git blob: ' + row['path'])
                    row['sha256'] = reader.digest.hexdigest()
                emitted.append(row)
                if number % 100 == 0 or number == len(rows):
                    emit_progress(progress, 'bundle_export_progress', files=number, total=len(rows),
                                  wall_seconds=round(time.monotonic() - started, 3))
    current = repository_state(root, head)
    if current[:3] != (head, tree, index):
        raise InputError('HEAD/index changed while exporting selected input bundle')
    manifest = {'schema_version': 1, 'kind': 'gunman-selected-inputs/1', 'source_commit': head,
                'source_run_id': str(run_id), 'checks': selected, 'execution_plan_sha256': plan_sha,
                'source_receipts': sources, 'files': emitted, 'archive_size': writer.size,
                'archive_sha256': writer.digest.hexdigest()}
    (destination / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    disk_after = bundle_disk_snapshot(destination, 'bundle_export_disk_after', 0,
                                      progress=progress, started=started, archive_bytes=writer.size)
    return {'status': 'ready', 'approval_scope': 'input_availability_only', 'tests_executed': False,
            'commit': head, 'checks': selected, 'source_run_id': str(run_id), 'files': len(emitted),
            'bytes': sum(row['size'] for row in emitted), 'archive_sha256': manifest['archive_sha256'],
            'archive_size': writer.size, 'export_seconds': round(time.monotonic() - started, 3),
            'storage': {'before': disk_before, 'after': disk_after}}



def cache_verified_git_blobs(root, stage, rows, *, progress=None):
    """Supply missing immutable Git objects from the fully verified staging data.

    A blob-less checkout also needs these objects for its original `git diff
    HEAD` guard. Publishing only worktree bytes would make that read lazily fetch
    the same evidence again. This writes object-cache entries only: no index,
    ref, sparse flag, filter, or remote operation is used.
    """
    started = time.monotonic()
    unique = {}
    for number, row in enumerate(rows):
        unique.setdefault(row['blob'], (number, row))
    sizes = blob_sizes(root, unique)
    missing = []
    for oid, (number, row) in unique.items():
        if sizes[oid] is None:
            missing.append((oid, number, row))
        elif sizes[oid] != row['size']:
            raise InputError('Existing Git blob cache size differs from verified input: ' + row['path'])
    raw_bytes = sum(row['size'] for _, _, row in missing)
    report = {'objects': len(missing), 'raw_bytes': raw_bytes, 'network_fetch': False,
              'cache_kind': 'verified Git blob object cache; no source/index/ref changes'}
    if not missing:
        return {**report, 'seconds': round(time.monotonic() - started, 3)}
    objects = Path(git(root, 'rev-parse', '--git-path', 'objects').decode().strip())
    objects = objects if objects.is_absolute() else root / objects
    disk_before = bundle_disk_snapshot(objects, 'bundle_git_cache_disk_before', 0,
                                      progress=progress, started=started,
                                      missing_blob_raw_bytes=raw_bytes,
                                      allocation_note='Additional zlib-compressed Git objects; actual volume usage sampled before/after, not assumed equal to raw bytes')
    # Staging leaves are generated decimal names under build/, never untrusted
    # archive paths. Relative paths avoid quoting/root-name issues in Git's
    # newline-delimited stdin-paths protocol; controls are independently denied.
    paths = [(stage / str(number)).relative_to(root).as_posix() for _, number, _ in missing]
    for path in paths:
        safe_path(root, path)
    emit_progress(progress, 'bundle_git_cache_started', objects=len(missing), raw_bytes=raw_bytes)
    try:
        result = subprocess.run(['git', '--no-lazy-fetch', '-C', str(root), 'hash-object',
                                 '--no-filters', '-w', '--stdin-paths'],
                                input=('\n'.join(paths) + '\n').encode(), capture_output=True, timeout=300)
    except subprocess.TimeoutExpired as error:
        raise InputError('Verified Git blob cache import exceeded its bounded operation', report) from error
    if result.returncode:
        raise InputError('Verified Git blob cache import failed: ' + result.stderr.decode(errors='replace')[-1500:], report)
    if result.stdout.decode(errors='replace').splitlines() != [oid for oid, _, _ in missing]:
        raise InputError('Written Git blob cache SHA differs from verified staging inputs', report)
    if blob_sizes(root, [oid for oid, _, _ in missing]) != {oid: row['size'] for oid, _, row in missing}:
        raise InputError('Verified Git blob cache is not readable after import', report)
    disk_after = bundle_disk_snapshot(objects, 'bundle_git_cache_disk_after', 0,
                                     progress=progress, started=started,
                                     missing_blob_raw_bytes=raw_bytes)
    report.update(seconds=round(time.monotonic() - started, 3),
                  storage={'before': disk_before, 'after': disk_after})
    emit_progress(progress, 'bundle_git_cache_complete', objects=len(missing), raw_bytes=raw_bytes,
                  seconds=report['seconds'])
    return report

def restore_bundle(root, checks, profiles, commit, execution_plan, run_id, bundle, *, progress=None):
    """Validate same-run data against current Git, then restore without fetching blobs."""
    root = Path(root).resolve()
    started = time.monotonic()
    head, tree, index, flags, selected, plan_sha = bundle_contract(root, checks, profiles, commit, execution_plan, run_id)
    bundle = Path(bundle)
    bundle = bundle if bundle.is_absolute() else root / bundle
    manifest_path, archive_path = regular_file(bundle / 'manifest.json'), regular_file(bundle / 'inputs.tar')
    manifest_raw = manifest_path.read_bytes()
    manifest = json.loads(manifest_raw)
    if (not isinstance(manifest, dict) or manifest.get('schema_version') != 1 or manifest.get('kind') != 'gunman-selected-inputs/1'
            or manifest.get('source_commit') != head or manifest.get('source_run_id') != str(run_id)
            or manifest.get('checks') != selected or manifest.get('execution_plan_sha256') != plan_sha
            or not isinstance(manifest.get('source_receipts'), list) or not manifest['source_receipts']):
        raise InputError('Bundle source/run/plan identity differs from this job')
    receipt_paths, receipt_rows = set(), {}
    for receipt in manifest['source_receipts']:
        if (not isinstance(receipt, dict) or set(receipt) != {'path', 'sha256', 'commit', 'checks', 'files'}
                or receipt['commit'] != head or not isinstance(receipt['path'], str)
                or not receipt['path'].startswith('build/')
                or not re.fullmatch(r'[0-9a-f]{64}', str(receipt['sha256']))
                or not isinstance(receipt['checks'], list)
                or not all(isinstance(item, str) for item in receipt['checks'])
                or len(receipt['checks']) != len(set(receipt['checks']))
                or not set(receipt['checks']) <= set(selected)
                or type(receipt['files']) is not int or receipt['files'] < 0):
            raise InputError('Invalid prepare receipt provenance in bundle')
        safe_path(root, receipt['path'])
        if receipt['path'] in receipt_paths:
            raise InputError('Duplicate prepare receipt provenance in bundle')
        receipt_paths.add(receipt['path'])
        source_raw = regular_file(bundle / 'receipts' / (receipt['sha256'] + '.json')).read_bytes()
        if hashlib.sha256(source_raw).hexdigest() != receipt['sha256']:
            raise InputError('Original prepare receipt SHA differs from bundle provenance')
        source = json.loads(source_raw)
        source_rows = receipt_inputs(root, source, head, selected)
        if source['checks'] != receipt['checks'] or len(source_rows) != receipt['files']:
            raise InputError('Original prepare receipt scope/count differs from bundle provenance')
        for name, row in source_rows.items():
            if name in receipt_rows and receipt_rows[name] != row:
                raise InputError('Conflicting original prepare receipt entries')
            receipt_rows[name] = row
    rows = manifest.get('files')
    if not isinstance(rows, list) or len(rows) > len(tree):
        raise InputError('Invalid bundle input list')
    names = []
    existing = set()
    if not sparse_enabled(root):
        raise InputError('Bundle restore requires the existing sparse checkout')
    for row in rows:
        validate_bundle_row(root, row, head, tree, index)
        names.append(row['path'])
        path = safe_path(root, row['path'])
        if path.exists():
            verify_present_bundle_file(root, row)
            existing.add(row['path'])
        elif flags.get(row['path'], '').upper() != 'S':
            raise InputError('Absent bundle path is not a sparse input: ' + row['path'])
    if names != sorted(set(names)):
        raise InputError('Bundle contains duplicate or unordered paths')
    if ({row['path']: {key: row[key] for key in ('path', 'mode', 'blob', 'size')} for row in rows}
            != receipt_rows):
        raise InputError('Bundle files differ from original prepare receipt inputs')
    # All members are independently verified in staging, including already
    # present inputs. The downloaded archive already occupies its own volume;
    # hardlink publication does not allocate a third full input copy.
    disk_before = bundle_disk_snapshot(root / 'build', 'bundle_restore_disk_before',
                                       sum(row['size'] for row in rows), progress=progress, started=started,
                                       archive_bytes=archive_path.stat().st_size,
                                       stage_required_bytes=sum(row['size'] for row in rows),
                                       git_cache_note='Verified missing Git objects are cached before publication; compressed allocation is separately observed')
    emit_progress(progress, 'bundle_archive_verify_started', files=len(rows), bytes=manifest.get('archive_size'))
    archive_verify_started = time.monotonic()
    archive_size, _, archive_sha = file_hashes(archive_path, progress=progress)
    if archive_size != manifest.get('archive_size') or archive_sha != manifest.get('archive_sha256'):
        raise InputError('Bundle archive SHA/size differs from manifest')
    archive_verified = time.monotonic()
    emit_progress(progress, 'bundle_archive_verify_complete', bytes=archive_size,
                  seconds=round(archive_verified - archive_verify_started, 3))
    published = []
    staging_parent = safe_path(root, 'build')
    staging_parent.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='selected-input-stage-', dir=staging_parent) as directory:
        stage = Path(directory)
        try:
            end_offset = 0
            with tarfile.open(archive_path, mode='r|') as archive:
                for number, row in enumerate(rows):
                    member = archive.next()
                    if (member is None or member.name != row['path'] or not member.isreg() or member.sparse is not None
                            or member.size != row['size'] or member.mode != (0o755 if row['mode'] == '100755' else 0o644)
                            or set(member.pax_headers) - {'path'}):
                        raise InputError('Invalid, missing or reordered bundle member: ' + row['path'])
                    with archive.extractfile(member) as source, (stage / str(number)).open('xb') as output:
                        reader = BlobReader(source, row['size'])
                        while block := reader.read(1024 * 1024):
                            output.write(block)
                        if (reader.count != row['size'] or reader.blob.hexdigest() != row['blob']
                                or reader.digest.hexdigest() != row['sha256']):
                            raise InputError('Bundle member differs from current Git blob/SHA: ' + row['path'])
                    (stage / str(number)).chmod(0o755 if row['mode'] == '100755' else 0o644)
                    end_offset = ((member.offset_data + member.size + 511) // 512) * 512
                    if (number + 1) % 100 == 0 or number + 1 == len(rows):
                        emit_progress(progress, 'bundle_content_verify_progress', files=number + 1, total=len(rows),
                                      wall_seconds=round(time.monotonic() - started, 3))
                if archive.next() is not None or archive.pax_headers:
                    raise InputError('Unexpected extra bundle member or global metadata')
            verify_archive_end(archive_path, end_offset, archive_size)
            staged = time.monotonic()
            git_cache = cache_verified_git_blobs(root, stage, rows, progress=progress)
            cached = time.monotonic()
            current = repository_state(root, head)
            if current[:3] != (head, tree, index) or current[3] != flags:
                raise InputError('HEAD/index changed while validating input bundle')
            for number, row in enumerate(rows):
                path = safe_path(root, row['path'])
                if row['path'] in existing:
                    verify_present_bundle_file(root, row)
                    continue
                if current[3].get(row['path'], '').upper() != 'S':
                    raise InputError('Input skip-worktree identity changed before publish')
                path.parent.mkdir(parents=True, exist_ok=True)
                safe_path(root, row['path'])
                source = stage / str(number)
                os.link(source, path)  # atomic no-overwrite; never extractall or replace.
                published.append((path, source, row))
            current = repository_state(root, head)
            if current[:3] != (head, tree, index):
                raise InputError('HEAD/index changed while publishing input bundle')
            for row in rows:
                verify_present_bundle_file(root, row)
            report = make_plan(root, selected, (), head)
            if report['status'] != 'ready':
                raise InputError('Bundle incomplete: original selected preflight is not ready', {'preflight': report})
            if repository_state(root, head)[:3] != (head, tree, index):
                raise InputError('HEAD/index changed during final selected preflight')
        except BaseException:
            # Roll back only our newly linked inodes; never remove pre-existing
            # files or a user replacement created during a failed import.
            for path, source, row in reversed(published):
                try:
                    safe_path(root, row['path'])
                    if path.exists() and not path.is_symlink() and path.stat().st_ino == source.stat().st_ino:
                        verify_present_bundle_file(root, row)
                        path.unlink()
                except (OSError, InputError):
                    pass  # Preserve a concurrent in-place edit as well as any replacement.
            raise
    finished = time.monotonic()
    disk_after = bundle_disk_snapshot(staging_parent, 'bundle_restore_disk_after', 0,
                                      progress=progress, started=started, archive_bytes=archive_size)
    emit_progress(progress, 'bundle_restore_complete', files=len(rows), bytes=sum(row['size'] for row in rows),
                  wall_seconds=round(finished - started, 3))
    return {**report, 'source_run_id': str(run_id), 'transport': 'same-run-selected-input-bundle',
            'bundle_manifest_sha256': hashlib.sha256(manifest_raw).hexdigest(), 'archive_sha256': archive_sha,
            'restored_files': len(published), 'already_identical_files': len(existing), 'files': len(rows),
            'bytes': sum(row['size'] for row in rows), 'timings': {
                'identity_manifest_existing_seconds': round(archive_verify_started - started, 3),
                'archive_verify_seconds': round(archive_verified - archive_verify_started, 3),
                'content_stage_seconds': round(staged - archive_verified, 3),
                'git_object_cache_seconds': round(cached - staged, 3),
                'publish_recheck_preflight_seconds': round(finished - cached, 3),
                'wall_seconds': round(finished - started, 3)},
            'storage': {'before': disk_before, 'after': disk_after},
            'git_object_cache': git_cache,
            'limits': 'Input availability and exact source verification only; no selected test executed or accepted.'}


def new_report_file(root, output):
    root, output = Path(root).resolve(), Path(output)
    if '..' in output.parts:
        raise InputError('Report path must not contain parent traversal')
    path = output if output.is_absolute() else root / output
    try:
        relative = path.relative_to(root).as_posix()
    except ValueError:
        raise InputError('Report output must be a new file under this worktree build/') from None
    if not relative.startswith('build/'):
        raise InputError('Report output must be a new file under this worktree build/')
    path = safe_path(root, relative)
    if path.exists():
        raise InputError('Report output already exists; refusing overwrite: ' + relative)
    path.parent.mkdir(parents=True, exist_ok=True)
    safe_path(root, relative)
    return path.open('x')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='append', default=[])
    parser.add_argument('--profile', action='append', default=[])
    parser.add_argument('--commit', default='HEAD')
    parser.add_argument('--root', type=Path, default=ROOT)
    operation = parser.add_mutually_exclusive_group()
    operation.add_argument('--materialize', action='store_true')
    operation.add_argument('--export-bundle', type=Path, help='Create the prepare same-run selected-input artifact under build/')
    operation.add_argument('--restore-bundle', type=Path, help='Validate and restore the prepare same-run selected-input artifact')
    parser.add_argument('--receipt', action='append', type=Path, default=[])
    parser.add_argument('--execution-plan', type=Path)
    parser.add_argument('--run-id')
    parser.add_argument('--progress', action='store_true', help='Write visible phase/file/batch timing events to stderr')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args(argv)
    started = time.monotonic()
    output = None
    try:
        if args.output:
            output = new_report_file(args.root, args.output)
        progress = (lambda event: print('CLOUD INPUTS ' + json.dumps(event, sort_keys=True), file=sys.stderr, flush=True)) if args.progress else None
        if args.export_bundle or args.restore_bundle:
            if not args.execution_plan or not args.run_id or (args.restore_bundle and args.receipt):
                raise InputError('Bundle operations require execution-plan/run-id; restore does not accept receipts')
            common = (args.root, args.check, args.profile, args.commit, args.execution_plan, args.run_id)
            report = (export_bundle(*common, args.receipt, args.export_bundle, progress=progress) if args.export_bundle
                      else restore_bundle(*common, args.restore_bundle, progress=progress))
        elif args.materialize:
            report = materialize(args.root, args.check, args.profile, args.commit, progress=progress)
        else:
            report = make_plan(args.root, args.check, args.profile, args.commit)
        # A successful plan is not a claim that inputs or selected tests passed.
        code = 0 if report['status'] == 'ready' else (2 if report['status'] == 'needs_materialization' else 1)
    except (OSError, ValueError, KeyError, tarfile.TarError, EOFError, subprocess.SubprocessError) as error:
        report = {'status': 'blocked', 'approval_scope': 'input_availability_only', 'error': str(error), 'tests_executed': False,
                  **getattr(error, 'details', {})}
        code = 1
    report['seconds'] = round(time.monotonic() - started, 3)
    text = json.dumps(report, ensure_ascii=False, indent=2) + '\n'
    if output is not None:
        try:
            with output:
                output.write(text)
        except OSError as error:
            report = {'status': 'blocked', 'error': 'Report write failed: ' + str(error), 'tests_executed': False}
            text, code = json.dumps(report, ensure_ascii=False, indent=2) + '\n', 1
    print(text, end='')
    return code


if __name__ == '__main__':
    raise SystemExit(main())
