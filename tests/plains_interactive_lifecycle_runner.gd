extends SceneTree
var failures:=0
var assertions:=0
var app:DemoApp
var trace:Variant
func _initialize()->void:run.call_deferred()
func check(ok:bool,msg:String)->void:
 assertions+=1;print('CHECK ',ok,' ',msg)
 if not ok:failures+=1
func frames(n:int)->void:
 for i:int in n:await physics_frame
func isolate(node:Node)->void:
 if node is DemoContactEmitter:node.enabled=false
 if node is EnemyAttackBehavior:node.set_physics_process(false)
 for child:Node in node.get_children():isolate(child)
func reload_ferry()->void:
 app=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
 var seed_value:=""
 for i:int in 8:
  var candidate:="d081-actuator/%s"%i
  var generated:=PlainsRegionGenerator.new().generate(PlainsRegionCampaign.seed_for(candidate,1),PlayerTuning.load_default(),false,"","intro")
  if generated.ok and generated.manifest.nodes.any(func(n):return n.module_id=="plains_bell_ferry_control"):seed_value=candidate;break
 check(not seed_value.is_empty(),"bounded normal generated fixture includes ferry controller")
 check(app.start_plains(seed_value),'formal App starts actual generated region');await frames(8)
 var stage:PlainsRegionStage=app.stage
 var index:=-1
 for i:int in stage.shot_latches.size():
  if stage.shot_latches[i].motion_mode:index=i;break
 check(index>=0,'formal generated map contains controlled ferry')
 if index<0:
  if not await preload("res://tests/audio_teardown.gd").drain_world(app):failures+=1;push_error("actual lifecycle app audio failed to drain");quit(1);return
  app.free();return
 var latch:ShotLatch=stage.shot_latches[index]
 isolate(app)
 # Setup-only teleport; pressure/path proof is a separate input-only fixture.
 app.player.reset_at(latch.to_global(Vector2(latch.bell_position.x,282)))
 await frames(4)
 app.controller.router.request_action(&'shoot_release',(latch.bell_body.global_position-app.player.global_position).normalized());await frames(60)
 check(latch.open_count==1 and latch.motion_target.motion_running,'actual projectile starts formal ferry')
 paused=true
 stage.capture_state()
 var instance_id:String=stage.generated.manifest.shot_latch_plan.latches[index].id
 var data:Dictionary=app.region_state.mechanisms[instance_id].duplicate(true)
 var before:float=latch.motion_target.motion_clock
 var pos:Vector2=latch.motion_target.position
 app._load_stage()
 await process_frame;await process_frame
 stage=app.stage;latch=stage.shot_latches[index]
 check(latch.link_id==str(stage.generated.manifest.shot_latch_plan.latches[index].link_id),'reload same stable paired mechanism')
 check(latch.open_count==1 and latch.motion_target.motion_running,'reload preserves started state and one accepted toggle')
 print('PRE COMPARE paused=',paused,' beforeclock=',before,' nowclock=',latch.motion_target.motion_clock,' beforepos=',pos,' nowpos=',latch.motion_target.position)
 print('DELTA phase=',latch.motion_target.motion_clock-before,' position=',latch.motion_target.position-pos)
 check(is_equal_approx(latch.motion_target.motion_clock,before) and latch.motion_target.position.distance_to(pos)<.001,'paused real unload and rebuild retains phase and position within 0.001px float tolerance')
 check(latch._pending.is_empty() and latch._eligible_shots.is_empty(),'reload restores no old accepted requests or shot eligibility')
 paused=false;await frames(8)
 check(latch.motion_target.motion_clock>before,'restored ferry advances from saved phase')
 print('RELOAD assertions=',assertions,' failures=',failures,' before=',before,' after=',latch.motion_target.motion_clock,' snapshot=',data)
 if not await preload("res://tests/audio_teardown.gd").drain_world(app):failures+=1;push_error("actual lifecycle app audio failed to drain");quit(1);return
 app.free()

