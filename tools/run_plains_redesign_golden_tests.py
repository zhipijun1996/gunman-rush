"""Native continuous Golden proof, with raw state validation and a real missing-bank rejection.

Each run has a new directory; failures and original traces are never overwritten.
This is a development fixture, not formal region/visual/device admission.
"""
import hashlib
import itertools
import json
import math
from pathlib import Path
import re
import subprocess
import tempfile

import harness
import level_formal
from run_tests import REPO


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sources():
    result = level_formal.source_files()
    for name in ('tools/run_plains_redesign_golden_tests.py', 'tools/harness/profiles.json'):
        result[name] = digest(REPO / name)
    return result


def validate_phrases(o):
    """Bind both complete legs to frames and accepted physical transactions."""
    frames, events = o['frames'], o['events']
    initial=frames[0]
    assert o['initial']==initial and o['final']==frames[-1], 'outer frame boundaries'
    modules=['plains_windchime_well','plains_low_arch'] if o['kind']=='main' else ['plains_recoil_step','plains_remote_sequence','plains_bell_ferry_control']
    previous_end=3; labels=set()
    for li,leg in enumerate(o['legs']):
        forward=o['forward_entry'] if li==0 else not o['forward_entry']
        assert leg['forward'] is forward, 'ordered leg direction'
        ordered=modules if forward else modules[::-1]
        assert [p['label'] for p in leg['phrases']]==[f"{o['kind']}/{li}/{m}" for m in ordered], 'complete ordered phrases in each leg'
        for p,module in zip(leg['phrases'],ordered):
            labels.add(p['label']); start,end=p['start']['tick'],p['end']['tick']
            assert start==previous_end and start<end<len(frames), 'consecutive frame-bound phrase times'
            for boundary,tick in [(p['start'],start),(p['end'],end)]:
                assert {k:v for k,v in boundary.items() if k!='phrase'}=={k:v for k,v in frames[tick].items() if k!='phrase'}, 'actual frame boundary; phrase changes only between ticks'
            previous_end=end
            ev=[e for e in events if e['phrase']==p['label']]
            assert all(start<e['tick']<=end for e in ev), 'phrase event frame range'
            jumps=[e for e in ev if e['kind']=='accepted_jump']; lands=[e for e in ev if e['kind']=='accepted_landing']
            shots=[e for e in ev if e['kind']=='accepted_shot']; commits=[e for e in ev if e['kind']=='latch_committed']
            for e in jumps+shots:
                assert math.dist(e['position'],frames[e['tick']-1]['position'])<.001, 'accepted action actual pre-Motor origin'
                action='jump' if e['kind']=='accepted_jump' else 'shoot_release'
                assert any(q['kind']=='input_request' and q['action']==action and q['tick']==e['tick'] for q in ev), 'accepted action Router request'
            for e in lands:
                f=frames[e['tick']]
                assert f['grounded'] and all(f['support']) and math.dist(f['position'],e['position'])<.001, 'actual supported landing frame'
            for shot in shots:
                spends=[e for e in ev if e['kind']=='energy_transaction' and e['event_id']==f"shot/{initial['session_id']}/{shot['shot_id']}"]
                assert len(spends)==1 and spends[0]['tick']==shot['tick'] and spends[0]['status']==0 and spends[0]['operation']=='consume'
                assert spends[0]['amount']==-initial['shot_cost'] and spends[0]['current']==shot['energy']==frames[shot['tick']]['energy'], 'same-shot resource transaction'
                assert shot['recoil_remaining']>0 and frames[shot['tick']]['recoil_remaining']>0, 'accepted shot native recoil'
            assert not any(e['kind']=='energy_transaction' and e['event_id'].startswith('hit/') for e in ev), 'no enemy-hit recovery'
            if module in ['plains_recoil_step','plains_windchime_well','plains_low_arch']:
                assert len(jumps)==1 and len(lands)==1 and jumps[0]['tick']<lands[0]['tick'], 'complete one-jump phrase'
            if module=='plains_recoil_step':
                assert len(shots)==(1 if forward else 0), 'actual ascent shot versus descent'
                if forward:
                    shot=shots[0]; f=frames[shot['tick']]
                    assert jumps[0]['tick']<shot['tick']<lands[0]['tick'] and shot['direction'][1]>.9
                    assert not f['grounded'] and f['recoil_velocity'][1]<0 and shot['charges']==initial['max_air_shots']-1
                    assert lands[0]['position'][1]<jumps[0]['position'][1]-180, 'higher receiver acquired'
                else: assert lands[0]['position'][1]>jumps[0]['position'][1]+180, 'lower receiver on return'
            if module=='plains_remote_sequence':
                before,after=p['start']['latches'][0],p['end']['latches'][0]
                if before['open']:
                    assert before['gate_disabled'] and before['open_count']==1 and before['sequence_step']==1
                    assert not shots and not commits and not jumps and not lands, 'persistent remote return'
                    assert all(f['latches'][0]['open'] and f['latches'][0]['gate_disabled'] for f in frames[start:end+1]), 'actual open gate persists'
                    assert any(e['kind']=='latch_health_commit' and e['tick']<=start for e in events), 'return permission has earlier actual receipt'
                else:
                    assert not before['gate_disabled'] and before['sequence_step']==0
                    assert len(shots)==2 and len(jumps)==1 and len(lands)==2 and len(commits)==1, 'complete closed remote actions'
                    a,b=shots; commit=commits[0]
                    assert a['tick']<jumps[0]['tick']<lands[0]['tick']<b['tick']<=commit['tick']<lands[1]['tick']
                    upper=frames[b['tick']]
                    assert upper['grounded'] and all(upper['support']) and b['position'][1]<p['start']['position'][1]-80
                    assert abs(b['position'][1]-lands[0]['position'][1])<.001, 'shot uses elevated landing support'
                    key=f"{initial['motor_id']}:{initial['session_id']}:{a['shot_id']}"
                    assert any(f['latches'][0]['sequence_step']==1 and key in f['latches'][0]['seen'] for f in frames[a['tick']:b['tick']]), 'first real projectile precedes second'
                    health=[e for e in ev if e['kind']=='latch_health_commit']
                    assert len(health)==1 and health[0]['event_id']==f"{initial['motor_id']}:{initial['session_id']}:{b['shot_id']}"
                    assert health[0]['tick']==commit['tick'] and health[0]['operation']=='damage' and health[0]['status']==0 and health[0]['current']==0
                assert after['open'] and after['gate_disabled'] and after['open_count']==1 and after['sequence_step']==1
            if module=='plains_bell_ferry_control':
                before=p['start']['latches'][1]; count=before['open_count']; running=before['motion_running']
                assert len(shots)==len(commits)==(2 if running else 3), 'all actual toggle shots/commits in each direction'
                assert len(jumps)==len(lands)==2 and jumps[0]['tick']<lands[0]['tick']<jumps[1]['tick']<lands[1]['tick']
                stop=None
                for shot,commit in zip(shots,commits):
                    count+=1;running=not running;t=commit['tick'];f=frames[t]['latches'][1]
                    assert shot['tick']<t<jumps[0]['tick'] and commit['open_count']==count and f['open_count']==count
                    assert f['motion_running']==running and f['open']==running, 'shot commits actual motion transition'
                    assert any(e['kind']=='projectile_impact' and shot['tick']<=e['tick']<=t for e in ev), 'toggle has actual projectile collision'
                    if not running: stop=t
                    elif stop is not None:
                        parked=frames[stop:t]
                        assert len(parked)>=30 and all(not f['latches'][1]['motion_running'] for f in parked)
                        assert len({f['latches'][1]['motion_clock'] for f in parked})==1 and len({tuple(f['latches'][1]['platform_position']) for f in parked})==1, 'stopped clock and position preserved'
                        assert frames[t+2]['latches'][1]['motion_clock']>frames[stop]['latches'][1]['motion_clock'], 'restart preserved phase advances'
                board=frames[lands[0]['tick']];platform=board['latches'][1]['platform_position']
                assert abs(board['position'][0]-platform[0])<48 and abs(board['position'][1]+18-(platform[1]-12))<.2, 'actual ferry boarding'
                assert p['end']['latches'][1]['motion_running'] and p['end']['latches'][1]['open_count']==count
    assert previous_end==o['final']['tick'], 'complete legs span actual final frame'
    assert all(e['phrase'] in labels or e['phrase']=='initial' for e in events), 'assigned itinerary events'


