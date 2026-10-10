class_name TouchOverlay
extends Control

var reset_label := "RESET"
var pause_label := "PAUSE"
var hide_reset_button := false

signal pause_requested
signal reset_requested
var router: InputRouter
var aim_origin: Node2D
var enabled := false
var left_center := Vector2.ZERO
var right_center := Vector2.ZERO
var jump_center := Vector2.ZERO
var radius := 90.0
var jump_radius := 48.0
var _captures: Dictionary = {}
var _left_offset := Vector2.ZERO
var _right_offset := Vector2.ZERO
var _direction := Vector2.ZERO
var _vertical_ready := true
var _layout_size := Vector2.ZERO
var _pause_rect := Rect2()
var _reset_rect := Rect2()
var _safe_rect := Rect2()
var _left_idle := Vector2.ZERO
var _right_idle := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	router.cancelled.connect(_cancel)
	set_enabled(OS.has_feature("android") or OS.has_feature("ios") or (OS.has_feature("web") and DisplayServer.is_touchscreen_available()))
	update_layout()

func set_enabled(value: bool) -> void:
	if enabled != value and is_instance_valid(router):
		router.clear("touch_overlay_changed")
	enabled = value
	visible = value
	if is_instance_valid(router):
		router.touch_enabled = value
		if value:
			router.activate_device(&"touch")

func update_layout() -> void:
	var viewport_size := get_viewport_rect().size
	_layout_size = viewport_size
	var safe := Rect2(Vector2.ZERO, viewport_size)
	if OS.has_feature("android") or OS.has_feature("ios"):
		var physical := DisplayServer.get_display_safe_area()
		var window_size := Vector2(DisplayServer.window_get_size())
		if window_size.x > 0 and window_size.y > 0 and physical.size.x > 0 and physical.size.y > 0:
			var screen_transform := get_viewport().get_screen_transform().affine_inverse()
			var window_origin := Vector2(DisplayServer.window_get_position())
			var start := screen_transform * (Vector2(physical.position) - window_origin)
			var end := screen_transform * (Vector2(physical.end) - window_origin)
			safe = Rect2(start, end - start).intersection(safe)
	_configure_layout(safe, viewport_size)

func _configure_layout(safe: Rect2, viewport_size: Vector2) -> void:
	_safe_rect = safe
	var scale_factor := minf(safe.size.x / 1280.0, safe.size.y / 720.0)
	radius = float(router.profile.values.touch_radius) * scale_factor
	jump_radius = float(router.profile.values.touch_jump_radius) * scale_factor
	var margin := 24.0 * scale_factor
	var gap := 24.0 * scale_factor
	# Fit configurable controls into their own half-screen even when a
	# profile requests oversized rings; fitting changes only touch layout.
	var fit := minf(1.0, (safe.size.x * 0.5 - gap - margin * 2) / (2 * (radius + jump_radius)))
	fit = minf(fit, (safe.size.y - margin * 2) / (2 * maxf(radius, jump_radius)))
	radius *= fit
	jump_radius *= fit
	var controls_y := safe.end.y - maxf(radius, jump_radius) - margin
	_left_idle = Vector2(safe.position.x + radius + margin, controls_y)
	jump_center = Vector2(safe.end.x - jump_radius - margin, controls_y)
	_right_idle = Vector2(jump_center.x - jump_radius - radius - gap, controls_y)
	left_center = _left_idle
	right_center = _right_idle
	_pause_rect = Rect2(safe.end.x - 100 * scale_factor, safe.position.y + 12 * scale_factor, 88 * scale_factor, 48 * scale_factor)
	_reset_rect = Rect2(safe.end.x - 200 * scale_factor, safe.position.y + 12 * scale_factor, 88 * scale_factor, 48 * scale_factor)
	_layout_size = viewport_size
	queue_redraw()

func _process(_delta: float) -> void:
	if enabled and _layout_size != get_viewport_rect().size:
		router.clear("touch_viewport_changed")

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if handle_touch(event):
			get_viewport().set_input_as_handled()

