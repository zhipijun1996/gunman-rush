class_name DemoGameHud
extends Control
## Read-only resources and navigation. No resource, ability or character rules live here.
const COLORS := preload("res://scripts/ui/demo_ui_01/clockwork_theme.gd")
signal debug_requested
var actor: PlayerController
var hearts: DemoHeartStrip
var energy: DemoResourceTrack
var resonance: DemoResourceTrack
var time_ring: DemoTimeEnergyRing
var portrait: TextureRect
var double_jump_icon: DemoAbilityIcon
var hook_icon: DemoAbilityIcon
var _rows: VBoxContainer
var _health_text: Label
var _energy_text: Label
var _shots: HFlowContainer
var _shot_cells: Array[Label] = []
var _weapon: Label
var _resonance_text: Label
var _focus_text: Label
var _abilities: Label
var _money: Label
var _location: Label
var _notice: Label
var _notice_time := 0.0
var _focus_dial: Control
var _reduced := false
var _last_device: StringName = &""
var _touch_menu: PanelContainer
var _touch_menu_text: Label
var _debug: Button
var _wallet_plate: PanelContainer
var _location_plate: PanelContainer
var _chrome_theme: Theme
var _head_row: HBoxContainer
var _vitals: VBoxContainer
var _portrait_source: AtlasTexture

class AmmoCell extends Label:
	var charged := false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(16, 25)
	func present(value: bool) -> void:
		charged = value
		queue_redraw()
	func _draw() -> void:
		var palette := preload("res://scripts/ui/demo_ui_01/clockwork_theme.gd")
		var body := PackedVector2Array([Vector2(5, 6), Vector2(8, 3), Vector2(11, 6), Vector2(11, 19), Vector2(5, 19)])
		var outline := body.duplicate()
		outline.append(outline[0])
		draw_polyline(outline, palette.INK, 4, false)
		draw_colored_polygon(body, palette.BRASS if charged else Color("4d5952"))
		draw_rect(Rect2(4, 20, 8, 2), palette.BRASS if charged else palette.MUTED)
		if charged: draw_line(Vector2(6, 7), Vector2(6, 16), palette.PAPER, 1, false)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = COLORS.create_theme()
	_chrome_theme = theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	time_ring = preload("res://scripts/ui/demo_ui_01/r3_time_energy_ring.gd").new()
	_focus_dial = time_ring
	add_child(time_ring)
	_rows = VBoxContainer.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_theme_constant_override("separation", 4)
	_rows.size.x = 280
	add_child(_rows)
	_head_row = HBoxContainer.new()
	_head_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head_row.add_theme_constant_override("separation", 10)
	_rows.add_child(_head_row)
	portrait = TextureRect.new()
	portrait.name = "ActualPlayerPortrait"
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(48, 48)
	_portrait_source = AtlasTexture.new()
	_portrait_source.atlas = preload("res://assets/underworld_plains/player_animation/states_sheet.png")
	# Viewed idle frame0 (0,0,80,64): hood, face and neck only, no other cell.
	_portrait_source.region = Rect2(26, 9, 31, 29)
	_portrait_source.filter_clip = true
	portrait.texture = _portrait_source
	_head_row.add_child(portrait)
	_vitals = VBoxContainer.new()
	_vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitals.add_theme_constant_override("separation", 4)
	_vitals.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head_row.add_child(_vitals)
	var health_row := HBoxContainer.new()
	health_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_row.add_theme_constant_override("separation", 7)
	_vitals.add_child(health_row)
	hearts = DemoHeartStrip.new()
	hearts.columns = 8
	health_row.add_child(hearts)
	_health_text = _label("", 16, COLORS.PAPER)
	_health_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_health_text.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_health_text.custom_minimum_size.x = 24
	health_row.add_child(_health_text)
	var resonance_row := HBoxContainer.new()
	resonance_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resonance_row.add_theme_constant_override("separation", 7)
	_vitals.add_child(resonance_row)
	_resonance_text = _label("共鸣", 16, COLORS.PAPER)
	resonance_row.add_child(_resonance_text)
	resonance = preload("res://scripts/ui/demo_ui_01/r3_resonance_line.gd").new()
	resonance.custom_minimum_size = Vector2(110, 10)
	resonance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resonance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	resonance_row.add_child(resonance)
	var availability := HBoxContainer.new()
	availability.mouse_filter = Control.MOUSE_FILTER_IGNORE
	availability.add_theme_constant_override("separation", 12)
	_rows.add_child(availability)
	_shots = HFlowContainer.new()
	_shots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shots.add_theme_constant_override("h_separation", 4)
	_shots.add_theme_constant_override("v_separation", 3)
	availability.add_child(_shots)
	double_jump_icon = preload("res://scripts/ui/demo_ui_01/r3_ability_icon.gd").new()
	double_jump_icon.name = "AvailableDoubleJump"
	double_jump_icon.kind = &"double_jump"
	double_jump_icon.tooltip_text = "二段跳可用"
	availability.add_child(double_jump_icon)
	hook_icon = preload("res://scripts/ui/demo_ui_01/r3_ability_icon.gd").new()
	hook_icon.name = "AvailableGrapple"
	hook_icon.kind = &"grapple"
	hook_icon.tooltip_text = "钩索可用"
	availability.add_child(hook_icon)
	# Keep the old diagnostic fields bound to official data, without rendering
	# removed energy/weapon/focus widgets or creating another resource ledger.
	energy = DemoResourceTrack.new()
	add_child(energy)
	energy.hide()
	_energy_text = _label("")
	_weapon = _label("")
	_focus_text = _label("")
	_abilities = _label("")
	for label: Label in [_energy_text, _weapon, _focus_text, _abilities]:
		add_child(label)
		label.hide()
	_wallet_plate = _empty_group(self)
	_money = _label("", 18, COLORS.BRASS)
	_wallet_plate.add_child(_money)
	_location_plate = _empty_group(self)
	_location = _label("", 16, COLORS.PAPER)
	_location.clip_text = true
	_location.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_location_plate.add_child(_location)
	_notice = _label("", 16, COLORS.PAPER)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(_notice)
	_touch_menu = PanelContainer.new()
	_touch_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch_menu.add_theme_stylebox_override("panel", COLORS.plate(COLORS.PANEL, COLORS.BRASS, 0))
	_touch_menu_text = _label("菜单", 18)
	_touch_menu_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_touch_menu_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_touch_menu.add_child(_touch_menu_text)
	add_child(_touch_menu)
	_touch_menu.hide()
	_debug = Button.new()
	_debug.text = "i"
	_debug.tooltip_text = "调试信息 / F3"
	_debug.custom_minimum_size = Vector2(48, 48)
	_debug.pressed.connect(func() -> void: debug_requested.emit())
	add_child(_debug)
	hide()

