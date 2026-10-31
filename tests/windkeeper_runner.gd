extends SceneTree
var assertions := 0
var failures := 0
var world: Node2D
var player: PlayerMotor
var controller: PlayerController
var boss: BossMotor
var encounter: WindkeeperEncounter
var life: DemoLifetime
var policy: FrameDamagePolicy
var segment: SegmentRespawn
var arena_consumer: WindkeeperArena
var module: PlatformingModule
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for i: int in count: await physics_frame
func fixture(at: Vector2 = Vector2(350,582)) -> void:
	if is_instance_valid(world): world.free()
	world = Node2D.new()
	root.add_child(world)
	module = preload("res://game/world/generation/scenes/modules/plains_boss_arena.tscn").instantiate()
	world.add_child(module)
	player = preload("res://game/player/player.tscn").instantiate()
	player.position = at
	world.add_child(player)
	controller = player.get_node("Controller")
	player.tuning.max_jumps = 1
	life = DemoLifetime.new()
	policy = FrameDamagePolicy.new()
	policy.lifetime = life
	world.add_child(policy)
	policy.register_target(&"player", controller.actor_resources.health, true)
	policy.player_fatal.connect(controller.die)
	segment = SegmentRespawn.new()
	segment.configure(controller,life)
	segment.add_anchor(&"initial",at)
	policy.environment_return_requested.connect(func() -> void:
		encounter.cancel_pending_attacks()
		if segment.return_to_anchor(): policy.protect_player()
	)
	boss = preload("res://scenes/bosses/windkeeper.tscn").instantiate()
	boss.position = Vector2(560,535)
	world.add_child(boss)
	var contact := DemoContactEmitter.new()
	contact.policy = policy
	contact.controller = controller
	contact.source_id = &"sheep_body"
	contact.half_size = Vector2(72,62)
	boss.add_child(contact)
	encounter = boss.get_node("Encounter")
	encounter.configure_arena(125,995,player)
	arena_consumer = encounter.bind_stage_geometry(module,controller,policy,life,segment)
	policy.bind_damageable(&"boss", boss.get_node("Damageable"), encounter.health)
	encounter.projectile_created.connect(func(projectile: BossProjectile) -> void:
		projectile.hit.connect(func(body: Node2D,event: StringName, amount: float) -> void:
			if body != player or not life.active: return
			var request := DamageRequest.new()
			request.token = life.token()
			request.actor_epoch = life.actor_epoch
			request.health_epoch = controller.actor_resources.health.epoch
			request.target_id = &"player"
			request.source_id = &"windkeeper"
			request.event_id = event
			request.amount = amount
			policy.submit(request)
		)
	)
	await frames(3)
	check(encounter.activate(), "actual Windkeeper activates in configured arena")
func shoot_core() -> void:
	var before := encounter.health.current
	var aim := boss.global_position + encounter.core_offset() - player.global_position
	check(controller.shoot_ability.try_fire(aim,player.is_on_floor()), "actual projectile can fire toward exposed core")
	await frames(25)
	check(encounter.health.current == before - 1, "actual projectile hits phase-specific core exactly once")
