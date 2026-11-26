class_name WorldCounterweight
extends CarrierDrive

@export var carrier_ids: Array[String] = []
@export var rest_progress := .5
@export var loaded_rate := .35
@export var return_rate := .15
@export var stroke := Vector2(192,192)
var progress := .5
var upper: Array[Vector2] = []
var blocked := false

func element_bind(context: Dictionary) -> void:
	super(context)
	progress = rest_progress
	if carrier_ids.size() != 2: return
	carriers.assign([context.runtime.nodes[carrier_ids[0]],context.runtime.nodes[carrier_ids[1]]])
	upper.assign([carriers[0].origin-Vector2.DOWN*stroke.x*rest_progress, carriers[1].origin-Vector2.DOWN*stroke.y*(1-rest_progress)])
	apply_targets(targets_at(progress),true)

func targets_at(p: float) -> Array[Vector2]:
	return [upper[0]+Vector2.DOWN*stroke.x*p, upper[1]+Vector2.DOWN*stroke.y*(1-p)]

func _physics_process(delta: float) -> void:
	if upper.size() != 2: return
	var a := carriers[0].carries_player()
	var b := carriers[1].carries_player()
	var next := progress
	var step := delta*equipment_time_scale
	if a != b: next = move_toward(progress,1.0 if a else 0.0,loaded_rate*step)
	elif not a: next = move_toward(progress,rest_progress,return_rate*step)
	blocked = not apply_targets(targets_at(next))
	if not blocked:
		progress = next
		motion_clock += step

func element_state() -> Dictionary:
	return {"progress":progress,"clock":motion_clock,"blocked":blocked}

func element_restore(data: Dictionary) -> void:
	progress = data.progress
	motion_clock = data.clock
	blocked = data.blocked
	if upper.size() == 2: apply_targets(targets_at(progress),true)

func _draw() -> void:
	preload("res://game/presentation/world/carrier_hardware.gd").counterweight(self,carriers,upper,progress,stroke)
