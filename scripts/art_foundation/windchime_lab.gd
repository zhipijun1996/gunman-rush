class_name WindchimeLab
extends Node2D
## Wind Chime Plains hand-composed art/gameplay sample. Formal campaign unchanged.
signal home_requested
var seed_text := "windchime-01"
var input_values: Dictionary = {}
var layout: Dictionary
var player: PlayerMotor
var controller: PlayerController
var camera: Camera2D
var terrain: TileMapLayer
var decoration: WindchimeDecoration
var backdrop: WindchimeBackdrop
var overlay: TouchOverlay
var policy: FrameDamagePolicy
var lifetime := DemoLifetime.new()
var show_grid := false
var _catalog: Control
var _world: Node2D
var _paused := false
var _material_mode := false
var _health_hud: WindchimeHUD
var _enemy_motors: Array[EnemyMotor] = []
var scenery: WindchimeScenery
var masonry: WindchimeMasonry

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	layout = _make_layout()
	assert(layout.ok, "Tile layout rejected")
	var background_layer := CanvasLayer.new()
	background_layer.layer = -20
	add_child(background_layer)
	backdrop = _make_backdrop()
	background_layer.add_child(backdrop)
	_world = Node2D.new()
	_world.name = "TileWorld"
	add_child(_world)
	_install_world()
	player = preload("res://scenes/player/player.tscn").instantiate()
	player.position = layout.spawn
	# Reuse ONLY the actual player mechanics. No old visual is a study input.
	player.get_node("CourierVisual").hide()
	player.get_node("PlayerVisualAdapter").process_mode = Node.PROCESS_MODE_DISABLED
	player.get_node("PlayerFeedback").hide()
	add_child(player)
	controller = player.get_node("Controller")
	controller.enable_shot_energy()
	controller.shoot_ability.shot_fired.connect(_skin_projectiles)
	if not input_values.is_empty(): controller.router.reconfigure(input_values)
	var actor_visual := _make_actor_visual()
	actor_visual.motor = player
	actor_visual.controller = controller
	player.add_child(actor_visual)
	overlay = InputSetup.attach(player, controller.router)
	overlay.hide_reset_button = true
	overlay.pause_requested.connect(_toggle_pause)
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
	_install_enemies()
	_make_ui()
	queue_redraw()

func _make_layout() -> Dictionary:
	return WindchimeLayout.build_map(seed_text)

func _make_backdrop() -> WindchimeBackdrop:
	return WindchimeBackdrop.new()

func _make_actor_visual() -> WindchimeActorVisual:
	return WindchimeActorVisual.new()

func _make_enemy_visual() -> WindchimeEnemyVisual:
	return WindchimeEnemyVisual.new()

func _make_projectile_visual() -> WindchimeProjectileVisual:
	return WindchimeProjectileVisual.new()

func _install_world() -> void:
	terrain = WindchimeTerrain.build(layout.cells, seed_text)
	_world.add_child(terrain)
	masonry = WindchimeMasonry.new()
	masonry.configure(layout.cells)
	_world.add_child(masonry)
	Blob47Terrain.add_collision(_world, layout.cells)
	for rect: Rect2 in layout.one_way:
		var platform := WindchimePlatform.new()
		platform.position = rect.position
		platform.bounds = Rect2(Vector2.ZERO, Vector2(rect.size.x, 10))
		platform.one_way = true
		_world.add_child(platform)
	for item: Dictionary in layout.moving:
		var platform := WindchimePlatform.new()
		platform.position = item.rect.position
		platform.bounds = Rect2(Vector2.ZERO, item.rect.size)
		platform.travel = item.travel
		platform.period = item.period
		_world.add_child(platform)
	decoration = WindchimeDecoration.new()
	var keepouts: Array[Rect2] = []
	keepouts.assign(layout.keepouts)
	keepouts.append(Rect2(layout.spawn - Vector2(40, 50), Vector2(80, 90)))
	decoration.configure(layout.cells, keepouts, seed_text)
	_world.add_child(decoration)
	scenery = WindchimeScenery.new()
	scenery.sockets.assign(layout.get("sockets", []))
	scenery.one_way.assign(layout.one_way)
	_world.add_child(scenery)

func _install_hazards() -> void:
	for index: int in layout.hazards.size():
		var rect: Rect2 = layout.hazards[index]
		var emitter := DemoContactEmitter.new()
		emitter.position = rect.get_center()
		emitter.half_size = rect.size / 2
		emitter.policy = policy
		emitter.controller = controller
		emitter.source_id = StringName("blob47/spikes/" + str(index))
		emitter.kind = DamageRequest.Kind.ENVIRONMENT
		_world.add_child(emitter)

