class_name DemoGameHud
extends Control
## Read-only projection of official resources. The app supplies only navigation/wallet context.
const COLORS := preload("res://scripts/ui/demo_ui_01/clockwork_theme.gd")
signal debug_requested
var actor: PlayerController
var hearts: DemoHeartStrip
var energy: DemoResourceTrack
var resonance: DemoResourceTrack
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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = COLORS.create_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rows = VBoxContainer.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_theme_constant_override("separation", 3)
	_rows.position = Vector2(24, 18)
	_rows.size.x = 360
	add_child(_rows)
	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 10)
	_rows.add_child(health_row)
	hearts = DemoHeartStrip.new()
	health_row.add_child(hearts)
	_health_text = COLORS.label("", 14)
	health_row.add_child(_health_text)
	var energy_row := HBoxContainer.new()
	energy_row.add_theme_constant_override("separation", 8)
	_rows.add_child(energy_row)
	energy = DemoResourceTrack.new()
	energy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	energy_row.add_child(energy)
	_energy_text = COLORS.label("", 15, COLORS.BRASS)
	energy_row.add_child(_energy_text)
	_shots = HFlowContainer.new()
	_shots.add_theme_constant_override("separation", 5)
	_rows.add_child(_shots)
	_weapon = COLORS.label("", 15)
	_weapon.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_weapon.custom_minimum_size.x = 310
	_rows.add_child(_weapon)
	var resonance_row := HBoxContainer.new()
	_rows.add_child(resonance_row)
	_resonance_text = COLORS.label("", 13, COLORS.TEAL)
	resonance_row.add_child(_resonance_text)
	resonance = DemoResourceTrack.new()
	resonance.color = COLORS.TEAL
	resonance.custom_minimum_size = Vector2(90, 10)
	resonance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	resonance_row.add_child(resonance)
	_focus_text = COLORS.label("", 13, COLORS.TEAL)
	_rows.add_child(_focus_text)
	_abilities = COLORS.label("", 13, COLORS.MUTED)
	_rows.add_child(_abilities)
	_money = COLORS.label("", 15, COLORS.BRASS)
	add_child(_money)
	_notice = COLORS.label("", 15, COLORS.PAPER)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.custom_minimum_size = Vector2(310, 0)
	_rows.add_child(_notice)
	_location = COLORS.label("", 14, COLORS.PAPER)
	add_child(_location)
	_touch_menu = PanelContainer.new()
	_touch_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch_menu.add_theme_stylebox_override("panel", COLORS.plate(COLORS.INK, COLORS.EDGE, 0))
	_touch_menu_text = COLORS.label("MENU", 16)
	_touch_menu_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_touch_menu_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_touch_menu.add_child(_touch_menu_text)
	add_child(_touch_menu)
	_touch_menu.hide()
	_debug = Button.new()
	_debug.text = "i"
	_debug.tooltip_text = "调试信息 / F3"
	_debug.custom_minimum_size = Vector2(48, 48)
	_debug.add_theme_font_size_override("font_size", 16)
	_debug.pressed.connect(func() -> void: debug_requested.emit())
	add_child(_debug)
	hide()

func bind(value: PlayerController) -> void:
	unbind()
	actor = value
	if not is_instance_valid(actor): return
	actor.actor_resources.health.changed.connect(_health_changed)
	actor.shoot_ability.shot_rejected.connect(_rejected)
	actor.energy_recovered.connect(_recovered)
	hearts.capacity = 0.0
	_refresh()
	show()

func unbind() -> void:
	if is_instance_valid(actor):
		if actor.actor_resources.health.changed.is_connected(_health_changed): actor.actor_resources.health.changed.disconnect(_health_changed)
		if actor.shoot_ability.shot_rejected.is_connected(_rejected): actor.shoot_ability.shot_rejected.disconnect(_rejected)
		if actor.energy_recovered.is_connected(_recovered): actor.energy_recovered.disconnect(_recovered)
	actor = null
	_notice_time = 0.0
	if is_instance_valid(_notice): _notice.text = ""
	hide()

func _health_changed(result: ActorResourceResult) -> void:
	if result.status != ActorResourceResult.Status.APPLIED: return
	if result.amount_applied < 0:
		_notify("生命 -%s" % _number(absf(result.amount_applied)), COLORS.CORAL)
	elif result.amount_applied > 0:
		_notify("恢复 +%s" % _number(result.amount_applied), COLORS.TEAL)
	_refresh()

func _rejected(reason: StringName) -> void:
	if reason == &"empty": _notify("空中弹药耗尽 · 命中或落地补充" if actor.shot_energy != null else "空中弹药耗尽 · 落地补充", COLORS.BRASS)
	elif reason == &"energy": _notify("精力不足 · 落地休息", COLORS.BRASS)

func _recovered(amount: float, _airborne: bool) -> void:
	if amount > 0: _notify("命中续航 +%s" % _number(amount), COLORS.TEAL)

func _notify(text: String, color: Color) -> void:
	_notice.text = text
	_notice.add_theme_color_override("font_color", color)
	_notice_time = 1.25

