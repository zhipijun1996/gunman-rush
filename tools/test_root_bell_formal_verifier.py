"""Actual complete Python entry refusals; mocked process transport is NEVER native."""
import argparse
import contextlib
import copy
import io
import json
import math
from pathlib import Path
import sys
import types
import zipfile
import hashlib
from unittest.mock import patch
import run_root_bell_formal as rf

ROOT=Path(__file__).resolve().parents[1]
NATIVE_ARCHIVE=ROOT/'docs/evidence/region_production_v3/enemy_encounter_v2/movie02_native_and_frozen_sources.zip'
HISTORICAL_TUNING=ROOT/'tests/fixtures/root_bell/pre_focus_15_player_tuning.json'
HISTORICAL_TUNING_SHA='e5161bb8ef1855b9eda515ab0613a4a738b47abc43b0f2dc118d2e45f71b2058'
# Reader-only exact 9-file closure: original baseline + pinned delta, no runtime.
HISTORICAL_AUTHORITY=ROOT/'tests/fixtures/root_bell/historical_authority_v2.zip'
HISTORICAL_AUTHORITY_SHA='583530183764fd0c9dc6d2f124d30110bbf6ca8501737775059499e15a1cbfea'

def require_historical_tuning(raw, source_inventory, capture):
    expected=source_inventory['config/player_tuning.json']
    rf.require(expected==HISTORICAL_TUNING_SHA and hashlib.sha256(raw).hexdigest()==expected,
               'Historical tuning bytes differ from pinned original source inventory')
    for capability in ('initial_capability','final_capability'):
        rf.require(capture[capability]['config_hashes']['player_tuning']==expected,
                   'Historical capture config identity differs from original inventory')

def prepare_historical_authority(out, archive, capture):
    """Reader-only historical inputs, never current runtime or rewritten capture."""
    delta_bytes=archive.read('modified_source_bytes.zip')
    rf.require(hashlib.sha256(delta_bytes).hexdigest()==rf.FROZEN_NATIVE_02_PINS['old_delta_zip_sha256'],
               'Original source delta ZIP changed')
    with zipfile.ZipFile(io.BytesIO(delta_bytes)) as delta:
        manifest=json.loads(delta.read('source_manifest.json'))
        inventory=manifest['full_source_sha256']
        for name, expected in manifest['changed_source_sha256'].items():
            rf.require(hashlib.sha256(delta.read(name)).hexdigest()==expected==inventory[name],
                       'Original changed source bytes mismatch '+name)
        raw=HISTORICAL_TUNING.read_bytes()
        require_historical_tuning(raw,inventory,capture)
        required={'config/player_tuning.json','resources/enemies/plains_root_bell.tres',
                  'resources/enemies/patrol_health.tres','resources/actors/prototype_health.tres',
                  'resources/weapons/pulse_gun.tres','resources/player/plains_shot_energy.tres',
                  'scripts/resources/definitions/shot_energy_definition.gd','scenes/player/player.tscn'}
        target_edge=capture['manifest']['root_bell_admission']['physical_facts']['edge']
        edge=next(e for e in capture['manifest']['connections'] if e['id']==target_edge)
        for index in edge['modules']:
            required.add('resources/generation/modules/'+capture['manifest']['nodes'][index]['module_id']+'.tres')
        directory=out/'historical_authority'
        directory.mkdir()
        frozen_bytes=HISTORICAL_AUTHORITY.read_bytes()
        rf.require(hashlib.sha256(frozen_bytes).hexdigest()==HISTORICAL_AUTHORITY_SHA,
                   'Historical authority fixture ZIP changed')
        with zipfile.ZipFile(io.BytesIO(frozen_bytes)) as frozen:
            rf.require(set(frozen.namelist())==required and len(frozen.namelist())==len(required),
                       'Historical authority fixture closure differs from required original inputs')
            frozen_sources={name:frozen.read(name) for name in required}
        copied={}
        for name in sorted(required):
            data=frozen_sources[name]
            origin=('exact historical tuning fixture' if name=='config/player_tuning.json' else
                    'pinned original source delta ZIP' if name in manifest['changed_source_sha256'] else
                    'exact Git baseline '+manifest['baseline_commit'])
            actual=hashlib.sha256(data).hexdigest()
            rf.require(actual==inventory[name],'Historical authority source mismatch '+name)
            path=directory/name
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(data)
            copied[name]={'sha256':actual,'origin':origin}
    return directory,{'scope':'Historical Python reader authority only; NO current runtime/native proof',
                      'directory':str(directory.relative_to(ROOT)),
                      'original_delta_zip_sha256':hashlib.sha256(delta_bytes).hexdigest(),
                      'historical_authority_fixture_sha256':HISTORICAL_AUTHORITY_SHA,
                      'original_source_inventory_sha256':hashlib.sha256(json.dumps(inventory,sort_keys=True).encode()).hexdigest(),
                      'files':copied},inventory

