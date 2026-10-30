extends StaticBody2D
## Delivery gear-seal/1: a physical 32px inward closure, with visible teeth.
## Contact damage has no delivered value and is deliberately not invented.
var rect_pixels: Rect2
var port_id := ""

func configure(spec: Dictionary) -> void:
	port_id = spec.port_id
	rect_pixels = Rect2(spec.rect_pixels[0], spec.rect_pixels[1], spec.rect_pixels[2], spec.rect_pixels[3])
	name = "Seal_" + port_id
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect_pixels.size
	shape.shape = rectangle
	shape.position = rect_pixels.get_center()
	add_child(shape)
	add_to_group(&"mapgen_gear_seals")
	queue_redraw()

func _draw() -> void:
	draw_rect(rect_pixels, Color("403c38"))
	var vertical := rect_pixels.size.y > rect_pixels.size.x
	for index: int in 4:
		var center := rect_pixels.position + (Vector2(16, 16 + index * 32) if vertical else Vector2(16 + index * 32, 16))
		var teeth := PackedVector2Array()
		for tooth: int in 32:
			var angle := float(tooth) * TAU / 32
			teeth.append(center + Vector2.from_angle(angle) * (15 if tooth % 4 in [1, 2] else 11))
		draw_colored_polygon(teeth, Color("b7a084"))
		draw_circle(center, 6, Color("6b6256"))
		draw_circle(center, 2, Color("ddc59e"))