def validate_positive(data):
    observations = data.get('observations', [])
    expected = set(itertools.product(('main', 'high'), (True, False), (True, False), (0, .125, .25, .375, .5, .625, .75, .875)))
    actual = [(o['kind'], o['forward_entry'], o['low_initial_energy'], o['phase']) for o in observations]
    assert len(actual) == len(expected) and set(actual) == expected, 'complete unique phase/direction/energy matrix'
    assert data['failures'] == 0 and not data['broken_bank'] and not data['smoke']
    for o in observations:
        frames, events = o['frames'], o['events']
        assert frames[0]['energy'] == (0 if o['low_initial_energy'] else frames[0]['energy_capacity'])
        assert [f['tick'] for f in frames] == list(range(len(frames))), 'actual every-frame state'
        assert all(f['motor_id'] == frames[0]['motor_id'] and f['session_id'] == frames[0]['session_id'] for f in frames)
        assert all(f['safe'] and f['continuous'] for f in frames), 'unchanged complete-body/hazard sweep'
        assert all(math.dist(a['position'], b['position']) <= 30 for a,b in zip(frames,frames[1:])), 'native movement continuity'
        assert all(0 <= f['energy'] <= f['energy_capacity'] for f in frames)
        assert {f['weapon'] for f in frames} == {'pulse_gun'}, 'single unchanged actual base weapon'
        assert all(f['max_jumps']==1 and not f['hook_enabled'] and not f['wall_enabled'] for f in frames), 'actual S1 capability boundary'
        assert len(o['legs']) == 2 and all(l['reached'] for l in o['legs'])
        validate_phrases(o)
        assert o['shots'] == len([e for e in events if e['kind']=='accepted_shot'])
        accepted_shots = [e for e in events if e['kind']=='accepted_shot']
        assert [e['shot_id'] for e in accepted_shots] == list(range(1,len(accepted_shots)+1))
        assert all((b['tick']-a['tick'])/60+1e-9 >= frames[0]['shot_cooldown'] for a,b in zip(accepted_shots,accepted_shots[1:])), 'real cooldown'
        for leg in o['legs']:
            for p in leg['phrases']:
                end = p['end']
                assert p['reached'] and end['grounded'] and all(end['support']) and end['cooldown']==0
                assert end['used_jumps']==0 and end['shot_charges']==end['max_air_shots']
                assert end['normal_velocity']==[0,0] and end['recoil_velocity']==[0,0]
                ev = [e for e in events if e['phrase']==p['label']]
                jumps = [e for e in ev if e['kind']=='accepted_jump']
                landings = [e for e in ev if e['kind']=='accepted_landing']
                if p['label'].endswith('plains_low_arch'):
                    assert len(jumps)==1 and landings
                    release = next(e for e in ev if e['kind']=='input_request' and e['action']=='jump_release' and e['tick']>jumps[0]['tick'])
                    assert release['tick']-jumps[0]['tick']==7
                    assert not any(e['kind']=='accepted_shot' for e in ev)
                if p['label']=='main/0/plains_windchime_well' and o['forward_entry']:
                    shots = [e for e in ev if e['kind']=='accepted_shot']
                    commits = [e for e in ev if e['kind']=='latch_committed']
                    assert len(shots)==1 and len(commits)==1 and len(jumps)==1 and landings
                    shot,commit = shots[0],commits[0]
                    assert shot['direction'][1]>.9 and shot['charges']==1 and shot['recoil_remaining']>0
                    assert jumps[0]['tick']<shot['tick']<=commit['tick']<landings[-1]['tick']
                    assert commit['gate_disabled'] and commit['open_count']==1
                    health = [e for e in ev if e['kind']=='latch_health_commit']
                    assert len(health)==1 and health[0]['event_id']==f"{frames[0]['motor_id']}:{frames[0]['session_id']}:{shot['shot_id']}"
                    assert health[0]['operation']=='damage' and health[0]['status']==0 and health[0]['current']==0
                    spends = [e for e in ev if e['kind']=='energy_transaction' and e['operation']=='consume']
                    assert len(spends)==1 and spends[0]['event_id']==f"shot/{frames[0]['session_id']}/{shot['shot_id']}"
                    assert spends[0]['amount']==-frames[0]['shot_cost']
                    assert not any(e['kind']=='energy_transaction' and e['event_id'].startswith('hit/') for e in ev), 'mechanism hit never grants enemy recovery'
                    following = [f for f in frames if shot['tick']<f['tick']<=shot['tick']+10]
                    assert any(f['recoil_velocity'][1]<0 and f['recoil_remaining']>0 for f in following)
                    assert min(f['position'][1] for f in following)<shot['position'][1]-100
            for a,b in zip(leg['phrases'],leg['phrases'][1:]):
                assert a['end']['tick']<b['end']['tick'] and a['end']['tick']==b['start']['tick'], 'no reset between actual phrases'
        if o['kind']=='high':
            # The optional third beat contains actual moving phase, parked phase and
            # restart, never a reset or a metadata-only phase proof.
            moving = [f['latches'][-1] for f in frames if f['latches'][-1]['motion_running']]
            parked = [f['latches'][-1] for f in frames if not f['latches'][-1]['motion_running'] and f['latches'][-1]['open_count']>=2]
            assert moving and parked
            assert len({tuple(f['platform_position']) for f in moving})>30
            assert any(a['motion_clock']==b['motion_clock'] and a['platform_position']==b['platform_position'] for a,b in zip(parked,parked[1:]))
            assert max(f['open_count'] for f in moving)>=5, 'real park/restart in both directions'
    controls = data.get('controls', [])
    assert {c['kind'] for c in controls} == {'air_low_energy','cooldown_guard'}
    for c in controls:
        ev = c['events']
        shots = [e for e in ev if e['kind']=='accepted_shot']
        rejected = [e for e in ev if e['kind']=='rejected_shot']
        assert all(f['safe'] and f['continuous'] for f in c['frames'])
        assert not any(e['kind']=='latch_committed' for e in ev)
        if c['kind']=='air_low_energy':
            assert c['initial']['energy']==0 and not shots and any(e['reason']=='energy' for e in rejected)
        else:
            assert len(shots)==1 and any(e['reason']=='cooldown' for e in rejected)
    return True


