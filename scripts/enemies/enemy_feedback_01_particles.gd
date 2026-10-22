class_name EnemyFeedback01Particles
extends Node2D
## Existing committed Damageable event + shared receipt; no collision or audio.
## A bounded, local 2-world-unit pixel burst, frozen by the host's pause mode.
const MAX_BURSTS := 3
const CREAM := Color("fff2b3")
const BRASS := Color("d7a85a")
var sample: EnemyFeedback01
var receiver: Damageable
var _bursts: Array[Dictionary] = []
var _last_serial := 0
var _epoch := -1
var emitted_bursts := 0

func bind(state: EnemyFeedback01, damageable: Damageable) -> void:
	sample = state
	receiver = damageable
	_epoch = sample.epoch()
	receiver.damaged.connect(_committed_impact)

func _committed_impact(context: Dictionary) -> void:
	if sample == null or sample.last_event_id != StringName(context.get("event_id", "")) or context.get("target_epoch", -1) != sample.epoch() or _last_serial == sample.impact_serial: return
	var point: Variant = context.get("hit_point", global_position)
	var direction: Variant = context.get("hit_direction", Vector2.RIGHT)
	if not point is Vector2 or not direction is Vector2 or not (point as Vector2).is_finite() or not (direction as Vector2).is_finite(): return
	if _epoch != sample.epoch():
		_epoch = sample.epoch()
		_bursts.clear()
	_last_serial = sample.impact_serial
	var lethal := sample.death_active
	if _bursts.size() >= MAX_BURSTS: _bursts.pop_front()
	_bursts.append({"point": point, "direction": -(direction as Vector2).normalized(), "age": 0.0, "lethal": lethal})
	emitted_bursts += 1
	queue_redraw()

func _process(delta: float) -> void:
	if get_tree().paused: return
	if sample == null: return
	if _epoch != sample.epoch():
		_epoch = sample.epoch()
		_bursts.clear()
	for burst: Dictionary in _bursts: burst.age = float(burst.age) + delta
	_bursts = _bursts.filter(func(burst: Dictionary) -> bool: return float(burst.age) < (.42 if burst.lethal else .26))
	queue_redraw()

func _draw() -> void:
	if sample == null or _epoch != sample.epoch(): return
	for burst: Dictionary in _bursts:
		var duration := .42 if burst.lethal else .26
		var progress := float(burst.age) / duration
		var center := to_local(burst.point)
		var base: Vector2 = burst.direction
		if base.is_zero_approx(): base = Vector2.LEFT
		var count := 18 if burst.lethal else 14
		var radius := 40.0 if burst.lethal else 28.0
		for i: int in count:
			var angle := TAU * float(i) / count
			var unit := Vector2.from_angle(angle)
			var travel := unit * radius * (1.0 - pow(1.0-progress, 2.0)) + base * progress * 12
			travel.y += progress * progress * 12
			var p := (center + travel).snapped(Vector2(2, 2))
			var width := 4.0 if i % 3 == 0 else 2.0
			var color := CREAM if i % 3 != 1 else BRASS
			color.a = 1.0 - progress
			draw_rect(Rect2(p, Vector2(width, 2)), color)
		if progress < .35:
			# Brief asymmetric contact star, never a full-screen glow or round cloud.
			var reach := 8.0 * (1.0 - progress/.35)
			draw_line(center-Vector2(reach, 0), center+Vector2(reach, 0), CREAM, 2)
			draw_line(center-Vector2(0, reach), center+Vector2(0, reach), CREAM, 2)

func active_bursts() -> int:
	return _bursts.size()

func clear_for_epoch() -> void:
	_epoch = sample.epoch()
	_bursts.clear()
	queue_redraw()

func _exit_tree() -> void:
	if is_instance_valid(receiver) and receiver.damaged.is_connected(_committed_impact): receiver.damaged.disconnect(_committed_impact)
	_bursts.clear()
	sample = null
	receiver = null
