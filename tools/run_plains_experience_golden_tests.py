"""Actual Godot D1-D3 goldens, physical island removal and raw-proof refusals."""
import copy, hashlib, itertools, json, math, re, subprocess, tempfile
from pathlib import Path
import harness, level_formal
from run_tests import REPO

def sources():
    return level_formal.source_files(extra_paths=['tools/run_plains_experience_golden_tests.py',
        'tools/run_plains_redesign_spatial_tests.py','tools/harness/profiles.json'])

def paid_policy(frame):
    policy=frame['shot_policy']
    path=policy['definition_path']; assert path.startswith('res://')
    raw=(REPO/path[6:]).read_bytes()
    assert policy['definition_sha256']==hashlib.sha256(raw).hexdigest()
    # The actual configured resource, never the dormant numeric cost, chooses the contract.
    configured_free=bool(re.search(rb'^shooting_consumes_energy\s*=\s*false\s*$',raw,re.M))
    assert policy['shooting_consumes_energy'] is (not configured_free)
    if configured_free:
        assert path=='res://game/player/resources/demo_ui_01/time_energy_v2.tres'
        assert frame['max_air_shots']==json.loads((REPO/'config/player_tuning.json').read_text())['max_air_shots']==1
    return not configured_free

def shot_ledger(events, shot, before, after):
    transactions=[e for e in events if e['kind']=='energy_transaction' and e['event_id']==f"shot/{before['session_id']}/{shot['shot_id']}"]
    if paid_policy(after):
        assert len(transactions)==1
        tx=transactions[0];assert tx['tick']==shot['tick'] and tx['operation']=='consume' and tx['status']==0
        assert tx['amount']==-after['shot_cost'] and tx['current']==shot['energy']==after['energy']
    else:
        assert not transactions and shot['energy']==before['energy']==after['energy']
        assert shot['charges']==(before['shot_charges'] if before['grounded'] else before['shot_charges']-1)
        spawned=[e for e in events if e['kind']=='actual_projectile_spawned' and e['shot_id']==shot['shot_id']]
        impacts=[e for e in events if e['kind']=='actual_projectile_impact' and e['shot_id']==shot['shot_id']]
        assert len(spawned)==len(impacts)==1
        spawn,impact=spawned[0],impacts[0]
        assert spawn['tick']==shot['tick']<impact['tick'] and spawn['packet']>0
        assert (spawn['owner_id'],spawn['session_id'])==(before['motor_id'],before['session_id'])
        assert spawn['airborne'] is (not before['grounded'])
        assert math.dist(spawn['direction'],shot['direction'])<.00001 and math.dist(impact['direction'],shot['direction'])<.00001


