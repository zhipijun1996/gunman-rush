class_name PixelPlainsPlatform
extends Blob47Platform
func _draw() -> void:
	draw_rect(bounds,Color("365a59") if one_way else Color("a66d45"))
	draw_rect(Rect2(0,0,bounds.size.x,2),Color("ead39a"))
	draw_rect(Rect2(0,bounds.size.y-4,bounds.size.x,4),Color("111e2b"))
	for x: int in range(8,int(bounds.size.x),16):
		draw_rect(Rect2(x,2,2,bounds.size.y-4),Color("6e9180") if one_way else Color("b47c64"))
	if not one_way:
		for x: float in [6,bounds.size.x-10]: draw_rect(Rect2(x,6,4,4),Color("ead39a"))
