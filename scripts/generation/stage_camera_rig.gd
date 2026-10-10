class_name StageCameraRig
extends Camera2D
## Presentation-only, translated gravity-aware view. Never moves the actor.
var target: PlayerMotor
var world_bounds := Rect2()
var follow_rate := 8.0
var lookahead_distance := 100.0
var _lookahead := 0.0

func configure(actor: PlayerMotor, bounds: Rect2) -> void:
	target = actor
	world_bounds = bounds
	_lookahead = 0.0
	if is_instance_valid(target):
		global_position = bounded_center(target.global_position + Vector2(0, -80))
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

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or world_bounds.size.x <= 0.0:
		return
	var velocity := target.normal_velocity + target.recoil_velocity
	var requested := clampf(velocity.x / maxf(1.0, target.tuning.ground_speed), -1.0, 1.0) * lookahead_distance
	var blend := 1.0 - exp(-follow_rate * delta)
	_lookahead = lerpf(_lookahead, requested, blend)
	var desired := bounded_center(target.global_position + Vector2(_lookahead, -80))
	global_position = bounded_center(global_position.lerp(desired, blend))
