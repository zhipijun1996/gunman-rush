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
var _material_family: StringName = &""
var _kill_hold_seconds := 0.0

func bind(state: EnemyFeedback01, damageable: Damageable) -> void:
	sample = state
	receiver = damageable
	_epoch = sample.epoch()
	var actor := receiver.get_parent().get_node_or_null("Actor") as EnemyActor
	if PlainsEnemyAudio.supports(actor):
		_material_family = PlainsEnemyAudio.family(actor.definition)
		var hold := sample.tuning.plains_kill_hold_seconds
		_kill_hold_seconds = clampf(hold, 0.0, 0.06) if is_finite(hold) else 0.0
	receiver.damaged.connect(_committed_impact)
	set_process(false)

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
	var scoped := not _material_family.is_empty()
	var chip_direction := (direction as Vector2).normalized() * (1.0 if scoped else -1.0)
	_bursts.append({"point": point, "direction": chip_direction, "age": 0.0, "lethal": lethal, "serial": sample.impact_serial, "hold_remaining": _kill_hold_seconds if scoped and lethal else 0.0})
	emitted_bursts += 1
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if get_tree().paused: return
	if sample == null: return
	if _epoch != sample.epoch():
		_epoch = sample.epoch()
		_bursts.clear()
	for burst: Dictionary in _bursts:
		var held := minf(delta, float(burst.hold_remaining))
		burst.hold_remaining = float(burst.hold_remaining) - held
		burst.age = float(burst.age) + delta - held
	_bursts = _bursts.filter(func(burst: Dictionary) -> bool: return float(burst.age) < (.42 if burst.lethal else .26))
	queue_redraw()
	if _bursts.is_empty(): set_process(false)

func _draw() -> void:
	if sample == null or _epoch != sample.epoch(): return
	for burst: Dictionary in _bursts:
		var scoped := not _material_family.is_empty()
		var duration := .42 if burst.lethal else .26
		var center := to_local(burst.point)
		var base: Vector2 = burst.direction
		if base.is_zero_approx(): base = Vector2.LEFT
		var count := (7 if burst.lethal else 4) if scoped else (18 if burst.lethal else 12)
		# Enlarge the spatial envelope, not the pixel blocks. Five very brief
		# tapered splinters establish the contact before the fine chips separate.
		var contact := 1.0 - clampf(float(burst.age) / (.045 if scoped else .075), 0, 1)
		if contact > 0:
			var rays := 3 if scoped else 5
			var middle := 1 if scoped else 2
			for ray: int in rays:
				var axis := base.rotated(float(ray - middle) * .43)
				var side := axis.orthogonal()
				var ray_weight := (1.0 if ray == middle else .65) if scoped else (1.0 if ray == 2 else .72 if ray % 2 == 1 else .52)
				var length := ((18.0 if burst.lethal else 12.0) if scoped else (42.0 if burst.lethal else 31.0)) * ray_weight
				var root := center + axis * 2
				var tip := center + axis * length * (.55 + .45 * contact)
				var width := (1.0 if scoped else (2.3 if ray == 2 else 1.2)) * contact
				var points := PackedVector2Array([root-side*width, tip, root+side*width])
				draw_colored_polygon(points, Color(CREAM, contact * .95))
		# A short through-impact counterstroke reads the shot direction without
		# moving the actor/camera or changing the accepted hurt clock.
		if contact > 0 and not scoped:
			var counter := -base
			var side := counter.orthogonal()
			var tip := center + counter * (22 if burst.lethal else 16) * (.6 + .4 * contact)
			draw_colored_polygon(PackedVector2Array([center-side*contact, tip, center+side*contact]), Color(CREAM, contact*.8))
		# No full radial ring, chunky confetti or gameplay RNG consumption.
		for i: int in count:
			var variant := (i * 5 + int(burst.serial)) % 11
			var life := duration * (.58 + float(variant) * .038)
			var progress := float(burst.age) / life
			if progress >= 1: continue
			var angle := -.95 + float((i * 7) % count) / maxf(1, count-1) * 1.9
			var unit := base.rotated(angle)
			var speed := (70.0 + float(variant) * 5.0) if scoped else (145.0 + float(variant) * 9.0)
			var travel := unit * speed * life * (progress - .32*progress*progress)
			travel.y += (110 if scoped else 38) * float(burst.age) * float(burst.age)
			var p := (center + travel).snapped(Vector2.ONE)
			var color := CREAM if i % 3 == 0 and progress < .4 else BRASS
			if scoped:
				color = Color("b8ac7f") if _material_family == &"shell" else Color("aeb9ba") if _material_family == &"wing" else Color("94a071")
				if i % 2 == 1: color = Color("826347") if _material_family != &"wing" else BRASS
			color.a = .85 * pow(1.0 - progress, 1.4)
			var tail := (p - unit * ((2.0 if progress < .3 else 1.0) if scoped else (6.0 if progress < .3 else 2.0))).snapped(Vector2.ONE)
			draw_line(tail, p, color, 1.0 if scoped else (1.5 if progress < .25 else 1.0), false)

func active_bursts() -> int:
	return _bursts.size()

func clear_for_epoch() -> void:
	_epoch = sample.epoch()
	_bursts.clear()
	set_process(false)
	queue_redraw()

func dispose() -> void:
	set_process(false)
	if is_instance_valid(receiver) and receiver.damaged.is_connected(_committed_impact): receiver.damaged.disconnect(_committed_impact)
	_bursts.clear()
	sample = null
	receiver = null
	queue_redraw()

func _exit_tree() -> void:
	dispose()
