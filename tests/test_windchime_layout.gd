extends SceneTree
## Real starting PlayerMotor, forward AND return; no ability grants, shots,
## mid-route reset, resource refill or actor position writes.
const Layout := preload("res://experiments/terrain/art_foundation/windchime_layout.gd")
var checks := 0
var failures: Array[String] = []
var _layout: Dictionary
var _player: PlayerMotor
var _controller: PlayerController
var _jumps := 0
var _trace: Array[Dictionary] = []

func _init() -> void:
	_run.call_deferred()

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: " + message)

func _run() -> void:
	_layout = Layout.build_map()
	expect(_layout.ok and _layout.bounds.size == Vector2(2560, 896), "MAP01 exact tile bounds")
	expect(_layout == Layout.build_map(), "handmade layout deterministic")
	expect(not _layout.production_pool, "sample does not claim formal pool admission")
	for cell: Vector2i in _layout.cells:
		expect(Rect2i(Vector2i.ZERO, Layout.SIZE).has_point(cell), "solid stays inside map")
		expect(_layout.cells[cell] == &"windchime_stone", "one declared visual family")
	# Large architectural negative space is absent from BOTH tile and collision.
	for y: int in range(24, 28):
		for x: int in range(34, 42):
			expect(not _layout.cells.has(Vector2i(x, y)), "arch opening remains empty")
	for x: int in range(29, 47):
		expect(_layout.cells.has(Vector2i(x, 19)), "arch deck has continuous support")
	var rebuilt: Dictionary = {}
	for rect: Rect2 in Blob47Terrain.collision_rectangles(_layout.cells):
		for y: int in range(int(rect.position.y / Layout.CELL), int(rect.end.y / Layout.CELL)):
			for x: int in range(int(rect.position.x / Layout.CELL), int(rect.end.x / Layout.CELL)):
				var cell := Vector2i(x, y)
				expect(not rebuilt.has(cell), "collision rectangles never overlap")
				rebuilt[cell] = Layout.MATERIAL
	expect(rebuilt == _layout.cells, "collision union is exactly the authored tile occupancy")
	for card: Dictionary in _layout.modules:
		expect(card.required_abilities.is_empty(), "main module grants no H/W/D")
		expect(card.ports_and_halo.owner == "merged_world_cells", "single occupancy before masks")
	for item: Dictionary in _layout.moving:
		var sweep: Rect2 = item.rect.merge(Rect2(item.rect.position + item.travel, item.rect.size))
		for rect: Rect2 in Blob47Terrain.collision_rectangles(_layout.cells):
			expect(not sweep.intersects(rect), "optional moving sweep does not enter static stone")
	var world := Node2D.new()
	root.add_child(world)
	var terrain := WindchimeTerrain.build(_layout.cells, _layout.seed)
	world.add_child(terrain)
	expect(terrain.get_used_cells().size() == _layout.cells.size(), "actual new-family TileMap renders every collision cell")
	Blob47Terrain.add_collision(world, _layout.cells)
	for rect: Rect2 in _layout.one_way:
		var platform := WindchimePlatform.new()
		platform.position = rect.position
		platform.bounds = Rect2(Vector2.ZERO, Vector2(rect.size.x, 10))
		platform.one_way = true
		world.add_child(platform)
	for item: Dictionary in _layout.moving:
		var platform := WindchimePlatform.new()
		platform.position = item.rect.position
		platform.bounds = Rect2(Vector2.ZERO, item.rect.size)
		platform.travel = item.travel
		platform.period = item.period
		world.add_child(platform)
	_player = preload("res://game/player/player.tscn").instantiate()
	_player.position = _layout.spawn
	world.add_child(_player)
	_controller = _player.get_node("Controller")
	_controller.enable_shot_energy()
	for adapter: String in ["KeyboardMouseAdapter", "GamepadAdapter"]:
		var input := _player.get_node_or_null(adapter)
		if input != null: input.process_mode = Node.PROCESS_MODE_DISABLED
	_controller.jump_ability.jumped.connect(func() -> void: _jumps += 1)
	for tick: int in 10: await physics_frame
	expect(_player.is_on_floor(), "real actor initially rests on entry stone")
	var start_steps := _player.motion_steps
	var initial_health := _controller.actor_resources.health.current
	var forward: Dictionary = await _drive(1.0, 2432.0)
	expect(forward.reached, "real basic Motor reaches endpoint: " + str(forward))
	var backward: Dictionary = await _drive(-1.0, 80.0)
	expect(backward.reached, "same actor returns without reset: " + str(backward))
	# The optional branch is a real climb to the visible upper reward, then a
	# safe drop back to the main court. The moving carrier is an optional way
	# to remain high; it never provides the only return or required refill.
	var branch_entry: Dictionary = await _drive(1.0, 672.0)
	expect(branch_entry.reached and _player.is_on_floor(), "optional branch reached through main route")
	for target: Vector2 in [Vector2(800, 494), Vector2(944, 430), Vector2(1104, 430)]:
		var branch_jump: Dictionary = await _jump_to(target)
		expect(branch_jump.reached, "optional branch accepted jump: " + str(branch_jump))
		print("WINDCHIME_UPPER ", branch_jump)
	var branch_return: Dictionary = await _drive(1.0, 1568.0)
	for settle: int in 45:
		await physics_frame
		_capture("branch_landing", 0.0, false)
	expect(branch_return.reached and _player.is_on_floor() and _player.position.y > 570, "upper reward returns safely to main court: " + str(branch_return))
	expect(_jumps >= 4 and _player.motion_steps > start_steps + 100, "accepted jumps and real Motor steps")
	expect(not _controller.traversal.hook_enabled and not _controller.traversal.wall_enabled and not _controller.traversal.double_enabled, "no ungranted movement ability")
	expect(_controller.received_resource_grants.is_empty(), "no external resource grants")
	expect(_controller.actor_resources.health.current == initial_health, "geometry route takes no forced damage")
	print("WINDCHIME_ROUTE forward=%s return=%s accepted_jumps=%d" % [str(forward), str(backward), _jumps])
	var bridge_middle: Dictionary = await _drive(1.0, 1616.0)
	expect(bridge_middle.reached, "wood drop test first clears the stone abutment with the whole body")
	_controller.router.clear("windchime_test_end")
	expect(_player.request_drop_through(), "real actor can drop through the Windchime wood bridge")
	for drop_tick: int in 30:
		await physics_frame
		_capture("intentional_one_way_drop", 0.0, false)
	expect(_player.position.y > 700, "one-way bridge never becomes a solid stone collision")
	var trace_file := FileAccess.open("res://build/windchime-layout-trace.json", FileAccess.WRITE)
	if trace_file != null:
		trace_file.store_string(JSON.stringify({"layout_version": Layout.VERSION,
			"player_scene": "res://game/player/player.tscn", "physics_hz": Engine.physics_ticks_per_second,
			"initial_spawn_only": true, "required_shots": 0, "granted_abilities": [], "frames": _trace}))
	_controller.shoot_ability.reset()
	world.free()
	await process_frame
	await process_frame
	var material: Dictionary = Layout.build_material_fixture()
	expect(material.bounds.size == Vector2(1280, 768), "MAP00 material fixture exact bounds")
	expect(not material.cells.has(Vector2i(32, 15)), "MAP00 includes a real closed hole")
	expect(Layout.material_map("test-material-seed").seed == "test-material-seed", "MAP00 API preserves requested decoration seed")
	print("WINDCHIME_LAYOUT checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _drive(direction: float, finish_x: float) -> Dictionary:
	var hold_ticks := 0
	var minimum_y := _player.position.y
	var maximum_y := _player.position.y
	for tick: int in 1800:
		_controller.router.set_move_axis(direction)
		var ahead := Vector2(_player.position.x + direction * 32, _player.position.y + 30)
		var edge := not _supported(ahead)
		if _player.is_on_floor() and (_player.is_on_wall() or edge) and hold_ticks == 0:
			_controller.router.set_jump_held(&"windchime_route", true)
			hold_ticks = 10 if edge else 7
		elif hold_ticks > 0:
			hold_ticks -= 1
			if hold_ticks == 0: _controller.router.set_jump_held(&"windchime_route", false)
		await physics_frame
		_capture("drive_to_" + str(finish_x), direction, hold_ticks > 0)
		minimum_y = minf(minimum_y, _player.position.y)
		maximum_y = maxf(maximum_y, _player.position.y)
		if _player.position.y > _layout.bounds.end.y:
			return {"reached": false, "reason": "fell_out", "tick": tick, "position": _player.position}
		if (direction > 0 and _player.position.x >= finish_x) or (direction < 0 and _player.position.x <= finish_x):
			_controller.router.set_move_axis(0)
			_controller.router.set_jump_held(&"windchime_route", false)
			for settle: int in 12:
				await physics_frame
				_capture("settle_at_" + str(finish_x), 0.0, false)
			return {"reached": true, "tick": tick, "position": _player.position,
				"minimum_y": minimum_y, "maximum_y": maximum_y}
	return {"reached": false, "reason": "timeout", "position": _player.position}

func _jump_to(target: Vector2) -> Dictionary:
	_controller.router.set_jump_held(&"windchime_route", true)
	var airborne := false
	var started_jumps := _jumps
	for tick: int in 180:
		var difference := target.x - _player.position.x
		_controller.router.set_move_axis(signf(difference) if absf(difference) > 3.0 else 0.0)
		await physics_frame
		_capture("upper_jump_to_" + str(target), signf(difference) if absf(difference) > 3.0 else 0.0, true)
		if not _player.is_on_floor(): airborne = true
		if airborne and _player.is_on_floor():
			_controller.router.set_jump_held(&"windchime_route", false)
			_controller.router.set_move_axis(0.0)
			for settle: int in 3:
				await physics_frame
				_capture("upper_landing", 0.0, false)
			return {"reached": absf(_player.position.x - target.x) < 8 and absf(_player.position.y - target.y) < 2 and _jumps > started_jumps,
				"position": _player.position, "target": target, "tick": tick}
	_controller.router.set_jump_held(&"windchime_route", false)
	return {"reached": false, "reason": "jump_timeout", "position": _player.position, "target": target}

func _capture(phase: String, move_axis: float, jump_held: bool) -> void:
	_trace.append({"frame": _trace.size(), "phase": phase, "move_axis": move_axis,
		"jump_held": jump_held, "accepted_jumps": _jumps, "motion_steps": _player.motion_steps,
		"position": [_player.position.x, _player.position.y],
		"normal_velocity": [_player.normal_velocity.x, _player.normal_velocity.y],
		"grounded": _player.is_on_floor(), "used_jumps": _controller.jump_ability.used_jumps,
		"shot_charges": _controller.action_resources.shot_charges,
		"health": _controller.actor_resources.health.current})

func _supported(point: Vector2) -> bool:
	# A visible one/two-cell descent is a walk, not a reason to launch early.
	# Jumping off the preceding high step can overshoot the last takeoff deck.
	for drop: int in [0, 32, 64]:
		if _layout.cells.has(Vector2i(floori(point.x / Layout.CELL), floori((point.y + drop) / Layout.CELL))): return true
	for rect: Rect2 in _layout.one_way:
		if point.x >= rect.position.x and point.x < rect.end.x and point.y <= rect.position.y + 32 and point.y + 64 >= rect.position.y: return true
	return false
