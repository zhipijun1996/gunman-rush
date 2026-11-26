class_name CarrierDrive
extends Node2D
## All members either advance to the same accepted phase or wait together.
@export var element_id := ""
@export_enum("attempt") var state_scope := "attempt"
@export var section_id := "main"
var carriers: Array[WorldMovingPlatform] = []
var motion_clock := 0.0
var equipment_time_scale := 1.0
var motion_running := true

func element_bind(context: Dictionary) -> void:
	process_physics_priority = -110
	for node: Node in context.runtime.nodes.values():
		if node is WorldMovingPlatform and node.drive_id == element_id:
			carriers.append(node)
	carriers.sort_custom(func(a: Node,b: Node): return str(a.element_id) < str(b.element_id))
	queue_redraw()

func apply_targets(targets: Array[Vector2], initialize := false) -> bool:
	for i: int in carriers.size():
		if not initialize and carriers[i].safe_fraction(targets[i]) < 1.0: return false
	for i: int in carriers.size():
		if initialize: carriers[i].jump_to(targets[i])
		else: carriers[i].position = targets[i]
	queue_redraw()
	return true

func set_equipment_time(scale: float) -> void:
	equipment_time_scale = scale

func cancel_pending() -> void:
	equipment_time_scale = 1.0
