class_name PlainsTimberSurface
extends Node2D
## Native wood strip follows a real one-way top; no collision or invented extra ledges.
var bounds:Rect2
const TEXTURE=preload("res://assets/plains_v07/native/mill_walkway.png")
func _draw()->void:
	draw_surface(self,bounds)

static func draw_surface(canvas: CanvasItem, area: Rect2) -> void:
	var x:=area.position.x
	while x<area.end.x:
		var width:=minf(64,area.end.x-x)
		canvas.draw_texture_rect_region(TEXTURE,Rect2(x,area.position.y,width,16),Rect2(32,0,width,16))
		x+=width
	canvas.draw_texture_rect_region(TEXTURE,Rect2(area.position,Vector2(8,16)),Rect2(0,0,8,16))
	canvas.draw_texture_rect_region(TEXTURE,Rect2(area.end.x-8,area.position.y,8,16),Rect2(TEXTURE.get_width()-8,0,8,16))
