class_name PlainsWoodPlatformArt
extends RefCounted
## A single body-local draw per one-way surface; geometry is owned by the module.
const MATERIAL := preload("res://shaders/plains_wood_platform.gdshader")

static func build(rect: Rect2) -> ColorRect:
	var scale_value := minf(PlainsCohesionArt.SCALE, rect.size.x / 300.0)
	var above := 40.0 * scale_value
	var height := minf(rect.size.y + above, 195.0 * scale_value)
	var quad := ColorRect.new()
	quad.name = "OneWayPaint"
	quad.position = rect.position - Vector2(0, above)
	quad.size = Vector2(rect.size.x, height)
	quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = MATERIAL
	material.set_shader_parameter("atlas", PlainsCohesionArt.ATLAS)
	material.set_shader_parameter("platform_width", rect.size.x)
	material.set_shader_parameter("art_scale", scale_value)
	material.set_shader_parameter("draw_height", height)
	quad.material = material
	return quad
