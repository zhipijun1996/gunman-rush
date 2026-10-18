from pathlib import Path
import json,hashlib,copy,sys,ast,importlib.util,re
R=Path.cwd();O=R/'build/independent/canopy-app/actual03/final-delta';O.mkdir(parents=True,exist_ok=True);S=R/'build/forest_depth/snapshots/canopy_app03';D=S/'build/forest_depth/campaign/canopy_app03';raw=D/'capture.json';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();sys.path.insert(0,str(S/'tools'))
def load(name,p):
 sp=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m);return m
frozen=load('native03_reader',S/'tools/run_forest_depth_campaign_boss.py');current_path=R/'tools/run_forest_depth_campaign_boss.py';current=load('offline_new_reader',current_path);current_hash=sha(current_path);frozen_hash=sha(S/'tools/run_forest_depth_campaign_boss.py');assert frozen_hash=='9ec517f500dee284902c3883fb271181962201075b59c64adbd3f737235f711a'
data=json.loads(raw.read_text());frozen.validate_canopy(data);current.validate_canopy(data)
snapshot=json.loads((S/'build/snapshot-receipt.json').read_text());assert snapshot['source_copy_guard']and len(snapshot['source_files'])==2068 and all(sha(S/p)==h for p,h in snapshot['source_files'].items())
r=json.loads((D/'receipt.json').read_text());assert r['passed']and r['source_guard']and r['source_before']==r['source_after']and r['verifier_before']==r['verifier_after'];assert all(sha(S/p)==h for p,h in r['source_before'].items())and all(sha(S/p)==h for p,h in r['verifier_before'].items());assert r['native_budget_seconds']==180 and r['import_budget_seconds']==90
host_path=R/'build/forest_depth/canopy-app-preparation/native03/receipt.json';host=json.loads(host_path.read_text());assert host['exit_code']==0 and host['source_guard'] and host['source_before']==host['source_after']==snapshot['source_files']
log=(D/'native.log').read_text();assert '4.7.2'in log and 'FOREST DEPTH CAMPAIGN: 46 assertions / 0 failures'in log and not re.search(r'(?m)^ERROR:|SCRIPT ERROR:|Parse Error:|ObjectDB.*leaked|resources? still in use at exit',log)
assert not data['failures']and len(data['checks'])==46 and all(x['passed']for x in data['checks']);assert len(data['schema_negatives'])==9 and all(x['valid_accepted']is False and x['restore_accepted']is False and x['atomic']is True and x['before']==x['after']and x['hp_before']==x['hp_after']for x in data['schema_negatives'])
reload=data['reload'];before=reload['before'];bound=reload['after_bound'];resumed=reload['after_resume'];saved=reload['saved'];assert saved['health']==15 and abs(saved['fields'][0]['weave']['age']-.516666666666667)<1e-9
assert [before[k]for k in ['player_hp','energy','capacity']]==[4,80,5]==[bound[k]for k in ['player_hp','energy','capacity']]==[resumed[k]for k in ['player_hp','energy','capacity']];assert before['player']!=bound['player']
frames=data['combat']['frames'];events=data['combat']['events'];hits=[e for e in events if e.get('event')=='policy_result'and e.get('target')=='boss'];player_hits=[e for e in events if e.get('event')=='policy_result'and e.get('target')=='player'];assert len(frames)==704 and len(hits)==24 and not player_hits and data['combat']['initial']['player_hp']==4 and data['combat']['final']['player_hp']==4
newhit=next(e for e in hits if e['segment']=='after_reload');newindex=events.index(newhit);used={e['event_id']for e in hits};oldshot=next(e for e in events if e.get('event')=='accepted_shot'and e['segment']=='before_reload'and f"{e['motor_id']}:{e['session']}:{e['serial']}"not in used)
def old_owner(z):
 e=z['combat']['events'][newindex];e['event_id']=f"{oldshot['motor_id']}:{oldshot['session']}:{oldshot['serial']}";e['source']='player_projectile:'+str(oldshot['motor_id'])
# Preserve the actual original whole-reader acceptance of this malformed ownership.
z=copy.deepcopy(data);old_owner(z);frozen.validate_canopy(z)
shot=next(e for e in events if e.get('event')=='accepted_shot');inputs=[e for e in events if e.get('event')=='actual_queued_input'and e.get('action')=='shoot_release'and e['tick']==shot['tick']and e['session']==shot['session']and e['segment']==shot['segment']];assert len(inputs)==1;ii=events.index(inputs[0]);fi=next(i for i,f in enumerate(frames)if f['segment']=='after_reload')+2
cases=[('cross_reload_old_source_and_serial',old_owner),('Router_other_motor',lambda z:z['combat']['events'][ii].update(motor_id=999)),('Router_wrong_engine_frame',lambda z:z['combat']['events'][ii].update(physics_frame=0)),('resume_inactive',lambda z:z['reload']['after_resume'].update(active=False,app_boss_started=False)),('resume_energy_changed',lambda z:z['reload']['after_resume'].update(energy=100)),('resume_old_owner',lambda z:z['reload']['after_resume'].update(session=before['session'],player_instance=before['player_instance'])),('Policy_wrong_actor_epoch',lambda z:z['combat']['events'][newindex].update(actor_epoch=999)),('Policy_wrong_health_epoch',lambda z:z['combat']['events'][newindex].update(health_epoch=999)),('wrong_frame_stage_epoch',lambda z:z['combat']['frames'][fi].update(stage_epoch=999)),('delete_middle_motor_frame',lambda z:z['combat']['frames'].pop(fi))]
mut=[]
for n,fn in cases:
 z=copy.deepcopy(data);fn(z);err=None
 try:current.validate_canopy(z)
 except Exception as e:err=str(e)
 assert err,n;mut.append({'case':n,'rejected':True,'error':err})
