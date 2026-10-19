from pathlib import Path
import re,json,hashlib
R=Path('/workspace/gunman-rush-design');S=R/'build/forest_depth/snapshots/level_capability01';O=S/'build/capability_boundary'; original=(S/'tests/level_capability_runner.gd').read_text()
body=original.replace('extends SceneTree','extends Node',1).replace('const SNAPSHOT := preload("res://tools/level_capability_snapshot.gd")','var SNAPSHOT: Script = load("res://tools/level_capability_snapshot.gd")').replace('func _initialize() -> void: run.call_deferred()\n','')
body=body.replace('preload("res://scenes/player/player.tscn")','load("res://scenes/player/player.tscn")').replace(' as PlayerMotor','').replace(' as PlayerController','').replace('BuildState.new()','load("res://scripts/builds/build_state.gd").new()').replace('PlayerTuning.load_default()','load("res://scripts/player/player_tuning.gd").load_default()').replace('preload("res://tests/level_design_trace.gd")','load("res://tests/level_design_trace.gd")').replace('WeaponCatalog.IDS','load("res://scripts/combat/weapon_catalog.gd").IDS').replace('WeaponCatalog.get_loadout','load("res://scripts/combat/weapon_catalog.gd").get_loadout').replace('root.add_child(motor)','get_tree().root.add_child(motor)').replace('driver.tree = self','driver.tree = get_tree()').replace('await process_frame','await get_tree().process_frame').replace('\tquit(1 if failures else 0)','')
body=re.sub(r'(var \w+) :=',r'\1 =',body)
(O/'case.gd').write_text(body)
entry='''extends SceneTree
func _initialize() -> void: execute.call_deferred()
func execute() -> void:
 var type: Script=load("res://build/capability_boundary/case.gd")
 var case: Node=type.new()
 root.add_child(case)
 await case.run()
 var failed: bool=case.failures!=0 or case.assertions!=41
 case.free()
 case=null
 type=null
 quit(1 if failed else 0)
'''
(O/'entry.gd').write_text(entry)
for label,target in [('original','res://tests/level_capability_runner.gd'),('candidate','res://build/capability_boundary/case.gd')]:
 (O/(label+'_load.gd')).write_text('extends SceneTree\nfunc _initialize() -> void: execute.call_deferred()\nfunc execute() -> void:\n var script: Script=load("'+target+'")\n print("BOUNDARY LOAD '+label+': ",script!=null)\n script=null\n quit(0)\n')
a=re.findall(r'verify\((.*)',original);b=re.findall(r'verify\((.*)',body)
# Allow runtime type lookup spelling only; original assertion expressions/labels retained otherwise.
norm=lambda x:x.replace('load("res://scripts/player/player_tuning.gd").load_default()','PlayerTuning.load_default()')
assert [norm(x) for x in b]==a
receipt={'scope':'Build-only candidate; no tracked source change','original_sha256':hashlib.sha256(original.encode()).hexdigest(),'candidate_sha256':hashlib.sha256(body.encode()).hexdigest(),'verify_call_lines_identical_after_runtime_type_lookup_normalization':True,'original_verify_lines':a,'candidate_verify_lines':b}
(R/'build/forest_depth/level_capability/boundary-preparation.json').write_text(json.dumps(receipt,indent=2)+'\n');print(O)