@contextlib.contextmanager
def historical_semantics(directory):
    # Keep main output paths, current source checks and transport on the real ROOT.
    # Only the existing unmodified semantic predicate reads historical resources.
    original=rf.strict_semantics
    def validate_historical(*args,**kwargs):
        with patch.object(rf,'ROOT',directory):
            return original(*args,**kwargs)
    with patch.object(rf,'strict_semantics',side_effect=validate_historical):
        yield

def variants(base):
    samples={}
    x=copy.deepcopy(base);case=x['root_bell_cases'][-1];start=case['start_tick']-1;first=x['frames'][start]
    for i,f in enumerate(x['frames'][start:],start):
        f['position']=copy.deepcopy(first['position']);f['velocity']=[0,0];f['axis']=0;f['input_requests']=[];f['accepted_events']=[];f['grounded']=True;f['collisions']=copy.deepcopy(first['collisions']);f['shot_energy']=100.;f['shot_cooldown']=0.;f['shots']=2;f['used_jumps']=0;f['displacement']=math.dist(x['frames'][i-1]['position'],f['position'])
    case['position']=copy.deepcopy(first['position']);x['final_capability']['position']=copy.deepcopy(first['position']);x['final_capability']['shot_energy']['current']=100.
    for e in x['events']:
        if e['kind']=='root_case_end' and e.get('id')==case['id']:e['position']=copy.deepcopy(first['position'])
    x['events']=[e for e in x['events'] if e['tick']<case['start_tick'] or e['kind'] in ['root_case_begin','root_case_end']];x['resource_receipts']=[r for r in x['resource_receipts'] if r['tick']<case['start_tick']]
    samples['all_return_motion_erased']=x
    x=copy.deepcopy(base);case=x['root_bell_cases'][-1];start=case['start_tick']-1;first=x['frames'][start]
    for f in x['frames'][start:]:
        f['position']=copy.deepcopy(first['position']);f['velocity']=[0,0];f['displacement']=0;f['axis']=0;f['input_requests']=[];f['accepted_events']=[];f['grounded']=True;f['collisions']=copy.deepcopy(first['collisions'])
    case['position']=copy.deepcopy(first['position'])
    for e in x['events']:
        if e['kind']=='root_case_end' and e.get('id')==case['id']:e['position']=copy.deepcopy(first['position'])
    x['events']=[e for e in x['events'] if e['tick']<case['start_tick'] or e['kind'] in ['root_case_begin','root_case_end']];x['resource_receipts']=[r for r in x['resource_receipts'] if r['tick']<case['start_tick']]
    samples['independent_original_return_motion_erased']=x
    x=copy.deepcopy(base);x['resource_receipts']=[{'tick':c['start_tick']+1,'operation':'consume','amount_applied':-.01,'event_id':'foreign-not-the-real-shot','epoch':999,'current':10000000,'capacity':1} for c in x['root_bell_cases'] if c['id'].startswith('real_projectile')];samples['all_real_resource_receipts_replaced_by_unbound_fake']=x
    x=copy.deepcopy(base)
    for f in x['frames']:f['shot_energy']=10000000
    samples['frame_budget_above_actual_capacity']=x
    x=copy.deepcopy(base);case=x['root_bell_cases'][-1]
    for f in x['frames'][case['start_tick']-1:]:f['health']=0
    case['health']=0
    for e in x['events']:
        if e['kind']=='root_case_end' and e.get('id')==case['id']:e['health']=0
    samples['player_dead_during_complete_return']=x
    x=copy.deepcopy(base);identity=x['root_bell_identity'];ghost='ghost-absent-from-actual-manifest';x['root_bell_identity']=ghost;x['manifest']['root_bell_admission']['id']=ghost
    for f in x['frames']:f['root_bell']['id']=ghost
    for e in x['events']:
        for key in ['enemy','target']:
            if e.get(key)==identity:e[key]=ghost
    for c in x['root_bell_cases']:
        if 'actual_admission' in c:c['actual_admission']['id']=ghost
    samples['coherent_ghost_root_identity_not_in_manifest']=x
    x=copy.deepcopy(base);next(r for r in x['resource_receipts'] if r['event_id']=='shot/3/20')['event_id']='shot/3/999';samples['legal_epoch_capacity_foreign_shot_identity']=x
    x=copy.deepcopy(base);r=next(r for r in x['resource_receipts'] if r['event_id']=='shot/3/20');r['amount_applied']=-.01;r['requested_amount']=.01;r['current']=99.99;samples['legal_identity_wrong_actual_debit']=x
    x=copy.deepcopy(base);removed=next(r for r in x['resource_receipts'] if r['event_id']=='hit/3/25');tick=removed['tick'];x['resource_receipts'].remove(removed)
    x['events']=[e for e in x['events'] if not(e['kind']=='energy_recovered' and e['tick']==tick)]
    for frame in x['frames']:frame['accepted_events']=[e for e in frame['accepted_events'] if not(e['kind']=='energy_recovered' and e['tick']==tick)]
    resource='resources/player/plains_shot_energy.tres';script='scripts/resources/definitions/shot_energy_definition.gd';capacity=rf._number(resource,'capacity');rate=rf._number(resource,'ground_recovery',script);delay=rf._number(resource,'recovery_delay',script);current=rf._number(resource,'initial_current');remaining=x['initial_capability']['shot_energy']['_delay'];grounded=x['initial_capability']['grounded'];dt=1/x['physics_hz'];by_tick={}
    for r in x['resource_receipts']:by_tick.setdefault(r['tick'],[]).append(r)
    for frame in x['frames']:
        gain=max(0,dt-remaining);remaining=max(0,remaining-dt)
        if grounded:current=min(capacity,current+rate*gain)
        for r in by_tick.get(frame['tick'],[]):
            before=current
            if r['operation']=='consume':current-=r['requested_amount'];remaining=delay
            else:current=min(capacity,current+r['requested_amount'])
            r['amount_applied']=current-before;r['current']=current
        frame['shot_energy']=current;grounded=frame['grounded']
    x['final_capability']['shot_energy']['current']=current;samples['missing_real_hit_grant_coherent_replay']=x
    return samples

