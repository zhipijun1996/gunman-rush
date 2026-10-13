class_name ActionStudioPauseInput
extends Node
var studio: ActionStudio
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		studio._toggle_pause()
		get_viewport().set_input_as_handled()
