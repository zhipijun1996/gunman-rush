@static_unload
class_name ItemArtLibrary
extends RefCounted
## Atlas pixels and animation recipes only. Never retains an actor or drives gameplay.
const CONFIG_PATH := "res://config/item_v5_art.json"
const ASSET_ROOT := "res://assets/items/v5/"
const MAX_TEXTURE_RGBA_BYTES := 64*1024*1024
static var _signature := ""
static var _data: Dictionary = {}
static var _textures: Dictionary = {}
static var _icons: Dictionary = {}
static var _frames: Dictionary = {}
static var _warnings: Dictionary = {}
static var _last_error := ""
static var _texture_rgba_bytes := 0

static func clear_cache() -> void:
	_signature = ""
	_data.clear()
	_textures.clear()
	_icons.clear()
	_frames.clear()
	_warnings.clear()
	_last_error = ""
	_texture_rgba_bytes = 0

static func reload_registry() -> bool:
	_signature = ""
	_load()
	return not _data.is_empty()

static func diagnostics() -> Dictionary:
	_load()
	return {"valid":not _data.is_empty(),"last_error":_last_error,"textures":_textures.size(),"icons":_icons.size(),"clips":_frames.size(),"registered_texture_rgba_upper_bound_bytes":_texture_rgba_bytes,"texture_budget_bytes":MAX_TEXTURE_RGBA_BYTES}

static func has_icon(key: StringName) -> bool:
	_load()
	return _data.get("icons",{}).has(String(key))

static func has_clip(key: StringName) -> bool:
	_load()
	return _data.get("clips",{}).has(String(key))

static func entity_clip(kind: StringName, origin: StringName = &"") -> StringName:
	_load()
	var value: Variant = _data.get("entities",{}).get(String(kind),"")
	return _mapped_clip(value,origin)

static func cue_source(kind: StringName, origin: StringName) -> StringName:
	if not origin.is_empty(): return origin
	_load()
	var variants: Dictionary = _data.get("cues",{}).get(String(kind),{})
	return StringName(variants.get("source",""))

static func _mapped_clip(value: Variant, origin: StringName) -> StringName:
	if value is String: return StringName(value)
	if value is Dictionary: return StringName(value.get(String(origin),value.get("default","")))
	return &""

static func cue_clip(kind: StringName, origin: StringName) -> StringName:
	_load()
	var variants: Dictionary = _data.get("cues",{}).get(String(kind),{})
	return StringName(variants.get(String(origin),variants.get("default","")))

static func icon_texture(key: StringName) -> Texture2D:
	_load()
	var name := String(key)
	if _icons.has(name): return _icons[name] as Texture2D
	var row: Dictionary = _data.get("icons",{}).get(name,{})
	if row.is_empty():
		_diagnose("Missing explicitly requested item icon: "+name)
		return null
	var atlas := _atlas(row.texture,row.region)
	if atlas == null: return null
	_icons[name] = atlas
	return atlas

static func clip_duration(key: StringName) -> float:
	_load()
	var row: Dictionary = _data.get("clips",{}).get(String(key),{})
	return float(row.regions.size())/float(row.fps) if not row.is_empty() else 0.0

static func frame_texture(key: StringName, age: float) -> Texture2D:
	_load()
	var name := String(key)
	var row: Dictionary = _data.get("clips",{}).get(name,{})
	if row.is_empty():
		_diagnose("Missing explicitly requested item clip: "+name)
		return null
	if not is_finite(age) or age < 0: return null
	if not _frames.has(name):
		var clips: Array[Texture2D] = []
		for region: Array in row.regions:
			var atlas := _atlas(row.texture,region)
			if atlas == null: return null
			clips.append(atlas)
		_frames[name] = clips
	var textures: Array = _frames[name]
	var index := int(floor(age*float(row.fps)))
	index = index % textures.size() if bool(row.loop) else mini(index,textures.size()-1)
	return textures[index] as Texture2D

static func draw_clip(canvas: CanvasItem, key: StringName, age: float, position := Vector2.ZERO, angle := 0.0, tint := Color.WHITE, size_multiplier := Vector2.ONE) -> bool:
	var texture := frame_texture(key,age)
	if texture == null or canvas == null or not position.is_finite() or not is_finite(angle) or not size_multiplier.is_finite() or size_multiplier.x <= 0 or size_multiplier.y <= 0: return false
	var row: Dictionary = _data.clips[String(key)]
	var size := Vector2(float(row.world_size[0]),float(row.world_size[1]))*size_multiplier
	var pivot := Vector2(float(row.pivot[0]),float(row.pivot[1]))
	canvas.draw_set_transform(position,angle)
	canvas.draw_texture_rect(texture,Rect2(-size*pivot,size),false,tint)
	canvas.draw_set_transform(Vector2.ZERO)
	return true

