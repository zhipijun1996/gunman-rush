@tool
class_name LightInstrumentArt
extends RefCounted

const ATLAS := preload("res://assets/world_elements/guide_light/forest_instruments.png")
const CELL := 64
enum Frame { MOTH, BUD, BLOOM, COCOON, FIXED_LAMP }
const TALL_BANK := Rect2(0,64,96,96)
const CUT_BANK := Rect2(96,64,96,32)
const MAT := Rect2(96,98,64,16)
const CHARM := Rect2(205,66,40,52)

static func texture(node: Node, definition: String) -> Texture2D:
	return load(WorldElementCatalog.skin_value(node,definition,"instrument_atlas",ATLAS.resource_path))

static func bank_texture(node: Node, definition: String, slot: String, fallback: Texture2D, region: Rect2) -> Texture2D:
	var override_path := WorldElementCatalog.skin_value(node,definition,slot,"")
	if not override_path.is_empty(): return load(override_path)
	var sheet := WorldElementCatalog.skin_value(node,definition,"bank_atlas","")
	if sheet.is_empty(): return fallback
	var texture_art := AtlasTexture.new()
	texture_art.atlas = load(sheet)
	texture_art.region = region
	texture_art.filter_clip = true
	return texture_art

static func draw(node: Node2D, atlas: Texture2D, frame: Frame, center: Vector2, tint := Color.WHITE, scale_factor := 1.0) -> void:
	var size := Vector2.ONE * CELL * scale_factor
	var target := Rect2((center-size/2).round(),size)
	node.draw_texture_rect_region(atlas if atlas != null else ATLAS,target,Rect2(frame*CELL,0,CELL,CELL),tint)

static func glow(node: Node2D, center: Vector2, strength: float, radius: float) -> void:
	for band in range(4,0,-1):
		node.draw_circle(center,radius*band/4.0,Color(1.0,0.77,0.36,strength*(0.055 if band > 1 else 0.15)))

## Keep crowns and roots on the authored boundaries; only the stem band repeats.
static func draw_bank(node: Node2D, texture_art: Texture2D, rect: Rect2) -> void:
	var visible := (node.get_global_transform_with_canvas().affine_inverse()*node.get_viewport_rect()).intersection(rect)
	if not visible.has_area(): return
	var size := texture_art.get_size()
	var cap := minf(floorf(size.y*0.48),floorf(rect.size.y*0.55))
	var root := minf(floorf(size.y*0.36),rect.size.y-cap)
	var stem := maxf(1,size.y-cap-root)
	var x := rect.position.x+floorf((visible.position.x-rect.position.x)/size.x)*size.x
	while x < visible.end.x:
		var width := minf(size.x,rect.end.x-x)
		if cap > 0:
			node.draw_texture_rect_region(texture_art,Rect2(x,rect.position.y,width,cap),Rect2(0,0,width,cap))
		var stem_end := rect.end.y-root
		var y := rect.position.y+cap
		y += maxf(0,floorf((visible.position.y-y)/stem))*stem
		while y < minf(visible.end.y,stem_end):
			var span := minf(stem,stem_end-y)
			node.draw_texture_rect_region(texture_art,Rect2(x,y,width,span),Rect2(0,cap,width,span))
			y += span
		if root > 0:
			node.draw_texture_rect_region(texture_art,Rect2(x,stem_end,width,root),Rect2(0,size.y-root,width,root))
		x += size.x
