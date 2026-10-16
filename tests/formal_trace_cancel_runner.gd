extends "res://tests/plains_encounter_policy_runner.gd"
## Test-only cancellation consumers. Fault injection is labelled; no traversal,
## damage, combat or device acceptance is inferred from these mechanism cases.
const CLOSURE: Array[String] = [
 "plains_encounter_policy_runner","level_formal_trace","plains_region_trace",
 "plains_run_trace","random_stage_tests","branch_module_driver",
 "plains_exploration_motion","plains_creek_discovery_motion",
 "plains_interactive_motion","plains_cohesion_motion","shot_latch_module_driver",
 "challenge_ferry_tests","recoil_recovery_tests","challenge_recoil_tests"]

func probe_execution(driver: RewardTrace, state: Dictionary, kind: String) -> void:
 await probe_inner(driver,state,kind)
 while state.get("hold_execution_ack",false): await process_frame
 state.execution_done=true

func probe_inner(driver: RewardTrace, state: Dictionary, kind: String) -> void:
 if kind=="invalid_motor_entry":
  # A detached test observer reference, not actor relocation or a claimed kill.
  state.cancel_site="invalid_motor_entry"
  driver.motor=null
  driver.terminated=true
  driver.outcome="test_invalid_motor_observer_reference"
  await driver.tick()
  if driver.is_trace_cancelled(): return
 elif kind=="real_fatal_default_cleanup":
  await driver.tick(40)
  if driver.is_trace_cancelled(): return
  var request: DamageRequest=DamageRequest.new()
  request.token=driver.lifetime.token()
  request.event_id=&"cancel_fixture_lethal"
  request.source_id=&"test/cancel_lethal_policy_fixture"
  request.target_id=&"player"
  request.amount=driver.controller.actor_resources.health.current
  request.health_epoch=driver.controller.actor_resources.health.epoch
  request.actor_epoch=driver.lifetime.actor_epoch
  state.cancel_site="real_fatal_default_cleanup"
  state.lethal_submitted=driver.app.policy.submit(request)
  await driver.tick(2)
  if driver.is_trace_cancelled(): return
 elif kind=="nested_deep_trial":
  state.cancel_site="nested_deep_trial"
  await driver.deep_trial("deep_high")
  if driver.is_trace_cancelled(): return
 elif kind=="nested_branch_helper":
  var helper=load("res://tests/branch_module_driver.gd").new()
  state.helper_reference=weakref(helper)
  var module: PlatformingModule=driver.named("tutorial_gap")
  if module==null: module=driver.stage.modules[0]
  state.cancel_site="nested_branch_helper"
  await helper.traverse(module,driver.motor,driver.tick,driver.record_check)
  if driver.is_trace_cancelled(): return
 elif kind=="nested_claim_wait":
  var arrived: bool=await driver.tutorial()
  if driver.is_trace_cancelled(): return
  if not arrived: state.setup_failed=true;return
  arrived=await driver.follow_to("area_1_1")
  if driver.is_trace_cancelled(): return
  if not arrived: state.setup_failed=true;return
  var chest: Dictionary=driver.formal_stage.chests.filter(func(c: Dictionary):return str(c.id).ends_with("medium_0"))[0]
  arrived=await driver.move_to(chest.position.x,500)
  if driver.is_trace_cancelled(): return
  if not arrived: state.setup_failed=true;return
  # Explicit cancellation fixture: exhaust the observation budget at the next
  # nested modal tick. Original production/Harness budgets remain unchanged.
  driver.frame_budget=driver.trace_ticks
  state.cancel_site="nested_claim_wait"
  await driver.claim_required_chest(str(chest.id))
  if driver.is_trace_cancelled(): return
 else:
  state.cancel_site=kind
  await driver.move_to(driver.motor.global_position.x+100,500)
  if driver.is_trace_cancelled(): return
 state.unexpected_route_return=true

