extends RefCounted
## Real accepted grapple and skill producers must keep their existing physical
## response owner. Explicit fixtures and manually ordered actual component ticks.
func run(tree: SceneTree, check: Callable) -> Array[Dictionary]:
	var reports: Array[Dictionary]=[]
	var dt := 1.0/60
	# Original moving-target hook contract, with real HP and receiver events.
	var world := Node2D.new();world.position=Vector2(11000,0);tree.root.add_child(world)
	var player: PlayerMotor=load("res://game/player/player.tscn").instantiate();player.position=Vector2(100,100);world.add_child(player)
	var controller := player.get_node("Controller") as PlayerController
	controller.set_physics_process(false);player.get_node("KeyboardMouseAdapter").process_mode=Node.PROCESS_MODE_DISABLED
	controller.air_focus_ability.enabled=false;controller.traversal.grant(&"grapple")
	var enemy: EnemyMotor=load("res://game/enemies/scenes/patrol_drone.tscn").instantiate();enemy.position=Vector2(280,100)
	var actor := enemy.get_node("Actor") as EnemyActor
	actor.definition=load("res://resources/enemies/patrol_drone.tres").duplicate(true)
	actor.definition.health_definition.max_health=100;actor.definition.health_definition.initial_current=100;actor.definition.patrol_half_width=1000
	world.add_child(enemy);actor.set_physics_process(false)
	var hits: Array[Dictionary]=[]
	actor.damageable.damaged.connect(func(context: Dictionary) -> void:hits.append(context.duplicate()))
	await tree.physics_frame;await tree.process_frame
	var start:=enemy.position
	controller.router.activate_device(&"gamepad");controller.router.request_action(&"grapple",Vector2.RIGHT)
	var moved_ticks:=0
	var kicked:=false
	var frames: Array[Dictionary]=[]
	for i: int in 70:
		await tree.physics_frame;controller.physics_tick(dt)
		if controller.traversal.state==&"hook_kick":kicked=true;break
		actor.physics_tick(dt);moved_ticks+=1
		frames.append({"tick":Engine.get_physics_frames(),"position":enemy.position,"state":String(controller.traversal.state),"ordinary_stun":actor._damage_stun_remaining,"ordinary_force":enemy._knockback})
		await tree.process_frame
	check.call(kicked and hits.size()==1,"actual moving grapple reaches one accepted hit and launch")
	check.call(not hits.is_empty() and hits[0].get("damage_type",&"")==&"grapple","actual grapple producer identifies its response owner")
	check.call(absf(enemy.position.x-start.x-actor.definition.patrol_speed*moved_ticks*dt)<.1,"actual grapple does not stop or displace original moving AI")
	check.call(actor._damage_stun_remaining==0 and enemy._knockback.is_zero_approx(),"grapple retains hurt event without generic motion force")
	reports.append({"kind":"grapple","hits":hits.size(),"moved_ticks":moved_ticks,"expected_x":start.x+actor.definition.patrol_speed*moved_ticks*dt,"actual_x":enemy.position.x,"frames":frames})
	world.queue_free();await tree.process_frame;await tree.process_frame
	# Exercise BOTH real skill damage producers: generated physical fan blades
	# (PlayerProjectile) and actual charged cannon ray (WeaponActionRuntime.hit).
	for weapon: String in ["blade_bloom","laser_cannon"]:
		world=Node2D.new();world.position=Vector2(11000,0);tree.root.add_child(world)
		var floor_body:=StaticBody2D.new();floor_body.position=Vector2(300,720)
		var collision:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(2000,40);collision.shape=box;floor_body.add_child(collision);world.add_child(floor_body)
		player=load("res://game/player/player.tscn").instantiate();player.position=Vector2(100,682);world.add_child(player)
		controller=player.get_node("Controller");controller.set_physics_process(false);player.get_node("KeyboardMouseAdapter").process_mode=Node.PROCESS_MODE_DISABLED;controller.air_focus_ability.enabled=false
		enemy=load("res://game/enemies/scenes/patrol_drone.tscn").instantiate();enemy.position=Vector2(250,684)
		actor=enemy.get_node("Actor");actor.definition=load("res://resources/enemies/plains_sentry.tres").duplicate(true);actor.definition.health_definition.max_health=100;actor.definition.health_definition.initial_current=100
		world.add_child(enemy);actor.set_physics_process(false)
		var policy:=FrameDamagePolicy.new();policy.lifetime=DemoLifetime.new();world.add_child(policy);policy.set_physics_process(false)
		check.call(policy.bind_damageable(&"ownership_skill",actor.damageable,actor.health),"actual skill target policy binds "+weapon)
		var skill_contexts: Array[Dictionary]=[]
		actor.damageable.damaged.connect(func(context: Dictionary) -> void:skill_contexts.append({"skill_attack":context.get("skill_attack",false),"damage_type":String(context.get("damage_type",&"")),"direction":context.get("hit_direction",Vector2.ZERO),"event_id":String(context.get("event_id",""))}))
		for i: int in 4:await tree.physics_frame;controller.physics_tick(dt);actor.physics_tick(dt);await tree.process_frame
		check.call(controller.shoot_ability.equip(load("res://resources/weapons/%s.tres" % weapon)),"actual skill equipment accepted "+weapon)
		var definition:=controller.shoot_ability.weapon
		# Explicit resource-boundary initialization, never claimed earned currency.
		controller.combat_energy.current=definition.skill_cost
		# Observation only: weak node handles avoid creating new signal ownership cycles.
		var observation := {"entry":_sample(controller,actor,policy),"emissions":[],"impacts":[],"exits":[],"packets":[],"rejections":[],"batches":[],"boundaries":[]}
		controller.shoot_ability.shot_fired.connect(_observe_shot.bind(weakref(controller),observation))
		controller.shoot_ability.shot_rejected.connect(func(reason):observation.rejections.append({"kind":"shot_rejected","reason":str(reason),"clock":_clock()}))
		controller.router.action_rejected.connect(func(reason):observation.rejections.append({"kind":"action_rejected","reason":str(reason),"clock":_clock()}))
		controller.shoot_ability.packet_changed.connect(func(value,packet):observation.packets.append({"state":str(value),"packet":packet,"clock":_clock()}))
		policy.batch_resolved.connect(func(batch: Array[DamageResult]) -> void:
			for result: DamageResult in batch:observation.batches.append({"event_id":str(result.request.event_id),"target":str(result.request.target_id),"amount":result.request.amount,"health":result.health.current,"clock":_clock()}))
		controller.router.activate_device(&"gamepad");controller.router.set_aim(&"gamepad",Vector2.RIGHT,false)
		observation.request_accepted=controller.router.request_action(&"weapon_skill",Vector2.RIGHT)
		var first_hit:=-1
		var first_finished:=-1
		var initial_stagger:=0.0
		var initial_force:=0.0
		var skill_frames: Array[Dictionary]=[]
		for i: int in 65:
			await tree.physics_frame
			var boundaries := {"row":i,"before_controller":_sample(controller,actor,policy)}
			controller.physics_tick(dt)
			boundaries.after_controller=_sample(controller,actor,policy)
			actor.physics_tick(dt);policy.resolve_batch()
			boundaries.after_resolve=_sample(controller,actor,policy)
			await tree.process_frame
			boundaries.after_process=_sample(controller,actor,policy)
			observation.boundaries.append(boundaries)
			if not skill_contexts.is_empty() and first_hit<0:
				first_hit=i;initial_stagger=actor._stagger_remaining;initial_force=enemy._knockback.length()
			if first_hit>=0 and first_finished<0 and actor._stagger_remaining<=0:first_finished=i
			skill_frames.append({"row":i,"HP":actor.health.current,"position":enemy.position,"ordinary_stun":actor._damage_stun_remaining,"skill_stagger":actor._stagger_remaining,"skill_cooldown":actor._stagger_cooldown,"force":enemy._knockback,"force_remaining":enemy._knockback_seconds})
		check.call(not skill_contexts.is_empty() and actor.health.current<100,"real skill commits actual batched HP "+weapon)
		check.call(skill_contexts.all(func(context: Dictionary) -> bool:return context.skill_attack==true),"real producer preserves explicit skill flag through policy "+weapon)
		check.call(skill_frames.all(func(frame: Dictionary) -> bool:return frame.ordinary_stun==0),"actual skill never acquires extra ordinary hurt stun "+weapon)
		check.call(absf(initial_stagger-definition.skill_stagger_seconds)<.0001,"first skill commit uses original authored stagger "+weapon)
		check.call(first_hit>=0 and first_finished>first_hit and first_finished-first_hit<=ceili(definition.skill_stagger_seconds/dt)+1,"skill stagger ends without extra ordinary .12 delay "+weapon)
		if weapon=="blade_bloom":check.call(absf(initial_force-definition.skill_knockback_speed)<.1,"physical fan skill keeps its authored force "+weapon)
		else:check.call(initial_force==0 and absf(enemy.position.x-250)<.1,"cannon retains original no-knockback skill response")
		reports.append({"kind":"skill","weapon":weapon,"contexts":skill_contexts,"first_hit":first_hit,"stagger_finished":first_finished,"initial_stagger":initial_stagger,"initial_force":initial_force,"frames":skill_frames,"observation":observation})
		world.queue_free();await tree.process_frame;await tree.process_frame
	return reports

