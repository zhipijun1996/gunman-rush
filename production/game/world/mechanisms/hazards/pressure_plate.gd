@tool
class_name WorldPressurePlate
extends StaticBody2D

@export var element_id := ""
@export var section_id := "main"
@export_enum("attempt") var state_scope := "attempt"
@export var plate_size := Vector2(64,12)
@export var release_hold_s := .60
@export_enum("player","player_and_marked_weight") var accepted_load := "player"
@export var links: Array[Dictionary] = []

var occupied := false
var active := false
var remaining := 0.0
var sent_occupied := false
var sent_active := false
var controller: PlayerController
var lifetime: DemoLifetime
var runtime: WorldElementRuntime
var submit: Callable
var room: FixedWorldRoom

static func validate_configuration(_p: Dictionary,_row: Dictionary,_doc: Dictionary) -> String:
	return ""

func element_bind(context: Dictionary) -> void:
	controller = context.controller
	lifetime = context.lifetime
	runtime = context.runtime
	room = context.room
	submit = context.submit
	collision_layer = 1
	collision_mask = 0
	add_child(WorldHazardGeometry.rectangle_shape(plate_size))
	process_physics_priority = 1150
	reset_attempt()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller) or not controller.active or not lifetime.active: return
	occupied = WorldHazardGeometry.supported(controller.motor,self)
	if not occupied and accepted_load == "player_and_marked_weight":
		var top := global_transform * Rect2(-plate_size*.5,plate_size)
		for node: Node in get_tree().get_nodes_in_group("mechanism_pressure_weight"):
			if not room.is_ancestor_of(node): continue
			var load_box: Rect2 = node.pressure_bounds()
			if load_box.has_area() and absf(load_box.end.y-top.position.y) <= 1 and load_box.position.x < top.end.x and load_box.end.x > top.position.x:
				occupied = true
				break
	if occupied: remaining = release_hold_s
	else: remaining = maxf(0,remaining-delta)
	active = occupied or remaining > 0
	if can_commit(): submit.call(element_id)
	queue_redraw()

func element_signals() -> Dictionary:
	return {"occupied":occupied,"active":active}

func committed_outputs() -> Dictionary:
	return {"occupied":sent_occupied,"active":sent_active}

func element_signal() -> Dictionary:
	return {"output":"active","value":active}

func can_commit() -> bool:
	return sent_active != active or sent_occupied != occupied

func element_state() -> Dictionary:
	return {"occupied":occupied,"active":active,"remaining":remaining,"sent_occupied":sent_occupied,"sent_active":sent_active}

func proposed_state() -> Dictionary:
	var result := element_state()
	result.sent_occupied = occupied
	result.sent_active = active
	return result

func element_restore(data: Dictionary) -> void:
	occupied = data.occupied
	active = data.active
	sent_occupied = data.sent_occupied
	sent_active = data.sent_active
	remaining = data.remaining
	queue_redraw()

func reset_attempt() -> void:
	occupied = false
	active = false
	sent_active = false
	sent_occupied = false
	remaining = 0
	queue_redraw()

func accept_committed() -> void:
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(-plate_size*.5,plate_size)
	var travel := minf(3,rect.size.y*.27) if occupied else 0.0
	var bed := Rect2(rect.position+Vector2(0,rect.size.y*.48),Vector2(rect.size.x,rect.size.y*.52))
	MechanismRegionArt.panel(self,bed,Color(.72,.72,.72))
	var cap := Rect2(rect.position+Vector2(0,travel),Vector2(rect.size.x,maxf(1,rect.size.y*.45)))
	for ratio: float in [.17,.83]:
		var pivot := Vector2(rect.position.x+rect.size.x*ratio,rect.get_center().y+travel*.4)
		MechanismRegionArt.stamp(self,"mount",pivot,Vector2(minf(12,rect.size.x*.16),minf(10,rect.size.y)))
	MechanismRegionArt.panel(self,cap)
	var lamp := Color("8df5be") if occupied else Color("e9bd6c") if active else Color("777063")
	var cells := 4 if active else 1
	if active and not occupied and release_hold_s>0: cells = maxi(1,ceili(4*remaining/release_hold_s))
	var pitch := minf(3,rect.size.x/12)
	for i: int in cells:
		draw_rect(Rect2(rect.get_center().x+(i-1.5)*pitch,bed.get_center().y,maxf(1,pitch-1),2),lamp)
	if runtime == null: return
	for link: Dictionary in links:
		var node: Node2D = runtime.nodes.get(link.target)
		if node == null: continue
		var center := node.global_position
		if node.get("bounds") is Rect2: center = node.to_global(node.bounds.get_center())
		draw_dashed_line(Vector2.ZERO,to_local(center),Color("dd9a42") if sent_active != active or sent_occupied != occupied else Color("658c79"),1,6)
