class_name Blob47Lab
extends Node2D
## A playable foundation candidate, not a replacement for the full campaign.
signal home_requested
var seed_text := "foundation-01"
var input_values: Dictionary = {}
var layout: Dictionary
var player: PlayerMotor
var controller: PlayerController
var camera: Camera2D
var terrain: TileMapLayer
var decoration: Blob47Decoration
var backdrop: Blob47Backdrop
var overlay: TouchOverlay
var policy: FrameDamagePolicy
var lifetime := DemoLifetime.new()
var show_grid := false
var _catalog: Control
var _status: Label
var _world: Node2D
var _seed_index := 1
var _paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	layout = Blob47Layout.generate(seed_text)
	assert(layout.ok, "Tile layout rejected")
	var background_layer := CanvasLayer.new()
	background_layer.layer = -20
	add_child(background_layer)
	backdrop = Blob47Backdrop.new()
	background_layer.add_child(backdrop)
	_world = Node2D.new()
	_world.name = "TileWorld"
	add_child(_world)
	_install_world()
	player = preload("res://game/player/player.tscn").instantiate()
	player.position = layout.spawn
	# Reuse ONLY the actual player mechanics. No old visual is a study input.
	player.get_node("CourierVisual").hide()
	player.get_node("PlayerVisualAdapter").process_mode = Node.PROCESS_MODE_DISABLED
	player.get_node("PlayerFeedback").hide()
	add_child(player)
	controller = player.get_node("Controller")
	controller.enable_shot_energy()
	if not input_values.is_empty(): controller.router.reconfigure(input_values)
	var actor_visual := Blob47PlayerVisual.new()
	actor_visual.motor = player
	actor_visual.controller = controller
	player.add_child(actor_visual)
	overlay = InputSetup.attach_menu(player, controller.router, _toggle_pause)
	camera = Camera2D.new()
	camera.position = Vector2(640, 360)
	camera.limit_left = 0
	camera.limit_right = int(layout.bounds.end.x)
	camera.limit_top = 0
	camera.limit_bottom = int(layout.bounds.end.y)
	add_child(camera)
	camera.make_current()
	policy = FrameDamagePolicy.new()
	policy.lifetime = lifetime
	add_child(policy)
	policy.register_target(&"player", controller.actor_resources.health, true)
	policy.player_fatal.connect(controller.die)
	policy.environment_return_requested.connect(restart)
	_install_hazards()
	_make_ui()
	queue_redraw()

func _install_world() -> void:
	terrain = Blob47Terrain.build(layout.cells, seed_text)
	_world.add_child(terrain)
	Blob47Terrain.add_collision(_world, layout.cells)
	for rect: Rect2 in layout.one_way:
		var platform := Blob47Platform.new()
		platform.position = rect.position
		platform.bounds = Rect2(Vector2.ZERO, Vector2(rect.size.x, 10))
		platform.one_way = true
		_world.add_child(platform)
	for item: Dictionary in layout.moving:
		var platform := Blob47Platform.new()
		platform.position = item.rect.position
		platform.bounds = Rect2(Vector2.ZERO, item.rect.size)
		platform.travel = item.travel
		platform.period = item.period
		_world.add_child(platform)
	decoration = Blob47Decoration.new()
	var keepouts: Array[Rect2] = []
	keepouts.assign(layout.keepouts)
	keepouts.append(Rect2(layout.spawn - Vector2(40, 50), Vector2(80, 90)))
	decoration.configure(layout.cells, keepouts, seed_text)
	_world.add_child(decoration)

func _install_hazards() -> void:
	for index: int in layout.hazards.size():
		var rect: Rect2 = layout.hazards[index]
		var emitter := DemoContactEmitter.environment_rect(rect, policy, controller, StringName("blob47/spikes/" + str(index)))
		_world.add_child(emitter)

