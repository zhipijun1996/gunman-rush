extends Node2D
## Fixed-map host adapter for the existing formal Windkeeper. Authored materialized
## terrain is built by the registry; this node owns only the encounter lifecycle.
signal victory

var host: Node2D
var module: PlatformingModule
var player: PlayerController
var policy: FrameDamagePolicy
var lifetime: DemoLifetime
var segment: SegmentRespawn
var boss: BossMotor
var encounter: WindkeeperEncounter
var started := false
var completed := false
var broken := false
var world_bounds: Rect2
var arrival_bounds: Rect2
var reward_position := Vector2.ZERO
var target_id: StringName
var events: Array[Dictionary] = []
var _contact: DemoContactEmitter
var _fall: DemoContactEmitter
var _stands: Array[Vector2] = []
var _eligible_shots: Dictionary = {}
var _identity := ""
var _floor: Rect2
var _was_inside := false

func setup(arena_host: Node2D, controller: PlayerController, services: Dictionary) -> Dictionary:
	if is_instance_valid(host): return _failure("already_configured")
	if not is_instance_valid(arena_host) or not is_instance_valid(controller): return _failure("external_arena_and_player_required")
	if not services.has_all(["policy", "lifetime", "segment"]): return _failure("shared_policy_lifetime_segment_required")
	var supplied_module := arena_host.get("module") as PlatformingModule
	var content: Variant = arena_host.get("content")
	if supplied_module == null or not content is Dictionary or content.get("stable_id") != "game-plains-boss-arena":
		return _failure("M40_game-plains-boss-arena_materialized_module_required")
	# This adapter is deliberately limited to the delivered M40. A changed arena
	# requires a new explicit host geometry binding, never silent approximate fit.
	if not _exact_numeric_array(content.get("world_bounds"), [0, 0, 1152, 640]) or not _exact_numeric_array(content.get("platforms"), [[32,480,1120,80],[819,350,180,20],[486,350,180,20],[153,350,180,20],[0,480,56,24]]):
		return _failure("M40_materialized_geometry_mismatch")
	if not arena_host.global_transform.x.is_equal_approx(Vector2.RIGHT) or not arena_host.global_transform.y.is_equal_approx(Vector2.DOWN):
		return _failure("translation_only_arena_required")
	var supplied_identity: Variant = arena_host.get("instance_key")
	if not supplied_identity is String or supplied_identity.is_empty(): return _failure("run_map_instance_identity_required")
	_identity = supplied_identity
	host = arena_host
	module = supplied_module
	player = controller
	policy = services.policy as FrameDamagePolicy
	lifetime = services.lifetime as DemoLifetime
	segment = services.segment as SegmentRespawn
	if policy == null or lifetime == null or segment == null or segment.controller != player or segment.lifetime != lifetime:
		return _failure("incompatible_shared_host_services")
	process_physics_priority = 850
	_floor = module.definition.platforms[0]
	world_bounds = Rect2(host.to_global(module.definition.world_bounds.position), module.definition.world_bounds.size)
	arrival_bounds = world_bounds.grow_individual(-24, 0, -24, 0)
	# Use the actual materialized shelf tops. The native adapter's legacy x=350
	# stand misses the delivered source shelf; simply applying its affine is unsafe.
	var shelves: Array[Rect2] = []
	for index: int in [1, 2, 3]: shelves.append(module.definition.platforms[index])
	shelves.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.get_center().x < b.get_center().x)
	var collision := player.motor.get_node("CollisionShape2D") as CollisionShape2D
	if collision == null or not collision.shape is RectangleShape2D: return _failure("native_rectangular_player_required")
	var player_half_height := (collision.shape as RectangleShape2D).size.y * .5
	for index: int in shelves.size():
		var shelf: Rect2 = shelves[index]
		var stand := host.to_global(Vector2(shelf.get_center().x, shelf.position.y - player_half_height))
		_stands.append(stand)
		if not segment.add_anchor(_anchor_id(index), stand): return _failure("duplicate_boss_segment_anchor")
	boss = BossFactory.create(&"windkeeper_storm")
	if boss == null: return _failure("native_windkeeper_factory_failed")
	var definition := (boss.get_node("Encounter") as WindkeeperEncounter).definition
	var bottom := definition.collision_size.y * .5 + definition.collision_offset.y
	boss.position = Vector2(_floor.get_center().x, _floor.position.y - bottom)
	host.add_child(boss)
	encounter = boss.get_node("Encounter") as WindkeeperEncounter
	# configure_arena is a world-coordinate API. Native Windkeeper uses a 65px
	# body-to-floor offset, equal to the current Definition's bottom, without any
	# PlayerTuning or combat Definition modification.
	if not encounter.configure_arena(host.to_global(_floor.position).x + 25, host.to_global(_floor.end).x - 25, player.motor):
		return _failure("native_windkeeper_arena_rejected")
	if not is_equal_approx(encounter._floor_y, host.to_global(_floor.position).y):
		return _failure("native_windkeeper_floor_offset_changed")
	for stand: Vector2 in _stands: encounter._platform_piers.append(stand.x)
	encounter.reward_stands.assign(_stands)
	encounter.phase_changed.connect(_phase_changed)
	encounter.projectile_created.connect(_projectile_created)
	player.shoot_ability.shot_fired.connect(_record_shot)
	policy.batch_resolved.connect(_batch_resolved)
	target_id = StringName("module/" + _identity.uri_encode() + "/boss")
	# Dormant bosses cannot be shot before the player actually enters the arena.
	(boss.get_node("Damageable") as Damageable).damage_sink = func(_context: Dictionary) -> bool: return false
	_contact = DemoContactEmitter.new()
	_contact.name = "MapBossContact"
	_contact.policy = policy
	_contact.controller = player
	_contact.source_id = StringName(str(target_id) + "/contact")
	_contact.kind = DamageRequest.Kind.MONSTER
	_contact.contact_rect_provider = encounter.body_contact_rect
	_contact.enabled = false
	boss.add_child(_contact)
	_fall = DemoContactEmitter.new()
	_fall.name = "BrokenBridgeFall"
	_fall.policy = policy
	_fall.controller = player
	_fall.source_id = StringName(str(target_id) + "/broken_bridge_fall")
	_fall.kind = DamageRequest.Kind.ENVIRONMENT
	_fall.enabled = false
	# These are the native Windkeeper lifecycle pit dimensions, mapped once from
	# its source geometry to M40. They are not a second copy of delivery terrain.
	_fall.position = to_local(host.to_global(Vector2(507, 565)))
	_fall.half_size = Vector2(355, 95)
	add_child(_fall)
	reward_position = host.to_global(Vector2(_floor.get_center().x, _floor.position.y - player_half_height))
	events.append({"event":"boss_bound", "identity":_identity, "scene":boss.scene_file_path, "definition":encounter.definition.resource_path, "shelf_stands":_stand_values()})
	return {"ok":true, "boss":boss, "encounter":encounter, "target_id":str(target_id), "scene":boss.scene_file_path, "definition":encounter.definition.resource_path, "arrival_bounds":[arrival_bounds.position.x,arrival_bounds.position.y,arrival_bounds.size.x,arrival_bounds.size.y], "initial_exit_remains_sealed":true}

