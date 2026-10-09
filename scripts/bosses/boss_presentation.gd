class_name BossPresentation
extends Node2D

@export var encounter: BossEncounter

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if encounter == null or encounter.definition == null:
		return
	var size := encounter.definition.collision_size
	var alive := not encounter.health.terminal
	var tint := Color(0.46, 0.66, 0.76) if encounter.phases.phase == 1 else Color(0.86, 0.39, 0.24)
	if not alive:
		tint = Color(0.28, 0.3, 0.33, 0.4)
	var polygon := PackedVector2Array([Vector2(-size.x * 0.5, -size.y * 0.2), Vector2(-size.x * 0.25, -size.y * 0.5), Vector2(size.x * 0.25, -size.y * 0.5), Vector2(size.x * 0.5, -size.y * 0.2), Vector2(size.x * 0.5, size.y * 0.5), Vector2(-size.x * 0.5, size.y * 0.5)])
	draw_colored_polygon(polygon, tint)
	draw_line(Vector2(-size.x * 0.28, -8), Vector2(size.x * 0.28, -8), Color(1.0, 0.83, 0.4), 5.0)
	if alive and encounter.pattern.telegraphing:
		draw_arc(Vector2.ZERO, size.length() * 0.6, 0, TAU, 40, Color(1.0, 0.45, 0.18, 0.5 + encounter.pattern.warning_progress * 0.5), 3.0)
	var bar := Rect2(-size.x * 0.5, -size.y * 0.5 - 15, size.x, 6)
	draw_rect(bar, Color(0.15, 0.15, 0.18))
	bar.size.x *= encounter.health.current / maxf(1.0, encounter.health.capacity)
	draw_rect(bar, Color(1.0, 0.55, 0.32))
