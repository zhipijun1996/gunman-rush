class_name HomeScene
extends Node2D
## Safe, fixed Home consumer. All locomotion goes through the real PlayerMotor.
signal requested_interaction(function_id: StringName)
signal requested_navigation
const FLOOR_Y := 432.0
const NPCS := [
	{"id": &"character", "x": 250.0, "name": "Wardrobe / Character", "region": Rect2(0, 0, 660, 887), "pivot": Vector2(351, 874)},
	{"id": &"upgrade", "x": 600.0, "name": "Artisan / Permanent upgrades", "region": Rect2(660, 0, 530, 887), "pivot": Vector2(253, 873)},
	{"id": &"achievements", "x": 930.0, "name": "Archivist / Achievements", "region": Rect2(1190, 0, 584, 887), "pivot": Vector2(288.5, 875)},
	{"id": &"departure", "x": 1160.0, "name": "Plains / Begin adventure"},
]
var player: PlayerMotor
var controller: PlayerController
var camera: Camera2D
var nearest_id: StringName = &""
var input_blocked := false
var _status: Label
var _prompt: Label
var _controls: HBoxContainer
var _hud: CanvasLayer

func _ready() -> void:
	var background := Sprite2D.new()
	background.texture = load("res://assets/title_home/home_background.png")
	background.centered = false
	background.scale = Vector2(1280.0 / 1672.0, 720.0 / 941.0)
	background.z_index = -10
	add_child(background)
	_ground(Rect2(-100, FLOOR_Y, 1480, 160))
	_ground(Rect2(-28, -400, 28, 850))
	_ground(Rect2(1280, -400, 28, 850))
	for entry: Dictionary in NPCS:
		if not entry.has("region") or entry.id != &"upgrade":
			continue
		var sprite := Sprite2D.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = load("res://assets/title_home/npcs.png")
		atlas.region = entry.region
		sprite.texture = atlas
		sprite.centered = false
		sprite.scale = Vector2.ONE * 0.095
		sprite.position = Vector2(entry.x, FLOOR_Y) - entry.pivot * sprite.scale
		add_child(sprite)
	player = preload("res://scenes/player/player.tscn").instantiate() as PlayerMotor
	player.position = Vector2(110, FLOOR_Y - 18)
	add_child(player)
	controller = player.get_node("Controller") as PlayerController
	controller.shoot_ability.enabled = false
	controller.air_focus_ability.enabled = false
	controller.interact_requested.connect(interact)
	var pad := GamepadAdapter.new()
	pad.name = "GamepadAdapter"
	pad.router = controller.router
	pad.aim_origin = player
	player.add_child(pad)
	camera = Camera2D.new()
	camera.position = Vector2(640, 360)
	add_child(camera)
	camera.make_current()
	_hud = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)
	var top := HBoxContainer.new()
	top.theme = DemoMenu.create_theme()
	top.position = Vector2(24, 16)
	top.size = Vector2(1232, 52)
	_hud.add_child(top)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 24)
	_status.add_theme_color_override("font_shadow_color", Color(0.08, 0.05, 0.06, 0.95))
	_status.add_theme_constant_override("shadow_offset_x", 2)
	_status.add_theme_constant_override("shadow_offset_y", 2)
	_status.add_theme_color_override("font_color", Color("f5e6be"))
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_status)
	var menu_button := Button.new()
	menu_button.text = "MENU / SETTINGS"
	menu_button.custom_minimum_size = Vector2(200, 48)
	menu_button.pressed.connect(func() -> void: requested_navigation.emit())
	top.add_child(menu_button)
	_prompt = Label.new()
	_prompt.position = Vector2(340, 550)
	_prompt.size = Vector2(600, 62)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 24)
	_prompt.add_theme_color_override("font_shadow_color", Color(0.08, 0.05, 0.06, 0.95))
	_prompt.add_theme_constant_override("shadow_offset_x", 2)
	_prompt.add_theme_constant_override("shadow_offset_y", 2)
	_prompt.add_theme_color_override("font_color", Color("ffe6a0"))
	_hud.add_child(_prompt)
	_controls = HBoxContainer.new()
	_controls.theme = DemoMenu.create_theme()
	_controls.position = Vector2(32, 636)
	_controls.add_theme_constant_override("separation", 12)
	_hud.add_child(_controls)
	_touch_button("LEFT", -1.0)
	_touch_button("RIGHT", 1.0)
	var interaction := Button.new()
	interaction.text = "INTERACT"
	interaction.custom_minimum_size = Vector2(150, 60)
	interaction.pressed.connect(func() -> void:
		if not input_blocked:
			controller.router.activate_device(&"touch")
			controller.router.request_action(&"interact"))
	_controls.add_child(interaction)
	controller.router.touch_enabled = OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()
	set_meta_state({"notes": 0})

func _ground(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func set_meta_state(snapshot: Dictionary) -> void:
	if _status != null:
		_status.text = "FLOWERLIGHT HOME    /    NOTES %s" % snapshot.get("notes", 0)

func nearest_candidate(point: Vector2) -> StringName:
	var candidates: Array[Dictionary] = []
	for entry: Dictionary in NPCS:
		var distance := point.distance_to(Vector2(entry.x, FLOOR_Y - 18))
		var threshold := 115.0 if entry.id == nearest_id else 90.0
		if distance <= threshold:
			candidates.append({"id": entry.id, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.id) < str(b.id) if is_equal_approx(a.distance, b.distance) else a.distance < b.distance)
	return candidates[0].id if not candidates.is_empty() else &""

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	nearest_id = nearest_candidate(player.position)
	_prompt.text = "Walk to a keeper or the gate. W / Up to interact."
	for entry: Dictionary in NPCS:
		if entry.id == nearest_id:
			_prompt.text = "%s\nW / Up / Left stick up / INTERACT" % entry.name
	_controls.visible = not input_blocked and controller.router.touch_enabled and controller.router.current_device != &"gamepad"
	# No aim controls or combat in Home; shot input cannot create projectiles.
	controller.router.aim_engaged = false

func interact() -> void:
	if input_blocked or nearest_id.is_empty():
		return
	requested_interaction.emit(nearest_id)

func set_input_blocked(blocked: bool) -> void:
	input_blocked = blocked
	if not is_instance_valid(controller):
		return
	controller.router.clear("home_panel" if blocked else "home_panel_closed")
	controller.motor.reset_motion()
	controller.active = not blocked
	var keyboard := player.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter
	if not blocked:
		keyboard.observe_current_key_neutral()
	keyboard.set_process_unhandled_input(not blocked)
	player.get_node("GamepadAdapter").set_physics_process(not blocked)
	_controls.visible = not blocked and controller.router.touch_enabled

func _touch_button(text: String, axis: float) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(115, 60)
	button.button_down.connect(func() -> void:
		if not input_blocked:
			controller.router.activate_device(&"touch")
			controller.router.set_source_axis(&"touch", axis))
	button.button_up.connect(func() -> void: controller.router.set_source_axis(&"touch", 0.0))
	_controls.add_child(button)

func _unhandled_input(event: InputEvent) -> void:
	if not input_blocked and event.is_action_pressed("ui_cancel"):
		requested_navigation.emit()
		get_viewport().set_input_as_handled()
