class_name ActorResourcesHud
extends Control

var health_bar: ProgressBar
var health_label: Label
var stamina_bar: ProgressBar
var stamina_label: Label
var _resources: ActorResources
var _hurt_glow := 0.0
var _last_health := -1.0
var _shots_label: Label
var _shot_hint := 0.0
var _actor: PlayerController
var _focus: AirFocusAbility

func bind(resources: ActorResources, focus: AirFocusAbility = null, actor: PlayerController = null) -> void:
	unbind()
	_resources = resources
	_focus = focus
	_actor = actor
	if health_bar == null:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		health_bar = _make_bar(Vector2(22, 78), Color(0.82, 0.28, 0.32))
		health_label = _make_label(Vector2(252, 73))
		stamina_bar = _make_bar(Vector2(22, 95), Color(0.9, 0.68, 0.2))
		stamina_label = _make_label(Vector2(252, 90))
		_shots_label = _make_label(Vector2(22, 111))
		_shots_label.add_theme_font_override("font", preload("res://assets/fonts/windkeeper_ui.ttf"))
	if is_instance_valid(_resources):
		_resources.health.changed.connect(_health_changed)
		_resources.stamina.changed.connect(_stamina_changed)
		if is_instance_valid(_actor): _actor.shoot_ability.shot_rejected.connect(_shot_rejected)
		_refresh_health(_resources.health.snapshot())
		_refresh_stamina(_resources.stamina.snapshot())

func _shot_rejected(reason: StringName) -> void:
	if reason == &"empty": _shot_hint = 1.2

func unbind() -> void:
	if is_instance_valid(_actor) and _actor.shoot_ability.shot_rejected.is_connected(_shot_rejected):
		_actor.shoot_ability.shot_rejected.disconnect(_shot_rejected)
	if is_instance_valid(_resources):
		if _resources.health.changed.is_connected(_health_changed):
			_resources.health.changed.disconnect(_health_changed)
		if _resources.stamina.changed.is_connected(_stamina_changed):
			_resources.stamina.changed.disconnect(_stamina_changed)
	_resources = null
	_focus = null
	_actor = null
	_last_health = -1.0
	_hurt_glow = 0.0
	_shot_hint = 0.0

func _make_bar(location: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = location
	bar.show_percentage = false
	# ProgressBar reserves font height even with percentage hidden. External
	# 14px Labels own text, so the internal font must not inflate a 9px track.
	bar.add_theme_font_size_override("font_size", 1)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("23382f")
	background.border_color = Color("a58d5e")
	background.set_border_width_all(1)
	background.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	bar.custom_minimum_size = Vector2(220, 9)
	add_child(bar)
	# Reapply only after the in-tree theme resolves; the default theme can
	# otherwise clamp a pre-tree size to its previous 27px minimum.
	bar.size = Vector2(220, 9)
	return bar

func _make_label(location: Vector2) -> Label:
	var label := Label.new()
	label.position = location
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("f5ecd4"))
	label.add_theme_color_override("font_shadow_color", Color(0.08, 0.12, 0.10, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	return label

func _health_changed(result: ActorResourceResult) -> void:
	_refresh_health(result.snapshot)

func _stamina_changed(result: ActorResourceResult) -> void:
	_refresh_stamina(result.snapshot)

func _refresh_health(value: ActorResourceSnapshot) -> void:
	if _last_health >= 0.0 and value.current < _last_health:
		_hurt_glow = 0.30
	_last_health = value.current
	health_bar.max_value = value.capacity
	health_bar.value = value.current
	health_label.text = "HP %.0f/%.0f" % [value.current, value.capacity]

func _refresh_stamina(value: ActorResourceSnapshot) -> void:
	stamina_bar.max_value = value.capacity
	stamina_bar.value = value.current
	stamina_label.text = "STAMINA %.0f/%.0f" % [value.current, value.capacity]

func _process(delta: float) -> void:
	_shot_hint = maxf(0, _shot_hint - delta)
	if is_instance_valid(_actor) and _shots_label != null:
		var actor: PlayerController = _actor
		_shots_label.text = "空中弹药用尽：落地补充 / LAND TO RECHARGE" if _shot_hint > 0 else "AIR SHOTS %d/%d • JUMP %d/%d" % [actor.action_resources.shot_charges, actor.motor.tuning.max_air_shots, maxi(0, actor.motor.tuning.max_jumps - actor.jump_ability.used_jumps), actor.motor.tuning.max_jumps]
	elif _shots_label != null: _shots_label.text = ""
	_hurt_glow = maxf(0.0, _hurt_glow - delta)
	if health_bar != null:
		health_bar.modulate = Color(1.0, 1.0 - _hurt_glow, 1.0 - _hurt_glow)
	if is_instance_valid(_resources) and is_instance_valid(_focus):
		stamina_label.text = "FOCUS %.0f/%.0f | %s | %.1fs" % [_resources.stamina.current, _resources.stamina.capacity, "SLOW AIM" if _focus.active else "REST", maxf(0.0, _focus.tuning.focus_max_air_duration - _focus.air_time_used)]

func _exit_tree() -> void:
	unbind()
