class_name BreakableTerrain
extends Node2D
@export var element_id := ""
@export var section_id := "main"
@export var state_scope := "permanent"
@export var bounds := Rect2(0,0,96,96)
@export_enum("whole","local_cells") var break_mode := "whole"
@export var hits_required := 1
@export var accepted_attacks: Array[String] = ["shot","explosion"]
@export var cell_size := 32
@export var dig_radius := 24.0
var hp: Array = []
var pieces: Array[StaticBody2D] = []
var rectangles: Array[Rect2] = []
var receipts := {}
var queue: Array[Dictionary] = []
var submit: Callable
var controller: PlayerController

func _ready() -> void:
	var count := Vector2i.ONE if break_mode=="whole" else Vector2i(bounds.size/float(cell_size))
	for y in count.y:
		for x in count.x:
			var rect := bounds if break_mode=="whole" else Rect2(bounds.position+Vector2(x,y)*cell_size,Vector2.ONE*cell_size)
			rectangles.append(rect)
			pieces.append(ProjectileImpact.box(self,rect,1))
			hp.append(hits_required)

func element_bind(context: Dictionary) -> void:
	submit = context.submit
	controller = context.controller

func mechanism_shot(packet: Dictionary) -> bool:
	if not is_instance_valid(controller) or packet.get("controller")!=controller or not controller.active: return false
	var at := to_local(packet.hit_point)
	var piece := pieces.find(packet.get("collider"))
	if piece>=0: at = at.clamp(rectangles[piece].position,rectangles[piece].end)
	return enqueue(packet,at)

func receive_blast(point: Vector2, radius: float, packet: Dictionary) -> void:
	var local := to_local(point)
	var closest := Vector2.INF
	var distance := INF
	for i in hp.size():
		if hp[i]<=0: continue
		var on_rect := local.clamp(rectangles[i].position,rectangles[i].end)
		var d := on_rect.distance_squared_to(local)
		if d<distance:
			distance = d
			closest = on_rect
	if distance<=radius*radius: enqueue(packet,closest)

func enqueue(packet: Dictionary, point: Vector2) -> bool:
	var attack: String = packet.get("attack_kind","")
	var parent_kind := "shot" if attack=="charged_shot" else "explosion" if attack=="bomb" else attack
	if attack not in accepted_attacks and parent_kind not in accepted_attacks: return false
	var id: String = packet.get("packet_id","")
	if id.is_empty() or receipts.has(id) or not submit.is_valid(): return false
	var cells: Array[int] = []
	for i in hp.size():
		var rect := rectangles[i]
		if hp[i]>0 and (break_mode=="whole" or point.distance_squared_to(point.clamp(rect.position,rect.end))<=dig_radius*dig_radius):
			cells.append(i)
	if cells.is_empty(): return false
	receipts[id] = true
	queue.append({"cells":cells})
	submit.call(element_id)
	return true

func cancel_pending() -> void:
	receipts.clear()
	queue.clear()

func can_commit() -> bool: return not queue.is_empty()
func element_state() -> Dictionary: return {"hp":hp.duplicate()}
func proposed_state() -> Dictionary:
	var result := hp.duplicate()
	for i: int in queue.front().cells: result[i] = maxi(0,int(result[i])-1)
	return {"hp":result}
func element_restore(data: Dictionary) -> void:
	if data.hp.size()!=pieces.size(): return
	hp = data.hp.duplicate()
	for i in hp.size(): pieces[i].collision_layer = 1 if hp[i]>0 else 0
	queue_redraw()
func accept_committed() -> void: queue.pop_front()
func _physics_process(_delta: float) -> void:
	if not queue.is_empty() and controller.active: submit.call(element_id)
func _draw() -> void:
	for i in hp.size():
		if hp[i]<=0: continue
		var rect := rectangles[i]
		draw_rect(rect,Color("66616a"))
		draw_rect(rect.grow(-1),Color("aea08b"),false,2)
		if hp[i]<hits_required:
			draw_polyline(PackedVector2Array([rect.position,rect.get_center(),rect.get_center()-Vector2(rect.size.x*.15,0),rect.end]),Color("342f3a"),2)
