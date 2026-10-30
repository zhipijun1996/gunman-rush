extends SceneTree
## Integration acceptance in an unpacked package + installed hash-locked host.
## These checks do not fabricate new route, seam or human-playtest certification.
const REGISTRY=preload("module_registry.gd")
const PLAYER=preload("res://scenes/player/player.tscn")
var errors: Array=[]
var rows: Array=[]
var checked_mechanism:=false
var checked_reward:=false
var checked_shared_instances:=false
var checked_translated_wave:=false
var collision_checks:=0
var checked_body_collision:=false
var output:="user://module-runtime-validation.json"

func _initialize() -> void:
 var args:=OS.get_cmdline_user_args()
 for i: int in args.size():
  if args[i]=="--report" and i+1<args.size():output=args[i+1]
 run.call_deferred()

func check(ok: bool, detail: String) -> void:
 if not ok:errors.append(detail);push_error(detail)

func run() -> void:
 var base: String=get_script().resource_path.get_base_dir().get_base_dir()
 var registry=REGISTRY.new();check(registry.open(base).get("ok",false),"catalog_open")
 var catalog: Dictionary=registry.catalog
 var profile_loader=load(base.path_join("runtime/module_runtime/native_profile_v5-eeef5b9dc854.gd")).new()
 for entry: Dictionary in catalog.modules:
  var before:=errors.size()
  var world:=Node2D.new();world.name="AcceptanceWorld";world.process_mode=Node.PROCESS_MODE_PAUSABLE;root.add_child(world)
  var motor: PlayerMotor=PLAYER.instantiate()
  motor.get_node("PlayerFeedback").free();motor.position=Vector2(-90000,-90000);world.add_child(motor)
  var player: PlayerController=motor.get_node("Controller");player.enable_shot_energy()
  var initial: Dictionary=entry.initialConfiguration
  if initial.nativeFixture is Dictionary:
   check(profile_loader.initialize_once(player,initial.nativeTuning,initial.nativeFixture).get("ok",false),entry.id+":player_profile_initialization")
  elif initial.nativeTuning is Dictionary:
   check(FoundryCatalog.apply_profile(player,str(initial.nativeTuning.id)),entry.id+":native_tuning")
  var lifetime:=DemoLifetime.new();var policy:=FrameDamagePolicy.new();policy.lifetime=lifetime;world.add_child(policy);policy.register_player_controller(player)
  policy.register_target(&"player",player.actor_resources.health,true)
  var wallet:=RunWallet.new();wallet.grant(17,&"host-initial-wallet")
  var services:={"policy":policy,"lifetime":lifetime,"wallet":wallet,"meta":MetaProgression.new(),"region_state":PlainsRegionState.new()}
  var shots:=player.action_resources.shot_charges;var hp:=player.actor_resources.health.current
  var origin:=Vector2i(7,-3)
  var result: Dictionary=registry.instantiate_module(entry.id,"acceptance/"+entry.id,origin,world,player,services)
  check(result.get("ok",false),entry.id+":external_player_binding:"+str(result.get("reason","")))
  if result.get("ok",false):
   var instance: Node2D=result.instance
   disable_tree(world)
   check(player.action_resources.shot_charges==shots and player.actor_resources.health.current==hp and wallet.balance==17,entry.id+":resources_changed_at_binding")
   check(instance.rewards.actor==player,entry.id+":external_actor_identity")
   for port: Dictionary in entry.ports:
    var at: Array=port.position;var offset: Array=entry.sceneOriginOffsetPixels
    var expected:=Vector2(origin)*float(entry.blockSize)+Vector2(offset[0]+at[0],offset[1]+at[1])
    var actual: Dictionary=instance.world_port(str(port.id))
    check(actual.get("ok",false) and actual.position.is_equal_approx(expected),entry.id+":world_port:"+str(port.id))
   check(not registry.instantiate_module(entry.id,"acceptance/"+entry.id,origin,world,player,services).get("ok",false),entry.id+":duplicate_instance_accepted")
   check(not registry.instantiate_module(entry.id,"bad/"+entry.id,origin,world,player,services,"unknown-layout").get("ok",false),entry.id+":unknown_layout_accepted")
   var count: int=instance.content.platforms.size()
   for index: int in count:
    var body: StaticBody2D=instance.module.get_node_or_null("Platform"+str(index))
    check(body!=null,entry.id+":missing_platform:"+str(index))
    if body!=null:
     var shape: CollisionShape2D=body.get_node("CollisionShape2D");var rect: Array=instance.content.platforms[index]
     check(shape.shape is RectangleShape2D and shape.shape.size.is_equal_approx(Vector2(rect[2],rect[3])),entry.id+":collision_geometry:"+str(index))
     check(shape.one_way_collision==(index in instance.module.definition.one_way_platform_indices),entry.id+":collision_one_way:"+str(index));collision_checks+=1
   if not checked_body_collision and count>0:
    var floor_rect: Array=instance.content.platforms[0]
    motor.global_position=instance.to_global(Vector2(floor_rect[0]+floor_rect[2]/2.0,floor_rect[1]-18.5))
    await physics_frame
    for step: int in 4:
     motor.velocity=Vector2(0,60);motor.move_and_slide();await physics_frame
    check(motor.is_on_floor(),entry.id+":actual_host_body_floor_collision")
    checked_body_collision=motor.is_on_floor();motor.global_position=Vector2(-90000,-90000)
   # Actual native projectile swept collision and the original deferred bell transaction.
   if not checked_mechanism:
    for latch: ShotLatch in instance.cells.latches:
     if latch.is_open or latch.motion_mode or not latch.sequence_offset.is_zero_approx():continue
     if latch.get_script().resource_path!="res://scripts/world/shot_latch.gd":continue
     var prior:=latch.open_count
     var projectile:=PlayerProjectile.new();projectile.owner_controller=player;projectile.owner_body=motor
     projectile.owner_id=motor.get_instance_id();projectile.session_id=player.session_id;projectile.shot_id=1
     projectile.direction=Vector2.RIGHT;world.add_child(projectile);projectile.set_physics_process(false)
     projectile.global_position=latch.bell_body.global_position-Vector2(10,0)
     # The acceptance fixture supplies a fired-shot event; the actual host projectile owns impact delivery.
     player.shoot_ability.shot_fired.emit(Vector2.RIGHT,1)
     await physics_frame
     projectile.advance(1.0/60.0);latch._physics_process(1.0/60.0)
     await process_frame;await process_frame
     check(latch.open_count>prior,entry.id+":real_projectile_bell_commit")
     checked_mechanism=latch.open_count>prior
     if is_instance_valid(projectile):projectile.free()
     break
   # Existing reward service grants to the externally supplied wallet, idempotently.
   if not checked_reward and not instance.rewards.services.is_empty():
    var service: SimpleRoomReward=instance.rewards.services.values()[0]
    var balance:=wallet.balance;var receipt=service.claim(lifetime.token(),&"acceptance-claim")
    check(receipt.accepted() and wallet.balance>balance,entry.id+":reward_wallet_commit")
    var first:=wallet.balance;service.claim(lifetime.token(),&"acceptance-claim")
    check(wallet.balance==first,entry.id+":reward_duplicate_grant");checked_reward=receipt.accepted()
   if not checked_shared_instances and not instance.cells.enemies.is_empty():
    var targets_before: int=policy._targets.size()
    var other: Dictionary=registry.instantiate_module(entry.id,"second/"+entry.id,origin+Vector2i(20,0),world,player,services)
    check(other.get("ok",false),entry.id+":second_instance_binding")
    if other.get("ok",false):
     disable_tree(world)
     check(policy._targets.size()==targets_before+other.instance.cells.enemies.size(),entry.id+":independent_enemy_damage_targets")
     registry.unload("second/"+entry.id);await process_frame;await process_frame
     check(policy._targets.size()==targets_before,entry.id+":unload_releases_owned_damage_targets")
     checked_shared_instances=policy._targets.size()==targets_before
   if instance.content.has("review029_wave"):
    instance.wave.spawn_wave();disable_tree(world);await physics_frame
    var enemy: EnemyActor=instance.wave.actors[0]
    var old_x: float=enemy.motor.global_position.x
    var target_x: float=instance.to_global(Vector2(float(instance.content.review029_wave.targetX),0)).x
    instance.wave._physics_process(1.0/60.0)
    check((enemy.motor.global_position.x-old_x)*(target_x-old_x)>0,entry.id+":translated_ambush_direction")
    checked_translated_wave=(enemy.motor.global_position.x-old_x)*(target_x-old_x)>0
   registry.unload("acceptance/"+entry.id)
  rows.append({"id":entry.id,"passed":errors.size()==before,"sourceSha256":entry.sourceSha256,"ports":entry.ports.size()})
  world.queue_free();await process_frame;await process_frame
 check(checked_shared_instances,"no_shared_instance_witness");check(checked_translated_wave,"no_translated_ambush_witness");check(checked_body_collision,"no_real_body_collision_witness");check(checked_mechanism,"no_real_mechanism_witness");check(checked_reward,"no_real_reward_witness")
 var report:={"schema":"map-edit/portable-runtime-acceptance/v1","passed":errors.is_empty(),"engine":Engine.get_version_info().string,"modules":rows,"errors":errors,"collisionChecks":collision_checks,"actualBodyCollision":checked_body_collision,"independentSharedInstances":checked_shared_instances,"translatedAmbush":checked_translated_wave,"externalPlayerBinding":true,"translatedPlacement":[7,-3],"mechanism":checked_mechanism,"reward":checked_reward,"routeRecertification":false,"humanPlaytest":false}
 var f:=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("MODULE_PACKAGE_ACCEPTANCE ",JSON.stringify({"passed":errors.is_empty(),"modules":rows.size(),"collisions":collision_checks,"errors":errors.size()}));quit(0 if errors.is_empty()else 4)

func disable_tree(node: Node) -> void:
 node.set_process(false);node.set_physics_process(false);node.set_process_unhandled_input(false)
 for child: Node in node.get_children():disable_tree(child)
