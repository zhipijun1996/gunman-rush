"""Exact bee850c forest v1 fixture. This never certifies current forest v2.

Uses the existing frozen-assets rule: same-path identical bytes, or a retained
real Git blob; changed/missing inputs without that blob are a hard failure.
"""
import argparse
import gzip
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import tarfile
import zlib

BASELINE = 'bee850c66b2f402d644d7daa4c13db91c8abe8f8'
ROOT = Path(__file__).resolve().parents[1]
BASIS = ROOT / 'docs/evidence/forest_depth_v2/legacy_v1'
CHECK_IDS = ('forest-h-slice', 'forest-ecology', 'forest-progression',
             'forest-campaign', 'forest-debug', 'forest-traversal',
             'forest-region-matrix', 'forest-formal-combat')
SOURCE_DIRS = {'scripts', 'scenes', 'resources', 'config', 'tests', 'tools', 'shaders', 'addons', 'game'}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def git_identity(data, kind='blob'):
    return hashlib.sha1(kind.encode() + b' ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def safe_path(name):
    p = PurePosixPath(name)
    if not name or p.is_absolute() or '..' in p.parts or '\\' in name or str(p) != name:
        raise ValueError('Unsafe fixture path: ' + name)
    return p


def no_symlinks(path):
    """Check the lexical path before resolve/read/write, including every ancestor."""
    path = Path(path).absolute()
    for component in (*reversed(path.parents), path):
        if component.is_symlink():
            raise ValueError('Symlink fixture path/ancestor: ' + str(component))
    return path


def original_checks(project, manifest):
    """Manifest scheduling must equal the authenticated original profiles."""
    path = no_symlinks(project / 'tools/harness/profiles.json')
    raw = path.read_bytes()
    item = manifest['members']['tools/harness/profiles.json']
    if sha(raw) != item['sha256'] or git_identity(raw) != item['git_blob']:
        raise ValueError('Original profiles bytes differ')
    profiles = json.loads(raw)
    expected = {key: profiles['checks'][key] for key in CHECK_IDS}
    if manifest.get('checks') != expected:
        raise ValueError('Original check set/argv/cap/marker/config differs')
    return expected


def git(repo, *args):
    return subprocess.check_output(['git', *args], cwd=repo,
        env={k: v for k, v in os.environ.items() if not k.startswith('GIT_')})


def freeze(repo=ROOT, basis=BASIS, commit=BASELINE):
    """Author an immutable archive from genuine Git objects, never worktree bytes."""
    no_symlinks(repo)
    no_symlinks(basis)
    if basis.exists():
        raise ValueError('Refusing to overwrite fixture: ' + str(basis))
    commit = git(repo, 'rev-parse', commit + '^{commit}').decode().strip()
    rows = []
    for record in git(repo, 'ls-tree', '-r', '-l', '-z', commit).split(b'\0'):
        if not record:
            continue
        meta, path = record.split(b'\t', 1)
        mode, kind, oid, size = meta.decode().split()
        name = path.decode()
        safe_path(name)
        if kind != 'blob' or mode not in ('100644', '100755'):
            raise ValueError('Unsupported original tree entry: ' + name)
        rows.append(dict(path=name, mode=mode, git_blob=oid, size=int(size)))
    payload = {}
    assets = {}
    members = {}
    for row in rows:
        name = row['path']
        selected = (name.split('/')[0] in SOURCE_DIRS or
                    name in ('project.godot', 'export_presets.cfg', '.gitignore', 'docs/world_regions.json', 'docs/current_state.md',
                             'docs/quality/action_budget_spec.md', 'docs/quality/weapon_feel_spec.md',
                             'docs/quality/all_weapons_spec.md') or
                    name.startswith('docs/design/player_actions/'))
        if not selected and not name.startswith('assets/'):
            continue
        data = git(repo, 'cat-file', 'blob', row['git_blob'])
        item = {**row, 'sha256': sha(data)}
        if name.startswith('assets/'):
            assets[name] = item
        else:
            payload[name] = data
            members[name] = item
    # Preserve authentic HEAD and ALL original trees: original wrappers' git
    # rev-parse/ls-files must never discover the enclosing current repository.
    objects = {}
    tree_ids = {git(repo, 'rev-parse', commit + '^{tree}').decode().strip()}
    for record in git(repo, 'ls-tree', '-r', '-d', '-z', commit).split(b'\0'):
        if record:
            tree_ids.add(record.split(b'\t', 1)[0].decode().split()[2])
    for oid, kind in [(commit, 'commit'), *[(oid, 'tree') for oid in sorted(tree_ids)]]:
        data = git(repo, 'cat-file', kind, oid)
        assert git_identity(data, kind) == oid
        raw = kind.encode() + b' ' + str(len(data)).encode() + b'\0' + data
        name = '__git_objects__/' + oid
        payload[name] = zlib.compress(raw)
        objects[oid] = {'kind': kind, 'sha256': sha(payload[name])}
    profiles = json.loads(payload['tools/harness/profiles.json'])
    checks = {key: profiles['checks'][key] for key in CHECK_IDS}
    basis.mkdir(parents=True)
    archive = basis / 'source.tar.gz'
    with archive.open('wb') as raw:
        with gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode='w') as tar:
                for name, data in sorted(payload.items()):
                    info = tarfile.TarInfo(name)
                    info.size = len(data)
                    info.mode = int(members[name]['mode'], 8) & 0o777 if name in members else 0o644
                    tar.addfile(info, io.BytesIO(data))
    inventory = json.dumps({'source_commit': commit, 'entries': rows}, indent=2).encode() + b'\n'
    (basis / 'inventory.json').write_bytes(inventory)
    manifest = {'schema_version': 1, 'scope': 'historical_forest_v1_only_not_current_v2',
                'source_commit': commit, 'archive_sha256': sha(archive.read_bytes()),
                'inventory_sha256': sha(inventory), 'members': members, 'assets': assets,
                'git_objects': objects, 'checks': checks,
                'omitted_paths': 'Non-consumer docs/evidence, preview, build and repository administration are inventory-only; no claim of complete old checkout.'}
    (basis / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return manifest


def verify(project, manifest):
    """Reject missing, modified or symlink source/assets before and after execution."""
    no_symlinks(project)
    for name, item in (manifest['members'] | manifest['assets']).items():
        safe_path(name)
        path = no_symlinks(project / name)
        if path.is_symlink() or not path.is_file():
            raise ValueError('Missing/nonregular fixture input: ' + name)
        data = path.read_bytes()
        if sha(data) != item['sha256'] or git_identity(data) != item['git_blob']:
            raise ValueError('Fixture input differs: ' + name)
    expected = set(manifest['members'])
    for directory in SOURCE_DIRS:
        for path in (project / directory).rglob('*'):
            if path.is_file() and path.suffix in {'.gd', '.py', '.tres', '.tscn', '.json', '.sh', '.gdshader'}:
                if path.relative_to(project).as_posix() not in expected:
                    raise ValueError('Unexpected fixture source: ' + str(path.relative_to(project)))
    original_checks(project, manifest)
    metadata = no_symlinks(project / '.git')
    for entry in metadata.rglob('*'):
        no_symlinks(entry)
    for oid, item in manifest['git_objects'].items():
        if not re.fullmatch('[0-9a-f]{40}', oid):
            raise ValueError('Unsafe Git object identity')
        raw = (metadata / 'objects' / oid[:2] / oid[2:]).read_bytes()
        if sha(raw) != item['sha256'] or hashlib.sha1(zlib.decompress(raw)).hexdigest() != oid:
            raise ValueError('Frozen Git object changed')
    if git(project, 'rev-parse', 'HEAD').decode().strip() != manifest['source_commit']:
        raise ValueError('Fixture HEAD differs')


def restore(repo, folder, basis=BASIS):
    """Fresh isolated sources, Git index and engine cache; no cache copied from v2."""
    repo, folder, basis = (no_symlinks(p) for p in (repo, folder, basis))
    for name in ('manifest.json', 'source.tar.gz', 'inventory.json'):
        no_symlinks(basis / name)
    manifest = json.loads((basis / 'manifest.json').read_text())
    if manifest['source_commit'] != BASELINE or manifest['scope'] != 'historical_forest_v1_only_not_current_v2':
        raise ValueError('Wrong legacy fixture identity/scope')
    archive = (basis / 'source.tar.gz').read_bytes()
    inventory = (basis / 'inventory.json').read_bytes()
    if sha(archive) != manifest['archive_sha256'] or sha(inventory) != manifest['inventory_sha256']:
        raise ValueError('Fixture archive/inventory fingerprint differs')
    rows = json.loads(inventory)['entries']
    indexed = {r['path']: r for r in rows}
    if len(indexed) != len(rows):
        raise ValueError('Duplicate inventory path')
    for name, item in (manifest['members'] | manifest['assets']).items():
        if any(item[k] != indexed[name][k] for k in ('path', 'mode', 'git_blob', 'size')):
            raise ValueError('Manifest/inventory mismatch: ' + name)
    if folder.exists():
        raise ValueError('Fresh fixture directory required: ' + str(folder))
    folder.mkdir(parents=True)
    (folder / '.gdignore').touch()
    project = folder / 'project'
    project.mkdir()
    expected = set(manifest['members']) | {'__git_objects__/' + oid for oid in manifest['git_objects']}
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:gz') as tar:
        entries = tar.getmembers()
        if len(entries) != len(expected) or {m.name for m in entries} != expected:
            raise ValueError('Fixture archive member set differs')
        for member in entries:
            safe_path(member.name)
            if not member.isfile():
                raise ValueError('Nonregular archive member')
            data = tar.extractfile(member).read()
            if member.name.startswith('__git_objects__/'):
                oid = member.name.split('/')[1]
                if not re.fullmatch('[0-9a-f]{40}', oid) or sha(data) != manifest['git_objects'][oid]['sha256']:
                    raise ValueError('Corrupt frozen Git object')
                if hashlib.sha1(zlib.decompress(data)).hexdigest() != oid:
                    raise ValueError('Git object identity mismatch')
                path = project / '.git/objects' / oid[:2] / oid[2:]
            else:
                item = manifest['members'][member.name]
                if sha(data) != item['sha256'] or git_identity(data) != item['git_blob']:
                    raise ValueError('Corrupt frozen source: ' + member.name)
                path = project / member.name
            no_symlinks(path)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            if member.name in manifest['members']:
                path.chmod(int(manifest['members'][member.name]['mode'], 8) & 0o777)
    original_checks(project, manifest)
    reused, restored = [], []
    for name, item in manifest['assets'].items():
        safe_path(name)
        current = no_symlinks(repo / name)
        data = current.read_bytes() if current.is_file() and not current.is_symlink() else None
        if data is not None and sha(data) == item['sha256'] and git_identity(data) == item['git_blob']:
            reused.append(name)
        else:
            retained = no_symlinks(basis / 'asset_blobs' / item['git_blob'])
            if not retained.is_file() or retained.is_symlink():
                raise ValueError('Exact old asset blob required: ' + name)
            data = retained.read_bytes()
            restored.append(name)
        if sha(data) != item['sha256'] or git_identity(data) != item['git_blob']:
            raise ValueError('Old asset fingerprint differs: ' + name)
        destination = no_symlinks(project / name)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
    metadata = project / '.git'
    (metadata / 'refs').mkdir()
    (metadata / 'HEAD').write_text(manifest['source_commit'] + '\n')
    (metadata / 'shallow').write_text(manifest['source_commit'] + '\n')
    (metadata / 'config').write_text('[core]\n\trepositoryformatversion = 0\n\tbare = false\n\tlogallrefupdates = false\n')
    # read-tree needs trees, not omitted evidence blobs. No alternates/remotes,
    # no fabricated commit and no access to the enclosing repository's index.
    git(project, 'read-tree', 'HEAD')
    tracked = set(git(project, 'ls-files', '-z').decode().rstrip('\0').split('\0'))
    actual_index = {}
    for record in git(project, 'ls-files', '--stage', '-z').split(b'\0'):
        if record:
            meta, name = record.split(b'\t', 1)
            mode, oid, stage = meta.decode().split()
            if stage != '0':
                raise ValueError('Unexpected staged conflict in fixture index')
            actual_index[name.decode()] = (mode, oid)
    if tracked != set(indexed) or actual_index != {r['path']: (r['mode'], r['git_blob']) for r in rows}:
        raise ValueError('Authentic Git tree and inventory differ')
    verify(project, manifest)
    (folder / 'restoration.json').write_text(json.dumps({'scope': manifest['scope'], 'source_commit': manifest['source_commit'],
        'reused_assets': reused, 'restored_assets': restored, 'original_tracked_count': len(rows),
        'materialized_source_count': len(manifest['members']), 'native_executed': False}, indent=2) + '\n')
    return project, manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--freeze', action='store_true')
    parser.add_argument('--restore', type=Path)
    args = parser.parse_args()
    if args.freeze:
        freeze()
    elif args.restore:
        restore(ROOT, no_symlinks(args.restore))
    else:
        parser.error('Choose --freeze or --restore (neither runs Godot)')
