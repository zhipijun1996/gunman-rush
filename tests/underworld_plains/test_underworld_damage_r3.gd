extends SceneTree
## Accepted policy transactions and actual collision/Motor consumers. Explicit
## fixture spawns are not a claimed natural full-region route or device test.
var checks := 0
var failures: Array[String] = []
var world: Node2D
var motor: PlayerMotor
var controller: PlayerController
var art: UnderworldPlayer
var policy: FrameDamagePolicy
var audio: GameAudio
var rows: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ",label)
func ticks(count: int, phase: String) -> void:
	for i: int in count:
		var steps := motor.motion_steps
		await physics_frame
		await process_frame
		check(motor.motion_steps-steps <= 1,"sole Motor movement once in "+phase)
		rows.append({"phase":phase,"physics_tick":Engine.get_physics_frames(),"position":motor.position,"HP":controller.actor_resources.health.current,"animation":art.animation_receipt(),"hurt_audio":int(audio.played.get(&"hurt",0))})
func request(id: StringName, kind: DamageRequest.Kind, direction: Vector2 = Vector2.RIGHT) -> DamageRequest:
	var value := DamageRequest.new()
	value.token=policy.lifetime.token(); value.actor_epoch=policy.lifetime.actor_epoch
	value.health_epoch=controller.actor_resources.health.epoch
	value.event_id=id;value.source_id=id;value.target_id=&"player";value.kind=kind;value.hit_direction=direction
	return value
