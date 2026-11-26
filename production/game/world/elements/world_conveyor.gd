class_name WorldConveyor
extends TraversalMechanism

@export var bounds := Rect2(0,0,192,20)
@export_enum("floor","wall") var surface_mode := "floor"
@export_enum("left","right") var wall_face := "left"
@export var surface_speed := 80.0
@export var initial_active := true
var active := true
var tread_offset := 0.0
var wheel_angle := 0.0

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
	var travel := surface_speed*delta
	tread_offset = fposmod(tread_offset+travel,12)
	var depth := bounds.size.y if surface_mode=="floor" else bounds.size.x
	var radius := maxf(1,minf(depth-2,20)*.5)
	var winding := -1 if surface_mode=="wall" and wall_face=="left" else 1
	wheel_angle = fposmod(wheel_angle+winding*travel/radius,TAU)
	queue_redraw()

func element_state() -> Dictionary:
	return {"phase":"running" if active else "stopped","active":active}

func element_restore(data: Dictionary) -> void:
	active = data.active

func _draw() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	MechanismRegionArt.panel(self,bounds)
	var direction := Vector2.RIGHT if surface_mode=="floor" else Vector2.DOWN
	var inward := Vector2.DOWN if surface_mode=="floor" else Vector2.RIGHT if wall_face=="left" else Vector2.LEFT
	var length := bounds.size.dot(direction)
	var depth := bounds.size.dot(inward.abs())
	var start := bounds.position if inward != Vector2.LEFT else Vector2(bounds.end.x,bounds.position.y)
	var roller := minf(depth-2,20)
	if roller < 1: return
	var face := minf(6,depth*.32)
	var rail := start+inward*face
	draw_line(rail,rail+direction*length,Color("241e24"),maxf(2,face))
	var metal := Color("d1ba83") if active else Color("756d68")
	var at := tread_offset-12
	while at < length:
		var left := maxf(at,0)
		var right := minf(length,at+8)
		if roundf(left) < roundf(right):
			var a := start+direction*left
			var b := start+direction*right
			draw_line((a+inward*face*.5).round(),(b+inward*face*.5).round(),metal.darkened(.4),maxf(1,face))
			draw_line(a.round(),b.round(),metal,2)
		at += 12
	var count := maxi(2,ceili(length/48))
	for index: int in count:
		var along := lerpf(roller*.5,length-roller*.5,float(index)/(count-1))
		var point := start+direction*along+inward*(depth-roller*.5)
		TraversalMechanismArt.wheel(self,point,roller,wheel_angle,Color.WHITE if active else Color("97929b"))
