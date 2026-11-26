@tool
class_name WorldLocalLight
extends Node2D
@export var element_id := ""
@export var section_id := "main"
@export var state_scope := "attempt"
@export var light_radius := 160.0
@export var brightness := 1.0
@export var edge_falloff := 0.35
@export var initial_active := true
@export_enum("fixed","guide") var light_mode := "fixed"
@export var endpoint := Vector2(320,0)
@export var route: Array[Vector2] = []
@export var move_speed := 80.0
@export var waypoint_dwell_s := 0.40
@export_enum("return","dock") var end_behavior := "return"
@export var cocoon_radius := 12.0
var active := true
var phase := "home"
var path := PackedVector2Array()
var current := Vector2.ZERO
var destination := 0
var direction := 1
var wait_left := 0.0
var receipts := {}
var network: WorldLightNetwork

static func validate_configuration(p: Dictionary,_row: Dictionary,_doc: Dictionary) -> String:
	if p.light_radius <= 0 or p.brightness > 1 or p.edge_falloff > 1: return "light_radius/brightness/edge_falloff:out_of_range"
	if p.light_mode == "guide":
		if p.move_speed <= 0 or p.cocoon_radius <= 0: return "move_speed/cocoon_radius:positive_required"
		var track := WorldLightNetwork.possible_track(p)
		for i: int in range(1,track.size()):
			if track[i] == track[i-1]: return "route:zero_length_segment"
	return ""

func element_bind(context: Dictionary) -> void:
	active = initial_active
	network = WorldLightNetwork.of(context.room)
	network.controller = context.controller
	network.register_light_object(element_id,self,network.lamps)
	path = PackedVector2Array([Vector2.ZERO])
	if route.is_empty(): path.append(endpoint)
	else: path.append_array(route)
	if light_mode == "guide":
		var body := StaticBody2D.new()
		body.collision_layer = 8; body.collision_mask = 0
		var shape := CircleShape2D.new(); shape.radius = cocoon_radius
		var collision := CollisionShape2D.new(); collision.shape = shape
		body.add_child(collision); add_child(body)
	queue_redraw()

func light_center() -> Vector2: return to_global(current)
func mechanism_shot(context: Dictionary) -> bool:
	var id := str(context.get("packet_id",""))
	if light_mode != "guide" or not active or phase != "home" or id == "" or receipts.has(id): return false
	receipts[id] = true
	direction = 1; destination = 1; phase = "outbound"
	queue_redraw()
	return true

func advance_light(delta: float) -> void:
	if not active or phase == "home" or phase == "docked": return
	while delta > 0:
		if phase == "waypoint_wait":
			var used := minf(delta,wait_left)
			delta -= used; wait_left -= used
			if wait_left > 0: break
			if destination == path.size()-1:
				if end_behavior == "dock":
					phase = "docked"
					break
				direction = -1
			destination += direction
			phase = "outbound" if direction == 1 else "returning"
		else:
			var next := path[destination]
			var travel_s := current.distance_to(next)/move_speed
			if delta < travel_s:
				current = current.move_toward(next,delta*move_speed)
				break
			current = next
			delta -= travel_s
			if destination == 0:
				phase = "home"
				break
			wait_left = waypoint_dwell_s
			phase = "waypoint_wait"
	queue_redraw()

func reset_attempt() -> void:
	receipts.clear()
	active = initial_active
	phase = "home"
	current = Vector2.ZERO
	destination = 0
	direction = 1
	wait_left = 0.0
	queue_redraw()

func element_state() -> Dictionary:
	return {"active":active,"phase":phase,"current":[current.x,current.y],"destination":destination,"direction":direction,"wait_left":wait_left}
func element_can_receive(input: String,_value: bool) -> bool: return input == "set_active"
func element_propose(_input: String,value: bool) -> Dictionary:
	var result := element_state(); result.active = value; return result
func element_restore(data: Dictionary) -> void:
	active = data.active; phase = data.phase; current = FixedWorldProvider.point(data.current)
	destination = int(data.destination); direction = int(data.direction); wait_left = data.wait_left
	queue_redraw()

func _draw() -> void:
	var gold := Color("f5db8b") if active else Color("666858")
	if light_mode == "guide":
		draw_circle(Vector2.ZERO,cocoon_radius,Color("524d3d"))
		draw_arc(Vector2.ZERO,cocoon_radius,-2.7,2.7,18,Color("a58a58"),2)
		draw_line(Vector2(-cocoon_radius*0.65,3),Vector2(cocoon_radius*0.7,-3),gold,2)
		if Engine.is_editor_hint():
			var previous := Vector2.ZERO
			var route_points: Array = [endpoint] if route.is_empty() else route
			for point: Vector2 in route_points:
				draw_dashed_line(previous,point,Color("9d9272"),1,6)
				previous = point
	else:
		draw_rect(Rect2(-4,6,8,15),Color("69604c"))
		draw_rect(Rect2(-10,19,20,4),Color("766a53"))
	if active:
		draw_circle(current,16,Color(gold,0.12*brightness))
		draw_circle(current,9,Color(gold,0.25*brightness))
	draw_rect(Rect2(current-Vector2(3,4),Vector2(6,8)),gold)
	if Engine.is_editor_hint(): draw_arc(current,light_radius,0,TAU,64,Color(gold,0.35),1)
