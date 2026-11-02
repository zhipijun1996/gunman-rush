"""Bounded floorless canopy comparison; existing real Hollow consumer, not promotion."""
import argparse,contextlib,hashlib,json,re,time,subprocess
from pathlib import Path
import level_formal
from run_tests import run_engine
from run_forest_directional_golden import _resource_errors
ROOT=Path(__file__).resolve().parents[1]
VARIANTS=('H0R','noH_zeroR','noH_oneR','wrongH','noH_bay','cavity_HR','noH_cavity_twoR','cavity_wrongR','noH_cavity_outer','elbow_HR','elbow_H0R','noH_elbow_oneR')
def _cavity_resource_errors(frames,events,tuning,reset_ticks):
    """Original shot economy, plus proven production SegmentRespawn action reset.

    Reset ticks come only from the independently checked ENV/epoch/body/HP facts.
    Stamina and recovery delay survive; no energy boost is permitted by a return.
    """
    resource=(ROOT/'game/player/resources/plains_shot_energy.tres').read_text()
    definition=(ROOT/'game/combat/resources/definitions/shot_energy_definition.gd').read_text()
    def number(name):
        found=re.search(r'(?m)^'+name+r'\s*=\s*([\d.]+)',resource) or re.search(r'var '+name+r'\s*:=\s*([\d.]+)',definition)
        return float(found.group(1))
    capacity=number('capacity');energy=number('initial_current');cost=number('shot_energy_cost');recovery=number('ground_recovery');delay_limit=number('recovery_delay')
    delay=0.;shots=tuning['max_air_shots'];previous_grounded=False;hook_used=False;errors=[];dt=1/tuning['physics_hz']
    for f in frames:
        accepted=[e for e in events if e['tick']==f['tick'] and e['kind']=='shot_fired']
        if any(e['tick']==f['tick'] and e['kind']=='hook_cast' for e in events):hook_used=True
        if (f['grounded'] and not previous_grounded) or any(e['tick']==f['tick'] and e['kind']=='hook_kick' for e in events):hook_used=False
        if f['tick'] in reset_ticks:hook_used=False
        if f['hook_used']!=hook_used and 'H_token_not_actual_cast_contact_or_ground' not in errors:errors.append('H_token_not_actual_cast_contact_or_ground')
        jumped=any(e['tick']==f['tick'] and e['kind']=='jumped' for e in events)
        recovery_delta=max(0.,dt-delay);delay=max(0.,delay-dt)
        if previous_grounded:energy=min(capacity,energy+recovery*recovery_delta)
        started_grounded=previous_grounded and not jumped
        for _ in accepted:
            energy-=cost;delay=delay_limit
            if not started_grounded:shots-=1
        if f['grounded']:shots=tuning['max_air_shots']
        elif started_grounded:shots=max(0,shots-len(accepted))
        if not 0<=f['energy']<=capacity and 'energy_outside_real_capacity' not in errors:errors.append('energy_outside_real_capacity')
        if abs(f['energy']-energy)>.001 and 'energy_not_actual_shot_cost_delay_and_ground_recovery' not in errors:errors.append('energy_not_actual_shot_cost_delay_and_ground_recovery')
        if f['tick'] in reset_ticks:shots=tuning['max_air_shots']
        if f['shots']!=shots and 'charges_not_actual_accepted_shot_and_ground_reset' not in errors:errors.append('charges_not_actual_accepted_shot_and_ground_reset')
        previous_grounded=f['grounded']
    return errors

