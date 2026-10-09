class_name PlayerTuning
extends Resource

var ground_speed: float
var ground_acceleration: float
var ground_deceleration: float
var air_acceleration: float
var gravity: float
var max_normal_fall_speed: float
var coyote_time: float
var jump_buffer: float
var variable_jump_enabled: bool
var jump_hold_duration: float
var jump_min_hold_duration: float
var jump_release_speed: float
var recoil_mode: String
var shot_burst_speed: float
var shot_burst_duration: float
var recoil_impulse: float
var recoil_tau: float
var shot_cooldown: float
var max_air_shots: int
var projectile_speed: float
var projectile_radius: float
var projectile_damage: float
var projectile_lifetime: float
var drop_through_duration: float
var drop_through_speed: float
var max_jumps: int
var jump_speeds: Array[float] = []

static func load_default() -> PlayerTuning:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/player_tuning.json"))
	if not data is Dictionary:
		push_error("Invalid player_tuning.json")
		return null
	var tuning := PlayerTuning.new()
	for key: String in ["ground_speed", "ground_acceleration", "ground_deceleration", "air_acceleration", "gravity", "max_normal_fall_speed", "coyote_time", "jump_buffer", "variable_jump_enabled", "jump_hold_duration", "jump_min_hold_duration", "jump_release_speed", "max_jumps", "recoil_mode", "shot_burst_speed", "shot_burst_duration", "recoil_impulse", "recoil_tau", "shot_cooldown", "max_air_shots", "projectile_speed", "projectile_radius", "projectile_damage", "projectile_lifetime", "drop_through_duration", "drop_through_speed"]:
		if not data.has(key):
			push_error("Missing tuning key: " + key)
			return null
		tuning.set(key, data[key])
	for speed: float in data.get("jump_speeds", []):
		tuning.jump_speeds.append(speed)
	if tuning.max_jumps < 0 or (tuning.max_jumps > 0 and tuning.jump_speeds.is_empty()):
		push_error("Invalid jump configuration")
		return null
	if tuning.max_air_shots < 0 or tuning.recoil_tau <= 0.0 or tuning.shot_cooldown < 0.0 or tuning.projectile_speed <= 0.0 or tuning.projectile_radius <= 0.0 or tuning.projectile_damage <= 0.0 or tuning.projectile_lifetime <= 0.0 or tuning.drop_through_duration < 0.0 or tuning.drop_through_speed <= 0.0:
		push_error("Invalid combat configuration")
		return null
	if tuning.recoil_mode not in ["shot_burst", "legacy_impulse"] or tuning.shot_burst_speed <= 0.0 or tuning.shot_burst_duration <= 0.0:
		push_error("Invalid recoil mode/burst configuration")
		return null
	if tuning.jump_hold_duration < 0.0 or tuning.jump_min_hold_duration < 0.0 or tuning.jump_min_hold_duration > tuning.jump_hold_duration or tuning.jump_release_speed > 0.0:
		push_error("Invalid variable jump configuration")
		return null
	return tuning
