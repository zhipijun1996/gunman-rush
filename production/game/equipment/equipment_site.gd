class_name EquipmentSite
extends Node2D

const SMITH := preload("res://assets/equipment/smith_idle.png")
const SMITH_FRAME_SIZE := Vector2(64,64)
const SMITH_ANCHOR := Vector2(32,60)

@export_enum("reward","smith","secret") var kind := "reward"
@export var source_id := ""
@export var radius := 52.0
@export var requirements: Array = []
var services: WorldServices
var smith_time := 0.0
var smith_frame := 0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(kind == "smith")

func _process(delta: float) -> void:
	smith_time = fmod(smith_time + delta,1.0)
	var frame := floori(smith_time * 6)
	if frame != smith_frame:
		smith_frame = frame
		queue_redraw()

func available(point: Vector2) -> bool:
	return visible and global_position.distance_to(point) <= radius and services.state.holds(requirements)

func refresh(_revision: int = 0) -> void:
	if kind == "reward": visible = not services.ledger().claimed.has(source_id)
	if kind == "secret": visible = not services.state.has(source_id)

func reward_icon() -> Texture2D:
	var id: String = EquipmentCatalog.REWARDS.data.get(source_id,"")
	return EquipmentCatalog.ICONS.get(id)

func _draw() -> void:
	if kind == "secret": return
	var label := "强化师"
	var baseline := -60
	if kind == "smith":
		var region := Rect2(Vector2(smith_frame * SMITH_FRAME_SIZE.x,0),SMITH_FRAME_SIZE)
		draw_texture_rect_region(SMITH,Rect2(-SMITH_ANCHOR,SMITH_FRAME_SIZE),region)
	else:
		var icon := reward_icon()
		if icon == null: return
		draw_texture_rect(icon,Rect2(-16,-32,32,32),false)
		label = EquipmentCatalog.item(EquipmentCatalog.REWARDS.data[source_id]).name
		baseline = -37
	var start := Vector2(-80,baseline)
	draw_string_outline(EquipmentMenu.UI_FONT,start,label,HORIZONTAL_ALIGNMENT_CENTER,160,16,3,Color("201e22"))
	draw_string(EquipmentMenu.UI_FONT,start,label,HORIZONTAL_ALIGNMENT_CENTER,160,16,Color("f5e4bd"))
