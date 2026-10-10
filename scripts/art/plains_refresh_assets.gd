class_name PlainsRefreshAssets
extends RefCounted
## Runtime atlas regions, source PNGs remain unedited original generated assets.
const OBJECTS: Texture2D = preload("res://assets/plains_refresh/objects.png")
const LANDSCAPE: Texture2D = preload("res://assets/plains_refresh/landscape.png")
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
	var texture := AtlasTexture.new()
	texture.atlas = OBJECTS
	texture.region = REGIONS[kind]
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
	# Each complete vine clump stays entirely inside the authored damage rectangle.
	# Overlap covers seams without implying safe holes in a dangerous strip.
	var count := maxi(1, ceili(danger.size.x / maxf(24.0, danger.size.y * 1.46)))
	var width := danger.size.x / count
	for index: int in count:
		canvas.draw_texture_rect(texture, Rect2(danger.position + Vector2(width * index, 0), Vector2(width, danger.size.y)), false)
