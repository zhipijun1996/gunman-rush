class_name FixedWorldProvider
extends RefCounted
## Room-local lookup; the room session supplies its own contract.
var data: Dictionary = {}

func room(id: String) -> Dictionary:
	return data.get("rooms", {}).get(id, {})

func action(id: String) -> Dictionary:
	for row: Dictionary in data.get("actions", []):
		if row.id == id: return row
	return {}

static func point(value: Array) -> Vector2:
	return Vector2(float(value[0]),float(value[1]))

static func rect(value: Array) -> Rect2:
	return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))
