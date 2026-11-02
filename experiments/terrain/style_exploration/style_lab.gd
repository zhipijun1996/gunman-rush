class_name StyleLab
extends Node2D
## Isolated, playable five-style experiment. Campaign state is never touched.
signal home_requested

class AlwaysKeyRelay:
	extends Node
	var receiver: Callable
	func _input(event: InputEvent) -> void:
		receiver.call(event)

@export var default_style := "retro"
@export var default_biome := "plains"
var style_id := "retro"
var biome_id := "plains"
var sample_seed := 0
var input_values: Dictionary = {}
var layout: Dictionary = {}
var player: PlayerMotor
var controller: PlayerController
var camera: Camera2D
var terrain: TileMapLayer
var scenery: Node2D
var actor_visual: Node2D
var overlay: TouchOverlay
var lifetime := DemoLifetime.new()
var _world: Node2D
var _ui: CanvasLayer
var _catalog: PanelContainer
var _catalog_grid: GridContainer
var _status: Label
var _plains_button: Button
var _forest_button: Button
var _gear_button: Button
var _paused := false
var _decor_enabled := true
var _background_enabled := true
var _lights_enabled := true
var _grid_enabled := false
var _capture_path := ""
var _capture_catalog := false
var _capture_x := 640.0
var _capture_frames := 0
const REGION_VARIANT_STYLES := ["underworld", "cavern"]
const BIOMES := ["plains", "forest", "gear"]
const STYLE_NAMES := ["1  Retro Lines", "2  Basic Fairy", "3  Scribble", "4  Underworld", "5  Cavern"]

func _ready() -> void:
	style_id = default_style
	biome_id = default_biome
	_parse_arguments()
	layout = StyleLayout.generate(sample_seed)
	assert(StyleLayout.validate(layout).is_empty())
	_world = Node2D.new()
	_world.name = "ComparisonTileWorld"
	add_child(_world)
	_install_world()
	player = preload("res://game/player/player.tscn").instantiate()
	player.position = layout.spawn
	player.get_node("CourierVisual").hide()
	player.get_node("PlayerVisualAdapter").process_mode = Node.PROCESS_MODE_DISABLED
	player.get_node("PlayerFeedback").hide()
	add_child(player)
	controller = player.get_node("Controller")
	controller.enable_shot_energy()
	if not input_values.is_empty(): controller.router.reconfigure(input_values)
	controller.died.connect(restart)
	overlay = InputSetup.attach_menu(player, controller.router, _toggle_pause)
	camera = Camera2D.new()
	camera.position = Vector2(640, 360)
	camera.limit_left = 0
	camera.limit_right = int(layout.bounds.end.x)
	camera.limit_top = 0
	camera.limit_bottom = int(layout.bounds.end.y)
	add_child(camera)
	camera.make_current()
	_install_presentation()
	_make_ui()
	if not _capture_path.is_empty():
		overlay.hide()
		for adapter: String in ["KeyboardMouseAdapter", "GamepadAdapter"]:
			player.get_node(adapter).process_mode = Node.PROCESS_MODE_DISABLED
		camera.position.x = _capture_x
		if _capture_catalog:
			_toggle_catalog()
			# Capture host keeps rendering while the interactive catalog normally pauses.
			get_tree().paused = false

func _parse_arguments() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--style="):
			var value := arg.trim_prefix("--style=")
			if value in StyleTerrain.STYLES: style_id = value
		elif arg.begins_with("--sample="):
			var value := arg.trim_prefix("--sample=").to_int()
			sample_seed = StyleLayout.SEEDS[value] if value >= 0 and value < 4 else value
		elif arg.begins_with("--biome="):
			var value := arg.trim_prefix("--biome=")
			if value in BIOMES: biome_id = value
		elif arg.begins_with("--seed="): sample_seed = arg.trim_prefix("--seed=").to_int()
		elif arg.begins_with("--capture="): _capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--camera-x="): _capture_x = arg.trim_prefix("--camera-x=").to_float()
		elif arg == "--catalog": _capture_catalog = true
	if style_id not in REGION_VARIANT_STYLES: biome_id = "plains"