func _label(value: String, font_size: int = 18, color: Color = COLORS.PAPER) -> Label:
	var label := COLORS.label(value, font_size, color)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _empty_group(parent: Node) -> PanelContainer:
	var group := PanelContainer.new()
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	parent.add_child(group)
	return group

func bind(value: PlayerController) -> void:
	unbind()
	actor = value
	if not is_instance_valid(actor): return
	actor.actor_resources.health.changed.connect(_health_changed)
	actor.shoot_ability.shot_rejected.connect(_rejected)
	actor.energy_recovered.connect(_recovered)
	hearts.capacity = 0.0
	hearts.feedback = 0.0
	hearts.healing = false
	energy._previous = -1.0
	resonance._previous = -1.0
	time_ring.bind(actor)
	_refresh()
	show()

func unbind() -> void:
	if is_instance_valid(actor):
		if actor.actor_resources.health.changed.is_connected(_health_changed): actor.actor_resources.health.changed.disconnect(_health_changed)
		if actor.shoot_ability.shot_rejected.is_connected(_rejected): actor.shoot_ability.shot_rejected.disconnect(_rejected)
		if actor.energy_recovered.is_connected(_recovered): actor.energy_recovered.disconnect(_recovered)
	actor = null
	_notice_time = 0.0
	if is_instance_valid(time_ring): time_ring.unbind()
	if is_instance_valid(_notice): _notice.text = ""
	hide()

func _health_changed(result: ActorResourceResult) -> void:
	if result.status != ActorResourceResult.Status.APPLIED: return
	if result.amount_applied < 0: _notify("生命 -%s" % _number(absf(result.amount_applied)), COLORS.CORAL)
	elif result.amount_applied > 0: _notify("恢复 +%s" % _number(result.amount_applied), COLORS.TEAL)
	_refresh()

func _rejected(reason: StringName) -> void:
	if reason == &"empty": _notify("弹药耗尽", COLORS.BRASS)

func _recovered(_amount: float, _airborne: bool) -> void:
	# Shot-energy notifications are no longer presented as a second time reserve.
	pass

