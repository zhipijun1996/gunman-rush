"""Actual normal-input App Guardian earned-state reload and legacy compatibility.

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
    if data.get('failures') != 0 or not isinstance(data.get('assertions'), int) or data['assertions'] < 45:
        raise ValueError('Complete App restore runtime assertions required')
    checks = data.get('checks', [])
    if len(checks) != data['assertions'] or not all(r.get('passed') is True for r in checks):
        raise ValueError('Full native assertion ledger required')
    rows = data.get('cases', [])
    if len(rows) != 2 or {r.get('id') for r in rows} != {'guardian_app_reload', 'legacy_app_reload'}:
        raise ValueError('Both actual App reload paths required')
    guardian = next(r for r in rows if r['id'] == 'guardian_app_reload')
    if guardian.get('malformed_cases') != 6 or guardian['actor_epoch_after'] <= guardian['actor_epoch_before']:
        raise ValueError('Malformed App negatives and fresh actor epoch required')
    saved = guardian['saved']
    after = guardian['after_activation']
    if guardian.get('invalid_contract_cases') != 7:
        raise ValueError('All current contract and retired-schema negatives required')
    for row in (saved, guardian['after_bound_restore'], after):
        if row.get('duel_version') != 'guardian-two-action-cycle-v6' or 'duel_roots' in row:
            raise ValueError('Exact current V6 schema without retired root ledger required')
    if saved.get('cycles', 0) <= 0 or saved.get('mode') != 'bell_stagger' or not guardian.get('combat_frames') or not guardian.get('route_frames'):
        raise ValueError('Actual Body cycle, earned Bell stagger and full normal-input trace required')
    if not any(r.get('event') == 'bell_counter_committed' for r in guardian.get('phase_events', [])):
        raise ValueError('Real counter commit evidence required')
    if saved.get('stage_phase') != 2 or after.get('stage_phase') != 2:
        raise ValueError('Actual HP-triggered phase2 persistence required')
    if after.get('body_position') != saved.get('body_position') or after.get('health') != saved.get('health'):
        raise ValueError('Actual body and damaged HP persistence required')
    if after.get('attack_epoch', -1) <= saved.get('attack_epoch', 0):
        raise ValueError('Fresh attack invalidation required')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', default='build/forest_depth/restore/native')
    args = parser.parse_args()
    out = (ROOT / args.output_dir).resolve()
    if not out.is_relative_to(ROOT / 'build/forest_depth/restore') or out.exists():
        parser.error('Fresh output below build/forest_depth/restore required')
    out.mkdir(parents=True)
    before = level_formal.source_files()
    verifier = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in (Path(__file__).resolve(), ROOT / 'tests/forest_depth_restore_runner.gd')}
    receipt = {'scope': 'Actual DemoApp Guardian reload/legacy compatibility; normal-input earned-state integration, NOT Boss content admission',
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
            text = run_engine(['--headless', '--fixed-fps', '60', '--path', '.', '--script',
                'tests/forest_depth_restore_runner.gd', '--',
                '--output=res://' + str((out / 'capture.json').relative_to(ROOT))], 90)
        if not re.search(r'^FOREST DEPTH RESTORE: [1-9]\d* assertions, 0 failures$', text, re.M):
            raise RuntimeError('Complete native restore result missing')
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
            raise RuntimeError('Source changed during native restore check')
    print('PASS: actual App V6 earned-state reload and legacy compatibility; full Boss content admission NOT covered')


if __name__ == '__main__':
    main()
