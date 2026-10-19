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
var hook_center := Vector2.ZERO
var hook_radius := 0.0
var context_center := Vector2.ZERO
var skill_center := Vector2.ZERO
var _hook_idle := Vector2.ZERO
var _hook_offset := Vector2.ZERO
var _hook_direction := Vector2.ZERO
var _aim_owner: StringName = &"attack"
var _right_suppressed := false
var radius := 90.0
var jump_radius := 64.0
var jump_hit_radius := 76.0
var _move_running := false
var _move_direction := 0.0
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
	router.device_changed.connect(_device_changed)
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
	if not is_inside_tree(): return
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
	jump_hit_radius = jump_radius + float(router.profile.values.touch_jump_hit_padding) * scale_factor
	var inset := float(router.profile.values.touch_jump_left_inset) * scale_factor
	var margin := 24.0 * scale_factor
	var gap := 24.0 * scale_factor
	# Fit configurable controls into their own half-screen even when a
	# profile requests oversized rings; fitting changes only touch layout.
	var fit := minf(1.0, (safe.size.x * 0.5 - gap - margin * 2) / (2 * (radius + jump_hit_radius) + inset))
	fit = minf(fit, (safe.size.y - margin * 2) / (2 * maxf(radius, jump_hit_radius)))
	radius *= fit
	jump_radius *= fit
	jump_hit_radius *= fit
	inset *= fit
	var controls_y := safe.end.y - maxf(radius, jump_hit_radius) - margin
	_left_idle = Vector2(safe.position.x + radius + margin, controls_y)
	jump_center = Vector2(safe.end.x - jump_hit_radius - margin - inset, controls_y)
	hook_radius = radius * .76
	_hook_idle = jump_center - Vector2(0,jump_hit_radius*2.3)
	hook_center = _hook_idle
	context_center=_hook_idle-Vector2(hook_radius*1.75,0)
	skill_center=_hook_idle-Vector2(0,hook_radius*1.75)
	_right_idle = Vector2(jump_center.x - jump_hit_radius - radius - gap, controls_y)
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
	if event is InputEventScreenTouch or event is InputEventScreenDrag:router.observe_touch_pointer(event)
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
			if router.weapon_context_available and event.position.distance_to(context_center)<=hook_radius*.8:
				region=&"context"
			elif router.weapon_skill_available and event.position.distance_to(skill_center)<=hook_radius*.8:
				region=&"skill"
			elif router.grapple_available and event.position.distance_to(hook_center) <= hook_radius:
				region = &"hook"
			elif event.position.distance_to(jump_center) <= jump_hit_radius:
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
			if region==&"context":
				router.request_action(&"weapon_context")
			elif region==&"skill":
				pass
			elif region == &"hook":
				hook_center = event.position
				_right_suppressed = _captures.values().has(&"right")
				router.cancel_actions_for(&"shoot_release")
				_update_stick(&"hook", event.position)
			elif region == &"jump":
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
					_right_suppressed = false
				_update_stick(region, event.position)
			queue_redraw()
			return true
		elif _captures.has(event.index):
			var region: StringName = _captures[event.index]
			if region==&"skill":
				router.request_action(&"weapon_skill",router.skill_direction())
			elif region == &"hook":
				_update_stick(&"hook", event.position)
				if router.grapple_available and not _hook_direction.is_zero_approx():
					router.request_action(&"grapple",_hook_direction)
				_hook_direction = Vector2.ZERO
				_hook_offset = Vector2.ZERO
				hook_center = _hook_idle
				_restore_other_aim(&"hook")
			elif region == &"jump":
				router.set_jump_held(&"touch", false)
			elif region == &"right":
				_update_stick(region, event.position)
				if not _direction.is_zero_approx() and not _right_suppressed and _aim_owner == &"attack":
					router.primary_release(_direction)
				_direction = Vector2.ZERO
				_right_offset = Vector2.ZERO
				_right_suppressed = false
				_restore_other_aim(&"right")
				right_center = _right_idle
			elif region == &"left":
				_left_offset = Vector2.ZERO
				router.set_source_axis(&"touch", 0.0)
				router.set_look_axis(&"touch", 0.0)
				_move_direction = 0.0
				_move_running = false
				_vertical_ready = true
				left_center = _left_idle
			_captures.erase(event.index)
			queue_redraw()
			return true
	elif event is InputEventScreenDrag and _captures.has(event.index):
		if get_tree().paused:
			return false
		if not event.relative.is_zero_approx() or _captures[event.index] in [&"left", &"right", &"hook"]:
			router.activate_device(&"touch")
		_update_stick(_captures[event.index], event.position)
		queue_redraw()
		return true
	return false

func _update_stick(region: StringName, location: Vector2) -> void:
	if region==&"skill":return
	if region == &"hook":
		_hook_offset = (location-hook_center).limit_length(hook_radius)
		var conditioned := router.profile.axis(_hook_offset / hook_radius,"right_sensitivity")
		_hook_direction = Vector2.ZERO
		if conditioned.length() > float(router.profile.values.touch_deadzone):
			var inverse := aim_origin.get_canvas_transform().affine_inverse() if is_instance_valid(aim_origin) else Transform2D.IDENTITY
			_hook_direction = ((inverse*(hook_center+_hook_offset))-(inverse*hook_center)).normalized()
		_aim_owner = &"grapple"
		router.aim_mode = _aim_owner
		router.set_aim(&"touch",_hook_direction,not _hook_direction.is_zero_approx())
	elif region == &"left":
		_left_offset = (location - left_center).limit_length(radius)
		var axis := router.profile.axis(_left_offset / radius, "left_sensitivity")
		router.set_source_axis(&"touch", _movement_axis(axis.x))
		router.set_look_axis(&"touch", axis.y)
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
		# A captured hook owns the aim until release. Gun micro-drags only
		# update its stored direction, and a revoked gun needs a new finger.
		if _captures.values().has(&"hook") or _right_suppressed: return
		_aim_owner = &"attack"
		router.aim_mode = _aim_owner
		router.set_aim(&"touch", _direction, not _direction.is_zero_approx())

