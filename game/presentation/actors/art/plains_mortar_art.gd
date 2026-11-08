class_name PlainsMortarArt
extends Node2D
## A measured crop from the same authored frame. No reconstructed/raster art.
var animation: PlainsActorAnimation
var source := Rect2()
var destination := Rect2()
var elevation := 0.0
func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var surface:=ShaderMaterial.new()
	surface.shader=preload("res://game/presentation/actors/art/plains_actor_separation.gdshader")
	material=surface
func present(frame: Dictionary, angle: float, flash: float) -> Vector4:
	animation=frame.animation
	var index:=animation.frame_index(frame.clip,frame.progress)
	var region:=animation.barrel_regions[index]
	var joint:=animation.barrel_pivots[index]
	var painted_axis:=animation.muzzle_points[index]-joint
	position=frame.origin+joint*Vector2(frame.face,1)
	scale=Vector2(frame.face,1)
	elevation=angle-painted_axis.angle()
	source=Rect2(animation.region(frame.clip,frame.progress).position+region.position,region.size)
	destination=Rect2(region.position-animation.pivot-joint,region.size)
	(material as ShaderMaterial).set_shader_parameter("hit_flash",flash)
	visible=true;queue_redraw()
	var size:=animation.atlas.get_size()
	return Vector4(source.position.x/size.x,source.position.y/size.y,source.size.x/size.x,source.size.y/size.y)
func _draw() -> void:
	if animation==null:return
	draw_set_transform(Vector2.ZERO,elevation)
	draw_texture_rect_region(animation.atlas,destination,source)