def validate_cavity(d):
    errors=[];fs=d.get('frames',[]);ps={p['id']:p for p in d['manifest']['platforms']}
    if not fs:return ['continuous capture missing']
    if any(not isinstance(f,dict) or not isinstance(f.get('tick'),int) or not isinstance(f.get('position'),list) or len(f['position'])!=2 or not isinstance(f.get('body'),list) or len(f['body'])!=4 or type(f.get('grounded')) is not bool for f in fs):return ['full continuous body/state contract missing']
    if d.get('failure') or not d.get('returned'):errors.append('actual bounded complete recovery required')
    if not d.get('audio_released') or d.get('manual_motor_step') is not False or d.get('midroute_injection') is not False:errors.append('real input/lifecycle required')
    for i,f in enumerate(fs):
        if f['tick']!=i+1 or f['motor_steps']!=1:errors.append('one real Motor per continuous tick');break
        x,y=f['position']
        if f['body']!=[x-12,y-18,24,36] and any(abs(a-b)>.001 for a,b in zip(f['body'],[x-12,y-18,24,36])):errors.append('body envelope missing')
        for key in f['supports']:
            px,py,w,_=ps[key]['rect']
            if not f['grounded'] or abs(y+18-py)>1 or x-12<px or x+12>px+w:errors.append('false fullsupport')
    for index,f in enumerate(fs):
        x,y=f['position']
        for row in ps.values():
            if row['one_way']:continue
            px,py,w,h=row['rect']
            if min(x+12,px+w)-max(x-12,px)>.2 and min(y+18,py+h)-max(y-18,py)>.2:errors.append('body inside actual solid')
        if f['grounded']:
            poses=[f['position'],fs[max(0,index-1)]['position']]
            if not any(any(x+12>row['rect'][0]-.2 and x-12<row['rect'][0]+row['rect'][2]+.2 and abs(y+18-row['rect'][1])<=1 for x,y in poses) for row in ps.values()):errors.append('grounded without real support')
    by_tick={f['tick']:f for f in fs};reset_ticks=set()
    damages=d.get('damage_events',[]);returns=d.get('policy_returns',[])
    enum_source=(ROOT/'game/combat/damage/damage_request.gd').read_text()
    kinds=[x.strip() for x in re.search(r'enum Kind \{([^}]+)\}',enum_source).group(1).split(',')]
    environment_kind=kinds.index('ENVIRONMENT')
    for r in returns:
        hits=[e for e in damages if e.get('tick')==r.get('tick')]
        f=by_tick.get(r.get('tick'));previous=by_tick.get(r.get('tick',0)-1)
        valid=(r.get('returned') is True and len(hits)==1 and f is not None and previous is not None
               and r.get('actor_epoch_after')==r.get('actor_epoch_before',-2)+1
               and r.get('to')==d['manifest']['spawn'] and f['position']==r.get('to'))
        if valid:
            hit=hits[0];sid=hit.get('source','');match=re.fullmatch(r'hollow_thorns_(\d+)',sid)
            valid=(match is not None and int(match.group(1))<len(d['manifest']['dangers'])
                   and hit.get('kind')==environment_kind and hit.get('amount')==1
                   and hit.get('hp')==f['health']==previous['health']-hit['amount']
                   and hit.get('actor_epoch')==r['actor_epoch_after'])
            if valid:
                x,y=r['from'];px,py,w,h=d['manifest']['dangers'][int(match.group(1))]
                valid=min(x+12,px+w)>=max(x-12,px) and min(y+18,py+h)>=max(y-18,py)
        if valid:reset_ticks.add(r['tick'])
        else:errors.append('return lacks actual ENV body/HP/epoch/anchor proof')
    if len(reset_ticks)!=len(returns) or len(damages)!=len(returns):errors.append('damage/return causal cardinality mismatch')
    for a,b in zip(fs,fs[1:]):
        if b['tick'] not in reset_ticks and a['health']!=b['health']:errors.append('health changed without proven ENV return')
    if d['final_hp']!=fs[-1]['health'] or d['initial_hp']!=fs[0]['health']:errors.append('health summary mismatch')
    errors+=_cavity_resource_errors(fs,d['events'],json.loads((ROOT/'config/player_tuning.json').read_text()),reset_ticks)
    for e in d['events']:
        if e['kind']=='shot_fired' and not any(r.get('tick')==e['tick'] and r.get('kind')=='shoot_release' and r.get('direction')==e.get('direction') and r.get('queued') is True for r in d['requests']):errors.append('accepted shot lacks actual input request')
        if e['kind']=='hook_cast' and not any(r.get('tick')==e['tick'] and r.get('kind')=='grapple' and r.get('queued') is True for r in d['requests']):errors.append('accepted H lacks actual input request')

    if not all('cavity_observe' in f['supports'] for f in fs[-12:]):errors.append('real S recovery fullsupport12 missing')
    if d['variant']=='cavity_wrongR':
        if len(reset_ticks)!=1:errors.append('one real ENV Segment return required')
        if d.get('reached') or not d['damage_events'] or not d['policy_returns'] or d['final_hp']!=d['initial_hp']-1:errors.append('wrong direction actual Policy damage and segment recovery required')
    else:
        if not d.get('reached') or d['damage_events'] or d['policy_returns']:errors.append('direct real cavity route without damage required')
        for support in (['cavity_exit'] if d['variant']=='noH_cavity_outer' else ['cavity_bay','cavity_exit']):
            n=0;best=0
            for f in fs:
                n=n+1 if support in f['supports'] else 0;best=max(best,n)
            if best<12:errors.append(support+' fullsupport12 missing')
        contacts=[e for e in d['events'] if e['kind']=='hook_contact_kick']
        if d['variant']=='cavity_HR' and (len(contacts)!=2 or {e.get('target') for e in contacts}!={'cavity_ring_a','cavity_ring_b'}):errors.append('actual two cell H contacts required')
        expected_shots={'cavity_HR':2,'noH_cavity_twoR':4,'noH_cavity_outer':0}
        if d['variant'] in expected_shots and sum(e['kind']=='shot_fired' for e in d['events'])!=expected_shots[d['variant']]:errors.append('declared actual shot strategy missing')
        if d['variant'].startswith('noH') and any(e['kind']=='hook_cast' for e in d['events']):errors.append('control used H')
        if d['variant']=='noH_cavity_outer' and any(e['kind']=='shot_fired' for e in d['events']):errors.append('ordinary outside control used R')
    if d['manifest'].get('cavity_contract',{}).get('variant')=='horizontal_then_airborne_descending_elbow':
        relay='elbow_return_relay';count=best=0
        for f in fs:
            count=count+1 if relay in f['supports'] and f['tick']>d['return_start_tick'] else 0;best=max(best,count)
        if best<12:errors.append('actual ordinary relay fullsupport12 after C required')
        if any(e['kind']=='shot_fired' and e['tick']>d['return_start_tick'] for e in d['events']):errors.append('relay return must use ordinary jumps without R')
        if d['variant']=='noH_elbow_oneR':
            shots=[e for e in d['events'] if e['kind']=='shot_fired']
            second=[r for r in d['requests'] if r['kind']=='shoot_release' and r.get('cell')==1 and r.get('queued') is True]
            if len(shots)!=3 or len(second)!=1:errors.append('strong ordinary requires original first2R plus exactly1 second airborneR')
            elif second[0].get('grounded_before') is not False or second[0].get('body_before',[0,0])[0]-12<ps['cavity_bay']['rect'][0]+ps['cavity_bay']['rect'][2]:errors.append('second ordinaryR must really depart bay airborne, never claim grounded154')
        if d['variant'] in ('elbow_HR','elbow_H0R'):
            contacts=[e for e in d['events'] if e['kind']=='hook_contact_kick']
            if len(contacts)!=2 or [e.get('target') for e in contacts]!=['cavity_ring_a','cavity_ring_b']:errors.append('two actual ordered cell body arrivals required')
            shots=[e for e in d['events'] if e['kind']=='shot_fired']
            expected=2 if d['variant']=='elbow_HR' else 1
            if len(shots)!=expected:errors.append('declared elbow actual shot count mismatch')
            requests=[e for e in d['requests'] if e['kind']=='grapple' and e.get('cell')==1 and e.get('queued') is True]
            if len(requests)!=1:errors.append('one actual second-cell hook request required')
            else:
                req=requests[0];point=req.get('body_before',[]);origin=req.get('hook_origin_before',[]);bay=ps['cavity_bay']['rect']
                if len(point)!=2 or len(origin)!=2 or req.get('grounded_before') is not False or point[0]-12<bay[0]+bay[2] or any(abs(a-b)>.001 for a,b in zip(origin,[point[0],point[1]-6])) or req.get('direction',[0,0])[1]<=0:errors.append('second H must depart actual bay airborne and aim downward from actual fixed origin')
                target=next(a['position'] for a in d['manifest']['hook_anchors'] if a['id']=='cavity_ring_b')
                hook_range=float(re.search(r'(?m)^hook_range\s*=\s*([\d.]+)',(ROOT/'resources/player/traversal.tres').read_text()).group(1))
                if len(origin)==2 and sum((a-b)**2 for a,b in zip(origin,target))>hook_range**2+.001:errors.append('second H exceeded actual configured range')
                arrival=next((e for e in contacts if e.get('target')=='cavity_ring_b'),None)
                if arrival:
                    path=[f for f in fs if req['tick']<=f['tick']<=arrival['tick']]
                    if not path or any(f['hook_start']!=origin for f in path):errors.append('actual fixed second hook origin changed')
                    grounded=[f for f in fs if arrival['tick']<f['tick']<=d['return_start_tick'] and f['grounded']]
                    if not grounded or 'cavity_exit' not in grounded[0]['raw_floor_contacts']:errors.append('second hook first actual ground must be C partial/full receiver, not hidden trunk floor')
                    if not any(c['collider']=='cavity_ring_b' for f in path for c in f['probe_contacts']):errors.append('actual ShapeCast target collider proof missing')
                    f=by_tick.get(arrival['tick'])
                    if not f or sum((a-b)**2 for a,b in zip(f['position'],f['hook_tip']))>30.051**2:errors.append('body did not really arrive inside native stop30')
            cstart=next((e['tick'] for e in d['events'] if e['kind']=='phase' and e.get('to')=='elbow_return_align'),None)
            if cstart!=d['return_start_tick']:errors.append('actual C reception does not start declared relay return')
    return sorted(set(errors))
