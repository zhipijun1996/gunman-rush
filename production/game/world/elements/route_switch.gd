class_name WorldRouteSwitch
extends Node2D

@export var element_id := ""
@export var section_id := "main"
@export_enum("attempt") var state_scope := "attempt"
@export_enum("targets","synchronized_beams") var motion_mode := "targets"
@export var groups := {"A":[],"B":[]}
@export var target_bindings := {}
@export_enum("A","B") var initial_route := "A"
@export var warning_duration := 0.25
@export var turn_duration := 0.40
var runtime: WorldElementRuntime
var lifetime: DemoLifetime
var submit: Callable
var source_id := ""
var accepted := false
var requested := false
var phase := "idle"
var elapsed := 0.0
var clock := 0.0
var blocked := false
var scale_time := 1.0
var initialized := false
var motion_clock: float:
	get: return clock

func _ready() -> void:
	accepted = initial_route == "B"
	requested = accepted
func element_bind(context: Dictionary) -> void:
	runtime = context.runtime
	lifetime = context.lifetime
	submit = context.submit
	for ids: Array in groups.values():
		for id: String in ids: runtime.nodes[id].set_meta("coordinator_id",element_id)
	process_physics_priority = -115

func set_equipment_time(value: float) -> void: scale_time = value
func active_in(group: String,route: bool) -> bool: return (group == "B") == route

func binding(id: String) -> Dictionary:
	return target_bindings.get(id,target_bindings.get(id.get_file(),{"input":"set_active","active":true,"inactive":false}))

func target_values(route: bool) -> Array[Dictionary]:
	var decisions: Array[Dictionary] = []
	for key: String in groups:
		for id: String in groups[key]:
			var data := binding(id)
			var value: Variant = data.active if active_in(key,route) else data.inactive
			decisions.append({"node":runtime.nodes[id],"input":data.input,"value":value})
	return decisions

func safe_for_route(route: bool) -> bool:
	if motion_mode == "synchronized_beams": return sample_bridges(route,1.0,false)
	for decision: Dictionary in target_values(route):
		var target: Node = decision.node
		if not target.element_can_receive(decision.input,decision.value): return false
		if target is WorldRotatingBeam and decision.input == "set_pose" and target.pose != decision.value:
			var proposed: Dictionary = target.element_propose(decision.input,decision.value)
			if not target.can_rotate_to(proposed.goal_angle,target.rotation_mode == "indexed"): return false
	return true

func apply_targets(route: bool) -> void:
	for decision: Dictionary in target_values(route):
		decision.node.element_restore(decision.node.element_propose(decision.input,decision.value))

func sample_bridges(route: bool,ratio: float,apply: bool) -> bool:
	var candidate := {}
	for key: String in groups:
		for id: String in groups[key]:
			var beam: WorldRotatingBeam = runtime.nodes[id]
			var deployed := active_in(key,route)
			var start: float = beam.angles_deg[int(deployed)]
			var end: float = beam.angles_deg[int(not deployed)]
			var angle := lerpf(start,end,ratio)
			if not apply and not beam.can_rotate_to(angle,false): return false
			candidate[id] = angle
	if apply:
		for id: String in candidate:
			var beam: WorldRotatingBeam = runtime.nodes[id]
			beam.apply_driven_angle(candidate[id],false)
			if ratio >= 1.0: beam.pose = 0 if is_equal_approx(beam.angle,beam.angles_deg[0]) else 1
	return true

func holds_request(id: String) -> bool:
	return phase in ["warning","ready"] and source_id == id

func element_input_candidate(input: String,value: Variant,initiator: String,hydrate: bool) -> Dictionary:
	if input != "set_active" or not value is bool: return {}
	if hydrate:
		var data := element_state()
		data.requested = value
		data.accepted = value
		data.phase = "idle"
		data.elapsed = 0.0
		data.blocked = false
		return data
	if not source_id.is_empty() and initiator != source_id: return {}
	if phase == "idle" and value != accepted: source_id = initiator
	if not element_can_receive(input,value): return {}
	return element_propose(input,value)

