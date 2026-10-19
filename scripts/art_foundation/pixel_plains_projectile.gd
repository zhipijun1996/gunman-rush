class_name PixelPlainsProjectile
extends WindchimeProjectileVisual
func _draw() -> void:
	if not is_instance_valid(projectile): return
	for i: int in projectile.trail.size():
		var p := to_local(projectile.trail[i]).snapped(Vector2(2,2))
		draw_rect(Rect2(p,Vector2(4,2)),Color(.69,.73,.48,float(i)/maxi(1,projectile.trail.size())*.45))
	draw_rect(Rect2(-4,-2,8,4),Color("ead39a"))
