class_name WorldMotionSurface
extends StaticBody2D

@export var bounds := Rect2(0,0,192,16)
@export_enum("sticky","ice") var surface_mode := "sticky"
@export var walk_speed_scale := 0.5
@export var walk_acceleration_scale := 0.5
@export var brake_scale := 0.15
@export var reverse_acceleration_scale := 0.35

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	TraversalMechanism.rectangle(self,bounds.size,bounds.get_center())
	set_meta("motion_surface",self)

func walk_velocity(current: float, axis: float, speed: float, acceleration: float, delta: float) -> float:
	if surface_mode == "sticky":
		return move_toward(current,axis*speed*walk_speed_scale,acceleration*delta*(1.0 if is_zero_approx(axis) else walk_acceleration_scale))
	if is_zero_approx(axis): return move_toward(current,0,acceleration*delta*brake_scale)
	if current*axis < 0:
		var rate := acceleration*reverse_acceleration_scale
		var braking := minf(absf(current)/rate,delta)
		current = move_toward(current,0,braking*rate)
		delta -= braking
	return move_toward(current,axis*speed,acceleration*delta)

func _draw() -> void:
	draw_rect(bounds,Color("463e4b") if surface_mode=="sticky" else Color("43849a"))
	draw_line(bounds.position,Vector2(bounds.end.x,bounds.position.y),Color("aaa364") if surface_mode=="sticky" else Color("b4eff0"),3)
	for x: int in range(8,int(bounds.size.x)-8,17):
		var at := bounds.position+Vector2(x,5)
		if surface_mode=="sticky": draw_circle(at,3,Color("8b8557"))
		else: draw_line(at,at+Vector2(6,-3),Color("8acee1"),2)
