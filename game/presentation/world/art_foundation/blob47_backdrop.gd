class_name Blob47Backdrop
extends Node2D
## Screen-space parallax with a single vertical horizon. No repeated sky rows.
const SKY := preload("res://assets/art_foundation_v1/sky.svg")
const FAR := preload("res://assets/art_foundation_v1/far.svg")
const MIDDLE := preload("res://assets/art_foundation_v1/middle.svg")
var far_enabled := true
var middle_enabled := true

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	var factor := maxf(viewport_size.x / 1280.0, viewport_size.y / 720.0)
	var camera := get_viewport().get_camera_2d()
	var center := camera.global_position if camera != null else Vector2(640, 360)
	draw_texture_rect(SKY, Rect2(Vector2.ZERO, Vector2(2560, 720) * factor), false)
	if far_enabled: _parallax(FAR, center, factor, .10)
	if middle_enabled: _parallax(MIDDLE, center, factor, .25)

func _parallax(texture: Texture2D, center: Vector2, factor: float, rate: float) -> void:
	var width := 2560 * factor
	var x := -fposmod(center.x * rate * factor, width)
	var y := clampf((360 - center.y) * rate * .3, -40, 40) * factor
	for index: int in 2:
		draw_texture_rect(texture, Rect2(Vector2(x + index * width, y), Vector2(2560, 720) * factor), false)