func element_can_receive(input: String,value: Variant) -> bool:
	if input != "set_active" or not value is bool: return false
	if phase == "idle" and value == accepted: return true
	if phase == "idle":
		requested = value
		elapsed = 0
		phase = "warning"
		queue_redraw()
	return phase == "ready" and requested == value and safe_for_route(value)
func element_state() -> Dictionary:
	return {"requested":requested,"accepted":accepted,"phase":phase,"clock":clock,"elapsed":elapsed,"blocked":blocked}
func element_propose(_input: String,value: Variant) -> Dictionary:
	var data := element_state()
	if value != accepted:
		data.accepted = value
		data.phase = "executing"
		data.elapsed = 0.0
		data.blocked = false
	return data
func element_restore(data: Dictionary) -> void:
	var changed := accepted != bool(data.accepted)
	requested = data.requested
	accepted = data.accepted
	phase = data.phase
	if phase not in ["warning","ready"]: source_id = ""
	clock = data.clock
	elapsed = data.elapsed
	blocked = data.blocked
	if motion_mode == "synchronized_beams":
		var ratio := clampf(elapsed/turn_duration,0,1) if phase == "executing" else 1.0
		sample_bridges(accepted,ratio,true)
	elif changed or not initialized:
		apply_targets(accepted)
	initialized = true
	queue_redraw()

func _physics_process(delta: float) -> void:
	if runtime == null or not lifetime.active: return
	if not initialized:
		if safe_for_route(accepted): element_restore(element_state())
		else: return
	if holds_request(source_id) and not source_id.is_empty():
		var source: Node = runtime.nodes[source_id]
		var live: bool = (source.request_is_live() or source.expiration_pending) if source is WorldElementSwitch else source.can_commit()
		if not live:
			source_id = ""
			requested = accepted
			phase = "idle"
			blocked = false
			elapsed = 0
	if phase == "warning":
		var at := minf(warning_duration,elapsed+delta*scale_time)
		clock += at-elapsed
		elapsed = at
		if elapsed >= warning_duration: phase = "ready"
	if phase == "ready":
		blocked = not safe_for_route(requested)
		if not blocked and not source_id.is_empty(): submit.call(source_id)
	elif phase == "executing":
		if motion_mode == "synchronized_beams":
			var at := minf(turn_duration,elapsed+delta*scale_time)
			blocked = not sample_bridges(accepted,at/turn_duration,false)
			if not blocked:
				clock += at-elapsed
				elapsed = at
				sample_bridges(accepted,elapsed/turn_duration,true)
				if at >= turn_duration: phase = "idle"
		else:
			var complete := true
			for decision: Dictionary in target_values(accepted):
				if decision.node is WorldRotatingBeam and decision.node.stage != "idle": complete = false
			if complete: phase = "idle"
	queue_redraw()
func _draw() -> void:
	draw_circle(Vector2.ZERO,8,Color("e9ad5d") if phase != "idle" else Color("a8c19d"))
	if phase in ["warning","ready","executing"]:
		var progress := clampf(elapsed/maxf(warning_duration,0.001),0,1)
		if phase == "executing" and motion_mode == "synchronized_beams": progress = clampf(elapsed/turn_duration,0,1)
		draw_arc(Vector2.ZERO,12,-PI/2,-PI/2+TAU*maxf(.01,progress),24,Color("f2b166") if not blocked else Color("f08070"),2)
	if runtime == null: return
	for key: String in groups:
		for id: String in groups[key]:
			var target: Node2D = runtime.nodes[id]
			var at: Vector2 = target.to_global(target.bounds.get_center()) if target is WorldElementGate else target.global_position
			draw_dashed_line(Vector2.ZERO,to_local(at),Color("b9a174") if active_in(key,accepted) else Color("615a51"),1,7)
