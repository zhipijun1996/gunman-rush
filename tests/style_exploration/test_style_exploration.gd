extends SceneTree
## Actual TileSet/TileMapLayer, canonical atlas, all 20 consumers, real Motor routes.
var checks := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var upper_observations: Array[Dictionary] = []

func _init() -> void:
	_run.call_deferred()

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("FAIL: " + label)

func _run() -> void:
	var signatures: Dictionary = {}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/style_exploration/tilesets"))
	for style: String in StyleTerrain.STYLES:
		var result := ResourceSaver.save(StyleTerrain.create_tileset(style), "res://build/style_exploration/tilesets/%s.tres" % style)
		expect(result == OK, "real reusable TileSet resource can be saved: " + style)
	for seed_value: int in StyleLayout.SEEDS:
		var layout := StyleLayout.generate(seed_value)
		expect(layout == StyleLayout.generate(seed_value), "same seed reproduces actual geometry")
		expect(StyleLayout.validate(layout).is_empty(), "solid/one-way/route contract: " + str(seed_value))
		expect(layout.bounds == Rect2(0, 0, 2560, 736), "80 by 23 comparison slice")
		signatures[str(layout.modules)] = true
		var collision_cells: Dictionary = {}
		for rect: Rect2 in Blob47Terrain.collision_rectangles(layout.cells):
			for y: int in range(int(rect.position.y / 32), int(rect.end.y / 32)):
				for x: int in range(int(rect.position.x / 32), int(rect.end.x / 32)):
					var cell := Vector2i(x, y)
					expect(not collision_cells.has(cell), "collision union has no overlaps")
					collision_cells[cell] = StyleLayout.FAMILY
		expect(collision_cells == layout.cells, "collision exactly equals visible solid cells, including ravines")
		for style: String in StyleTerrain.STYLES:
			var layer := StyleTerrain.build(layout.cells, style)
			root.add_child(layer)
			var source := layer.tile_set.get_source(0) as TileSetAtlasSource
			expect(source.get_tiles_count() == 47, "47 real canonical atlas entries: " + style)
			expect(layer.get_used_cells().size() == layout.cells.size(), "real TileMapLayer consumes all geometry")
			expect(layer.tile_set.tile_size.x * layer.scale.x == 32, "all candidates have identical world tile scale")
			for cell: Vector2i in layout.cells:
				var at := layer.get_cell_atlas_coords(cell)
				expect(source.has_tile(at), "every assembled cell has real atlas art")
				expect(at == Blob47Rules.atlas_coords(Blob47Rules.mask_at(layout.cells, cell)), "assembled atlas uses merged world neighbors")
			layer.free()
	expect(signatures.size() == 4, "authored and three random seeds produce four genuinely different module orders")
	# Negative semantic case: a bridge is never allowed to overlap a solid.
	var bad := StyleLayout.generate(0)
	bad.one_way.append(Rect2(0, 608, 32, 8))
	expect(not StyleLayout.validate(bad).is_empty(), "solid/one-way semantic overlap is rejected")
	var lab := preload("res://experiments/terrain/entries/style_lab.tscn").instantiate() as StyleLab
	root.add_child(lab)
	for adapter: String in ["KeyboardMouseAdapter", "GamepadAdapter"]:
		lab.player.get_node(adapter).process_mode = Node.PROCESS_MODE_DISABLED
	lab.controller.jump_ability.jumped.connect(func() -> void: lab.set_meta("accepted_jumps", int(lab.get_meta("accepted_jumps", 0)) + 1))
	for seed_index: int in 4:
		lab.select_sample(seed_index)
		var frozen := lab.layout.duplicate(true)
		for style: String in StyleTerrain.STYLES:
			lab.select_style(style)
			lab.restart()
			var actor_epoch := lab.lifetime.actor_epoch
			var initial_steps := lab.player.motion_steps
			var initial_jumps := int(lab.get_meta("accepted_jumps", 0))
			var reached := await _drive(lab, 1)
			expect(reached, "actual Motor reaches right end: %s seed %d x=%.2f" % [style, lab.sample_seed, lab.player.position.x])
			expect(lab.lifetime.actor_epoch == actor_epoch, "no death/restart/teleport in forward route")
			expect(lab.player.motion_steps > initial_steps and int(lab.get_meta("accepted_jumps", 0)) > initial_jumps, "route uses actual accepted jumps and Motor steps")
			var forward := lab.player.position
			var returned := await _drive(lab, -1)
			expect(returned and lab.lifetime.actor_epoch == actor_epoch, "actual Motor returns across same cliffs/steps: %s seed %d x=%.2f" % [style, lab.sample_seed, lab.player.position.x])
			expect(lab.layout == frozen, "style switches and traversal do not mutate gameplay layout")
			observations.append({"style": style, "seed": lab.sample_seed, "reached": reached, "returned": returned, "forward_x": forward.x, "return_x": lab.player.position.x, "motor_steps": lab.player.motion_steps - initial_steps, "accepted_jumps": int(lab.get_meta("accepted_jumps", 0)) - initial_jumps, "actor_epoch_unchanged": lab.lifetime.actor_epoch == actor_epoch})
			await _verify_upper_modules(lab)
	expect(upper_observations.size() == 80, "all four upper module kinds are exercised in every style/seed consumer")
	for upper: Dictionary in upper_observations:
		expect(upper.completed, "every upper-platform visit includes a real return: %s/%d/%s" % [upper.style, upper.seed, upper.kind])
	# Actual previous-geometry counterexample: remove the added 96px stepping bridge.
	lab.select_sample(0)
	lab.select_style("basic")
	var arch_origin := 20.0 * 32
	for child: Node in lab._world.get_children():
		if child is StylePlatform and child.position == Vector2(arch_origin + 32, 384): child.free()
	expect(await _walk_to(lab, arch_origin + 80, 608), "pre-fix negative reaches arch on real ground route")
	expect(await _jump_to(lab, Vector2(arch_origin + 2.3 * 32, 480), "negative/first_oneway"), "pre-fix negative genuinely reaches first bridge")
	var old_geometry_can_reach := await _jump_to(lab, Vector2(arch_origin + 4.6 * 32, 320), "expected_negative/no_intermediate_step", true)
	expect(not old_geometry_can_reach, "actual old 160px rise is rejected without the intermediate jump step")
	lab.select_sample(0)
	# Camera-only art framing is explicitly separate from route proof.
	var art_player := lab.player.position
	var art_steps := lab.player.motion_steps
	var art_epoch := lab.lifetime.actor_epoch
	lab._capture_path = "camera_scope_fixture"
	lab._capture_x = 1800
	lab._process(0.0)
	expect(lab.camera.position.x == 1800 and lab.player.position == art_player, "capture camera-x moves the camera while the avatar remains at its actual position")
	expect(lab.player.motion_steps == art_steps and lab.lifetime.actor_epoch == art_epoch, "art framing makes no Motor steps or traversal claims")
	lab._capture_path = ""
	lab._capture_frames = 0
	# Switching candidates preserves the precise player pose, camera and physics.
	lab.controller.router.clear("comparison_switch_fixture")
	var before_position := lab.player.position
	var before_camera := lab.camera.position
	var before_session := lab.controller.session_id
	var before_collision := lab._world.get_child(1).get_instance_id()
	lab.select_style("basic" if lab.style_id != "basic" else "retro")
	expect(lab.player.position == before_position and lab.camera.position == before_camera, "style switching preserves pose and camera for comparison")
	expect(lab.controller.session_id == before_session and lab._world.get_child(1).get_instance_id() == before_collision, "style switching preserves live Motor session and collision instances")
	var before_layout := lab.layout.duplicate(true)
	lab._background_enabled = false
	lab._decor_enabled = false
	lab._lights_enabled = false
	lab._apply_layer_toggles()
	expect(lab.layout == before_layout, "presentation toggles cannot alter terrain")
	lab._toggle_catalog()
	expect(paused, "atlas catalog pauses real simulation")
	var close_key := InputEventKey.new()
	close_key.physical_keycode = KEY_T
	close_key.keycode = KEY_T
	close_key.pressed = true
	Input.parse_input_event(close_key)
	await process_frame
	await process_frame
	expect(not paused and not lab._catalog.visible, "real T input closes catalog while simulation is paused")
	lab._toggle_catalog()
	var restart_key := InputEventKey.new()
	restart_key.physical_keycode = KEY_R
	restart_key.keycode = KEY_R
	restart_key.pressed = true
	Input.parse_input_event(restart_key)
	await process_frame
	await process_frame
	expect(not paused and not lab._catalog.visible, "real R input restarts while simulation is paused")
	lab._toggle_catalog()
	lab.restart()
	expect(not paused and not lab._catalog.visible, "restart closes atlas and resumes")
	# Independent actual one-way fixture after route evidence, no traversal credit.
	var bridge := StylePlatform.new()
	bridge.position = Vector2(-320, 448)
	bridge.bounds = Rect2(0, 0, 128, 8)
	lab.add_child(bridge)
	lab.controller.reset_at(Vector2(-256, 400))
	for tick: int in 45: await physics_frame
	expect(lab.player.is_on_floor() and absf(lab.player.position.y - 430) < 1, "real Motor lands on named one-way shape")
	expect(lab.player.request_drop_through(), "unchanged Motor accepts bridge drop-through")
	for tick: int in 24: await physics_frame
	expect(lab.player.position.y > 475, "real body passes below one-way bridge")
	lab.leave()
	lab.free()
	await process_frame
	await process_frame
	var report := {"checks": checks, "failures": failures, "routes": observations, "upper_routes": upper_observations, "scope": "20 lower forward-and-return routes plus 80 module upper-platform visits and returns, using base PlayerMotor jumps only; camera-only art captures do not establish traversal; player aesthetics remain unverified"}
	var output_path := "res://build/style_exploration/runtime_report.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output_path = arg.trim_prefix("--report=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path).get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t")); file.close()
	else: expect(false, "runtime report can be saved")
	print("STYLE_EXPLORATION checks=%d failures=%d routes=%d" % [checks, failures.size(), observations.size()])
	quit(0 if failures.is_empty() else 1)

