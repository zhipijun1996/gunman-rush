extends Node
## Keep the original pre-physics admission ordering with a scene-owned signal.
## Deleting the scene removes this receiver before another frame can resume it.
signal synchronized

func _ready() -> void:
	get_tree().physics_frame.connect(_synchronize,CONNECT_ONE_SHOT)

func _synchronize() -> void:
	synchronized.emit()
