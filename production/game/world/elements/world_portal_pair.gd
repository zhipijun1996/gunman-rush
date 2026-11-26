class_name WorldPortalPair
extends TraversalMechanism

@export var paired_offset := Vector2(320,0)
@export var portal_size := Vector2(24,96)
@export var facings: Array[String] = ["left","right"]
@export var exit_clearance := 4.0
@export var initial_active := true
var active := true
var locked := -1
var previous := Vector2.ZERO
var blocked := false
const NORMALS := {"left":Vector2.LEFT,"right":Vector2.RIGHT,"up":Vector2.UP,"down":Vector2.DOWN}

func _ready() -> void:
	active = initial_active
	process_physics_priority = 900

func element_bind(context: Dictionary) -> void:
	super.element_bind(context)
	controller.motor.repositioned.connect(rebase)
	rebase()

func center(index: int) -> Vector2:
	return to_global(Vector2.ZERO if index == 0 else paired_offset)

func extent(box: Rect2, axis: Vector2) -> float:
	return axis.abs().dot(box.size*.5)

func overlaps(index: int, box: Rect2) -> bool:
	var normal: Vector2 = NORMALS[facings[index]]
	var offset := box.get_center()-center(index)
	return absf(offset.dot(normal)) <= portal_size.x*.5+extent(box,normal) and absf(offset.dot(normal.orthogonal())) <= portal_size.y*.5+extent(box,normal.orthogonal())

func rebase() -> void:
	var box := player_box()
	previous = box.get_center()
	locked = -1
	for i: int in 2:
		if overlaps(i,box): locked = i

func _physics_process(_delta: float) -> void:
	if not live(): return
	var box := player_box()
	var current := box.get_center()
	if locked >= 0 and not overlaps(locked,box): locked = -1
	if active and locked < 0 and previous != current:
		for entry: int in 2:
			if try_pass(entry,box,previous,current): break
	previous = player_box().get_center()

func try_pass(entry: int, box: Rect2, from: Vector2, to: Vector2) -> bool:
	var n: Vector2 = NORMALS[facings[entry]]
	var front := portal_size.x*.5+extent(box,n)
	var before := (from-center(entry)).dot(n)
	var after := (to-center(entry)).dot(n)
	if before <= 0 or after >= before or after > front: return false
	var tangent := n.orthogonal()
	var entry_at := from.lerp(to,clampf((before-front)/(before-after),0,1))
	var sideways := (entry_at-center(entry)).dot(tangent)
	if absf(sideways)+extent(box,tangent) > portal_size.y*.5: return false
	var exit := 1-entry
	var out: Vector2 = NORMALS[facings[exit]]
	var turn := (-n).angle_to(out)
	if absf(sideways)+extent(box,out.orthogonal()) > portal_size.y*.5:
		blocked = true
		queue_redraw()
		return false
	var destination := center(exit)+(tangent*sideways).rotated(turn)+out*(portal_size.x*.5+extent(box,out)+exit_clearance)
	var transform_at := player_shape.global_transform
	transform_at.origin = destination
	blocked = overlap(self,player_shape.shape,transform_at,[controller.motor.get_rid()])
	queue_redraw()
	if blocked: return false
	if controller.motor.last_portal_step == Engine.get_physics_frames(): return false
	controller.traversal.detach_for_transfer()
	if controller.motor.portal_move(destination-(box.get_center()-controller.motor.global_position),turn):
		locked = exit
		return true
	return false

func reset_attempt() -> void:
	active = initial_active
	blocked = false
	rebase()
	queue_redraw()

func element_state() -> Dictionary:
	return {"phase":"blocked" if blocked else "ready","active":active,"arrival":locked}

func element_restore(data: Dictionary) -> void:
	active = data.active
	locked = data.arrival
	if not active: blocked = false
	queue_redraw()

func _draw() -> void:
	for i: int in 2:
		var p := Vector2.ZERO if i==0 else paired_offset
		var normal: Vector2 = NORMALS[facings[i]]
		var tangent := normal.orthogonal()
		var color := Color("d0aa72") if active else Color("55595b")
		if blocked: color = Color("d38070")
		var edge := p+normal*portal_size.x*.5
		draw_line(edge-tangent*portal_size.y*.5,edge+tangent*portal_size.y*.5,color,3)
		for side: float in [-1.0,1.0]:
			var corner := edge+tangent*portal_size.y*.5*side
			draw_line(corner,corner-normal*portal_size.x,color,4)
		draw_line(p,p+normal*8,color,2)
