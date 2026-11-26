@tool
class_name MechanismRegionArt
extends RefCounted
## Native material and fittings shared by public mechanisms. Coordinates are
## local to the caller, including its current beam/shaft drawing transform.
const COMMON := "res://assets/mechanisms/regional/common.png"
const FRAMES := {
	"mount":Rect2(0,0,24,24),
	"finial":Rect2(24,0,32,32),
	"lamp":Rect2(56,0,28,36),
	"hazard":Rect2(84,0,32,32),
	"panel":Rect2(116,0,32,32)
}
static var _textures := {}

static func region_id(canvas: CanvasItem) -> String:
	var host: Node = canvas
	while host != null and not host is FixedWorldRoom: host = host.get_parent()
	return str(host.region_id) if host is FixedWorldRoom else ""

static func accent(canvas: CanvasItem) -> Color:
	var profile: Dictionary = WorldElementCatalog.catalog().mechanism_regions.get(region_id(canvas),{})
	return Color(profile.get("hardware_light","#e1bd83"))

static func sheet(canvas: CanvasItem) -> Texture2D:
	if canvas.texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE:
		canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var region := region_id(canvas)
	if not _textures.has(region):
		var profile: Dictionary = WorldElementCatalog.catalog().mechanism_regions.get(region,{})
		_textures[region] = load(profile.get("hardware_atlas",COMMON))
	return _textures[region]

static func stamp(canvas: CanvasItem, part: String, center: Vector2, size := Vector2.ZERO, tint := Color.WHITE) -> void:
	var src: Rect2 = FRAMES[part]
	var extent := src.size if size == Vector2.ZERO else size
	if extent.x <= 0 or extent.y <= 0: return
	canvas.draw_texture_rect_region(sheet(canvas),Rect2((center-extent*0.5).round(),extent),src,tint)

static func panel(canvas: CanvasItem, rect: Rect2, tint := Color.WHITE) -> void:
	if not rect.has_area(): return
	var atlas := sheet(canvas)
	var frame: Rect2 = FRAMES.panel
	# Tile the native material across the visible surface. The upper and lower
	# edge bands meet even on a thin beam, without stretching an entire tile.
	var margin := Vector2(minf(4,rect.size.x/2),minf(4,rect.size.y/2))
	RenderingServer.canvas_item_add_nine_patch(canvas.get_canvas_item(),rect,frame,atlas.get_rid(),margin,margin,RenderingServer.NINE_PATCH_TILE,RenderingServer.NINE_PATCH_TILE,true,tint)