# Pure recipe grammar; real image dimensions are additionally checked on loading.
static func validate_payload(value: Variant) -> String:
	if not value is Dictionary: return "Invalid item-art schema"
	var schema: Variant = value.get("schema_version")
	if not (schema is int or schema is float) or float(schema)!=1.0: return "Invalid item-art schema"
	for group: String in ["icons","clips","entities","cues"]:
		if not value.get(group) is Dictionary: return "Missing item-art dictionary: "+group
	for key: Variant in value.icons:
		var row: Variant = value.icons[key]
		if not key is String or key.is_empty() or not row is Dictionary or not _path_ok(row.get("texture")) or not _region_ok(row.get("region")): return "Invalid icon recipe: "+str(key)
	for key: Variant in value.clips:
		var row: Variant = value.clips[key]
		if not key is String or key.is_empty() or not row is Dictionary or not _path_ok(row.get("texture")) or not row.get("regions") is Array or row.regions.is_empty() or row.regions.size()>128: return "Invalid clip recipe: "+str(key)
		if not _positive(row.get("fps"),120) or not row.get("loop") is bool or not _pair(row.get("world_size"),false,640) or not _pair(row.get("pivot"),true,1): return "Invalid clip timing/geometry: "+str(key)
		for region: Variant in row.regions:
			if not _region_ok(region): return "Invalid clip frame: "+str(key)
	for key: Variant in value.entities:
		if not key is String: return "Invalid entity kind"
		var mapping: Variant = value.entities[key]
		if mapping is String:
			if not value.clips.has(mapping): return "Unknown entity clip: "+str(key)
		elif mapping is Dictionary:
			for origin: Variant in mapping:
				if not origin is String or not mapping[origin] is String or not value.clips.has(mapping[origin]): return "Unknown entity clip: "+str(key)
		else: return "Invalid entity mapping: "+str(key)
	for key: Variant in value.cues:
		if not key is String or not value.cues[key] is Dictionary: return "Invalid cue mapping: "+str(key)
		for origin: Variant in value.cues[key]:
			if origin == "source":
				if not value.cues[key][origin] is String or not String(value.cues[key][origin]).is_valid_identifier(): return "Invalid cue source: "+str(key)
				continue
			if not origin is String or not value.cues[key][origin] is String or not value.clips.has(value.cues[key][origin]): return "Unknown cue clip: "+str(key)
	return ""

static func _load() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		_signature = ""
		_data.clear()
		_textures.clear()
		_icons.clear()
		_frames.clear()
		_texture_rgba_bytes = 0
		_diagnose("Missing item-art resource registry")
		return
	var signature := FileAccess.get_sha256(CONFIG_PATH)
	if signature == _signature: return
	_signature = signature
	_data = {}
	_textures.clear()
	_icons.clear()
	_frames.clear()
	_last_error = ""
	_texture_rgba_bytes = 0
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if signature != FileAccess.get_sha256(CONFIG_PATH):
		_signature = ""
		_diagnose("Item-art registry changed during loading; retry on next read")
		return
	var problem := validate_payload(value)
	if not problem.is_empty():
		_diagnose(problem)
		return
	# No partial manifest if an explicitly registered region is missing/outside.
	var source_problem := validate_sources(value)
	if not source_problem.is_empty():
		_diagnose(source_problem)
		return
	_data = value.duplicate(true)

static func validate_sources(value: Dictionary) -> String:
	var grammar := validate_payload(value)
	if not grammar.is_empty(): return grammar
	for group: String in ["icons","clips"]:
		for row: Dictionary in value[group].values():
			var texture := _texture(row.texture)
			if texture == null: return "Missing or invalid registered item-art texture: "+str(row.texture)
			var regions: Array = [row.region] if group=="icons" else row.regions
			for region: Array in regions:
				var rect := Rect2(float(region[0]),float(region[1]),float(region[2]),float(region[3]))
				if not Rect2(Vector2.ZERO,texture.get_size()).encloses(rect): return "Item-art region exceeds actual source: "+str(row.texture)
	return ""

static func _atlas(path: String, region: Array) -> AtlasTexture:
	var texture := _texture(path)
	if texture == null: return null
	var rect := Rect2(float(region[0]),float(region[1]),float(region[2]),float(region[3]))
	if not Rect2(Vector2.ZERO,texture.get_size()).encloses(rect):
		_diagnose("Item-art atlas region outside source image: "+path)
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = rect
	atlas.filter_clip = true
	return atlas

static func _texture(path: String) -> Texture2D:
	if _textures.has(path): return _textures[path] as Texture2D
	if not ResourceLoader.exists(path):
		_diagnose("Missing registered item-art texture: "+path)
		return null
	var value := load(path) as Texture2D
	if value == null:
		_diagnose("Invalid item-art texture: "+path)
		return null
	var bytes := int(value.get_width())*int(value.get_height())*4
	if _texture_rgba_bytes+bytes > MAX_TEXTURE_RGBA_BYTES:
		_diagnose("Registered item-art textures exceed the64MiB RGBA upper-bound budget")
		return null
	_texture_rgba_bytes += bytes
	_textures[path] = value
	return value

static func _path_ok(value: Variant) -> bool:
	return value is String and value.begins_with(ASSET_ROOT) and value.ends_with(".png") and ".." not in value

static func _region_ok(value: Variant) -> bool:
	if not value is Array or value.size()!=4: return false
	for i: int in 4:
		var n: Variant = value[i]
		if not (n is int or n is float) or not is_finite(float(n)) or float(n)!=floor(float(n)) or float(n)<0 or (i>=2 and float(n)<=0): return false
	return true

static func _positive(value: Variant, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>0 and float(value)<=maximum

static func _pair(value: Variant, allow_zero: bool, maximum: float) -> bool:
	if not value is Array or value.size()!=2: return false
	for n: Variant in value:
		if not (n is int or n is float) or not is_finite(float(n)) or float(n)>maximum or float(n)<0 or (not allow_zero and float(n)==0): return false
	return true

static func _diagnose(message: String) -> void:
	_last_error = message
	if not _warnings.has(message):
		_warnings[message] = true
		push_warning(message)
