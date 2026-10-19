class_name BellstriderBellProjectile
extends BossProjectile
var flight_velocity:=Vector2.ZERO
var gravity:=360.0
func aim_landing(point: Vector2) -> void:
	var duration:=.9
	flight_velocity=(point-global_position)/duration-Vector2(0,gravity*duration*.5)
func advance(delta: float) -> void:
	if spent or delta<=0 or not is_finite(delta): return
	var motion_velocity:=flight_velocity+Vector2(0,gravity*delta*.5)
	direction=motion_velocity.normalized()
	speed=motion_velocity.length()
	super.advance(delta)
	flight_velocity.y+=gravity*delta
func _draw() -> void:
	if PixelFormalActors.pixel_context(self):
		PixelFormalActors.projectile(self,radius,direction,true)
		return
	var parts: Texture2D=preload("res://assets/plains_v4/windkeeper/parts.png")
	draw_texture_rect_region(parts,Rect2(-11,-14,22,29),Rect2(735,20,435,575))
