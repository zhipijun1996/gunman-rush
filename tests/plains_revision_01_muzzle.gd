extends SceneTree
## Real physics-volume and FrameDamagePolicy regression fixtures. Initial
## placements and direct entered-attack callbacks isolate muzzle clearance;
## this is not an AI/combat/visual acceptance recording.
const PLAYER := preload("res://game/player/player.tscn")
const ORIGIN := Vector2(100,120)
var checks := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var world: Node2D
var audio: GameAudio
var player: PlayerMotor
var controller: PlayerController
var motor: EnemyMotor
var actor: EnemyActor
var behavior: EnemyAttackBehavior
var policy: FrameDamagePolicy
var life: DemoLifetime
var output := "res://build/plains_revision_01/muzzle/runtime.json"
var serial := 0

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ",label)

func sync_space() -> void:
	await physics_frame
	await process_frame

func solid(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	return body

func fresh(behavior_id: StringName = &"sentry", target := Vector2(500,120), first_wall := Rect2()) -> void:
	if is_instance_valid(world):
		check(await load("res://tests/audio_teardown.gd").drain_world(world),"previous physical fixture audio releases")
		world.free()
		await process_frame
	world = Node2D.new()
	world.set_meta("underworld_formal_style",true)
	root.add_child(world)
	if first_wall.has_area(): solid(first_wall)
	player = PLAYER.instantiate() as PlayerMotor
	player.position = target
	world.add_child(player)
	controller = player.get_node("Controller") as PlayerController
	controller.set_physics_process(false)
	player.get_node("KeyboardMouseAdapter").process_mode = Node.PROCESS_MODE_DISABLED
	motor = EnemyFactory.create_for_behavior(behavior_id)
	check(motor != null,"actual registered factory creates "+String(behavior_id))
	if motor == null: return
	motor.position = ORIGIN
	world.add_child(motor)
	actor = motor.get_node("Actor") as EnemyActor
	actor.set_physics_process(false)
	life = DemoLifetime.new()
	policy = FrameDamagePolicy.new()
	policy.lifetime = life
	world.add_child(policy)
	policy.set_physics_process(false)
	policy.register_player_controller(controller)
	check(policy.register_target(&"player",controller.actor_resources.health,true),"real player health joins unchanged FrameDamagePolicy")
	actor.bind_encounter(controller,policy,life,&"muzzle-regression",[])
	behavior = actor.attack_behavior
	check(behavior != null,"actual actor binds registered attack behavior")
	await sync_space()

func fire(aim: Vector2 = Vector2.RIGHT) -> Array[EnemyAttackProjectile]:
	behavior.locked_direction = aim.normalized()
	actor.brain.direction = -1 if aim.x<0.0 else 1
	behavior._fire()
	var shots: Array[EnemyAttackProjectile] = []
	for shot: EnemyAttackProjectile in behavior._projectiles:
		if is_instance_valid(shot):
			shot.set_physics_process(false)
			shots.append(shot)
	return shots

func manual_seed() -> EnemyAttackProjectile:
	serial += 1
	var shot := EnemyAttackProjectile.new()
	shot.configure(behavior,StringName("manual-muzzle/%d"%serial),Vector2.RIGHT)
	world.add_child(shot)
	shot.global_position = ORIGIN
	shot.set_physics_process(false)
	return shot

func mouth() -> Vector2:
	var pivot := actor.definition.projectile_muzzle_pivot
	return ORIGIN+Vector2(pivot.x*actor.brain.direction,pivot.y)+behavior.locked_direction.normalized()*actor.definition.projectile_muzzle_reach

func impact_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for child: Node in world.get_children():
		if child is UnderworldProjectileVisual and (child as UnderworldProjectileVisual).impact:
			points.append((child as UnderworldProjectileVisual).global_position)
	return points

func record(id: String, before: int, extra: Dictionary = {}) -> void:
	var row := {"id":id,"passed":failures.size()==before}
	row.merge(extra)
	cases.append(row)

func definitions() -> void:
	var before := failures.size()
	var sentry := EnemyFactory.definition_for_behavior(&"sentry")
	check(sentry.definition_version==3 and sentry.projectile_muzzle_pivot==Vector2(8,-12) and sentry.projectile_muzzle_reach==12.0,"sentry Definition is the sole configured muzzle source")
	for id: StringName in [&"patrol",&"charger",&"diver",&"hopper",&"fan_sentry",&"root_bell",&"forest_lantern",&"forest_seed_sentry",&"forest_bark_beetle",&"forest_swing_pod",&"forest_thread_spider",&"forest_crossbranch",&"forest_bible_weaver"]:
		var definition := EnemyFactory.definition_for_behavior(id)
		check(definition != null and definition.projectile_muzzle_pivot==Vector2.ZERO and definition.projectile_muzzle_reach==0.0,String(id)+" retains zero-offset old projectile origin")
	var invalid := sentry.duplicate(true) as EnemyDefinition
	invalid.projectile_muzzle_pivot = Vector2(NAN,0)
	check(not invalid.is_valid(),"nonfinite muzzle pivot refused")
	invalid = sentry.duplicate(true) as EnemyDefinition
	invalid.projectile_muzzle_reach = -1.0
	check(not invalid.is_valid(),"negative muzzle reach refused")
	invalid.projectile_muzzle_reach = INF
	check(not invalid.is_valid(),"nonfinite muzzle reach refused")
	record("definition_contract_and_legacy_defaults",before)

func aim_and_clocks() -> void:
	for aim: Vector2 in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,-1).normalized(),Vector2(-1,1).normalized()]:
		await fresh()
		var before := failures.size()
		var shots := fire(aim)
		check(shots.size()==1,"sentry emits exactly one real seed")
		if shots.size()==1:
			var shot := shots[0]
			var expected := mouth()
			check(not shot.spent and shot.global_position.is_equal_approx(expected),"clear muzzle uses mirrored pivot and original locked aim "+str(aim))
			check(shot.direction.is_equal_approx(aim),"muzzle position never retargets locked direction "+str(aim))
			check(shot.radius==4.0 and shot.speed==actor.definition.projectile_speed and shot.remaining==actor.definition.projectile_lifetime,"placement preserves projectile radius, speed and full lifetime")
			check(shot._visual_age==0.0 and not shot._visual_launched and shot._visual_trail.is_empty(),"placement sweep does not advance flight/VFX clock or draw a center-to-mouth trail")
			check(policy.resolve_batch().is_empty(),"clear placement fabricates no player damage")
		record("locked_aim_"+str(aim),before)
	await fresh(&"fan_sentry")
	var before := failures.size()
	var fan := fire(Vector2.RIGHT)
	check(fan.size()==3,"zero-offset fan preserves three original seeds")
	for index: int in fan.size():
		check(not fan[index].spent and fan[index].global_position==ORIGIN,"zero offset has original center and no early placement query")
		check(fan[index].direction.is_equal_approx(Vector2.RIGHT.rotated([-.18,0.0,.18][index])),"fan's original locked spread remains unchanged")
	record("zero_offset_fan_original_spawn",before)