func contains_player() -> bool:
	return is_instance_valid(player) and world_bounds.has_point(player.motor.global_position)

func activate() -> bool:
	if started or completed or not is_instance_valid(encounter) or not lifetime.active or player.actor_resources.health.terminal:
		return false
	var collision := player.motor.get_node("CollisionShape2D") as CollisionShape2D
	var body: Rect2 = collision.global_transform * collision.shape.get_rect()
	if not arrival_bounds.encloses(body) or not player.motor.is_on_floor(): return false
	var receiver := boss.get_node("Damageable") as Damageable
	if not policy.bind_damageable(target_id, receiver, encounter.health): return false
	var native_sink := receiver.damage_sink
	receiver.damage_sink = func(context: Dictionary) -> bool:
		var shot_key := "%s:%s" % [context.get("session_id", -1), context.get("shot_id", -1)]
		return started and contains_player() and lifetime.active and _eligible_shots.get(shot_key, -1) == lifetime.actor_epoch and native_sink.call(context) == true
	started = encounter.activate()
	events.append({"event":"boss_activated", "accepted":started, "player_position":[player.motor.global_position.x,player.motor.global_position.y]})
	return started

func _record_shot(_direction: Vector2, shot_id: int) -> void:
	if not started or not lifetime.active or not contains_player(): return
	_eligible_shots["%s:%s" % [player.session_id, shot_id]] = lifetime.actor_epoch
	encounter.register_rune_shot(player.session_id, shot_id)
	# Native shots already have finite lifetimes. Bound the authorization ledger
	# without changing shot delivery or accepting projectiles from another epoch.
	while _eligible_shots.size() > 256: _eligible_shots.erase(_eligible_shots.keys()[0])

func _projectile_created(projectile: BossProjectile) -> void:
	projectile.hit.connect(func(body: Node2D, event_id: StringName, amount: float) -> void:
		if not started or body != player.motor or not lifetime.active or not contains_player(): return
		var request := DamageRequest.new()
		request.token = lifetime.token()
		request.actor_epoch = lifetime.actor_epoch
		request.health_epoch = player.actor_resources.health.epoch
		request.target_id = &"player"
		request.source_id = StringName(str(target_id) + "/projectile")
		request.event_id = StringName(str(target_id) + "/" + str(event_id))
		request.amount = amount
		request.hit_direction = projectile.direction
		policy.submit(request)
	)

