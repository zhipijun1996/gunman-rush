class_name PlainsWindowLight
extends RefCounted
## Authored window shaft behind actors/terrain; the actual light lives on its glass emitter.
static func attach(window: Sprite2D) -> void:
	var shaft:=Polygon2D.new()
	shaft.name="WindowDaylight"
	shaft.polygon=PackedVector2Array([Vector2(-26,-158),Vector2(24,-158),Vector2(206,170),Vector2(76,170)])
	var white:=GradientTexture2D.new()
	var gradient:=Gradient.new();gradient.colors=PackedColorArray([Color.WHITE,Color.WHITE])
	white.gradient=gradient;white.width=2;white.height=2
	shaft.texture=white
	shaft.uv=PackedVector2Array([Vector2(0,0),Vector2(2,0),Vector2(2,2),Vector2(0,2)])
	var material:=ShaderMaterial.new()
	material.shader=preload("res://game/presentation/world/plains_v07/window_shaft.gdshader")
	shaft.material=material
	shaft.z_index=1
	window.add_child(shaft)
