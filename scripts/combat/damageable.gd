class_name Damageable
extends Node

signal damaged(context: Dictionary)
signal health_changed(health: float)
signal died
@export var max_health := 3.0
@export var faction: StringName = &"target"
@export var actor_id := 0
var _legacy_health := 3.0
var _legacy_active := true
var _health_state: HealthState
var _death_emitted := false
var health: float:
	get: return _health_state.current if _health_state != null else _legacy_health
var active: bool:
	get: return not _health_state.terminal if _health_state != null else _legacy_active
var damage_epoch: int:
	get: return _health_state.epoch if _health_state != null else 0
var _events: Dictionary = {}
var damage_sink: Callable

func _ready() -> void:
	reset()

func reset() -> void:
	_legacy_health = max_health
	_legacy_active = true
	_death_emitted = false
	_events.clear()

func receive_damage(context: Dictionary) -> bool:
	var event_id: String = str(context.get("event_id", ""))
	var amount: float = float(context.get("amount", 0.0))
	if not active or amount <= 0.0 or not is_finite(amount) or event_id.is_empty() or _events.has(event_id):
		return false
	if context.get("source_faction", &"") == faction or (actor_id != 0 and context.get("source_actor_id", 0) == actor_id):
		return false
	if _health_state != null:
		if context.get("target_actor_id", -1) != actor_id or context.get("target_epoch", -1) != damage_epoch:
			return false
		if damage_sink.is_valid():
			return damage_sink.call(context) == true
		var request := ActorResourceRequest.new(StringName(event_id), damage_epoch, amount, _health_state.get_instance_id())
		var result := _health_state.apply_damage(request)
		if result.status != ActorResourceResult.Status.APPLIED:
			return false
		_events[event_id] = true
		damaged.emit(context)
		return true
	_events[event_id] = true
	_legacy_health = maxf(0.0, health - amount)
	damaged.emit(context)
	health_changed.emit(health)
	if health == 0.0:
		_legacy_active = false
		died.emit()
	return true

# Adapter for the existing projectile contract. New actors keep exactly one HP
# owner; legacy graybox targets retain their old counter until their migration.
func bind_health(state: HealthState) -> void:
	if _health_state != null and _health_state.changed.is_connected(_state_changed):
		_health_state.changed.disconnect(_state_changed)
	_health_state = state
	_events.clear()
	_death_emitted = false
	if _health_state != null:
		_health_state.changed.connect(_state_changed)
		_state_changed(null)

func _state_changed(_result: ActorResourceResult) -> void:
	health_changed.emit(health)
	if not active and not _death_emitted:
		_death_emitted = true
		died.emit()
	elif active:
		_death_emitted = false
