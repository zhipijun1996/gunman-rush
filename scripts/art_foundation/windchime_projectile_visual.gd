class_name WindchimeProjectileVisual
extends Node2D
## Original cream/brass pulse graphic on the unchanged swept projectile.
var projectile: PlayerProjectile

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(projectile): return
	for i: int in range(1,projectile.trail.size()):
		draw_line(to_local(projectile.trail[i-1]),to_local(projectile.trail[i]),Color(.96,.87,.61,float(i)/projectile.trail.size()*.5),2,true)
	draw_set_transform(Vector2.ZERO,projectile.direction.angle())
	draw_colored_polygon(PackedVector2Array([Vector2(-10,-2),Vector2(1,-3),Vector2(6,0),Vector2(1,3),Vector2(-10,2)]),Color("f4e8bf"))
	draw_line(Vector2(-9,0),Vector2(2,0),Color("bfa36b"),1,true)
	draw_set_transform(Vector2.ZERO)
