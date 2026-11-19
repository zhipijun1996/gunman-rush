class_name WorldSurfaceStyles
extends RefCounted
const PATH := "res://config/surface_styles.json"
static var _data: Dictionary = {}
static func catalog() -> Dictionary:
	if _data.is_empty(): _data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data
static func choose(explicit: String, region: String, material_id: String) -> String:
	if not explicit.is_empty(): return explicit
	var rules: Dictionary = catalog().regions.get(region, {})
	return str(rules.get("materials",{}).get(material_id,rules.get("default",catalog().default)))
static func texture(id: String) -> Texture2D:
	return TerrainMaterialRegistry.texture(str(catalog().styles[id].texture))
static func error(id: String, facing: String) -> String:
	var style: Dictionary = catalog().styles.get(id,{})
	return "surface_style_incompatible" if style.is_empty() or facing not in style.faces else ""