func _drive(lab: StyleLab, direction: int) -> bool:
	var hold_ticks := 0
	for tick: int in 1200:
		lab.controller.router.set_move_axis(float(direction))
		if lab.player.is_on_floor() and lab.player.is_on_wall() and hold_ticks == 0:
			lab.controller.router.set_jump_held(&"style_route", true)
			hold_ticks = 8
		elif hold_ticks > 0:
			hold_ticks -= 1
			if hold_ticks == 0: lab.controller.router.set_jump_held(&"style_route", false)
		await physics_frame
		if direction > 0 and lab.player.position.x > 2490: return true
		if direction < 0 and lab.player.position.x < 85: return true
	lab.controller.router.clear("route_timeout")
	return false


func _walk_to(lab: StyleLab, target_x: float, target_floor: float = -1.0) -> bool:
	var hold := 0
	for tick: int in 360:
		var difference := target_x - lab.player.position.x
		lab.controller.router.set_move_axis(signf(difference) if absf(difference) > 3.0 else 0.0)
		if absf(difference) <= 3.0 and lab.player.is_on_floor() and (target_floor < 0.0 or absf(lab.player.position.y + 18 - target_floor) < 2.0):
			lab.controller.router.set_jump_held(&"style_upper", false)
			return true
		if lab.player.is_on_floor() and lab.player.is_on_wall() and hold == 0:
			lab.controller.router.set_jump_held(&"style_upper", true)
			hold = 8
		elif hold > 0:
			hold -= 1
			if hold == 0: lab.controller.router.set_jump_held(&"style_upper", false)
		await physics_frame
	lab.controller.router.clear("upper_walk_timeout")
	return false

