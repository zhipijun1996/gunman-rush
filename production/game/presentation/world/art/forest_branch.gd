extends RefCounted
## Bark top tracks the collidable surface. Knots and dangling roots below it
## show the material and direction without extending the walkable interval.
const LIMB := preload("res://assets/scenery/forest/stem_limb.png")
const VINE := preload("res://assets/scenery/forest/trailing_limb.png")

static func paint(canvas: CanvasItem, surface: Rect2, style: String) -> void:
	var texture := VINE if style == "forest_vine" else LIMB
	var height := float(texture.get_height())*clampf(surface.size.x/192.,.72,1.14)
	var top_offset := height * (.16 if style == "forest_vine" else .25)
	var scale_x := -1. if style == "forest_branch_left" else 1.
	var start := surface.position if scale_x > 0 else Vector2(surface.end.x,surface.position.y)
	canvas.draw_set_transform(start,0.,Vector2(scale_x,1))
	canvas.draw_texture_rect(texture,Rect2(0,-top_offset,surface.size.x,height),false)
	canvas.draw_set_transform(Vector2.ZERO)