func _install_world() -> void:
	terrain = StyleTerrain.build(layout.cells, style_id)
	_world.add_child(terrain)
	StyleTerrain.add_collision(_world, layout.cells)
	for rect: Rect2 in layout.one_way:
		var bridge := StylePlatform.new()
		bridge.name = "OneWayWoodBridge"
		bridge.position = rect.position
		bridge.bounds = Rect2(Vector2.ZERO, rect.size)
		bridge.style_id = style_id
		_world.add_child(bridge)
	_apply_region_palette()

func _install_presentation() -> void:
	if ResourceLoader.exists("res://game/presentation/world/style_exploration/style_scenery.gd"):
		var script := load("res://game/presentation/world/style_exploration/style_scenery.gd") as Script
		scenery = script.new() as Node2D
		scenery.name = "StyleScenery"
		add_child(scenery)
		scenery.call("configure", style_id, layout, camera, biome_id)
		_apply_layer_toggles()
	if ResourceLoader.exists("res://game/presentation/actors/style_exploration/style_actor_visual.gd"):
		var script := load("res://game/presentation/actors/style_exploration/style_actor_visual.gd") as Script
		actor_visual = script.new() as Node2D
		actor_visual.set("motor", player)
		actor_visual.set("controller", controller)
		actor_visual.set("style_id", style_id)
		player.add_child(actor_visual)
		if actor_visual.has_method("configure"): actor_visual.call("configure", style_id)

func select_style(value: String) -> void:
	assert(value in StyleTerrain.STYLES)
	if value == style_id: return
	controller.router.clear("style_comparison")
	controller.shoot_ability.reset()
	style_id = value
	if style_id not in REGION_VARIANT_STYLES: biome_id = "plains"
	StyleTerrain.change_style(terrain, style_id)
	for child: Node in _world.get_children():
		if child is StylePlatform: child.configure(style_id)
	_apply_region_palette()
	if is_instance_valid(scenery):
		scenery.call("configure", style_id, layout, camera, biome_id)
		_apply_layer_toggles()
	if is_instance_valid(actor_visual) and actor_visual.has_method("configure"): actor_visual.call("configure", style_id)
	_refresh_catalog()
	_refresh_biome_ui()

func select_biome(value: String) -> void:
	assert(value in BIOMES)
	var admitted := value if value == "plains" or style_id in REGION_VARIANT_STYLES else "plains"
	if admitted == biome_id: return
	controller.router.clear("style_environment")
	controller.shoot_ability.reset()
	biome_id = admitted
	_apply_region_palette()
	if is_instance_valid(scenery):
		scenery.call("configure", style_id, layout, camera, biome_id)
		_apply_layer_toggles()
	_refresh_catalog()
	_refresh_biome_ui()

func select_environment(value: String) -> void:
	select_biome(value)

func _apply_region_palette() -> void:
	var path := "res://game/presentation/world/style_exploration/style_palette.gd"
	if not ResourceLoader.exists(path): return
	var palette := load(path) as Script
	palette.call("apply", terrain, style_id, biome_id)
	for child: Node in _world.get_children():
		if child is StylePlatform: palette.call("apply", child, style_id, biome_id)

func _refresh_biome_ui() -> void:
	if not is_instance_valid(_plains_button): return
	_plains_button.disabled = biome_id == "plains"
	_forest_button.disabled = style_id not in REGION_VARIANT_STYLES or biome_id == "forest"
	_gear_button.disabled = style_id not in REGION_VARIANT_STYLES or biome_id == "gear"

func select_sample(index: int) -> void:
	assert(index >= 0 and index < StyleLayout.SEEDS.size())
	controller.router.clear("style_reseed")
	_close_panels()
	sample_seed = StyleLayout.SEEDS[index]
	layout = StyleLayout.generate(sample_seed)
	assert(StyleLayout.validate(layout).is_empty())
	for child: Node in _world.get_children(): child.free()
	_install_world()
	if is_instance_valid(scenery):
		scenery.call("configure", style_id, layout, camera, biome_id)
		_apply_layer_toggles()
	restart()

