class_name WindchimePlatform
extends Blob47Platform
## Presentation only. Inherits the existing carried/one-way collision behavior.
func _draw() -> void:
	var r := bounds
	var navy := Color("35473d")
	draw_rect(r, Color("6d6855") if one_way else Color("a58a4f"))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color("e8d7a3"))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3), Vector2(r.size.x, 3)), navy)
	for x: int in range(0, int(r.size.x), 24):
		draw_line(r.position + Vector2(x, 3), r.position + Vector2(x, r.size.y - 2), navy, 1)
	if not one_way:
		for x: float in [r.position.x + 8, r.end.x - 8]:
			draw_circle(Vector2(x, r.position.y + r.size.y * .55), 2, Color("f4e8c1"))
		var mid := r.get_center()
		draw_polyline(PackedVector2Array([mid + Vector2(-7,-2), mid + Vector2(0,2), mid + Vector2(7,-2)]), navy, 2, true)