func present_context(location_text: String, coins: int, notes: int, reduced: bool = false) -> void:
	_reduced = reduced
	_location.text = location_text
	_money.text = "◇ %s 金币    %s 音符" % [coins, notes]
	var viewport := get_viewport_rect().size
	var pixel_scale := maxf(0.1, get_viewport().get_screen_transform().get_scale().abs().y)
	var factor := clampf(1.0 / pixel_scale, 1.0, 1.8)
	_rows.scale = Vector2.ONE * factor
	_money.scale = Vector2.ONE * factor
	_location.scale = Vector2.ONE * factor
	var margin := Vector2(24, 18) / minf(1, pixel_scale)
	# Native mobile safe area; Web keeps its host's safe-area canvas sizing.
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		if screen.x > 0 and screen.y > 0:
			margin = margin.max(Vector2(safe.position) * viewport / Vector2(screen))
	_rows.position = margin
	_location.position = Vector2(margin.x, viewport.y - 26 * factor - margin.y)
	_location.custom_minimum_size.x = maxf(1, (viewport.x - margin.x * 2) / factor)
	_location.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_debug.hide() # F3 retains the original developer overlay without adding combat clutter.
	_money.position = Vector2(maxf(margin.x, viewport.x - margin.x - 320 * factor), 140 / minf(1, pixel_scale))
	_money.size.x = 320
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	_touch_menu_text.text = "RESUME" if get_tree().paused else "MENU"

func present_navigation(map_button: Control, pause_button: Button, touch_menu_rect: Rect2 = Rect2()) -> void:
	# Retain the original map/pause consumers and callbacks; adapt their hit areas.
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
	var has_energy := actor.shot_energy != null
	energy.visible = has_energy
	_energy_text.visible = has_energy
	if has_energy:
		var stamina := actor.actor_resources.stamina
		energy.present(stamina.current, stamina.capacity, actor.shot_energy.shot_energy_cost)
		_energy_text.text = "精力 %s" % _number(stamina.current)
	var limit := actor.motor.tuning.max_air_shots
	if _shot_cells.size() != limit:
		for child: Node in _shots.get_children(): child.queue_free()
		_shot_cells.clear()
		var caption := COLORS.label("空中弹药", 13, COLORS.MUTED)
		_shots.add_child(caption)
		for i: int in limit:
			var cell := COLORS.label("●", 19, COLORS.BRASS)
			_shots.add_child(cell)
			_shot_cells.append(cell)
	var charges := actor.action_resources.shot_charges
	for i: int in _shot_cells.size():
		_shot_cells[i].text = "●" if i < charges else "○"
		_shot_cells[i].add_theme_color_override("font_color", COLORS.BRASS if i < charges else COLORS.MUTED)
	_shots.visible = limit > 0
	var weapon := actor.shoot_ability.weapon
	_weapon.text = "%s  ·  Lv.%s" % [weapon.display_name, weapon.tier]
	_weapon.tooltip_text = weapon.display_name
	# Resonance is earned independently even at tiers below the skill unlock.
	var combat := actor.combat_energy
	resonance.get_parent().visible = combat.current > 0 or weapon.tier == 3
	resonance.present(combat.current, combat.definition.capacity)
	_resonance_text.text = "共鸣 %s/%s  " % [_number(combat.current), _number(combat.definition.capacity)]
	if weapon.tier == 3:
		var ready := combat.current >= weapon.skill_cost
		_resonance_text.text += ("可用  " if ready else "积蓄  ")
	var focus := actor.air_focus_ability
	_focus_text.visible = focus.enabled and focus.tuning.air_focus_enabled and (focus.active or focus.exhausted or focus.air_time_used > 0.01 or focus.stamina < focus.stamina_state.capacity - 0.01)
	if _focus_text.visible:
		var remaining := maxf(0, focus.tuning.focus_max_air_duration - focus.air_time_used)
		var state := "慢时 %s%%" % roundi(focus.tuning.focus_time_scale * 100) if focus.active else "瞄准慢时"
		if focus.exhausted or remaining <= 0 or focus.stamina <= 0: state = "慢时耗尽 · 落地恢复"
		_focus_text.text = "%s  %.1fs · %s/%s" % [state, remaining, _number(focus.stamina), _number(focus.stamina_state.capacity)]
	var actions := actor.action_resource_view.snapshot()
	var badges: PackedStringArray = []
	if actions.jump_enabled: badges.append("跳跃 %s/%s" % [maxi(0, actions.jump_limit - actions.jumps_used), actions.jump_limit])
	var traversal := actor.traversal
	if traversal != null:
		if traversal.hook_enabled: badges.append("钩索 " + ("使用中" if traversal.busy() else "已用" if traversal.hook_used else "可用"))
		if traversal.wall_enabled: badges.append("蹬墙")
	_abilities.text = " · ".join(badges)
	_abilities.visible = actor.motor.tuning.max_jumps > 1 or (traversal != null and (traversal.hook_enabled or traversal.wall_enabled))

func _process(delta: float) -> void:
	if not visible: return
	_refresh()
	_notice_time = maxf(0, _notice_time - delta)
	_notice.visible = _notice_time > 0
	if _reduced: hearts.feedback = 0.0

func _exit_tree() -> void:
	unbind()
