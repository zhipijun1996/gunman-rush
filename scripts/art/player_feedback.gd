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
var _fall_speed := 0.0
var _step_distance := 0.0
var _step_position := Vector2.ZERO
var _hook_was_visible := false
var _guide_was_visible := false
var hook_redraw_ticks := 0

func _ready() -> void:
	z_index = 4
	_controller = get_parent().get_node("Controller") as PlayerController
	_session = _controller.session_id
	_controller.jump_ability.jumped.connect(_jump)
	_controller.traversal.action_changed.connect(func(action: StringName) -> void:
		if action in [&"hook_cast",&"hook_kick",&"wall_kick"]: GameAudio.cue(self,&"jump" if action in [&"wall_kick",&"hook_kick"] else &"focus_start")
		if action == &"hook_pull": GameAudio.cue(self,&"bell")
		if action == &"hook_contact_kick":
			GameAudio.cue(self,&"impact")
			_emit(_controller.traversal.hook_tip,-_controller.traversal.hook_direction,8,Color("ffecc0"),.22,95,&"hit_spark")
		if action == &"hook_kick":
			var launch := Vector2(_controller.traversal.kick_side*_controller.traversal.definition.hook_kick.x,_controller.traversal.definition.hook_kick.y)
			_emit(global_position,-launch.normalized(),10,Color("f5d79b"),.35,130,&"recoil_streak")
		if action == &"hook_miss": GameAudio.cue(self,&"denied")
		queue_redraw()
		if action in [&"hook_kick",&"wall_kick"]:
			_emit(global_position,Vector2.UP,8,Color("f5d79b"),.24,75,&"recoil_streak"))
	_controller.landed.connect(_land)
	_controller.shoot_ability.shot_fired.connect(_shot)
	_controller.shoot_ability.projectile_impacted.connect(_impact)
	_controller.energy_recovered.connect(func(_amount: float,_airborne: bool):
		_emit(global_position+Vector2(0,-12),Vector2.UP,7,Color("9cdfb4"),.35,55,&"hit_spark")
		GameAudio.cue(self,&"confirm"))
	_controller.actor_resources.health.changed.connect(_health_changed)
	_controller.segment_returned.connect(_segment_returned)
	_controller.died.connect(func() -> void:
		GameAudio.cue(self, &"death")
		clear())
	_controller.air_focus_ability.active_changed.connect(func(value: bool) -> void:
		if _controller.active: GameAudio.cue(self, &"focus_start" if value else &"focus_end"))
	_controller.shoot_ability.shot_rejected.connect(func(_reason: StringName) -> void: GameAudio.cue(self, &"denied"))

func clear() -> void:
	_particles.clear()
	queue_redraw()

func _jump() -> void:
	GameAudio.cue(self, &"jump")
	if _controller.jump_ability.used_jumps >= 2: GameAudio.cue(self,&"focus_start")
	_emit(global_position + Vector2(0, 17), Vector2.UP, 7, Color("c4b88f"), 0.26, 55.0, &"jump_launch")

func _land() -> void:
	GameAudio.cue(self, &"land")
	var count := clampi(3 + int(_fall_speed / 100),3,10)
	_emit(global_position + Vector2(0, 17), Vector2.UP, count, Color("c0b185"), 0.24 + count * .009, 25.0 + count * 4, &"landing_dust")
	_fall_speed = 0

func _shot(direction: Vector2, _shot_id: int) -> void:
	GameAudio.cue(self, &"shot")
	var visual := get_parent().get_node_or_null("CourierVisual") as CourierVisual
	var muzzle := _controller.shoot_ability.last_muzzle
	_emit(muzzle, direction, 4, Color("ffe3a0"), 0.08, 0.0, &"muzzle_flash")
	_emit(global_position, -direction, 5, Color("e5d7a5"), 0.20, 85.0, &"recoil_streak")

