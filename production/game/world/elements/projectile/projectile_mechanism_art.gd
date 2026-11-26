class_name ProjectileMechanismArt
extends RefCounted

const ATLAS := preload("res://assets/mechanisms/projectile_library/projectiles.png")
const VESSEL := Rect2(0,0,32,48)
const NOZZLE := Rect2(36,0,45,21)
const DIAL := Rect2(86,0,29,29)
const MIRROR := Rect2(120,0,18,82)
const ROD := Rect2(142,0,9,54)
const LENS := Rect2(157,0,36,16)
const MIST := Rect2(0,88,120,35)
const VEIL := Rect2(204,0,17,80)
const FLAME := Rect2(0,128,125,28)
const COALS := Rect2(0,161,96,17)

static func paint(canvas: CanvasItem, dest: Rect2, source: Rect2, tint := Color.WHITE) -> void:
	if not dest.has_area(): return
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.draw_texture_rect_region(ATLAS,dest,source,tint)

## Keep tips, clamps and emitter mouths at their native aspect ratio. Only the
## interior span extends to match the collision geometry the room chose.
static func beam(canvas: CanvasItem, dest: Rect2, source: Rect2, cap: float, vertical := false, tint := Color.WHITE) -> void:
	if not dest.has_area(): return
	var axis := 1 if vertical else 0
	var across := 1-axis
	var edge := minf(dest.size[axis]/2,cap*dest.size[across]/source.size[across])
	var source_widths := [cap,source.size[axis]-cap*2,cap]
	var display_widths := [edge,dest.size[axis]-edge*2,edge]
	for i: int in 3:
		var slice := source
		var part := dest
		slice.size[axis] = source_widths[i]
		part.size[axis] = display_widths[i]
		paint(canvas,part,slice,tint)
		source.position[axis] += slice.size[axis]
		dest.position[axis] += part.size[axis]