func blocked_launches() -> void:
	var obstacles := [Rect2(116,80,1,80),Rect2(99,119,2,2),Rect2(112,115,2,4)]
	var names := ["thin_wall_before_mouth","initial_circle_overlaps_solid","circle_radius_grazes_corner"]
	for index: int in obstacles.size():
		await fresh()
		var before := failures.size()
		solid(obstacles[index])
		await sync_space()
		if index==2:
			var ray := PhysicsRayQueryParameters2D.create(ORIGIN,mouth(),1,[motor.get_rid()])
			check(world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(),"corner counterexample really clears a center ray but intersects radius4")
		var shots := fire()
		check(shots.size()==1 and shots[0].spent,"real circle sweep refuses "+names[index])
		if shots.size()==1: check(shots[0].global_position==ORIGIN,"blocked seed cannot appear beyond solid "+names[index])
		check(policy.resolve_batch().is_empty(),"solid obstruction submits no player damage "+names[index])
		check(impact_points().size()==1,"solid creates exactly one actual contact effect "+names[index])
		record(names[index],before)

func close_player_and_occlusion() -> void:
	await fresh(&"sentry",Vector2(129,108))
	var before := failures.size()
	var hp := controller.actor_resources.health.current
	var shots := fire()
	var results := policy.resolve_batch()
	check(shots.size()==1 and shots[0].spent and results.size()==1 and controller.actor_resources.health.current==hp-1.0,"short launch interval cannot skip real nearby player; original Policy commits once")
	if results.size()==1:
		check(results[0].request.event_id==shots[0].event_id and results[0].request.hit_direction==Vector2.RIGHT and results[0].request.token.key()==life.token().key(),"short-interval contact retains actual seed ID, locked hit direction and token")
	var points := impact_points()
	check(points.size()==1 and points[0].x>ORIGIN.x and points[0].x<mouth().x-1.0,"player impact effect is at actual swept contact before muzzle, not at guessed mouth")
	if shots.size()==1:
		shots[0]._physics_process(.1)
		shots[0].launch_to_muzzle(mouth())
	check(policy.resolve_batch().is_empty() and controller.actor_resources.health.current==hp-1.0,"spent short-interval hit cannot resubmit damage")
	record("near_player_true_policy_contact",before)
	for wall_first: bool in [false,true]:
		var wall := Rect2(117,90,1,40)
		await fresh(&"sentry",Vector2(129,108),wall if wall_first else Rect2())
		before = failures.size()
		if not wall_first:
			solid(wall)
			await sync_space()
		hp = controller.actor_resources.health.current
		shots = fire()
		check(shots.size()==1 and shots[0].spent and policy.resolve_batch().is_empty() and controller.actor_resources.health.current==hp,"same-contact solid occludes player independent of body creation order "+str(wall_first))
		record("simultaneous_wall_player_"+str(wall_first),before)
	await fresh(&"sentry",Vector2(170,108))
	before = failures.size()
	hp = controller.actor_resources.health.current
	shots = fire()
	if shots.size()==1: shots[0]._physics_process(.4)
	results = policy.resolve_batch()
	check(shots.size()==1 and shots[0].spent and results.size()==1 and controller.actor_resources.health.current==hp-1.0,"ordinary flight after clear muzzle retains real swept-player Policy damage")
	record("ordinary_flight_after_clear_mouth",before)