func _jump_to(lab: StyleLab, target: Vector2, label: String, expected_refusal: bool = false) -> bool:
	lab.controller.router.set_jump_held(&"style_upper", false)
	for tick: int in 3: await physics_frame
	var start := lab.player.position
	var departed := false
	lab.controller.router.set_jump_held(&"style_upper", true)
	for tick: int in 100:
		var difference := target.x - lab.player.position.x
		lab.controller.router.set_move_axis(signf(difference) if absf(difference) > 3.0 else 0.0)
		await physics_frame
		if not lab.player.is_on_floor(): departed = true
		if departed and lab.player.is_on_floor():
			lab.controller.router.set_jump_held(&"style_upper", false)
			var ok := absf(lab.player.position.x - target.x) < 15.0 and absf(lab.player.position.y + 18 - target.y) < 2.0
			if not ok: printerr("EXPECTED_UPPER_REFUSAL " if expected_refusal else "UPPER_STEP_FAIL ", label, " from=", start, " target=", target, " actual=", lab.player.position)
			return ok
	lab.controller.router.clear("upper_jump_timeout")
	printerr("UPPER_STEP_TIMEOUT ", label, " from=", start, " target=", target, " actual=", lab.player.position)
	return false

func _drop_to(lab: StyleLab, target: Vector2) -> bool:
	lab.controller.router.set_jump_held(&"style_upper", false)
	if not lab.player.request_drop_through(): return false
	for tick: int in 150:
		var difference := target.x - lab.player.position.x
		lab.controller.router.set_move_axis(signf(difference) if absf(difference) > 3.0 else 0.0)
		await physics_frame
		if lab.player.is_on_floor() and absf(lab.player.position.y + 18 - target.y) < 2.0 and absf(difference) < 5.0: return true
	return false

