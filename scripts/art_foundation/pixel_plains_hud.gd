class_name PixelPlainsHUD
extends Control
var room: PixelPlainsRoom
const FONT:=preload("res://assets/fonts/foundry_notes.otf")
func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:queue_redraw()
func _draw() -> void:
	if room==null or room.controller==null:return
	var hp:=room.controller.actor_resources.health
	draw_rect(Rect2(8,8,120,27),Color(.06,.11,.15,.8))
	for i: int in ceili(hp.capacity):
		var color:=Color("b47c64") if i<hp.current else Color("365a59")
		draw_rect(Rect2(14+i*12,13,8,6),color)
		draw_rect(Rect2(16+i*12,19,4,2),color)
	var energy:=room.controller.actor_resources.stamina
	draw_rect(Rect2(14,25,102,3),Color("203b46"))
	draw_rect(Rect2(14,25,floorf(102*energy.current/maxf(1,energy.capacity)),3),Color("b0b97b"))
	draw_string(FONT,Vector2(474,22),"WINDCHIME / FIRST LIGHT",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("ead39a"))
	if not room.controller.active:draw_string(FONT,Vector2(254,150),"FALLEN / RESTART",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ead39a"))
