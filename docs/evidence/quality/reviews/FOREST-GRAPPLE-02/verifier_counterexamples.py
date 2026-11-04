"""Read-only verifier probes; synthetic cases explicitly do not prove gameplay."""
import ast, copy, hashlib, importlib.util, json, pathlib, subprocess, sys
ROOT=pathlib.Path(__file__).resolve().parents[4]
sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'tests')]
import test_forest_vertical_shortcut as shortcut
import run_forest_depth_region as region
import run_forest_air_chain as air
base='6c61faadd511c48a267b975550da897e701fd09f'
results={}
original=subprocess.check_output(['git','show',base+':tools/run_forest_air_chain.py'],cwd=ROOT,text=True)
def literal_assignment(src,name):
    for node in ast.parse(src).body:
        if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id==name for t in node.targets):return ast.literal_eval(node.value)
old=literal_assignment(original,'SUITE_CASES')
results['original_nine_air_cases_preserved']=list(air.SUITE_CASES[:len(old)])==list(old) and len(old)==9
oldprofiles=json.loads(subprocess.check_output(['git','show',base+':tools/harness/profiles.json'],cwd=ROOT,text=True))
newprofiles=json.loads((ROOT/'tools/harness/profiles.json').read_text())
results['all_original_profile_checks_preserved']=all(all(x in newprofiles['profiles'][name] for x in checks) for name,checks in oldprofiles['profiles'].items())
results['original_check_configs_unchanged']=all(newprofiles['checks'][k]==v for k,v in oldprofiles['checks'].items())
oldregion=subprocess.check_output(['git','show',base+':tools/run_forest_depth_region.py'],cwd=ROOT,text=True)
results['causal_receipt_reader_byteidentical']=ast.get_source_segment(oldregion,next(n for n in ast.parse(oldregion).body if isinstance(n,ast.FunctionDef) and n.name=='actual_projectile_energy_credits'))==ast.get_source_segment((ROOT/'tools/run_forest_depth_region.py').read_text(),next(n for n in ast.parse((ROOT/'tools/run_forest_depth_region.py').read_text()).body if isinstance(n,ast.FunctionDef) and n.name=='actual_projectile_energy_credits'))
d=shortcut.reader_fixture()
for f in d['frames'][5:11]:f['shots']=1
d['frames'][10]['grounded']=False;d['frames'][11]['grounded']=False
d['events'].append({'tick':11,'kind':'actual_shot_energy_credit','fired_airborne':True})
results['forged_shortcut_credit_errors']=shortcut.reader.validate(d)
results['forged_shortcut_credit_rejected']=bool(results['forged_shortcut_credit_errors'])
# Same isolated credit is rejected by preserved full projectile-causal reader.
credits,errors=region.actual_projectile_energy_credits({'frames':d['frames']},d['frames'][10],d['frames'][9],d['events'],1/60,20)
results['full_reader_rejects_same_forgery']=not credits and bool(errors)
results['full_reader_forgery_errors']=errors
# Independently construct a complete causal reader positive and remove each link.
ledger={'owner_id':1,'session_id':2,'weapon_epoch':0,'hits':{},'combat_packets':{}}
prev={'tick':1,'shot_economy':copy.deepcopy(ledger),'enemies':[{'id':'test_enemy','health':3}]}
frame={'tick':2,'shot_economy':copy.deepcopy(ledger),'enemies':[{'id':'test_enemy','health':2}]}
frame['shot_economy']['hits']={'2/3':True};frame['shot_economy']['combat_packets']={'2/3':20}
events=[{'kind':'shot_fired','tick':1,'serial':5,'aim':[0,1]},
{'kind':'actual_projectile_spawned','tick':1,'serial':5,'packet':3,'owner_id':1,'session_id':2,'weapon_epoch':0,'direction':[0,1],'lifetime':1,'fired_airborne':True},
{'kind':'committed_damage','tick':2,'event_id':'1:2:5','source':'player_projectile:1','target':'test_enemy','damage_kind':0,'amount':1,'health_after':2,'lethal':False},
{'kind':'actual_shot_energy_credit','tick':2,'hits':{'2/3':True},'owner_id':1,'session_id':2,'amount':20,'fired_airborne':True}]
positive={'frames':[prev,frame]}
valid_rows,valid_errors=region.actual_projectile_energy_credits(positive,frame,prev,events,1/60,20)
results['synthetic_full_causal_positive']=len(valid_rows)==1 and not valid_errors
results['synthetic_causal_negatives']=[]
for kind in ['missing_spawn','missing_damage','missing_credit','missing_shot','wrong_HP','wrong_epoch','wrong_packet','fake_airborne']:
 es=copy.deepcopy(events);fr=copy.deepcopy(frame)
 if kind.startswith('missing_'):
  event_kind={'missing_spawn':'actual_projectile_spawned','missing_damage':'committed_damage','missing_credit':'actual_shot_energy_credit','missing_shot':'shot_fired'}[kind]
  es=[e for e in es if e['kind']!=event_kind]
 elif kind=='wrong_HP':fr['enemies'][0]['health']=2.5
 elif kind=='wrong_epoch':fr['shot_economy']['weapon_epoch']=1
 elif kind=='wrong_packet':fr['shot_economy']['combat_packets']['2/3']=999
 else:es[-1]['fired_airborne']=False
 rows,errs=region.actual_projectile_energy_credits(positive,fr,prev,es,1/60,20)
 results['synthetic_causal_negatives'].append({'kind':kind,'rejected':bool(errs)})
paths=subprocess.check_output(['git','diff','--name-only',base,'--','tests','tools'],cwd=ROOT,text=True).splitlines()
paths += subprocess.check_output(['git','ls-files','--others','--exclude-standard','--','tests','tools'],cwd=ROOT,text=True).splitlines()
paths += ['tools/run_forest_vertical_shortcut.py','tools/run_grapple_feel_tests.py','tools/run_aim_save_compat_tests.py','tests/test_grapple_feel_wrapper.py','tests/test_forest_vertical_shortcut.py']
results['reviewed_sha256']={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sorted(set(paths))}
print(json.dumps(results,indent=2))
