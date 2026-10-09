class_name InputRouter
extends Node

signal cancelled(reason: String)
signal device_changed(device: StringName)
signal action_rejected(reason: String)
const ACTION_ORDER: Array[StringName] = [&"jump", &"jump_release", &"shoot_release", &"interact", &"drop_through"]
const MAX_ACTIONS := 16
const MAX_AGE_SECONDS := 0.1
var axis := 0.0
var aim_direction := Vector2.ZERO
var aim_engaged := false
var current_device: StringName = &"keyboard_mouse"
var touch_enabled := false
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
		aim_direction = Vector2.ZERO
		aim_engaged = false
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

func set_aim(source: StringName, direction: Vector2, engaged: bool = false) -> void:
	if not has_application_focus:
		return
	if source == current_device:
		aim_direction = direction.normalized() if direction.is_finite() else Vector2.ZERO
		aim_engaged = engaged and not aim_direction.is_zero_approx()

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
	axis = 0.0
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