def main():
    p=argparse.ArgumentParser();p.add_argument('--output-dir',required=True);args=p.parse_args();out=(ROOT/args.output_dir).resolve();rf.require(out.is_relative_to(ROOT/'build/root_bell') and not out.exists(),'New test output directory required');out.mkdir(parents=True)
    with zipfile.ZipFile(NATIVE_ARCHIVE) as archive:
        raw_native=archive.read('capture.json')
        rf.require(hashlib.sha256(raw_native).hexdigest()==rf.FROZEN_NATIVE_02_PINS['old_capture_sha256'],'Original portable native SHA changed')
        base=json.loads(raw_native)
        authority,authority_record,original_inventory=prepare_historical_authority(out,archive,base)
    rf.require(hashlib.sha256(raw_native).hexdigest()==rf.FROZEN_NATIVE_02_PINS['old_capture_sha256'],'Original portable native SHA changed')
    current_root=rf.ROOT
    try:rf.validate(base)
    except ValueError as error:
        rf.require(str(error)=='Not weakest formal capability','Current authority rejected for an unexpected reason: '+str(error))
        current_refusal={'refused':True,'reason':str(error)}
    else:raise ValueError('Current authority accepted historical focus/config identity')
    # Explicitly synthetic rejection probe only: align both the effective cap
    # and its tuning field to the current one-shot policy, so the independent
    # historical .2 focus versus current .15 mismatch remains reachable.
    current_tuning=json.loads((ROOT/'config/player_tuning.json').read_bytes())
    rf.require(current_tuning['max_air_shots']==1 and all(base[c]['air_shot_flight_cap']==2 and base[c]['tuning']['max_air_shots']==2 for c in ('initial_capability','final_capability')),
               'Current/historical one-shot capability contrast changed')
    focus_probe=copy.deepcopy(base)
    focus_fields=[]
    for capability in ('initial_capability','final_capability'):
        focus_probe[capability]['air_shot_flight_cap']=current_tuning['max_air_shots']
        focus_probe[capability]['tuning']['max_air_shots']=current_tuning['max_air_shots']
        focus_fields.extend([capability+'.air_shot_flight_cap',capability+'.tuning.max_air_shots'])
    try:rf.validate(focus_probe)
    except ValueError as error:
        rf.require(str(error)=='Actual tuning mismatch focus_time_scale','Independent old-focus rejection changed: '+str(error))
        current_refusal['independent_focus_probe']={'scope':'Explicit synthetic deep-copy rejection only, NOT native','modified_fields':focus_fields,'refused':True,'reason':str(error)}
    else:raise ValueError('Current authority accepted synthetic old-focus mismatch')
    altered_tuning=json.loads(HISTORICAL_TUNING.read_bytes());altered_tuning['focus_time_scale']=.15
    try:require_historical_tuning(json.dumps(altered_tuning).encode(),original_inventory,base)
    except ValueError as error:tuning_refusal={'refused':True,'reason':str(error)}
    else:raise ValueError('Edited historical tuning fixture accepted')
    with historical_semantics(authority):
        return run_historical_cases(out,base,raw_native,authority_record,current_root,current_refusal,tuning_refusal)

