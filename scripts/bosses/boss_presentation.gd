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
	var key: StringName = &"boss_dead" if not alive else (&"boss_phase_1" if encounter.phases.phase == 1 else &"boss_phase_2")
	# Shared 390px foot anchor keeps the phase swap planted. No collision or
	# attack range is inferred from the painted shoulder cannons.
	var scale_factor := minf(size.x * 1.20 / 429.0, size.y * 1.10 / 381.0)
	var destination := PlainsActorAssets.anchored_rect("enemies", key, Vector2(0, size.y * 0.5), scale_factor)
	draw_texture_rect(PlainsActorAssets.texture("enemies", key), destination, false, Color.WHITE if alive else Color(0.8, 0.8, 0.8, 0.65))
	if alive and encounter.pattern.telegraphing:
		draw_arc(Vector2.ZERO, size.length() * 0.6, 0, TAU, 40, Color(1.0, 0.45, 0.18, 0.5 + encounter.pattern.warning_progress * 0.5), 3.0)
	var bar := Rect2(-size.x * 0.5, -size.y * 0.5 - 15, size.x, 6)
	draw_rect(bar, Color(0.15, 0.15, 0.18))
	bar.size.x *= encounter.health.current / maxf(1.0, encounter.health.capacity)
	draw_rect(bar, Color(1.0, 0.55, 0.32))
