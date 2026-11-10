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
var chill_remaining := 0.0
var chill_speed_scale := 1.0
var _chill_body: CanvasItem
var _chill_color := Color.WHITE

func apply_chill(seconds:float,speed_scale:float)->void:
	if not active or faction!=&"enemy" or not is_finite(seconds) or seconds<=0 or not is_finite(speed_scale) or speed_scale<=0 or speed_scale>1:return
	if chill_remaining<=0:
		_chill_body=instance_from_id(actor_id) as CanvasItem if actor_id!=0 and is_instance_id_valid(actor_id) else get_parent() as CanvasItem
		if is_instance_valid(_chill_body):_chill_color=_chill_body.modulate
	chill_remaining=seconds;chill_speed_scale=speed_scale
	if is_instance_valid(_chill_body):_chill_body.modulate=_chill_color*Color(.68,1.05,1.4,1)
	set_physics_process(true)

func action_time_scale()->float:
	return chill_speed_scale if chill_remaining>0 and active else 1.0

func clear_chill()->void:
	chill_remaining=0;chill_speed_scale=1
	if is_instance_valid(_chill_body):_chill_body.modulate=_chill_color
	_chill_body=null;set_physics_process(false)

func _physics_process(delta:float)->void:
	chill_remaining=maxf(0,chill_remaining-delta)
	if chill_remaining<=0 or not active:clear_chill()

func _ready() -> void:
	reset()

func reset() -> void:
	clear_chill()
	_legacy_health = max_health
	_legacy_active = true
	_death_emitted = false
	_events.clear()

func impact_style() -> StringName:
	return &"ordinary"

## Physical armour can block shots without occupying an area-effect cooldown.
func can_receive_effects() -> bool:
	return active

## Keep spatial receiver and the single frame-policy/HP owner distinct.
func damage_policy_owner() -> Damageable:
	return self

## Cosmetic contact is separate from damage authorization and effect budgets.
func physical_impact(_point: Vector2) -> void:
	pass

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
		_notify_commit(context)
		return true
	_events[event_id] = true
	_legacy_health = maxf(0.0, health - amount)
	damaged.emit(context)
	health_changed.emit(health)
	if health == 0.0:
		_legacy_active = false
		died.emit()
	_notify_commit(context)
	return true

func _notify_commit(context: Dictionary) -> void:
	var callback: Callable=context.get("on_committed",Callable())
	if callback.is_valid(): callback.call()

# Adapter for the existing projectile contract. New actors keep exactly one HP
# owner; legacy graybox targets retain their old counter until their migration.
func bind_health(state: HealthState) -> void:
	clear_chill()
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
		clear_chill()
		_death_emitted = true
		died.emit()
	elif active:
		_death_emitted = false
