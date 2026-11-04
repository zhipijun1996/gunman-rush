extends SceneTree
## Fixed real-controller seed corpus. Writes source geometry, repetitions and
## phase timings; does not grant abilities, alter the world, or prove playthroughs.
const SEEDS := ["ci-smoke","formal-integration-1","mapgen-standard-2","plains-review-04","plains-review-05","plains-review-06"]
const DATA := preload("res://addons/mapgen/data_json.gd")
var directory := "res://build/mapgen_review/current"
var app: DemoApp
var records: Array[Dictionary]=[]
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
 for i: int in n: await process_frame
func small_metrics(ticket: RefCounted) -> Dictionary:
 var m: Dictionary=ticket.metrics
 var r := {"status":m.get("generation_status",ticket.phase),"error":ticket.error,"seed":ticket.request_data.get("seed"),"request":ticket.request_data,"config":ticket.config,"diagnostics":ticket.actual.get("diagnostics",{}),"solver_metrics":ticket.actual.get("metrics",{}),"rejected_source":ticket.actual if ticket.phase=="failed" and ticket.actual.get("status")=="PASS" else {}}
 for key: String in ["preload_cache_hit","preload_wall_ms","preload_ms","preload_calls","generation_wall_ms","generation_execution_ms","advance_calls","advance_ticks","validate_ms","host_tick_execution_ms","between_tick_gap_ms","preload_profile","generation_profile","backend","verified_library_receipt"]:
  if m.has(key):r[key]=m[key]
 return r
func run() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):directory=arg.trim_prefix("--output=")
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--repro="):
   await replay_upstream(arg.trim_prefix("--repro="));return
 DirAccess.make_dir_recursive_absolute(directory)
 app=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate();app.meta_persistence_enabled=false;root.add_child(app)
 await frames(3);app.menu._start_title_adventure();await frames(2)
 var selected_seeds: Array=SEEDS.duplicate()
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--seed="):selected_seeds=[arg.trim_prefix("--seed=")]
 for seed: String in selected_seeds:
  for map_index: int in [1,2]:
   var before:=Time.get_ticks_usec()
   var accepted: bool=app.start_plains(seed) if map_index==1 else app.start_debug_region(&"plains",2,seed)
   var source:=app.run_session.plains_generation
   var previous: RefCounted
   var attempts: Array[Dictionary]=[]
   while app._stage_pending and app.lifetime.active and Time.get_ticks_usec()-before<240000000:
    var current=source.generation._current
    if current!=null and current!=previous:
     if previous!=null:attempts.append(small_metrics(previous))
     previous=current
    await process_frame
   if previous!=null:attempts.append(small_metrics(previous))
   var ok:=accepted and app.lifetime.active and not app._stage_pending and app.stage is MapgenPlainsStage
   var row: Dictionary={"seed":seed,"map_index":map_index,"accepted":ok,"total_wait_ms":float(Time.get_ticks_usec()-before)/1000.0,"attempts":attempts,"status":app._status}
   if ok:
    var plan: LevelPlan=app.stage.level_plan
    var source_json: Dictionary=DATA.parse(app.stage.generated.manifest.mapgen.source_json).value
    row["source"]=source_json
    row["host_bind_and_assembly_ms"]=float(Time.get_ticks_usec()-previous.last_tick_finished_usec)/1000.0
    row["hash"]=plan.map_hash
    var counts: Dictionary={}
    for placement: LevelModulePlacement in plan.modules:counts[str(placement.template_id)]=int(counts.get(str(placement.template_id),0))+1
    row["module_counts"]=counts;row["modules"]=plan.modules.size();row["unique_modules"]=counts.size()
    row["repeated_fraction"]=1.0-float(counts.size())/plan.modules.size()
   var f:=FileAccess.open(directory.path_join("%s-map_%s.json" % [seed,map_index]),FileAccess.WRITE);f.store_string(JSON.stringify(row,"",true,true));f.close()
   records.append({"seed":seed,"map_index":map_index,"accepted":ok,"total_wait_ms":row.total_wait_ms,"attempts":attempts.size(),"modules":row.get("modules",0),"unique_modules":row.get("unique_modules",0)})
   print("MAPGEN REVIEW ",JSON.stringify(records[-1]))
   if app.lifetime.active:app.abandon_run()
   await frames(8);app.menu.close_panel()
 var file:=FileAccess.open(directory.path_join("summary.json"),FileAccess.WRITE);file.store_string(JSON.stringify(records,"\t"))
 await preload("res://tests/audio_teardown.gd").drain_world(app);app.queue_free();await frames(4)
 print("MAPGEN REVIEW COMPLETE ",records.size());quit()

func replay_upstream(path: String) -> void:
 var decoded: Dictionary=DATA.parse(FileAccess.get_file_as_string(path))
 if not decoded.get("ok",false) or not decoded.value is Dictionary:
  push_error("Invalid reproduction input");quit(1);return
 var input: Dictionary=decoded.value
 var profile:=RuntimeMapGenerationProfile.read_profile()
 var preload_job=preload("res://addons/mapgen/preload_job.gd").create(profile.lock.module_package.path,profile.lock.module_package.sha256)
 while not preload_job.is_done():preload_job.advance(128);await process_frame
 if preload_job.result().get("status")!="PASS":push_error("Locked module preload failed");quit(1);return
 var job=preload("res://addons/mapgen/generation_job.gd").create(input.request,preload_job.result().library,input.config)
 while not job.is_done():job.advance(128);await process_frame
 var actual: Dictionary=job.result()
 DirAccess.make_dir_recursive_absolute(directory)
 var file:=FileAccess.open(directory.path_join("upstream_actual.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(actual,"",true,true));file.close()
 print("MAPGEN UPSTREAM REPRO ",JSON.stringify({"seed":input.request.seed,"status":actual.status,"metrics":actual.get("metrics",{}),"error":actual.get("diagnostics",{}).get("error")}))
 quit(0 if actual.status==input.status else 1)