def validate(d):
    if 'cavity_contract' in d['manifest']:return validate_cavity(d)
    errors=[];fs=d.get('frames',[]);ps={p['id']:p for p in d['manifest']['platforms']}
    if not fs:return ['continuous capture missing']
    if d.get('manual_motor_step') is not False or d.get('midroute_injection') is not False:errors.append('normal input consumer required')
    if d.get('failure') or not d.get('reached') or not d.get('returned'):errors.append('actual crown and complete natural entry return required')
    if not d.get('audio_released'):errors.append('audio release missing')
    if d['damage_events'] or d['policy_returns'] or d['initial_hp']!=d['final_hp']:errors.append('natural recovery without damage/segment required')
    for i,f in enumerate(fs):
        if f['tick']!=i+1 or f['motor_steps']!=1:errors.append('continuous one Motor per frame required');break
        x,y=f['position']
        if any(abs(a-b)>.001 for a,b in zip(f['body'],[x-12,y-18,24,36])):errors.append('full body missing');break
        for key in f['supports']:
            px,py,w,_=ps[key]['rect']
            if not f['grounded'] or abs(y+18-py)>1 or x-12<px or x+12>px+w:errors.append('support/body mismatch')
    errors+=_resource_errors(fs,d['events'],json.loads((ROOT/'config/player_tuning.json').read_text()))
    if not all('belly_entry' in f['supports'] for f in fs[-12:]):errors.append('final entry fullsupport12 missing')
    shared=bool(d['manifest'].get('upper_candidate_contract',{}).get('preserved_lower_ports'))
    crown=next((e for e in d['events'] if e.get('to')==('shared_depart' if shared else 'crown_return')),None)
    if not crown or not all('outer_crown' in f['supports'] for f in fs if crown['tick']-11<=f['tick']<=crown['tick']):errors.append('crown fullsupport12 missing')
    all_shots=[e for e in d['events'] if e['kind']=='shot_fired']
    shots=[e for e in all_shots if not shared or e['tick']<=d['return_start_tick']]
    hooks=[e for e in d['events'] if e['kind']=='hook_contact_kick']
    if d['variant']=='H0R' and (shots or not any(e['target']=='upper_window_ring' for e in hooks) or d['recovered']):errors.append('zero-shot actual H direct crossing required')
    if shared:
        if not d.get('lower_entered'):errors.append('actual preserved lower-window D reception missing')
        landing=next((e for e in d['events'] if e.get('from')=='shared_inner_land' and e.get('to')=='return_floor'),None)
        if not landing or not all('inner_root' in f['supports'] for f in fs if landing['tick']-11<=f['tick']<=landing['tick']):errors.append('lower-window actual D fullsupport12 missing')
        lower=[e for e in d['events'] if e['tick']>d['return_start_tick']]
        if d['variant'].startswith('noH'):
            if sum(e['kind']=='shot_fired' for e in lower)!=1:errors.append('actual cheapest lower one-R return required')
        elif not any(e['kind']=='hook_contact_kick' and e.get('target')=='lower_window_ring' for e in lower):errors.append('actual preserved deep lower H contact missing')
    if d['variant'].startswith('noH') and any(e['kind']=='hook_cast' for e in d['events']):errors.append('noH control cast')
    if d['variant']=='noH_oneR' and len(shots)!=1:errors.append('one actual shot control required')
    if d['variant']in ('noH_zeroR','wrongH','noH_bay') and shots:errors.append('zero-shot control actually fired')
    if d['variant']=='wrongH' and not d['recovered']:errors.append('wrong hook must actually recover below')
    return sorted(set(errors))
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--variants',nargs='+',choices=VARIANTS,default=['H0R']);ap.add_argument('--output-dir',required=True);ap.add_argument('--skip-import',action='store_true');ap.add_argument('--shared',action='store_true');ap.add_argument('--cavity',action='store_true');ap.add_argument('--cavity-elbow',action='store_true');ap.add_argument('--cast-offset',type=int,choices=[-3,0,3],default=0);ap.add_argument('--recoil-offset',type=int,choices=[0,3],default=0);ap.add_argument('--standing-hook',action='store_true');ap.add_argument('--launch-offset',type=int,choices=[-8,0,8],default=0);a=ap.parse_args()
    if a.cavity_elbow:
        if any(v not in ('elbow_HR','elbow_H0R','noH_cavity_outer','noH_elbow_oneR') for v in a.variants):ap.error('elbow uses explicit adapted strategies, never legacy four-shot driver')
        a.cavity=True
    elif any(v.startswith('elbow_') or v=='noH_elbow_oneR' for v in a.variants):ap.error('elbow strategies require --cavity-elbow')
    out=(ROOT/a.output_dir).resolve()
    if out.exists() or not out.is_relative_to(ROOT/'build'):ap.error('fresh output under build required')
    out.mkdir(parents=True);before=level_formal.source_files();snapshot_path=ROOT/'build/snapshot-receipt.json';snapshot=json.loads(snapshot_path.read_text()) if snapshot_path.exists() else None;r={'scope':'new canopy physical/resource hypothesis only; no regional admission','source_before':before,'snapshot_receipt_sha256':hashlib.sha256(snapshot_path.read_bytes()).hexdigest() if snapshot else None,'git_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'cases':[],'passed':False};start=time.monotonic()
    try:
        if not a.skip_import:
            with (out/'import.log').open('w')as log,contextlib.redirect_stdout(log):run_engine(['--headless','--path','.','--editor','--quit'],90)
        for variant in a.variants:
            row={'variant':variant,'passed':False};r['cases'].append(row);argv=['--headless','--fixed-fps','60','--path','.','--script','tests/forest_hollow_upper_runner.gd','--','--variant='+variant,'--output=res://'+str((out/(variant+'.json')).relative_to(ROOT))];
            if a.cavity_elbow:argv.append('--cavity-elbow')
            if a.shared:argv.append('--shared')
            if a.cavity:argv.extend(['--cavity','--cast-offset='+str(a.cast_offset),'--recoil-offset='+str(a.recoil_offset),'--launch-offset='+str(a.launch_offset)])
            if a.standing_hook:argv.append('--standing-hook')
            row['argv']=argv
            with (out/(variant+'.log')).open('w')as log,contextlib.redirect_stdout(log):text=run_engine(argv,45)
            if re.search(r'(?m)^ERROR:|SCRIPT ERROR:|SHADER ERROR:|ObjectDB.*leaked|resources? still in use',text):raise RuntimeError('strict native error')
            if 'FOREST HOLLOW: '+variant+' terminal 'not in text:raise RuntimeError('terminal marker missing')
            d=json.loads((out/(variant+'.json')).read_text());row['validation_errors']=validate(d);row['passed']=not row['validation_errors'];row['frames']=len(d['frames']);row['shots']=sum(e['kind']=='shot_fired'for e in d['events']);row['recovered']=d['recovered'];row['crown_tick']=d['return_start_tick']
            if not row['passed']:raise RuntimeError('candidate failed: '+str(row['validation_errors']))
        r['passed']=True
    finally:
        r['source_after']=level_formal.source_files();r['source_guard']=r['source_after']==before;r['copy_source_guard']=all((ROOT/p).is_file()and hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in snapshot['source_files'].items()) if snapshot else None;r['elapsed_seconds']=time.monotonic()-start;r['logs']={p.name:hashlib.sha256(p.read_bytes()).hexdigest()for p in out.iterdir()if p.is_file()};(out/'receipt.json').write_text(json.dumps(r,indent=2)+'\n')
        if not r['source_guard']or r['copy_source_guard'] is False:raise RuntimeError('source drift')
    print('PASS: floorless canopy specified actual routes only; not admitted')
if __name__=='__main__':main()
