extends SceneTree
## Actual collision entities and original FrameDamagePolicy, in explicit small
## layouts. The target is a real24x36 body at a disclosed initial position.
## No hit signal is forged and no player HP debit is used to manufacture hits.
## These fixtures do not claim natural fight, visual, listening or device review.
const TEARDOWN := preload("res://tests/audio_teardown.gd")
var assertions := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var world: Node2D
var boss: BossMotor
var encounter: WindkeeperEncounter
var target: CharacterBody2D
var target_health: HealthState
var policy: FrameDamagePolicy
var life: DemoLifetime
var actual_hits: Array[Dictionary] = []
var terrain: StaticBody2D
var serial := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func ticks(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func cleanup() -> void:
	if is_instance_valid(world):
		if is_instance_valid(encounter): encounter.cancel()
		check(await TEARDOWN.drain_world(world), "actual component audio/world drains")
		world.free()
	await ticks(2)

func make_terrain(bounds: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.position = bounds.get_center()
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = bounds.size
	collision.shape = rectangle
	body.add_child(collision)
	world.add_child(body)
	return body

func fixture(point: Vector2 = Vector2(400, 400)) -> bool:
	await cleanup()
	actual_hits.clear()
	world = Node2D.new()
	root.add_child(world)
	target = CharacterBody2D.new()
	target.collision_layer = 1
	target.collision_mask = 0
	target.position = point
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(24, 36)
	collision.shape = rectangle
	target.add_child(collision)
	world.add_child(target)
	check(target.get_node_or_null("CollisionShape2D") == collision, "fixture uses the actual canonical player collision-node contract")
	life = DemoLifetime.new()
	target_health = HealthState.new()
	var health_definition := HealthDefinition.new()
	health_definition.resource_id = &"windkeeper_pressure_test_target"
	health_definition.max_health = 5
	health_definition.initial_current = 5
	check(target_health.configure(health_definition), "explicit target starts original health transaction")
	policy = FrameDamagePolicy.new()
	policy.lifetime = life
	world.add_child(policy)
	check(policy.register_target(&"player", target_health, true), "real FramePolicy owns target HP")
	boss = BossFactory.create(&"windkeeper_storm")
	check(boss != null, "formal factory creates Windkeeper")
	if boss == null: return false
	boss.position = Vector2(100, 365)
	world.add_child(boss)
	encounter = boss.get_node("Encounter") as WindkeeperEncounter
	encounter.set_physics_process(false)
	await ticks(3)
	check(encounter.configure_arena(0, 900, target) and encounter.activate(), "real owner activates in bounded component arena")
	encounter.skip_intro()
	return encounter.active

func bind_actual_hit(shot: BossProjectile) -> void:
	shot.hit.connect(func(body: Node2D, event: StringName, amount: float) -> void:
		check(body == target, "collision entity emitted its actual configured target")
		var request := DamageRequest.new()
		request.token = life.token()
		request.actor_epoch = life.actor_epoch
		request.health_epoch = target_health.epoch
		request.target_id = &"player"
		request.source_id = &"actual_pressure_collision"
		request.event_id = event
		request.amount = amount
		request.hit_direction = shot.direction
		actual_hits.append({"event": String(event), "amount": amount, "direction": shot.direction, "admitted": policy.submit(request)})
	)

func strike(a: Vector2, b: Vector2, width: float = 12) -> WindkeeperPressureStrike:
	serial += 1
	var shot := WindkeeperPressureStrike.new()
	shot.configure(encounter.definition, StringName("pressure-strike-fixture-%s" % serial), Vector2.RIGHT, target, boss)
	shot.bind_attack(encounter, encounter.attack_epoch)
	shot.lifetime = 1.0
	world.add_child(shot)
	bind_actual_hit(shot)
	shot.set_segment(a, b, width)
	return shot

func projectile(at: Vector2, wave: bool = false) -> WindkeeperPressureProjectile:
	serial += 1
	var shot := WindkeeperPressureProjectile.new()
	shot.configure(encounter.definition, StringName("pressure-projectile-fixture-%s" % serial), Vector2.RIGHT, target, boss)
	shot.bind_attack(encounter, encounter.attack_epoch)
	shot.wave = wave
	shot.radius = 9 if wave else 7
	shot._shape.radius = shot.radius
	shot.speed = 300
	shot.lifetime = 2
	world.add_child(shot)
	shot.set_physics_process(false)
	shot.global_position = at
	bind_actual_hit(shot)
	return shot

func finish_observation(label: String) -> void:
	observations.append({"case": label, "HP": target_health.current, "actual_hits": actual_hits.duplicate(true), "attack_epoch": encounter.attack_epoch})

func strike_contact() -> void:
	if not await fixture(): return
	var shot := strike(Vector2(350, 400), Vector2(450, 400))
	shot.advance(1.0 / 60)
	await ticks(2)
	check(actual_hits.size() == 1 and target_health.current == 4, "actual blade middle capsule commits one HP through FramePolicy")
	check(bool(actual_hits[0].admitted) if not actual_hits.is_empty() else false, "collision hit is admitted by the unchanged policy")
	finish_observation("blade middle direct contact")

func strike_empty_corner() -> void:
	if not await fixture(Vector2(400, 440)): return
	var shot := strike(Vector2(350, 350), Vector2(450, 450))
	shot.advance(1.0 / 60)
	await ticks(2)
	check(actual_hits.is_empty() and target_health.current == 5, "empty diagonal AABB corner is not a real blade hit")
	finish_observation("diagonal broad-bounds negative")

func strike_swept_crossing() -> void:
	if not await fixture(): return
	var shot := strike(Vector2(300, 350), Vector2(500, 350))
	shot.set_segment(Vector2(300, 450), Vector2(500, 450), 12)
	shot.advance(1.0 / 60)
	await ticks(2)
	check(actual_hits.size() == 1 and target_health.current == 4, "actual continuous endpoint travel detects target between two clear endpoint poses")
	finish_observation("moving blade endpoint crossing")

func frozen_contact() -> void:
	if not await fixture(): return
	var shot := strike(Vector2(350, 400), Vector2(450, 400))
	var age := shot._visual_age
	var lifetime := shot.lifetime
	shot.advance_frozen_contact()
	check(shot.spent and shot._visual_age == age and shot.lifetime == lifetime, "frozen entry tests real contact without advancing animation or lifetime")
	shot.advance_frozen_contact()
	await ticks(2)
	check(actual_hits.size() == 1 and target_health.current == 4, "frozen reentry cannot emit duplicate physical hit")
	finish_observation("frozen real overlap once")

func frozen_old_path_negative() -> void:
	if not await fixture(): return
	var shot := strike(Vector2(300, 350), Vector2(500, 350))
	shot.set_segment(Vector2(300, 450), Vector2(500, 450), 12)
	# The actor lies along the previous moving sweep, but outside the current
	# held blade. Frozen sampling must not replay that past travel.
	var old_start := shot.previous_start
	var old_end := shot.previous_end
	var current_start := shot.start_world
	var current_end := shot.end_world
	var lifetime := shot.lifetime
	var age := shot._visual_age
	var location := shot.global_position
	shot.advance_frozen_contact()
	check(not shot.spent, "frozen current-clear blade is not consumed by its past swept path")
	check(shot.previous_start == old_start and shot.previous_end == old_end
		and shot.start_world == current_start and shot.end_world == current_end,
		"frozen sampling preserves every stored blade endpoint")
	check(shot.lifetime == lifetime and shot._visual_age == age and shot.global_position == location,
		"frozen negative advances neither lifetime, pose position nor visual age")
	await ticks(2)
	check(actual_hits.is_empty() and target_health.current == 5,
		"past blade crossing cannot damage the real actor during a world freeze")
	finish_observation("frozen current pose clear, past path crossing negative")

func cancelled_contact(terminal: bool) -> void:
	if not await fixture(): return
	var shot := strike(Vector2(350, 400), Vector2(450, 400))
	var old_epoch := encounter.attack_epoch
	if terminal:
		var request := ActorResourceRequest.new(&"explicit-owner-terminal-fixture", encounter.health.epoch, encounter.health.current, encounter.health.get_instance_id())
		check(encounter.health.apply_damage(request).accepted(), "explicit owner-terminal fixture uses authoritative health transaction")
	else:
		encounter.cancel_pending_attacks()
	shot.advance_frozen_contact()
	await ticks(2)
	check(actual_hits.is_empty() and target_health.current == 5, "cancelled or terminal owner cannot hurt despite current physical overlap")
	check(encounter.attack_epoch != old_epoch or not encounter.active or encounter.health.terminal, "owner admission changes before any late overlap sampling")
	finish_observation("terminal overlap negative" if terminal else "cancelled-epoch overlap negative")

func seed_contact(blocked: bool) -> void:
	if not await fixture(): return
	if blocked: make_terrain(Rect2(270, 200, 24, 400))
	await ticks(2)
	var shot := projectile(Vector2(150, 400))
	shot.advance(1.0)
	await ticks(2)
	if blocked:
		check(actual_hits.is_empty() and target_health.current == 5, "actual wall occludes full-speed wind seed before actor")
	else:
		check(actual_hits.size() == 1 and target_health.current == 4, "moving seed swept through actual actor enters FramePolicy once")
	finish_observation("wall occluded seed" if blocked else "actual seed contact")

func supported_wave(gap: bool) -> void:
	if not await fixture(Vector2(400, 412)): return
	make_terrain(Rect2(0, 430, 260 if gap else 900, 40))
	await ticks(2)
	var shot := projectile(Vector2(150, 420), true)
	# Small ordinary steps test the support branch along the true travel path.
	for index: int in 70:
		if not is_instance_valid(shot) or shot.spent: break
		shot.advance(1.0 / 60)
		await ticks(1)
	if gap:
		check(actual_hits.is_empty() and target_health.current == 5, "ground wave ends at real unsupported gap and cannot hit across missing bridge")
	else:
		check(actual_hits.size() == 1 and target_health.current == 4, "supported actual ground wave reaches actor and commits one HP")
	finish_observation("ground gap negative" if gap else "supported ground wave")

func cancelled_seed() -> void:
	if not await fixture(): return
	var shot := projectile(target.global_position)
	encounter.cancel_pending_attacks()
	shot.advance_frozen_contact()
	await ticks(2)
	check(actual_hits.is_empty() and target_health.current == 5, "old-epoch seed frozen overlap cannot deliver a late hit")
	finish_observation("cancelled seed overlap")

func run() -> void:
	await strike_contact()
	await strike_empty_corner()
	await strike_swept_crossing()
	await frozen_contact()
	await frozen_old_path_negative()
	await cancelled_contact(false)
	await cancelled_contact(true)
	await seed_contact(false)
	await seed_contact(true)
	await supported_wave(false)
	await supported_wave(true)
	await cancelled_seed()
	await cleanup()
	DirAccess.make_dir_recursive_absolute("res://build/windkeeper_pressure_01")
	var file := FileAccess.open("res://build/windkeeper_pressure_01/attack_geometry.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"assertions": assertions, "failures": failures, "observations": observations,
		"scope": "real pressure attack entity collision with real FramePolicy; explicit static actor/layout fixtures and original App-style hit binding; not actual App, natural fight, visuals, listening or device approval"}, "\t"))
	file.close()
	print("WINDKEEPER PRESSURE ATTACK GEOMETRY: ", assertions, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
