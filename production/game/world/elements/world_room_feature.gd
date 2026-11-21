class_name WorldRoomFeature
extends Node2D
## Registered configuration host. Services retain ownership of accepted facts.
@export var parameters: Dictionary = {}

func _enter_tree() -> void:
	prepare_room(get_parent() as FixedWorldRoom)

func prepare_room(room: FixedWorldRoom) -> void:
	var definition: Dictionary = WorldElementCatalog.catalog().definitions[str(get_meta("definition_id"))]
	for field: String in definition.get("room_bindings",{}):
		var binding: Dictionary = definition.room_bindings[field]
		var value: Variant = binding.get("constant")
		if binding.has("parameter"): value = parameters.get(str(binding.parameter),definition.get("parameter_defaults",{}).get(str(binding.parameter)))
		if binding.get("position",false): value = [position.x,position.y]
		room.set(field,WorldRoomDocument.decode(room.get(field),value))
