class_name HomeScene
extends Node2D
## Safe, fixed Home consumer. All locomotion goes through the real PlayerMotor.
signal requested_interaction(function_id: StringName)
signal requested_navigation
const FLOOR_Y := 432.0
var world: UnderworldHomeWorld
var parallax: UnderworldParallax
var reserved_id := ""
const FUNCTION_NAMES := {"character":"衣装守护者 / Character","upgrade":"维修工坊 / Permanent upgrades","achievements":"钟之档案 / Achievements","departure":"走出聚落 · 风铃平原 / Begin adventure"}
var player: PlayerMotor
var controller: PlayerController
var camera: Camera2D
var nearest_id: StringName = &""
var input_blocked := false
var _status: Label
var _prompt: Label
var _controls: HBoxContainer
var overlay: TouchOverlay
var _resource_hud: ActorResourcesHud
var _hud: CanvasLayer

func _ready() -> void:
	world=UnderworldHomeWorld.new()
	add_child(world)
	world.configure(FLOOR_Y)
	var width:=float(world.specification.world_width)
	_ground(Rect2(-100,FLOOR_Y,width+200,640))
	_ground(Rect2(-28,-400,28,1100))
	_ground(Rect2(width,-400,28,1100))
	for platform: Dictionary in world.specification.get("platforms",[]):
		var rect: Array=platform.rect
		_ground(Rect2(rect[0],rect[1],rect[2],rect[3]),true,str(platform.id))
	player = preload("res://scenes/player/player.tscn").instantiate() as PlayerMotor
	player.position = Vector2(110, FLOOR_Y - 18)
	add_child(player)
	controller = player.get_node("Controller") as PlayerController
	controller.enable_shot_energy()
	controller.interact_requested.connect(interact)
	overlay=InputSetup.attach(player,controller.router)
	overlay.hide_reset_button=true
	overlay.pause_label="MENU"
	overlay.pause_requested.connect(func()->void:requested_navigation.emit())
	var guide:=DemoAimGuide.new();guide.controller=controller;player.add_child(guide)
	var vignette:=FocusVignette.new();vignette.ability=controller.air_focus_ability;player.add_child(vignette)
	camera = Camera2D.new()
	camera.position = Vector2(640, float(world.specification.get("camera_y",360)))
	add_child(camera)
	camera.make_current()
	parallax=UnderworldParallax.new()
	parallax.configure(camera)
	add_child(parallax)
	player.get_node("CourierVisual").hide()
	player.get_node("PlayerVisualAdapter").process_mode=Node.PROCESS_MODE_DISABLED
	player.get_node("PlayerFeedback").hide()
	var art:=UnderworldPlayer.new()
	art.motor=player
	art.controller=controller
	art.name="UnderworldPlayer"
	player.add_child(art)
	_hud = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)
	var backing:=ColorRect.new();backing.position=Vector2(12,8);backing.size=Vector2(340,132);backing.color=Color(.055,.10,.095,.84);backing.mouse_filter=Control.MOUSE_FILTER_IGNORE;_hud.add_child(backing)
	var top := HBoxContainer.new()
	top.theme = DemoMenu.create_theme()
	top.position = Vector2(370, 16)
	top.size = Vector2(886, 52)
	_hud.add_child(top)
	_resource_hud=ActorResourcesHud.new();_resource_hud.position=Vector2(2,0);_hud.add_child(_resource_hud);_resource_hud.bind(controller.actor_resources,controller.air_focus_ability,controller);_resource_hud.set_region_compact(true)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 18)
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
	var prompt_backing:=ColorRect.new();prompt_backing.position=Vector2(325,544);prompt_backing.size=Vector2(650,82);prompt_backing.color=Color(.055,.10,.095,.84);prompt_backing.mouse_filter=Control.MOUSE_FILTER_IGNORE;_hud.add_child(prompt_backing)
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
	_controls.position = Vector2(390, 636)
	_controls.add_theme_constant_override("separation", 12)
	_hud.add_child(_controls)
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
	UnderworldUI.style_canvas(_hud)

func _ground(rect: Rect2,one_way: bool=false,id: String="") -> void:
	var body := StaticBody2D.new()
	if not id.is_empty():body.name=id
	if one_way:body.add_to_group("one_way_platform")
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	collision.name="CollisionShape2D"
	collision.one_way_collision=one_way
	body.add_child(collision)
	add_child(body)

func set_meta_state(snapshot: Dictionary) -> void:
	if _status != null:
		_status.text = "风铃聚落 / WINDCHIME HOME    ·    NOTES %s" % snapshot.get("notes", 0)

func nearest_candidate(point: Vector2) -> StringName:
	var candidates: Array[Dictionary] = []
	for entry: Dictionary in world.specification.slots:
		if not bool(entry.active):continue
		var foot:=slot_world_foot(StringName(entry.id))
		var distance:=absf(point.x-foot.x)
		var threshold := 115.0 if StringName(entry.id) == nearest_id else 90.0
		# Tier proximity is deliberate: a lower-floor player must never open an
		# upstairs service, even if its x is directly over the player's head.
		if distance<=threshold and absf(point.y+18-foot.y)<32:
			candidates.append({"id":StringName(entry.id),"distance":distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.id) < str(b.id) if is_equal_approx(a.distance, b.distance) else a.distance < b.distance)
	return candidates[0].id if not candidates.is_empty() else &""

func slot_world_foot(id: StringName) -> Vector2:
	for entry: Dictionary in world.specification.slots:
		if StringName(entry.id)==id:return Vector2(float(entry.x),float(entry.get("y",FLOOR_Y)))
	return Vector2.INF

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	nearest_id = nearest_candidate(player.position) if player.is_on_floor() else &""
	_prompt.text = "空中工坊 · Space 跳跃 / S 下穿平台\n向东走出聚落 → 风铃平原"
	if not nearest_id.is_empty():
		_prompt.text = "%s\nW / Left stick up / INTERACT" % FUNCTION_NAMES[str(nearest_id)]
	reserved_id=""
	if nearest_id.is_empty():
		for entry: Dictionary in world.specification.slots:
			if not bool(entry.active) and player.is_on_floor() and absf(player.position.x-float(entry.x))<90 and absf(player.position.y+18-float(entry.get("y",FLOOR_Y)))<32:
				reserved_id=str(entry.id)
				_prompt.text=str(entry.label)+" · 功能预留，尚未开放"
	world.update_focus(player.position,camera.get_screen_center_position().x)
	_controls.visible = not input_blocked and controller.router.touch_enabled and controller.router.current_device != &"gamepad"
	overlay.visible=not input_blocked and overlay.enabled and controller.router.current_device!=&"gamepad"

func interact() -> void:
	if input_blocked or not player.is_on_floor() or nearest_id.is_empty():
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
	overlay.set_process_unhandled_input(not blocked)
	overlay.visible=not blocked and overlay.enabled

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

func _process(_delta: float) -> void:
	if is_instance_valid(player) and is_instance_valid(camera):
		camera.position.x=clampf(player.position.x,640.0,float(world.specification.world_width)-640.0)
