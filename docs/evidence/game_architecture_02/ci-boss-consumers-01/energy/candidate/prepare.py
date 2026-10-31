from pathlib import Path
import hashlib,json,subprocess,difflib,re
root=Path('/workspace/gunman-rush-refactor');out=Path(__file__).parent
source='2cf83fa07e0b7aab0e36d44c25c2aaaf38a32d62'
health_origin='resources/bosses/bellstrider_health.tres'
health_path='tests/fixtures/demo_ui_01_r3/bellstrider_health_d079.tres'
test_path='tests/plains_experience_energy_runner.gd'
raw=subprocess.check_output(['git','show',source+':'+health_origin],cwd=root)
blob=subprocess.check_output(['git','rev-parse',source+':'+health_origin],cwd=root,text=True).strip()
health_sha=hashlib.sha256(raw).hexdigest()
health=out/'candidate'/health_path;health.parent.mkdir(parents=True,exist_ok=True);health.write_bytes(raw)
old=(root/test_path).read_text();before=out/'before'/test_path;before.parent.mkdir(parents=True,exist_ok=True);before.write_text(old)
changes=[('var armour_boss:=load("res://scenes/bosses/bellstrider.tscn").instantiate() as BossMotor','var armour_boss:=load("res://scenes/bosses/windkeeper.tscn").instantiate() as BossMotor'),('# Explicit historical armoured target; current continuous Bosses are shootable during attacks.','# Explicit D079 aperture target on the existing generic encounter. Freeze\n\t# historical Health too: the live Bellstrider Health resource is now 40 HP.'),('(armour_boss.get_node("Encounter") as BossEncounter).definition=preload("res://resources/bosses/legacy/bellstrider_window_v1.tres")','var historical_armour:=preload("res://resources/bosses/legacy/bellstrider_window_v1.tres").duplicate(true) as WindkeeperDefinition\n\thistorical_armour.health_definition=preload("res://'+health_path+'")\n\t(armour_boss.get_node("Encounter") as BossEncounter).definition=historical_armour'),('var encounter:=armour_boss.get_node("Encounter") as BellstriderEncounter','var encounter:=armour_boss.get_node("Encounter") as WindkeeperEncounter')]
new=old
for a,b in changes:
 assert new.count(a)==1,a
 new=new.replace(a,b)
restored=new
for a,b in reversed(changes):restored=restored.replace(b,a)
assert restored==old
candidate=out/'candidate'/test_path;candidate.parent.mkdir(parents=True,exist_ok=True);candidate.write_text(new)
provenance={'schema_version':1,'scope':'Exact D079 test-only HealthDefinition dependency; does not replace the current 40 HP production Bellstrider resource. No historical encounter implementation is copied.','source_commit':source,'original_path':health_origin,'source_git_blob':blob,'preserved_path':health_path,'sha256':health_sha,'transformations':[],'reason':'The existing legacy Bell window Definition still follows the shared live health path, which now supplies 40 HP. The historical energy/no-refund fixture asserts 16 HP and must pin its actual dependency.','existing_history_authority':'tests/fixtures/demo_ui_01_r3/history.json','runtime_registration':'none; loaded only by the explicit historical energy fixture'}
prov_path='tests/fixtures/demo_ui_01_r3/bellstrider_health_d079.provenance.json'
p=out/'candidate'/prov_path;p.write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n')
patch=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='a/'+test_path,tofile='b/'+test_path))
for path in [health_path,prov_path]:
 patch+=''.join(difflib.unified_diff([], (out/'candidate'/path).read_text().splitlines(True),fromfile='/dev/null',tofile='b/'+path))
(out/'candidate.patch').write_text(patch)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
files=[{'path':test_path,'before_sha256':sha(before),'candidate_sha256':sha(candidate)}]+[{'path':path,'before_sha256':None,'candidate_sha256':sha(out/'candidate'/path)} for path in [health_path,prov_path]]
proof={'scope_revision':'Additional sixth test fixture migration beyond the previous five current-consumer files. Historical D079 contract retained; not a migration to current 40 HP Bellstrider. Adds only test-only health data and provenance.','head_at_read':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'files':files,'preservation':{'entire_original_test_restored_by_reversing_only_four_fixture_edits':True,'all_assertions_unchanged':True,'all_loops_and_frame_budgets_unchanged':True,'expected_original_assertion_count':540,'old_required_values':'health==16; stamina==80; real armour_hit>0; no received resource grants','current_production_health_not_written':True,'frozen_health_exact_git_blob':True},'shared_runtime_path':['Existing Windkeeper scene instantiation','Instance-only duplicate of the existing legacy Bell WindkeeperDefinition','Exact historical 16 HP HealthDefinition assigned before add_child/_ready','Same BossMotor configured with legacy collision_size 104x92','Same WindkeeperDamageable receives actual swept projectile; observe closed body emits armour_hit and returns false','Original policy/energy consumer sees no accepted damage and no refund'], 'runtime_status':'unverified; no Godot invoked by author','baseline_evidence':'/workspace/refactor-evidence/legacy-boss-fixture-baseline-01/report.json','required_test':'Existing tests/plains_experience_energy_runner.gd through original run_plains_region_tests.py 90-second case/strict native guard; all 540 assertions retained','not_covered':['No replacement claim for the removed historical Bell lob/ring/roll/Presentation algorithms in plains_pressure_boss_runner.','No default CI deletion or waiver prepared here.','No current Boss HP, definition, damage, refund, scene, implementation or resource mutation.']}
(out/'candidate.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n');print(json.dumps(files,indent=2))