func restart() -> void:
	_close_panels()
	lifetime.invalidate_actor()
	controller.reset_at(layout.spawn)
	camera.position = Vector2(640, 360)

func _close_panels() -> void:
	if is_instance_valid(_catalog): _catalog.hide()
	_paused = false
	get_tree().paused = false

func _make_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 30
	_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui)
	var key_relay := AlwaysKeyRelay.new()
	key_relay.name = "PauseSafeComparisonKeys"
	key_relay.process_mode = Node.PROCESS_MODE_ALWAYS
	key_relay.receiver = _handle_key
	_ui.add_child(key_relay)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 8)
	panel.custom_minimum_size = Vector2(1256, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(.035, .055, .08, .91)
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 5
	panel_style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", panel_style)
	_ui.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	box.add_child(row)
	for index: int in StyleTerrain.STYLES.size():
		var target: String = StyleTerrain.STYLES[index]
		_button(row, STYLE_NAMES[index], func() -> void: select_style(target))
	var separator := VSeparator.new()
	row.add_child(separator)
	for index: int in StyleLayout.SEEDS.size():
		var sample_index := index
		_button(row, "S%d" % index, func() -> void: select_sample(sample_index))
	_button(row, "Tiles [T]", _toggle_catalog)
	_button(row, "Home", leave)
	_plains_button = _button(row, "Plains", func() -> void: select_biome("plains"))
	_forest_button = _button(row, "Forest", func() -> void: select_biome("forest"))
	_gear_button = _button(row, "Gear [B]", func() -> void: select_biome("gear"))
	_refresh_biome_ui()
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 5)
	box.add_child(tools)
	_button(tools, "Restart [R]", restart)
	_button(tools, "BG", func() -> void: _background_enabled = not _background_enabled; _apply_layer_toggles())
	_button(tools, "Decor", func() -> void: _decor_enabled = not _decor_enabled; _apply_layer_toggles())
	_button(tools, "Light", func() -> void: _lights_enabled = not _lights_enabled; _apply_layer_toggles())
	_button(tools, "Grid", func() -> void: _grid_enabled = not _grid_enabled; queue_redraw())
	_button(tools, "Pause", _toggle_pause)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Color("c5d7d2"))
	tools.add_child(_status)
	_catalog = PanelContainer.new()
	_catalog.position = Vector2(265, 110)
	_catalog.custom_minimum_size = Vector2(750, 570)
	var catalog_style := panel_style.duplicate() as StyleBoxFlat
	catalog_style.bg_color = Color("1c2733")
	_catalog.add_theme_stylebox_override("panel", catalog_style)
	_ui.add_child(_catalog)
	var catalog_box := VBoxContainer.new()
	_catalog.add_child(catalog_box)
	var heading := Label.new()
	heading.text = "47 canonical tiles / 32 world px / real atlas [T close]"
	heading.add_theme_font_size_override("font_size", 18)
	catalog_box.add_child(heading)
	_catalog_grid = GridContainer.new()
	_catalog_grid.columns = 8
	_catalog_grid.add_theme_constant_override("h_separation", 16)
	_catalog_grid.add_theme_constant_override("v_separation", 5)
	catalog_box.add_child(_catalog_grid)
	_refresh_catalog()
	_catalog.hide()

func _refresh_catalog() -> void:
	if not is_instance_valid(_catalog_grid): return
	for child: Node in _catalog_grid.get_children(): child.free()
	var texture := load(StyleTerrain.atlas_path(style_id)) as Texture2D
	var source_size := texture.get_width() / 8
	for mask: int in Blob47Rules.catalog_masks():
		var box := VBoxContainer.new()
		_catalog_grid.add_child(box)
		var image := TextureRect.new()
		var region := AtlasTexture.new()
		region.atlas = texture
		region.region = Rect2(Vector2(Blob47Rules.atlas_coords(mask) * source_size), Vector2.ONE * source_size)
		region.filter_clip = true
		image.texture = region
		StyleRegionPalette.apply(image, style_id, biome_id)
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.custom_minimum_size = Vector2(72, 56)
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(image)
		var label := Label.new()
		label.text = "%03d" % mask
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		box.add_child(label)

