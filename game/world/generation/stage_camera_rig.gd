class_name StageCameraRig
extends Camera2D
## Presentation-only, translated gravity-aware view. Never moves the actor.
@export var viewing_zoom := 1.95
# Formal region opts into a wider view; legacy/Lab consumers keep their zoom.
var region_composition := false
# Forest traversal shares a continuous dead zone on ground and in the air.
# Authored observation hints never switch the whole view at takeoff/landing.
var stable_vertical_follow := false
var region_focus := Vector2.INF
# Optional authored observation pair; INF retains every existing view policy.
var observation_focus := Vector2.INF
var target: PlayerMotor
var world_bounds := Rect2()
# World units; independent from player tuning and collision geometry.
@export var dead_zone := Vector2(42.0, 72.0)
@export var lookahead_distance := 48.0
@export var lookahead_speed := 75.0
@export var response_time := Vector2(0.28, 0.36)
var _lookahead := 0.0
var _anchor := Vector2.ZERO
var _spring_velocity := Vector2.ZERO
var _session := -1
@export var vertical_lower_zone := 72.0
@export var descent_hysteresis := 20.0
var _descending := false
var _inspection := 0.0
var _composition_offset := 80.0
var terrain_bounds := Rect2()
var follow_trace: Dictionary = {}
var route_focus := Vector2.INF
var _shake_age := 0.0
var _shake_amplitude := 0.0
var _shake_clock := 0.0
var _support: Node2D
var _support_transform := Transform2D.IDENTITY
var _support_point := Vector2.ZERO
var _support_delta := Vector2.ZERO

func use_stable_forest_view() -> void:
	stable_vertical_follow = true
	viewing_zoom = 1.20
	dead_zone.y = 90.0
	vertical_lower_zone = 90.0
	response_time = Vector2(0.18,0.24)

func add_impulse(amplitude:float,duration:float)->void:
	_shake_amplitude=maxf(_shake_amplitude,clampf(amplitude,0,7))
	_shake_age=maxf(_shake_age,clampf(duration,0,.8))

func configure(actor: PlayerMotor, bounds: Rect2) -> void:
	zoom = Vector2.ONE * (1.60 if region_composition and not stable_vertical_follow else viewing_zoom)
	target = actor
	terrain_bounds = bounds
	world_bounds = bounds.grow_individual(0, 180, 0, 180)
	if is_instance_valid(target):
		snap_to_target()
		reset_smoothing()
		make_current()
		force_update_scroll()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 1200
	position_smoothing_enabled = false
	enabled = true

func bounded_center(point: Vector2) -> Vector2:
	var half_view := get_viewport_rect().size / (2.0 * zoom)
	var low := world_bounds.position + half_view
	var high := world_bounds.end - half_view
	return Vector2(world_bounds.get_center().x if low.x > high.x else clampf(point.x, low.x, high.x), world_bounds.get_center().y if low.y > high.y else clampf(point.y, low.y, high.y))

func snap_to_target() -> void:
	_support = null
	_support_delta = Vector2.ZERO
	_lookahead = 0.0
	_descending = false
	_spring_velocity = Vector2.ZERO
	_inspection = 0.0
	_composition_offset = 80.0
	_anchor = bounded_center(target.global_position + Vector2(0, -80))
	global_position = _anchor
	var controller := target.get_node_or_null("Controller") as PlayerController
	_session = controller.session_id if controller else -1

func _physics_process(delta: float) -> void:
	_shake_clock+=delta
	_shake_age=maxf(0,_shake_age-delta)
	offset=Vector2(sin(_shake_clock*57),cos(_shake_clock*71))*_shake_amplitude*minf(1,_shake_age/.4) if _shake_age>0 else Vector2.ZERO
	if _shake_age<=0:_shake_amplitude=0
	if not is_instance_valid(target) or world_bounds.size.x <= 0.0:
		return
	if not is_current():
		make_current()
	var controller := target.get_node_or_null("Controller") as PlayerController
	if controller and controller.session_id != _session:
		# Respawn/stage transitions are cuts, never a fast pan across the level.
		snap_to_target()
		return
	_follow_support_frame()
	advance_follow(target.global_position, target.normal_velocity.x,
		maxf(1.0, target.tuning.ground_speed), delta)

# Dampen the actor's motion relative to its support, not the common motion of
# the support and rider. Walk/jump/recoil retain the existing spring and limits.
func _follow_support_frame() -> void:
	var support: Node2D
	_support_delta = Vector2.ZERO
	if target.is_on_floor():
		for index: int in target.get_slide_collision_count():
			var hit := target.get_slide_collision(index)
			if hit.get_normal().dot(target.up_direction) > .7:
				support = hit.get_collider() as Node2D
				break
	if is_instance_valid(support):
		if support == _support:
			_support_delta = support.global_transform * _support_point - _support_transform * _support_point
			_anchor += _support_delta
			global_position += _support_delta
		_support_transform = support.global_transform
		_support_point = support.to_local(target.global_position)
	_support = support

