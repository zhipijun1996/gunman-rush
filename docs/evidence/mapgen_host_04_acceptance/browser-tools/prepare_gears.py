"""External recovery preparation only. Does not run a server, browser or engine."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys

sys.dont_write_bytecode = True
DRIVER_SHA = '112c62449312246ac3a600a1dd3b690ce8a1cf32ef5517ce0be014b8c8b036f0'
SCENE = 'res://experiments/generation/runtime_map_m35_slice.tscn'

def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def extract_expected(log, source):
    """Read actual native events; no prior-run positions or identity fallback."""
    text = log.read_text()
    markers = re.findall(r'^RUNTIME_MAP_M35_RUNTIME checks=(\d+) failures=(\d+)\s*$', text, re.M)
    assert len(markers) == 1 and int(markers[0][0]) >= 69 and markers[0][1] == '0', 'Native completion marker missing or failed'
    events = {'MAPGEN_RUNTIME ': [], 'MAPGEN_HOST_V2 ': []}
    for line in text.splitlines():
        for prefix, values in events.items():
            if line.startswith(prefix):
                values.append(json.loads(line[len(prefix):]))
    committed = [v for v in events['MAPGEN_RUNTIME '] if v.get('event') == 'committed' and v.get('output', {}).get('seed') == 930007]
    assert committed, 'No actual gears committed observation'
    receipt = committed[0]
    assert all(v['identity'] == receipt['identity'] and v['output'] == receipt['output'] for v in committed), 'Ambiguous native receipts'
    identity = receipt['identity']; host = identity['host_load_identity']
    loaded = [v for v in events['MAPGEN_HOST_V2 '] if v.get('event') == 'loaded' and v.get('host_load_identity') == host]
    assert loaded, 'No matching actual loaded observation'
    sample = loaded[0]
    assert sample['player'] == identity['host_load']['spawn']
    assert len(sample['mechanisms']) == 1 and len(sample['static_contacts']) == 1
    mechanism = sample['mechanisms'][0]; contact = sample['static_contacts'][0]
    assert identity['host_load']['selected_instances'] == [mechanism['instance_id']]
    assert len(mechanism['ferries']) == 2 and len(mechanism['saws']) == 1
    assert all(contact[k] is True for k in ['enabled', 'shared_policy', 'fall_plane'])
    assert receipt['output']['status'] == 'PASS' and receipt['source_kind'] == 'generated_memory'
    return dict(schema='gunman-rush/mapgen04-browser-expected/v1', source=source, scene=SCENE,
                sdk_implementation='mapgen/gdscript-candidate-0.4.0', input_profile='gears_conformance',
                runtime_profile=receipt['profile'], actual_generated_output=receipt['output'],
                spawn=sample['player'], selected_instances=identity['host_load']['selected_instances'],
                host_load_identity=host, map_content_identity=identity['map_content_identity'],
                native_proof_file=str(log.resolve()), native_proof_sha256=sha(log),
                mechanisms=dict(ferry_ids=[v['id'] for v in mechanism['ferries']],
                                saw_ids=[v['id'] for v in mechanism['saws']], static_contact_rect=contact['rect']))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['source-root', 'bundle', 'native-log', 'output']:
        parser.add_argument('--'+name, type=Path, required=True)
    for name in ['source', 'pack-sha256']:
        parser.add_argument('--'+name, required=True)
    parser.add_argument('--pack-bytes', type=int, required=True)
    parser.add_argument('--port', type=int, default=8831)
    a = parser.parse_args(); root = a.source_root.resolve(); bundle = a.bundle.resolve()
    assert re.fullmatch('[0-9a-f]{40}', a.source)
    assert re.fullmatch('[0-9a-f]{64}', a.pack_sha256) and a.pack_bytes > 0
    assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip() == a.source
    assert not subprocess.check_output(['git', 'status', '--porcelain'], cwd=root, text=True).strip()
    driver = Path(__file__).with_name('gears_run.py').resolve(); assert sha(driver) == DRIVER_SHA
    expected = extract_expected(a.native_log.resolve(), a.source)
    sys.path.insert(0, str(root/'tools'))
    from cloud_delivery import validate_bundle, inject_entry
    info, validation = validate_bundle(bundle, root, SCENE)
    assert info['source_commit'] == expected['source'] == a.source
    assert validation['pack_sha256'] == a.pack_sha256 and validation['pack_bytes'] == a.pack_bytes
    out = a.output.resolve(); out.mkdir(parents=True, exist_ok=False)
    site = out/'site'; site.mkdir()
    original = (bundle/'index.html').read_text()
    injected = inject_entry(original, 'MAPGEN-HOST-04-ACCEPTANCE-01', str(expected['actual_generated_output']['seed']), 'scene', SCENE)
    links = []
    for src in sorted(bundle.rglob('*')):
        assert not src.is_symlink()
        target = site/src.relative_to(bundle)
        if src.is_dir(): target.mkdir(exist_ok=True)
        elif src == bundle/'index.html': target.write_text(injected)
        else:
            os.link(src, target)
            assert (src.stat().st_dev, src.stat().st_ino) == (target.stat().st_dev, target.stat().st_ino)
            links.append(dict(path=src.relative_to(bundle).as_posix(), bytes=src.stat().st_size, dev=src.stat().st_dev, inode=src.stat().st_ino))
    expected_path = out/'expected-native.json'; expected_path.write_text(json.dumps(expected, indent=2)+'\n')
    receipt_path = out/'stage-receipt.json'
    receipt = dict(source=a.source, pack_sha256=a.pack_sha256, pack_bytes=a.pack_bytes,
                   native_proof_file=expected['native_proof_file'], native_proof_sha256=expected['native_proof_sha256'],
                   validation=validation, url=f'http://127.0.0.1:{a.port}/', site=str(site),
                   original_index_sha256=sha(bundle/'index.html'), injected_index_sha256=sha(site/'index.html'),
                   hardlinks=links, large_site_copy=False, published=False)
    receipt_path.write_text(json.dumps(receipt, indent=2)+'\n')
    argv = ['python3', '-B', str(driver), '--source-root', str(root), '--bundle', str(bundle),
            '--output', str(out/'actual'), '--commands', str(out/'commands'),
            '--ocr-prefix', str(driver.parent/'ocr-data'), '--source', a.source,
            '--url', receipt['url'], '--pack-sha256', a.pack_sha256, '--pack-bytes', str(a.pack_bytes),
            '--expected-host-load-identity', expected['host_load_identity'], '--expected-observation', str(expected_path)]
    producers = [Path(__file__).resolve(), driver.parent/'previous_stage_original.py', receipt_path,
                 site/'index.html', root/'tools/build.py', root/'tools/cloud_delivery.py', root/'tools/mobile_web_perf/serve_coi.py']
    for path in producers: argv.extend(['--producer-file', str(path)])
    (out/'run-argv.json').write_text(json.dumps(argv, indent=2)+'\n')
    (out/'run.sh').write_text('#!/bin/sh\nset -eu\nexec '+shlex.join(argv)+'\n')
    serve = ['python3', '-B', str(root/'tools/mobile_web_perf/serve_coi.py'), '--directory', str(site), '--port', str(a.port)]
    (out/'serve.sh').write_text('#!/bin/sh\nset -eu\nexec '+shlex.join(serve)+'\n')
    (out/'recovery-producers.json').write_text(json.dumps({str(p):sha(p) for p in [driver, *producers]}, indent=2)+'\n')
    print(json.dumps(dict(status='PREPARED_ONLY_NOT_RUN', output=str(out), driver_sha256=sha(driver), expected=expected), indent=2))

if __name__ == '__main__':
    main()
