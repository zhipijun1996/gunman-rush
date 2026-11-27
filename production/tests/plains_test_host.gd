class_name FieldTerracePilot
extends WorldGameHost
## In-memory host for input and fault-injection tests of the registered game rooms.
var connection: Node:
	get: return active.room_dressing if active else null
var landed_on_terrace: bool:
	get: return lesson_progress.has("landed")
var retry_hint_shown: bool:
	get: return lesson_progress.has("hint")
var bell_mount: Sprite2D:
	get: return terrace.bell_mount if terrace else null
var chime_time: float:
	get: return terrace.chime_time if terrace else 0.0

func startup_destination() -> Dictionary:
	return {"ok":true,"room":"P01"}
