class_name WorldSequenceWave
extends Node2D

@export var element_id := ""
@export var section_id := "main"
@export_enum("attempt") var state_scope := "attempt"
@export var members_order: Array[String] = []
@export var warning_duration := 0.25
@export var deploy_duration := 0.25
@export var start_interval := 0.60
@export var hold_duration := 1.20
@export var retract_duration := 0.25
var runtime: WorldElementRuntime
var lifetime: DemoLifetime
var accepted := false
var running := false
var elapsed := 0.0
var blocked := false
var scale_time := 1.0
var motion_clock: float:
	get: return elapsed

func element_bind(context: Dictionary) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	runtime = context.runtime
	lifetime = context.lifetime
	process_physics_priority = -115
	install(elapsed)
func set_equipment_time(value: float) -> void: scale_time = value
func total_duration() -> float:
	return warning_duration+maxi(0,members_order.size()-1)*start_interval+deploy_duration+hold_duration+retract_duration
func fraction(at: float,index: int) -> float:
	var t := at-warning_duration-index*start_interval
	if t <= 0: return 0
	if t < deploy_duration: return t/deploy_duration
	t -= deploy_duration+hold_duration
	return 1.0-clampf(t/retract_duration,0,1)
func angles(at: float) -> Array[float]:
	var result: Array[float] = []
	for i: int in members_order.size():
		var beam: WorldRotatingBeam = runtime.nodes[members_order[i]]
		result.append(lerpf(beam.angles_deg[1],beam.angles_deg[0],fraction(at,i)))
	return result
func install(at: float) -> void:
	var values := angles(at)
	for i: int in members_order.size():
		var beam: WorldRotatingBeam = runtime.nodes[members_order[i]]
		beam.apply_driven_angle(values[i],false)
		beam.pose = 0 if is_equal_approx(values[i],beam.angles_deg[0]) else 1
	queue_redraw()
func hydrates_edge(input: String) -> bool:
	return input == "trigger"

func element_input_candidate(input: String,value: Variant,_initiator: String,hydrate: bool) -> Dictionary:
	if not element_can_receive(input,value): return {}
	if not hydrate: return element_propose(input,value)
	var data := element_state()
	data.accepted = value
	return data

func element_can_receive(input: String,value: Variant) -> bool:
	return input == "trigger" and value is bool and not running
func element_state() -> Dictionary:
	return {"accepted":accepted,"running":running,"elapsed":elapsed,"blocked":blocked}
func element_propose(_input: String,value: Variant) -> Dictionary:
	if value == accepted: return element_state()
	return {"accepted":value,"running":true,"elapsed":0.0,"blocked":false}
func element_restore(data: Dictionary) -> void:
	accepted = data.accepted
	running = data.running
	elapsed = data.elapsed
	blocked = data.blocked
	install(elapsed)
func _physics_process(delta: float) -> void:
	if not running or not lifetime.active: return
	var at := minf(total_duration(),elapsed+delta*scale_time)
	var values := angles(at)
	for i: int in members_order.size():
		var beam: WorldRotatingBeam = runtime.nodes[members_order[i]]
		if not beam.can_rotate_to(values[i],false):
			blocked = true
			queue_redraw()
			return
	blocked = false
	elapsed = at
	install(at)
	running = at < total_duration()
func _draw() -> void:
	BeamHardware.signal_dial(self,running,blocked,true)
	if runtime == null: return
	for i: int in members_order.size():
		var beam: WorldRotatingBeam = runtime.nodes[members_order[i]]
		var point := to_local(beam.global_position)
		draw_dashed_line(Vector2.ZERO,point,Color("82745d"),1,7)
		var lamp := point+Vector2(0,-beam.beam_thickness*.5-9)
		MechanismRegionArt.stamp(self,"lamp",lamp,Vector2(10,13),Color.WHITE if fraction(elapsed,i)>0 else Color("#868982"))
