class_name StageCameraRig
extends Camera2D
## Presentation-only, translated gravity-aware view. Never moves the actor.
@export var viewing_zoom := 1.95
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

func configure(actor: PlayerMotor, bounds: Rect2) -> void:
	zoom = Vector2.ONE * viewing_zoom
	target = actor
	world_bounds = bounds
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
	_lookahead = 0.0
	_spring_velocity = Vector2.ZERO
	_anchor = bounded_center(target.global_position + Vector2(0, -80))
	global_position = _anchor
	var controller := target.get_node_or_null("Controller") as PlayerController
	_session = controller.session_id if controller else -1

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or world_bounds.size.x <= 0.0:
		return
	if not is_current():
		make_current()
	var controller := target.get_node_or_null("Controller") as PlayerController
	if controller and controller.session_id != _session:
		# Respawn/stage transitions are cuts, never a fast pan across the level.
		snap_to_target()
		return
	advance_follow(target.global_position, target.normal_velocity.x,
		maxf(1.0, target.tuning.ground_speed), delta)

func advance_follow(actor_position: Vector2, movement_speed: float, run_speed: float, delta: float) -> void:
	if delta <= 0.0:
		return
	# Recoil and aim direction do not steer lookahead. Slew limits reversals.
	var requested := clampf(movement_speed / run_speed, -1.0, 1.0) * lookahead_distance
	_lookahead = move_toward(_lookahead, requested, lookahead_speed * delta)
	var point := actor_position + Vector2(_lookahead, -80)
	for axis: int in 2:
		_anchor[axis] = clampf(_anchor[axis], point[axis] - dead_zone[axis], point[axis] + dead_zone[axis])
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
	safe = bounded_center(safe)
	for axis: int in 2:
		if not is_equal_approx(safe[axis], global_position[axis]):
			_spring_velocity[axis] = 0.0
	global_position = safe
