extends Node2D
## Presentation only: the original Module paints static terrain in one draw.
## Render the opened plate from the actual committed collision-release state.
var release
var plate:=Rect2()
func configure(binding,rect: Array) -> void:
	release=binding;plate=Rect2(rect[0],rect[1],rect[2],rect[3])
func _process(_delta: float) -> void:
	queue_redraw()
func _draw() -> void:
	if release==null or not release.released:return
	draw_rect(plate,Color("101c29"))
	draw_line(plate.position,plate.position+Vector2(plate.size.x,0),Color("50dcbd"),2)
	draw_string(ThemeDB.fallback_font,plate.position+Vector2(8,22),"OPEN",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("50dcbd"))
