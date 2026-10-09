class_name ActorResourcesHud
extends Control

var health_bar: ProgressBar
var health_label: Label
var stamina_bar: ProgressBar
var stamina_label: Label
var _resources: ActorResources
var _focus: AirFocusAbility

func bind(resources: ActorResources, focus: AirFocusAbility = null) -> void:
	unbind()
	_resources = resources
	_focus = focus
	if health_bar == null:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		health_bar = _make_bar(Vector2(22, 78), Color(0.82, 0.28, 0.32))
		health_label = _make_label(Vector2(252, 73))
		stamina_bar = _make_bar(Vector2(22, 95), Color(0.9, 0.68, 0.2))
		stamina_label = _make_label(Vector2(252, 90))
	if is_instance_valid(_resources):
		_resources.health.changed.connect(_health_changed)
		_resources.stamina.changed.connect(_stamina_changed)
		_refresh_health(_resources.health.snapshot())
		_refresh_stamina(_resources.stamina.snapshot())

func unbind() -> void:
	if is_instance_valid(_resources):
		if _resources.health.changed.is_connected(_health_changed):
			_resources.health.changed.disconnect(_health_changed)
		if _resources.stamina.changed.is_connected(_stamina_changed):
			_resources.stamina.changed.disconnect(_stamina_changed)
	_resources = null
	_focus = null

func _make_bar(location: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = location
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.15, 0.2, 0.25)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	bar.size = Vector2(220, 10)
	bar.scale = Vector2(1.0, 0.35)
	add_child(bar)
	return bar

func _make_label(location: Vector2) -> Label:
	var label := Label.new()
	label.position = location
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 14)
	add_child(label)
	return label

func _health_changed(result: ActorResourceResult) -> void:
	_refresh_health(result.snapshot)

func _stamina_changed(result: ActorResourceResult) -> void:
	_refresh_stamina(result.snapshot)

func _refresh_health(value: ActorResourceSnapshot) -> void:
	health_bar.max_value = value.capacity
	health_bar.value = value.current
	health_label.text = "HP %.0f/%.0f" % [value.current, value.capacity]

func _refresh_stamina(value: ActorResourceSnapshot) -> void:
	stamina_bar.max_value = value.capacity
	stamina_bar.value = value.current
	stamina_label.text = "STAMINA %.0f/%.0f" % [value.current, value.capacity]

func _process(_delta: float) -> void:
	if is_instance_valid(_resources) and is_instance_valid(_focus):
		stamina_label.text = "FOCUS %.0f/%.0f | %s | %.1fs left" % [_resources.stamina.current, _resources.stamina.capacity, "SLOW AIM" if _focus.active else "air aim slows / ground recharges", maxf(0.0, _focus.tuning.focus_max_air_duration - _focus.air_time_used)]

func _exit_tree() -> void:
	unbind()
