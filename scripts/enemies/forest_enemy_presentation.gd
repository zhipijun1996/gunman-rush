class_name ForestEnemyPresentation
extends Node2D
@export var actor: EnemyActor
var age := 0.0
func _process(delta: float) -> void:
	age += delta
	queue_redraw()
func _draw() -> void:
	if actor == null: return
	var alive := not actor.health.terminal
	var state: StringName = actor.attack_behavior.state if actor.attack_behavior != null else &"idle"
	var bible_body := ForestBibleActors.draw_enemy_body(self, actor, age)
	if actor.definition.behavior_id == &"forest_lantern":
		if not bible_body:
			var wing := 8 + sin(age * 14) * 3 if alive else 6.0
			_paint_ellipse(Vector2(-12, -6), Vector2(wing, 4), Color(.65, .88, .67, .65))
			_paint_ellipse(Vector2(12, -6), Vector2(wing, 4), Color(.65, .88, .67, .65))
			draw_circle(Vector2.ZERO, 11, Color(.21, .4, .29) if alive else Color(.2, .2, .2))
			draw_arc(Vector2(0, 2), 7, 0, TAU, 20, Color(.96, .82, .35) if alive else Color(.4,.4,.4), 3)
		if state == &"telegraph": draw_line(Vector2.ZERO, Vector2(actor.brain.direction * 22, 0), Color.WHITE, 2)
	else:
		if not bible_body:
			draw_line(Vector2(0, 17), Vector2(0,-10), Color(.25,.46,.26), 8)
			draw_circle(Vector2(0,-5), 14, Color(.45,.2,.35) if alive else Color(.2,.2,.2))
			for side: int in [-1,1]: draw_line(Vector2(side*20, 10), Vector2(0,-8), Color(.5,.65,.34), 5)
		if state == &"telegraph":
			draw_arc(Vector2(0,-5), 18, 0, TAU, 24, Color(1,.65,.3), 3)
			var goal := to_local(actor.attack_behavior.attack_goal)
			var size := actor.definition.pulse_size
			draw_rect(Rect2(goal-Vector2(size.x*.5, 3), Vector2(size.x, 3)),Color(1,.75,.35))
			draw_arc(goal, size.x*.5, PI, TAU, 20, Color(1,.75,.35), 2)
func _paint_ellipse(center: Vector2, extent: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i: int in 20: points.append(center + Vector2(cos(TAU*i/20)*extent.x, sin(TAU*i/20)*extent.y))
	draw_colored_polygon(points, color)
