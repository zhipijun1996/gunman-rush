class_name PlainsWoodPlatformArt
extends RefCounted
const MATERIAL := preload("res://shaders/plains_wood_platform.gdshader")
## The visual follows the authored rectangle; body/collision remain module-owned.
static func build(rect: Rect2, pixel_style: bool = true) -> CanvasItem:
	if not pixel_style: return _legacy_build(rect)
	var node := PixelOneWayPaint.new()
	node.name = "PixelOneWayPaint"
	node.bounds = rect
	return node

class PixelOneWayPaint extends Node2D:
	var bounds: Rect2
	func _draw() -> void:
		PixelFormalTerrain.draw_one_way(self, bounds)

# Historical fixture-only renderer; never an input to the new pixel material.
static func _legacy_build(rect: Rect2) -> ColorRect:
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
