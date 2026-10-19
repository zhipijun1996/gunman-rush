extends SceneTree
var checks := 0
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: " + message)

func _run() -> void:
	var masks: Dictionary = {}
	for raw: int in 256:
		# Independent coordinate oracle: include a diagonal only if both of its
		# component orthogonal offsets are also present.
		var cells: Dictionary = {Vector2i.ZERO: &"sandstone"}
		var directions := [Vector2i.UP, Vector2i(1,-1), Vector2i.RIGHT, Vector2i(1,1), Vector2i.DOWN, Vector2i(-1,1), Vector2i.LEFT, Vector2i(-1,-1)]
		var expected := 0
		for index: int in 8:
			if raw & (1 << index): cells[directions[index]] = &"sandstone"
		for index: int in 8:
			var at: Vector2i = directions[index]
			if not cells.has(at): continue
			if at.x != 0 and at.y != 0 and (not cells.has(Vector2i(at.x,0)) or not cells.has(Vector2i(0,at.y))): continue
			expected |= 1 << index
		expect(Blob47Rules.canonical_mask(raw) == expected, "oracle raw " + str(raw))
		expect(Blob47Rules.mask_at(cells, Vector2i.ZERO) == expected, "occupancy raw " + str(raw))
		masks[expected] = true
	expect(masks.size() == 47, "exactly 47 distinct canonical states")
	var mixed: Dictionary = {Vector2i.ZERO: &"sandstone", Vector2i.RIGHT: &"other"}
	expect(Blob47Rules.mask_at(mixed, Vector2i.ZERO) == 0, "different family does not join")
	var shape: Dictionary = {}
	for y: int in range(-3, 5):
		for x: int in range(-4, 8):
			if not (x >= 0 and x <= 2 and y >= -1 and y <= 2): shape[Vector2i(x,y)] = &"sandstone"
	var rectangles := Blob47Terrain.collision_rectangles(shape)
	var rebuilt: Dictionary = {}
	var area := 0.0
	for rect: Rect2 in rectangles:
		area += rect.get_area()
		for y: int in range(int(rect.position.y/32), int(rect.end.y/32)):
			for x: int in range(int(rect.position.x/32), int(rect.end.x/32)):
				var point := Vector2i(x,y)
				expect(not rebuilt.has(point), "collision does not overlap")
				rebuilt[point] = &"sandstone"
	expect(rebuilt == shape and area == shape.size()*32*32, "collision union preserves hole and negatives exactly")
	var reversed: Dictionary = {}
	var keys: Array = shape.keys()
	keys.reverse()
	for key: Vector2i in keys: reversed[key] = shape[key]
	expect(Blob47Terrain.collision_rectangles(reversed) == rectangles, "collision independent of insertion order")
	var layer := Blob47Terrain.build(shape, "oracle-seed")
	root.add_child(layer)
	expect(layer.get_used_cells().size() == shape.size(), "actual TileMapLayer has all cells")
	var source := layer.tile_set.get_source(0) as TileSetAtlasSource
	expect(source.get_tiles_count() == 141, "actual atlas contains 47 states x three variants")
	for cell: Vector2i in shape:
		var coords := layer.get_cell_atlas_coords(cell)
		expect(source.has_tile(coords), "runtime atlas coordinate exists")
		expect(coords == Blob47Rules.atlas_coords(Blob47Rules.mask_at(shape, cell), Blob47Rules.variant_at("oracle-seed", cell)), "runtime selects canonical art")
	layer.free()
	var generated := Blob47Layout.generate("foundation-01")
	var before := generated.duplicate(true)
	var keepouts: Array[Rect2] = []
	keepouts.assign(generated.keepouts)
	var decorations := Blob47Decoration.new()
	root.add_child(decorations)
	decorations.configure(generated.cells, keepouts, "foundation-01")
	var placements := decorations.placements.duplicate(true)
	expect(not placements.is_empty(), "sample actually uses decoration family")
	decorations.configure(generated.cells, keepouts, "foundation-01")
	expect(decorations.placements == placements, "decoration deterministic")
	for item: Dictionary in placements:
		for keepout: Rect2 in keepouts:
			expect(not keepout.grow(10).intersects(item.bounds), "actual prop respects keepout")
	var budgets: Dictionary = {}
	for item: Dictionary in placements:
		var budget: Vector2i = budgets.get(item.bucket, Vector2i.ZERO)
		budgets[item.bucket] = budget + Vector2i(1, 1 if item.kind == 4 else 0)
	for budget: Vector2i in budgets.values():
		expect(budget.x <= Blob47Rules.DECORATION_PROFILE.max_props_per_screen_bucket, "bounded prop bucket")
		expect(budget.y <= Blob47Rules.DECORATION_PROFILE.max_lamps_per_screen_bucket, "bounded lamp bucket")
	decorations.configure(generated.cells, keepouts, "different-decoration-seed")
	expect(generated == before, "decoration does not mutate layout or Manifest")
	decorations.free()
	# Real PlayerMotor with accepted InputRouter requests. No position writes in
	# the route: only the initial spawn. This is a simple sample route, not a
	# proof for all production levels or all optional upper routes.
	var lab := preload("res://scenes/demo/blob47_lab.tscn").instantiate() as Blob47Lab
	root.add_child(lab)
	for adapter: String in ["KeyboardMouseAdapter", "GamepadAdapter"]:
		lab.player.get_node(adapter).process_mode = Node.PROCESS_MODE_DISABLED
	var jumped := 0
	lab.controller.jump_ability.jumped.connect(func() -> void: lab.set_meta("jump_count", int(lab.get_meta("jump_count",0))+1))
	var previous_steps := lab.player.motion_steps
	var hold_ticks := 0
	for tick: int in 1500:
		lab.controller.router.set_move_axis(1.0)
		# Take the safe low route: jump only when the real body meets a step.
		# Blind periodic full jumps enter the optional upper hazards (retained in
		# the initial failed trace), so they do not express this route's intent.
		if lab.player.is_on_floor() and lab.player.is_on_wall() and hold_ticks == 0:
			lab.controller.router.set_jump_held(&"foundation_test", true)
			hold_ticks = 7
		elif hold_ticks > 0:
			hold_ticks -= 1
			if hold_ticks == 0: lab.controller.router.set_jump_held(&"foundation_test", false)
		await physics_frame
		if lab.player.position.x > 2490: break
	jumped = int(lab.get_meta("jump_count",0))
	expect(lab.player.position.x > 2490, "real Motor reaches sample end, x=" + str(lab.player.position.x))
	expect(jumped > 0 and lab.player.motion_steps > previous_steps, "route uses actual accepted jumps and Motor steps")
	var same_layout := lab.layout.duplicate(true)
	lab.decoration.visible = false
	lab.backdrop.middle_enabled = false
	expect(lab.layout == same_layout, "layer toggles preserve gameplay data")
	lab._toggle_catalog()
	expect(paused, "catalog pauses simulation")
	lab.restart()
	expect(not paused and not lab._catalog.visible, "restart closes catalog before resuming")
	lab._toggle_catalog()
	lab._next_seed()
	expect(not paused and not lab._catalog.visible and lab.seed_text == "foundation-02", "reseed closes catalog and replaces content")
	for case: int in range(2, 4):
		if case == 3: lab._next_seed()
		hold_ticks = 0
		var starting_epoch := lab.lifetime.actor_epoch
		for tick: int in 1500:
			lab.controller.router.set_move_axis(1.0)
			if lab.player.is_on_floor() and lab.player.is_on_wall() and hold_ticks == 0:
				lab.controller.router.set_jump_held(&"foundation_test", true)
				hold_ticks = 7
			elif hold_ticks > 0:
				hold_ticks -= 1
				if hold_ticks == 0: lab.controller.router.set_jump_held(&"foundation_test", false)
			await physics_frame
			if lab.player.position.x > 2490: break
		expect(lab.player.position.x > 2490 and lab.lifetime.actor_epoch == starting_epoch, "real low route without return on " + lab.seed_text)
	# Separate one-way contract fixture, after route evidence. Motor must find
	# the named collision shape and genuinely pass below it on a drop request.
	lab.controller.router.clear("drop_fixture")
	var drop_platform := Blob47Platform.new()
	drop_platform.position = Vector2(-320, 448)
	drop_platform.bounds = Rect2(0, 0, 128, 10)
	drop_platform.one_way = true
	lab.add_child(drop_platform)
	lab.controller.reset_at(Vector2(-256, 400))
	for tick: int in 45: await physics_frame
	expect(lab.player.is_on_floor() and absf(lab.player.position.y - 430) < 1, "actual Motor lands on one-way top")
	expect(lab.player.request_drop_through(), "one-way drop request accepted by unchanged Motor")
	for tick: int in 35: await physics_frame
	expect(lab.player.position.y > 475, "actual Motor passes below one-way")
	var moving_platform := Blob47Platform.new()
	moving_platform.position = Vector2(-320, 544)
	moving_platform.bounds = Rect2(0, 0, 128, 32)
	moving_platform.travel = Vector2(64, 0)
	lab.add_child(moving_platform)
	lab.controller.reset_at(Vector2(-256, 490))
	for tick: int in 45: await physics_frame
	expect(lab.player.is_on_floor(), "actual Motor stands on moving solid")
	var carrier_start := moving_platform.position.x
	var passenger_start := lab.player.position.x
	for tick: int in 30: await physics_frame
	var carried := lab.player.position.x - passenger_start
	var travelled := moving_platform.position.x - carrier_start
	expect(absf(travelled) > 5 and absf(carried - travelled) < 2, "engine collision carries player without position writes")
	lab.leave()
	lab.free()
	await process_frame
	await process_frame
	print("BLOB47_FOUNDATION checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