func _batch_resolved(_results: Array[DamageResult]) -> void:
	# The policy invalidates the Run before emitting this signal on a same-frame
	# player death. Native encounter.defeated is too early to decide victory.
	if completed or not started or not lifetime.active or player.actor_resources.health.terminal or not encounter.health.terminal: return
	completed = true
	_contact.enabled = false
	_fall.enabled = false
	reward_position = encounter.reward_stand_position()
	events.append({"event":"boss_victory", "target_id":str(target_id), "exit_seal_opened":false})
	victory.emit()

func _phase_changed(phase: int) -> void:
	events.append({"event":"boss_phase", "phase":phase})
	if phase == 3 and not broken: _break_ground.call_deferred()

func _break_ground() -> void:
	if broken or not is_instance_valid(module) or not lifetime.active: return
	broken = true
	var old := module.get_node("Platform0") as StaticBody2D
	old.collision_layer = 0
	# Native source shores [0,600,290,80] and [1000,600,120,80]
	# under M40's source-to-materialized affine (-x+1152,y-120).
	# Initial materialized platforms are never mirrored again.
	var shores: Array[Rect2] = [Rect2(862,480,290,80), Rect2(32,480,120,80)]
	module.definition.platforms[0] = shores[0]
	module.definition.platforms.append(shores[1])
	for index: int in shores.size():
		var body := StaticBody2D.new()
		body.name = "MapBossShore" + str(index)
		body.position = shores[index].get_center()
		body.collision_layer = 1
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = shores[index].size
		shape.shape = rectangle
		body.add_child(shape)
		module.add_child(body)
	module.ground_surface_regions.erase(0)
	module.exposed_surface_edges.clear()
	module.queue_redraw()
	_fall.enabled = true
	var nearest := 0
	for index: int in _stands.size():
		if player.motor.global_position.distance_squared_to(_stands[index]) < player.motor.global_position.distance_squared_to(_stands[nearest]): nearest = index
	segment.activate_anchor(_anchor_id(nearest))
	events.append({"event":"boss_bridge_broken", "disabled_platform":0, "preserved_shelves":[1,2,3], "preserved_seam_platform":4, "exit_seal_opened":false})

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(encounter): return
	if not lifetime.active:
		encounter.cancel()
		_contact.enabled = false
		_fall.enabled = false
		return
	var inside := contains_player()
	if _was_inside and not inside: _eligible_shots.clear()
	_was_inside = inside
	_contact.enabled = started and inside and encounter.body_contact_enabled()
	if not broken: return
	if player.motor.is_on_floor():
		for index: int in _stands.size():
			if player.motor.global_position.distance_to(_stands[index]) < 45: segment.activate_anchor(_anchor_id(index))
	encounter.rune_platform = -1
	var feet := host.to_local(player.motor.global_position) + Vector2(0, 18)
	for index: int in _stands.size():
		var stand := host.to_local(_stands[index])
		if absf(feet.y - stand.y - 18) < 2 and absf(feet.x - stand.x) <= 78: encounter.rune_platform = index

func _anchor_id(index: int) -> StringName:
	return StringName(_identity + "/boss_shelf/" + str(index))

func _stand_values() -> Array:
	var result: Array = []
	for stand: Vector2 in _stands: result.append([stand.x, stand.y])
	return result

func snapshot() -> Dictionary:
	return {"started":started, "completed":completed, "bridge_broken":broken, "target_id":str(target_id), "boss_health":encounter.health.current if is_instance_valid(encounter) else -1, "phase":encounter.stage_phase if is_instance_valid(encounter) else 0, "mode":str(encounter.mode) if is_instance_valid(encounter) else "", "reward_position":[reward_position.x,reward_position.y], "shelf_stands":_stand_values(), "events":events.duplicate(true), "initial_exit_remains_sealed":true}

func _failure(reason: String) -> Dictionary:
	return {"ok":false, "instance_id":"M40", "module_id":"game-plains-boss-arena", "mechanism":"native_windkeeper_binding", "reason":reason}

func _exact_numeric_array(actual: Variant, expected: Array) -> bool:
	# Godot's JSON reader uses floats. Array equality distinguishes their Variant
	# types from integer literals; compare numeric values without a tolerance.
	if not actual is Array or actual.size() != expected.size(): return false
	for index: int in expected.size():
		var value: Variant = actual[index]
		var reference: Variant = expected[index]
		if reference is Array:
			if not _exact_numeric_array(value, reference): return false
		elif typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or float(value) != float(reference):
			return false
	return true

func _exit_tree() -> void:
	if is_instance_valid(encounter): encounter.cancel()
