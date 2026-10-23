class_name EnemyFeedback01Frames
extends RefCounted
## Authored, species/skin-specific poses. No authority over damage or locomotion.
## The unchanged generated PNGs are sliced using audited, integer pixel regions.
const DEATH_SECONDS := .48
const ROOT := "res://assets/enemy_feedback_01/frames_v8/"
var _textures: Array[Texture2D] = []
var _bounds: Array[Rect2] = []
var key: String
var horizontal_offset := 0.0
static var _visible_rects: Dictionary = {}

static func visible_bounds(texture: Texture2D, destination: Rect2) -> Rect2:
	var cache_key := str(texture.get_rid())
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		cache_key = str(atlas.atlas.get_rid()) + str(atlas.region)
	if not _visible_rects.has(cache_key):
		var pixels := texture.get_image()
		var minimum := pixels.get_size()
		var maximum := Vector2i(-1, -1)
		for y: int in pixels.get_height():
			for x: int in pixels.get_width():
				# Same alpha>16 definition as the authored H4 basis audit.
				if pixels.get_pixel(x, y).a <= 16.0/255.0: continue
				minimum = Vector2i(mini(minimum.x, x), mini(minimum.y, y))
				maximum = Vector2i(maxi(maximum.x, x), maxi(maximum.y, y))
		_visible_rects[cache_key] = Rect2(Vector2(minimum), Vector2(maximum-minimum+Vector2i.ONE))
	var visible: Rect2 = _visible_rects[cache_key]
	return Rect2(destination.position + visible.position/texture.get_size()*destination.size, visible.size/texture.get_size()*destination.size)

func _init(style: StringName, id: StringName, body_size: Vector2) -> void:
	key = String(style) + ("_diver" if id == &"plains_diver" else "_charger")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	var data: Dictionary = manifest.frames[key]
	var atlas: Texture2D = load(ROOT + str(data.texture)) as Texture2D
	var basis := Vector2(float(data.basis_px[0]), float(data.basis_px[1]))
	# One fixed scale vector for the entire clip, matching the original actual
	# body extent (including legacy flyer's existing aspect). Never resize poses
	# independently: a corpse remains anatomically lower instead of shrinking.
	var factor := body_size / basis
	for i: int in 8:
		var region: Array = data.regions[i]
		var anchor: Array = data.anchors[i]
		var frame := AtlasTexture.new()
		frame.atlas = atlas
		frame.region = Rect2(float(region[0]), float(region[1]), float(region[2]), float(region[3]))
		frame.filter_clip = true
		_textures.append(frame)
		_bounds.append(Rect2(-Vector2(float(anchor[0]), float(anchor[1])) * factor, frame.region.size * factor))

func texture(index: int) -> Texture2D:
	return _textures[clampi(index, 0, 7)]

func bounds(index: int) -> Rect2:
	var value := _bounds[clampi(index, 0, 7)]
	value.position.x += horizontal_offset
	return value

func hurt_index(sample: EnemyFeedback01) -> int:
	if sample == null or sample.hurt_remaining <= 0: return -1
	var elapsed := sample.tuning.hurt_seconds - sample.hurt_remaining
	return clampi(int(elapsed / sample.tuning.hurt_seconds * 4), 0, 3)