func pending_death()->void:
 trace=load('res://tests/plains_region_trace.gd').new();trace.tree=self;trace.check=check;trace.world=Node2D.new();root.add_child(trace.world);trace.stage=PlainsRegionAssembler.new();trace.world.add_child(trace.stage)
 var module:=PlatformingModule.new();module.definition=preload('res://resources/generation/modules/plains_bell_ferry_control.tres');trace.stage.add_child(module);trace.stage.modules.append(module)
 trace.motor=preload('res://game/player/player.tscn').instantiate();trace.motor.position=Vector2(130,282);trace.world.add_child(trace.motor);trace.controller=trace.motor.get_node('Controller');trace.controller.enable_shot_energy();trace.controller.set_physics_process(false);trace.motor.get_node('KeyboardMouseAdapter').set_process_unhandled_input(false);trace.previous_body=Rect2(trace.motor.position-Vector2(12,18),Vector2(24,36))
 var manifest:Dictionary={'layout_id':'connected_region','nodes':[{'id':'review-ferry','module_id':'plains_bell_ferry_control','offset':[0,0],'mirrored':false,'reverse_traversal':false}]};manifest.shot_latch_plan=PlainsShotLatchPlanner.recorded_plan(manifest)
 trace.shot_latch_encounter=GeneratedShotLatchEncounter.new();trace.world.add_child(trace.shot_latch_encounter);check(trace.shot_latch_encounter.setup(manifest,trace.stage,trace.controller,trace.lifetime),'consumer installed')
 await trace.tick(4)
 var l:ShotLatch=trace.shot_latch_encounter.latches[0];var ferry:ModuleMovingPlatform=module.moving_platforms[0]
 trace.controller.router.request_action(&'shoot_release',Vector2.UP);await trace.tick(60);check(l.open_count==1 and ferry.motion_running,'real shot starts ferry')
 var before:float=ferry.motion_clock;var lc:float=l._clock;var mc:float=module.clock;var pos:=ferry.position
 paused=true
 for i:int in 60:await process_frame
 check(ferry.motion_clock==before and l._clock==lc and module.clock==mc and ferry.position==pos,'paused clocks and carrier position do not advance')
 paused=false;await trace.tick(4);check(ferry.motion_clock>before,'unpause resumes carrier')
 var audio_receipt: Dictionary = preload("res://tests/audio_teardown.gd").stop_fallback_voices(trace.world)
 l.cancel_pending();check(ferry.motion_clock>before and ferry.motion_running,'segment cancellation preserves carrier phase and running state')
 trace.controller.router.request_action(&'shoot_release',Vector2.UP)
 trace.controller.physics_tick(1.0/60)
 var bullets:Array[PlayerProjectile]=trace.controller.shoot_ability.get_projectiles()
 check(bullets.size()==1,'pending death fixture actual shot exists')
 if not bullets.is_empty():bullets[0].advance(.1)
 check(not l._pending.is_empty(),'death occurs with real projectile request pending')
 print('PRE DEATH pending=',l._pending,' count=',l.open_count,' running=',ferry.motion_running)
 var count:int=l.open_count
 var policy:=FrameDamagePolicy.new();policy.lifetime=trace.lifetime;trace.world.add_child(policy)
 check(policy.register_target(&'player',trace.controller.actor_resources.health,true),'real damage policy binds same health')
 policy.player_fatal.connect(func()->void:trace.controller.die())
 var fatal:=DamageRequest.new();fatal.token=trace.lifetime.token();fatal.actor_epoch=trace.lifetime.actor_epoch;fatal.health_epoch=trace.controller.actor_resources.health.epoch;fatal.target_id=&'player';fatal.source_id=&'review-fatal';fatal.event_id=&'same-frame-death';fatal.kind=DamageRequest.Kind.MONSTER;fatal.amount=trace.controller.actor_resources.health.current
 check(policy.submit(fatal),'same-frame fatal request accepted by actual damage policy')
 var results:Array[DamageResult]=policy.resolve_batch()
 check(results.size()==1 and results[0].lethal and trace.controller.actor_resources.health.terminal and not trace.lifetime.active,'real health fatal batch commits before deferred bell action')
 await process_frame;await process_frame
 print('POST DEATH pending=',l._pending,' count=',l.open_count,' running=',ferry.motion_running)
 check(l.open_count==count,'no post-death toggle commits')
 trace.shot_latch_encounter.queue_free();await process_frame;await process_frame
 check(not is_instance_valid(l),'unloaded mechanism is gone without stale callback')
 if not await preload("res://tests/audio_teardown.gd").wait_fallback_release(audio_receipt):failures+=1;push_error("actual lifecycle fallback audio failed to drain");quit(1);return
 trace.world.free()

func run()->void:
 await reload_ferry()
 await pending_death()
 print("PLAINS INTERACTIVE LIFECYCLE: %s assertions, %s failures"%[assertions,failures])
 quit(1 if failures else 0)
