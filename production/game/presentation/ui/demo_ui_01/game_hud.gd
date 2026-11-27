class_name DemoGameHud
extends Control
## One read-only HUD above the current ordinary session. Room simulation, abilities,
## discovery and purchases continue to belong to their respective world services.
const COLORS := preload("res://game/presentation/ui/demo_ui_01/clockwork_theme.gd")
const PORTRAIT := preload("res://assets/underworld_plains/player_animation/states_sheet.png")
var session: OrdinaryRoomSession
var host: WorldGameHost
var hearts := DemoHeartStrip.new()
var resonance := DemoResonanceLine.new()
var time_ring := DemoTimeEnergyRing.new()
var double_jump_icon := DemoAbilityIcon.new()
var hook_icon := DemoAbilityIcon.new()
var guard_icon := DemoAbilityIcon.new()
var rows := VBoxContainer.new()
var portrait := TextureRect.new()
var health_text := COLORS.label("",16,COLORS.PAPER)
var resonance_text := COLORS.label("",16,COLORS.PAPER)
var skill_text := COLORS.label("",16,COLORS.BRASS)
var money := COLORS.label("",18,COLORS.BRASS)
var location := COLORS.label("",16,COLORS.PAPER)
var ammunition := HBoxContainer.new()
var map_card := MapCard.new()
var _overlay_hidden := false
var _layout_size := Vector2.ZERO
var _map_rect := Rect2()
var _touch_layout := false

class AmmoCell extends Control:
	var charged := false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(14,24)
	func _draw() -> void:
		var body := PackedVector2Array([Vector2(4,7),Vector2(7,3),Vector2(10,7),Vector2(10,18),Vector2(4,18)])
		draw_colored_polygon(body,COLORS.BRASS if charged else COLORS.RAISED)
		body.append(body[0])
		draw_polyline(body,COLORS.INK,2)
		draw_rect(Rect2(3,19,9,2),COLORS.PAPER if charged else COLORS.MUTED)

class MapCard extends Control:
	var map: WorldRouteMap
	var skin := COLORS.plate(Color("203233eb"),COLORS.EDGE,0)
	func _ready() -> void:
		skin.set_corner_radius_all(6)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		accessibility_name = "区域地图"
		tooltip_text = "区域地图"
	func _gui_input(event: InputEvent) -> void:
		if is_instance_valid(map) and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			accept_event()
			if event.pressed: map.open()
	func _draw() -> void:
		draw_style_box(skin,Rect2(Vector2.ZERO,size))
		var font_size := clampi(roundi(size.y*.19),14,18)
		draw_string(COLORS.FONT,Vector2(10,font_size+4),"区域地图",HORIZONTAL_ALIGNMENT_LEFT,size.x-20,font_size,COLORS.PAPER)
		if is_instance_valid(map):
			map.draw_region(self,Rect2(8,font_size+9,size.x-16,size.y-font_size-16),true)

static func mount(owner_host: WorldGameHost) -> DemoGameHud:
	var layer := CanvasLayer.new()
	layer.name = "PlayHud"
	layer.layer = 4
	owner_host.add_child(layer)
	var hud := DemoGameHud.new()
	hud.host = owner_host
	layer.add_child(hud)
	return hud

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = COLORS.create_theme()
	add_child(time_ring)
	add_child(rows)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation",3)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation",8)
	rows.add_child(header)
	var face := AtlasTexture.new()
	face.atlas = PORTRAIT
	face.region = Rect2(26,9,31,29)
	face.filter_clip = true
	portrait.texture = face
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.custom_minimum_size = Vector2(48,48)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(portrait)
	var vitals := VBoxContainer.new()
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.add_theme_constant_override("separation",1)
	header.add_child(vitals)
	var health_line := HBoxContainer.new()
	health_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.add_child(health_line)
	health_line.add_child(hearts)
	health_line.add_child(health_text)
	var reserve := HBoxContainer.new()
	reserve.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.add_child(reserve)
	reserve.add_child(resonance_text)
	resonance.custom_minimum_size = Vector2(90,12)
	resonance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reserve.add_child(resonance)
	var availability := HBoxContainer.new()
	availability.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(availability)
	ammunition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	availability.add_child(ammunition)
	double_jump_icon.kind = &"double_jump"
	hook_icon.kind = &"grapple"
	guard_icon.kind = &"recoil_guard"
	for icon: Control in [double_jump_icon,hook_icon,guard_icon,skill_text]: availability.add_child(icon)
	for label: Label in [health_text,resonance_text,skill_text,money,location]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_constant_override("outline_size",3)
		label.add_theme_color_override("font_outline_color",COLORS.INK)
	add_child(location)
	add_child(money)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(map_card)
	hide()

