class_name WorldConveyor
extends TraversalMechanism

@export var bounds := Rect2(0,0,192,20)
@export_enum("floor","wall") var surface_mode := "floor"
@export_enum("left","right") var wall_face := "left"
@export var surface_speed := 80.0
@export var initial_active := true
var active := true
var tread_offset := 0.0

func _ready() -> void:
	active = initial_active
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("conveyor",self)
	body.set_meta("editor_entity_id",element_id)
	rectangle(body,bounds.size,bounds.get_center())
	add_child(body)

func transport(normal: Vector2, attached_to_wall: bool) -> Vector2:
	if not active: return Vector2.ZERO
	if surface_mode == "floor" and normal.y < -.7: return Vector2.RIGHT*surface_speed
	var outside := -1.0 if wall_face == "left" else 1.0
	if surface_mode == "wall" and attached_to_wall and normal.x * outside > .7: return Vector2.DOWN*surface_speed
	return Vector2.ZERO

func _process(delta: float) -> void:
	if not active: return
	tread_offset = fposmod(tread_offset + surface_speed*delta,12)
	queue_redraw()

func element_state() -> Dictionary:
	return {"phase":"running" if active else "stopped","active":active}

func element_restore(data: Dictionary) -> void:
	active = data.active

func _draw() -> void:
	draw_rect(bounds,Color("424b48"))
	var direction := Vector2.RIGHT if surface_mode=="floor" else Vector2.DOWN
	var edge := bounds.position
	if surface_mode=="wall" and wall_face=="right": edge.x += bounds.size.x-3
	var length := bounds.size.dot(direction)
	var at := tread_offset
	while at+5 < length:
		draw_line(edge+direction*at,edge+direction*(at+5),Color("d8b774") if active else Color("8b826d"),4)
		at += 12