func _verify_upper_modules(lab: StyleLab) -> void:
	lab.restart()
	var epoch := lab.lifetime.actor_epoch
	for module: Dictionary in lab.layout.modules:
		var origin := float(module.origin.x * 32)
		var kind: String = module.id
		var before_steps := lab.player.motion_steps
		var before_jumps := int(lab.get_meta("accepted_jumps", 0))
		var steps: Array[Dictionary] = []
		var ok := await _walk_to(lab, origin + 80, 608)
		steps.append({"id": "walk_from_spawn_or_previous_module", "ok": ok, "position": str(lab.player.position)})
		if kind == "wind_terrace":
			ok = await _walk_to(lab, origin + 5.4 * 32, 576)
			steps.append({"id": "existing_lower_terrace", "ok": ok, "position": str(lab.player.position)})
		var first := Vector2(origin + (4.2 * 32 if kind in ["meadow", "wind_terrace"] else 2.3 * 32), 448 if kind == "wind_terrace" else 480)
		ok = await _jump_to(lab, first, kind + "/first_oneway")
		steps.append({"id": "first_oneway", "ok": ok, "position": str(lab.player.position)})
		var extra := Vector2(origin + 2.3 * 32, 384)
		if kind in ["arch", "bowl"]:
			ok = await _jump_to(lab, extra, kind + "/new_oneway_step")
			steps.append({"id": "upper_oneway_step", "ok": ok, "position": str(lab.player.position)})
		var top := Vector2(origin + (7.5 * 32 if kind in ["meadow", "wind_terrace"] else 4.6 * 32), 384 if kind == "meadow" else (352 if kind == "wind_terrace" else 320))
		ok = await _jump_to(lab, top, kind + "/solid_top")
		steps.append({"id": "solid_top", "ok": ok, "position": str(lab.player.position)})
		if kind == "arch":
			ok = await _walk_to(lab, origin + 11.0 * 32, 320)
			steps.append({"id": "arch_full_roof", "ok": ok, "position": str(lab.player.position)})
			ok = await _walk_to(lab, top.x, 320)
			steps.append({"id": "arch_roof_return", "ok": ok, "position": str(lab.player.position)})
		elif kind == "bowl":
			ok = await _walk_to(lab, origin + 7.5 * 32, 384)
			steps.append({"id": "bowl_inner_floor", "ok": ok, "position": str(lab.player.position)})
			ok = await _jump_to(lab, Vector2(origin + 10.8 * 32, 320), kind + "/right_lip")
			steps.append({"id": "bowl_right_lip", "ok": ok, "position": str(lab.player.position)})
			ok = await _walk_to(lab, origin + 7.5 * 32, 384)
			steps.append({"id": "bowl_inner_return", "ok": ok, "position": str(lab.player.position)})
			ok = await _jump_to(lab, top, kind + "/left_lip_return")
			steps.append({"id": "bowl_left_lip_return", "ok": ok, "position": str(lab.player.position)})
		ok = await _jump_to(lab, extra if kind in ["arch", "bowl"] else first, kind + "/return_oneway")
		steps.append({"id": "return_oneway", "ok": ok, "position": str(lab.player.position)})
		if kind in ["arch", "bowl"]:
			ok = await _drop_to(lab, first)
			steps.append({"id": "drop_to_first_oneway", "ok": ok, "position": str(lab.player.position)})
		ok = await _drop_to(lab, Vector2(origin + 80, 608))
		steps.append({"id": "return_to_main_ground", "ok": ok, "position": str(lab.player.position)})
		var completed := lab.lifetime.actor_epoch == epoch
		for step: Dictionary in steps:
			expect(step.ok, "upper %s seed %d %s %s" % [lab.style_id, lab.sample_seed, kind, step.id])
			completed = completed and step.ok
		expect(lab.lifetime.actor_epoch == epoch, "upper route never resets/teleports")
		upper_observations.append({"style": lab.style_id, "seed": lab.sample_seed, "kind": kind, "completed": completed, "steps": steps, "motor_steps": lab.player.motion_steps - before_steps, "accepted_jumps": int(lab.get_meta("accepted_jumps", 0)) - before_jumps, "actor_epoch_unchanged": lab.lifetime.actor_epoch == epoch})
