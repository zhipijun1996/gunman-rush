extends SceneTree
## Presentation-only region variants. Reuses the separately proven geometry-v2
## Motor routes; verifies that this switch cannot replace those physics consumers.
var checks := 0
var failures: Array[String] = []
var records: Array[Dictionary] = []

func _init() -> void:
	_run.call_deferred()

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("FAIL: " + label)

func _snapshot(lab: StyleLab) -> Dictionary:
	var collision_ids: Array[int] = []
	for child: Node in lab._world.get_children():
		if child is CollisionObject2D: collision_ids.append(child.get_instance_id())
	var atlas: Dictionary = {}
	for cell: Vector2i in lab.terrain.get_used_cells(): atlas[cell] = lab.terrain.get_cell_atlas_coords(cell)
	return {"player": lab.player.position, "camera": lab.camera.position, "player_id": lab.player.get_instance_id(),
		"actor_visual_id": lab.actor_visual.get_instance_id(), "session": lab.controller.session_id,
		"actor_epoch": lab.lifetime.actor_epoch, "motor_steps": lab.player.motion_steps,
		"tile_set": lab.terrain.tile_set.get_instance_id(), "atlas": atlas, "collision_ids": collision_ids,
		"layout": lab.layout.duplicate(true), "tuning": lab.player.tuning.get_instance_id(),
		"health": lab.controller.actor_resources.health.current, "shots": lab.controller.action_resources.shot_charges}

func _check_preserved(lab: StyleLab, before: Dictionary, label: String) -> void:
	var after := _snapshot(lab)
	for key: String in before:
		expect(after[key] == before[key], label + " preserves " + key)
	expect(StyleLayout.generate(lab.sample_seed) == before.layout, label + " preserves deterministic geometry RNG output")
	expect(lab.controller.router.axis == 0.0 and lab.controller.router._queue.is_empty(), label + " clears stale movement and action requests")
	expect(lab.scenery.get("biome_id") == lab.biome_id, label + " reaches the real scenery consumer")
	var palette_expected := lab.style_id != "underworld" or lab.biome_id != "plains"
	expect((lab.terrain.material != null) == palette_expected, label + " uses the admitted region ramp or original Underworld plains palette")
	for child: Node in lab._world.get_children():
		if child is StylePlatform: expect((child.material != null) == palette_expected, label + " uses the admitted one-way palette without replacing physics")

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	await process_frame

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var lab := preload("res://scenes/style_exploration/style_lab.tscn").instantiate() as StyleLab
	root.add_child(lab)
	for adapter: String in ["KeyboardMouseAdapter", "GamepadAdapter"]:
		lab.player.get_node(adapter).process_mode = Node.PROCESS_MODE_DISABLED
	for style: String in ["underworld", "cavern"]:
		for sample: int in 4:
			lab.select_style(style)
			lab.select_sample(sample)
			for tick: int in 20: await physics_frame
			lab._toggle_pause()
			var before := _snapshot(lab)
			for biome: String in ["forest", "gear"]:
				lab.controller.router.set_move_axis(1.0)
				lab.controller.router.request_action(&"shoot_release", Vector2.RIGHT)
				var button: Button = lab._forest_button if biome == "forest" else lab._gear_button
				expect(not button.disabled, "UI exposes admitted " + style + "/" + biome)
				button.pressed.emit()
				expect(lab.biome_id == biome, "UI button selects " + style + "/" + biome)
				_check_preserved(lab, before, "%s/%s/%d" % [style, biome, lab.sample_seed])
				expect(button.disabled and not lab._plains_button.disabled, "UI marks the selected region and permits return to plains")
				records.append({"style": style, "biome": biome, "seed": lab.sample_seed, "same_layout": lab.layout == before.layout,
					"same_tile_set": lab.terrain.tile_set.get_instance_id() == before.tile_set, "same_player_position": lab.player.position == before.player,
					"same_camera_position": lab.camera.position == before.camera, "same_motor_steps": lab.player.motion_steps == before.motor_steps,
					"scope": "pure presentation; no formal region/ability unlock or route traversal claim"})
				lab._plains_button.pressed.emit()
				expect(lab.biome_id == "plains", "UI restores original plains environment")
				_check_preserved(lab, before, "return_plains/%s/%d" % [style, lab.sample_seed])
			# Actual keyboard delivery works through the existing ALWAYS relay while paused.
			for expected: String in ["forest", "gear", "plains"]:
				await _key(KEY_B)
				expect(lab.biome_id == expected, "real B input cycles admitted biome while paused")
				_check_preserved(lab, before, "key_cycle/%s/%s/%d" % [style, expected, lab.sample_seed])
			lab._toggle_pause()
	expect(records.size() == 16, "two styles times two additional regions times four seeds are exercised")
	# Actual GUI mouse hit: this is separate from the button signal checks above.
	lab.select_style("underworld")
	lab.select_sample(0)
	for tick: int in 20: await physics_frame
	lab._toggle_pause()
	var mouse_before := _snapshot(lab)
	var point := lab._forest_button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	await process_frame
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = point
	mouse.global_position = point
	mouse.pressed = true
	Input.parse_input_event(mouse)
	await process_frame
	await process_frame
	mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = point
	mouse.global_position = point
	mouse.pressed = false
	Input.parse_input_event(mouse)
	await process_frame
	await process_frame
	expect(lab.biome_id == "forest", "actual mouse click reaches Forest button while paused")
	_check_preserved(lab, mouse_before, "actual_mouse_forest")
	# Unsupported styles keep all original plains samples and disable variants.
	for style: String in ["retro", "basic", "scribble"]:
		lab.select_style("underworld")
		lab.select_biome("gear")
		lab.select_style(style)
		expect(lab.biome_id == "plains" and lab.scenery.get("biome_id") == "plains", "unsupported style automatically returns to plains: " + style)
		expect(lab._forest_button.disabled and lab._gear_button.disabled, "unsupported variant buttons are disabled")
		lab.select_biome("forest")
		expect(lab.biome_id == "plains", "unsupported forest request does not open a region")
		lab.select_biome("gear")
		expect(lab.biome_id == "plains", "unsupported gear request does not open a region")
	lab.leave()
	lab.free()
	await process_frame
	await process_frame
	# Dedicated variant scenes are convenience art previews, using the same runtime.
	for style: String in ["underworld", "cavern"]:
		for biome: String in ["forest", "gear"]:
			var scene := load("res://scenes/style_exploration/%s_%s.tscn" % [style, biome]) as PackedScene
			var variant := scene.instantiate() as StyleLab
			root.add_child(variant)
			expect(variant.style_id == style and variant.biome_id == biome, "named art-preview scene opens its requested environment")
			expect(variant.layout == StyleLayout.generate(0), "named art-preview scene uses original comparison geometry")
			variant.leave()
			variant.free()
			await process_frame
			await process_frame
	var report := {"checks": checks, "failures": failures, "variants": records, "layout_version": StyleLayout.VERSION,
		"scope": "16 added presentation consumers; physics/lower and upper traversal reuse separately recorded runtime_v2 proofs because TileSet/cells/collision/motor/tuning are unchanged"}
	var path := "res://build/style_exploration/biome_report.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path = arg.trim_prefix("--report=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t")); file.close()
	else: expect(false, "biome report can be saved")
	print("STYLE_BIOMES checks=%d failures=%d variants=%d" % [checks, failures.size(), records.size()])
	quit(0 if failures.is_empty() else 1)