def actor_causality(frames, events):
    """Actor signals and Router causes must exactly cover observed floor transitions."""
    assert frames and len({f['tick'] for f in frames})==len(frames)
    paid=paid_policy(frames[0])
    for f in frames:
        assert f['shot_policy']==frames[0]['shot_policy']
        if not paid:
            assert f['focus']=={'shared':True,'aiming':False,'active':False,'automatic_process':False}
            assert f['health']==frames[0]['health']>0
    if not paid and frames[0]['focus']['automatic_process'] is False:
        assert not any(e['kind']=='energy_transaction' for e in events), 'manual current fixture has no native energy transaction owner'
    by_tick={f['tick']:f for f in frames}
    lo,hi=min(by_tick),max(by_tick)
    assert sorted(by_tick)==list(range(lo,hi+1))
    assert len({(f['motor_id'],f['session_id']) for f in frames})==1
    assert all(isinstance(e['tick'],int) and lo<e['tick']<=hi for e in events)
    assert [e['tick'] for e in events]==sorted(e['tick'] for e in events)
    # Duplicate receipts are not additional actions or additional proof.
    assert len({json.dumps(e,sort_keys=True) for e in events})==len(events)
    for e in events:
        before,after=by_tick[e['tick']-1],by_tick[e['tick']]
        observed=after if e['kind']=='accepted_landing' else before
        assert math.dist(e['position'],observed['position'])<.001
    regeneration=json.loads((REPO/'config/player_tuning.json').read_text())
    max_recovery=regeneration['focus_stamina_recovery']/regeneration['physics_hz']
    for t in range(lo+1,hi+1):
        balance=by_tick[t-1]['energy']
        for tx in [e for e in events if e['kind']=='energy_transaction' and e['tick']==t]:
            assert tx['status']==0
            if tx['amount']>0:
                assert tx['operation']=='grant' and tx['event_id']=='' and tx['amount']<=max_recovery+.00001 and by_tick[t-1]['grounded']
            else:
                assert paid, 'unfocused current fixture has no debit owner'
                assert tx['operation']=='consume' and tx['event_id'].startswith('shot/')
            balance+=tx['amount'];assert abs(balance-tx['current'])<.00001
        assert abs(balance-by_tick[t]['energy'])<.00001
        if not paid:
            before,after=by_tick[t-1],by_tick[t]
            fired=[e for e in events if e['kind']=='accepted_shot' and e['tick']==t]
            # This fixture has no grant source; only real supported landing/ground
            # resets a round. Every actual emitted shot leaves one flight charge less.
            expected=after['max_air_shots'] if after['grounded'] else before['shot_charges']-len(fired)
            assert after['shot_charges']==expected and 0<=expected<=1
    jumps=[e for e in events if e['kind']=='accepted_jump']
    lands=[e for e in events if e['kind']=='accepted_landing']
    drops=[e for e in events if e['kind']=='input_request' and e['action']=='drop_through']
    land_ticks=[t for t in range(lo+1,hi+1) if not by_tick[t-1]['grounded'] and by_tick[t]['grounded']]
    leave_ticks=[t for t in range(lo+1,hi+1) if by_tick[t-1]['grounded'] and not by_tick[t]['grounded']]
    assert [e['tick'] for e in lands]==land_ticks
    assert sorted(e['tick'] for e in jumps+drops)==leave_ticks
    for e in jumps:
        t=e['tick'];before,after=by_tick[t-1],by_tick[t]
        requests=[q for q in events if q['kind']=='input_request' and q['action']=='jump' and q['tick']==t]
        assert len(requests)==1 and before['grounded'] and all(before['support'])
        assert not after['grounded'] and after['normal_velocity'][1]<0
        assert after['used_jumps']==before['used_jumps']+1
    for e in lands:
        f=by_tick[e['tick']];assert f['grounded'] and all(f['support'])
        assert f['used_jumps']==0 and f['shot_charges']==f['max_air_shots']
    for e in drops:
        before,after=by_tick[e['tick']-1],by_tick[e['tick']]
        assert before['grounded'] and all(before['support']) and not after['grounded'] and after['normal_velocity'][1]>0
    return by_tick,jumps,lands,drops