func _make_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 14)
	panel.custom_minimum_size.x = 820
	panel.add_theme_stylebox_override("panel", Blob47Platform._box(Color("f1e7cc"), Color("5a6558")))
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var heading := Label.new()
	heading.text = "  NEW ART FOUNDATION  /  TILE GARDEN  "
	heading.add_theme_color_override("font_color", Color("3b554b"))
	heading.add_theme_font_size_override("font_size", 20)
	box.add_child(heading)
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color("5b6455"))
	_status.add_theme_font_size_override("font_size", 13)
	box.add_child(_status)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	box.add_child(row)
	_button(row, "Restart", restart)
	_button(row, "Next seed", _next_seed)
	_button(row, "47 tiles", _toggle_catalog)
	_button(row, "Grid", func() -> void: show_grid = not show_grid; queue_redraw())
	_button(row, "Decor", func() -> void: decoration.visible = not decoration.visible)
	_button(row, "Depth", func() -> void: backdrop.middle_enabled = not backdrop.middle_enabled; backdrop.far_enabled = backdrop.middle_enabled)
	_button(row, "Light", func() -> void: decoration.lights_enabled = not decoration.lights_enabled; decoration.queue_redraw())
	_button(row, "Pause", _toggle_pause)
	_button(row, "Home", leave)
	var hint := Label.new()
	hint.text = " A/D move   Space jump   Release mouse to fire   |   Candidate v1 - visual approval pending "
	hint.add_theme_color_override("font_color", Color("5b6455"))
	hint.add_theme_font_size_override("font_size", 13)
	box.add_child(hint)
	_catalog = Panel.new()
	_catalog.position = Vector2(140, 160)
	_catalog.size = Vector2(1000, 500)
	_catalog.add_theme_stylebox_override("panel", Blob47Platform._box(Color("f1e7cc"), Color("5a6558")))
	_catalog.hide()
	layer.add_child(_catalog)
	var title := Label.new()
	title.text = "47 canonical masks  |  N=1 NE=2 E=4 SE=8 S=16 SW=32 W=64 NW=128"
	title.position = Vector2(20, 14)
	title.add_theme_color_override("font_color", Color("3b554b"))
	title.add_theme_font_size_override("font_size", 18)
	_catalog.add_child(title)
	var masks := Blob47Rules.catalog_masks()
	for index: int in masks.size():
		var at := Blob47Rules.atlas_coords(masks[index])
		var texture := AtlasTexture.new()
		texture.atlas = Blob47Terrain.ATLAS
		texture.region = Rect2(Vector2(at * Blob47Rules.PITCH + Vector2i.ONE * Blob47Rules.GUTTER), Vector2.ONE * Blob47Rules.SOURCE_SIZE)
		texture.filter_clip = true
		var image := TextureRect.new()
		image.texture = texture
		image.position = Vector2(20 + (index % 12) * 81, 58 + (index / 12) * 105)
		image.size = Vector2(64, 64)
		_catalog.add_child(image)
		var label := Label.new()
		label.text = "%03d" % masks[index]
		label.position = image.position + Vector2(16, 65)
		label.add_theme_color_override("font_color", Color("3b554b"))
		_catalog.add_child(label)

func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: controller.router.clear("foundation_ui"); action.call())
	parent.add_child(button)

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	camera.position = camera.position.lerp(Vector2(player.position.x + 260, 360), 1 - exp(-delta * 6))
	_status.text = "  %s  |  %s  |  %d tiles / %d props  |  HP %.0f" % [seed_text, layout.version, layout.cells.size(), decoration.placements.size(), controller.actor_resources.health.current]
	if player.position.y > layout.bounds.end.y + 80: restart()

func restart() -> void:
	# Restart/reseed explicitly closes the catalog before resuming simulation.
	if is_instance_valid(_catalog): _catalog.hide()
	get_tree().paused = false
	_paused = false
	lifetime.invalidate_actor()
	controller.reset_at(layout.spawn)
	policy.protect_player()

func _next_seed() -> void:
	controller.router.clear("foundation_seed")
	_seed_index += 1
	seed_text = "foundation-%02d" % _seed_index
	layout = Blob47Layout.generate(seed_text)
	assert(layout.ok)
	for child: Node in _world.get_children(): child.free()
	_install_world()
	_install_hazards()
	queue_redraw()
	restart()

func _toggle_catalog() -> void:
	_catalog.visible = not _catalog.visible
	controller.router.clear("foundation_catalog")
	get_tree().paused = _catalog.visible or _paused

func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused or _catalog.visible
	controller.router.clear("foundation_pause")

func leave() -> void:
	controller.router.clear("foundation_leave")
	controller.shoot_ability.reset()
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
	if layout.is_empty() or not layout.ok: return
	for rect: Rect2 in layout.hazards:
		for x: int in range(int(rect.position.x), int(rect.end.x), 8):
			var points := PackedVector2Array([Vector2(x, rect.end.y), Vector2(x + 4, rect.position.y), Vector2(x + 8, rect.end.y)])
			draw_colored_polygon(points, Color("b34f47"))
			draw_polyline(points, Color("493d3d"), 1.5)
	if show_grid:
		for x: int in range(0, int(layout.bounds.end.x) + 1, 32):
			draw_line(Vector2(x, 0), Vector2(x, layout.bounds.end.y), Color(1, 1, 1, .16))
		for y: int in range(0, int(layout.bounds.end.y) + 1, 32):
			draw_line(Vector2(0, y), Vector2(layout.bounds.end.x, y), Color(1, 1, 1, .16))
