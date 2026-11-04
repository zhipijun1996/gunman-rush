extends SceneTree
const READY=preload("res://tests/formal_region_test_support.gd")
var app:DemoApp
var in_flight:=false
var mismatch:=false
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func frames(n:int):
 for i:int in n:await process_frame
func run():
 in_flight="--in-flight" in OS.get_cmdline_user_args()
 mismatch="--mismatch" in OS.get_cmdline_user_args()
 app=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate();app.meta_persistence_enabled=false;root.add_child(app)
 await frames(3);app.menu._seed="ci-smoke";app.menu._start_title_adventure()
 var before:=Time.get_ticks_usec()
 while Time.get_ticks_usec()-before<120000000:
  await process_frame
  if app._home_map_source!=null and (app._home_map_source.progress=="generate" if in_flight or mismatch else app._home_map_source.phase=="prepared"):break
 check(app._home_map_source!=null and (app._home_map_source.progress=="generate" if in_flight or mismatch else app._home_map_source.phase=="prepared"),"Home preparation reaches the requested real phase")
 if failures:await finish();return
 var source:=app._home_map_source;var handle:=source.ticket;var scope:=source._lifetime
 check(source.generation.metrics(handle).get("backend")=="thread","Home uses an independent pure solver thread")
 check(source.generation.take_plan(handle,scope)==null and app.director.state==DemoRunDirector.State.HOME,"Home cannot take a scene plan or commit a run")
 var worker_id:int=source.generation._current.worker.get_instance_id() if source.generation._current.worker!=null else 0
 var fingerprint:String=source.generation._current.provenance.expected_request_fingerprint
 before=Time.get_ticks_usec();check(app.start_plains("different-actual-input" if mismatch else "ci-smoke"),"actual departure accepted")
 await frames(3)
 if mismatch:
  check(not app.run_session.plains_generation._home_solve_reused,"different actual seed rejects Home work")
  check(source.generation.is_closed() and not source.generation.is_current(handle,scope),"mismatched Home handle is invalid and its worker closed")
  app.abandon_run();await frames(4)
  check(not is_instance_valid(app.stage),"cancelling replacement loading cannot commit a late map")
  await finish();return
 if in_flight:
  check(app.run_session.plains_generation.generation._current.worker.get_instance_id()==worker_id,"actual departure continues the same in-flight worker without restarting")
 check(app.run_session.plains_generation.generation._current.provenance.expected_request_fingerprint==fingerprint,"adopted request keeps the exact fingerprint before normal retries")
 check(await READY.ready(app,self),"prepared map assembles through the normal run")
 var elapsed:=float(Time.get_ticks_usec()-before)/1000
 var actual:=app.run_session.plains_generation
 check(actual._home_solve_reused,"new run reuses finished Home solve")
 check(not source.generation.is_current(handle,scope) and not source.generation.commit(handle,scope),"old Home handle cannot validate or commit")
 check(app._home_map_source==null and app._departing_map_source==null,"no Home generation remains while playing")
 check(app.player.tuning.max_jumps==1 and app.player.tuning.max_air_shots==1,"Home preparation grants no additional player actions")
 var stage:MapgenPlainsStage=app.stage
 var view:=stage.map_view
 view._cache_terrain()
 var before_area:=0.0
 for pieces:Array in view._terrain_cells.values():
  for piece:Dictionary in pieces:before_area+=piece.rect.get_area()
 var module:PlatformingModule=stage.assembler.modules[-1]
 var removed_area:=module.definition.platforms[0].get_area()
 var revision:=stage.geometry_revision
 module.release_platform(0) # Disclosed far-module geometry/cache fixture.
 check(stage.geometry_revision>revision,"committed native geometry invalidates map and terrain caches")
 view._cache_terrain()
 var after_area:=0.0
 for pieces:Array in view._terrain_cells.values():
  for piece:Dictionary in pieces:after_area+=piece.rect.get_area()
 check(is_equal_approx(before_area-after_area,removed_area),"map cache follows actual live collision geometry")
 var visible:=0
 for latch:ShotLatch in stage.shot_latches:
  if latch._animation_visible():visible+=1
 check(visible>0 and visible<stage.shot_latches.size(),"visual culling selects visible mechanisms without disabling their physics")
 print("HOME PREPARE WAIT ",elapsed)
 await finish()
func finish():
 if app.lifetime.active:app.abandon_run()
 await frames(4);await preload("res://tests/audio_teardown.gd").drain_world(app);app.queue_free();await frames(4)
 print("MAPGEN HOME PREPARE: ",checks," assertions, ",failures," failures");quit(1 if failures else 0)
