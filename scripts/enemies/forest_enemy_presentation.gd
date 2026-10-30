class_name ForestEnemyPresentation
extends Node2D
@export var actor: EnemyActor
var age := 0.0
var hit_template: EnemyHitTemplate
var motion: ForestMotion02
var lifecycle := EnemyPresentationLifecycle.new()
func _ready() -> void:
	if EnemyPresentationBinding.bind_existing(actor,self,&"forest").is_empty(): return
	hit_template = EnemyHitTemplate.install(actor, self)
	motion = ForestMotion02.install(self)
	lifecycle.bind(actor,self,_presentation_initialized,Callable(),motion)
	lifecycle.own_cleanup(hit_template.dispose)
func _presentation_initialized() -> void:
	age = 0.0
	queue_redraw()
func synchronize_presentation() -> void:
	lifecycle.synchronize()
func _exit_tree() -> void:
	lifecycle.dispose()
func _process(delta: float) -> void:
	if not lifecycle.advance(delta): return
	age += delta
	queue_redraw()
func _draw() -> void:
	if not lifecycle.is_bound(): return
	if actor == null: return
	var alive := not actor.health.terminal
	var bible_body := ForestBibleActors.draw_enemy_body(self, actor, age)
	if actor.definition.behavior_id == &"forest_lantern":
		if not bible_body:
			hit_template.begin_body(self)
			var wing := 8 + sin(age * 14) * 3 if alive else 6.0
			_paint_ellipse(Vector2(-12, -6), Vector2(wing, 4), hit_template.tint(Color(.65, .88, .67, .65)))
			_paint_ellipse(Vector2(12, -6), Vector2(wing, 4), hit_template.tint(Color(.65, .88, .67, .65)))
			draw_circle(Vector2.ZERO, 11, hit_template.tint(Color(.21, .4, .29) if alive else Color(.2, .2, .2)))
			draw_arc(Vector2(0, 2), 7, 0, TAU, 20, hit_template.tint(Color(.96, .82, .35) if alive else Color(.4,.4,.4)), 3)
			draw_set_transform(Vector2.ZERO)
	else:
		if not bible_body:
			hit_template.begin_body(self)
			draw_line(Vector2(0, 17), Vector2(0,-10), hit_template.tint(Color(.25,.46,.26)), 8)
			draw_circle(Vector2(0,-5), 14, hit_template.tint(Color(.45,.2,.35) if alive else Color(.2,.2,.2)))
			for side: int in [-1,1]: draw_line(Vector2(side*20, 10), Vector2(0,-8), hit_template.tint(Color(.5,.65,.34)), 5)
			draw_set_transform(Vector2.ZERO)
func _paint_ellipse(center: Vector2, extent: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i: int in 20: points.append(center + Vector2(cos(TAU*i/20)*extent.x, sin(TAU*i/20)*extent.y))
	draw_colored_polygon(points, color)
