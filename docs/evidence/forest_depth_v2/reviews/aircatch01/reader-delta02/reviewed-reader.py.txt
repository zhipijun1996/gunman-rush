"""Fresh double-window real-input golden and cheap alternatives, NOT region promotion.

Run only in a guarded runtime snapshot under the host's shared engine lock.
First budget: import 90s; four native processes share ONE total 90s deadline.
"""
import argparse
import contextlib
import hashlib
import json
import math
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


def validate(data, aircatch=False):
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
    if aircatch:
        errors += validate_aircatch(data)
    return sorted(set(errors))


def validate_aircatch(data):
    """New opt-in scope; old validation/default cases are not weakened."""
    errors=[];fs=data['frames'];events=data['events'];m=data['manifest']
    if data.get('aircatch_geometry') is not True or m.get('version')!='forest-hollow-lower-aircatch-candidate-v1' or not m.get('aircatch_contract'):errors.append('actual aircatch factory contract missing')
    ps={r['id']:r for r in m['platforms']}
    if ps.get('outer_root',{}).get('rect')!=[366,300,334,40] or ps.get('inner_root',{}).get('rect')!=[-310,220,460,40]:errors.append('actual two corner cuts missing')
    if m.get('spawn')!=[0,0] or m.get('dangers')!=[]:errors.append('normal M spawn and unchanged hazard-free local geometry required')
    if not any(a.get('id')=='lower_window_ring' and a.get('position')==[120,155] for a in m['hook_anchors']):errors.append('original low ring changed')
    for f in fs:
        if not isinstance(f.get('motor_contacts'),list) or not isinstance(f.get('normal_velocity'),list) or not isinstance(f.get('recoil_remaining'),(float,int)):errors.append('actual collider/normal velocity/recoil trace missing');break
        values=f['position']+f['velocity']+f['normal_velocity']+[f['energy'],f['health'],f['recoil_remaining']]
        if any(type(v) not in (int,float) or not math.isfinite(v) for v in values):errors.append('finite actual body/velocity/resource trace required')
        x,y=f['position']
        for row in ps.values():
            if row['one_way']:continue
            px,py,w,h=row['rect']
            if min(x+12,px+w)-max(x-12,px)>.2 and min(y+18,py+h)-max(y-18,py)>.2:errors.append('actual body overlaps solid trunk/root')
    def longest(key):
        n=best=0
        for f in fs:n=n+1 if key in f.get('supports',[]) else 0;best=max(best,n)
        return best
    if longest('outer_crown')<12 or longest('inner_root')<12 or not all('belly_entry' in f.get('supports',[]) for f in fs[-12:]):errors.append('complete E12 D12 M12 fullbody supports required')
    begin=data.get('return_start_tick',-1)
    returning=[e for e in events if e['tick']>begin]
    casts=[e for e in returning if e['kind']=='hook_cast'];contacts=[e for e in returning if e['kind']=='hook_contact_kick']
    if data['variant']=='deepH_zeroR':
        if len(casts)!=1 or len(contacts)!=1 or contacts[0].get('target')!='lower_window_ring':errors.append('one real lower H Motor arrival required')
        else:
            cast=casts[0]['tick'];arrival=contacts[0]['tick']
            departures=[r for r in data['requests'] if begin<r.get('tick',-1)<cast and r.get('kind')=='drop_through' and r.get('queued') is True]
            departure=departures[0]['tick'] if len(departures)==1 else -1
            transition=[e for e in returning if e.get('kind')=='phase' and e.get('from')=='air_depart' and e.get('to')=='air_descent']
            previous_departure=next((f for f in fs if f['tick']==departure-1),None)
            if len(departures)!=1 or len(transition)!=1 or transition[0].get('tick')!=departure:
                errors.append('departure request not bound to actual phase transition')
            elif previous_departure is None or previous_departure.get('grounded') is not True or 'outer_crown' not in previous_departure.get('supports',[]) or departures[0].get('grounded_before') is not True or departures[0].get('body_before')!=previous_departure['position'] or departures[0].get('velocity_before')!=previous_departure['velocity'] or transition[0].get('position')!=previous_departure['position']:
                errors.append('departure before-state not actual supported crown Motor frame')
            window=[f for f in fs if departure<=f['tick']<=arrival]
            if departure<0 or not departure<cast<arrival or len(window)!=arrival-departure+1:errors.append('actual single departure through Motor arrival interval missing')
            if not window or any(f['grounded'] or f.get('supports') or f.get('raw_floor_contacts') or f.get('motor_contacts') for f in window):errors.append('descending H touched support before Motor contact')
            requests=[r for r in data['requests'] if r.get('tick')==cast and r.get('kind')=='grapple' and r.get('queued') is True]
            origin=[requests[0]['body_before'][0],requests[0]['body_before'][1]-6] if len(requests)==1 and isinstance(requests[0].get('body_before'),list) and len(requests[0]['body_before'])==2 else None
            hook_window=[f for f in fs if cast<=f['tick']<=arrival]
            if origin is None or any(f.get('hook_start')!=origin for f in hook_window):errors.append('request-time hook origin changed during cast/pull/arrival')
            before=next((f for f in fs if f['tick']==cast-1),None)
            if not before or before['grounded'] or before['velocity'][1]<=0:errors.append('H must actually start in normal descent')
            if not any(f['hook_state']=='hook_pull' for f in window):errors.append('real moving hook pull trace required')
    elif data['variant']!='return_R':errors.append('aircatch initial scope is H0R and strongest one-R only')
    for e in events:
        kind=e.get('kind')
        if kind not in ['shot_fired','hook_cast']:continue
        request_kind='shoot_release' if kind=='shot_fired' else 'grapple'
        requests=[r for r in data['requests'] if r.get('tick')==e['tick'] and r.get('kind')==request_kind and r.get('queued') is True]
        if len(requests)!=1 or not isinstance(requests[0].get('body_before'),list) or not isinstance(requests[0].get('velocity_before'),list):errors.append('actual action request/body/velocity binding missing')
        else:
            previous=next((f for f in fs if f['tick']==e['tick']-1),None)
            if previous is None or requests[0]['body_before']!=previous['position'] or requests[0]['velocity_before']!=previous['velocity'] or requests[0].get('grounded_before')!=previous['grounded']:errors.append('request before-state not actual preceding Motor frame')
            if kind=='shot_fired' and requests[0].get('direction')!=e.get('direction'):errors.append('accepted shot direction not actual queued input')
    return errors


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', default='build/forest_depth/hollow_trunk/native01')
    parser.add_argument('--aircatch',action='store_true',help='New continuous descent H0R versus earliest body-fit one-R; same original native90 total')
    args=parser.parse_args()
    case_variants=('deepH_zeroR','return_R') if args.aircatch else VARIANTS
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
    if args.aircatch:
        receipt["aircatch_contract"]={"variants":list(case_variants),"scope":"continuous descending H0R correction only, not random-region depth", "first_causal_failure_stops":True,"same_normal_M_E_D_M":True}
    started=time.monotonic()
    try:
        with (out/'import.log').open('w') as log, contextlib.redirect_stdout(log):
            import_text=run_engine(['--headless','--path','.','--editor','--quit'],90)
        if re.search(r'(?m)^ERROR:|SCRIPT ERROR:|SHADER ERROR:',import_text):
            raise RuntimeError('Strict native import ERROR')
        deadline=time.monotonic()+90
        for variant in case_variants:
            row={'variant':variant,'passed':False}
            receipt['cases'].append(row)
            argv=['--headless','--fixed-fps','60','--path','.', '--script',
                  'tests/forest_hollow_trunk_runner.gd','--','--variant='+variant,
                  '--output=res://'+str((out/(variant+'.json')).relative_to(ROOT))]
            if args.aircatch:argv.append('--aircatch')
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
                row['validation_errors']=validate(data,aircatch=args.aircatch)
                row['passed']=not row['validation_errors']
                row['outcome']={k:data.get(k) for k in ('reached','returned','recovered','lower_entered','direct_recovered','return_start_tick','failure')}
                row['frames']=len(data['frames'])
                if args.aircatch:
                    arrival=next((e for e in data['events'] if e.get('from')=='air_land_inner' and e.get('to')=='inner_walk'),None)
                    row['D12_state']=next(({k:f[k]for k in ('tick','position','velocity','health','energy','shots','supports')}for f in data['frames']if arrival is not None and f['tick']==arrival['tick']),None)
                    row['final_M12_state']={k:data['frames'][-1][k]for k in ('tick','position','velocity','health','energy','shots','supports')}

            except Exception as error:
                row['error']=str(error)
                capture=out/(variant+'.json')
                log_text=(out/(variant+'.log')).read_text()
                # A terminal route failure is evidence for THIS independent
                # candidate, not a reason to skip the genuinely different one.
                if capture.is_file() and 'FOREST HOLLOW: '+variant+' terminal ' in log_text and not re.search(r'(?m)^ERROR:|SCRIPT ERROR:|ObjectDB.*leaked|resources? still in use',log_text):
                    data=json.loads(capture.read_text())
                    row['validation_errors']=validate(data,aircatch=args.aircatch)
                    row['outcome']={k:data.get(k) for k in ('reached','returned','lower_entered','failure')}
                    row['frames']=len(data['frames'])
                else:
                    raise
            if args.aircatch and not row['passed']:
                raise RuntimeError('First aircatch causal failure; no further cases')
        captured=[json.loads((out/(variant+'.json')).read_text()) for variant in case_variants]
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
