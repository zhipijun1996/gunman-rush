"""Fresh double-window real-input golden and cheap alternatives, NOT region promotion.

Run only in a guarded runtime snapshot under the host's shared engine lock.
First budget: import 90s; four native processes share ONE total 90s deadline.
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
from run_forest_directional_golden import _resource_errors

ROOT = Path(__file__).resolve().parents[1]
VARIANTS = ('airH_recoil', 'deepH_zeroR', 'return_R', 'return_none')
OWN = ('scripts/generation/forest_hollow_trunk_geometry.gd',
       'scripts/demo/forest_hollow_trunk_golden.gd',
       'tests/forest_hollow_trunk_runner.gd', 'tools/run_forest_hollow_trunk.py')


def validate(data):
    errors = []
    frames = data.get('frames', [])
    if len(frames) < 30:
        return ['complete continuous body trace required']
    if data.get('midroute_injection') is not False or data.get('manual_motor_step') is not False:
        errors.append('real normal-input consumer required')
    if data.get('audio_released') is not True:
        errors.append('audio not drained')
    if data.get('initial_hp') != data.get('final_hp') or data.get('damage_events') or data.get('policy_returns'):
        errors.append('candidate recovery must be natural, without health/segment return')
    platforms = {row['id']: row for row in data['manifest']['platforms']}
    for i, frame in enumerate(frames):
        if frame.get('tick') != i+1 or frame.get('motor_steps') != 1:
            errors.append('continuous actual single Motor step trace required')
            break
        x, y = frame['position']
        body=frame.get('body')
        if not isinstance(body,list) or len(body)!=4 or any(abs(a-b)>0.001 for a,b in zip(body,[x-12,y-18,24,36])):
            errors.append('full production 24x36 body missing')
            break
        for key in frame.get('supports', []):
            px, py, w, _ = platforms[key]['rect']
            if not frame['grounded'] or abs(y+18-py)>1 or x-12<px or x+12>px+w:
                errors.append('support flag disagrees with actual body and platform')
    tuning = json.loads((ROOT/'config/player_tuning.json').read_text())
    errors += _resource_errors(frames, data.get('events', []), tuning)
    variant = data.get('variant')
    begin=data.get('return_start_tick',-1)
    returning=[e for e in data['events'] if e['tick']>begin]
    shots=[e for e in returning if e['kind']=='shot_fired']
    contacts=[e for e in returning if e['kind']=='hook_kick']
    if begin<0 or not data.get('reached'):
        errors.append('same actual outward prelude and crown departure required')
    if data.get('failure'):
        errors.append('actual native route failed: '+data['failure'])
    if variant in ('airH_recoil','deepH_zeroR','return_R'):
        if not data.get('returned') or not data.get('lower_entered'):
            errors.append('actual lower-window entry and complete belly return required')
    elif variant=='return_none':
        if not (data.get('returned') or data.get('direct_recovered')):
            errors.append('no-action descent must enter OR naturally land and recover')
    if variant in ('airH_recoil','deepH_zeroR'):
        if not any(e.get('target')=='lower_window_ring' for e in contacts):
            errors.append('actual lower-window hook contact required')
        expected=0 if variant=='deepH_zeroR' else 1
        if len(shots)!=expected:
            errors.append('return actual shot budget mismatch')
    elif (shots and variant=='return_none') or (variant=='return_R' and len(shots)!=1):
        errors.append('actual cheaper return shot control mismatch')
    if variant in ('return_R','return_none') and any(e['kind']=='hook_cast' for e in returning):
        errors.append('return-only H ablation actually cast H')
    return sorted(set(errors))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', default='build/forest_depth/hollow_trunk/native01')
    args=parser.parse_args()
    out=(ROOT/args.output_dir).resolve()
    if not out.is_relative_to(ROOT/'build/forest_depth/hollow_trunk') or out.exists():
        parser.error('Fresh output below build/forest_depth/hollow_trunk required')
    out.mkdir(parents=True)
    before=level_formal.source_files()
    own={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in OWN}
    snapshot=json.loads((ROOT/'build/snapshot-receipt.json').read_text())
    receipt={'scope':'New double-window development golden; not full region/content/device/player acceptance',
             'new_first_budgets_seconds':{'import':90,'all_native_combined':90},
             'base_commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
             'source_before':before,'producer_before':own,'cases':[],'passed':False}
    started=time.monotonic()
    try:
        with (out/'import.log').open('w') as log, contextlib.redirect_stdout(log):
            import_text=run_engine(['--headless','--path','.','--editor','--quit'],90)
        if re.search(r'(?m)^ERROR:|SCRIPT ERROR:|SHADER ERROR:',import_text):
            raise RuntimeError('Strict native import ERROR')
        deadline=time.monotonic()+90
        for variant in VARIANTS:
            row={'variant':variant,'passed':False}
            receipt['cases'].append(row)
            argv=['--headless','--fixed-fps','60','--path','.', '--script',
                  'tests/forest_hollow_trunk_runner.gd','--','--variant='+variant,
                  '--output=res://'+str((out/(variant+'.json')).relative_to(ROOT))]
            row['argv']=argv
            try:
                with (out/(variant+'.log')).open('w') as log, contextlib.redirect_stdout(log):
                    remaining=deadline-time.monotonic()
                    if remaining<=0: raise RuntimeError('Original combined native90 budget exhausted')
                    text=run_engine(argv,remaining)
                if re.search(r'(?m)^ERROR:|SCRIPT ERROR:|SHADER ERROR:',text):
                    raise RuntimeError('Strict native ERROR')
                if not re.search(r'^FOREST HOLLOW: '+re.escape(variant)+r' terminal ',text,re.M):
                    raise RuntimeError('actual terminal marker absent')
                data=json.loads((out/(variant+'.json')).read_text())
                row['validation_errors']=validate(data)
                row['passed']=not row['validation_errors']
                row['outcome']={k:data.get(k) for k in ('reached','returned','recovered','lower_entered','direct_recovered','return_start_tick','failure')}
                row['frames']=len(data['frames'])
            except Exception as error:
                row['error']=str(error)
                capture=out/(variant+'.json')
                log_text=(out/(variant+'.log')).read_text()
                # A terminal route failure is evidence for THIS independent
                # candidate, not a reason to skip the genuinely different one.
                if capture.is_file() and 'FOREST HOLLOW: '+variant+' terminal ' in log_text and not re.search(r'(?m)^ERROR:|SCRIPT ERROR:|ObjectDB.*leaked|resources? still in use',log_text):
                    data=json.loads(capture.read_text())
                    row['validation_errors']=validate(data)
                    row['outcome']={k:data.get(k) for k in ('reached','returned','lower_entered','failure')}
                    row['frames']=len(data['frames'])
                else:
                    raise
        captured=[json.loads((out/(variant+'.json')).read_text()) for variant in VARIANTS]
        departure=[]
        for data in captured:
            event=next((e for e in data['events'] if e.get('to')=='air_descent'),None)
            if event is None:
                departure.append(None)
            else:
                frame=next(f for f in data['frames'] if f['tick']==event['tick'])
                departure.append({k:frame[k] for k in ('position','velocity','health','energy','shots')})
        receipt['departure_states']=departure
        receipt['same_actual_departure']=all(state==departure[0] and state is not None for state in departure)
        receipt['passed']=all(row['passed'] for row in receipt['cases']) and receipt['same_actual_departure']
        if not receipt['passed']:
            raise RuntimeError('Actual hollow-trunk comparison rejected; see per-case validation errors')
    finally:
        receipt['elapsed_seconds']=time.monotonic()-started
        receipt['source_after']=level_formal.source_files()
        receipt['producer_after']={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in OWN}
        receipt['source_guard']=before==receipt['source_after'] and own==receipt['producer_after']
        receipt['snapshot_all_raw_bytes_unchanged']=all((ROOT/p).is_file() and hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==v for p,v in snapshot['source_files'].items())
        receipt['logs']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.is_file()}
        (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
        if not receipt['source_guard'] or not receipt['snapshot_all_raw_bytes_unchanged']:
            raise RuntimeError('Source changed during hollow golden')
    print('PASS: new hollow-trunk real-input loop/comparisons only; NOT full region')


if __name__=='__main__':
    main()