func floor_at(location: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new();body.position=location
	var shape := CollisionShape2D.new();var box := RectangleShape2D.new();box.size=size;shape.shape=box
	body.add_child(shape);world.add_child(body);return body
func lower_route_fixture(use_semantics: bool, lower_present: bool = true) -> Dictionary:
	var fixture := Node2D.new();fixture.position=Vector2(2200,0);world.add_child(fixture)
	var module := PlatformingModule.new();module.definition=load("res://resources/generation/modules/plains_ferry_channel.tres");module.authoring_debug=false;fixture.add_child(module)
	var landing := StaticBody2D.new();landing.position=Vector2(400,740)
	var shape := CollisionShape2D.new();var box := RectangleShape2D.new();box.size=Vector2(400,24);shape.shape=box;landing.add_child(shape)
	if lower_present: fixture.add_child(landing)
	else: landing.free()
	var body: PlayerMotor=preload("res://scenes/player/player.tscn").instantiate();body.position=Vector2(400,390);fixture.add_child(body)
	var target := body.get_node("Controller") as PlayerController
	body.get_node("KeyboardMouseAdapter").process_mode=Node.PROCESS_MODE_DISABLED
	var damage := FrameDamagePolicy.new();damage.lifetime=DemoLifetime.new();damage.register_target(&"player",target.actor_resources.health,true);fixture.add_child(damage)
	var records := module.world_static_hazard_records()
	check(records.size()==1 and records[0].role=="fall_plane","actual ferry channel bottom sensor classified by unattached bottom-band geometry")
	check(records[0].rect==module.world_static_dangers()[0],"record world rect and order preserve original collision API")
	var record: Dictionary=records[0]
	var emitter := DemoContactEmitter.new();emitter.controller=target;emitter.policy=damage;emitter.kind=DamageRequest.Kind.ENVIRONMENT;emitter.source_id=&"actual_ferry_channel_pit_plane"
	emitter.half_size=(record.rect as Rect2).size*.5;emitter.fall_plane=use_semantics;fixture.add_child(emitter);emitter.global_position=(record.rect as Rect2).get_center()
	var damage_sources: Array[String]=[]
	damage.batch_resolved.connect(func(batch: Array[DamageResult]) -> void:
		for hit: DamageResult in batch: damage_sources.append(String(hit.request.source_id)))
	for i: int in 75: await physics_frame;await process_frame
	var output := {"new_semantics":use_semantics,"lower_present":lower_present,"health":target.actor_resources.health.current,"position":body.position,"on_floor":body.is_on_floor(),"actual_sources":damage_sources,"role":record.role,"rect":record.rect}
	fixture.queue_free();await process_frame;await process_frame
	return output

func wall_knockback_fixture() -> void:
	floor_at(Vector2(1650,400),Vector2(400,40))
	floor_at(Vector2(1640,320),Vector2(20,120))
	var body: PlayerMotor=preload("res://scenes/player/player.tscn").instantiate();body.position=Vector2(1600,362);world.add_child(body)
	body.get_node("KeyboardMouseAdapter").process_mode=Node.PROCESS_MODE_DISABLED
	for i: int in 4: await physics_frame;await process_frame
	var before := body.position
	body.accept_damage_knockback(Vector2.RIGHT)
	check(body.position==before,"wall fixture force does not teleport at request")
	for i: int in 8: await physics_frame;await process_frame
	check(body.position.x<=1618.1 and body.position.x>before.x,"actual collision stops hit force against wall")
	check(body.damage_velocity.x==0,"wall projects persistent damage velocity")
	body.reset_motion()
	check(body.damage_remaining==0 and body.damage_velocity==Vector2.ZERO,"existing reset_motion clears independent hit channel")
	body.queue_free();await process_frame

func real_enemy_projectile_fixture() -> void:
	var enemy: EnemyMotor=preload("res://scenes/enemies/patrol_drone.tscn").instantiate()
	enemy.position=motor.position+Vector2(110,0)
	var old := enemy.get_node("Presentation");enemy.remove_child(old);old.free()
	var actor := enemy.get_node("Actor") as EnemyActor
	var presentation := UnderworldEnemy.new();presentation.actor=actor;enemy.add_child(presentation)
	world.add_child(enemy)
	check(policy.bind_damageable(&"r3_actual_enemy",actor.damageable,actor.health),"actual enemy bound to batched policy")
	var accepted_hits: Array[Dictionary]=[]
	actor.damageable.damaged.connect(func(context: Dictionary) -> void: accepted_hits.append(context))
	await settle_audio_voices()
	var enemy_audio_before := int(audio.played.get(&"hurt",0))
	controller.router.aim_direction=Vector2.RIGHT
	controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(20,"actual_player_projectile_enemy_hit")
	check(actor.health.current==actor.health.capacity-1,"real Router/Shoot/projectile commits one enemy HP")
	check(accepted_hits.size()==1 and presentation.accepted_hurt_count==1,"committed batched hit emits one actual enemy hurt")
	check(not accepted_hits.is_empty() and (accepted_hits[0].get("hit_direction",Vector2.ZERO) as Vector2).x>.9,"actual projectile direction preserved through damage sink")
	check(presentation._hurt>0,"ordinary enemy renders bounded hurt animation after actual projectile")
	check(int(audio.played.get(&"hurt",0))==enemy_audio_before+1,"real ordinary enemy accepted hit emits exactly one hurt audio")
	if not accepted_hits.is_empty():
		check(not actor.damageable.receive_damage(accepted_hits[0]),"actual projectile event replay refused")
	var count := presentation.accepted_hurt_count
	await ticks(2,"enemy_replay_rejected")
	check(presentation.accepted_hurt_count==count,"enemy event replay cannot retrigger hurt")
	check(int(audio.played.get(&"hurt",0))==enemy_audio_before+1,"enemy hit replay cannot emit second hurt audio")
	enemy.queue_free();await process_frame

func settle_audio_voices() -> void:
	# Fixed-fps may simulate seconds before AudioServer's independent mix thread
	# has played a voice. Wait on actual bounded voice release, never waive cues.
	var deadline := Time.get_ticks_msec()+2500
	while audio._voices.any(func(voice: AudioStreamPlayer) -> bool:return voice.playing) and Time.get_ticks_msec()<deadline:
		await process_frame
	check(not audio._voices.any(func(voice: AudioStreamPlayer) -> bool:return voice.playing),"actual audio voice pool drained within bounded mix-thread wait")

func actual_module_hurt_fixture(path: String, is_gear: bool) -> Dictionary:
	var fixture := Node2D.new();fixture.position=Vector2(5000,0);world.add_child(fixture)
	var module := PlatformingModule.new();module.definition=load(path);module.authoring_debug=false;fixture.add_child(module)
	var body: PlayerMotor=preload("res://scenes/player/player.tscn").instantiate();body.position=module.definition.entry_port.position;fixture.add_child(body)
	var target := body.get_node("Controller") as PlayerController
	body.get_node("KeyboardMouseAdapter").process_mode=Node.PROCESS_MODE_DISABLED
	body.get_node("PlayerVisualAdapter").process_mode=Node.PROCESS_MODE_DISABLED
	body.get_node("CourierVisual").hide();body.get_node("PlayerFeedback").hide()
	var visual := UnderworldPlayer.new();visual.motor=body;visual.controller=target;body.add_child(visual)
	var damage := FrameDamagePolicy.new();damage.lifetime=DemoLifetime.new();fixture.add_child(damage)
	damage.register_target(&"player",target.actor_resources.health,true);damage.register_player_controller(target)
	var respawn := SegmentRespawn.new();respawn.configure(target,damage.lifetime)
	respawn.add_anchor(&"actual_module_entry",module.world_entry())
	var accepted: Array[Dictionary]=[]
	var frames: Array[Dictionary]=[]
	var entry_exit: Array[Dictionary]=[]
	var source_roles: Dictionary={}
	if is_gear: module.setup_damage(target,damage,damage.lifetime)
	else:
		for record: Dictionary in module.world_static_hazard_records():
			var emitter := DemoContactEmitter.new();emitter.controller=target;emitter.policy=damage;emitter.source_id=StringName(record.authored_id);emitter.kind=DamageRequest.Kind.ENVIRONMENT;emitter.half_size=(record.rect as Rect2).size*.5
			fixture.add_child(emitter);emitter.global_position=(record.rect as Rect2).get_center();source_roles[String(emitter.source_id)]=record
	damage.environment_return_requested.connect(func() -> void:
		var echoes: Array[Node]=fixture.get_children().filter(func(node: Node) -> bool:return node is DamageReturnEcho)
		# Echo is created by the segment_returned signal below, not before return.
		if respawn.return_to_anchor():
			damage.protect_player()
			echoes=fixture.get_children().filter(func(node: Node) -> bool:return node is DamageReturnEcho)
			entry_exit.append({"safe_entry":body.global_position,"old_exit":(echoes[0] as DamageReturnEcho).global_position if not echoes.is_empty() else Vector2.ZERO,"entry_fade":visual._return_fade_remaining,"hurt":visual._hurt_remaining}))
	damage.batch_resolved.connect(func(batch: Array[DamageResult]) -> void:
		for result: DamageResult in batch:
			accepted.append({"source_id":String(result.request.source_id),"authored_id":String(module.definition.saws[0].source_id) if is_gear else String(result.request.source_id),"module_id":String(module.definition.module_id),"stage_epoch":result.request.token.stage_epoch,"actor_epoch":result.request.actor_epoch,"hit_direction":result.request.hit_direction,"HP":result.health.current}))
	for i: int in 4: await physics_frame;await process_frame
	check(respawn.activate_anchor(&"actual_module_entry"),"real module entry anchor validates before "+("gear" if is_gear else "thorn"))
	await settle_audio_voices()
	var audio_before := int(audio.played.get(&"hurt",0))
	target.router.set_move_axis(1)
	for i: int in 80:
		await physics_frame;await process_frame
		frames.append({"tick":Engine.get_physics_frames(),"position":body.global_position,"animation":visual.animation_receipt(),"HP":target.actor_resources.health.current})
	check(accepted.size()==1 and target.actor_resources.health.current==4,"actual "+("gear" if is_gear else "attached thorn")+" accepts one environment hit")
	check(int(audio.played.get(&"hurt",0))==audio_before+1,"actual module environment emits one hurt audio cue")
	check(entry_exit.size()==1 and (entry_exit[0].old_exit as Vector2).distance_to(entry_exit[0].safe_entry)>10 and entry_exit[0].entry_fade>0,"actual module environment has distinct exit and bounded entry fade")
	check(visual.return_echo_count==1 and visual._return_fade_remaining==0 and visual.animation_state!="hurt","actual module hurt completes transition without replay")
	var result := {"module":String(module.definition.module_id),"events":accepted,"entry_exit":entry_exit,"frames":frames}
	fixture.queue_free();await process_frame;await process_frame
	return result

func hurt_shoot_order_fixture(order: String) -> Dictionary:
	var fixture := Node2D.new();fixture.position=Vector2(7000,0);world.add_child(fixture)
	var landing := StaticBody2D.new();landing.position=Vector2(300,400)
	var shape := CollisionShape2D.new();var box := RectangleShape2D.new();box.size=Vector2(1000,40);shape.shape=box;landing.add_child(shape);fixture.add_child(landing)
	var body: PlayerMotor=preload("res://scenes/player/player.tscn").instantiate();body.position=Vector2(200,362);fixture.add_child(body)
	var target := body.get_node("Controller") as PlayerController
	target.set_physics_process(false);body.get_node("KeyboardMouseAdapter").process_mode=Node.PROCESS_MODE_DISABLED
	var damage := FrameDamagePolicy.new();damage.lifetime=DemoLifetime.new();damage.register_target(&"player",target.actor_resources.health,true);damage.register_player_controller(target)
	var shots: Array[Dictionary]=[]
	target.shoot_ability.shot_fired.connect(func(direction: Vector2, id: int) -> void:shots.append({"direction":direction,"id":id,"damage_remaining":body.damage_remaining,"cooldown":target.shoot_ability.cooldown_remaining}))
	for i: int in 4:
		await physics_frame;target.physics_tick(1.0/60);await process_frame
	check(body.is_on_floor(),"hurt-fire order fixture starts on actual floor "+order)
	var hit := DamageRequest.new();hit.token=damage.lifetime.token();hit.actor_epoch=damage.lifetime.actor_epoch;hit.health_epoch=target.actor_resources.health.epoch;hit.event_id=StringName(order);hit.source_id=&"order_monster";hit.target_id=&"player";hit.hit_direction=Vector2.RIGHT
	if order=="shoot_before_hit":
		target.router.request_action(&"shoot_release",Vector2.LEFT)
		await physics_frame;target.physics_tick(1.0/60);await process_frame
	check(damage.submit(hit),"order monster request accepted "+order);damage.resolve_batch()
	if order=="mid_hurt_fresh_shot":
		for i: int in 5:
			await physics_frame;target.physics_tick(1.0/60);await process_frame
	if order!="shoot_before_hit": target.router.request_action(&"shoot_release",Vector2.LEFT)
	await physics_frame;target.physics_tick(1.0/60);await process_frame
	check(shots.size()==1 and target.shoot_ability.cooldown_remaining>0,"hurt preserves one legal shot and original cooldown "+order)
	check(body.recoil_burst_remaining==0 and body.damage_remaining>0 and body.normal_velocity.y>0,"hurt owns motion without burst gravity freeze "+order)
	var count := shots.size()
	check(not damage.submit(hit),"same order hit replay cannot refresh force "+order)
	for i: int in 25:
		await physics_frame;target.physics_tick(1.0/60);await process_frame
	check(body.damage_remaining==0 and body.recoil_burst_remaining==0 and shots.size()==count,"hurt exits without delayed gun burst or auto-shot "+order)
	target.router.request_action(&"shoot_release",Vector2.LEFT)
	await physics_frame;target.physics_tick(1.0/60);await process_frame
	check(shots.size()==2 and body.recoil_burst_remaining>0 and body.recoil_velocity.x>0,"after hurt fresh shot retains normal opposite-direction recoil "+order)
	var output := {"order":order,"HP":target.actor_resources.health.current,"shots":shots,"normal_velocity":body.normal_velocity,"recoil":body.recoil_velocity}
	damage.free();fixture.queue_free();await process_frame;await process_frame
	return output

func run() -> void:
	world=Node2D.new();root.add_child(world)
	audio=GameAudio.new();world.add_child(audio)
	floor_at(Vector2(500,400),Vector2(1600,40))
	motor=preload("res://scenes/player/player.tscn").instantiate();motor.position=Vector2(200,362);world.add_child(motor)
	controller=motor.get_node("Controller")
	motor.get_node("KeyboardMouseAdapter").process_mode=Node.PROCESS_MODE_DISABLED
	motor.get_node("PlayerVisualAdapter").process_mode=Node.PROCESS_MODE_DISABLED
	motor.get_node("CourierVisual").hide();motor.get_node("PlayerFeedback").hide()
	art=UnderworldPlayer.new();art.motor=motor;art.controller=controller;motor.add_child(art)
	policy=FrameDamagePolicy.new();policy.lifetime=DemoLifetime.new();world.add_child(policy)
	policy.register_target(&"player",controller.actor_resources.health,true);policy.register_player_controller(controller)
	await ticks(20,"supported_idle")
	check(motor.is_on_floor(),"real collider supports player")
	var before := motor.position
	var applied := request(&"real_monster_fixture",DamageRequest.Kind.MONSTER)
	check(policy.submit(applied),"valid monster accepted into batch")
	policy.resolve_batch()
	check(motor.position==before,"damage queues force without moving outside Motor")
	check(motor.damage_remaining>0 and motor.damage_velocity.x>0,"committed hit queues away-from-source force")
	check(int(audio.played.get(&"hurt",0))==1,"hidden original effects consumer still plays exactly one hurt cue")
	await ticks(2,"monster_hurt_start")
	check(motor.position.x>before.x and motor.position.y<before.y,"actual Motor swept knockback displaces away and up")
	check(art.animation_state=="hurt" and art._damage_flash_remaining>0,"generated hurt clip outranks locomotion and flashes")
	var accepted := art._accepted_hurt_count
	check(not policy.submit(applied),"duplicate damage refused")
	check(not policy.submit(request(&"iframe",DamageRequest.Kind.MONSTER)),"monster iframe refuses next attack")
	var stale := request(&"stale",DamageRequest.Kind.ENVIRONMENT);stale.actor_epoch-=1
	check(not policy.submit(stale),"stale actor environment refused")
	var invalid := request(&"nan_direction",DamageRequest.Kind.MONSTER,Vector2(NAN,0))
	check(not policy.submit(invalid),"nonfinite direction refused")
	check(art._accepted_hurt_count==accepted and int(audio.played.get(&"hurt",0))==1,"all rejected requests create no new feedback/audio")
	var frozen := motor.damage_remaining
	var frozen_pose := art.animation_receipt()
	paused=true
	for i: int in 8: await process_frame
	check(motor.damage_remaining==frozen and art.animation_receipt().state_age==frozen_pose.state_age,"pause freezes hit force and actual animation")
	paused=false
	await ticks(45,"hurt_exit")
	check(motor.damage_remaining==0 and art._hurt_remaining==0 and art.animation_state!="hurt","bounded force and hurt animation exit into actual locomotion")
	# Real environmental sweep, HP commit and selective return all run in the
	# production physics priority order; no test calls the hurt callback directly.
	var respawn := SegmentRespawn.new();respawn.configure(controller,policy.lifetime)
	respawn.add_anchor(&"fixture_safe",Vector2(200,362));check(respawn.activate_anchor(&"fixture_safe"),"safe anchor validates full body and three supports")
	var origin := motor.position+Vector2(44,0)
	var emitter := DemoContactEmitter.new();emitter.position=origin;emitter.policy=policy;emitter.controller=controller;emitter.source_id=&"r3_thorn_contact";emitter.kind=DamageRequest.Kind.ENVIRONMENT;emitter.half_size=Vector2(5,18);world.add_child(emitter)
	var returns := [0]
	var return_entry: Array[Dictionary]=[]
	controller.segment_returned.connect(func() -> void:
		var echoes: Array[Node]=world.get_children().filter(func(node: Node) -> bool:return node is DamageReturnEcho)
		return_entry.append({"echoes":echoes.size(),"entry":motor.global_position,"exit":(echoes[0] as DamageReturnEcho).global_position if not echoes.is_empty() else Vector2.ZERO,"fade":art._return_fade_remaining,"hurt":art._hurt_remaining}))
	policy.environment_return_requested.connect(func() -> void:
		if respawn.return_to_anchor(): policy.protect_player();returns[0]+=1)
	controller.router.set_move_axis(1)
	await ticks(18,"real_environment_contact")
	controller.router.set_move_axis(0)
	check(returns[0]==1,"actual swept thorn contact returns exactly once")
	check(art.return_echo_count==1,"accepted environment preserves one old-point exit silhouette")
	check(return_entry.size()==1 and return_entry[0].echoes==1 and (return_entry[0].exit as Vector2).distance_to(return_entry[0].entry)>20,"old world exit and accepted safe entry are distinct actual positions")
	check(return_entry.size()==1 and return_entry[0].fade>0 and return_entry[0].hurt>0,"safe entry begins bounded fade while retaining hurt clip")
	check(controller.actor_resources.health.current==3,"monster plus thorn each cost exactly one HP")
	check(motor.damage_remaining==0,"environment return clears knockback channel")
	check(policy.lifetime.actor_epoch==2,"environment return advances actor epoch")
	check(int(audio.played.get(&"hurt",0))==2,"environment feedback adds exactly one cue without replay")
	await ticks(45,"environment_recover_exit")
	check(art.animation_state!="hurt" and art._return_fade_remaining==0,"safe-spawn entry and hurt exit finish")
	emitter.queue_free()
	# A wrong framing rectangle is not a kill volume. Existing implementation
	# would reject all these points with bounds.grow(100).has_point().
	check(not DamageBoundary.should_return(motor,Rect2(800,100,10,10)),"offside framing edge cannot damage a supported actor")
	check(not DamageBoundary.should_return(motor,Rect2(-100,-900,1000,100)),"lower real floor outside recorded bounds cannot cause false return")
	var lower_floor := floor_at(Vector2(200,1100),Vector2(180,20))
	var probe: PlayerMotor=preload("res://scenes/player/player.tscn").instantiate();probe.position=Vector2(200,850);world.add_child(probe)
	(probe.get_node("Controller") as PlayerController).set_physics_process(false)
	await physics_frame;await physics_frame
	check(not DamageBoundary.should_return(probe,Rect2(0,0,600,500)),"airborne above actual lower landing outside manifest is protected")
	lower_floor.queue_free();await physics_frame;await physics_frame
	check(DamageBoundary.should_return(probe,Rect2(0,0,600,500)),"true bottomless fall below full body boundary returns")
	probe.queue_free()
	var hurt_shoot_orders: Array[Dictionary]=[]
	for order: String in ["shoot_before_hit","hit_before_shoot","mid_hurt_fresh_shot"]: hurt_shoot_orders.append(await hurt_shoot_order_fixture(order))
	var actual_gear := await actual_module_hurt_fixture("res://resources/generation/modules/plains_gear_hop.tres",true)
	var actual_surface := await actual_module_hurt_fixture("res://resources/generation/modules/plains_thorn_slalom.tres",false)
	await wall_knockback_fixture()
	await real_enemy_projectile_fixture()
	var old_lower := await lower_route_fixture(false)
	var fixed_lower := await lower_route_fixture(true)
	var true_pit := await lower_route_fixture(true,false)
	check(old_lower.health==4 and old_lower.on_floor and old_lower.actual_sources==["actual_ferry_channel_pit_plane"],"old sensor reproduces false damage despite actual reachable lower landing")
	check(fixed_lower.health==5 and fixed_lower.on_floor and fixed_lower.actual_sources.is_empty(),"new sensor actually falls through onto same lower floor without damage")
	check(true_pit.health==4 and not true_pit.on_floor and true_pit.actual_sources==["actual_ferry_channel_pit_plane"],"same new pit sensor retains actual damage without lower landing")
	var surface_definition := load("res://resources/generation/modules/plains_thorn_slalom.tres") as PlatformingModuleDefinition
	var surface_module := PlatformingModule.new();surface_module.definition=surface_definition
	world.add_child(surface_module)
	for record: Dictionary in surface_module.world_static_hazard_records(): check(record.role=="surface","authored surface thorns never become safe fall planes")
	surface_module.queue_free()
	for reversed: bool in [false,true]:
		var death_policy := FrameDamagePolicy.new();death_policy.lifetime=DemoLifetime.new()
		var health := HealthState.new();var definition := HealthDefinition.new();definition.resource_id=&"r3_fatal";definition.max_health=1;definition.initial_current=1
		check(health.configure(definition),"terminal fixture uses valid original health definition")
		check(death_policy.register_target(&"player",health,true),"terminal player registered")
		var boss_health := HealthState.new();check(boss_health.configure(definition),"terminal other target configured")
		check(death_policy.register_target(&"boss",boss_health),"terminal other target registered")
		var fatal_hit := DamageRequest.new();fatal_hit.token=death_policy.lifetime.token();fatal_hit.actor_epoch=death_policy.lifetime.actor_epoch;fatal_hit.health_epoch=health.epoch;fatal_hit.target_id=&"player";fatal_hit.source_id=&"fatal";fatal_hit.event_id=&"fatal"
		var callback_active: Array[bool]=[]
		fatal_hit.on_damage_applied=func() -> void:callback_active.append(death_policy.lifetime.active)
		var other_hit := fatal_hit.copy();other_hit.target_id=&"boss";other_hit.health_epoch=boss_health.epoch
		check(death_policy.submit(other_hit if reversed else fatal_hit),"first terminal transaction accepted")
		check(death_policy.submit(fatal_hit if reversed else other_hit),"second terminal transaction accepted")
		death_policy.resolve_batch()
		check(callback_active==[false,false],"committed damage observer runs after fatal lifetime invalidation")
		death_policy.free()
	# Same-frame arbitration and lethal priority use the unchanged original suite.
	await load("res://tests/damage_tests.gd").new().run(self,check)
	var enemy_edge_rows: Array[Dictionary]=await load("res://tests/underworld_plains/damage_enemy_edge_cases.gd").new().run(self,check)
	var response_owner_rows: Array[Dictionary]=await load("res://tests/underworld_plains/damage_response_ownership_cases.gd").new().run(self,check)
	var output := {"response_owner_cases":response_owner_rows,"enemy_edge_cases":enemy_edge_rows,"checks":checks,"failures":failures,"trace":rows,"old_lower_route":old_lower,"new_lower_route":fixed_lower,"true_pit":true_pit,"hurt_shoot_orders":hurt_shoot_orders,"actual_gear":actual_gear,"actual_surface":actual_surface,"return_entry":return_entry,"scope":"actual policy/contact/Motor fixture; not natural route, GPU or physical device"}
	DirAccess.make_dir_recursive_absolute("res://build/underworld_r3/damage")
	var file := FileAccess.open("res://build/underworld_r3/damage/runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(output,"\t"));file.close()
	await audio.shutdown();world.queue_free();await process_frame;await process_frame
	print("UNDERWORLD_DAMAGE_R3 checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
