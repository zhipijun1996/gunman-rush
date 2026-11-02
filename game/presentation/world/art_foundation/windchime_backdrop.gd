class_name WindchimeBackdrop
extends Node2D
## Three independent atmosphere planes. Finite panorama, no vertical tiling.
const SKY := preload("res://assets/windchime_plains/meadow_distance.png")
const MIDDLE := preload("res://assets/windchime_plains/middle_ruins.svg")
const CLOUDS := preload("res://assets/windchime_plains/cloud_veil.svg")
var far_enabled := true
var middle_enabled := true
var _clock := 0.0

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _draw() -> void:
	var camera := get_viewport().get_camera_2d()
	var center := camera.global_position if camera != null else Vector2(640,360)
	var d := center - Vector2(640,360)
	var factor := get_viewport_rect().size / Vector2(1280,720)
	draw_set_transform(Vector2.ZERO,0,factor)
	draw_rect(Rect2(0,0,1280,720),Color("c1d6c7"))
	if far_enabled:
		draw_texture_rect(SKY, Rect2(Vector2(-96-d.x*.035,-55-d.y*.025), Vector2(1500,844)),false)
	if middle_enabled:
		draw_texture_rect(MIDDLE,Rect2(Vector2(-80-d.x*.16,-150-d.y*.08),Vector2(2560,900)),false)
		draw_texture_rect(CLOUDS,Rect2(Vector2(-d.x*.23+sin(_clock*.035)*8,-185-d.y*.12),Vector2(2560,900)),false)
	# Tiny distant birds stay pale and never use a gameplay object silhouette.
	for i: int in 7:
		var p := Vector2(180+i*172, 205+sin(float(i)*2.2)*45) - d*Vector2(.07,.02)
		p.x += sin(_clock*.16+i)*10
		draw_polyline(PackedVector2Array([p+Vector2(-4,-2),p,p+Vector2(4,-2)]),Color("f5eed7"),1.5,true)
	draw_set_transform(Vector2.ZERO)