func _restore_other_aim(released: StringName) -> void:
	if released == &"right" and _captures.values().has(&"hook"):
		_aim_owner = &"grapple"
		router.aim_mode = _aim_owner
		router.set_aim(&"touch", _hook_direction, not _hook_direction.is_zero_approx())
	elif released == &"hook" and _captures.values().has(&"right") and not _right_suppressed:
		_aim_owner = &"attack"
		router.aim_mode = _aim_owner
		router.set_aim(&"touch", _direction, not _direction.is_zero_approx())
	else:
		_aim_owner = &"attack"
		router.aim_mode = _aim_owner
		router.set_aim(&"touch", Vector2.ZERO, false)

func _device_changed(source: StringName) -> void:
	if source == &"touch": return
	# Only aim captures are revoked; an independently held jump can release.
	for index: int in _captures.keys():
		if _captures[index] in [&"hook", &"right"]: _captures.erase(index)
	_direction = Vector2.ZERO
	_hook_direction = Vector2.ZERO
	_right_offset = Vector2.ZERO
	_hook_offset = Vector2.ZERO
	_right_suppressed = false
	_aim_owner = &"attack"
	router.aim_mode = &"attack"
	router.cancel_actions_for(&"shoot_release")
	router.cancel_actions_for(&"grapple")

func _movement_axis(value: float) -> float:
	var p := router.profile.values
	var magnitude := absf(value)
	var direction := signf(value)
	if magnitude <= float(p.touch_move_stop_deadzone) or (direction != _move_direction and magnitude < float(p.left_deadzone)):
		_move_direction = 0.0
		_move_running = false
		return 0.0
	if direction != _move_direction:
		_move_running = false
	_move_direction = direction
	if p.touch_move_mode == "analog":
		return value if magnitude >= float(p.left_deadzone) else 0.0
	if p.touch_move_mode == "digital":
		return direction
	# Separate enter/exit thresholds keep a resting thumb from changing gears.
	if magnitude >= float(p.touch_run_enter):
		_move_running = true
	elif magnitude <= float(p.touch_run_exit):
		_move_running = false
	return direction * (1.0 if _move_running else float(p.touch_walk_ratio))

func _cancel(_reason: String) -> void:
	_captures.clear()
	_move_direction = 0.0
	_move_running = false
	_left_offset = Vector2.ZERO
	_right_offset = Vector2.ZERO
	_direction = Vector2.ZERO
	_hook_direction = Vector2.ZERO
	_hook_offset = Vector2.ZERO
	_right_suppressed = false
	_aim_owner = &"attack"
	_vertical_ready = true
	update_layout()

func _draw() -> void:
	if enabled and router.weapon_context_available:
		draw_circle(context_center,hook_radius*.8,Color(.55,.65,.4,.6))
		draw_string(ThemeDB.fallback_font,context_center+Vector2(-23,4),router.weapon_context_label,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.WHITE)
	if enabled and router.weapon_skill_available:
		draw_circle(skill_center,hook_radius*.8,Color(.35,.45,.8,.65))
		draw_circle(skill_center,5,Color(.8,.8,1,.8))
		draw_string(ThemeDB.fallback_font,skill_center+Vector2(-16,4),"SKILL",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.WHITE)
	if not enabled:
		return
	for center: Vector2 in [left_center, right_center]:
		draw_circle(center, radius, Color(0.4, 0.65, 0.8, 0.08))
		draw_arc(center, radius, 0, TAU, 48, Color(0.7, 0.85, 0.9, 0.30), 2)
	draw_circle(left_center + _left_offset, radius * 0.25, Color(0.8, 0.9, 1, 0.35))
	draw_circle(right_center + _right_offset, radius * 0.25, Color(1, 0.65, 0.3, 0.35))
	if router.grapple_available:
		draw_circle(hook_center,hook_radius,Color(.85,.67,.26,.12))
		draw_arc(hook_center,hook_radius,0,TAU,48,Color(.95,.78,.40,.65),2)
		draw_circle(hook_center+_hook_offset,hook_radius*.25,Color(.95,.78,.40,.6))
		draw_string(ThemeDB.fallback_font,hook_center+Vector2(-20,5),"HOOK",HORIZONTAL_ALIGNMENT_LEFT,-1,14)
	draw_circle(jump_center, jump_radius, Color(0.35, 0.8, 0.6, 0.32))
	var font := ThemeDB.fallback_font
	draw_string(font, jump_center + Vector2(-22, 6), "JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	draw_rect(_pause_rect, Color(0.2, 0.3, 0.4, 0.8))
	if not hide_reset_button:
		draw_rect(_reset_rect, Color(0.2, 0.3, 0.4, 0.8))
	draw_string(font, _pause_rect.position + Vector2(12, 30), "RESUME" if get_tree().paused else pause_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	if not hide_reset_button:
		draw_string(font, _reset_rect.position + Vector2(12, 30), reset_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
