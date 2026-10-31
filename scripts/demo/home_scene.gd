class_name HomeScene
extends Node2D
## Safe, fixed Home consumer. All locomotion goes through the real PlayerMotor.
signal requested_interaction(function_id: StringName)
signal requested_navigation
const FLOOR_Y := 432.0
var world: UnderworldHomeWorld
var parallax: UnderworldParallax
var reserved_id := ""
const FUNCTION_NAMES := {"character":"织时匠 / Timeweaver","upgrade":"维修工坊 / Permanent upgrades","arms":"武器工坊 / Armorer","relics":"道具图鉴 / Item codex","achievements":"钟之档案 / Achievements","departure":"走出聚落 · 风铃平原 / Begin adventure"}
var avatar_selection_id := "courier"
var player: PlayerMotor
var controller: PlayerController
var camera: Camera2D
var nearest_id: StringName = &""
var input_blocked := false
var _status: Label
var _prompt: Label
var _controls: HBoxContainer
var overlay: TouchOverlay
var _resource_hud: DemoGameHud
var _hud: CanvasLayer
var _home_top: HBoxContainer
var _menu_button: Button
var _prompt_backing: ColorRect
var _interaction: Button
var _layout_signature: Array = []
var _notes := 0

func _ready() -> void:
	world=UnderworldHomeWorld.new()
	world.weapon_workshop_enabled = true
	world.item_codex_enabled = true
	add_child(world)
	world.configure(FLOOR_Y)
	# Rename the live service label without changing its authored id or geometry.
	for slot: Dictionary in world.specification.slots:
		if str(slot.id) == "character":
			slot.label = FUNCTION_NAMES["character"]
			var service_label := world.slot_nodes.get("character") as Label
			if service_label != null:
				service_label.text = "织时匠"
				service_label.set_meta("home_slot", slot.duplicate(true))
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
	var request_navigation := func() -> void: requested_navigation.emit()
	overlay = InputSetup.attach_menu(player, controller.router, request_navigation, "MENU")
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
	var art := PlayerPresentationRuntime.make_body(player, controller, "UnderworldPlayer", avatar_selection_id)
	player.add_child(art)
	PlayerPresentationRuntime.attach(player)
	_hud = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)
	var top := HBoxContainer.new()
	_home_top = top
	top.theme = preload("res://scripts/ui/menu_theme.gd").create_theme()
	top.position = Vector2(370, 16)
	top.size = Vector2(886, 52)
	_hud.add_child(top)
	_resource_hud=DemoGameHud.new();_hud.add_child(_resource_hud);_resource_hud.bind(controller)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_shadow_color", Color(0.08, 0.05, 0.06, 0.95))
	_status.add_theme_constant_override("shadow_offset_x", 2)
	_status.add_theme_constant_override("shadow_offset_y", 2)
	_status.add_theme_color_override("font_color", Color("f5e6be"))
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_status)
	var menu_button := Button.new()
	_menu_button = menu_button
	menu_button.text = "菜单"
	menu_button.custom_minimum_size = Vector2(200, 48)
	menu_button.pressed.connect(func() -> void: requested_navigation.emit())
	top.add_child(menu_button)
	var prompt_backing:=ColorRect.new();prompt_backing.position=Vector2(325,544);prompt_backing.size=Vector2(650,82);prompt_backing.color=Color(.055,.10,.095,.84);prompt_backing.mouse_filter=Control.MOUSE_FILTER_IGNORE;_hud.add_child(prompt_backing)
	_prompt_backing = prompt_backing
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
	_controls.theme = preload("res://scripts/ui/menu_theme.gd").create_theme()
	_controls.position = Vector2(390, 636)
	_controls.add_theme_constant_override("separation", 12)
	_hud.add_child(_controls)
	var interaction := Button.new()
	_interaction = interaction
	interaction.text = "互动"
	interaction.custom_minimum_size = Vector2(150, 60)
	interaction.pressed.connect(func() -> void:
		if not input_blocked:
			controller.router.activate_device(&"touch")
			controller.router.request_action(&"interact"))
	_controls.add_child(interaction)
	controller.router.touch_enabled = OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()
	set_meta_state({"notes": 0})
	UnderworldUI.style_canvas(_hud)
	# Load the optional presentation at the composition root; avoid a static
	# HomeScene -> presentation -> scenery -> stage -> DemoApp class cycle.
	var presentation:=load("res://scripts/underworld_plains/underworld_presentation.gd") as Script
	presentation.attach(self,world,player)
	_layout_home_hud()

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
	_notes = int(snapshot.get("notes", 0))
	if _resource_hud != null: _resource_hud.present_context("风铃聚落", 0, _notes)
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
	_prompt.text = "Space 跳跃 · S 下穿平台\n向右走出聚落 → 风铃平原"
	if not nearest_id.is_empty():
		_prompt.text = "%s\nW / Left stick up / INTERACT" % FUNCTION_NAMES[str(nearest_id)]
	reserved_id=""
	if nearest_id.is_empty():
		for entry: Dictionary in world.specification.slots:
			if not bool(entry.active) and player.is_on_floor() and absf(player.position.x-float(entry.x))<90 and absf(player.position.y+18-float(entry.get("y",FLOOR_Y)))<32:
				reserved_id=str(entry.id)
				_prompt.text=str(entry.label)+" · 功能预留，尚未开放"
	if overlay.enabled:
		_prompt.text = str(FUNCTION_NAMES[str(nearest_id)]).split(" / ")[0] if not nearest_id.is_empty() else "功能预留，尚未开放" if not reserved_id.is_empty() else ""
		_prompt.visible = not _prompt.text.is_empty()
		_prompt_backing.visible = _prompt.visible
		_interaction.disabled = nearest_id.is_empty()
	else:
		_prompt.show()
		_prompt_backing.show()
		_interaction.disabled = false
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
	if is_instance_valid(_resource_hud):
		var metrics := [get_viewport_rect().size, DemoUiModalMetrics.ui_scale(get_viewport()), overlay.enabled]
		if metrics != _layout_signature: _layout_home_hud()
		_resource_hud.present_touch_menu(overlay)