func run() -> void:
	await fixture()
	check(encounter.health.capacity == 12 and encounter.stage_phase == 1, "configurable giant sheep has three-stage HP")
	encounter._enter(&"neck",3.8)
	await frames(2)
	await shoot_core()
	encounter._enter(&"observe",3)
	await frames(20)
	var hp := encounter.health.current
	check(controller.shoot_ability.try_fire(Vector2(1,-.2),true), "closed-body shot fires normally")
	await frames(25)
	check(encounter.health.current == hp, "closed wool is not an exposed core")
	# Stomp is a real horizontal shape-swept attack. Baseline ground contact hits.
	await fixture(Vector2(390,582))
	encounter._enter(&"stomp_warning",0.01)
	await frames(100)
	check(controller.actor_resources.health.current < controller.actor_resources.health.capacity, "grounded character is hit by actual stomp wave")
	# One held jump evades the identical wave without altering physics.
	await fixture(Vector2(390,582))
	encounter._enter(&"stomp_warning",0.01)
	controller.router.set_jump_held(&"test",true)
	await frames(70)
	check(controller.actor_resources.health.current == controller.actor_resources.health.capacity, "one held jump safely clears actual stomp wave")
	check(controller.jump_ability.used_jumps <= 1, "stomp dodge never assumes double jump")
	# Charge pattern genuinely moves and exposes the neck after embedding.
	await fixture(Vector2(300,582))
	encounter._stomp_next = false
	encounter._enter(&"observe",0.01)
	await frames(150)
	check(encounter.mode == &"neck" and encounter.core_open, "charge ends at slope with exposed neck window")
	check(boss.position.x < 560, "charge has actual horizontal displacement")
	# Real jump + recoil changes sides during a committed charge.
	await fixture(Vector2(390,582))
	encounter.direction = -1
	encounter._enter(&"charge_warning",1.1)
	await frames(40)
	controller.router.set_move_axis(1)
	controller.router.set_jump_held(&"swap",true)
	await frames(14)
	check(controller.shoot_ability.try_fire(Vector2.LEFT,false), "air shot supplies real charge-side swap recoil")
	await frames(65)
	controller.router.set_move_axis(0)
	check(player.position.x > boss.position.x + 84, "actual jump/recoil crosses behind committed charge")
	check(controller.actor_resources.health.current == controller.actor_resources.health.capacity, "recoil side swap avoids giant body contact")
	# Climb side steps using one-jump inputs then shoot the elevated back core.
	await fixture(Vector2(175,582))
	encounter.health.apply_damage(ActorResourceRequest.new(&"phase2_fixture",encounter.health.epoch,5,encounter.health.get_instance_id()))
	await frames(80)
	check(encounter.stage_phase == 2, "second HP threshold switches to distinct windmill pattern")
	encounter._enter(&"back",8)
	controller.router.set_move_axis(1)
	controller.router.set_jump_held(&"test",true)
	await frames(48)
	controller.router.set_move_axis(0)
	controller.router.set_jump_held(&"test",false)
	await frames(15)
	check(player.position.x >= 290 and player.position.x <= 470 and player.is_on_floor() and player.position.y < 470, "real one-jump trajectory reaches stable elevated side grass platform")
	await shoot_core()
	# Stable side shelf lies outside local blade/current volume.
	var safe_hp := controller.actor_resources.health.current
	encounter._enter(&"blades",3.4)
	await frames(205)
	check(controller.actor_resources.health.current == safe_hp, "stable grass shelf survives full wind blade sweep")
	check(encounter.mode == &"back", "windmill rotation leads to elevated back exposure")
	# Leaf middles, not only tips, sweep real player volume; current enters Motor.
	await fixture(Vector2(625,452))
	encounter.health.apply_damage(ActorResourceRequest.new(&"blade_fixture",encounter.health.epoch,5,encounter.health.get_instance_id()))
	await frames(80)
	encounter.blade_angle = 0
	encounter._enter(&"blades",3.4)
	var before_wind_x := player.position.x
	await frames(12)
	check(controller.actor_resources.health.current < controller.actor_resources.health.capacity, "rotating leaf midsection causes real policy damage")
	check(player.position.x > before_wind_x, "local current moves player through sole Motor step")
	encounter.cancel_pending_attacks()
	check(player._local_duration == 0 and player._local_velocity.is_zero_approx(), "cancellation clears pending local current")
	# Third phase is short segmented physical chase, not faster phase one.
	await fixture(Vector2(400,452))
	encounter.health.apply_damage(ActorResourceRequest.new(&"phase3_fixture",encounter.health.epoch,8,encounter.health.get_instance_id()))
	await frames(310)
	check(encounter.stage_phase == 3 and encounter.chase_segment == 0, "third threshold starts broken-bridge segment chase")
	encounter._enter(&"observe",0.01)
	await frames(210)
	check(encounter.mode == &"pier_open" and encounter.core_open, "chase ends at first real bridge pier exposure")
	check(absf(boss.position.x - (encounter.arena.left_x + 245)) < 3, "first chase uses bounded physical displacement to actual pier")
	# Cross the 80px broken gap in one jump; turn back shot supplies next landing recoil.
	controller.router.set_jump_held(&"test",true)
	controller.router.set_move_axis(1)
	await frames(38)
	controller.router.set_move_axis(0)
	controller.router.set_jump_held(&"test",false)
	var shot_hp := encounter.health.current
	var core_aim := boss.global_position + encounter.core_offset() - player.global_position
	check(controller.shoot_ability.try_fire(core_aim,false), "actual turn-back air shot triggers recoil over bridge gap")
	await frames(50)
	check(encounter.health.current == shot_hp - 1, "turn-back projectile hits exposed chase core")
	check(player.position.x > 550 and player.is_on_floor(), "one jump plus turn-back recoil reaches next safe bridge segment")
	check(controller.actor_resources.health.current == controller.actor_resources.health.capacity, "bridge trajectory remains no damage")
	# Third-stage holes are real, lower ground cannot bypass bridge routes.
	var ray := PhysicsRayQueryParameters2D.create(Vector2(510,500),Vector2(510,850),1,[player.get_rid()])
	check(player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(), "phaseIII bridge gap has no hidden lower floor")
	var saved_boss_hp := encounter.health.current
	var saved_epoch := life.actor_epoch
	controller.router.set_move_axis(-1)
	await frames(40)
	controller.router.set_move_axis(0)
	await frames(50)
	check(life.actor_epoch > saved_epoch and player.is_on_floor() and player.position.y < 470, "falling bridge gap performs actual selective return to safe bridge start")
	check(encounter.health.current == saved_boss_hp and encounter.stage_phase == 3 and arena_consumer.broken, "bridge fall keeps bossHP phase and broken geometry")
	# Full initial HP trace uses ordinary Motor inputs and actual projectiles only.
	await full_fight()
	# Cancel/pause never leaves delayed attacks or local current pending.
	encounter._wave(1)
	check(not encounter._projectiles.is_empty(), "real attack exists before cancellation")
	var previous_epoch := encounter.attack_epoch
	encounter.cancel_pending_attacks()
	check(encounter._projectiles.is_empty() and encounter.attack_epoch > previous_epoch and not encounter.core_open, "pause/segment cancellation invalidates old attacks and exposed window")
	var phase_before := encounter.stage_phase
	var boss_hp := encounter.health.current
	paused = true
	await process_frame
	await process_frame
	check(encounter.stage_phase == phase_before and encounter.health.current == boss_hp, "pause preserves health and stage")
	paused = false
	# Hundreds of actual lifecycle cycles retain bounded active projectiles.
	await fixture(Vector2(300,582))
	encounter.set_physics_process(false)
	for cycle: int in 120:
		encounter._wave(-1)
		for projectile: BossProjectile in encounter._projectiles: projectile.dispose()
		await frames(1)
		encounter._prune_attacks()
		check(encounter._projectiles.is_empty(), "disposed attack references pruned during long encounter")
	# Explicit restored phase fixture, on the same real unbroken Arena. No phase
	# signal is emitted: this exercises the owner entry used by App reload.
	paused = true
	check(encounter.stage_phase==1 and not arena_consumer.broken, "ordinary restore fixture retains its actual initial bridge")
	encounter.restore_stage_geometry(arena_consumer)
	await process_frame
	check(not arena_consumer.broken and module.get_node("Platform0").collision_layer==1, "ordinary non-third-phase restore leaves real ground intact")
	encounter.stage_phase = 3
	encounter.restore_stage_geometry(arena_consumer)
	check(not arena_consumer.broken, "ordinary restored bridge keeps the existing deferred removal boundary")
	await process_frame
	await process_frame
	check(arena_consumer.broken and module.get_node("Platform0").collision_layer==0, "ordinary third-phase owner restore removes the actual original ground")
	check(module.definition.platforms[0]==Rect2(0,600,290,80) and module.definition.platforms[-1]==Rect2(1000,600,120,80), "ordinary restored bridge preserves the original two ground remnants")
	paused = false
	world.free()
	await process_frame
	if "--failure-probe" in OS.get_cmdline_user_args(): check(false, "intentional Windkeeper failure probe")
	print("WINDKEEPER: %s assertions, %s failures" % [assertions,failures])
	quit(0 if failures == 0 else 1)