func reward_received(point: Vector2, permanent: bool = false) -> void:
	_emit(point, Vector2.UP, 12, Color("c8b8ff") if permanent else Color("ffe3a0"), 0.40, 85.0, &"coin_sparkle")

func _impact(point: Vector2, direction: Vector2) -> void:
	GameAudio.cue(self, &"impact")
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
	if _controller.active and _controller.motor.is_on_floor() and absf(_controller.motor.normal_velocity.x) > 20:
		_step_distance += minf(10.0, global_position.distance_to(_step_position))
		if _step_distance >= 55:
			_step_distance = 0.0
			GameAudio.cue(self, &"step")
	else: _step_distance = 0.0
	_step_position = global_position
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
	var hook_visible := _controller.traversal.state in [&"hook_cast",&"hook_fly",&"hook_pull",&"hook_kick",&"hook_contact_kick",&"hook_hang",&"hook_miss",&"hook_retract"]
	if hook_visible: hook_redraw_ticks += 1
	if had_particles or hook_visible or _hook_was_visible or _controller.traversal.guide_active or _guide_was_visible:
		queue_redraw()
	_hook_was_visible = hook_visible
	_guide_was_visible=_controller.traversal.guide_active

## Essential traversal feedback belongs to the active body renderer. Formal
## pixel regions hide the old particle layer, so the current body calls this
## same read-only draw path instead of revealing the entire legacy layer.
static func draw_grapple(canvas: Node2D, controller: PlayerController, hand_world: Vector2) -> void:
	if controller == null or not controller.active: return
	if controller.traversal.guide_active:
		var origin := canvas.to_local(controller.motor.global_position+Vector2(0,-6))
		var finish := canvas.to_local(controller.traversal.guide_point)
		var offset := finish-origin
		var segments := maxi(1,ceili(offset.length()/16))
		var color := Color(.55,.95,.85,.65) if controller.traversal.guide_target_valid else Color(.9,.75,.45,.4)
		for i: int in segments:
			var t := float(i)/segments
			canvas.draw_line(origin+offset*t,origin+offset*minf(1,t+.5/segments),color,1.2,true)
		canvas.draw_arc(finish,8,0,TAU,24,color,1.5,true)
	if controller != null and controller.traversal.state in [&"hook_cast",&"hook_fly",&"hook_pull",&"hook_kick",&"hook_contact_kick",&"hook_hang",&"hook_miss",&"hook_retract"]:
		var traversal := controller.traversal
		var tip := canvas.to_local(traversal.hook_tip)
		var start := canvas.to_local(hand_world)
		if traversal.state == &"hook_cast": tip = start
		var sag := 0.0 if traversal.state in [&"hook_pull",&"hook_contact_kick",&"hook_hang"] else 8.0
		var previous := start
		for i: int in range(1,13):
			var t := float(i)/12
			var point := start.lerp(tip,t)+Vector2(0,sin(t*PI)*sag)
			canvas.draw_line(previous,point,Color("ddc089"),1.6,true)
			previous = point
		var angle := traversal.hook_direction.angle()
		canvas.draw_arc(tip,5,angle-PI*.6,angle+PI*.6,12,Color("ffecc0"),2,true)
		canvas.draw_line(tip-traversal.hook_direction*7,tip,Color("a78855"),2,true)

func _draw() -> void:
	if _controller != null:
		var visual := _controller.motor.get_node("CourierVisual") as CourierVisual
		draw_grapple(self, _controller, visual.grapple_hand_position())
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
	GameAudio.cue(self, &"hurt")
	# Only committed nonterminal HP loss; replay/invulnerability never emits.
	# RunEnd owns terminal cleanup, so no particle callback survives the actor.
	if not result.snapshot.terminal:
		_emit(global_position, Vector2.UP, 18, Color("ff9c85"), 0.32, 125.0)

func _segment_returned() -> void:
	_session = _controller.session_id
	clear()
	_emit(global_position, Vector2.UP, 14, Color("ff9c85"), 0.30, 95.0)