func _layout_home_hud() -> void:
	if not is_instance_valid(_interaction): return
	var viewport := get_viewport()
	var pixel_scale := DemoUiModalMetrics.ui_scale(viewport)
	var safe := DemoUiModalMetrics.safe_rect(viewport)
	_layout_signature = [get_viewport_rect().size, pixel_scale, overlay.enabled]
	_resource_hud.present_context("风铃聚落", 0, _notes)
	_resource_hud.present_touch_menu(overlay)
	# Location and currency already belong to the shared HUD. Keep one menu
	# target on touch, with the original overlay signal owning navigation.
	_status.hide()
	_home_top.visible = not overlay.enabled
	_menu_button.custom_minimum_size = Vector2(108, 48)
	_home_top.position = Vector2(safe.end.x - 132, safe.position.y + 18)
	_home_top.size = Vector2(108, 48)
	var button_size := Vector2(150, 60) / minf(1.0, pixel_scale)
	_interaction.custom_minimum_size = button_size
	_interaction.add_theme_font_size_override("font_size", 20)
	_controls.size = button_size
	_controls.position = Vector2(safe.get_center().x - button_size.x * 0.5, safe.end.y - button_size.y - 24.0 / pixel_scale)
	var prompt_size := Vector2(minf(400.0, safe.size.x * 0.44), 52.0)
	_prompt.size = prompt_size
	_prompt.position = Vector2(safe.get_center().x - prompt_size.x * 0.5, _controls.position.y - prompt_size.y - 6.0 / pixel_scale)
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt_backing.position = _prompt.position - Vector2(4, 3) / pixel_scale
	_prompt_backing.size = prompt_size + Vector2(8, 6) / pixel_scale
