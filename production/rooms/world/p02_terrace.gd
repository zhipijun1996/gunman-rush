class_name FieldTerracePilot
extends WorldGameHost
## Isolated, memory-only historical review and its fault-injection regressions.
const CONNECTIONS := "res://tests/fixtures/plains_receivers/"
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

func binding_path() -> String:
	return CONNECTIONS+"bindings.json"

func startup_destination() -> Dictionary:
	return {"ok":true,"room":"P01"}

func has_room(id: String) -> bool:
	return super.has_room(id) or FileAccess.file_exists(CONNECTIONS+id+".json")

func read_destination(id: String) -> Dictionary:
	var document := super.read_destination(id)
	if document.get("error") == "room_not_bound" and FileAccess.file_exists(CONNECTIONS+id+".json"):
		return WorldRoomDocument.read(CONNECTIONS+id+".json")
	return document
