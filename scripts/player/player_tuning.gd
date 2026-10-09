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
var max_jumps: int
var jump_speeds: Array[float] = []

static func load_default() -> PlayerTuning:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/player_tuning.json"))
	if not data is Dictionary:
		push_error("Invalid player_tuning.json")
		return null
	var tuning := PlayerTuning.new()
	for key: String in ["ground_speed", "ground_acceleration", "ground_deceleration", "air_acceleration", "gravity", "max_normal_fall_speed", "coyote_time", "jump_buffer", "max_jumps"]:
		if not data.has(key):
			push_error("Missing tuning key: " + key)
			return null
		tuning.set(key, data[key])
	for speed: float in data.get("jump_speeds", []):
		tuning.jump_speeds.append(speed)
	if tuning.max_jumps < 0 or (tuning.max_jumps > 0 and tuning.jump_speeds.is_empty()):
		push_error("Invalid jump configuration")
		return null
	return tuning