# Passive snapshots only. No aim/pose repaint, query, movement or damage calls.
static func _clock() -> Dictionary:
	return {"physics":Engine.get_physics_frames(),"process":Engine.get_process_frames(),"time_scale":Engine.time_scale,"physics_hz":Engine.physics_ticks_per_second}

static func _projectile_sample(projectile: PlayerProjectile) -> Dictionary:
	return {"id":projectile.shot_id,"position":projectile.global_position,"direction":projectile.direction,"age":projectile._age,"launch_motion":projectile.launch_motion,"visual_launched":projectile._visual_launched,"spent":projectile.spent,"speed":projectile.speed,"radius":projectile.radius,"shape_radius":projectile._shape.radius,"lifetime":projectile.lifetime,"session":projectile.session_id,"weapon_epoch":projectile.weapon_epoch,"skill":projectile.skill_attack,"processing":projectile.is_physics_processing(),"clock":_clock()}

static func _sample(controller: PlayerController, actor: EnemyActor, policy: FrameDamagePolicy) -> Dictionary:
	var projectiles: Array[Dictionary]=[]
	for projectile: PlayerProjectile in controller.shoot_ability._projectiles:
		if is_instance_valid(projectile):projectiles.append(_projectile_sample(projectile))
	var visual := controller.motor.get_node("CourierVisual") as CourierVisual
	var runtime := controller.shoot_ability.runtime
	return {"clock":_clock(),"player":controller.motor.global_position,"player_velocity":controller.motor.velocity,"grounded":controller.motor.is_on_floor(),"controller_tick":controller._tick,"active":controller.active,"session":controller.session_id,"weapon_epoch":controller.shoot_ability.weapon_epoch,"packet":controller.shoot_ability.packet_id,"energy":controller.combat_energy.current,"phase":str(runtime.phase),"phase_age":runtime.age,"skill":runtime._skill,"direction":runtime.direction,"queue":policy._queue.size(),"policy_seen":policy._seen.size(),"enemy":actor.motor.global_position,"hp":actor.health.current,"visual_state":str(visual.state),"visual_elapsed":visual.elapsed,"facing":visual.facing,"body_transform":visual.body.global_transform,"muzzle":visual.visible_muzzle_position(),"aim":controller.router.aim_direction,"aim_engaged":controller.router.aim_engaged,"controller_automatic":controller.is_physics_processing(),"actor_automatic":actor.is_physics_processing(),"policy_automatic":policy.is_physics_processing(),"projectiles":projectiles}

static func _observe_shot(direction: Vector2, id: int, owner: WeakRef, observation: Dictionary) -> void:
	var controller := owner.get_ref() as PlayerController
	if controller==null:return
	for projectile: PlayerProjectile in controller.shoot_ability._projectiles:
		if not is_instance_valid(projectile) or projectile.shot_id!=id:continue
		observation.emissions.append({"direction":direction,"id":id,"last_muzzle":controller.shoot_ability.last_muzzle,"projectile":_projectile_sample(projectile)})
		projectile.impacted.connect(_observe_impact.bind(weakref(projectile),observation.impacts))
		projectile.tree_exiting.connect(_observe_exit.bind(weakref(projectile),observation.exits))

static func _observe_impact(point: Vector2, direction: Vector2, reference: WeakRef, events: Array) -> void:
	var projectile := reference.get_ref() as PlayerProjectile
	if projectile!=null:events.append({"point":point,"direction":direction,"projectile":_projectile_sample(projectile)})

static func _observe_exit(reference: WeakRef, events: Array) -> void:
	var projectile := reference.get_ref() as PlayerProjectile
	if projectile!=null:events.append(_projectile_sample(projectile))