def encounter_causality(observation):
    """Golden action grammar, bound to actual actor/resource/projectile/mechanism frames."""
    fs,es=observation['frames'],observation['events']
    by_tick,jumps,lands,drops=actor_causality(fs,es)
    shots=[e for e in es if e['kind']=='accepted_shot']
    impacts=[e for e in es if e['kind']=='projectile_impact']
    commits=[e for e in es if e['kind']=='latch_committed']
    health=[e for e in es if e['kind']=='latch_health_commit']
    assert len(shots)==len(impacts) and len({e['shot_id'] for e in shots})==len(shots)
    identity=fs[0]['motor_id'],fs[0]['session_id']
    for shot,impact in zip(shots,impacts):
        t=shot['tick'];before,after=by_tick[t-1],by_tick[t]
        req=[e for e in es if e['kind']=='input_request' and e['action']=='shoot_release' and e['tick']==t]
        assert len(req)==1 and math.dist(req[0]['direction'],shot['direction'])<.00001
        assert math.dist(impact['direction'],shot['direction'])<.00001 and t<impact['tick']
        transactions=[e for e in es if e['kind']=='energy_transaction' and e['event_id']==f"shot/{identity[1]}/{shot['shot_id']}"]
        shot_ledger(es,shot,before,after)
        assert shot['recoil_remaining']>0 and after['recoil_remaining']>0
    assert not any(e['kind']=='energy_transaction' and e['event_id'].startswith('hit/') for e in es)
    def supported(event):
        f=by_tick[event['tick']];return f['grounded'] and all(f['support'])
    def boat(frame):
        return frame['grounded'] and all(frame['support']) and abs(frame['position'][1]-282)<1 and abs(frame['position'][0]-frame['latches'][0]['platform_position'][0])<48
    def island(frame):
        return frame['grounded'] and all(frame['support']) and math.dist(frame['position'],[420,192])<1
    # Every emitted mechanism commit must be the actual count transition, not a label.
    for n,event in enumerate(commits):
        t=event['tick'];a,b=by_tick[t-1]['latches'][0],by_tick[t]['latches'][0]
        assert event['open_count']==n+1 and a['open_count']==n and b['open_count']==n+1
        assert event['gate_disabled']==b['gate_disabled']
    transitions=[f['tick'] for a,f in zip(fs,fs[1:]) if a['latches'][0]['open_count']!=f['latches'][0]['open_count']]
    assert [e['tick'] for e in commits]==transitions
    if observation['kind']=='remote':
        assert len(jumps)==1 and len(lands)==3 and len(drops)==1 and len(health)==1
        first,second=shots;first_hit,second_hit=impacts;commit=commits[0];damage=health[0]
        upper,ground=lands[1:];jump=jumps[0];drop=drops[0]
        assert first['tick']<first_hit['tick']<jump['tick']<upper['tick']<second['tick']<second_hit['tick']==damage['tick']==commit['tick']<drop['tick']<ground['tick']
        sequence=[f['tick'] for a,f in zip(fs,fs[1:]) if a['latches'][0]['sequence_step']==0 and f['latches'][0]['sequence_step']==1]
        assert sequence==[first_hit['tick']]
        key=lambda shot:f"{identity[0]}:{identity[1]}:{shot['shot_id']}"
        assert key(first) in by_tick[first_hit['tick']]['latches'][0]['seen']
        assert damage['event_id']==key(second) and damage['operation']=='damage' and damage['status']==0 and damage['amount']==-1 and damage['current']==0
        assert not by_tick[commit['tick']-1]['latches'][0]['gate_disabled'] and by_tick[commit['tick']]['latches'][0]['gate_disabled'] and by_tick[commit['tick']]['latches'][0]['open']
        assert supported(upper) and supported(ground) and upper['position'][1]<ground['position'][1]-80
        assert math.dist(upper['position'],second['position'])<.001 and abs(ground['position'][1]-fs[0]['position'][1])<1
        assert math.dist(by_tick[drop['tick']-1]['position'],upper['position'])<1
    else:
        assert len(jumps)==3 and len(lands)==5 and len(drops)==1 and not health
        board_jump,island_jump,exit_jump=jumps
        initial,board_land,island_land,reboard_land,dock_land=lands
        start,park,restart=commits;drop=drops[0]
        visits=observation['visits'];callbacks=[e for e in es if e['kind']=='grounded_island_callback']
        assert len(visits)==len(callbacks)==1
        visit,callback=visits[0],callbacks[0]
        assert start['tick']<board_jump['tick']<board_land['tick']<shots[1]['tick']<park['tick']<island_jump['tick']<island_land['tick']<=visit['tick']<callback['tick']<drop['tick']<reboard_land['tick']<shots[2]['tick']<restart['tick']<exit_jump['tick']<dock_land['tick']
        assert visit==by_tick[callback['tick']-1] and math.dist(callback['position'],visit['position'])<.001 and island(visit)
        assert island(by_tick[callback['tick']]) and island(by_tick[drop['tick']-1])
        assert math.hypot(*visit['normal_velocity'])<.1 and math.hypot(*visit['recoil_velocity'])<.1
        for shot,impact,commit in zip(shots,impacts,commits):
            assert shot['tick']<impact['tick']==commit['tick']
        for n,commit in enumerate(commits):
            t=commit['tick'];before,after=by_tick[t-1]['latches'][0],by_tick[t]['latches'][0]
            assert before['motion_running'] is (n==1) and after['motion_running'] is (n!=1) and after['open'] is after['motion_running']
        park_clock=by_tick[park['tick']]['latches'][0]['motion_clock']
        park_position=by_tick[park['tick']]['latches'][0]['platform_position']
        assert all(not by_tick[t]['latches'][0]['motion_running'] and by_tick[t]['latches'][0]['motion_clock']==park_clock and by_tick[t]['latches'][0]['platform_position']==park_position for t in range(park['tick'],restart['tick']))
        assert boat(by_tick[board_land['tick']]) and boat(by_tick[island_jump['tick']-1]) and boat(by_tick[reboard_land['tick']]) and boat(by_tick[shots[2]['tick']-1]) and boat(by_tick[exit_jump['tick']-1])
        assert island(by_tick[island_land['tick']])
        assert all(island(by_tick[t]) for t in range(island_land['tick'],drop['tick']))
        assert by_tick[restart['tick']+1]['latches'][0]['motion_clock']>park_clock
        assert supported(dock_land) and abs(dock_land['position'][1]-282)<1
        assert (dock_land['position'][0]>=600) if observation['forward'] else (dock_land['position'][0]<=200)


