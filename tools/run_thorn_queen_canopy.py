"""Actual-input canopy Queen v3; old v2 CLI and194 remain separate legacy consumers."""
import argparse,contextlib,hashlib,json,re,time,math
from pathlib import Path
from run_tests import run_engine
import level_formal
ROOT=Path(__file__).resolve().parent.parent

def validate(data, selected):
    if data.get('failures') or data.get('assertions',0)<12 or data.get('selected')!=selected:
        raise ValueError('Real assertions/selection failed; preserve original capture')
    if data.get('manual_motor_step') is not False or data.get('midroute_player_position_or_resource_writes') is not False:
        raise ValueError('Only normal real Player inputs permitted')
    if data.get('content_version')!='forest-queen-canopy-v3':raise ValueError('New exact content version required')
    frames=data['frames']; events=data['events']; rows=data['cases']
    for prev,f in zip(frames,frames[1:]):
        if prev['case']!=f['case']:continue
        if f['tick']!=prev['tick']+1 or f['motor_steps']!=prev['motor_steps']+1:raise ValueError('Sole Motor frame discontinuity')
        if math.dist(prev['boss_position'],f['boss_position'])>data['migration_speed']/60+.001:raise ValueError('Boss teleported')
        if f['actual_time_scale']!=1 or f['actual_focus']:raise ValueError('No unintended focus/time-scale mutation')
    by={(f['case'],f['tick']):f for f in frames}
    for e in events:
        if e.get('event')!='actual_queen_motor_motion':continue
        f=by.get((e['case'],e['tick']))
        if f is None or e['source_id']!=f['queen_motor_id'] or e['physics_frame']!=f['physics_frame']:raise ValueError('Motor actor/frame mismatch')
        if math.dist(e['after'],f['boss_position'])>.001:raise ValueError('Motor body telemetry mismatch')
        if math.dist([e['before'][i]+e['actual'][i] for i in range(2)],e['after'])>.001:raise ValueError('Actual travel mismatch')
        if math.hypot(*e['requested'])>data['migration_speed']/60+.001:raise ValueError('Motion speed changed')
    for row in rows:
        if (row['initial_player_hp'],row['initial_boss_hp'],row['initial_energy'])!=(5,24,100):raise ValueError('Unequal starting resources')
        if row['boss_hp']!=0 or row['player_hp']<=0 or row['support12']<12:raise ValueError('Full24HP natural fight and recovery required')
        own=[e for e in events if e.get('case')==row['id']]
        hits=[e for e in own if e.get('event')=='policy_result' and e.get('target')=='boss']
        if len(hits)!=24 or len({e['id'] for e in hits})!=24:raise ValueError('24 distinct actual Policy commits required')
        phases=[e for e in own if e.get('event')=='canopy_phase_started']
        if {e['phase'] for e in phases}!={2,3}:raise ValueError('Both new mechanisms must naturally start')
        if row['id']!='purpose' and any(e.get('event')=='actual_queued_input' and e.get('action')=='grapple' for e in own):raise ValueError('Ordinary used H')
        for e in phases:
            if e.get('body_flight_unchanged') is not True:raise ValueError('Field threshold must not rewrite committed body route')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output-dir', required=True)
    parser.add_argument('--case', choices=['all','purpose','ordinary_cut','ordinary_keep','lure'], default='purpose')
    args = parser.parse_args()
    out = (ROOT / args.output_dir).resolve()
    if not out.is_relative_to((ROOT / 'build/forest_depth/queen').resolve()):
        parser.error('output must be beneath build/forest_depth/queen')
    if out.exists() and any(out.iterdir()):
        parser.error('fresh output directory required')
    out.mkdir(parents=True, exist_ok=True)
    before = level_formal.source_files()
    verifier = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in [Path(__file__).resolve(), ROOT / 'tests/thorn_queen_canopy_runner.gd', ROOT / 'tests/support/forest_queen_canopy_fixture.gd']}
    receipt = {'case': args.case, 'scope': 'New canopy-v3 full-life prototype, legacy194 unchanged; no Boss admission',
               'source_before': before, 'verifier_before': verifier, 'passed': False}
    start = time.monotonic()
    try:
        with (out / 'import.log').open('w') as log, contextlib.redirect_stdout(log):
            imported = run_engine(['--headless', '--path', '.', '--editor', '--quit'], 90)
        receipt['editor_import_completed'] = True
        if re.search(r'(?m)^(?:SCRIPT )?ERROR:|Parse Error:', imported):
            raise RuntimeError('Editor import error')
        with (out / 'native.log').open('w') as log, contextlib.redirect_stdout(log):
            text = run_engine(['--headless', '--fixed-fps', '60', '--path', '.', '--script',
                               'tests/thorn_queen_canopy_runner.gd', '--',
                               f'--case={args.case}', f'--output-dir=res://{out.relative_to(ROOT)}'], 120)
        if not re.search(r'^CANOPY QUEEN GOLDEN: [1-9]\d* assertions, 0 failures$', text, re.M):
            raise RuntimeError('Complete native success marker required')
        if re.search(r'(^|\n)(?:SCRIPT )?ERROR:', text):
            raise RuntimeError('Engine resource/parse/runtime error')
        validate(json.loads((out / 'capture.json').read_text()), args.case)
        receipt['passed'] = True
    except BaseException as error:
        receipt['error'] = repr(error)
        receipt['inner_logs'] = [str(out / name) for name in ('import.log', 'native.log') if (out / name).exists()]
        for name in ('import.log', 'native.log'):
            path = out / name
            if path.exists():
                print(f'Actual {name} tail:', flush=True)
                print('\n'.join(path.read_text(errors='replace').splitlines()[-80:]), flush=True)
        raise
    finally:
        receipt['source_after'] = level_formal.source_files()
        receipt['source_guard'] = before == receipt['source_after']
        receipt['elapsed_seconds'] = time.monotonic() - start
        receipt['verifier_sha256'] = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                                     for path in [Path(__file__).resolve(), ROOT / 'tests/thorn_queen_canopy_runner.gd', ROOT / 'tests/support/forest_queen_canopy_fixture.gd']}
        receipt['verifier_guard'] = receipt['verifier_sha256'] == verifier
        (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        if not receipt['source_guard'] or not receipt['verifier_guard']:
            raise RuntimeError('Source changed during capture')
    print('PASS: Queen isolated mechanism technical observations; value and map2 admission UNVERIFIED')


if __name__ == '__main__':
    main()
