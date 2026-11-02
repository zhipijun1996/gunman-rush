class_name ActionStudioPauseInput
extends Node
var studio: ActionStudio
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	_consume_menu_close_pointer(event)

func _consume_menu_close_pointer(event: InputEvent) -> bool:
	if not event is InputEventMouseButton: return false
	if event.button_index <= 0: return false
	var mask: int = 1 << (event.button_index-1)
	var popup := studio._weapon_picker.get_popup()
	# Inside-menu events are routed to its embedded Viewport before this
	# root listener. Outside clicks must close it before gameplay sees them.
	if popup.visible:
		if event.pressed:
			popup.hide()
			studio.menu_pointer_block |= mask
		get_viewport().set_input_as_handled()
		return true
	if (studio.menu_pointer_block & mask)==0: return false
	studio._record(&"menu_pointer_consumed",{"pressed":event.pressed,"button":event.button_index})
	if not event.pressed: studio.menu_pointer_block &= ~mask
	get_viewport().set_input_as_handled()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if _consume_menu_close_pointer(event): return
	if event.is_action_pressed("ui_cancel"):
		studio._toggle_pause()
		get_viewport().set_input_as_handled()
