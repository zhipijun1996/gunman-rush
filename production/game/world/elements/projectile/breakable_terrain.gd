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
var fragments: Array[Dictionary] = []

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
	queue.append({"cells":cells,"contact":point})
	submit.call(element_id)
	return true

func cancel_pending() -> void:
	receipts.clear()
	queue.clear()
	fragments.clear()

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
func accept_committed() -> void:
	var work := queue.pop_front() as Dictionary
	var stride := maxi(1,ceili(work.cells.size()/12.))
	for index: int in range(0,work.cells.size(),stride):
		var i: int = work.cells[index]
		var point: Vector2 = work.contact if break_mode=="whole" else rectangles[i].get_center()
		fragments.append({"point":point,"age":0.0,"broken":hp[i]==0})
func _physics_process(delta: float) -> void:
	if not fragments.is_empty():
		for i: int in range(fragments.size()-1,-1,-1):
			fragments[i].age += delta
			if fragments[i].age>=.28: fragments.remove_at(i)
		queue_redraw()
	if not queue.is_empty() and controller.active: submit.call(element_id)
func _draw() -> void:
	for i in hp.size():
		if hp[i]<=0: continue
		var rect := rectangles[i]
		var strength := float(hp[i])/hits_required
		MechanismRegionArt.panel(self,rect,Color.WHITE.lerp(Color("a18f91"),1.-strength))
		var seed_angle := sin(float(i*23+41))
		var points := PackedVector2Array()
		for offset: Vector2 in [Vector2(.13,0),Vector2(.29,.22),Vector2(.23,.34),Vector2(.43,.48),Vector2(.39,.58)]:
			var unit := Vector2(.5+(offset.x-.5)*seed_angle,offset.y)
			points.append((rect.position+unit*rect.size).round())
		draw_polyline(points,Color("1b182899"),1)
		var last := points[points.size()-1]
		if strength<1:
			var end := (rect.position+rect.size*Vector2(.79,.95)).round()
			draw_polyline(PackedVector2Array([last,last.lerp(end,.30)+Vector2(2,-2),last.lerp(end,.58)-Vector2(3,0),end]),Color("211b27"),2)
			draw_line(last,last.lerp(rect.position,.54)+Vector2(4,0),Color("4c3c3b"),1)
		if rect.size.x>=22 and rect.size.y>=20 and (i%5==1 or break_mode=="whole"):
			MechanismRegionArt.stamp(self,"hazard",rect.get_center()+Vector2(2,2),Vector2(13,11),Color("ada29a"))
	for effect: Dictionary in fragments:
		PixelVfx.clip(self,&"dust" if effect.broken else &"impact",effect.point,effect.age/.28,0.,Color("ceb384"),Vector2.ONE*(.55 if effect.broken else .32))
