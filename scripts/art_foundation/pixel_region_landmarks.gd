class_name PixelRegionLandmarks
extends RefCounted
## Original quiet-pixel silhouettes, not sampled from historical art mothers.
## Canvas feet are opaque at the bottom row; transparent air is non-colliding.
const VERSION := "pixel-region-landmarks-v1"
const SIZES := {
	"windmill_plateau": Vector2i(24, 36),
	"creek_well": Vector2i(24, 20),
	"clock_court": Vector2i(24, 32),
	"repair_gallery": Vector2i(28, 24),
}
static var _textures: Dictionary = {}

static func texture(identity: String) -> Texture2D:
	if _textures.has(identity): return _textures[identity]
	if not SIZES.has(identity): return null
	var size: Vector2i = SIZES[identity]
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var ink := PixelFormalTerrain.INK
	var stone := PixelFormalTerrain.STONE
	var brass := PixelFormalTerrain.BRASS
	var cream := PixelFormalTerrain.CREAM
	var moss := PixelFormalTerrain.MOSS
	if identity == "windmill_plateau":
		# Narrow rooted tower, four stepped sails and a central copper axle.
		image.fill_rect(Rect2i(8, 17, 8, 19), ink)
		image.fill_rect(Rect2i(10, 19, 4, 17), stone)
		image.fill_rect(Rect2i(5, 34, 14, 2), brass)
		for step: int in range(8):
			for direction: Vector2i in [Vector2i(1,1),Vector2i(-1,-1),Vector2i(-1,1),Vector2i(1,-1)]:
				var point := Vector2i(11, 12) + direction * step
				image.fill_rect(Rect2i(point, Vector2i(2, 2)), cream if step > 2 else brass)
		image.fill_rect(Rect2i(10, 11, 4, 4), brass)
		image.fill_rect(Rect2i(11, 12, 2, 2), ink)
	elif identity == "creek_well":
		# Low stone basin, dark open water, two posts and a hanging bucket.
		image.fill_rect(Rect2i(3, 11, 18, 9), ink)
		image.fill_rect(Rect2i(3, 12, 18, 2), cream)
		image.fill_rect(Rect2i(5, 15, 14, 5), stone)
		image.fill_rect(Rect2i(7, 11, 10, 2), Color("345d76"))
		image.fill_rect(Rect2i(4, 2, 2, 10), brass)
		image.fill_rect(Rect2i(18, 2, 2, 10), brass)
		image.fill_rect(Rect2i(3, 1, 18, 2), cream)
		image.fill_rect(Rect2i(11, 3, 1, 6), moss)
		image.fill_rect(Rect2i(10, 8, 4, 3), brass)
	elif identity == "clock_court":
		# A broad stone plinth, paired uprights, open arch and clock hands.
		image.fill_rect(Rect2i(2, 29, 20, 3), stone)
		image.fill_rect(Rect2i(4, 11, 4, 18), stone)
		image.fill_rect(Rect2i(16, 11, 4, 18), stone)
		image.fill_rect(Rect2i(5, 7, 14, 5), ink)
		image.fill_rect(Rect2i(7, 3, 10, 12), brass)
		image.fill_rect(Rect2i(9, 5, 6, 8), cream)
		image.fill_rect(Rect2i(11, 6, 1, 5), ink)
		image.fill_rect(Rect2i(11, 9, 4, 1), ink)
		image.fill_rect(Rect2i(2, 29, 20, 1), cream)
	elif identity == "repair_gallery":
		# Open workbench and tool rack; no fake standing roof or wall.
		image.fill_rect(Rect2i(2, 1, 2, 23), brass)
		image.fill_rect(Rect2i(24, 1, 2, 23), brass)
		image.fill_rect(Rect2i(2, 1, 24, 2), stone)
		image.fill_rect(Rect2i(3, 15, 22, 3), cream)
		image.fill_rect(Rect2i(6, 18, 3, 6), brass)
		image.fill_rect(Rect2i(19, 18, 3, 6), brass)
		image.fill_rect(Rect2i(8, 5, 2, 7), cream)
		image.fill_rect(Rect2i(6, 5, 6, 2), cream)
		image.fill_rect(Rect2i(17, 5, 2, 8), brass)
		image.fill_rect(Rect2i(15, 4, 6, 3), stone)
		image.fill_rect(Rect2i(10, 13, 7, 2), moss)
	var result := ImageTexture.create_from_image(image)
	_textures[identity] = result
	return result
