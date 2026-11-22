class_name EquipmentSite
extends Node2D

@export_enum("reward","smith","secret") var kind := "reward"
@export var source_id := ""
@export var radius := 52.0
@export var requirements: Array = []
var services: WorldServices

func available(point: Vector2) -> bool:
	return visible and global_position.distance_to(point) <= radius and services.state.holds(requirements)

func refresh(_revision: int = 0) -> void:
	if kind == "reward": visible = not services.ledger().claimed.has(source_id)
	if kind == "secret": visible = not services.state.has(source_id)

func _draw() -> void:
	if kind == "secret": return
	var texture := preload("res://assets/plains_v07/native/equipment.png")
	draw_texture_rect(texture,Rect2(-14,-28,28,28),false)
	draw_string(EquipmentMenu.UI_FONT,Vector2(-60,-31),"强化师" if kind == "smith" else EquipmentCatalog.item(str(EquipmentCatalog.REWARDS.data.get(source_id,""))).get("name",""),HORIZONTAL_ALIGNMENT_CENTER,120,15)