func cancellation_guards() -> void:
	for reason: String in ["old_actor_epoch","ended_stage","dead_owner","protected_interval","invalid_destination"]:
		await fresh()
		var before := failures.size()
		var shot := manual_seed()
		var destination := ORIGIN+Vector2(20,-12)
		match reason:
			"old_actor_epoch": life.invalidate_actor()
			"ended_stage": life.end()
			"dead_owner": actor.health.apply_damage(ActorResourceRequest.new(&"muzzle-owner-death",actor.health.epoch,actor.health.capacity,actor.health.get_instance_id()))
			"protected_interval": behavior.protected_points.assign([ORIGIN+Vector2(10,-6)])
			"invalid_destination": destination = Vector2(NAN,0)
		check(not shot.launch_to_muzzle(destination) and shot.spent,"placement observes original cancellation/protection guard "+reason)
		check(shot.global_position==ORIGIN and shot._visual_age==0.0 and impact_points().is_empty() and policy.resolve_batch().is_empty(),"cancelled placement has no travel/contact/damage "+reason)
		record(reason,before)

func run() -> void:
	audio = GameAudio.new()
	root.add_child(audio)
	definitions()
	await aim_and_clocks()
	await blocked_launches()
	await close_player_and_occlusion()
	await cancellation_guards()
	if is_instance_valid(world):
		check(await load("res://tests/audio_teardown.gd").drain_world(world),"final physical fixture audio releases")
		world.free()
		await process_frame
	check(await audio.shutdown(),"owned GameAudio backend releases within original bound")
	audio.free()
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file==null:
		printerr("Cannot write muzzle regression evidence")
		quit(1)
		return
	file.store_string(JSON.stringify({"task":"PLAINS-MONSTER-REVISION-01","scope":"Real physics fixture/Policy muzzle clearance; not a natural AI route or visual approval","checks":checks,"failures":failures,"cases":cases},"\t"))
	file.close()
	print("PLAINS REVISION MUZZLE: checks=%d; failures=%d; cases=%d"%[checks,failures.size(),cases.size()])
	quit(0 if failures.is_empty() else 1)
