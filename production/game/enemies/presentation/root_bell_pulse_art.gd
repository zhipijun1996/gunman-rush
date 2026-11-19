class_name RootBellPulseArt
extends RefCounted
## Existing authored active roots, shared by scene and formal bodies.
const ATLAS := preload("res://assets/region_production_v3/enemies/root_bell_burst/source/master.png")
static var _manifest: Dictionary = {}

static func configure(canvas: Node2D) -> void:
	var sampled := ShaderMaterial.new()
	sampled.shader = preload("res://shaders/local_pixel_study.gdshader")
	sampled.set_shader_parameter("cell_world_units",1.0)
	canvas.material = sampled
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

static func draw(canvas: Node2D, definition: EnemyDefinition, center: Vector2, id: String, opacity: float) -> void:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/region_production_v3/enemies/root_bell_burst/manifest.json"))
	var frame: Dictionary = _manifest.frames[id]
	var region: Array = frame.region_xywh
	var raw_size: Array = frame.display_size
	var size := definition.pulse_size if id in ["strike","bend"] else Vector2(raw_size[0],raw_size[1])
	canvas.draw_texture_rect_region(ATLAS,Rect2(center-Vector2(size.x*.5,size.y),size),Rect2(region[0],region[1],region[2],region[3]),Color(1,1,1,opacity))
