class_name Damageable
extends Node

signal damaged(context: Dictionary)
signal health_changed(health: float)
signal died
@export var max_health := 3.0
@export var faction: StringName = &"target"
@export var actor_id := 0
var health := 3.0
var active := true
var _events: Dictionary = {}

func _ready() -> void:
	reset()

func reset() -> void:
	health = max_health
	active = true
	_events.clear()

func receive_damage(context: Dictionary) -> bool:
	var event_id: String = str(context.get("event_id", ""))
	var amount: float = float(context.get("amount", 0.0))
	if not active or amount <= 0.0 or not is_finite(amount) or event_id.is_empty() or _events.has(event_id):
		return false
	if context.get("source_faction", &"") == faction or (actor_id != 0 and context.get("source_actor_id", 0) == actor_id):
		return false
	_events[event_id] = true
	health = maxf(0.0, health - amount)
	damaged.emit(context)
	health_changed.emit(health)
	if health == 0.0:
		active = false
		died.emit()
	return true
