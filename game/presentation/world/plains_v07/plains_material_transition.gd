class_name PlainsMaterialTransition
extends Node2D
## Authored material join on a continuous solid. The 47-neighbour geometry stays unchanged.
const TILES:Texture2D=preload("res://assets/plains_v07/native/grass_masonry_transitions.png")
var height:=32.0
var stone_on_right:=false
func _ready()->void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	z_index=2
	var lit:=ShaderMaterial.new();lit.shader=UnderworldTerrain.CORE_SHADER;material=lit
	queue_redraw()
func _draw()->void:
	var y:=0.0
	while y<height:
		var step:=minf(32,height-y)
		var row:=0 if y==0 else 1
		var variant:=posmod(int(y/32),3)
		var destination:=Rect2(-16,y,32,step)
		if stone_on_right:destination.position.x=16;destination.size.x=-32
		draw_texture_rect_region(TILES,destination,Rect2(variant*32,row*32,32,step))
		y+=step
