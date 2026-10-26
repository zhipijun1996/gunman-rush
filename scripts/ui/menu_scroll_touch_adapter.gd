extends Node
## Local GUI compatibility for Godot 4.7.2 ScrollContainer, which consumes mouse
## drag events but not ScreenDrag. Own vertical ScreenDrag gestures locally;
## native Button/Range input and global emulation stay unchanged.
signal forwarded(phase: StringName)

var scroll: ScrollContainer
var _finger := -1
var _suppressed: Dictionary = {}
var _position := Vector2.ZERO
var _scrolling := false
var _range_gesture := false
var _drag_total := Vector2.ZERO
var _scroll_start := 0.0
const VERTICAL_DRAG_THRESHOLD := 12.0
var _window: Window
var _web_canvas: Variant
var _web_cancel_callback: Variant

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_window = get_tree().root
	if OS.has_feature("web"):
		var bridge := Engine.get_singleton("JavaScriptBridge")
		_web_canvas = bridge.call("get_interface","document").getElementById("canvas")
		_web_cancel_callback = bridge.call("create_callback",_web_touch_cancel)
		# The Web backend loses canceled on its subsequent ScreenTouch release.
		# Cancel before that ordinary release can activate a native Button.
		_web_canvas.addEventListener("touchcancel",_web_cancel_callback,true)

func _web_touch_cancel(_arguments: Array) -> void:
	cancel(&"dom_touchcancel")

func _available() -> bool:
	return is_instance_valid(scroll) and scroll.is_inside_tree() and scroll.is_visible_in_tree()

func _contains(point: Vector2) -> bool:
	return _available() and Rect2(Vector2.ZERO,scroll.size).has_point(scroll.get_global_transform_with_canvas().affine_inverse()*point)

func _consume() -> void:
	if is_instance_valid(_window): _window.set_input_as_handled()

func _motion(point: Vector2, relative: Vector2, held: bool) -> void:
	var mouse := InputEventMouseMotion.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.position = point
	mouse.global_position = point
	mouse.relative = relative
	mouse.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	_window.push_input(mouse,true)

func _button(pressed: bool, canceled := false) -> void:
	var mouse := InputEventMouseButton.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	mouse.position = _position
	mouse.global_position = _position
	mouse.pressed = pressed
	# Native is_released() is false for canceled events. BaseButton clears its
	# pending press without calling pressed; no offscreen-coordinate workaround.
	mouse.canceled = canceled
	_window.push_input(mouse,true)

func _is_range_gesture() -> bool:
	var target := _window.gui_get_hovered_control()
	while is_instance_valid(target) and target != scroll:
		if target is Range: return true
		target = target.get_parent_control()
	return false

func _reset_gesture() -> void:
	_scrolling = false
	_range_gesture = false
	_drag_total = Vector2.ZERO
	_scroll_start = 0.0

func cancel(reason: StringName = &"cancel") -> void:
	var owned := _finger != -1
	var pending_button := owned and not _scrolling
	_finger = -1
	_suppressed.clear()
	_reset_gesture()
	if owned and is_instance_valid(_window):
		if pending_button: _button(false,true)
		forwarded.emit(reason)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if _suppressed.has(event.index):
			_consume()
			if not event.pressed or event.canceled: _suppressed.erase(event.index)
			return
		if event.index == _finger:
			_consume()
			_position = event.position
			if not event.pressed or event.canceled:
				# Release ownership before a Button callback can replace this menu.
				var pending_button := not _scrolling
				_finger = -1
				_reset_gesture()
				if pending_button: _button(false,event.canceled)
				forwarded.emit(&"cancel" if event.canceled else &"release")
			_consume()
			return
		if not event.pressed or event.canceled or not _contains(event.position): return
		_consume()
		if _finger != -1 or not _suppressed.is_empty():
			_suppressed[event.index] = true
			return
		_finger = event.index
		_position = event.position
		_reset_gesture()
		_scroll_start = scroll.scroll_vertical
		# Establish actual GUI hover before MouseButton, required by BaseButton.
		_motion(_position,Vector2.ZERO,false)
		_range_gesture = _is_range_gesture()
		_button(true)
		forwarded.emit(&"press")
		_consume()
	elif event is InputEventScreenDrag:
		if _suppressed.has(event.index):
			_consume()
		elif event.index == _finger:
			_consume()
			if not _available():
				cancel(&"hidden")
				return
			_position = event.position
			var inverse := scroll.get_global_transform_with_canvas().affine_inverse()
			_drag_total += inverse.basis_xform(event.relative)
			if not _scrolling and not _range_gesture and scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and absf(_drag_total.y) > VERTICAL_DRAG_THRESHOLD:
				# Cancel the native pending Button before taking ownership of the
				# gesture. No release click is generated after an actual drag.
				_button(false,true)
				_scrolling = true
				forwarded.emit(&"scroll_begin")
			if _scrolling:
				scroll.scroll_vertical = roundi(_scroll_start - _drag_total.y)
			else:
				_motion(_position,event.relative,true)
			forwarded.emit(&"drag")
			_consume()

func _process(_delta: float) -> void:
	if (_finger != -1 or not _suppressed.is_empty()) and not _available(): cancel(&"hidden")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: cancel(&"focus_out")

func _exit_tree() -> void:
	cancel(&"exit")
	if _web_canvas != null and _web_cancel_callback != null:
		_web_canvas.removeEventListener("touchcancel",_web_cancel_callback,true)
