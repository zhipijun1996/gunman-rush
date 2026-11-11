class_name PlainsTimberSurface
extends Node2D
## Native wood strip follows a real one-way top; no collision or invented extra ledges.
var bounds:Rect2
const TEXTURE=preload("res://assets/plains_v07/native/mill_walkway.png")
func _draw()->void:
	var x:=bounds.position.x
	while x<bounds.end.x:
		var width:=minf(64,bounds.end.x-x)
		draw_texture_rect_region(TEXTURE,Rect2(x,bounds.position.y,width,16),Rect2(32,0,width,16))
		x+=width
	draw_texture_rect_region(TEXTURE,Rect2(bounds.position,Vector2(8,16)),Rect2(0,0,8,16))
	draw_texture_rect_region(TEXTURE,Rect2(bounds.end.x-8,bounds.position.y,8,16),Rect2(TEXTURE.get_width()-8,0,8,16))