func full_fight() -> void:
	await fixture(Vector2(300,582))
	var visited := {1:true}
	var shots := 0
	var jump_armed := true
	for tick: int in 8000:
		if not visited.has(encounter.stage_phase): print("FIGHT PHASE ",encounter.stage_phase," at ",player.position," playerHP ",controller.actor_resources.health.current)
		visited[encounter.stage_phase] = true
		if encounter.health.terminal or controller.actor_resources.health.terminal: break
		var desired := (boss.position.x + (160 if player.position.x > boss.position.x else -160) if encounter.core_open else 300.0) if encounter.stage_phase == 1 else (620.0 if encounter.stage_phase == 2 else clampf(boss.position.x + 165,600,970))
		controller.router.set_move_axis(clampf((desired-player.position.x)/40,-1,1))
		if player.is_on_floor(): jump_armed = true
		if encounter.stage_phase == 1 and player.is_on_floor() and player.position.y < 550:
			controller.router.request_action(&"drop_through")
		var dodge := encounter.mode in [&"stomp_warning",&"charge_warning"] and encounter.clock < .3
		var climb := encounter.stage_phase >= 2 and (player.position.y > 500 or encounter.stage_phase == 3 and (440 < player.position.x and player.position.x < 480 or 700 < player.position.x and player.position.x < 740))
		if jump_armed and player.is_on_floor() and (dodge or climb):
			controller.router.set_jump_held(&"fight",true)
			jump_armed = false
		elif player.normal_velocity.y >= 0:
			controller.router.set_jump_held(&"fight",false)
		if encounter.core_open and controller.shoot_ability.cooldown_remaining <= 0 and (encounter.stage_phase != 1 or player.position.y > 510) and (encounter.stage_phase == 1 or player.is_on_floor() and player.position.y < 470) and (encounter.stage_phase == 1 or absf(player.position.x-desired) < 25):
			var aim := boss.global_position + encounter.core_offset() - player.global_position
			if controller.shoot_ability.try_fire(aim,player.is_on_floor()): shots += 1
		await frames(1)
	check(encounter.health.terminal, "full fight from initial12 HP ends through real core projectiles")
	check(visited.has(1) and visited.has(2) and visited.has(3), "full actual HP progression enters all three phases")
	check(controller.actor_resources.health.current > 0, "full actual fight completes while player is alive")
	check(shots >= 12, "full fight damage came from real emitted player bullets")
	check(not encounter.active and encounter._projectiles.is_empty(), "actual defeat cancels all enemy projectiles")
	print("WINDKEEPER FIGHT TRACE: shots=",shots," playerHP=",controller.actor_resources.health.current," bossHP=",encounter.health.current)
