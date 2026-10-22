class_name EnemyFeedback01Particles
extends Node2D
## Existing committed Damageable event + shared receipt; no collision or audio.
## Brief tapered contact fan + fine directional chips; the host owns pause.
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
	_bursts.append({"point": point, "direction": -(direction as Vector2).normalized(), "age": 0.0, "lethal": lethal, "serial": sample.impact_serial})
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
		var center := to_local(burst.point)
		var base: Vector2 = burst.direction
		if base.is_zero_approx(): base = Vector2.LEFT
		var count := 12 if burst.lethal else 8
		# Enlarge the spatial envelope, not the pixel blocks. Three very brief
		# tapered splinters establish the contact before the fine chips separate.
		var contact := 1.0 - clampf(float(burst.age) / .075, 0, 1)
		if contact > 0:
			for ray: int in 3:
				var axis := base.rotated(float(ray-1) * .72)
				var side := axis.orthogonal()
				var length := (20.0 if burst.lethal else 15.0) * (1.0 if ray == 1 else .66)
				var root := center + axis * 2
				var tip := center + axis * length * (.55 + .45 * contact)
				var width := (1.2 if ray == 1 else .75) * contact
				var points := PackedVector2Array([root-side*width, tip, root+side*width])
				draw_colored_polygon(points, Color(CREAM, contact * .95))
		# No radial ring, chunky confetti or gameplay RNG consumption.
		for i: int in count:
			var variant := (i * 5 + int(burst.serial)) % 11
			var life := duration * (.58 + float(variant) * .038)
			var progress := float(burst.age) / life
			if progress >= 1: continue
			var angle := -.95 + float((i * 7) % count) / maxf(1, count-1) * 1.9
			var unit := base.rotated(angle)
			var speed := 92.0 + float(variant) * 7.0
			var travel := unit * speed * life * (progress - .32*progress*progress)
			travel.y += 38 * float(burst.age) * float(burst.age)
			var p := (center + travel).snapped(Vector2.ONE)
			var color := CREAM if i % 3 == 0 and progress < .4 else BRASS
			color.a = .85 * pow(1.0 - progress, 1.4)
			var tail := (p - unit * (3.0 if progress < .3 else 1.0)).snapped(Vector2.ONE)
			draw_line(tail, p, color, 1, false)

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
