extends SceneTree
var checks: Array=[]
var cases: Array=[]
var owner_observations: Array=[]
var failures:=0
func data_script(path:String)->Script:return load(path) as Script
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks.append({"passed":ok,"label":label})
 if not ok:failures+=1;printerr("AIM HISTORY FAIL: "+label)
func frames(n:int)->void:
 for i:int in n:await physics_frame;await process_frame
func accepted(d:Dictionary)->bool:
 var m =data_script("res://scripts/run/run_manifest.gd").from_snapshot(d)
 return m!=null and m.canonical_json()==JSON.stringify(d,"",true)
func run()->void:
 var originals:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/main_dbc6ba08_actual_plains_prefixes.json"))
 var current:=originals[0].recorded.duplicate(true) as Dictionary
 var fingerprint:=FileAccess.get_sha256("res://config/player_tuning.json")
 var tuning =data_script("res://scripts/player/player_tuning.gd").load_default()
 check(tuning.max_air_shots==1 and tuning.focus_time_scale==0.15,"new-run default retains one shot and .15")
 for e:Dictionary in current.stages:
  var o:Dictionary=e.outputs
  var g =data_script("res://scripts/generation/plains_region_generator.gd").new()
  var generated:Dictionary=g.generate(str(o.generated_layout.seed),tuning,false,"",str(o.generated_layout.difficulty))
  check(generated.ok and generated.manifest.player_tuning_hash==fingerprint and generated.manifest.shot_energy_version=="time-energy-v2","new generation current fingerprint and v2 marker map%s"%e.stage_index)
  o.generated_layout=generated.manifest
  o.enemy_layout={"version":generated.manifest.version,"enemies":generated.manifest.enemies}
  o.shot_latch_layout=generated.manifest.shot_latch_plan
  o.stage_tuning.max_air_shots=1
  o.capability_snapshot.max_air_shots=1
 check(accepted(current),"genuine current one-shot profile canonical")
 var earned:=current.duplicate(true)
 for e:Dictionary in earned.stages:
  e.outputs.capability_snapshot.items=["shot_purple"]
  e.outputs.capability_snapshot.max_air_shots=2
  e.outputs.stage_tuning.max_air_shots=2
 check(accepted(earned),"current legitimate earned shot item resolves to two without legacy bypass")
 var missing_earned:=earned.duplicate(true);missing_earned.stages[0].outputs.capability_snapshot.items=[]
 check(data_script("res://scripts/run/run_manifest.gd").from_snapshot(missing_earned)==null,"current two-shot claim without earned item rejects")
 for mutation:String in ["unearned_two","retag_old","unknown_hash","wrong_marker","capability_mismatch","gravity"]:
  var bad:=current.duplicate(true)
  var o:Dictionary=bad.stages[0].outputs
  match mutation:
   "unearned_two":o.stage_tuning.max_air_shots=2;o.capability_snapshot.max_air_shots=2
   "retag_old":o.generated_layout.player_tuning_hash=data_script("res://scripts/generation/plains_region_generator.gd").PRE_SINGLE_SHOT_TUNING_HASH
   "unknown_hash":o.generated_layout.player_tuning_hash="f".repeat(64)
   "wrong_marker":o.generated_layout.shot_energy_version="plains-shot-energy-v1"
   "capability_mismatch":o.capability_snapshot.max_air_shots=2
   "gravity":o.stage_tuning.gravity+=1
  o.generated_layout.manifest_hash=data_script("res://scripts/generation/plains_region_generator.gd").new()._hash(o.generated_layout)
  check(data_script("res://scripts/run/run_manifest.gd").from_snapshot(bad)==null,"current profile rejects "+mutation)
 for mutation:String in ["wrong_focus","wrong_marker","capability_mismatch","gravity"]:
  var bad:Dictionary=originals[0].recorded.duplicate(true)
  var o:Dictionary=bad.stages[0].outputs
  match mutation:
   "wrong_focus":o.stage_tuning.focus_time_scale=0.2
   "wrong_marker":o.generated_layout.shot_energy_version="time-energy-v2";o.generated_layout.manifest_hash=data_script("res://scripts/generation/plains_region_generator.gd").new()._hash(o.generated_layout)
   "capability_mismatch":o.capability_snapshot.max_air_shots=1
   "gravity":o.stage_tuning.gravity+=1
  check(data_script("res://scripts/run/run_manifest.gd").from_snapshot(bad)==null,"3a1 historical profile rejects "+mutation)
 var pre:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/evidence/forest_depth_v2/reviews/campaign-output-helper/cross_region_manifest.json"))
 pre.schema_version=1;pre.versions=pre.legacy_versions.duplicate(true);pre.erase("legacy_versions");pre.stages=pre.stages.slice(0,2)
 for e:Dictionary in pre.stages:e.outputs.stage_tuning.focus_time_scale=0.15
 check(accepted(pre),"existing e516 two-shot/.15 replay remains canonical")
 var bad_pre:=pre.duplicate(true)
 bad_pre.stages[0].outputs.stage_tuning.focus_time_scale=0.2
 bad_pre.stages[0].outputs.stage_tuning.max_air_shots=1
 bad_pre.stages[0].outputs.capability_snapshot.max_air_shots=1
 check(data_script("res://scripts/run/run_manifest.gd").from_snapshot(bad_pre)==null,"e516 forged one-shot/.2 mix rejected")
 var helper:Node=load("res://tests/aim_save_compat_case.gd").new();helper.reporter=weakref(self);root.add_child(helper)
 for archive:Dictionary in originals:
  for e:Dictionary in archive.recorded.stages:
   var expected:Dictionary=e.outputs.generated_layout
   var state =data_script("res://scripts/run/plains_region_state.gd").new();check(state.bind_map(expected.manifest_hash),"actual 3a1 oldmap binds "+archive.mode+str(e.stage_index))
   state.claimed["old_claim"]=true;state.opened["old_open"]=true;state.mechanisms["old_switch"]={"open":true}
   var app:=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
   check(app.start_debug_region(&"plains",int(e.stage_index),str(archive.recorded.root_seed)),"actual oldmap loader starts "+archive.mode+str(e.stage_index))
   app.region_states[1]=state
   await frames(10)
   var ready:bool=app.stage is PlainsRegionStage and app.stage.assembly_ok
   check(ready,"actual oldmap assembles "+archive.mode+str(e.stage_index))
   if ready:
    check(data_script("res://scripts/generation/random_stage_generator.gd").new()._same_data(app.stage.generated.manifest,expected),"exact 3a1 full layout restored "+archive.mode+str(e.stage_index))
    check(app.region_state==state and state.claimed.has("old_claim") and state.opened.has("old_open") and state.mechanisms.get("old_switch")=={"open":true},"old claims and switch retained "+archive.mode+str(e.stage_index))
    check(app.controller.motor.tuning.max_air_shots==1 and app.controller.motor.tuning.focus_time_scale==0.15,"historical identity never grants runtime shots "+archive.mode+str(e.stage_index))
    check(data_script("res://scripts/generation/plains_region_generator.gd").new().validate(expected,app.controller.motor.tuning),"all actual old module contracts support current1 "+archive.mode+str(e.stage_index))
    check(accepted(JSON.parse_string(app.director.manifest.canonical_json())),"actual reloaded fresh metadata canonical "+archive.mode+str(e.stage_index))
   await helper.dispose(app)
 helper.free();helper=null
 finish.call_deferred()
func finish()->void:
 var report:={"checks":checks,"failures":failures,"owner_observations":owner_observations,"scope":"finite historical metadata replay and real App map ledger restore; runtime current1, no full-run resume API"}
 DirAccess.make_dir_recursive_absolute("res://build")
 var f:=FileAccess.open("res://build/aim-history-profiles.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
 print("AIM HISTORY PROFILES: %s assertions / %s failures"%[checks.size(),failures]);quit(1 if failures else 0)