func _make_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_health_hud = WindchimeHUD.new()
	_health_hud.controller = controller
	_health_hud.lab = self
	layer.add_child(_health_hud)
	var row := HBoxContainer.new()
	row.position = Vector2(22, 91)
	row.add_theme_constant_override("separation", 6)
	layer.add_child(row)
	_button(row, "Restart", restart)
	_button(row, "Materials", _toggle_material_map)
	_button(row, "47 tiles", _toggle_catalog)
	_button(row, "Pause", _toggle_pause)
	_button(row, "Home", leave)
	_catalog = Panel.new()
	_catalog.position = Vector2(130, 155)
	_catalog.size = Vector2(1020, 500)
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("173341")
	skin.border_color = Color("baa56c")
	skin.set_border_width_all(1)
	_catalog.add_theme_stylebox_override("panel", skin)
	_catalog.hide()
	layer.add_child(_catalog)
	var title := Label.new()
	title.text = "LIMESTONE / 47 CANONICAL MASKS     •     CLOSE TO RESUME"
	title.position = Vector2(24, 15)
	title.add_theme_color_override("font_color", Color("eee2bb"))
	title.add_theme_font_size_override("font_size", 17)
	_catalog.add_child(title)
	var masks := Blob47Rules.catalog_masks()
	for index: int in masks.size():
		var at := Blob47Rules.atlas_coords(masks[index])
		var texture := AtlasTexture.new()
		texture.atlas = WindchimeTerrain.ATLAS
		texture.region = Rect2(Vector2(at * Blob47Rules.PITCH + Vector2i.ONE * Blob47Rules.GUTTER), Vector2.ONE * Blob47Rules.SOURCE_SIZE)
		texture.filter_clip = true
		var image := TextureRect.new()
		image.texture = texture
		image.position = Vector2(24 + (index % 12) * 81, 58 + (index / 12) * 105)
		image.size = Vector2(64, 64)
		_catalog.add_child(image)
		var label := Label.new()
		label.text = "%03d" % masks[index]
		label.position = image.position + Vector2(16, 65)
		label.add_theme_color_override("font_color", Color("d8c99d"))
		_catalog.add_child(label)

func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color("eee2bb"))
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(.05, .14, .18, .85)
	skin.set_content_margin_all(7)
	button.add_theme_stylebox_override("normal", skin)
	button.pressed.connect(func() -> void: controller.router.clear("foundation_ui"); action.call())
	parent.add_child(button)

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	camera.position = camera.position.lerp(Vector2(player.position.x + 230, clampf(player.position.y - 80, 360, layout.bounds.end.y - 360)), 1 - exp(-delta * 6))

	if player.position.y > layout.bounds.end.y + 80: restart()

func restart() -> void:
	# Restart/reseed explicitly closes the catalog before resuming simulation.
	if is_instance_valid(_catalog): _catalog.hide()
	get_tree().paused = false
	_paused = false
	# Restart is an explicit new sample attempt, including enemies and registry.
	# A fatal policy ended the old lifetime; never reactivate it or reuse its tokens.
	var previous := lifetime
	previous.end()
	lifetime = DemoLifetime.new()
	lifetime.epoch = previous.epoch + 1
	lifetime.stage_epoch = previous.stage_epoch + 1
	lifetime.actor_epoch = previous.actor_epoch + 1
	controller.reset_at(layout.spawn)
	for child: Node in _world.get_children(): child.free()
	_enemy_motors.clear()
	policy.free()
	policy = FrameDamagePolicy.new()
	policy.lifetime = lifetime
	add_child(policy)
	policy.register_target(&"player", controller.actor_resources.health, true)
	policy.player_fatal.connect(controller.die)
	policy.environment_return_requested.connect(restart)
	_install_world()
	_install_hazards()
	_install_enemies()
	policy.protect_player()

func _toggle_material_map() -> void:
	controller.router.clear("windchime_map")
	_material_mode = not _material_mode
	layout = WindchimeLayout.material_map(seed_text) if _material_mode else WindchimeLayout.build_map(seed_text)
	assert(layout.ok)
	camera.limit_right = int(layout.bounds.end.x)
	camera.limit_bottom = int(layout.bounds.end.y)
	camera.position = Vector2(640,360)
	queue_redraw()
	restart()

func _skin_projectiles(_aim: Vector2, _shot_id: int) -> void:
	for projectile: PlayerProjectile in controller.shoot_ability.get_projectiles():
		if is_instance_valid(projectile.presentation): continue
		var visual := _make_projectile_visual()
		visual.projectile = projectile
		projectile.presentation = visual
		projectile.add_child(visual)

func _install_enemies() -> void:
	for socket: Dictionary in layout.get("sockets", []):
		if socket.kind != &"enemy": continue
		var enemy := preload("res://scenes/enemies/patrol_drone.tscn").instantiate() as EnemyMotor
		enemy.position = Vector2(socket.position) - Vector2(0,16)
		# Only the existing enemy mechanics/definition are reused.
		var old := enemy.get_node("Presentation")
		enemy.remove_child(old)
		old.free()
		_world.add_child(enemy)
		var actor := enemy.get_node("Actor") as EnemyActor
		var visual := _make_enemy_visual()
		visual.actor = actor
		enemy.add_child(visual)
		var id := StringName("windchime/enemy/" + str(_enemy_motors.size()))
		# Stage recreation owns a fresh policy; entries from freed actors are removed.
		policy.bind_damageable(id, actor.damageable, actor.health)
		var contact := DemoContactEmitter.new()
		contact.policy = policy
		contact.controller = controller
		contact.source_id = id
		contact.half_size = actor.definition.collision_size / 2
		enemy.add_child(contact)
		actor.defeated.connect(func(_actor: EnemyActor) -> void: contact.enabled = false)
		_enemy_motors.append(enemy)

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
			draw_colored_polygon(points, Color("dc6e5d"))
			draw_polyline(points, Color("642e33"), 1.5)
	if show_grid:
		for x: int in range(0, int(layout.bounds.end.x) + 1, Blob47Rules.CELL):
			draw_line(Vector2(x, 0), Vector2(x, layout.bounds.end.y), Color(1, 1, 1, .16))
		for y: int in range(0, int(layout.bounds.end.y) + 1, Blob47Rules.CELL):
			draw_line(Vector2(0, y), Vector2(layout.bounds.end.x, y), Color(1, 1, 1, .16))