func advance_follow(actor_position: Vector2, movement_speed: float, run_speed: float, delta: float) -> void:
	if delta <= 0.0:
		return
	# Recoil and aim direction do not steer lookahead. Slew limits reversals.
	var requested := clampf(movement_speed / run_speed, -1.0, 1.0) * lookahead_distance
	_lookahead = move_toward(_lookahead, requested, lookahead_speed * delta)
	if stable_vertical_follow:
		var controller := target.get_node_or_null("Controller") as PlayerController if is_instance_valid(target) else null
		var look := controller.router.look_axis if controller and target.is_on_floor() else 0.0
		var before_inspection := _inspection
		_inspection = move_toward(_inspection,look*100.0,delta*90.0)
		_anchor.y += _inspection-before_inspection
	if is_instance_valid(target) and target.is_on_floor():
		_composition_offset = move_toward(_composition_offset, 35.0, delta * 90.0)
	var point := actor_position + Vector2(_lookahead, -_composition_offset)
	if stable_vertical_follow: point.y += _inspection
	if region_composition and region_focus.is_finite() and not route_focus.is_finite():
		point.x += clampf((region_focus.x-actor_position.x)*.35,-100,100)
	if route_focus.is_finite():
		# Bounded phase-specific composition, with actor visibility still authoritative.
		point.x += clampf(route_focus.x - actor_position.x, -96,96)
		point.y = clampf((actor_position.y + route_focus.y) * .5 - 10, actor_position.y - 90, actor_position.y + 40)
	_anchor.x = clampf(_anchor.x, point.x - dead_zone.x, point.x + dead_zone.x)
	var grounded_follow := is_instance_valid(target) and target.is_on_floor() and not route_focus.is_finite() and not stable_vertical_follow
	if not grounded_follow:
		# Preserve the highest useful route view through small-platform landings.
		if point.y < _anchor.y - dead_zone.y:
			_anchor.y = point.y + dead_zone.y
			_descending = false
		elif point.y > _anchor.y + vertical_lower_zone:
			_descending = true
		if _descending:
			_anchor.y = maxf(_anchor.y, point.y - vertical_lower_zone + descent_hysteresis)
			if point.y < _anchor.y + vertical_lower_zone - descent_hysteresis: _descending = false
	if route_focus.is_finite():
		# The tall guardian shares the composition with bridge-height players.
		_anchor.y = move_toward(_anchor.y, point.y, 90 * delta)
	if grounded_follow:
		var controller := target.get_node_or_null("Controller") as PlayerController
		var look := controller.router.look_axis if controller else 0.0
		_inspection = move_toward(_inspection, look * 100.0, delta * 90.0)
		_anchor.y = move_toward(_anchor.y, actor_position.y - 35.0 + _inspection, delta * 90.0)
	elif not stable_vertical_follow:
		_inspection = move_toward(_inspection, 0.0, delta * 90.0)
	if region_composition and observation_focus.is_finite() and grounded_follow and not route_focus.is_finite():
		var pair_margin := (get_viewport_rect().size/(2.0*zoom)-Vector2(48,48)).max(Vector2(24,24))
		_anchor = ((actor_position+observation_focus)*.5).clamp(actor_position-pair_margin,actor_position+pair_margin)
	var requested_anchor := _anchor
	_anchor = bounded_center(_anchor)
	# Exact critically damped spring for a constant target during this step.
	# Unlike a frame-dependent lerp, damping is stable across simulation rates.
	for axis: int in 2:
		var omega := 2.0 / maxf(0.01, response_time[axis])
		var offset := global_position[axis] - _anchor[axis]
		var impulse := _spring_velocity[axis] + omega * offset
		var decay := exp(-omega * delta)
		global_position[axis] = _anchor[axis] + (offset + impulse * delta) * decay
		_spring_velocity[axis] = (_spring_velocity[axis] - omega * impulse * delta) * decay
	# Keep a full actor and a margin visible during bursts/long falls. This
	# soft-follow exception is local to the view; it never clamps the Motor.
	var margin := (get_viewport_rect().size / (2.0 * zoom) - Vector2(48, 48)).max(Vector2(24, 24))
	var safe := Vector2(clampf(global_position.x, actor_position.x - margin.x, actor_position.x + margin.x),
		clampf(global_position.y, actor_position.y - margin.y, actor_position.y + margin.y))
	if region_composition and region_focus.is_finite() and not route_focus.is_finite():
		# Preserve a body's landing clearance through the complete well arc,
		# including the falling half after the apex, without moving the actor.
		var half_height := get_viewport_rect().size.y/(2.0*zoom.y)
		var landing_min := region_focus.y+18.0-half_height+40.0
		# Elective extra upward recoil can exceed one-screen bank coverage.
		# The full actor safety envelope remains authoritative in that case.
		safe.y = minf(maxf(safe.y,landing_min),actor_position.y+margin.y)
	safe = bounded_center(safe)
	for axis: int in 2:
		if not is_equal_approx(safe[axis], global_position[axis]):
			_spring_velocity[axis] = 0.0
			# Rebase the anchor at safety corrections to prevent repeated pullback.
			_anchor[axis] = safe[axis]
	follow_trace = {"actor": actor_position, "anchor": _anchor, "session": _session, "bounds_clamp": _anchor - requested_anchor, "safety_correction": safe - global_position, "descending": _descending, "support_delta": _support_delta}
	global_position = safe
