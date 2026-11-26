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
	draw_rect(rect,Color("48483e"))
	var y := rect.position.y + (3 if occupied else 0)
	draw_rect(Rect2(rect.position.x,y,plate_size.x,minf(4,plate_size.y)),Color("d7bc85"))
	draw_rect(Rect2(-4,rect.end.y-3,8,3),Color("84dcc7") if active else Color("76624e"))
	if runtime == null: return
	for link: Dictionary in links:
		var node: Node2D = runtime.nodes.get(link.target)
		if node == null: continue
		var center := node.global_position
		if node.get("bounds") is Rect2: center = node.to_global(node.bounds.get_center())
		draw_dashed_line(Vector2.ZERO,to_local(center),Color("dd9a42") if sent_active != active or sent_occupied != occupied else Color("658c79"),1,6)
