class_name ProjectileArt
extends RefCounted
const ATLAS := preload("res://assets/plains_v4/projectiles.png")
# Hand-painted transparent atlas; anchor at bright head, decorative trail behind.
# Radius remains gameplay-owned; artwork never creates a hurtbox.
static func paint(canvas: Node2D, kind: int, direction: Vector2, radius: float) -> void:
	var cells := [Vector2(0, 0), Vector2(640, 0), Vector2(0, 640), Vector2(640, 640)]
	var anchor := Vector2(505, 330) if kind < 2 else Vector2(505, 325)
	var scale_factor := radius / (110.0 if kind == 0 else 160.0)
	canvas.draw_set_transform(Vector2.ZERO, direction.angle())
	canvas.draw_texture_rect_region(ATLAS, Rect2(-anchor * scale_factor, Vector2.ONE * 640 * scale_factor), Rect2(cells[kind], Vector2.ONE * 640))
	canvas.draw_set_transform(Vector2.ZERO)