def validate_rejections(data):
    """Corrupt copies of evidence references, never the native original file."""
    results=[]
    def probe(name,mutate):
        undo=mutate()
        try:
            validate_positive(data)
            rejected=False; reason='unexpected acceptance'
        except (AssertionError,KeyError,ValueError,StopIteration,TypeError,IndexError) as exc:
            rejected=True; reason=f'{type(exc).__name__}: {exc}'
        finally:
            undo()
        results.append({'mode':name,'rejected':rejected,'reason':reason})
    def replace(obj,key,value):
        old=obj[key];obj[key]=value
        return lambda:obj.update({key:old})
    high=next(o for o in data['observations'] if o['kind']=='high' and o['forward_entry'])
    def empty_high():
        old=[(o,o['events'],o['shots']) for o in data['observations'] if o['kind']=='high']
        for o,_,_ in old:o['events']=[];o['shots']=0
        return lambda:[o.update(events=ev,shots=count) for o,ev,count in old]
    def empty_return():
        old=[(o['legs'][1],o['legs'][1]['phrases']) for o in data['observations'] if o['kind']=='high']
        for leg,_ in old:leg['phrases']=[]
        return lambda:[leg.update(phrases=phrases) for leg,phrases in old]
    def omit(kind,module):
        ev=high['events']; victim=next(e for e in ev if e['kind']==kind and e['phrase'].endswith(module))
        return replace(high,'events',[e for e in ev if e is not victim])
    probe('empty_high_events_and_zero_shot_count',empty_high)
    probe('empty_high_second_leg_phrases',empty_return)
    for name,kind,module in [('missing_step_landing','accepted_landing','plains_recoil_step'),('missing_remote_health_receipt','latch_health_commit','plains_remote_sequence'),('missing_remote_gate_commit','latch_committed','plains_remote_sequence'),('missing_ferry_toggle_commit','latch_committed','plains_bell_ferry_control'),('missing_step_energy_receipt','energy_transaction','plains_recoil_step'),('missing_step_input','input_request','plains_recoil_step')]:
        if kind=='energy_transaction':
            def mutate():
                victim=next(e for e in high['events'] if e['kind']=='energy_transaction' and e['operation']=='consume' and e['phrase'].endswith('plains_recoil_step'))
                return replace(high,'events',[e for e in high['events'] if e is not victim])
        elif kind=='input_request':
            def mutate():
                victim=next(e for e in high['events'] if e['kind']=='input_request' and e['action']=='shoot_release' and e['phrase'].endswith('plains_recoil_step'))
                return replace(high,'events',[e for e in high['events'] if e is not victim])
        else: mutate=lambda k=kind,m=module:omit(k,m)
        probe(name,mutate)
    probe('wrong_high_second_leg_direction',lambda:replace(high['legs'][1],'forward',high['legs'][0]['forward']))
    probe('false_high_phrase_frame_boundary',lambda:replace(high['legs'][0]['phrases'][0]['end'],'energy',-1))
    receipt=next(e for e in high['events'] if e['kind']=='latch_health_commit')
    probe('wrong_high_session_shot_receipt',lambda:replace(receipt,'event_id','wrong:session:shot'))
    assert all(r['rejected'] for r in results), 'evidence corruption escaped: '+str(results)
    validate_positive(data) # Restoration must leave the actual positive valid.
    return results


