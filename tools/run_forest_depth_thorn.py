"""Actual optional thorn return: purpose jump versus same-bank omitted jump.

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
    if data.get('failures') or len(data.get('cases', [])) != 2:
        raise ValueError('Both complete real App thorn controls required')
    rows = {r['id']: r for r in data['cases']}
    if set(rows) != {'purpose_horizontal', 'wrong_recoil'}:
        raise ValueError('Purpose and cheapest wrong-recoil control required')
    if rows['purpose_horizontal']['manifest'] != rows['wrong_recoil']['manifest']:
        raise ValueError('Controls must retain identical actual generated map bytes')
    for name, row in rows.items():
        if row.get('failures') or row.get('audio_released') is not True:
            raise ValueError('Full route/local receiving support/teardown required: '+name)
        if row.get('manual_motor_step') is not False or row.get('position_or_resource_injection') is not False:
            raise ValueError('Privileged motion or resource setup forbidden')
        frames = row.get('frames', [])
        if not frames or any(f.get('tick') != i+1 or f.get('motor_steps') != 1 for i,f in enumerate(frames)):
            raise ValueError('Continuous actual Motor frames required')
        if row['final']['health'] <= 0 or len(row['completed_legs']) != len(row['itinerary']):
            raise ValueError('Complete surviving continuation to safe route endpoint required')
        if row['manifest'].get('dangers') != [[810.0,482.0,120.0,24.0]]:
            raise ValueError('Exact single candidate bramble required')
        hits=[e for e in row['events'] if e.get('kind') == 'committed_damage' and str(e.get('source','')).startswith('generated_spikes_') and e.get('target') == 'player' and e.get('amount',0)>0]
        omitted=[e for e in row['events'] if e.get('kind') == 'thorn_wrong_recoil_direction']
        if name == 'purpose_horizontal' and (hits or omitted or row.get('changed_shot')):
            raise ValueError('Purpose must clear actual thorn without its damage')
        if name == 'wrong_recoil' and (not hits or len(omitted)!=1 or row.get('changed_shot') is not True):
            raise ValueError('Error must cause real Policy thorn damage after actual H from same safe bank')
        if name == 'wrong_recoil' and not any(e.get('kind')=='actual_thorn_segment_return' for e in row['events']):
            raise ValueError('Actual App Policy/Segment recovery must be recorded before successful retry')
        endpoint=next(a['position'] for a in row['manifest']['areas'] if a['id']=='gate_ready')
        if any(abs(row['final']['position'][i]-endpoint[i])>8 for i in range(2)):
            raise ValueError('Real surviving route endpoint required')
        platforms={p['id']:p['rect'] for p in row['manifest']['platforms']}
        def full(frame, support):
            rect=platforms.get(support);point=frame.get('position',[])
            return rect and len(point)==2 and point[0]-12>=rect[0]-.1 and point[0]+12<=rect[0]+rect[2]+.1 and abs(point[1]+18-rect[1])<1
        contacts=[e for e in row['events'] if e.get('kind')=='hook_contact_kick' and e.get('target')=='hollow__upper_window_ring']
        if not contacts:
            raise ValueError('Actual upper-window H contact required in both controls')
        for leg in row['completed_legs']:
            window=[f for f in frames if leg['tick']-11<=f['tick']<=leg['tick']]
            if len(window)!=12 or any(not f.get('grounded') or not any(full(f,id) for id in f.get('supports',[])) for f in window):
                raise ValueError('Twelve actual support frames per completed leg required')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', default='build/forest_depth/thorn/native')
    args = parser.parse_args()
    out = (ROOT / args.output_dir).resolve()
    if not out.is_relative_to(ROOT / 'build/forest_depth/thorn') or out.exists():
        parser.error('Fresh output below build/forest_depth/thorn required')
    out.mkdir(parents=True)
    before = level_formal.source_files()
    verifier = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in (Path(__file__).resolve(), ROOT / 'tests/forest_depth_thorn_runner.gd', ROOT / 'tests/forest_depth_thorn_trace.gd')}
    receipt = {'scope': 'Actual DemoApp upper H-window thorn boundary and recoil-direction Policy control; NOT whole-region admission',
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
                'tests/forest_depth_thorn_runner.gd', '--',
                '--output=res://' + str((out / 'capture.json').relative_to(ROOT))], 90)
        if not re.search(r'^FOREST DEPTH THORN: 2 cases, 0 failures$', text, re.M):
            raise RuntimeError('Complete native thorn controls missing')
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
            raise RuntimeError('Source changed during native thorn controls')
    print('PASS: actual optional thorn purpose and real Policy wrong-recoil recovery control; NOT whole-region admission')


if __name__ == '__main__':
    main()
