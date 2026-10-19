class_name InputRouter
extends Node

signal cancelled(reason: String)
signal device_changed(device: StringName)
signal action_rejected(reason: String)
const ACTION_ORDER: Array[StringName] = [&"jump", &"jump_release", &"shoot_release", &"interact", &"drop_through", &"grapple", &"weapon_context", &"weapon_skill"]
const MAX_ACTIONS := 16
# Browsers may deliver touch-derived mouse events as device 0, not Godot emulation.
const TOUCH_MOUSE_GUARD_USEC := 400000
const MAX_AGE_SECONDS := 0.1
var axis := 0.0
var look_axis := 0.0
var aim_direction := Vector2.ZERO
var aim_engaged := false
var last_aim_direction := Vector2.ZERO
var _skill_primary_suppressed := false
var grapple_available := false
var weapon_context_available := false
var weapon_skill_available := false
var weapon_context_label := "CONTEXT"
var aim_mode: StringName = &"attack"
var current_device: StringName = &"keyboard_mouse"
var touch_enabled := false
var touch_mouse_guard_until_usec := 0
var _touch_contact_ids: Dictionary = {}
var has_application_focus := true
var profile: InputProfile = InputProfile.load_default()
var _source_axes: Dictionary = {}
var _jump_sources: Dictionary = {}
var epoch := 0
var sequence := 0
var _queue: Array[Dictionary] = []
var _last_tick := -1

func sample_axes() -> float:
	return axis

func set_move_axis(value: float) -> void:
	if not has_application_focus:
		return
	axis = clampf(value, -1.0, 1.0) if is_finite(value) else 0.0

func activate_device(source: StringName) -> void:
	if not has_application_focus:
		return
	if source != current_device:
		_source_axes.clear()
		axis = 0.0
		look_axis = 0.0
		aim_direction = Vector2.ZERO
		aim_engaged = false
		last_aim_direction=Vector2.ZERO;_skill_primary_suppressed=false
		current_device = source
		device_changed.emit(source)

func set_source_axis(source: StringName, value: float, meaningful: bool = false) -> void:
	if not has_application_focus:
		return
	if meaningful:
		activate_device(source)
	_source_axes[source] = value
	if source == current_device:
		set_move_axis(value)

func set_look_axis(source: StringName, value: float) -> void:
	if has_application_focus and source == current_device:
		look_axis = clampf(value, -1.0, 1.0) if is_finite(value) else 0.0

func set_aim(source: StringName, direction: Vector2, engaged: bool = false) -> void:
	if not has_application_focus:
		return
	if source == current_device:
		if engaged and not aim_engaged:_skill_primary_suppressed=false
		aim_direction = direction.normalized() if direction.is_finite() else Vector2.ZERO
		aim_engaged = engaged and not aim_direction.is_zero_approx()
		if not aim_direction.is_zero_approx():last_aim_direction=aim_direction

func reconfigure(candidate: Dictionary) -> bool:
	if not profile.configure(candidate):
		action_rejected.emit("invalid_input_profile")
		return false
	clear("input_profile_changed")
	return true

func load_profile(path: String) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return reconfigure(parsed) if parsed is Dictionary else false

func set_jump_held(source: StringName, held: bool) -> void:
	if not has_application_focus or (is_inside_tree() and get_tree().paused):
		return
	var was_held := not _jump_sources.is_empty()
	if held:
		_jump_sources[source] = true
	else:
		_jump_sources.erase(source)
	var is_held := not _jump_sources.is_empty()
	if is_held != was_held:
		request_action(&"jump" if is_held else &"jump_release")

func request_action(type: StringName, direction: Vector2 = Vector2.ZERO) -> bool:
	if not has_application_focus:
		action_rejected.emit("application_unfocused")
		return false
	if not ACTION_ORDER.has(type):
		action_rejected.emit("unknown_action")
		return false
	if _queue.size() >= MAX_ACTIONS:
		action_rejected.emit("queue_full")
		push_warning("InputRouter queue full; new action dropped")
		return false
	if type == &"shoot_release" and (not direction.is_finite() or direction.is_zero_approx()):
		action_rejected.emit("invalid_direction")
		return false
	if type==&"weapon_skill":
		if direction.is_zero_approx():direction=skill_direction()
		_skill_primary_suppressed=aim_engaged
		cancel_actions_for(&"shoot_release")
	sequence += 1
	_queue.append({"type": type, "sequence": sequence, "epoch": epoch, "timestamp": Time.get_ticks_usec() / 1000000.0, "direction": direction.normalized()})
	return true

func consume_actions(tick: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if tick <= _last_tick:
		return result
	_last_tick = tick
	var now := Time.get_ticks_usec() / 1000000.0
	var merged: Dictionary = {}
	var last_jump_edge: StringName = &""
	for action: Dictionary in _queue:
		if action.epoch != epoch or now - float(action.timestamp) > MAX_AGE_SECONDS:
			continue
		if action.type in [&"jump", &"jump_release"]:
			if action.type != last_jump_edge:
				result.append(action)
				last_jump_edge = action.type
		else:
			merged[action.type] = action
	_queue.clear()
	for action: Dictionary in merged.values():
		result.append(action)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.sequence < b.sequence)
	return result

func cancel_actions_for(type: StringName) -> void:
	for index: int in range(_queue.size() - 1, -1, -1):
		if _queue[index].type == type:
			_queue.remove_at(index)

func clear(reason: String) -> void:
	_touch_contact_ids.clear()
	last_aim_direction=Vector2.ZERO;_skill_primary_suppressed=false
	aim_mode = &"attack"
	axis = 0.0
	look_axis = 0.0
	aim_direction = Vector2.ZERO
	aim_engaged = false
	_source_axes.clear()
	_jump_sources.clear()
	_queue.clear()
	epoch += 1
	cancelled.emit(reason)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		has_application_focus = false
		clear("application_focus_out")
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		has_application_focus = true
		clear("application_focus_in")
	elif what == NOTIFICATION_PAUSED:
		clear("pause")

func primary_release(direction: Vector2) -> bool:
	if _skill_primary_suppressed:
		_skill_primary_suppressed=false;return false
	return request_action(&"shoot_release",direction) if aim_mode == &"attack" else false

func skill_direction() -> Vector2:
	if not aim_direction.is_zero_approx():return aim_direction
	return last_aim_direction if not last_aim_direction.is_zero_approx() else Vector2.UP

func _input(event: InputEvent) -> void:
	# Observe contact edges before GUI consumption, including handled releases.
	if touch_enabled and (event is InputEventScreenTouch or event is InputEventScreenDrag):observe_touch_pointer(event)
func observe_touch_pointer(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.canceled:_touch_contact_ids.clear()
		elif event.pressed:_touch_contact_ids[event.index]=true
		else:_touch_contact_ids.erase(event.index)
	touch_mouse_guard_until_usec=Time.get_ticks_usec()+TOUCH_MOUSE_GUARD_USEC
func touch_owns_pointer() -> bool:
	return touch_enabled and (not _touch_contact_ids.is_empty() or Time.get_ticks_usec()<touch_mouse_guard_until_usec)