def main():
    base = REPO/'build/plains_redesign/golden'
    base.mkdir(parents=True, exist_ok=True)
    folder = Path(tempfile.mkdtemp(prefix='run_',dir=base))
    before = sources()
    report = {'status':'failed','source_before':before,'source_after':None,'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=REPO,text=True).strip(),'runs':[],'scope':'G0/G1 development fixture; production_pool=false; enemy/visual/device/player proof unverified'}
    try:
        for negative in (False,True):
            name='deleted_bank_negative' if negative else 'positive'
            output=folder/(name+'.json'); log=folder/(name+'.log')
            command=['bash',str(REPO/'tools/godot.sh'),'--headless','--fixed-fps','60','--path',str(REPO),'--script','tests/plains_redesign_golden_runner.gd','--','--output='+str(output)]
            if negative: command.append('--delete-far-bank')
            process=harness.run_check({'argv':command,'timeout_seconds':180,'success_pattern':r'^PLAINS REDESIGN GOLDEN: [1-9]\d* assertions, 0 failures$'},log,REPO)
            raw=json.loads(output.read_text()) if output.is_file() else {}
            valid=False; error=None
            try:
                assert not re.search(r'SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ERROR: Failed to load script',log.read_text())
                if negative:
                    assert process['exit_code']==1 and raw['broken_bank'] and raw['failures']>0
                    assert len(raw['observations'])==1 and not raw['observations'][0]['legs'][0]['reached']
                    assert raw['observations'][0]['final']['tick']>30
                    assert 'FAIL: negative removes' not in log.read_text()
                    assert any(e['kind']=='accepted_jump' for e in raw['observations'][0]['events'])
                else:
                    assert process['status']=='passed'
                    validate_positive(raw)
                    rejections=validate_rejections(raw)
                    regression_output=folder/'validator_rejections.json'
                    regression_output.write_text(json.dumps({'source_output':str(output.relative_to(REPO)),'source_output_sha256':digest(output),'results':rejections},indent=2)+'\n')
                    report['validator_rejections']={'path':str(regression_output.relative_to(REPO)),'sha256':digest(regression_output),'cases':len(rejections),'all_rejected':True}
                valid=True
            except (AssertionError,KeyError,ValueError,StopIteration,TypeError,IndexError) as exc:
                error=str(exc) or type(exc).__name__
            report['runs'].append({'command':command,'process':process,'expected_exit_code':1 if negative else 0,'expected_rejection':negative,'validated':valid,'validation_error':error,'output':str(output.relative_to(REPO)),'output_sha256':digest(output) if output.is_file() else None,'log':str(log.relative_to(REPO)),'log_sha256':digest(log)})
            if not valid: raise RuntimeError(f'{name}: real proof failed ({error}); retained {folder}')
        report['source_after']=sources()
        assert report['source_after']==before, 'source changed during actual run'
        report['status']='passed'
        print('PLAINS REDESIGN GOLDEN: real positive and negative cases validated',flush=True)
        return 0
    finally:
        report['source_after']=sources()
        (folder/'receipt.json').write_text(json.dumps(report,indent=2)+'\n')
        print('PLAINS REDESIGN RECEIPT: '+str((folder/'receipt.json').relative_to(REPO)),flush=True)


if __name__=='__main__':
    raise SystemExit(main())
