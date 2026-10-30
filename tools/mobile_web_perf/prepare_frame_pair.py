"""Prepare a local engine-only Debug/Release A/B pair without running Godot.

Both pages retain the production HTML/loader/CSS and consume the same exact PCK.
Only official, matching threaded engine files differ. This is not a complete
release export: the PCK retains its original export mode (or explicit diagnostic
patches). Local symlinks avoid duplicating hundreds of MiB and forbid treating
these directories as ready-to-upload deployment bundles.
"""
from __future__ import annotations

import argparse
import copy
import gzip
import hashlib
import json
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SUFFIXES = ('.js', '.wasm', '.audio.worklet.js', '.audio.position.worklet.js')
CHUNK_SIZE = 512 * 1024


def sha(data):
    return hashlib.sha256(data).hexdigest()


def file_sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def describe(path):
    return {'path': str(path.resolve()), 'bytes': path.stat().st_size,
            'sha256': file_sha(path)}


def chunks(data, folder):
    folder.mkdir(parents=True, exist_ok=True)
    rows = []
    for offset in range(0, len(data), CHUNK_SIZE):
        block = data[offset:offset + CHUNK_SIZE]
        digest = sha(block)
        target = folder / (digest + '.gz')
        compressed = gzip.compress(block, compresslevel=9, mtime=0)
        if not target.exists():
            target.write_bytes(compressed)
        elif target.read_bytes() != compressed:
            raise ValueError('Conflicting content-addressed chunk: ' + str(target))
        rows.append({'url': 'chunks/' + target.name, 'sha256': digest,
                     'bytes': len(block), 'gzip_bytes': len(compressed)})
    return rows


def link(source, destination):
    destination.symlink_to(source.resolve())


