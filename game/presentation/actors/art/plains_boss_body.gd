class_name PlainsBossBody
extends Node2D
## Dedicated CanvasItem keeps deformation uniforms away from sparks/wind textures.
var frame: Dictionary={}
func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var surface:=ShaderMaterial.new()
	surface.shader=PlainsBossTween.SHADER
	material=surface
func present(pose: Dictionary, flash: float) -> void:
	frame=pose
	(material as ShaderMaterial).set_shader_parameter("hit_flash",flash)
	queue_redraw()
func _draw() -> void:
	if not frame.is_empty():PlainsBossFrames.draw(self,frame)
