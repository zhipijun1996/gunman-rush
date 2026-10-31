class_name GrappleAnchor
extends Area2D
## Explicit hookable clock-ring. Background ornaments never get this tag.
## Legacy rings bounce by default; explicit rest rings hold until jump/fire/H.
@export var hang_enabled := false
var clock := 0.0
func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	add_to_group(&"grapple_target")
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12
	collision.shape = circle
	add_child(collision)
func _process(delta: float) -> void:
	clock += delta
	queue_redraw()
func _draw() -> void:
	draw_circle(Vector2.ZERO,16,Color(.2,.32,.28,.7))
	draw_arc(Vector2.ZERO,12,0,TAU,32,Color("e4bc6e"),3,true)
	draw_arc(Vector2.ZERO,7,0,TAU,24,Color("fff0c6"),1.5,true)
	if hang_enabled:
		draw_line(Vector2(-10,-21),Vector2(10,-21),Color("83f4d4"),3,true)
		draw_line(Vector2(-10,-21),Vector2(-10,-13),Color("83f4d4"),3,true)
		draw_line(Vector2(10,-21),Vector2(10,-13),Color("83f4d4"),3,true)
		draw_arc(Vector2.ZERO,20,0,TAU,32,Color("83f4d4"),2,true)
	for i: int in 4:
		var direction := Vector2.RIGHT.rotated(i*PI/2+sin(clock)*.04)
		draw_line(direction*13,direction*18,Color("ba9150"),2,true)
