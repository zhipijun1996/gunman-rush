class_name BossPresentationState
extends RefCounted
## Detached, read-only observation. Names and raw clocks retain owner semantics.
## No Node, Resource, target, mutable path or combat controller is exported.
var _values: Dictionary

func _init(values: Dictionary = {}) -> void:
	_values = values.duplicate(true)

var state_id: StringName:
	get: return _values.get("state_id", &"")
var state_source: StringName:
	get: return _values.get("state_source", &"encounter")
var raw_mode: StringName:
	get: return _values.get("raw_mode", &"")
var phase: int:
	get: return _values.get("phase", 1)
var phase_axes: Dictionary:
	get: return _values.get("phase_axes", {}).duplicate(true)
var raw_clock: float:
	get: return _values.get("raw_clock", 0.0)
var clock_kind: StringName:
	get: return _values.get("clock_kind", &"none")
var clock_domain: StringName:
	get: return _values.get("clock_domain", &"none")
var telegraph_duration: float:
	get: return _values.get("telegraph_duration", 0.0)
var telegraphing: bool:
	get: return _values.get("telegraphing", false)
var warning_progress: float:
	get: return _values.get("warning_progress", 0.0)
var release_action: bool:
	get: return _values.get("release_action", false)
var sustained_action: bool:
	get: return _values.get("sustained_action", false)
var recovery_active: bool:
	get: return _values.get("recovery_active", false)
var active: bool:
	get: return _values.get("active", false)
var terminal: bool:
	get: return _values.get("terminal", false)
var health_epoch: int:
	get: return _values.get("health_epoch", 0)
var position: Vector2:
	get: return _values.get("position", Vector2.ZERO)
var direction: float:
	get: return _values.get("direction", 1.0)
var damage_model: StringName:
	get: return _values.get("damage_model", &"body")
var core_hint_visible: bool:
	get: return _values.get("core_hint_visible", false)
var body_contact_enabled: bool:
	get: return _values.get("body_contact_enabled", false)

func as_dictionary() -> Dictionary:
	return _values.duplicate(true)
