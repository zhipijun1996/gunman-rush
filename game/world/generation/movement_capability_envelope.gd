class_name MovementCapabilityEnvelope
extends RefCounted
## Fixed-step, collision-free estimates for content screening only.
## No obstacles, moving-platform phases, chained actions or landing proof.
const VERSION := 1
const DT := 1.0 / 60.0
const MAX_TICKS := 600

static func snapshot(tuning: PlayerTuning) -> Dictionary:
	if tuning == null or Engine.physics_ticks_per_second != 60:
		return {}
	for value: float in [tuning.gravity, tuning.ground_speed, tuning.air_acceleration, tuning.max_normal_fall_speed]:
		if not is_finite(value) or value <= 0.0:
			return {}
	for value: float in [tuning.jump_hold_duration, tuning.jump_min_hold_duration, tuning.shot_burst_duration, tuning.shot_burst_speed, tuning.shot_cooldown]:
		if not is_finite(value) or value < 0.0:
			return {}
	if tuning.jump_min_hold_duration > tuning.jump_hold_duration or not is_finite(tuning.jump_release_speed) or tuning.jump_release_speed > 0.0 or tuning.max_air_shots < 0:
		return {}
	if tuning.max_jumps < 0 or tuning.max_jumps > 0 and tuning.jump_speeds.is_empty():
		return {}
	var held := _jump(tuning, false)
	var tap := _jump(tuning, true)
	if held.is_empty() or tap.is_empty():
		return {}
	return {"version": VERSION, "scope": "collision_free_single_jump_screening_not_reachability", "physics_hz": 60, "held_jump_height": held.height, "tap_jump_height": tap.height, "held_jump_range": held.range, "tap_jump_range": tap.range, "held_air_time": held.air_time, "tap_air_time": tap.air_time, "burst_distance": tuning.shot_burst_speed * tuning.shot_burst_duration if tuning.recoil_mode == "shot_burst" else 0.0, "ground_speed": tuning.ground_speed, "max_jumps": tuning.max_jumps, "max_air_shots": tuning.max_air_shots}

static func _jump(tuning: PlayerTuning, tap: bool) -> Dictionary:
	if tuning.max_jumps == 0:
		return {"height": 0.0, "range": 0.0, "air_time": 0.0}
	var launch := tuning.jump_speeds[0]
	if not is_finite(launch) or launch >= 0.0:
		return {"height": 0.0, "range": 0.0, "air_time": 0.0}
	var vertical := launch
	var horizontal := 0.0
	var y := 0.0
	var x := 0.0
	var height := 0.0
	var held_elapsed := 0.0
	var remaining := tuning.jump_hold_duration if tuning.variable_jump_enabled else 0.0
	for index: int in MAX_TICKS:
		if tuning.variable_jump_enabled and vertical < 0.0:
			if tap and held_elapsed + 1.0e-9 >= tuning.jump_min_hold_duration:
				vertical = maxf(vertical, tuning.jump_release_speed)
				remaining = 0.0
			elif remaining > 0.0:
				var held_delta := minf(DT, remaining)
				vertical = lerpf(vertical, launch, held_delta / DT)
				held_elapsed += held_delta
				remaining = maxf(0.0, remaining - DT)
		horizontal = move_toward(horizontal, tuning.ground_speed, tuning.air_acceleration * DT)
		vertical = minf(vertical + tuning.gravity * DT, tuning.max_normal_fall_speed)
		y += vertical * DT
		x += horizontal * DT
		height = maxf(height, -y)
		if index > 0 and y >= 0.0:
			return {"height": height, "range": x, "air_time": (index + 1) * DT}
	return {}
