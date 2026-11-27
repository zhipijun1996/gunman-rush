extends RefCounted
## The illustrated upper edge follows the one-way collision. The tapered
## underside and truss stay below the feet, including at intermediate widths.
const LEDGES := {
	"island_shelf":preload("res://assets/scenery/shattered_isles/ledge.png"),
	"star_truss":preload("res://assets/scenery/starbridge_gate/ledge.png"),
	"clock_brace":preload("res://assets/scenery/clockheart/ledge.png")
}

static func paint(canvas: CanvasItem, surface: Rect2, style: String) -> void:
	var tex: Texture2D = LEDGES[style]
	var count := maxi(1,roundi(surface.size.x/tex.get_width()))
	var width := surface.size.x/count
	for i in count:
		var at := surface.position+Vector2(i*width,-1)
		canvas.draw_texture_rect(tex,Rect2(at,Vector2(width,tex.get_height())),false)