func _button(parent: Node, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.custom_minimum_size.y = 25
	button.pressed.connect(func() -> void: controller.router.clear("style_ui"); action.call())
	parent.add_child(button)
	return button

func _apply_layer_toggles() -> void:
	if not is_instance_valid(scenery): return
	for item: Array in [["set_decor_enabled", _decor_enabled], ["set_background_enabled", _background_enabled], ["set_lights_enabled", _lights_enabled]]:
		if scenery.has_method(item[0]): scenery.call(item[0], item[1])

func _toggle_catalog() -> void:
	_catalog.visible = not _catalog.visible
	controller.router.clear("style_catalog")
	get_tree().paused = _paused or _catalog.visible

func _toggle_pause() -> void:
	_paused = not _paused
	controller.router.clear("style_pause")
	get_tree().paused = _paused or _catalog.visible

func _handle_key(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.shift_pressed and event.physical_keycode >= KEY_0 and event.physical_keycode <= KEY_3:
		select_sample(event.physical_keycode - KEY_0)
	elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_5:
		select_style(StyleTerrain.STYLES[event.physical_keycode - KEY_1])
	elif event.physical_keycode == KEY_B and style_id in REGION_VARIANT_STYLES: select_biome(BIOMES[(BIOMES.find(biome_id) + 1) % BIOMES.size()])
	elif event.physical_keycode == KEY_T: _toggle_catalog()
	elif event.physical_keycode == KEY_R: restart()
	elif event.physical_keycode == KEY_ESCAPE: _toggle_pause()

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	if _capture_path.is_empty():
		camera.position = camera.position.lerp(Vector2(player.position.x + 220, 360), 1 - exp(-delta * 6))
	else:
		camera.position.x = _capture_x
		_capture_frames += 1
		if _capture_frames == 35: _save_capture.call_deferred()
	_status.text = "%s %s / seed %d / %d tiles  |  A D + Space  |  Shift 0-3 seeds" % [style_id, biome_id, sample_seed, layout.cells.size()]
	if player.position.y > layout.bounds.end.y + 100: restart()

func _save_capture() -> void:
	await RenderingServer.frame_post_draw
	var absolute := ProjectSettings.globalize_path(_capture_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var result := get_viewport().get_texture().get_image().save_png(absolute)
	var receipt := {"kind": "camera_only_art_capture", "traversal_claim": false, "style": style_id, "biome": biome_id, "seed": sample_seed, "layout_version": layout.version, "camera_position": {"x": camera.position.x, "y": camera.position.y}, "player_position": {"x": player.position.x, "y": player.position.y}, "motor_steps": player.motion_steps, "actor_epoch": lifetime.actor_epoch, "png": absolute, "error": result}
	var metadata := FileAccess.open(absolute + ".json", FileAccess.WRITE)
	if metadata != null:
		metadata.store_string(JSON.stringify(receipt, "\t"))
		metadata.close()
	print("STYLE_CAPTURE style=%s biome=%s seed=%d camera_x=%.2f player_x=%.2f view=camera_only path=%s error=%d" % [style_id, biome_id, sample_seed, camera.position.x, player.position.x, absolute, result])
	leave()
	queue_free()
	get_tree().quit(0 if result == OK else 1)

func leave() -> void:
	controller.router.clear("style_leave")
	controller.shoot_ability.reset()
	controller.traversal.cancel()
	get_tree().paused = false
	home_requested.emit()

func _exit_tree() -> void:
	lifetime.end()
	if is_instance_valid(controller):
		controller.shoot_ability.reset()
		controller.traversal.cancel()
		controller.air_focus_ability.stop()
	get_tree().paused = false

func _draw() -> void:
	if not _grid_enabled or layout.is_empty(): return
	for x: int in range(0, int(layout.bounds.end.x) + 1, 32): draw_line(Vector2(x, 0), Vector2(x, layout.bounds.end.y), Color(1, 1, 1, .13))
	for y: int in range(0, int(layout.bounds.end.y) + 1, 32): draw_line(Vector2(0, y), Vector2(layout.bounds.end.x, y), Color(1, 1, 1, .13))
