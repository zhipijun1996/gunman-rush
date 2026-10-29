class_name WindchimeEnemyVisual
extends Node2D
## New wind-up bird skin on the existing patrol enemy, no new AI or stats.
var actor: EnemyActor
var _clock := 0.0
var _hurt := 0.0
var lifecycle := EnemyPresentationLifecycle.new()

func _presentation_profile() -> StringName:
	return &"windchime"

func _ready() -> void:
	if EnemyPresentationBinding.bind_existing(actor,self,_presentation_profile()).is_empty(): return
	lifecycle.bind(actor,self,_presentation_initialized,_presentation_health_changed)

func _presentation_initialized() -> void:
	_hurt = 0.0
	visible = not actor.health.terminal
	queue_redraw()

func _presentation_health_changed(result: ActorResourceResult) -> void:
	if result.status == ActorResourceResult.Status.APPLIED and result.amount_applied < 0: _hurt = .12

func synchronize_presentation() -> void:
	lifecycle.synchronize()

func _exit_tree() -> void:
	lifecycle.dispose()

func _process(delta: float) -> void:
	if not lifecycle.advance(delta): return
	_advance_presentation(delta)

func _advance_presentation(delta: float) -> void:
	_clock += delta
	_hurt = maxf(0, _hurt - delta)
	visible = not actor.health.terminal
	queue_redraw()

func _draw() -> void:
	if not lifecycle.is_bound(): return
	if actor == null or actor.health.terminal: return
	var facing := float(actor.brain.direction)
	var ink := Color("2c4137")
	var gold := Color("b6a066") if _hurt <= 0 else Color("f1ddae")
	draw_set_transform(Vector2(0,sin(_clock*6)),0,Vector2(facing,1))
	var stride := sin(_clock * 12) * 3
	draw_line(Vector2(-5,8),Vector2(-7+stride,16),ink,3,true)
	draw_line(Vector2(4,8),Vector2(6-stride,16),ink,3,true)
	draw_colored_polygon(PackedVector2Array([Vector2(-10,3),Vector2(-23,-6),Vector2(-18,3),Vector2(-23,5),Vector2(-7,10)]),ink)
	draw_circle(Vector2(-2,1),12,gold)
	draw_colored_polygon(PackedVector2Array([Vector2(-10,-3),Vector2(5,2),Vector2(-5,8)]),ink)
	draw_circle(Vector2(10,-7),8,ink)
	draw_circle(Vector2(12,-9),2,Color("f6e9c4"))
	draw_colored_polygon(PackedVector2Array([Vector2(16,-7),Vector2(25,-4),Vector2(16,-3)]),gold)
	draw_line(Vector2(-4,-9),Vector2(-4,-20),gold,2,true)
	draw_arc(Vector2(-8,-20),4,0,TAU,16,gold,2,true)
	draw_arc(Vector2(0,-20),4,0,TAU,16,gold,2,true)
	draw_set_transform(Vector2.ZERO)
	for i: int in ceili(actor.health.current):
		draw_circle(Vector2(-5+i*5,-31),1.4,Color("f2dfad"))
