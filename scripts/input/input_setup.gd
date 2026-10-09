class_name InputSetup
extends RefCounted

static func attach(motor: Node2D, router: InputRouter) -> TouchOverlay:
	var keyboard := motor.get_node_or_null("KeyboardMouseAdapter") as KeyboardMouseAdapter
	if keyboard == null:
		keyboard = KeyboardMouseAdapter.new()
		keyboard.name = "KeyboardMouseAdapter"
		keyboard.router = router
		keyboard.aim_origin = motor
		motor.add_child(keyboard)
	else:
		keyboard.aim_origin = motor
	var gamepad := GamepadAdapter.new()
	gamepad.name = "GamepadAdapter"
	gamepad.router = router
	gamepad.aim_origin = motor
	motor.add_child(gamepad)
	var layer := CanvasLayer.new()
	layer.name = "InputLayer"
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	motor.add_child(layer)
	var overlay := TouchOverlay.new()
	overlay.name = "TouchOverlay"
	overlay.router = router
	overlay.aim_origin = motor
	layer.add_child(overlay)
	return overlay
