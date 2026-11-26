class_name ProjectileField
extends Node2D
## Each room owns its field list. Simultaneously loaded rooms cannot intercept each other's attacks.
@export var projectile_categories: Array[String] = ["ordinary"]
var domain: Node

static func domain_for(node: Node) -> Node:
	var room: Node
	var parent := node
	while parent != null:
		if parent is OrdinaryRoomSession: return parent
		if parent is FixedWorldRoom: room = parent
		parent = parent.get_parent()
	return room

static func fields_for(owner_node: Node) -> Array:
	var host := domain_for(owner_node)
	return host.get_meta(&"flight_fields", []) if host != null else []

func _enter_tree() -> void:
	domain = domain_for(self)
	if domain == null: return
	var fields: Array = domain.get_meta(&"flight_fields", [])
	fields.append(self)
	domain.set_meta(&"flight_fields", fields)

func _exit_tree() -> void:
	if is_instance_valid(domain):
		var fields: Array = domain.get_meta(&"flight_fields", [])
		fields.erase(self)
		domain.set_meta(&"flight_fields", fields)

static func valid_list(items: Variant, allowed: Array) -> bool:
	if not items is Array or items.is_empty(): return false
	var seen := {}
	for value: Variant in items:
		if value not in allowed or seen.has(value): return false
		seen[value] = true
	return true

static func validate_configuration(p: Dictionary, _row: Dictionary, _doc: Dictionary) -> String:
	if not valid_list(p.projectile_categories, ["ordinary"]): return "projectile_categories:invalid"
	if p.has("factions") and not valid_list(p.factions, ["player","enemy"]): return "factions:invalid"
	return ""
