extends SceneTree
var assertions:=0
var failures:=0
var app:DemoApp
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 assertions+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func frames(n:int)->void:
 for i:int in n:await physics_frame
func isolate(node:Node)->void:
 if node is DemoContactEmitter:node.enabled=false
 if node is EnemyAttackBehavior:node.set_physics_process(false)
 for child:Node in node.get_children():isolate(child)
func run()->void:
 # Fixture spawn is explicit. Subsequent wall movement uses real physics/input.
 app=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
 await frames(2);check(app.start_plains("d082-seal-lifecycle"),"formal region setup");await frames(8)
 var stage:PlainsRegionStage=app.stage
 app.player.reset_at(Vector2(stage.boss_arena.position.x+70,stage.boss_arena.end.y-18));await frames(48)
 var seal:BossArenaSeal=stage.boss_seal
 check(seal.closed and seal.close_count==1,"full core entry closes actual formal seal once")
 check(not app.segment._history.is_empty() and app.segment._history[-1]==&"boss_enter","environment fallback stays inside sealed arena")
 isolate(app)
 app.controller.router.set_move_axis(-1);await frames(90)
 check(app.player.global_position.x>=stage.boss_arena.position.x+11,"real retreat is physically blocked")
 app.controller.router.set_move_axis(0)
 paused=true;stage.capture_state();check(app.region_state.boss_state.seal_closed,"closed seal saved in actual ledger")
 app._load_stage();await process_frame;await process_frame
 stage=app.stage;seal=stage.boss_seal
 check(seal.closed and seal.walls[0].collision_layer==1,"paused unload rebuild restores real walls")
 check(stage.boss_arena.encloses(Rect2(app.player.position-Vector2(12,18),Vector2(24,36))),"reload spawns inside closed arena")
 check(not app.segment._history.is_empty() and app.segment._history[-1]==&"boss_enter","reload preserves safe internal fallback")
 paused=false;await frames(8);isolate(app)
 await warning_jump(stage)
 await high_jump(stage)
 var boss:BossEncounter=stage.boss.get_node("Encounter")
 var before:float=app.wallet.balance
 var request:=DamageRequest.new();request.token=app.lifetime.token();request.actor_epoch=app.lifetime.actor_epoch;request.health_epoch=boss.health.epoch;request.target_id=&"boss";request.source_id=&"explicit_cohesion_fixture";request.event_id=&"mini_fx_fixture";request.amount=boss.health.current
 check(app.policy.submit(request),"explicit defeat fixture enters real death-priority batch")
 await frames(3)
 check(stage.reward_available and not seal.closed,"defeat opens actual walls and guarantees reward")
 check(is_instance_valid((stage.visual_layer as PlainsStageVisual)._boss_loot),"mini defeat has a visible guaranteed loot object")
 check(stage.get_children().any(func(n):return n is DefeatBurst and n.mini),"mini defeat uses finite AI explosion object")
 check(app.wallet.balance==before,"visual loot does not duplicate fixed reward payout")
 app.player.reset_at(stage.reward_position)
 check(not app._offer_generated_exit(&"boss_home"),"manual exit cannot pause death animation early")
 await frames(60)
 check(app.exit_modal.opened,"settled loot opens actual reward confirmation")
 app._confirm_generated_exit();await frames(8)
 check(app.director.stage_index==2 and app.wallet.balance==before+12,"mini loot settles existing guaranteed 12 coins exactly once")
 if not await load("res://tests/audio_teardown.gd").drain_world(app):
  failures+=1;push_error("TEST AUDIO TEARDOWN: playback did not release within 1000ms");quit(1);return
 app.free();await process_frame;paused=false
 print("PLAINS COHESION LIFECYCLE: %s assertions, %s failures"%[assertions,failures]);quit(1 if failures else 0)

func high_jump(stage:PlainsRegionStage)->void:
 var module:PlatformingModule
 for candidate:PlatformingModule in stage.assembler.modules:
  if candidate.definition.module_id==&"plains_bellstrider_arena":module=candidate
 # Only this probe starts on the actual upper shelf; motion thereafter is input.
 var boss:BossEncounter=stage.boss.get_node("Encounter");boss.set_physics_process(false)
 app.player.reset_at(module.to_global(Vector2(800,392)));await frames(4)
 app.controller.router.set_jump_held(&"ceiling_probe",true);app.controller.router.request_action(&"jump")
 var crossed:=false
 var preserved:=true
 var fired:=false
 var shot_key:=""
 for i:int in 40:
  await frames(1)
  if app.player.position.y<stage.boss_arena.position.y:
   crossed=true;preserved=preserved and app._in_boss_core()
   if not fired:
    app.controller.router.request_action(&"shoot_release",Vector2.UP);fired=true
  if fired and shot_key.is_empty() and app.controller.shoot_ability._shot_serial>0:
   shot_key="%s:%s"%[app.controller.session_id,app.controller.shoot_ability._shot_serial]
   preserved=preserved and app._boss_eligible_shots.has(shot_key)
 app.controller.router.set_jump_held(&"ceiling_probe",false)
 check(crossed and fired and preserved,"actual upper-shelf jump crosses old top while preserving sealed shot eligibility")
 await frames(45)
 check(stage.boss_seal.closed and app._in_boss_core(),"landing keeps real sealed containment")

func warning_jump(stage:PlainsRegionStage)->void:
 var module:PlatformingModule
 for candidate:PlatformingModule in stage.assembler.modules:
  if candidate.definition.module_id==&"plains_bellstrider_arena":module=candidate
 var seal:BossArenaSeal=stage.boss_seal
 seal.release()
 app.player.reset_at(module.to_global(Vector2(800,392)));await frames(3)
 app.controller.router.set_jump_held(&"warning_jump",true);app.controller.router.request_action(&"jump")
 await frames(42)
 check(seal.closed,"actual warning-period high jump closes on schedule without restarting countdown")
 app.controller.router.set_jump_held(&"warning_jump",false);await frames(45)
