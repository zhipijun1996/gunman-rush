class_name StyleRegionPalette
extends RefCounted
## Explicit nondestructive region ramps, not a claim of newly painted TileSets.
## Source topology, pixel clusters, alpha and all collision geometry are preserved.
const RAMP_SHADER := preload("res://scripts/style_exploration/region_material.gdshader")
const RAMPS := {
	"cavern/plains": ["353d35", "66725b", "b3b494", "e1d5a9"],
	"cavern/forest": ["101e1a", "334f3c", "759677", "b9c598"],
	"cavern/gear": ["1b252b", "4d5b61", "ab9777", "dbcca9"],
	"underworld/forest": ["05120f", "142b24", "477457", "98b77e"],
	"underworld/gear": ["080f16", "1d2b34", "657e88", "c9b57b"]
}

static func apply(item: CanvasItem, style_id: String, biome_id: String) -> void:
	var key := style_id + "/" + biome_id
	if not RAMPS.has(key):
		item.material = null
		return
	var ramp: Array = RAMPS[key]
	var material := ShaderMaterial.new()
	material.shader = RAMP_SHADER
	for i: int in 4:
		material.set_shader_parameter(["shadow_color", "body_color", "edge_color", "light_color"][i], Color(ramp[i]))
	item.material = material
	item.set_meta("palette_method", "source-luminance region ramp; native alpha and pixel clusters retained")

static func scenery_colors(style_id: String, biome_id: String) -> Array[Color]:
	if biome_id == "forest":
		return [Color("102b2b"), Color("496a57"), Color("30564c"), Color("c9df91")]
	if biome_id == "gear":
		return [Color("17232e"), Color("7a7268"), Color("465663"), Color("efbd6e")]
	if style_id == "cavern":
		return [Color("789da2"), Color("e4cca0"), Color("71816c"), Color("e9d28e")]
	return [Color("18263b"), Color("616d85"), Color("293d49"), Color("a5f29b")]