def run_historical_cases(out,base,raw_native,authority_record,current_root,current_refusal,tuning_refusal):
    positive=rf.validate(base);old27=rf.tamper(base);rf.require(len(old27)==27,'Original27 assertions changed');results={};original_run=rf.subprocess.run
    for name,candidate in variants(base).items():
        folder=out/name
        def fake_run(command,*args,**kwargs):
            if command[:2]==['bash','tools/godot.sh']:
                dest=ROOT/next(a for a in command if a.startswith('--output=res://')).removeprefix('--output=res://');dest.write_text(json.dumps(candidate)+'\n');kwargs['stdout'].write('UNIT TEST SYNTHETIC PROCESS TRANSPORT; NO NATIVE\nLEVEL FORMAL CAPTURE: 5145 frames, 6 edges, outcome=route_target_reached, capture_errors=0\n');kwargs['stdout'].flush();return types.SimpleNamespace(returncode=0)
            return original_run(command,*args,**kwargs)
        try:
            with patch.object(sys,'argv',['run_root_bell_formal.py','--output-dir',str(folder.relative_to(ROOT))]),patch.object(rf.subprocess,'run',side_effect=fake_run),contextlib.redirect_stdout(io.StringIO()):rf.main()
        except (ValueError,KeyError,IndexError,TypeError) as e:results[name]={'refused':True,'reason':str(e)}
        else:raise ValueError('Coherent full consumer bad case accepted '+name)
        report=folder/'report.json';data=json.loads(report.read_text());rf.require(data['status']=='failed','Bad test got successful receipt');data['scope']='UNIT TEST: explicitly synthetic process transport and historical mutated data; NOT NATIVE';report.write_text(json.dumps(data,indent=2)+'\n')
    rf.require(rf.ROOT==current_root==ROOT,'Historical semantic scope leaked into main ROOT')
    result={'status':'passed','scope':'Actual Python main negatives with explicitly synthetic transport, NO NATIVE/MOVIE execution','historical_authority':authority_record,'authority_refusals':{'current_authority_rejects_historical_capture':current_refusal,'edited_historical_tuning':tuning_refusal},'baseline_original_native_observed':positive,'original27_refusals':old27,'coherent_fullmain_refusals':results,'original_capture_sha256':hashlib.sha256(raw_native).hexdigest(),'current_verifier_sha256':rf.sha(ROOT/'tools/run_root_bell_formal.py'),'current_test_sha256':rf.sha(Path(__file__))}
    (out/'report.json').write_text(json.dumps(result,indent=2)+'\n');print('STRICT FORMAL PYTHON: original27 + coherent full-main',len(results),'refusals; no native')
if __name__=='__main__':main()
