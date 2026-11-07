class_name WorldNpc
extends Node2D
## A stable placement and visual only. Services own dialogue conditions and results.
@export var npc_id := ""
@export var visual_kind := "artisan"
@export var display_name := ""
var chapter := ""
var animation: WorldSpriteAnimation
static func visual_for(id: String,story: String="") -> String:
	# Story-specific activities use the same traveler identity and native body scale.
	if id=="NPC_TRAVELER_AQI":return {"AQI_T01":"aqi_clock","AQI_T02":"aqi_tea","AQI_T03":"aqi_lantern","AQI_T01_LOOKOUT":"aqi_lookout"}.get(story,"aqi")
	return {"NPC_P_REC":"reclaimer","NPC_P_WEAVER":"weaver","NPC_TRAVELER_AQI":"aqi"}.get(id,"reclaimer")
func _ready() -> void:
	animation=WorldSpriteAnimation.new()
	animation.asset_id=visual_for(npc_id,chapter)
	animation.position=Vector2(0,18)
	add_child(animation)
func greet() -> void:
	if animation!=null: animation.play_event()
var highlighted:=false:
	set(value):
		if highlighted==value: return
		highlighted=value;queue_redraw()
func _draw() -> void:
	if highlighted:
		draw_line(Vector2(-5,-55),Vector2(0,-61),DemoClockworkTheme.TEAL,2)
		draw_line(Vector2(0,-61),Vector2(5,-55),DemoClockworkTheme.TEAL,2)
