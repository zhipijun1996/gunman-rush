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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	MechanismRegionArt.panel(self,bounds)
	var sheet := TraversalMechanismArt.RESIN if surface_mode=="sticky" else TraversalMechanismArt.ICE
	var depth := minf(sheet.get_height(),bounds.size.y)
	var width := float(sheet.get_width())
	var offset := 0.0
	while offset < bounds.size.x:
		var span := minf(width,bounds.size.x-offset)
		var dst := Rect2(bounds.position+Vector2(offset,0),Vector2(span,depth))
		draw_texture_rect_region(sheet,dst,Rect2(0,0,span,sheet.get_height()))
		offset += span
