"""Actual Godot D1-D3 goldens, physical island removal and raw-proof refusals."""
import copy, hashlib, itertools, json, math, re, subprocess, tempfile
from pathlib import Path
import harness, level_formal
from run_tests import REPO

def sources():
    result=level_formal.source_files()
    for name in ['tools/run_plains_experience_golden_tests.py','tools/run_plains_redesign_spatial_tests.py','tools/harness/profiles.json']:
        result[name]=hashlib.sha256((REPO/name).read_bytes()).hexdigest()
    return result

def valid(data, negative=False):
    try:
        assert data['version']=='plains-experience-golden-v1' and data['deleted_island'] is negative
        obs=data['observations']
        if negative:
            return data['failures']>0 and len(obs)==1 and obs[0]['kind']=='creek' and not obs[0]['passed'] and not obs[0]['visits'] and len(obs[0]['frames'])>100
        assert data['failures']==0 and len(obs)==16
        assert {(o['kind'],o['forward'],o['low'],o['phase']) for o in obs}==set(itertools.product(['remote','creek'],[True,False],[True,False],[0.,.5]))
        for o in obs:
            fs,es=o['frames'],o['events']; assert o['passed'] and len(fs)>100
            identity=(fs[0]['motor_id'],fs[0]['session_id'])
            assert fs[0]['energy']==(0 if o['low'] else fs[0]['energy_capacity'])
            for i,f in enumerate(fs):
                assert f['tick']==i and (f['motor_id'],f['session_id'])==identity and f['safe'] and f['continuous']
                assert 0<=f['energy']<=f['energy_capacity'] and all(math.isfinite(v) for v in f['position']+f['normal_velocity']+f['recoil_velocity'])
                if i: assert math.dist(f['position'],fs[i-1]['position'])<35
            assert fs[-1]['grounded'] and all(fs[-1]['support'])
            shots=[e for e in es if e['kind']=='accepted_shot']; commits=[e for e in es if e['kind']=='latch_committed']
            for e in shots:
                assert any(q['kind']=='input_request' and q['action']=='shoot_release' and q['tick']==e['tick'] for q in es)
                transactions=[q for q in es if q['kind']=='energy_transaction' and q['event_id']==f"shot/{identity[1]}/{e['shot_id']}"]
                assert len(transactions)==1 and transactions[0]['amount']==-fs[0]['shot_cost'] and transactions[0]['status']==0
                assert math.dist(e['position'],fs[e['tick']-1]['position'])<.001
            if o['kind']=='remote':
                assert len(shots)==2 and len(commits)==1 and shots[0]['tick']<shots[1]['tick']<=commits[0]['tick']
                upper=fs[shots[1]['tick']]; assert upper['grounded'] and all(upper['support']) and shots[1]['position'][1]<220
                assert math.dist(shots[1]['position'],shots[0]['position'])>80
                if o['forward']:assert shots[1]['position'][0]-shots[0]['position'][0]>300
                assert fs[-1]['latches'][0]['open'] and fs[-1]['latches'][0]['gate_disabled']
                assert any(f['latches'][0]['sequence_step']==1 for f in fs[shots[0]['tick']:shots[1]['tick']])
            else:
                assert len(shots)==len(commits)==3 and [e['open_count'] for e in commits]==[1,2,3]
                assert len(o['visits'])==1
                visit=o['visits'][0]; t=visit['tick']; assert visit==fs[t] and visit['grounded'] and all(visit['support']) and math.dist(visit['position'],[420,192])<1
                assert len([e for e in es if e['kind']=='grounded_island_callback'])==1
                assert commits[1]['tick']<t<shots[2]['tick']<=commits[2]['tick']
                parked=fs[t]['latches'][0]; assert not parked['motion_running']
                assert all(not f['latches'][0]['motion_running'] and f['latches'][0]['motion_clock']==parked['motion_clock'] and f['latches'][0]['platform_position']==parked['platform_position'] for f in fs[t-10:t+1])
                assert fs[-1]['latches'][0]['motion_running'] and fs[-1]['latches'][0]['motion_clock']>parked['motion_clock']
                boat_support=lambda f:f['grounded'] and abs(f['position'][1]-282)<1 and abs(f['position'][0]-f['latches'][0]['platform_position'][0])<55
                assert any(boat_support(f) for f in fs[commits[0]['tick']:commits[1]['tick']])
                assert any(boat_support(f) for f in fs[t+1:shots[2]['tick']])
                assert math.dist(fs[-1]['position'],[780 if o['forward'] else 20,282])<1
        ts=data['tolerance'];assert len(ts)==18
        assert {(o['forward'],o['release_ticks'],o['takeoff_offset']) for o in ts}==set(itertools.product([True,False],[5,7,9],[-8,0,8]))
        expected=hashlib.sha256((REPO/'resources/generation/modules/plains_low_arch.tres').read_bytes()).hexdigest()
        for o in ts:
            assert o['definition_version']==2 and o['definition_sha256']==expected and o['saw_origin']==[320,308] and o['saw_radius']==18
            assert o['platforms']==[[0,300,640,32],[200,160,240,18]]
            jumps=[e for e in o['events'] if e['kind']=='accepted_jump'];assert len(jumps)==1
            releases=[e for e in o['events'] if e['kind']=='input_request' and e['action']=='jump_release' and e['tick']>jumps[0]['tick']]
            assert releases and releases[0]['tick']-jumps[0]['tick']==o['release_ticks']
            assert abs(jumps[0]['position'][0]-((275 if o['forward'] else 365)+o['takeoff_offset']))<1
            assert o['passed'] is True and all(f['safe'] and f['continuous'] for f in o['frames'])
            assert all(any(h['position']==[320,308] and h['radius']==18 for h in f['hazards']) for f in o['frames'])
            fs=o['frames'];assert len({(f['motor_id'],f['session_id']) for f in fs})==1 and fs[-1]['grounded'] and all(fs[-1]['support'])
            assert math.dist(fs[-1]['position'],[620 if o['forward'] else 20,282])<1
            for i,f in enumerate(fs):
                assert f['tick']==i
                if i:assert math.dist(f['position'],fs[i-1]['position'])<35
        cs=data['space_controls'];assert len(cs)==2 and {o['kind'] for o in cs}=={'walk_without_jump','held_jump_bonks_ceiling'}
        walk=next(o for o in cs if o['kind']=='walk_without_jump');assert not walk['safe'] and any(not f['safe'] for f in walk['frames']) and not any(e['kind']=='accepted_jump' for e in walk['events'])
        held=next(o for o in cs if o['kind']=='held_jump_bonks_ceiling');assert held['ceiling_contact'] and any(any(c['normal'][1]>.7 for c in f['collisions']) for f in held['frames'])
        routes=data['exploration_first'];assert len(routes)==1
        o=routes[0];assert o['upper'] and o['main_untouched'] and o['returned'] and len(o['shots'])==2
        fs={f['tick']:f for f in o['frames']};start,end=o['start_tick'],o['end_tick'];index=o['latch_index']
        assert not fs[start]['latches'][index]['open'] and fs[end]['latches'][index]['open'] and fs[end]['latches'][index]['gate_disabled']
        assert all(start<e['tick']<=end for e in o['shots']) and math.dist(fs[end]['position'],[0,0])<1
        assert len({(f['motor_id'],f['session_id']) for f in o['frames']})==1 and all(f['safe'] and f['continuous'] for f in o['frames'])
        return True
    except (AssertionError,KeyError,TypeError,ValueError,IndexError): return False

