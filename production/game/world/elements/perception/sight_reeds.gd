@tool
class_name WorldSightReeds
extends Node2D
@export var element_id := ""
@export var state_scope := "attempt"
@export var section_id := "main"
@export var bounds := Rect2(0,0,160,128):
	set(value):
		bounds = value
		queue_redraw()
@export var initial_active := true
const TALL := preload("res://assets/world_elements/guide_light/reed_bank.png")
const CUT := preload("res://assets/world_elements/guide_light/cut_reeds.png")
var tall_art: Texture2D = TALL
var cut_art: Texture2D = CUT
var active := true
var network: WorldLightNetwork

func element_bind(context: Dictionary) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tall_art = load(WorldElementCatalog.skin_value(self,"zone.sight_occluder","tall_texture",TALL.resource_path))
	cut_art = load(WorldElementCatalog.skin_value(self,"zone.sight_occluder","cut_texture",CUT.resource_path))
	active = initial_active
	network = WorldLightNetwork.of(context.room)
	network.reeds.append(self)
	tree_exiting.connect(func(): network.reeds.erase(self),CONNECT_ONE_SHOT)
	z_index = -1
	queue_redraw()

func element_state() -> Dictionary: return {"active":active}
func element_can_receive(input: String, _value: bool) -> bool: return input == "set_active"
func element_propose(_input: String, value: bool) -> Dictionary: return {"active":value}
func element_restore(data: Dictionary) -> void:
	active = data.active
	queue_redraw()

func _draw() -> void:
	var texture := tall_art if active else cut_art
	var height := bounds.size.y if active else minf(bounds.size.y*0.24,texture.get_height())
	var rect := Rect2(Vector2(bounds.position.x,bounds.end.y-height),Vector2(bounds.size.x,height))
	LightInstrumentArt.draw_bank(self,texture,rect)
