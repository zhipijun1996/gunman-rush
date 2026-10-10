class_name PlainsActorAssets
extends RefCounted
## Read-only atlas cache. Anchors affect paint only, never gameplay geometry.
static var _catalogs: Dictionary = {}
static var _textures: Dictionary = {}

static func catalog(group: String) -> Dictionary:
	if not _catalogs.has(group):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/plains_v3/%s/manifest.json" % group))
		_catalogs[group] = parsed if parsed is Dictionary else {}
	return _catalogs[group]

static func frame(group: String, id: StringName) -> Dictionary:
	for entry: Dictionary in catalog(group).get("frames", []):
		if str(entry.id) == str(id):
			return entry
	return {}

static func texture(group: String, id: StringName) -> Texture2D:
	var entry := frame(group, id)
	if entry.is_empty():
		return null
	return region_texture("res://assets/plains_v3/%s/%s" % [group, catalog(group).texture], entry.region)

static func region_texture(path: String, region: Array) -> Texture2D:
	var key := path + str(region)
	if not _textures.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = load(path) as Texture2D
		atlas.region = Rect2(float(region[0]), float(region[1]), float(region[2]), float(region[3]))
		atlas.filter_clip = true
		_textures[key] = atlas
	return _textures[key]

static func anchored_rect(group: String, id: StringName, anchor: Vector2, uniform_scale: float) -> Rect2:
	var entry := frame(group, id)
	var pivot: Array = entry.anchor_px
	var region: Array = entry.region
	return Rect2(anchor - Vector2(float(pivot[0]), float(pivot[1])) * uniform_scale, Vector2(float(region[2]), float(region[3])) * uniform_scale)