func bind_session(value: OrdinaryRoomSession, place: String) -> void:
	if is_instance_valid(session):
		if session.state.committed.is_connected(_world_changed):
			session.state.committed.disconnect(_world_changed)
		if session.touch_controls.visibility_changed.is_connected(_touch_visibility_changed):
			session.touch_controls.visibility_changed.disconnect(_touch_visibility_changed)
	session = value
	session.state.committed.connect(_world_changed)
	session.touch_controls.visibility_changed.connect(_touch_visibility_changed)
	session.touch_controls.map_drawn_by_hud = true
	session.touch_controls.queue_redraw()
	session.equipment_menu.shortcut.hide()
	location.text = place
	hearts.capacity = 0.0
	hearts.feedback = 0.0
	resonance._previous = -1.0
	time_ring.bind(session.controller)
	_layout_size = Vector2.ZERO
	_world_changed(session.state.revision)
	_sync_visibility()

func _touch_visibility_changed() -> void:
	if is_instance_valid(session) and is_instance_valid(session.touch_controls):
		_layout(session.touch_controls)

func set_overlay_hidden(value: bool) -> void:
	_overlay_hidden = value
	_sync_visibility()

func _sync_visibility() -> void:
	visible = is_instance_valid(session) and session.lifetime.active and not _overlay_hidden and not host.crossing and not get_tree().paused

func _world_changed(_revision: int) -> void:
	money.text = "金币  %d" % int(session.services.ledger().gold)
	map_card.queue_redraw()

func _process(_delta: float) -> void:
	_sync_visibility()
	if not visible: return
	if host.route_map != map_card.map:
		map_card.map = host.route_map as WorldRouteMap
		map_card.queue_redraw()
	var touch := session.touch_controls
	if _layout_size!=size or _map_rect!=touch.map_button or _touch_layout!=touch.enabled:
		_layout(touch)
	# A player can plant the floating stick anywhere on the left half of the field.
	var stick_area := Rect2(touch.left_center-Vector2.ONE*touch.radius,Vector2.ONE*touch.radius*2.0)
	location.visible = not touch.enabled or not location.get_global_rect().intersects(stick_area)
	var actor := session.controller
	var health := actor.actor_resources.health
	hearts.present(health.current,health.capacity)
	health_text.text = "%s/%s" % [number(health.current),number(health.capacity)]
	var combat := actor.combat_energy
	resonance.present(combat.current,combat.capacity())
	resonance_text.text = "共鸣 %s / %s" % [number(combat.current),number(combat.capacity())]
	var count := actor.motor.tuning.max_air_shots if actor.shoot_ability.enabled else 0
	while ammunition.get_child_count()<count: ammunition.add_child(AmmoCell.new())
	for index in ammunition.get_child_count():
		var cell := ammunition.get_child(index) as AmmoCell
		cell.visible = index<count
		var charged := index<actor.action_resources.shot_charges
		if cell.charged!=charged:
			cell.charged=charged
			cell.queue_redraw()
	double_jump_icon.visible = actor.traversal.double_enabled and actor.jump_ability.can_air_jump()
	hook_icon.visible = actor.traversal.hook_enabled and (actor.motor.is_on_floor() or not actor.traversal.hook_used)
	var guard := session.recoil_guard
	guard_icon.visible = is_instance_valid(guard) and guard.owned
	if guard_icon.visible:
		guard_icon.present_guard(guard.landing_ready and guard.cooldown<=0,guard.active,guard.cooldown,clampf(guard.cooldown/guard.cooldown_seconds,0,1))
	var router := actor.router
	skill_text.visible = actor.shoot_ability.enabled and router.weapon_skill_available and router.current_device!=&"touch"
	if skill_text.visible:
		var key := "Q" if router.current_device!=&"gamepad" else "Y"
		skill_text.text = "%s  %s" % [key,router.weapon_skill_label]
		skill_text.modulate = COLORS.MUTED if router.weapon_skill_cooldown_ratio>0 else Color.WHITE

func _layout(touch: RoomTouchControls) -> void:
	_layout_size = size
	_map_rect = touch.map_button
	_touch_layout = touch.enabled
	map_card.position = _map_rect.position
	map_card.size = _map_rect.size
	# Existing touch capture owns this exact rectangle. Desktop clicks use the same map.
	map_card.mouse_filter = Control.MOUSE_FILTER_IGNORE if touch.enabled else Control.MOUSE_FILTER_STOP
	var safe := touch.safe_bounds()
	var screen_scale := maxf(.1,get_viewport().get_screen_transform().get_scale().x)
	var factor := clampf(1.0/screen_scale,1,1.35)
	var margin := Vector2(20,16)
	rows.position = safe.position+margin
	rows.scale = Vector2.ONE*factor
	hearts.columns = 5 if safe.size.x/factor<800 else 8
	money.size = Vector2(_map_rect.size.x,28)
	money.position = Vector2(_map_rect.position.x,_map_rect.end.y+7)
	location.scale = Vector2.ONE*factor
	location.size = location.get_minimum_size()
	var left := rows.position.x
	if touch.enabled:
		left = maxf(touch.healing_button.end.x,safe.position.x+touch.radius*2.0+24)+margin.x
	location.position = Vector2(left,safe.end.y-margin.y-location.size.y*factor)

static func number(value: float) -> String:
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")
