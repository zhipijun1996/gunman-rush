class_name FoundryPauseInput
extends Node
signal toggle_requested

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		toggle_requested.emit()
		get_viewport().set_input_as_handled()
