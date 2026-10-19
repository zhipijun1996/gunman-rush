class_name UnderworldPlayer
extends PixelPlainsActor
## The selected courier source, with state-driven pose and real muzzle anchor.
const COURIER := preload("res://assets/style_exploration/underworld/player.png")
func _draw() -> void:
	if _dead:
		draw_set_transform(Vector2(0,14),-.5,Vector2.ONE)
		draw_texture_rect(COURIER,Rect2(-20,-18,36,25),false,Color(1,1,1,maxf(.25,1-_death_age/.65)))
		draw_set_transform(Vector2.ZERO)
		return
	var face := 1.0 if controller.router.aim_direction.x>=0 else -1.0
	var moving := motor.is_on_floor() and absf(motor.velocity.x)>10
	var bob := 2*roundf(absf(sin(_clock*14))) if moving else 0.0
	var squash := 1.0 if motor.is_on_floor() else .94 if motor.velocity.y<0 else 1.04
	draw_set_transform(Vector2(0,18-bob),0,Vector2(face,squash))
	var width := 44.0*COURIER.get_width()/COURIER.get_height()
	draw_texture_rect(COURIER,Rect2(-width*.5,-44,width,44),false)
	draw_set_transform(Vector2.ZERO)
	var anchor := motor.get_node("CourierVisual") as CourierVisual
	var muzzle := to_local(anchor.visible_muzzle_position()).snapped(Vector2(2,2))
	var aim := controller.router.aim_direction.normalized()
	PixelFormalActors.pixel_line(self,Vector2(face*4,-1),muzzle,Color("101816"),4)
	PixelFormalActors.pixel_line(self,Vector2(face*4,-3)+aim*8,muzzle-Vector2(0,2),Color("9b7740"),2)
	if _flash>0: draw_rect(Rect2(muzzle+aim*4-Vector2(2,2),Vector2(6,6)),Color("ead8a3"))