def valid(data, negative=False):
    try:
        assert data['cleanup_ok'] is True, 'owned fallback backend cleanup must succeed even for expected geometry rejection'
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
            encounter_causality(o)
            shots=[e for e in es if e['kind']=='accepted_shot']; commits=[e for e in es if e['kind']=='latch_committed']
            for e in shots:
                assert any(q['kind']=='input_request' and q['action']=='shoot_release' and q['tick']==e['tick'] for q in es)
                transactions=[q for q in es if q['kind']=='energy_transaction' and q['event_id']==f"shot/{identity[1]}/{e['shot_id']}"]
                if paid_policy(fs[0]):
                    assert len(transactions)==1 and transactions[0]['amount']==-fs[0]['shot_cost'] and transactions[0]['status']==0
                else:
                    shot_ledger(es,e,fs[e['tick']-1],fs[e['tick']])
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
            actor_causality(o['frames'],o['events'])
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
        for control in cs:actor_causality(control['frames'],control['events'])
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

def causal_mutations(data):
    """Deletes, displaces and duplicates required causal evidence; never edits honest raw."""
    cases=['remove_jump_receipts','remove_landing_receipts','remove_drop_inputs','callback_at_tick_zero','remove_remote_health','jump_wrong_position','jump_wrong_tick','landing_wrong_position','landing_wrong_tick','duplicate_jump','duplicate_landing','duplicate_drop','drop_wrong_position','drop_after_reboard','callback_wrong_position','callback_at_start_bank','callback_after_restart','duplicate_callback','health_wrong_id','health_wrong_tick','duplicate_health','health_wrong_amount','impact_wrong_direction','remove_impact','missing_resource_recovery','shot_resource_wrong_id','restart_motion_lie']
    for name in cases:
        bad=copy.deepcopy(data)
        remote=next(o for o in bad['observations'] if o['kind']=='remote')
        creek=next(o for o in bad['observations'] if o['kind']=='creek' and not o['forward'])
        es=creek['events'];rs=remote['events']
        pick=lambda events,kind:next(e for e in events if e['kind']==kind)
        if name=='remove_jump_receipts':
            for o in bad['observations']:o['events']=[e for e in o['events'] if e['kind']!='accepted_jump']
        elif name=='remove_landing_receipts':
            for o in bad['observations']:o['events']=[e for e in o['events'] if e['kind']!='accepted_landing']
        elif name=='remove_drop_inputs':
            for o in bad['observations']:o['events']=[e for e in o['events'] if not(e['kind']=='input_request' and e['action']=='drop_through')]
        elif name=='callback_at_tick_zero':
            e=pick(es,'grounded_island_callback');e['tick']=0;e['position']=[0,282]
        elif name=='remove_remote_health':remote['events']=[e for e in rs if e['kind']!='latch_health_commit']
        elif name=='jump_wrong_position':pick(es,'accepted_jump')['position'][0]+=24
        elif name=='jump_wrong_tick':pick(es,'accepted_jump')['tick']+=1
        elif name=='landing_wrong_position':pick(es,'accepted_landing')['position'][0]+=24
        elif name=='landing_wrong_tick':pick(es,'accepted_landing')['tick']+=1
        elif name=='duplicate_jump':es.append(copy.deepcopy(pick(es,'accepted_jump')))
        elif name=='duplicate_landing':es.append(copy.deepcopy(pick(es,'accepted_landing')))
        elif name=='duplicate_drop':es.append(copy.deepcopy(next(e for e in es if e['kind']=='input_request' and e['action']=='drop_through')))
        elif name=='drop_wrong_position':next(e for e in es if e['kind']=='input_request' and e['action']=='drop_through')['position'][0]+=24
        elif name=='drop_after_reboard':
            e=next(e for e in es if e['kind']=='input_request' and e['action']=='drop_through');e['tick']=[q for q in es if q['kind']=='accepted_landing'][3]['tick']+1;e['position']=creek['frames'][e['tick']-1]['position'].copy()
        elif name=='callback_wrong_position':pick(es,'grounded_island_callback')['position'][0]+=24
        elif name=='callback_at_start_bank':
            e=pick(es,'grounded_island_callback');e['tick']=pick(es,'accepted_landing')['tick']+1;e['position']=creek['frames'][e['tick']-1]['position'].copy()
        elif name=='callback_after_restart':
            e=pick(es,'grounded_island_callback');e['tick']=[q for q in es if q['kind']=='latch_committed'][-1]['tick']+1;e['position']=creek['frames'][e['tick']-1]['position'].copy()
        elif name=='duplicate_callback':es.append(copy.deepcopy(pick(es,'grounded_island_callback')))
        elif name=='health_wrong_id':pick(rs,'latch_health_commit')['event_id']='unrelated:projectile'
        elif name=='health_wrong_tick':pick(rs,'latch_health_commit')['tick']+=1
        elif name=='duplicate_health':rs.append(copy.deepcopy(pick(rs,'latch_health_commit')))
        elif name=='health_wrong_amount':pick(rs,'latch_health_commit')['amount']=0
        elif name=='impact_wrong_direction':pick(rs,'projectile_impact')['direction']=[1,0]
        elif name=='remove_impact':remote['events']=[e for e in rs if e['kind']!='projectile_impact']
        elif name=='missing_resource_recovery':
            o=next(o for o in bad['observations'] if o['low'])
            if paid_policy(o['frames'][0]):
                event=next(e for e in o['events'] if e['kind']=='energy_transaction' and e['amount']>0);o['events'].remove(event)
            else:
                # The manual, unfocused fixture never advances AirFocus. A claimed
                # recovery therefore has no native receipt; reject forged balance.
                o['frames'][10]['energy']+=1
        elif name=='shot_resource_wrong_id':
            if paid_policy(creek['frames'][0]):next(e for e in es if e['kind']=='energy_transaction' and e['operation']=='consume')['event_id']='shot/unrelated'
            else:
                shot=pick(es,'accepted_shot');es.append({'kind':'energy_transaction','tick':shot['tick'],'position':shot['position'].copy(),'event_id':'shot/unrelated','operation':'consume','amount':-creek['frames'][0]['shot_cost'],'current':shot['energy'],'status':0})
        elif name=='restart_motion_lie':
            t=[e for e in es if e['kind']=='latch_committed'][-1]['tick'];creek['frames'][t]['latches'][0]['motion_running']=False
        # Plausible timestamp sorting must not rescue a wrong causal stage.
        for o in bad['observations']:o['events'].sort(key=lambda e:e['tick'])
        yield name,bad


