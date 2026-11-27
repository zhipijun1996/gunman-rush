class_name DemoResonanceLine
extends DemoResourceTrack
## Frame-free line using the inherited official current/capacity projection.
func _draw() -> void:
	var y := size.y * 0.5
	var fraction := clampf(current / maxf(capacity, 0.001), 0.0, 1.0)
	draw_line(Vector2(0, y + 1), Vector2(size.x, y + 1), Color(COLORS.INK, 0.9), 5, false)
	draw_line(Vector2(0, y), Vector2(size.x, y), Color(COLORS.PAPER, 0.35), 2, false)
	if fraction > 0:
		draw_line(Vector2(0, y), Vector2(size.x * fraction, y), COLORS.PAPER if flash > 0 else COLORS.BRASS, 3, false)