func _notify(value: String, color: Color) -> void:
	_notice.text = value
	_notice.add_theme_color_override("font_color", color)
	_notice_time = 1.25

func present_context(location_text: String, coins: int, notes: int, reduced: bool = false) -> void:
	_reduced = reduced
	if theme != _chrome_theme: theme = _chrome_theme
	_location.text = location_text.replace("WINDCHIME PLAINS", "风铃平原").replace("THORN FOREST", "荆棘森林").replace("TUTORIAL", "初行")
	_money.text = "金币 %s  ·  音符 %s" % [coins, notes]
	var viewport := get_viewport_rect().size
	var pixel_scale := preload("res://scripts/ui/demo_ui_01/modal_metrics.gd").pixel_scale(get_viewport())
	var factor := clampf(1.0 / pixel_scale, 1.0, 1.8)
	var physical_width := viewport.x * get_viewport().get_screen_transform().get_scale().abs().x
	var narrow := physical_width < 600
	_rows.scale = Vector2.ONE * factor
	_rows.size.x = maxf(140, minf(180, physical_width - 247.0)) / maxf(0.01, factor * pixel_scale) if narrow else 300.0
	hearts.columns = 5 if narrow else 8
	resonance.custom_minimum_size.x = 70 if narrow else 110
	_wallet_plate.scale = Vector2.ONE * factor
	_location_plate.scale = Vector2.ONE * factor
	var safe := preload("res://scripts/ui/demo_ui_01/modal_metrics.gd").safe_rect(get_viewport())
	var margin := Vector2(24, 18) / minf(1, pixel_scale)
	_rows.position = safe.position + margin
	_location_plate.custom_minimum_size = Vector2(minf(360, maxf(1, (safe.size.x - margin.x * 2) / factor)), 26)
	_location_plate.size = _location_plate.custom_minimum_size
	_location_plate.position = Vector2(safe.position.x + margin.x, safe.end.y - _location_plate.size.y * factor - margin.y)
	_wallet_plate.size = _wallet_plate.get_combined_minimum_size()
	_wallet_plate.position = Vector2(maxf(safe.position.x + margin.x, safe.end.x - margin.x - _wallet_plate.size.x * factor), safe.position.y + 140 / minf(1, pixel_scale))
	var font_size := maxi(16, ceili(14.0 / maxf(0.01, factor * pixel_scale)))
	for label: Label in [_health_text, _resonance_text, _location, _notice]: label.add_theme_font_size_override("font_size", font_size)
	_money.add_theme_font_size_override("font_size", maxi(18, font_size))
	_debug.hide()
	_refresh()

func present_touch_menu(overlay: TouchOverlay) -> void:
	# Only the existing navigation hit rectangle changes. Its original input/cancel
	# handling and pause signal remain the sole touch consumer.
	_touch_menu.visible = overlay.enabled
	if not overlay.enabled: return
	var scale := maxf(0.1, get_viewport().get_screen_transform().get_scale().abs().y)
	var safe := preload("res://scripts/ui/demo_ui_01/modal_metrics.gd").safe_rect(get_viewport())
	var target_size := Vector2(108, 48) / minf(1, scale)
	var rect := Rect2(Vector2(safe.end.x - 24.0 / scale - target_size.x, safe.position.y + 18.0 / scale), target_size)
	if overlay._pause_rect != rect:
		overlay._pause_rect = rect
		overlay.queue_redraw()
	_touch_menu.position = rect.position
	_touch_menu.size = rect.size
	_touch_menu_text.add_theme_font_size_override("font_size", maxi(16, ceili(14.0 / scale)))
	_touch_menu_text.text = "继续" if get_tree().paused else "菜单"
	# Keep location information clear of the original left movement pad. Very
	# short letterboxed canvases retain the same information in the actual map.
	_location_plate.visible = get_viewport_rect().size.y * scale >= 300
	var factor := _rows.scale.x
	_location_plate.custom_minimum_size.x = 200.0 / maxf(0.01, factor * scale)
	_location_plate.size = _location_plate.custom_minimum_size
	# Place the actual location text above the current (possibly floating) pad.
	# The transparent HUD root and a fixed distance from the bottom cannot
	# describe the real input reservation on every viewport/device.
	var label_height := maxf(_location_plate.size.y, _location_plate.get_combined_minimum_size().y) * factor
	var location_y := overlay.left_center.y - overlay.radius - 10.0 / scale - label_height
	_location_plate.visible = _location_plate.visible and location_y >= safe.position.y + 18.0 / scale
	_location_plate.position = Vector2(safe.position.x + 24.0 / scale, maxf(safe.position.y, location_y))