func handle_touch(event: InputEvent) -> bool:
	if not enabled or not router.has_application_focus:
		return false
	if event is InputEventScreenTouch:
		if event.canceled:
			router.clear("system_touch_cancel")
			return true
		if event.pressed:
			if _captures.has(event.index):
				return true
			var region: StringName = &""
			# GUI Controls consume their touches before this unhandled adapter. Jump
			# and menu hit tests precede the floating sticks, even inside a ring.
			if event.position.distance_to(jump_center) <= jump_radius:
				region = &"jump"
			elif _pause_rect.has_point(event.position):
				region = &"pause"
			elif not hide_reset_button and _reset_rect.has_point(event.position):
				region = &"reset"
			elif _safe_rect.has_point(event.position):
				region = &"left" if event.position.x < _safe_rect.get_center().x else &"right"
			if get_tree().paused and region not in [&"pause", &"reset"]:
				return false
			if region == &"" or region in _captures.values():
				return false
			_captures[event.index] = region
			router.activate_device(&"touch")
			if region == &"jump":
				router.set_jump_held(&"touch", true)
			elif region == &"pause":
				pause_requested.emit()
			elif region == &"reset":
				reset_requested.emit()
			else:
				# Keep the exact touch origin; clamping it would create an aim
				# vector on an edge tap. Drawing alone is clipped to the viewport.
				if region == &"left":
					left_center = event.position
				else:
					right_center = event.position
				_update_stick(region, event.position)
			queue_redraw()
			return true
		elif _captures.has(event.index):
			var region: StringName = _captures[event.index]
			if region == &"jump":
				router.set_jump_held(&"touch", false)
			elif region == &"right":
				_update_stick(region, event.position)
				if not _direction.is_zero_approx():
					router.request_action(&"shoot_release", _direction)
				_direction = Vector2.ZERO
				_right_offset = Vector2.ZERO
				router.set_aim(&"touch", Vector2.ZERO)
				right_center = _right_idle
			elif region == &"left":
				_left_offset = Vector2.ZERO
				router.set_source_axis(&"touch", 0.0)
				_vertical_ready = true
				left_center = _left_idle
			_captures.erase(event.index)
			queue_redraw()
			return true
	elif event is InputEventScreenDrag and _captures.has(event.index):
		if get_tree().paused:
			return false
		if not event.relative.is_zero_approx() or _captures[event.index] in [&"left", &"right"]:
			router.activate_device(&"touch")
		_update_stick(_captures[event.index], event.position)
		queue_redraw()
		return true
	return false

func _update_stick(region: StringName, location: Vector2) -> void:
	if region == &"left":
		_left_offset = (location - left_center).limit_length(radius)
		var axis := router.profile.axis(_left_offset / radius, "left_sensitivity")
		if axis.length() < float(router.profile.values.left_deadzone):
			axis = Vector2.ZERO
		router.set_source_axis(&"touch", axis.x)
		if absf(axis.y) < 0.35:
			_vertical_ready = true
		elif absf(axis.y) >= 0.65 and _vertical_ready:
			_vertical_ready = false
			router.request_action(&"interact" if axis.y < 0.0 else &"drop_through")
	elif region == &"right":
		_right_offset = (location - right_center).limit_length(radius)
		_direction = Vector2.ZERO
		var conditioned := router.profile.axis(_right_offset / radius, "right_sensitivity")
		if conditioned.length() > float(router.profile.values.touch_deadzone):
			var inverse := aim_origin.get_canvas_transform().affine_inverse() if is_instance_valid(aim_origin) else Transform2D.IDENTITY
			_direction = ((inverse * (right_center + _right_offset)) - (inverse * right_center)).normalized()
		router.set_aim(&"touch", _direction, not _direction.is_zero_approx())

func _cancel(_reason: String) -> void:
	_captures.clear()
	_left_offset = Vector2.ZERO
	_right_offset = Vector2.ZERO
	_direction = Vector2.ZERO
	_vertical_ready = true
	update_layout()

func _draw() -> void:
	if not enabled:
		return
	for center: Vector2 in [left_center, right_center]:
		draw_circle(center, radius, Color(0.4, 0.65, 0.8, 0.08))
		draw_arc(center, radius, 0, TAU, 48, Color(0.7, 0.85, 0.9, 0.30), 2)
	draw_circle(left_center + _left_offset, radius * 0.25, Color(0.8, 0.9, 1, 0.35))
	draw_circle(right_center + _right_offset, radius * 0.25, Color(1, 0.65, 0.3, 0.35))
	draw_circle(jump_center, jump_radius, Color(0.35, 0.8, 0.6, 0.32))
	var font := ThemeDB.fallback_font
	draw_string(font, jump_center + Vector2(-22, 6), "JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	draw_rect(_pause_rect, Color(0.2, 0.3, 0.4, 0.8))
	if not hide_reset_button:
		draw_rect(_reset_rect, Color(0.2, 0.3, 0.4, 0.8))
	draw_string(font, _pause_rect.position + Vector2(12, 30), "RESUME" if get_tree().paused else pause_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	if not hide_reset_button:
		draw_string(font, _reset_rect.position + Vector2(12, 30), reset_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
