class_name InputRouter
extends Node

signal cancelled(reason: String)
signal action_rejected(reason: String)
const ACTION_ORDER: Array[StringName] = [&"jump", &"shoot_release", &"interact", &"drop_through"]
const MAX_ACTIONS := 16
const MAX_AGE_SECONDS := 0.1
var axis := 0.0
var epoch := 0
var sequence := 0
var _queue: Array[Dictionary] = []
var _last_tick := -1

func sample_axes() -> float:
	return axis

func set_move_axis(value: float) -> void:
	axis = clampf(value, -1.0, 1.0) if is_finite(value) else 0.0

func request_action(type: StringName, direction: Vector2 = Vector2.ZERO) -> bool:
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
	for action: Dictionary in _queue:
		if action.epoch == epoch and now - float(action.timestamp) <= MAX_AGE_SECONDS:
			merged[action.type] = action
	_queue.clear()
	for type: StringName in ACTION_ORDER:
		if merged.has(type):
			result.append(merged[type])
	return result

func cancel_actions_for(type: StringName) -> void:
	for index: int in range(_queue.size() - 1, -1, -1):
		if _queue[index].type == type:
			_queue.remove_at(index)

func clear(reason: String) -> void:
	axis = 0.0
	_queue.clear()
	epoch += 1
	cancelled.emit(reason)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		clear("focus_or_pause")
