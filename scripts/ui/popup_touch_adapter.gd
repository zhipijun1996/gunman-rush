class_name PopupTouchAdapter
extends Node
## Touch belongs to this embedded popup Viewport, never to gameplay sticks.
signal forwarded(phase: StringName)
var popup: PopupMenu
var _web_canvas: Variant
var _web_cancel_callback: Variant

func _ready() -> void:
	if OS.has_feature("web"):
		var bridge := Engine.get_singleton("JavaScriptBridge")
		var document: Variant = bridge.call("get_interface","document")
		_web_canvas = document.getElementById("canvas")
		_web_cancel_callback = bridge.call("create_callback",_web_touch_cancel)
		# Godot 4.7.2 loses the DOM touchcancel flag. Capture it before its
		# ordinary touch-release handler can activate a popup item.
		_web_canvas.addEventListener("touchcancel",_web_cancel_callback,true)

func _web_touch_cancel(_arguments: Array) -> void:
	if popup != null and popup.visible:
		forwarded.emit(&"cancel")
		popup.hide()

func _exit_tree() -> void:
	if _web_canvas != null and _web_cancel_callback != null:
		_web_canvas.removeEventListener("touchcancel",_web_cancel_callback,true)

func _input(event: InputEvent) -> void:
	if popup == null or not popup.visible: return
	if event is InputEventScreenTouch:
		forwarded.emit(&"cancel" if event.canceled else &"press" if event.pressed else &"release")
		if event.canceled:
			popup.hide()
		else:
			var mouse := InputEventMouseButton.new()
			mouse.device = InputEvent.DEVICE_ID_EMULATION
			mouse.button_index = MOUSE_BUTTON_LEFT
			mouse.position = Vector2(popup.position)+event.position
			mouse.global_position = mouse.position
			mouse.pressed = event.pressed
			# Root forwarding reaches Window::_input_from_window, where the
			# native PopupMenu processes items; child push_input alone does not.
			get_tree().root.push_input(mouse,true)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var mouse := InputEventMouseMotion.new()
		mouse.device = InputEvent.DEVICE_ID_EMULATION
		mouse.position = Vector2(popup.position)+event.position
		mouse.global_position = mouse.position
		mouse.relative = event.relative
		mouse.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_tree().root.push_input(mouse,true)
		get_viewport().set_input_as_handled()