func run_probe(kind: String) -> void:
 var app: DemoApp=DemoApp.new()
 app.meta_persistence_enabled=false
 root.add_child(app)
 verify(app.start_plains("level-design-v2-baseline"),kind+" normal actual world starts")
 for unused: int in 120:
  await physics_frame
  await process_frame
  if app.stage is PlainsRegionStage and not app._stage_pending: break
 var driver: RewardTrace=RewardTrace.new()
 verify(driver.attach(app,"fast",0,"kill_from_bank_v1"),kind+" real scheduled controller attached")
 driver.frame_budget=12000 if kind in ["nested_claim_wait","real_fatal_default_cleanup"] else 6
 var state: Dictionary={"execution_done":false,"hold_execution_ack":kind=="noncooperative_ack"}
 var actor_reference: WeakRef=weakref(driver.controller)
 var connections_before: int=driver.controller.shoot_ability.shot_fired.get_connections().size()
 probe_execution.call_deferred(driver,state,kind)
 var started: int=Time.get_ticks_msec()
 while not driver.terminated and not state.get("execution_done",false) and Time.get_ticks_msec()-started<90000:
  await process_frame
 verify(driver.terminated and state.get("cancel_site","")==kind and (kind=="invalid_motor_entry" or (kind=="real_fatal_default_cleanup" and driver.outcome.begins_with("run_ended/")) or driver.outcome=="frame_budget_exhausted") and not state.get("setup_failed",false) and not state.get("unexpected_route_return",false),kind+" reaches the declared actual sticky suspension")
 var original_terminal: Dictionary={"events":driver.events.duplicate(true),"capability":driver.final_capability.duplicate(true),"runtime":driver.final_runtime.duplicate(true),"outcome":driver.outcome}
 var production_cleanup_done: bool=false
 if kind=="real_fatal_default_cleanup":
  var first_fatal_health: bool=driver.events.any(func(e: Dictionary):return e.kind=="player_health" and e.get("current",-1)==0)
  var committed_fatal: bool=driver.events.any(func(e: Dictionary):return e.kind=="damage_committed" and e.get("target","")=="player" and e.get("lethal",false))
  verify(state.get("lethal_submitted",false) and first_fatal_health and committed_fatal and driver.events.any(func(e: Dictionary):return e.kind=="died") and driver.events.any(func(e: Dictionary):return e.kind=="run_ended"),"real lethal FrameDamagePolicy reaches production death/run-ended handlers")
  var production_started: int=Time.get_ticks_msec()
  while (actor_reference.get_ref()!=null or app.director.state!=DemoRunDirector.State.HOME) and Time.get_ticks_msec()-production_started<1000:
   await process_frame
  production_cleanup_done=actor_reference.get_ref()==null and app.director.state==DemoRunDirector.State.HOME and app.controller==null
  verify(production_cleanup_done,"default production cleanup really frees old actor before observer unwind")
 var frozen: Dictionary={"frames":driver.observed_frames.duplicate(true),"events":driver.events.duplicate(true),"resources":driver.resource_receipts.duplicate(true),"diagnostics":driver.diagnostics.duplicate(true),"outcome":driver.outcome,"facts":driver.cancellation_facts().duplicate(true)}
 var sealed_hash: String=JSON.stringify(frozen).sha256_text()
 var cleanup: Dictionary=await unwind_reward_execution(driver,state,app)
 var refused_timeout: bool=false
 if kind=="noncooperative_ack":
  refused_timeout=not cleanup.ok and not cleanup.execution_done and cleanup.elapsed_msec>=cleanup.deadline_msec
  verify(refused_timeout,"noncooperative acknowledgement actually rejected within original deadline")
  # The negative is not allowed to leak: restore legitimate cooperation and
  # observe an actual ack before any world/driver is released.
  state.hold_execution_ack=false
  var timeout_receipt: Dictionary=cleanup.duplicate(true)
  cleanup=await unwind_reward_execution(driver,state,app)
  cleanup["expected_timeout_refusal"]=timeout_receipt
 verify(cleanup.ok and driver.terminated,kind+" cancellation preserves sticky termination and stable actual counters")
 verify(JSON.stringify(frozen).sha256_text()==sealed_hash,kind+" original terminal evidence remains byte sealed")
 if is_instance_valid(driver.controller):
  verify(driver.controller.shoot_ability.shot_fired.get_connections().size()==connections_before,kind+" nested helper removed its actual shot observer")
 else:
  verify(production_cleanup_done,kind+" original signal emitter released by default production cleanup")
 var helper_released: bool=not state.has("helper_reference") or (state.helper_reference as WeakRef).get_ref()==null
 verify(helper_released,kind+" nested helper await state released")
 var removed: int=driver.disconnect_test_observers()
 var audio_released: bool=await AUDIO_TEARDOWN.drain_world(app)
 verify(removed>0 and audio_released,kind+" actual observers and backend released")
 var reference: WeakRef=weakref(driver)
 app.queue_free()
 await process_frame
 driver=null
 var released: bool=reference.get_ref()==null
 verify(released,kind+" driver actual WeakRef released")
 cases.append({"id":kind,"scope":"explicit_cancel_mechanism_fixture_not_gameplay_traversal","cancel_site":state.get("cancel_site","not_reached"),"first_terminal_observation":original_terminal,"production_cleanup_done_before_unwind":production_cleanup_done,"sealed_case_sha256":sealed_hash,"post_unwind_sha256":JSON.stringify(frozen).sha256_text(),"unwind":cleanup,"driver_released":released,"helper_released":helper_released,"audio_released":audio_released,"observers_disconnected":removed,"expected_timeout_refused":refused_timeout})

func run() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
 for name: String in CLOSURE:
  var script: Script=load("res://tests/"+name+".gd")
  verify(script!=null,"actual complete14 script protocol compiles: "+name)
 for kind: String in ["budget_move","nested_deep_trial","nested_branch_helper","invalid_motor_entry","nested_claim_wait","real_fatal_default_cleanup","noncooperative_ack"]:
  await run_probe(kind)
 var report: Dictionary={"schema_version":1,"artifact_kind":"formal_trace_cancellation_proof","assertions":assertions,"failures":failures,"cases":cases,"engine":Engine.get_version_info().string,"scope":"actual test-only consumers; current native/recovery/reward/historical matrices remain separate"}
 DirAccess.make_dir_recursive_absolute(output.get_base_dir())
 var file: FileAccess=FileAccess.open(output,FileAccess.WRITE)
 file.store_string(JSON.stringify(report));file.close()
 print("FORMAL TRACE CANCEL: %s assertions, %s failures, %s cases"%[assertions,failures,cases.size()])
 quit(1 if failures else 0)
