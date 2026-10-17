"""Fresh native version registry/recorded-v1 checks, not forest v2 admission.

Run inside copy_runtime_snapshot.py's guarded runtime snapshot while holding
its host's global engine lock; this wrapper never mutates the author worktree.
"""
import argparse
import contextlib
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time

import level_formal
from run_tests import run_engine

ROOT = Path(__file__).resolve().parents[1]


def validate(data):
    if data.get('failures') != 0 or not isinstance(data.get('assertions'), int) or data['assertions'] < 60:
        raise ValueError('Complete version runtime assertions required')
    checks = data.get('checks', [])
    if len(checks) != data['assertions'] or not all(r.get('passed') is True for r in checks):
        raise ValueError('Full native assertion ledger required')
    rows = data.get('cases', [])
    delegates = [r for r in rows if r.get('id') == 'delegate']
    expected = {(f'version-contract-{seed:02d}/thorn_forest/map_{map_index}', map_index)
                for seed in range(4) for map_index in (1, 2)}
    if len(delegates) != 8 or {(r.get('seed'), r.get('map')) for r in delegates} != expected:
        raise ValueError('All four seeds and two maps required')
    legacy = 'thorn-forest-region-v1'
    for row in delegates:
        if (row.get('equal_complete_output') is not True or row.get('stage_generator_version') != legacy
                or row.get('enemy_version') != legacy or row.get('manifest', {}).get('version') != legacy):
            raise ValueError('Complete v1 delegate generation mismatch')
    queens = [r for r in rows if r.get('id') == 'v2_map2_experimental']
    if len(queens) != 1:
        raise ValueError('Exactly one current experimental Queen candidate required')
    queen = queens[0]
    contract = queen.get('boss_contract', {})
    if (queen.get('ok') is not True or queen.get('returned_version') != 'thorn-forest-region-v2'
            or queen.get('production_pool') is not False
            or contract.get('version') != 'forest-queen-weave-golden-v2'
            or contract.get('boss_contract') != 'queen-weave-region-experimental'
            or contract.get('admission') != 'experimental_whole_boss_pending'
            or contract.get('entry_mapping', {}).get('new_high_bridge') is not False):
        raise ValueError('Exact experimental Queen geometry/admission required; no fallback or promotion')
    lifecycle = data.get('exit_lifecycle', {})
    for key in ('registry', 'legacy', 'equality', 'tuning'):
        if (lifecycle.get(key, {}).get('before_release_alive') is not True
                or lifecycle[key].get('after_run_return_alive') is not False):
            raise ValueError('Observed runner-local release required: ' + key)
    apps = [r for r in rows if r.get('id') == 'app_legacy']
    if len(apps) != 2 or {r.get('map') for r in apps} != {1, 2}:
        raise ValueError('Both actual legacy DemoApp entry maps required')
    for row in apps:
        expected_scene = 'res://scenes/bosses/' + ('thorn_guardian' if row['map'] == 1 else 'thorn_queen') + '.tscn'
        if row.get('boss_scene') != expected_scene or not row.get('enemies'):
            raise ValueError('Actual old Boss/enemy scenes required')
        output = row.get('recorded_outputs', {})
        if any(output.get(key, {}).get('version') != legacy for key in
               ('generated_layout', 'stage_generator', 'region_map', 'enemy_layout')):
            raise ValueError('Recorded outputs must all retain v1 identity')
        if row['map'] == 1:
            fallback = row.get('fallback', {})
            if (fallback.get('version') != legacy or not fallback.get('hash_before')
                    or fallback.get('hash_before') != fallback.get('hash_after')
                    or not all(fallback.get(key) is True for key in ('same_state', 'claims_retained', 'actors_retained'))):
                raise ValueError('Actual hash-bound v1 state fallback required')
    if len(rows) != 11:
        raise ValueError('Unexpected/missing native cases')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', default='build/forest_depth/versions/native')
    parser.add_argument('--verbose', action='store_true', help='Preserve engine verbose exit diagnostics; strict guards unchanged')
    args = parser.parse_args()
    out = (ROOT / args.output_dir).resolve()
    if not out.is_relative_to(ROOT / 'build/forest_depth/versions') or out.exists():
        parser.error('Fresh output below build/forest_depth/versions required')
    out.mkdir(parents=True)
    before = level_formal.source_files()
    verifier = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in (Path(__file__).resolve(), ROOT / 'tests/forest_depth_version_runner.gd')}
    receipt = {'scope': 'Runtime registry/legacy compatibility, NOT v2 gameplay admission',
               'base_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
               'source_before': before, 'verifier_before': verifier, 'passed': False}
    snapshot = ROOT / 'build/snapshot-receipt.json'
    if snapshot.is_file():
        receipt['runtime_snapshot_receipt_sha256'] = hashlib.sha256(snapshot.read_bytes()).hexdigest()
    started = time.monotonic()
    try:
        with (out / 'import.log').open('w') as log, contextlib.redirect_stdout(log):
            import_text = run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
        if re.search(r'(^|\n)(?:SCRIPT )?ERROR:', import_text):
            raise RuntimeError('Unexpected native import ERROR')
        with (out / 'native.log').open('w') as log, contextlib.redirect_stdout(log):
            text = run_engine((['--verbose'] if args.verbose else []) + ['--headless', '--fixed-fps', '60', '--path', '.', '--script',
                'tests/forest_depth_version_runner.gd', '--',
                '--output=res://' + str((out / 'capture.json').relative_to(ROOT))], 90)
        if not re.search(r'^FOREST DEPTH VERSIONS: [1-9]\d* assertions, 0 failures$', text, re.M):
            raise RuntimeError('Complete native version result missing')
        if re.search(r'(^|\n)(?:SCRIPT )?ERROR:', text):
            raise RuntimeError('Unexpected native engine ERROR')
        validate(json.loads((out / 'capture.json').read_text()))
        receipt['passed'] = True
    finally:
        receipt['source_after'] = level_formal.source_files()
        receipt['verifier_after'] = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in verifier}
        receipt['source_guard'] = before == receipt['source_after'] and verifier == receipt['verifier_after']
        receipt['elapsed_seconds'] = time.monotonic() - started
        receipt['logs'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                           for p in out.iterdir() if p.is_file()}
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        if not receipt['source_guard']:
            raise RuntimeError('Source changed during native version check')
    print('PASS: forest depth runtime registry and actual legacy entry/state; v2 gameplay NOT covered')


if __name__ == '__main__':
    main()