def main():
    base=REPO/'build/plains_redesign/experience';base.mkdir(parents=True,exist_ok=True);folder=Path(tempfile.mkdtemp(prefix='run_',dir=base))
    before=sources();receipt={'status':'failed','source_before':before,'runs':[]}
    try:
        for negative in [False,True]:
            name='deleted_island' if negative else 'positive';out=folder/(name+'.json')
            cmd=['bash','tools/godot.sh','--headless','--fixed-fps','60','--path','.','--script','tests/plains_experience_golden_runner.gd','--','--output='+str(out)]+(['--delete-island'] if negative else [])
            result=harness.run_check({'argv':cmd,'timeout_seconds':180,'success_pattern':r'^PLAINS EXPERIENCE NATIVE: [1-9]\d* assertions, 0 failures$'},folder/(name+'.log'),REPO)
            data=json.loads(out.read_text()) if out.is_file() else {};ok=result['exit_code']==(1 if negative else 0) and valid(data,negative) and not re.search(r'SCRIPT ERROR:|Parse Error:|SHADER ERROR:|ObjectDB.*leaked|resources? still in use at exit',(folder/(name+'.log')).read_text())
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
        for name,corrupt in causal_mutations(data):
            refused=not valid(corrupt);refusals.append({'case':name,'refused':refused})
            if not refused:raise RuntimeError('Accepted missing/misbound causal evidence '+name)
        for name in ['forged_policy','forged_focus_shared','forged_hp','forged_projectile_owner','forged_projectile_impact','forged_air_charge','coherent_forged_recovery']:
            bad=copy.deepcopy(data);o=bad['observations'][0]
            if name=='forged_policy':o['frames'][0]['shot_policy']['shooting_consumes_energy']=True
            elif name=='forged_focus_shared':o['frames'][10]['focus']['shared']=False
            elif name=='forged_hp':o['frames'][10]['health']-=1
            elif name=='forged_projectile_owner':next(e for e in o['events'] if e['kind']=='actual_projectile_spawned')['owner_id']+=1
            elif name=='forged_projectile_impact':next(e for e in o['events'] if e['kind']=='actual_projectile_impact')['shot_id']+=100
            elif name=='forged_air_charge':next(f for f in o['frames'][4:] if not f['grounded'])['shot_charges']=0
            else:
                o=next(o for o in bad['observations'] if o['kind']=='remote' and o['low'])
                t=2;amount=.1
                for frame in o['frames'][t:]:frame['energy']+=amount
                for event in o['events']:
                    if event['kind']=='accepted_shot' and event['tick']>=t:event['energy']+=amount
                o['events'].append({'kind':'energy_transaction','tick':t,'phrase':o['frames'][t-1]['phrase'],'position':o['frames'][t-1]['position'].copy(),'event_id':'','operation':'grant','amount':amount,'current':o['frames'][t]['energy'],'status':0})
                o['events'].sort(key=lambda e:e['tick'])
            refused=not valid(bad);refusals.append({'case':name,'refused':refused})
            if not refused:raise RuntimeError('Accepted false current-policy proof '+name)
        (folder/'validator_refusals.json').write_text(json.dumps(refusals,indent=2)+'\n')
        receipt['source_after']=sources();assert before==receipt['source_after'],'changed source during native proof'
        receipt['status']='passed';print('PLAINS EXPERIENCE GOLDEN: actual differentiated routes and encounter counterexamples validated')
    finally:
        (folder/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print('PLAINS EXPERIENCE RECEIPT: '+str(folder/'receipt.json'))
if __name__=='__main__':main()
