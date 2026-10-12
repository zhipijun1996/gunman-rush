extends SceneTree
var failures:=0
var assertions:=0
func _initialize()->void: run.call_deferred()
func check(ok:bool,label:String)->void:
 assertions+=1
 if not ok: failures+=1;print("FAIL ",label)
func run()->void:
 var g:=PlainsRegionGenerator.new();var found:=false
 for i:int in 4:
  var m:Dictionary=g.generate("review-pressure/%s"%i,PlayerTuning.load_default(),false,"","advanced").manifest
  var selected:Dictionary={}
  for n:Dictionary in m.nodes:
   if n.module_id=="plains_ferry_channel" and m.enemies.any(func(e:Dictionary)->bool:return e.area==n.id and e.behavior_id=="fan_sentry"): selected=n;break
  if selected.is_empty(): continue
  found=true;var trace=load("res://tests/plains_region_trace.gd").new();trace.tree=self;trace.check=check
  trace.world=Node2D.new();root.add_child(trace.world);trace.stage=PlainsRegionAssembler.new();trace.region_state=PlainsRegionState.new();trace.region_state.bind_map(str(m.manifest_hash));trace.stage.region_state=trace.region_state;trace.world.add_child(trace.stage)
  check(trace.stage.build(m,PlayerTuning.load_default()).ok,"actual whole-map geometry builds")
  var module:PlatformingModule=trace.named(str(selected.id))
  trace.motor=preload("res://scenes/player/player.tscn").instantiate();trace.motor.position=module.world_entry();trace.world.add_child(trace.motor);trace.controller=trace.motor.get_node("Controller");trace.controller.enable_shot_energy();trace.controller.set_physics_process(false);trace.motor.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
  trace.previous_body=Rect2(trace.motor.position-Vector2(12,18),Vector2(24,36))
  for p:PlatformingModule in trace.stage.modules:
   for saw:ModuleSawHazard in p.hazards:trace.previous_hazards[saw.get_instance_id()]=saw.global_position
  var life:=DemoLifetime.new();var policy:=FrameDamagePolicy.new();policy.lifetime=life;trace.world.add_child(policy);policy.register_target(&"player",trace.controller.actor_resources.health,true);policy.player_fatal.connect(func(): trace.controller.die())
  var enemies:Array[EnemyActor]=[]
  for e:Dictionary in m.enemies:
   if e.area!=selected.id:continue
   var drone:=preload("res://scenes/enemies/patrol_drone.tscn").instantiate() as EnemyMotor;drone.position=Vector2(e.position[0],e.position[1]);var actor:=drone.get_node("Actor") as EnemyActor;actor.definition=PlainsEncounterPlanner.definition_for_behavior(str(e.behavior_id)).duplicate(true);actor.definition.patrol_half_width=e.patrol_radius;actor.definition.aerial=e.aerial
   if e.has("dive_depth"):actor.definition.dive_depth=e.dive_depth
   trace.world.add_child(drone);policy.bind_damageable(StringName(e.id),actor.damageable,actor.health);actor.bind_encounter(trace.controller,policy,life,StringName(e.id),trace.stage.world_anchors());actor.attack_behavior.max_concurrent_attacks=2;enemies.append(actor)
   var emitter:=DemoContactEmitter.new();emitter.policy=policy;emitter.controller=trace.controller;emitter.source_id=StringName(e.id+"_contact");emitter.kind=DamageRequest.Kind.MONSTER;emitter.half_size=actor.definition.collision_size/2+Vector2.ONE;drone.add_child(emitter)
  trace.stage.setup_damage(trace.controller,policy,life)
  await trace.tick(3);var hp:float=trace.controller.actor_resources.health.current;var driver=load("res://tests/branch_module_driver.gd").new();driver.module=module;driver.motor=trace.motor;driver.controller=trace.controller;driver.tick_callback=trace.tick;driver.check=check
  await driver.move_to(module.position.x-130)
  var f:ModuleMovingPlatform=module.moving_platforms[0]
  for unused:int in 900:
   var phase:float=fposmod(module.clock+f.definition.initial_phase*f.definition.period(),f.definition.period())
   if phase>f.definition.period()-1.0:break
   await driver.advance()
  var ok:bool=await load("res://tests/plains_exploration_motion.gd").carrier(driver,module,true)
  await trace.tick(3);var serials:Array=[]
  for actor:EnemyActor in enemies:serials.append([actor.definition.behavior_id,actor.attack_behavior._serial,actor.health.current,actor.attack_behavior.state])
  check(ok and trace.safe_trace and trace.continuous_trace,"read phase then board/ride/leave without teleport or hazard contact")
  check(trace.controller.actor_resources.health.current==hp,"real fan + diver + platform route takes zero damage")
  var live:=true;var repeated:=false
  for actor:EnemyActor in enemies:
   live=live and not actor.health.terminal and actor.health.current==actor.definition.health_definition.initial_current
   if actor.definition.behavior_id==&"fan_sentry": repeated=actor.attack_behavior._serial>=6
  check(live and repeated,"enemies remain alive; real fan fires repeatedly after previous projectiles free")
  check(trace.motor.is_on_floor() and trace.motor.global_position.distance_to(module.world_exit())<2,"pressure route exits on actual standing support")
  print("FORMAL PRESSURE seed=",m.seed," node=",selected.id," phases=",selected.initial_phases," ok=",ok," hp_before=",hp," hp_after=",trace.controller.actor_resources.health.current," safe=",trace.safe_trace," continuous=",trace.continuous_trace," actors=",serials," ticks=",trace.trace_ticks)
  trace.world.free();break
 check(found,"find real ferry channel plus fan in formal generation")
 print("PLAINS EXPLORATION PRESSURE: %s assertions, %s failures" % [assertions,failures])
 quit(1 if failures else 0)
