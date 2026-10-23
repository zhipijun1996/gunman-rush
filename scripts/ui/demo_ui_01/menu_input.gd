class_name DemoUiInput
extends RefCounted
## UI-only mappings. Player InputProfile and gameplay adapters remain unchanged.
static func ensure_actions() -> void:
	var buttons := {"ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B, "ui_up": JOY_BUTTON_DPAD_UP, "ui_down": JOY_BUTTON_DPAD_DOWN, "ui_left": JOY_BUTTON_DPAD_LEFT, "ui_right": JOY_BUTTON_DPAD_RIGHT}
	for action: String in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = buttons[action]
		if not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)
	for action: String in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		var event := InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_LEFT_Y if action in ["ui_up", "ui_down"] else JOY_AXIS_LEFT_X
		event.axis_value = -1.0 if action in ["ui_up", "ui_left"] else 1.0
		if not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)
