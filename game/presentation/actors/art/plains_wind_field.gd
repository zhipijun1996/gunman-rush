class_name PlainsWindField
extends Node2D
## A spatial field sampled from the exact pushing rectangle and accepted clock.
var encounter: WindkeeperPressureEncounter
func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var surface:=CanvasItemMaterial.new()
	surface.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material=surface
func _process(_delta: float) -> void:
	if get_tree().paused:return
	visible=is_instance_valid(encounter) and encounter.active and not encounter.health.terminal and encounter.mode==&"gust" and encounter.stage_phase>=2
	if visible:queue_redraw()
func _draw() -> void:
	if not is_instance_valid(encounter):return
	var field:=encounter.wind_field_rect()
	var age:=encounter._state_age
	var envelope:=minf(clampf(age/.10,0,1),clampf(encounter.clock/.12,0,1))
	# Six staggered elevations fill the whole forward volume, leaving open air
	# between streaks. Clock-driven advection is continuous at render cadence.
	for lane: int in 6:
		for section: int in 3:
			var cycle:=fposmod(age*1.65+section/3.0+lane*.173,1)
			var x:=lerpf(field.position.x+65,field.end.x-65,cycle if encounter.locked_direction>0 else 1-cycle)
			var y:=field.position.y+30+lane*(field.size.y-60)/5+sin(age*4+lane)*5
			var opacity:=sin(cycle*PI)*envelope*.64
			var scale_factor:=.58+float(lane%3)*.08
			PlainsBossEffects.paint(self,&"wind",3,fposmod(age*2+lane*.21+section*.13,1),Vector2(x,y),Vector2(encounter.locked_direction*scale_factor,.65),0,Color(1,1,1,opacity))
