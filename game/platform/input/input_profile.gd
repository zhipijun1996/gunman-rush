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
	if not merged.has("gamepad_device_bindings"): merged.gamepad_device_bindings = {}
	if not merged.has("gamepad_heal_button"):
		merged.gamepad_heal_button=JSON.parse_string(FileAccess.get_file_as_string("res://config/input_profile.json")).gamepad_heal_button
	# Existing full profiles predate LT's release threshold. Add its current
	# default proportion without resetting their other bindings/preferences.
	if candidate.has("gamepad_trigger_threshold") and not candidate.has("gamepad_jump_trigger_release_threshold"):
		var defaults: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/input_profile.json"))
		merged.gamepad_jump_trigger_release_threshold = float(candidate.gamepad_trigger_threshold) * float(defaults.gamepad_jump_trigger_release_threshold) / float(defaults.gamepad_trigger_threshold)

	for key: String in ["left_deadzone", "right_enter_deadzone", "right_exit_deadzone", "left_sensitivity", "right_sensitivity", "response_curve", "touch_radius", "touch_jump_radius", "touch_jump_hit_padding", "touch_jump_left_inset", "touch_move_mode", "touch_walk_ratio", "touch_move_stop_deadzone", "touch_run_enter", "touch_run_exit", "touch_deadzone", "gamepad_trigger_threshold", "gamepad_jump_trigger_release_threshold", "keyboard", "mouse_shoot_button", "gamepad_jump_button"]:
		if not merged.has(key):
			return false
	for key: String in ["left_deadzone", "right_enter_deadzone", "right_exit_deadzone", "touch_deadzone", "gamepad_trigger_threshold", "gamepad_jump_trigger_release_threshold"]:
		if not (merged[key] is float or merged[key] is int) or not is_finite(float(merged[key])) or float(merged[key]) < 0.0 or float(merged[key]) >= 1.0:
			return false
	if float(merged.gamepad_jump_trigger_release_threshold) >= float(merged.gamepad_trigger_threshold): return false
	if float(merged.gamepad_trigger_threshold) <= 0 or float(merged.right_exit_deadzone) >= float(merged.right_enter_deadzone):
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
	# Repair the shipped arrow-key typo when loading that exact older default pair.
	if merged.keyboard.get("left",[]) == [65,4194321] and merged.keyboard.get("right",[]) == [68,4194323]:
		merged.keyboard.left=[65,4194319];merged.keyboard.right=[68,4194321]
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
	var heal: Variant=merged.gamepad_heal_button
	if not (heal is int or heal is float) or not is_finite(float(heal)) or float(heal)!=floorf(float(heal)) or int(heal)<0 or int(heal)>=JOY_BUTTON_MAX:return false
	if not _valid_gamepads(merged.gamepad_device_bindings): return false
	values = merged
	return true

func axis(raw: Vector2, sensitivity_key: String) -> Vector2:
	if not raw.is_finite():
		return Vector2.ZERO
	var magnitude := minf(raw.length(), 1.0)
	return raw.normalized() * clampf(pow(magnitude, float(values.response_curve)) * float(values[sensitivity_key]), 0.0, 1.0)

static func gamepad_key(device: int) -> String:
	return OS.get_name()+"/"+Input.get_joy_guid(device)+"/"+Input.get_joy_name(device)

func gamepad_binding(device: int, role: String) -> Dictionary:
	var defaults := {
		"jump": {"kind":"button","index":int(values.gamepad_jump_button)},
		"heal": {"kind":"button","index":int(values.gamepad_heal_button)},
		"jump_trigger": {"kind":"axis","index":JOY_AXIS_TRIGGER_LEFT},
		"item_trigger": {"kind":"axis","index":JOY_AXIS_TRIGGER_RIGHT},
		"map": {"kind":"button","index":JOY_BUTTON_BACK}}
	return values.get("gamepad_device_bindings",{}).get(gamepad_key(device),{}).get(role,defaults[role])

static func binding_down(binding: Dictionary, device: int, edge: InputEvent = null) -> float:
	if binding.kind=="button":
		return float(edge.pressed if edge is InputEventJoypadButton and edge.device==device and edge.button_index==int(binding.index) else Input.is_joy_button_pressed(device,int(binding.index)))
	if binding.kind=="axis":
		return edge.axis_value if edge is InputEventJoypadMotion and edge.device==device and edge.axis==int(binding.index) else Input.get_joy_axis(device,int(binding.index))
	return 0.0

static func _valid_gamepads(profiles: Variant) -> bool:
	if not profiles is Dictionary: return false
	for key: Variant in profiles:
		if not key is String or key.is_empty() or key.length()>256 or not profiles[key] is Dictionary: return false
		var seen: Dictionary={}
		for role: String in ["jump","heal","jump_trigger","item_trigger","map"]:
			var b: Variant=profiles[key].get(role)
			if not b is Dictionary or not b.get("kind") is String: return false
			if not (b.get("index") is int or b.get("index") is float) or not is_finite(float(b.index)) or float(b.index)!=floorf(float(b.index)): return false
			if b.kind=="none":
				if role not in ["map","item_trigger"] or int(b.index)!=-1: return false
				continue
			if b.kind=="axis":
				if role not in ["jump_trigger","item_trigger"] or int(b.index)<4 or int(b.index)>=JOY_AXIS_MAX: return false
			elif b.kind=="button":
				if int(b.index)<0 or int(b.index)>=JOY_BUTTON_MAX: return false
				if int(b.index) in [JOY_BUTTON_X,JOY_BUTTON_Y,JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER,JOY_BUTTON_START]: return false
			else: return false
			var physical:=str(b.kind)+"/"+str(int(b.index))
			if seen.has(physical): return false
			seen[physical]=true
	return true
