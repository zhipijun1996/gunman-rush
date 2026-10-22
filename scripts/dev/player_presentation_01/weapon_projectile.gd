class_name PlayerWeaponFeelProjectile
extends Node2D
## A leaf on the real swept projectile. Original leaf survives for exact OFF.
var projectile: PlayerProjectile
var previous: CanvasItem
var previous_visible := true
var active := false
var mode := WeaponDefinition.Mode.PULSE
var trail_opacity := .42

func set_active(value: bool) -> void:
	active=value
	visible=value
	if not is_instance_valid(projectile): return
	if value:
		if is_instance_valid(previous): previous.hide()
		projectile.presentation=self
	else:
		if projectile.presentation==self: projectile.presentation=previous if is_instance_valid(previous) else null
		if is_instance_valid(previous): previous.visible=previous_visible
	projectile.queue_redraw()

func _process(_delta: float) -> void:
	if active: queue_redraw()

func _draw() -> void:
	if not active or not is_instance_valid(projectile): return
	var history := projectile.trail
	for i: int in range(1,history.size()):
		var t := float(i)/history.size()
		var color := Color("c6a970")
		color.a=t*t*trail_opacity
		draw_line(to_local(history[i-1]).snapped(Vector2(2,2)),to_local(history[i]).snapped(Vector2(2,2)),color,2 if t>.65 else 1,false)
	if projectile.art_kind==&"blade":
		# Preserve the equipped blade artwork/rotation; only the trail is revised.
		var texture := projectile.weapon_blade_texture()
		if texture!=null:
			draw_set_transform(Vector2.ZERO,projectile._age*20)
			draw_texture_rect(texture,Rect2(-11,-11,22,22),false)
			draw_set_transform(Vector2.ZERO)
		else: UnderworldProjectileVisual.paint(self,projectile.direction,projectile.radius,projectile._age,[],&"blade",true,projectile.skill_attack)
		return
	var length := 7.0 if mode==WeaponDefinition.Mode.MACHINE else 10.0
	var height := 2.0 if mode==WeaponDefinition.Mode.MACHINE else 3.0
	draw_set_transform(Vector2.ZERO,projectile.direction.angle())
	draw_colored_polygon(PackedVector2Array([Vector2(-length-2,-height-1),Vector2(2,-height-1),Vector2(7,0),Vector2(2,height+1),Vector2(-length-2,height+1)]),Color("17241f"))
	draw_colored_polygon(PackedVector2Array([Vector2(-length,-height),Vector2(2,-height),Vector2(5,0),Vector2(2,height),Vector2(-length,height)]),Color("e9ce8d"))
	draw_line(Vector2(-length+2,0),Vector2(4,0),Color("fff4ce"),2,false)
	if projectile.skill_attack:
		draw_line(Vector2(-length,-height-3),Vector2(0,-height-3),Color("c6a970"),1,false)
		draw_line(Vector2(-length,height+3),Vector2(0,height+3),Color("c6a970"),1,false)
	draw_set_transform(Vector2.ZERO)

func _exit_tree() -> void:
	set_active(false)
