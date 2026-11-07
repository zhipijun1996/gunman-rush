class_name WorldText
extends RefCounted
## UI IDs have one catalog; NPC/item/action prose stays with its content definition.
static var catalog: Dictionary={}
static func configure(data: Dictionary) -> void:
	catalog=data.get("strings",{}).duplicate(true)
static func text(id: String,fallback: String="") -> String:
	return str(catalog.get(id,fallback if not fallback.is_empty() else "["+id+"]"))
