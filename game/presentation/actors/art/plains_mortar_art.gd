class_name PlainsMortarArt
extends Node2D
## One isolated painted barrel, no cloth/arch in the rotating cutout.
const TEXTURE=preload("res://assets/plains_boss_motion_142/bellstrider_mortar.png")
const GEOMETRY=preload("res://game/presentation/actors/art/plains_mortar_geometry.gd")
var destination:=Rect2()
var elevation:=0.0
static func point(key: String) -> Vector2:
	match key:
		"pivot":return GEOMETRY.PIVOT
		"joint":return GEOMETRY.JOINT
		"muzzle":return GEOMETRY.MUZZLE
		_:return GEOMETRY.FRAME_SIZE
static func painted_axis() -> Vector2:
	return point("muzzle")-point("joint")
static func barrel_length() -> float:
	return painted_axis().length()
func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var surface:=ShaderMaterial.new()
	surface.shader=preload("res://game/presentation/actors/art/plains_actor_separation.gdshader")
	material=surface
func present(frame: Dictionary, angle: float, flash: float) -> void:
	var animation: PlainsActorAnimation=frame.animation
	var joint:=PlainsBossTween.anchor(frame,animation.barrel_pivots)
	position=frame.origin+joint*Vector2(frame.face,1)
	scale=Vector2(frame.face,1)
	elevation=angle-painted_axis().angle()
	destination=Rect2(-point("pivot")-point("joint"),point("frame_size"))
	(material as ShaderMaterial).set_shader_parameter("hit_flash",flash)
	visible=true;queue_redraw()
func _draw() -> void:
	draw_set_transform(Vector2.ZERO,elevation)
	draw_texture_rect(TEXTURE,destination,false)
