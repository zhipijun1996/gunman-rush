class_name PlainsRefreshAssets
extends RefCounted
## Runtime atlas regions, source PNGs remain unedited original generated assets.
const OBJECTS: Texture2D = preload("res://assets/plains_refresh/objects.png")
const LANDSCAPE: Texture2D = preload("res://assets/plains_refresh/landscape.png")
const DOOR: Texture2D = preload("res://assets/plains_v3/windchime_door.png")
const HEART: Texture2D = preload("res://assets/plains_v3/objects_rewards.png")
const REGIONS := {
	&"coin": Rect2(15, 140, 455, 475),
	&"note": Rect2(482, 140, 304, 468),
	&"door": Rect2(789, 32, 462, 603),
	&"bramble": Rect2(4, 777, 535, 366),
	&"enemy_left": Rect2(546, 766, 310, 373),
	&"enemy_right": Rect2(861, 766, 392, 373),
}
static var _object_cache: Dictionary = {}
static func object_texture(kind: StringName) -> AtlasTexture:
	if _object_cache.has(kind):
		return _object_cache[kind]
	if kind in [&"coin", &"note", &"heart"]:
		var id := {&"coin": "run_coin", &"note": "meta_note", &"heart": "healing"}[kind] as String
		var updated := PlainsV3Assets.texture("objects.json", id)
		_object_cache[kind] = updated
		return updated
	var texture := AtlasTexture.new()
	texture.atlas = DOOR if kind == &"door" else OBJECTS
	texture.region = Rect2(30, 56, 975, 1430) if kind == &"door" else REGIONS[kind]
	texture.filter_clip = true
	_object_cache[kind] = texture
	return texture

static func landscape_texture(index: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = LANDSCAPE
	texture.region = [Rect2(0, 0, 2172, 236), Rect2(0, 239, 2172, 247), Rect2(0, 487, 2172, 237)][index]
	texture.filter_clip = true
	return texture

static func draw_bramble(canvas: CanvasItem, danger: Rect2) -> void:
	var texture := object_texture(&"bramble")
	for piece: Dictionary in bramble_pieces(danger):
		canvas.draw_texture_rect_region(texture, piece.destination, piece.source)

static func bramble_pieces(danger: Rect2) -> Array[Dictionary]:
	# Fixed natural clump proportion; cropped edges instead of squashing two tiles.
	# Overlap the living vine centres so no transparent seam reads as a safe gap.
	var pieces: Array[Dictionary] = []
	if not danger.has_area():
		return pieces
	var source := REGIONS[&"bramble"] as Rect2
	var scale_value := danger.size.y / source.size.y
	var width := source.size.x * scale_value
	var stride := width * 0.64
	var x := danger.position.x - width * 0.18
	while x < danger.end.x:
		var full := Rect2(x, danger.position.y, width, danger.size.y)
		var visible := full.intersection(danger)
		pieces.append({"destination": visible, "source": Rect2((visible.position - full.position) / scale_value, visible.size / scale_value)})
		x += stride
	return pieces
