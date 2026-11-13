class_name WorldElementGear
extends Node2D
@export var element_id := ""
@export_enum("permanent", "attempt") var state_scope := "attempt"
@export var travel := Vector2.ZERO
@export var period := 4.8
@export var phase := 0.0
@export var drive_id := ""
var hazard: WorldGearObstacle
var active := true

func element_bind(context: Dictionary) -> void:
	hazard = WorldGearObstacle.new()
	hazard.definition = {"id":element_id,"point":[0,0],"travel":[travel.x,travel.y],"period":period,"phase":phase}
	hazard.controller = context.controller; hazard.policy = context.policy
	hazard.source_room_id = str(context.room.room_id)
	add_child(hazard)
	if not drive_id.is_empty(): hazard.clock_source = context.runtime.nodes[drive_id]

func element_state() -> Dictionary:
	return {"active":active,"clock":hazard.clock}

func element_can_receive(input: String, _value: bool) -> bool:
	return input == "set_active" and drive_id.is_empty()

func element_propose(_input: String, value: bool) -> Dictionary:
	var data := element_state(); data.active = value; return data

func element_restore(data: Dictionary) -> void:
	active = bool(data.active); hazard.clock = float(data.clock); hazard.motion_running = active
	hazard.refresh_position()