def main():
    base=REPO/'build/plains_redesign/experience';base.mkdir(parents=True,exist_ok=True);folder=Path(tempfile.mkdtemp(prefix='run_',dir=base))
    before=sources();receipt={'status':'failed','source_before':before,'runs':[]}
    try:
        for negative in [False,True]:
            name='deleted_island' if negative else 'positive';out=folder/(name+'.json')
            cmd=['bash','tools/godot.sh','--headless','--fixed-fps','60','--path','.','--script','tests/plains_experience_golden_runner.gd','--','--output='+str(out)]+(['--delete-island'] if negative else [])
            result=harness.run_check({'argv':cmd,'timeout_seconds':180,'success_pattern':r'^PLAINS EXPERIENCE NATIVE: [1-9]\d* assertions, 0 failures$'},folder/(name+'.log'),REPO)
            data=json.loads(out.read_text()) if out.is_file() else {};ok=result['exit_code']==(1 if negative else 0) and valid(data,negative) and not re.search(r'SCRIPT ERROR:|Parse Error:|SHADER ERROR:',(folder/(name+'.log')).read_text())
            receipt['runs'].append({'command':cmd,'result':result,'valid':ok,'sha256':hashlib.sha256(out.read_bytes()).hexdigest() if out.is_file() else None})
            if not ok:raise RuntimeError('Actual experience proof failed '+str(folder))
        data=json.loads((folder/'positive.json').read_text());refusals=[]
        for name in ['empty_frames','missing_stop','missing_restart','missing_island','forged_island','missing_shot','wrong_sightline','empty_return','teleport','missing_upper_return','forged_tolerance','missing_tolerance_corner','missing_tolerance_release','old_definition','missing_walk_hazard']:
            bad=copy.deepcopy(data);o=next(o for o in bad['observations'] if o['kind']=='creek' and not o['forward'])
            if name=='missing_upper_return':bad['exploration_first']=[]
            elif name=='forged_tolerance':bad['tolerance'][0]['frames'][20]['safe']=False
            elif name=='missing_tolerance_corner':bad['tolerance'].pop()
            elif name=='missing_tolerance_release':bad['tolerance'][0]['events']=[e for e in bad['tolerance'][0]['events'] if not(e['kind']=='input_request' and e['action']=='jump_release')]
            elif name=='old_definition':bad['tolerance'][0]['definition_version']=1
            elif name=='missing_walk_hazard':bad['space_controls'][0]['frames']=[]
            elif name=='empty_frames':o['frames']=[]
            elif name=='missing_stop':o['events']=[e for e in o['events'] if not(e['kind']=='latch_committed' and e['open_count']==2)]
            elif name=='missing_restart':o['events']=[e for e in o['events'] if not(e['kind']=='latch_committed' and e['open_count']==3)]
            elif name=='missing_island':o['visits']=[]
            elif name=='forged_island':o['visits'][0]['position'][0]+=200
            elif name=='missing_shot':o['events']=[e for e in o['events'] if e['kind']!='accepted_shot']
            elif name=='wrong_sightline':
                o=next(o for o in bad['observations'] if o['kind']=='remote');[e for e in o['events'] if e['kind']=='accepted_shot'][1]['position'][1]=282
            elif name=='empty_return':bad['observations']=[x for x in bad['observations'] if x is not o]
            else:o['frames'][20]['position'][0]+=1000
            refused=not valid(bad);refusals.append({'case':name,'refused':refused})
            if not refused:raise RuntimeError('Accepted false proof '+name)
        (folder/'validator_refusals.json').write_text(json.dumps(refusals,indent=2)+'\n')
        receipt['source_after']=sources();assert before==receipt['source_after'],'changed source during native proof'
        receipt['status']='passed';print('PLAINS EXPERIENCE GOLDEN: actual differentiated routes and encounter counterexamples validated')
    finally:
        (folder/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print('PLAINS EXPERIENCE RECEIPT: '+str(folder/'receipt.json'))
if __name__=='__main__':main()
