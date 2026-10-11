class_name PlayerFeedback
extends Node2D
## Bounded cosmetic particles. Signals report completed gameplay; this consumer
## never changes motion, input, timescale, damage, resources or random streams.
@export var effects_enabled := true:
	set(value):
		effects_enabled = value
		if not value:
			_particles.clear()
			queue_redraw()
@export var max_particles := 64:
	set(value):
		max_particles = maxi(0, value)
		while _particles.size() > max_particles:
			_particles.pop_front()
		queue_redraw()
var _particles: Array[Dictionary] = []
var _serial := 0
var _controller: PlayerController
var _session := -1
var _shot_audio: AudioStreamPlayer2D
var _fall_speed := 0.0

func _ready() -> void:
	z_index = 4
	_shot_audio = AudioStreamPlayer2D.new()
	_shot_audio.stream = preload("res://assets/audio/plains_shot.wav")
	_shot_audio.volume_db = -15
	_shot_audio.max_polyphony = 1
	add_child(_shot_audio)
	_controller = get_parent().get_node("Controller") as PlayerController
	_session = _controller.session_id
	_controller.jump_ability.jumped.connect(_jump)
	_controller.landed.connect(_land)
	_controller.shoot_ability.shot_fired.connect(_shot)
	_controller.shoot_ability.projectile_impacted.connect(_impact)
	_controller.actor_resources.health.changed.connect(_health_changed)
	_controller.segment_returned.connect(_segment_returned)
	_controller.died.connect(clear)

func clear() -> void:
	_particles.clear()
	queue_redraw()

func _jump() -> void:
	_emit(global_position + Vector2(0, 17), Vector2.UP, 7, Color("c4b88f"), 0.26, 55.0, &"jump_launch")

func _land() -> void:
	var count := clampi(3 + int(_fall_speed / 100),3,10)
	_emit(global_position + Vector2(0, 17), Vector2.UP, count, Color("c0b185"), 0.24 + count * .009, 25.0 + count * 4, &"landing_dust")
	_fall_speed = 0

func _shot(direction: Vector2, _shot_id: int) -> void:
	_shot_audio.play()
	var visual := get_parent().get_node_or_null("CourierVisual") as CourierVisual
	var muzzle := visual.muzzle_position(direction) if visual else global_position + direction * 16
	_emit(muzzle, direction, 4, Color("ffe3a0"), 0.08, 0.0, &"muzzle_flash")
	_emit(global_position, -direction, 5, Color("e5d7a5"), 0.20, 85.0, &"recoil_streak")

func reward_received(point: Vector2, permanent: bool = false) -> void:
	_emit(point, Vector2.UP, 12, Color("c8b8ff") if permanent else Color("ffe3a0"), 0.40, 85.0, &"coin_sparkle")

func _impact(point: Vector2, direction: Vector2) -> void:
	_emit(point, -direction, 8, Color("eed8a9"), 0.20, 110.0, &"hit_spark")

func _emit(point: Vector2, direction: Vector2, count: int, color: Color, lifetime: float, speed: float, art_key: StringName = &"") -> void:
	if not effects_enabled or not _controller.active:
		return
	for index: int in count:
		if _particles.size() >= maxi(0, max_particles):
			break
		_serial += 1
		# Local visual sequence: no global RNG, no effect on map/reward sampling.
		var angle := float((_serial * 37) % 101 - 50) / 70.0
		var factor := 0.35 + float((_serial * 13) % 61) / 100.0
		_particles.append({"point": point, "velocity": direction.rotated(angle) * speed * factor, "age": 0.0, "life": lifetime, "color": color, "radius": 1.0 + float(_serial % 3) * 0.6, "art_key": art_key if index == 0 else &"", "angle": direction.angle(), "kind": &"leaf" if art_key in [&"jump_launch", &"landing_dust"] and index % 3 == 1 else &"spark" if art_key in [&"muzzle_flash", &"hit_spark", &"recoil_streak"] else &"dust"})
	queue_redraw()

func _process(delta: float) -> void:
	if not _controller.motor.is_on_floor(): _fall_speed = maxf(_fall_speed, _controller.motor.normal_velocity.y)
	if _session != _controller.session_id:
		_session = _controller.session_id
		clear()
	if not _controller.active:
		clear()
		return
	var had_particles := not _particles.is_empty()
	for index: int in range(_particles.size() - 1, -1, -1):
		var particle := _particles[index]
		particle.age += delta
		if particle.age >= particle.life:
			_particles.remove_at(index)
			continue
		particle.point += particle.velocity * delta
		if particle.kind in [&"dust", &"leaf"]: particle.velocity += Vector2(0, 100) * delta
	if had_particles:
		queue_redraw()

func _draw() -> void:
	for particle: Dictionary in _particles:
		var color: Color = particle.color
		color.a = (1.0 - particle.age / particle.life) * 0.7
		if not str(particle.get("art_key", "")).is_empty():
			var key: StringName = particle.art_key
			var rotation_angle: float = float(particle.angle) if key == &"muzzle_flash" else float(particle.angle) + PI if key == &"recoil_streak" else 0.0
			draw_set_transform(to_local(particle.point), rotation_angle)
			var destination := PlainsActorAssets.anchored_rect("effects", key, Vector2.ZERO, 0.14)
			draw_texture_rect(PlainsActorAssets.texture("effects", key), destination, false, Color(1, 1, 1, color.a))
			draw_set_transform(Vector2.ZERO)
		else:
			var point := to_local(particle.point)
			if particle.kind == &"leaf":
				color = Color(0.58, 0.65, 0.29, color.a)
				var axis: Vector2 = Vector2.RIGHT.rotated(particle.age * 7.0 + particle.angle) * particle.radius * 2.0
				draw_line(point - axis, point + axis, color, 1.8)
			elif particle.kind == &"spark":
				var velocity: Vector2 = particle.velocity
				draw_line(point, point - velocity.normalized() * (3.0 + particle.radius), color, 1.4)
			else:
				draw_circle(point, particle.radius, color)

func _health_changed(result: ActorResourceResult) -> void:
	if result.operation != &"damage" or result.status != ActorResourceResult.Status.APPLIED or result.amount_applied >= 0.0:
		return
	# Only committed nonterminal HP loss; replay/invulnerability never emits.
	# RunEnd owns terminal cleanup, so no particle callback survives the actor.
	if not result.snapshot.terminal:
		_emit(global_position, Vector2.UP, 18, Color("ff9c85"), 0.32, 125.0)

func _segment_returned() -> void:
	_session = _controller.session_id
	clear()
	_emit(global_position, Vector2.UP, 14, Color("ff9c85"), 0.30, 95.0)

func _exit_tree() -> void:
	if is_instance_valid(_shot_audio):
		_shot_audio.stop()
		_shot_audio.stream = null