# Actual03 is undamaged during combat; exercise real hurt commits only through actual02's ledger sub-reader.
oldraw=R/'build/forest_depth/snapshots/canopy_app02/build/forest_depth/campaign/canopy_app02/capture.json';d2=json.loads(oldraw.read_text());current.validate_canopy_policy_ledger(d2);ph=[(i,e)for i,e in enumerate(d2['combat']['events'])if e.get('event')=='policy_result'and e.get('target')=='player'];assert ph
pidx,hit=ph[0];sub=[]
for field,value in [('hp',hit['hp']+.5),('lethal',not hit['lethal'])]:
 z=copy.deepcopy(d2);z['combat']['events'][pidx][field]=value;err=None
 try:current.validate_canopy_policy_ledger(z)
 except Exception as e:err=str(e)
 assert err;sub.append({'field':field,'ledger_only_rejected':True,'error':err})
try:current.validate_canopy(d2);raise AssertionError('actual02 must remain wholeFAIL')
except (ValueError,AssertionError) as e:
 assert str(e)!='actual02 must remain wholeFAIL'
# Existing frozen legacy helpers/readers retain exact ASTs.
funcs=lambda p:{n.name:ast.dump(n,include_attributes=False)for n in ast.parse(p.read_text()).body if isinstance(n,ast.FunctionDef)};a,b=funcs(S/'tools/run_forest_depth_campaign_boss.py'),funcs(current_path);old_helpers=['require','finite','vector','close','same_aim','validate_inputs_and_health','validate_pointer_and_map2','validate','validate_queen'];assert all(a[n]==b[n]for n in old_helpers)
assert data['before_gold']=={'capacity':5.,'count':0,'hp':4.,'wallet':0}and data['after_gold']=={'capacity':7.,'count':1,'hp':4.,'wallet':0};assert len(data['pointer_events'])==12 and data['teardown']['observed_actors_alive']==[]
assert sha(current_path)==current_hash
(O/'frozen03-reader.py.txt').write_bytes((S/'tools/run_forest_depth_campaign_boss.py').read_bytes());(O/'offline-reader.py.txt').write_bytes(current_path.read_bytes())
res={'status':'CONTINUE_BOUNDED_ACTUAL_APP03_AND_OFFLINE_OWNERSHIP_READER_DELTA','native_run_by_reviewer':False,'original_raw_sha256':sha(raw),'native03_reader_sha256':frozen_hash,'offline_reader_sha256':current_hash,'native03_original_wrapper_exit0':True,'native03_checks':46,'native03_source_inventory_verified':2068,'runtime_beforeafter_verified':len(r['source_before']),'verifier_beforeafter_verified':len(r['verifier_before']),'source_overlay':'Native03 snapshot atdd214+dirty; offline reader different SHA, not backdated','observed':{'combat_frames':704,'boss_hp':{'initial':24,'save':15,'final':0},'combat_player_HP':[4,4],'saved_live_field_age':saved['fields'][0]['weave']['age'],'saved_Player_HP_energy_capacity':[4,80,5],'before_player_position':before['player'],'bound_checkpoint_position':bound['player'],'session':[before['session'],bound['session']],'actor_epoch':[before['actor_epoch'],bound['actor_epoch']],'stage_epoch':[before['stage_epoch'],bound['stage_epoch']],'schema_negatives':9,'pointer_events':12,'gold_before':data['before_gold'],'gold_after':data['after_gold']},'original03_reader_crossreload_mutant_acceptance_preserved':True,'current_key_mutants':mut,'actual02_hurt_ledger_subtests':{'raw_sha256':sha(oldraw),'actual_Player_commits':len(ph),'ledger_only_baseline_accepted':True,'whole02_not_accepted':True,'mutations':sub},'old_readers_AST_unchanged':old_helpers,'limits':['No whole Boss fun/mechanism approval','No new native with offline reader','03 combat Player hurt absent;02 sub-reader proof explicitly partial','Checkpoint S rebuild is not preserving Player airborne position','Map2 debug entry plus natural route, not full natural plains/map1 campaign','Full194/CI/browser/OS/device/audio/human approval unverified']}
(O/'review.json').write_text(json.dumps(res,indent=2)+'\n');print(json.dumps({'status':res['status'],'current_key_mutants':len(mut),'actual02_Player_ledger_mutants':len(sub),'offline_reader':current_hash},indent=2))
