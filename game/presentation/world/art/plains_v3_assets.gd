class_name PlainsV3Assets
extends RefCounted
## Read-only region consumer; original art manifests remain delivery evidence.
static var _tables: Dictionary = {}
static var _textures: Dictionary = {}
static func table(file: String) -> Dictionary:
	if not _tables.has(file):
		_tables[file] = JSON.parse_string(FileAccess.get_file_as_string("res://assets/plains_v3/" + file))
	return _tables[file]
static func entry(file: String, id: String) -> Dictionary:
	for item: Dictionary in table(file).assets:
		if str(item.get("id", item.get("asset_id", ""))) == id:
			return item
	return {}
static func rect(values: Array) -> Rect2:
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
static func texture(file: String, id: String) -> AtlasTexture:
	var key := file + ":" + id
	if _textures.has(key):
		return _textures[key]
	var item := entry(file, id)
	var source := str(item.texture)
	if not source.begins_with("res://"):
		source = "res://" + source
	var region := rect(item.region)
	var body := rect(item.body_bounds)
	if item.get("bounds_format", "") == "xyxy_region_local":
		body.size -= body.position
	var result := AtlasTexture.new()
	result.atlas = load(source) as Texture2D
	result.region = Rect2(region.position + body.position, body.size)
	result.filter_clip = true
	_textures[key] = result
	return result
static func stage_icon(type_id: StringName) -> AtlasTexture:
	var key := "stage:" + str(type_id)
	if _textures.has(key):
		return _textures[key]
	var ui := table("ui/manifest.json")
	if not ui.stage_type_mapping.has(str(type_id)):
		return null
	var item: Dictionary = ui.regions[ui.stage_type_mapping[str(type_id)]]
	var result := AtlasTexture.new()
	result.atlas = load("res://assets/plains_v3/ui/%s.png" % item.atlas) as Texture2D
	result.region = rect(item.region)
	result.filter_clip = true
	_textures[key] = result
	return result
