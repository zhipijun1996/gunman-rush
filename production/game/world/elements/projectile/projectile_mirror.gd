class_name ProjectileMirror
extends ProjectileField
@export var element_id := ""
@export var state_scope := "attempt"
@export var section_id := "main"
@export var mirror_length := 128.0
@export_enum("fixed","indexed") var orientation_mode := "fixed"
@export var normal_deg := 0.0
@export var normal_angles_deg: Array[float] = [0,45,90,135]
@export var initial_index := 0
@export var turn_s := 0.35
@export var control_offset := Vector2(0,-88)
@export var control_radius := 10.0
@export var two_sided := false
var angle := 0.0
var index := 0
var target := 0
var start := 0.0
var progress := 1.0
var last_frame := -1
var frame_start := 0.0
var frame_span := 0.0
var frame_turn_end := 1.0
var frame_turn_start := 0.0
var receipts := {}
var prior_turns: Array[Dictionary] = []

func _ready() -> void:
	index = initial_index
	target = index
	angle = deg_to_rad(normal_deg if orientation_mode == "fixed" else normal_angles_deg[index])
	start = angle
	frame_start = angle
	process_physics_priority = -180
	if orientation_mode=="indexed": ProjectileTurnOrder.install(domain)

func arc() -> float:
	var difference := angle_difference(start,deg_to_rad(normal_angles_deg[target]))
	return PI if is_equal_approx(absf(difference),PI) else difference

func _physics_process(delta: float) -> void:
	prior_turns.clear()
	frame_start = angle
	frame_turn_start = 0.0
	frame_turn_end = 1.0
	frame_span = 0
	last_frame = Engine.get_physics_frames()
	turn_step(delta)

func turn_step(delta: float) -> void:
	if progress >= 1 or delta <= 0: return
	frame_turn_end = minf(1,frame_turn_start+(1-progress)*turn_s/get_physics_process_delta_time())
	progress = minf(1,progress+delta/turn_s)
	angle = start + arc()*progress
	frame_span = angle-frame_start
	if progress>=1: index = target
	queue_redraw()

func normal_at(fraction: float) -> Vector2:
	for previous: Dictionary in prior_turns:
		if fraction < previous.until:
			var progress_at := clampf((fraction-float(previous.begin))/maxf(.0000001,float(previous.end)-float(previous.begin)),0,1)
			return Vector2.from_angle(float(previous.angle)+float(previous.span)*progress_at+global_rotation)
	var t := clampf((fraction-frame_turn_start)/maxf(0.0000001,frame_turn_end-frame_turn_start),0,1)
	return Vector2.from_angle(frame_start+frame_span*t+global_rotation)

func command_turn(packet: Dictionary) -> void:
	var id: String = packet.get("packet_id","")
	if orientation_mode != "indexed" or id.is_empty() or receipts.has(id): return
	receipts[id] = true
	var fraction := clampf(packet.get("hit_fraction",1.0),0,1)
	if progress < 1: return
	if last_frame==Engine.get_physics_frames() and not is_zero_approx(frame_span):
		if fraction < frame_turn_end: return
		prior_turns.append({"until":fraction,"begin":frame_turn_start,"end":frame_turn_end,"angle":frame_start,"span":frame_span})
	start = angle
	target = (index+1)%normal_angles_deg.size()
	progress = 0
	if last_frame == Engine.get_physics_frames():
		frame_turn_start = fraction
		frame_start = angle
		turn_step(get_physics_process_delta_time()*(1-frame_turn_start))
	queue_redraw()

func cancel_pending() -> void:
	receipts.clear()
	prior_turns.clear()

func element_state() -> Dictionary:
	return {"angle":angle,"index":index,"target":target,"start":start,"progress":progress}
func element_can_receive(input: String, value: Variant) -> bool:
	return input=="set_index" and orientation_mode=="indexed" and progress>=1 and WorldRoomValidation.number(value) and int(value)==value and value>=0 and value<normal_angles_deg.size()
func element_propose(_input: String, value: Variant) -> Dictionary:
	var data := element_state()
	if value!=index:
		data.start = angle
		data.target = value
		data.progress = 0.0
	return data
func element_restore(data: Dictionary) -> void:
	angle = data.angle
	start = data.start
	index = int(data.index)
	target = int(data.target)
	progress = data.progress
	frame_start = angle
	frame_span = 0
	queue_redraw()

func contact(at: Vector2, motion: Vector2, radius: float, _faction: String, elapsed: float, step: float, delta: float) -> Dictionary:
	var result := {}
	if orientation_mode=="indexed":
		var button := to_global(control_offset)
		var t := 0.0 if at.distance_to(button)<=control_radius+radius else Geometry2D.segment_intersects_circle(at,at+motion,button,control_radius+radius) if motion.length_squared()>0 else -1.0
		if t>=0: result = {"kind":"button","priority":1,"t":t}
	var root := global_position
	var f0 := elapsed/maxf(delta,0.00000001)
	var duration := step/maxf(delta,0.00000001)
	var relative_bound := motion.length()+absf(frame_span)*duration/maxf(0.000001,frame_turn_end-frame_turn_start)*mirror_length/2
	for previous: Dictionary in prior_turns:
		relative_bound = maxf(relative_bound,motion.length()+absf(previous.span)*duration/maxf(.000001,float(previous.end)-float(previous.begin))*mirror_length/2)
	var t := 0.0
	# Distance to a rotating finite segment is Lipschitz-bounded by translation plus tip speed.
	# Conservative advancement cannot skip a sweep, even when both endpoint tests are clear.
	for iteration in 192:
		var n := normal_at(f0+duration*t)
		var tangent := n.orthogonal()
		var p := at+motion*t-root
		var nearest := tangent*clampf(p.dot(tangent),-mirror_length/2,mirror_length/2)
		var distance := p.distance_to(nearest)-radius
		if distance <= 0.0001:
			if not result.is_empty() and result.t <= t+0.000001: return result
			var front := p.dot(n)>=0
			if not front: n = -n
			if absf(motion.dot(n)) < 0.00001 and is_zero_approx(frame_span): return result
			return {"kind":"mirror","t":t,"priority":2,"normal":n,"reflect":(two_sided or front) and motion.dot(n)<0}
		if relative_bound<=0.0000001: break
		t += distance/relative_bound
		if t>1.0 or (not result.is_empty() and result.t < t): break
	return result

func _draw() -> void:
	var n := Vector2.from_angle(angle)
	var edge := n.orthogonal()*mirror_length/2
	draw_line(-edge,edge,Color("38546b"),5)
	draw_line(-edge+n*2,edge+n*2,Color("c5eff5"),2)
	if two_sided: draw_line(-edge-n*2,edge-n*2,Color("c5eff5"),2)
	if orientation_mode=="indexed":
		draw_line(Vector2.ZERO,control_offset,Color("626c72"),2)
		draw_circle(control_offset,control_radius,Color("39474c"))
		draw_arc(control_offset,control_radius,0,TAU,24,Color("e7c875"),2)
		for i: int in normal_angles_deg.size():
			var notch := Vector2.from_angle(deg_to_rad(normal_angles_deg[i]))
			draw_line(control_offset+notch*(control_radius-3),control_offset+notch*(control_radius+3),Color.WHITE if i==target else Color("848483"),2)
