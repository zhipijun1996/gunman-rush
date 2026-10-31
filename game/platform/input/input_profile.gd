class_name InputProfile
extends Resource

var values: Dictionary = {}

static func load_default() -> InputProfile:
	var profile := InputProfile.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config/input_profile.json"))
	if parsed is Dictionary and profile.configure(parsed):
		return profile
	push_error("Invalid input profile")
	return null

func configure(candidate: Dictionary) -> bool:
	var merged := values.duplicate(true)
	merged.merge(candidate, true)
	for key: String in ["left_deadzone", "right_enter_deadzone", "right_exit_deadzone", "arm_confirm_ticks", "center_confirm_ticks", "left_sensitivity", "right_sensitivity", "response_curve", "touch_radius", "touch_jump_radius", "touch_jump_hit_padding", "touch_jump_left_inset", "touch_move_mode", "touch_walk_ratio", "touch_move_stop_deadzone", "touch_run_enter", "touch_run_exit", "touch_deadzone", "keyboard", "mouse_shoot_button", "gamepad_jump_button"]:
		if not merged.has(key):
			return false
	for key: String in ["left_deadzone", "right_enter_deadzone", "right_exit_deadzone", "touch_deadzone"]:
		if not (merged[key] is float or merged[key] is int) or not is_finite(float(merged[key])) or float(merged[key]) < 0.0 or float(merged[key]) >= 1.0:
			return false
	if float(merged.right_exit_deadzone) >= float(merged.right_enter_deadzone):
		return false
	for key: String in ["arm_confirm_ticks", "center_confirm_ticks"]:
		if not (merged[key] is float or merged[key] is int) or not is_finite(float(merged[key])) or float(merged[key]) < 1 or float(merged[key]) != floorf(float(merged[key])):
			return false
	for key: String in ["left_sensitivity", "right_sensitivity", "response_curve", "touch_radius", "touch_jump_radius"]:
		if not (merged[key] is float or merged[key] is int) or not is_finite(float(merged[key])) or float(merged[key]) <= 0:
			return false
	for key: String in ["touch_jump_hit_padding", "touch_jump_left_inset", "touch_walk_ratio", "touch_move_stop_deadzone", "touch_run_enter", "touch_run_exit"]:
		if not (merged[key] is float or merged[key] is int) or not is_finite(float(merged[key])) or float(merged[key]) < 0:
			return false
	if merged.touch_move_mode not in ["two_step", "digital", "analog"]:
		return false
	if float(merged.touch_walk_ratio) <= 0 or float(merged.touch_walk_ratio) >= 1:
		return false
	if not (float(merged.touch_move_stop_deadzone) < float(merged.left_deadzone) and float(merged.left_deadzone) < float(merged.touch_run_exit) and float(merged.touch_run_exit) < float(merged.touch_run_enter) and float(merged.touch_run_enter) <= 1):
		return false
	if not merged.keyboard is Dictionary:
		return false
	var used: Dictionary = {}
	for action: String in ["left", "right", "up", "down", "jump", "shoot"]:
		if not merged.keyboard.get(action) is Array:
			return false
		for code: Variant in merged.keyboard[action]:
			if not (code is float or code is int) or not is_finite(float(code)) or float(code) != floorf(float(code)) or int(code) <= 0 or used.has(int(code)):
				return false
			used[int(code)] = true
	if not (merged.mouse_shoot_button is float or merged.mouse_shoot_button is int) or not is_finite(float(merged.mouse_shoot_button)) or float(merged.mouse_shoot_button) != floorf(float(merged.mouse_shoot_button)) or int(merged.mouse_shoot_button) < 1 or int(merged.mouse_shoot_button) > 9:
		return false
	if not (merged.gamepad_jump_button is float or merged.gamepad_jump_button is int) or not is_finite(float(merged.gamepad_jump_button)) or float(merged.gamepad_jump_button) != floorf(float(merged.gamepad_jump_button)) or int(merged.gamepad_jump_button) < 0 or int(merged.gamepad_jump_button) > 20:
		return false
	for action: String in merged.keyboard:
		var codes: Array[int] = []
		for code: Variant in merged.keyboard[action]:
			codes.append(int(code))
		merged.keyboard[action] = codes
	values = merged
	return true

func axis(raw: Vector2, sensitivity_key: String) -> Vector2:
	if not raw.is_finite():
		return Vector2.ZERO
	var magnitude := minf(raw.length(), 1.0)
	return raw.normalized() * clampf(pow(magnitude, float(values.response_curve)) * float(values[sensitivity_key]), 0.0, 1.0)
