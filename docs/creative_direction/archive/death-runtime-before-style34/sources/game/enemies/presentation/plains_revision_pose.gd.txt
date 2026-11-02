class_name PlainsRevisionPose
extends RefCounted
## A draw-local snapshot. Float properties retain GDScript's 64-bit arithmetic.
## Raw fields are distinct: Ground vitality and Flora intentionally clamp at
## different points. Never cache by Dictionary identity across draws.
var clock: float
var stride: float
var travel: float
var raw_load: float
var raw_strike: float
var load: float
var strike: float
var recovery: float
var hurt: float
var raw_turn: float
var turn: float
var air: bool
var vertical: float
var dead: bool
var raw_death: float
var death: float
var drive: float
var appendage_follow: float
var aim: float
var death_clock: float
var landing: float
var live: PlainsRevisionPose
# Draw-local scalar terms, evaluated once with the original 64-bit expressions.
# Keep each offset wave distinct; trigonometric identities change rounding.
var stride_sin: float
var stride_cos: float
var rear_stride_sin: float
var rear_stride_cos: float
var patrol_breath_sin: float
var patrol_body_sin: float
var patrol_head_sin: float
var patrol_gait_head_sin: float
var patrol_gait_lag_sin: float
var charger_breath_sin: float
var charger_body_sin: float
var charger_head_sin: float
var charger_gait_head_sin: float
var hopper_breath_sin: float
var hopper_head_sin: float
var hopper_gait_head_sin: float
var recovery_half_sin: float
var recovery_full_sin: float
var recovery_return_sin: float
var charger_hurt_sin: float
var sentry_breath_sin: float
var sentry_muzzle_sin: float
var sentry_body_sin: float
var sentry_leaf_sin: float
var fan_wing_sin: float
var fan_body_sin: float
var fan_pitch_sin: float
var fan_feet_sin: float
var root_stem_sin: float
var root_hurt_sin: float
var root_upper_sin: float
var root_bell_sin: float
var root_leaf_sin: float
var ground_quiet: float
var flora_quiet: float

# Root geometry is local to this prepared snapshot, never shared across poses.
# Flora fills it lazily and recomputes for a different valid body size. Vector2
# fields preserve the existing single-precision intermediate coordinates.
var root_geometry_ready := false
var root_geometry_size := Vector2.ZERO
var root_base: Vector2
var root_elbow: Vector2
var root_crown: Vector2
var root_destination: Vector2
var root_bent: Vector2
var root_hanger: Vector2
var root_moved_hanger: Vector2
var root_moved_leaf: Vector2
var root_lower_angle: float
var root_upper_angle: float
var root_crown_angle: float
var root_droop: float
var root_swing: float
var root_bell_angle: float
var root_leaf_angle: float

static func prepare(values: Dictionary) -> PlainsRevisionPose:
	var result := PlainsRevisionPose.new()
	result.clock = float(values.get("clock", 0.0))
	result.stride = float(values.get("stride", 0.0))
	result.travel = clampf(float(values.get("travel", 0.0)), 0.0, 1.0)
	result.raw_load = float(values.get("load", 0.0))
	result.raw_strike = float(values.get("strike", 0.0))
	result.load = clampf(result.raw_load, 0.0, 1.0)
	result.strike = clampf(result.raw_strike, 0.0, 1.0)
	result.recovery = clampf(float(values.get("recovery", 0.0)), 0.0, 1.0)
	result.hurt = clampf(float(values.get("hurt", 0.0)), 0.0, 1.0)
	result.raw_turn = float(values.get("turn", 0.0))
	result.turn = clampf(result.raw_turn, -1.0, 1.0)
	result.air = bool(values.get("air", false))
	result.vertical = float(values.get("vertical", 0.0))
	result.dead = bool(values.get("dead", false))
	result.raw_death = float(values.get("death", 0.0))
	result.death = clampf(result.raw_death, 0.0, 1.0)
	result.drive = clampf(float(values.get("drive", 0.0)), -1.0, 1.0)
	result.appendage_follow = clampf(float(values.get("appendage_follow", result.travel)), 0.0, 1.0)
	result.aim = float(values.get("aim", 0.0))
	result.death_clock = float(values.get("death_clock", 0.0))
	result.landing = float(values.get("landing", 0.0))
	result._prepare_motion_terms()
	if result.dead:
		var captured := values.duplicate()
		captured["dead"] = false
		result.live = prepare(captured)
	return result

func _prepare_motion_terms() -> void:
	stride_sin = sin(stride)
	stride_cos = cos(stride)
	rear_stride_sin = sin(stride + PI)
	rear_stride_cos = cos(stride + PI)
	patrol_breath_sin = sin(clock * 3.6)
	patrol_body_sin = sin(stride - .22)
	patrol_head_sin = sin(clock * 2.1 - .65)
	patrol_gait_head_sin = sin(stride - .65)
	patrol_gait_lag_sin = sin(stride - .55)
	charger_breath_sin = sin(clock * 2.8)
	charger_body_sin = sin(stride - .38)
	charger_head_sin = sin(clock * 1.9 - .80)
	charger_gait_head_sin = sin(stride - .75)
	hopper_breath_sin = sin(clock * 3.5)
	hopper_head_sin = sin(clock * 2.4 - .7)
	hopper_gait_head_sin = sin(stride - .7)
	recovery_half_sin = sin(recovery * PI)
	recovery_full_sin = sin(recovery * PI * 2.0)
	recovery_return_sin = sin((1.0 - recovery) * PI * 2.0)
	charger_hurt_sin = sin((1.0 - hurt) * PI * 5.0)
	sentry_breath_sin = sin(clock * 3.1)
	sentry_muzzle_sin = sin(clock * 2.2 - .55)
	sentry_body_sin = sin(clock * 2.2)
	sentry_leaf_sin = sin(clock * 2.2 - .9)
	fan_wing_sin = sin(clock * 12.5)
	fan_body_sin = sin(clock * 12.5 - .52)
	fan_pitch_sin = sin(clock * 12.5 - .72)
	fan_feet_sin = sin(clock * 12.5 - 1.1)
	root_stem_sin = sin(clock * 2.6)
	root_hurt_sin = sin((1.0 - hurt) * PI * 1.5)
	root_upper_sin = sin(clock * 2.6 - .5)
	root_bell_sin = sin(clock * 2.6 - .95)
	root_leaf_sin = sin(clock * 2.6 - 1.2)
	ground_quiet = 1.0-clampf(raw_load+raw_strike,0.0,1.0)*.75
	flora_quiet = 1.0-clampf(load+strike,0.0,1.0)*.8
