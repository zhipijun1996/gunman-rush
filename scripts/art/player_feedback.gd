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

func _ready() -> void:
	z_index = 4
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
	_emit(global_position + Vector2(0, 17), Vector2.UP, 7, Color("c1c8ba"), 0.26, 55.0, &"jump_launch")

func _land() -> void:
	_emit(global_position + Vector2(0, 17), Vector2.UP, 10, Color("afbba9"), 0.33, 65.0, &"landing_dust")

func _shot(direction: Vector2, _shot_id: int) -> void:
	_emit(global_position + direction * 16.0, direction, 9, Color("ffe3a0"), 0.14, 145.0, &"muzzle_flash")
	_emit(global_position, -direction, 5, Color("d8e9e9"), 0.20, 85.0, &"recoil_streak")

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
		_particles.append({"point": point, "velocity": direction.rotated(angle) * speed * factor, "age": 0.0, "life": lifetime, "color": color, "radius": 1.0 + float(_serial % 3) * 0.6, "art_key": art_key if index == 0 else &"", "angle": direction.angle()})
	queue_redraw()

func _process(delta: float) -> void:
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
		particle.velocity += Vector2(0, 100) * delta
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
			draw_circle(to_local(particle.point), particle.radius, color)

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