def prepare(bundle, output, templates, pack_override=None):
    if output.exists():
        raise ValueError('Preserve previous attempts; output already exists')
    info = json.loads((bundle / 'build-info.json').read_text())
    if not info['threads_enabled'] or info['audio_supply'] != 'dedicated_thread':
        raise ValueError('Expected the official threaded production baseline')
    page = (bundle / 'index.html').read_text()
    config_match = re.search(r'const GODOT_CONFIG = (\{[^\n]+\});', page)
    if not config_match or 'const GODOT_THREADS_ENABLED = true;' not in page:
        raise ValueError('Production HTML/configuration does not match expectations')
    original_config = json.loads(config_match.group(1))
    old_engine = 'index.' + info['engine_id'] + '.engine'
    if original_config['executable'] != old_engine or original_config['mainPack'] != info['pack']:
        raise ValueError('Production HTML and metadata disagree')
    worker = (bundle / 'index.cache-sw.js').read_text()
    resource_line = worker.splitlines()[1]
    if not resource_line.startswith('const RESOURCE_MAP = ') or not resource_line.endswith(';'):
        raise ValueError('Unexpected production resource map format')
    old_resources = json.loads(resource_line[len('const RESOURCE_MAP = '):-1])
    worker_template = (ROOT / 'tools/web/cache_worker.js').read_text()
    startup_template = (ROOT / 'tools/web/cache_startup.js').read_text()
    rendered_old_worker = worker_template.replace('__RESOURCE_MAP__', json.dumps(old_resources, separators=(',', ':'))).replace('__WORKER_ID__', json.dumps(info['loader_id']))
    if rendered_old_worker != worker:
        raise ValueError('Current worker template differs from the exact baseline')
    baseline_pack = bundle / info['pack']
    baseline_sha = file_sha(baseline_pack)
    if baseline_sha != old_resources[info['pack']]['sha256'] or not baseline_sha.startswith(info['build_id']):
        raise ValueError('Baseline pack failed its complete content hash')
    pack = pack_override or baseline_pack
    pack_sha = file_sha(pack)
    pack_id = pack_sha[:12]
    pack_name = 'index.' + pack_id + '.pck'
    output.mkdir(parents=True)
    if pack_override:
        pack_chunks_dir = output / '_shared_pack_chunks'
        pack_data = pack.read_bytes()
        pack_resource = {'bytes': len(pack_data), 'sha256': pack_sha,
                         'chunks': chunks(pack_data, pack_chunks_dir), 'mime': 'application/octet-stream'}
    else:
        pack_chunks_dir = bundle / 'chunks'
        pack_resource = copy.deepcopy(old_resources[info['pack']])
    receipt = {
        'scope': 'Engine-template-only A/B, same exact PCK; not a full release export or a device performance result.',
        'baseline_info': info, 'baseline_pack': describe(baseline_pack),
        'measured_pack': describe(pack), 'diagnostic_pack_override': bool(pack_override),
        'pack_export_mode': 'original debug-exported pack' if not pack_override else 'explicit diagnostic derivative; consult its producer receipt',
        'local_only_symlinks': True,
        'deployment_warning': 'Do not upload this local comparison directly; materialize links and validate a deployment separately.',
        'unchanged': ['1280x720 project/scene viewport policy inside the same pack', 'production HTML CSS and startup behavior', '8/4 configured worker pools', 'game assets and audio policy'],
        'html_allowed_changes': ['engine filename and WASM size', 'worker content identity', 'pack name/size/badge only when an explicit diagnostic pack is supplied'],
        'variants': [],
    }
    for mode in ('debug', 'release'):
        target = output / ('engine-' + mode)
        target.mkdir()
        archive = templates / ('web_' + mode + '.zip')
        with zipfile.ZipFile(archive) as z:
            engine_files = {suffix: z.read('godot' + suffix) for suffix in SUFFIXES}
        engine_id = sha(b''.join(engine_files.values()))[:12]
        engine = 'index.' + engine_id + '.engine'
        resources = {pack_name: copy.deepcopy(pack_resource)}
        (target / 'chunks').mkdir()
        for row in pack_resource['chunks']:
            source = pack_chunks_dir / Path(row['url']).name
            if not source.is_file() or source.stat().st_size != row['gzip_bytes']:
                raise ValueError('Missing/mismatched baseline chunk: ' + str(source))
            link(source, target / row['url'])
        link(pack, target / pack_name)
        official = {}
        for suffix, data in engine_files.items():
            name = engine + suffix
            (target / name).write_bytes(data)
            resources[name] = {'bytes': len(data)}
            official[name] = {'zip_member': 'godot' + suffix, 'sha256': sha(data), 'bytes': len(data)}
            if mode == 'debug' and (bundle / (old_engine + suffix)).read_bytes() != data:
                raise ValueError('Baseline engine differs from official threaded Debug template')
            if suffix == '.wasm':
                compressed = gzip.compress(data, compresslevel=9, mtime=0)
                (target / (name + '.gz')).write_bytes(compressed)
                resources[name].update(sha256=sha(data), gzip=name + '.gz', mime='application/wasm',
                                       chunks=chunks(data, target / 'chunks'))
        new_worker = worker_template.replace('__RESOURCE_MAP__', json.dumps(resources, separators=(',', ':')))
        worker_id = sha((new_worker + startup_template).encode())[:12]
        (target / 'index.cache-sw.js').write_text(new_worker.replace('__WORKER_ID__', json.dumps(worker_id)))
        config = copy.deepcopy(original_config)
        config['executable'] = engine
        config['mainPack'] = pack_name
        config['fileSizes'] = {pack_name: pack.stat().st_size, engine + '.wasm': len(engine_files['.wasm'])}
        new_page = page.replace(config_match.group(1), json.dumps(config, separators=(',', ':')), 1)
        new_page = new_page.replace(old_engine, engine).replace(info['loader_id'], worker_id)
        new_page = new_page.replace(info['build_id'], pack_id)
        if pack_override:
            new_page = new_page.replace('试玩 ' + info['build_id'][:8], '试玩 ' + pack_id[:8])
        # Verify no CSS/startup/control changes slipped in beyond the allowlist.
        restored = new_page.replace(engine, old_engine).replace(worker_id, info['loader_id']).replace(pack_id, info['build_id'])
        if pack_override:
            restored = restored.replace('试玩 ' + pack_id[:8], '试玩 ' + info['build_id'][:8])
        restored_match = re.search(r'const GODOT_CONFIG = (\{[^\n]+\});', restored)
        restored = restored.replace(restored_match.group(1), config_match.group(1), 1)
        if restored != page:
            raise ValueError('HTML changed outside the engine/pack/worker allowlist')
        (target / 'index.html').write_text(new_page)
        for source in bundle.iterdir():
            if source.is_file() and source.name not in {'index.html', 'index.cache-sw.js', 'build-info.json', 'build_report.json'} and not source.name.endswith('.pck') and '.engine.' not in source.name:
                link(source, target / source.name)
        metadata = dict(info, build_id=pack_id, pack=pack_name, pack_bytes=pack.stat().st_size,
                        engine_id=engine_id, loader_id=worker_id, wasm_bytes=len(engine_files['.wasm']),
                        wasm_gzip_bytes=(target / (engine + '.wasm.gz')).stat().st_size,
                        download_bytes=sum(c['gzip_bytes'] for r in resources.values() for c in r.get('chunks', [])),
                        engine_template=mode, engine_only_comparison=True, diagnostic_pack_override=bool(pack_override))
        (target / 'build-info.json').write_text(json.dumps(metadata, indent=2) + '\n')
        row = {'mode': mode, 'directory': str(target), 'template_archive': describe(archive),
               'pack_sha256': pack_sha, 'official_engine_files': official,
               'html_sha256': file_sha(target / 'index.html'), 'metadata': metadata,
               'html_allowlist_inverse_verified': True}
        receipt['variants'].append(row)
    (output / 'pair-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--templates', type=Path, default=Path('/workspace/toolchains/user-data/godot/export_templates/4.7.2.stable'))
    parser.add_argument('--pack', type=Path, help='Explicit diagnostic derivative, used identically by both engines')
    args = parser.parse_args()
    receipt = prepare(args.bundle.resolve(), args.output.resolve(), args.templates.resolve(), args.pack.resolve() if args.pack else None)
    print(json.dumps({'output': str(args.output), 'pack_sha256': receipt['measured_pack']['sha256'],
                      'variants': {v['mode']: v['metadata']['engine_id'] for v in receipt['variants']}}))


if __name__ == '__main__':
    main()
