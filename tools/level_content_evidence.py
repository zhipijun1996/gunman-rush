#!/usr/bin/env python3
"""Preserve exact native outputs and source overlays without copying game art.

Restore each runtime from its immutable base Git SHA, then apply source/ and
check runtime_source SHA entries. Binary assets remain at that pinned base;
their full hashes are in the index. This is provenance, not test approval.
"""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

from level_content import sha, write


def runtime_root(path):
    path = path.resolve().parent
    while not (path / 'project.godot').is_file() and path != path.parent: path = path.parent
    if not (path / 'project.godot').is_file(): raise ValueError('Runtime root not found')
    return path


def pack(experiments, output, extras=()):
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    index = {'schema_version': 1, 'runtimes': [], 'members': [],
             'restore': 'Checkout each base Git SHA; apply namespace/source files; verify every runtime_source member SHA. Native traces remain under namespace/evidence. Binary game art is restored from that exact Git SHA, never from current main.',
             'early_round_limit': 'Exploratory v1/v2 native failures are retained separately; complete original producer source bytes were not preserved, so those early rounds are not claimed fully reproducible.'}
    contents = {}
    for number, experiment in enumerate(experiments):
        path = Path(experiment).resolve()
        root = runtime_root(path)
        report = json.loads(path.read_text())
        prefix = f'run-{number:02d}'
        inv = report['receipts'][0]['runtime_source'] if report.get('receipts') else {}
        index['runtimes'].append({'namespace': prefix, 'base_git_sha': report['source_commit'],
                                  'runtime_source': inv, 'experiment': str(path.relative_to(root)),
                                  'source_identity_scope': report.get('source_identity_scope'),
                                  'engine': report.get('receipts', [{}])[0].get('engine_identity')})
        files = {path, path.with_name('archive.json')}
        for receipt in report.get('receipts', []):
            if receipt.get('raw_path'):
                native = root / receipt['raw_path']
                files.update((native, native.with_name('native.log'), native.with_name('receipt.json')))
            catalog = receipt.get('request', {}).get('catalog')
            if catalog: files.add(root / catalog)
        for file in sorted(files):
            if file.is_file(): contents[prefix + '/evidence/' + str(file.relative_to(root))] = file.read_bytes()
        # Full actual textual source bytes (including all geometry, renderer,
        # config and metadata), plus exact base SHA for all original binary art.
        for name, expected in inv.items():
            file = root / name
            if not file.is_file() or sha(file) != expected: raise ValueError('Source changed before archive: ' + name)
            if file.suffix.lower() in ('.gd', '.gdshader', '.tscn', '.tres', '.json', '.py', '.sh', '.godot', '.cfg'):
                contents[prefix + '/source/' + name] = file.read_bytes()
        for pattern in ('level_content*.py', 'level_pilot*.gd'):
            for file in (root / 'tools').glob(pattern):
                contents[prefix + '/source/' + str(file.relative_to(root))] = file.read_bytes()
    for number, extra in enumerate(extras):
        file = Path(extra).resolve()
        if not file.is_file(): raise ValueError('Missing review artifact: ' + str(file))
        contents[f'review/{number:03d}-' + file.name] = file.read_bytes()
    for name, data in contents.items():
        index['members'].append({'path': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name, data in contents.items(): z.writestr(name, data)
        z.writestr('RESTORE-INDEX.json', json.dumps(index, ensure_ascii=False, indent=2))
    with zipfile.ZipFile(output) as z:
        if z.testzip(): raise ValueError('ZIP CRC failure')
        for entry in index['members']:
            data = z.read(entry['path'])
            if len(data) != entry['bytes'] or hashlib.sha256(data).hexdigest() != entry['sha256']:
                raise ValueError('Restoration readback mismatch')
    write(output.with_suffix('.index.json'), {**index, 'archive_sha256': sha(output), 'archive_bytes': output.stat().st_size})
    print(f'EVIDENCE: {len(contents)} exact members, CRC/SHA readback verified; not a quality verdict')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--experiment', action='append', required=True)
    p.add_argument('--output', required=True)
    p.add_argument('--extra', action='append', default=[])
    args = p.parse_args()
    pack(args.experiment, args.output, args.extra)


if __name__ == '__main__': main()