func region_layout_controls() -> Array[Control]:
	# App owns gameplay avoidance; expose only the actual visible card owners.
	# Touch pause is the overlay's own reserved control and stays in that slot.
	var controls: Array[Control]=[]
	for card: Control in [_rows,_wallet_plate,_location_plate]:
		if card.is_visible_in_tree():controls.append(card)
	return controls

func present_navigation(map_button: Control, pause_button: Button, touch_menu_rect: Rect2 = Rect2()) -> void:
	# Retain the original map/pause consumers and callbacks; adapt their hit areas.
	pause_button.theme = _chrome_theme
	pause_button.theme_type_variation = &"CompactButton"
	var viewport := get_viewport_rect().size
	var pixel_scale := maxf(0.1, get_viewport().get_screen_transform().get_scale().abs().y)
	var factor := clampf(1.0 / pixel_scale, 1.0, 1.8)
	var right := 24.0 / minf(1, pixel_scale)
	var top := 18.0 / minf(1, pixel_scale)
	if touch_menu_rect.has_area(): top = maxf(top, touch_menu_rect.end.y + 10.0 / pixel_scale)
	if is_instance_valid(map_button):
		var map_factor := maxf(factor, 14.0 / (12.0 * pixel_scale))
		map_button.scale = Vector2.ONE * map_factor
		map_button.size = Vector2(160, maxf(32, 48.0 / pixel_scale / map_factor))
		map_button.position = Vector2(viewport.x - right - 160 * map_factor, top)
		top += map_button.size.y * map_factor + 10.0 / pixel_scale
	pause_button.scale = Vector2.ONE * factor
	pause_button.custom_minimum_size = Vector2(108, maxf(48, 48.0 / pixel_scale / factor))
	pause_button.size = pause_button.custom_minimum_size
	pause_button.position = Vector2(viewport.x - right - pause_button.size.x * factor, top)

func _number(value: float) -> String:
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")

func _refresh() -> void:
	if not is_instance_valid(actor) or hearts == null: return
	var health := actor.actor_resources.health
	hearts.present(health.current, health.capacity)
	_health_text.text = "%s/%s" % [_number(health.current), _number(health.capacity)]
	_health_text.custom_minimum_size.x = _health_text.get_theme_font("font").get_string_size(_health_text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _health_text.get_theme_font_size("font_size")).x + 4
	var combat := actor.combat_energy
	resonance.present(combat.current, combat.definition.capacity)
	_resonance_text.tooltip_text = "共鸣 %s/%s" % [_number(combat.current), _number(combat.definition.capacity)]
	var focus_state := actor.air_focus_ability.stamina_state
	energy.present(focus_state.current, focus_state.capacity)
	var limit := actor.motor.tuning.max_air_shots
	if _shot_cells.size() != limit:
		for child: Node in _shots.get_children():
			_shots.remove_child(child)
			child.queue_free()
		_shot_cells.clear()
		for i: int in limit:
			var cell := AmmoCell.new()
			_shots.add_child(cell)
			_shot_cells.append(cell)
	for i: int in _shot_cells.size(): (_shot_cells[i] as AmmoCell).present(i < actor.action_resources.shot_charges)
	_shots.visible = limit > 0
	_shots.tooltip_text = "空中弹药 %s/%s" % [actor.action_resources.shot_charges, limit]
	var traversal := actor.traversal
	double_jump_icon.visible = traversal != null and traversal.double_enabled and actor.jump_ability.can_air_jump()
	hook_icon.visible = traversal != null and traversal.hook_enabled and (actor.motor.is_on_floor() or not traversal.hook_used)
	var state_text := PackedStringArray()
	if traversal != null:
		if traversal.double_enabled: state_text.append("二跳可用" if double_jump_icon.visible else "二跳已用")
		if traversal.hook_enabled: state_text.append("钩索可用" if hook_icon.visible else "钩索已用")
	_abilities.text = " · ".join(state_text)

func _process(delta: float) -> void:
	if not visible: return
	_refresh()
	_notice_time = maxf(0, _notice_time - delta)
	_notice.visible = _notice_time > 0
	if _reduced: hearts.feedback = 0.0

func _exit_tree() -> void:
	unbind()
