class_name WorldRotatingBeam
extends MechanismSolid

@export var beam_length := 160.0
@export var beam_thickness := 20.0
@export var pivot_fraction := 0.5
@export_enum("step","continuous","indexed","load_tilt","contact_flip") var rotation_mode := "step"
@export var angles_deg: Array[float] = [0.0,90.0]
@export var initial_pose := 0
@export var warning_s := 0.20
@export var rotate_s := 0.35
@export_enum("clockwise","counterclockwise") var rotation_direction := "clockwise"
@export var angular_speed_deg := 45.0
@export var initial_angle_deg := 0.0
@export var initial_running := true
@export var rest_angle_deg := 0.0
@export var max_tilt_deg := 25.0
@export var tilt_speed_deg := 30.0
@export var return_speed_deg := 20.0
@export var balance_half_width := 12.0
@export var contact_delay_s := 0.60
@export var danger_hold_s := 1.50
@export var hazard_depth := 12.0
@export var drive_id := ""

var angle := 0.0
var start_angle := 0.0
var goal_angle := 0.0
var pose := 0
var requested_pose := 0
var stage := "idle"
var remaining := 0.0
var running := true
var scale_time := 1.0
var load_side := "empty"
var danger: DemoContactEmitter
var prior_angle := 0.0
var motion_clock := 0.0
var angle_owner: WorldRotatingBeam
var followers: Array[WorldRotatingBeam] = []

func _ready() -> void:
	pose = initial_pose
	requested_pose = pose
	running = initial_running
	match rotation_mode:
		"continuous": angle = initial_angle_deg
		"load_tilt": angle = rest_angle_deg
		"contact_flip":
			angle = 180.0*initial_pose
			stage = "safe" if initial_pose == 0 else "danger"
			remaining = danger_hold_s if initial_pose == 1 else 0.0
		_: angle = angles_deg[pose]
	make_solid(Vector2(beam_length,beam_thickness))
	place_angle(angle)
	shot_part(Vector2.ZERO, beam_thickness*0.5+6.0)

func center_offset() -> Vector2:
	return Vector2(beam_length*(0.5-pivot_fraction),0)

func place_angle(value: float) -> void:
	angle = value
	body.rotation = deg_to_rad(angle)
	body.position = center_offset().rotated(body.rotation)
	body.force_update_transform()
	queue_redraw()

func element_bind(context: Dictionary) -> void:
	super(context)
	angle_owner = runtime.nodes.get(drive_id) as WorldRotatingBeam
	if angle_owner != null:
		angle_owner.followers.append(self)
		place_angle(angle_owner.angle)
		read_owner_phase()
	if rotation_mode == "contact_flip":
		danger = make_hazard(Rect2())
		danger.contact_test_provider = _touches_spikes

func _touches_spikes(center: Vector2, previous: Vector2, actor: Vector2, half: Vector2) -> bool:
	var spikes := RectangleShape2D.new()
	spikes.size = Vector2(beam_length,hazard_depth)
	var player_rect := RectangleShape2D.new()
	player_rect.size = half*2
	var samples := maxi(1,ceili((absf(deg_to_rad(angle-prior_angle))*beam_length + (actor-center-previous).length())/3.0))
	for i: int in range(samples+1):
		var alpha := float(i)/samples
		var radians := deg_to_rad(lerpf(prior_angle,angle,alpha))
		var edge := center_offset()+Vector2.DOWN*(beam_thickness+hazard_depth)*0.5
		var at := global_transform*Transform2D(radians,edge.rotated(radians))
		var point := (previous+center).lerp(actor,alpha)
		if spikes.collide(at,player_rect,Transform2D(0,point)): return true
	return false

func set_equipment_time(value: float) -> void:
	scale_time = value

func rider_shift(point: Vector2, new_angle: float) -> Vector2:
	var local_point := to_local(point)
	return to_global(local_point.rotated(deg_to_rad(new_angle-angle)))-point

func can_rotate_to(value: float, transport := true) -> bool:
	if not is_inside_tree() or is_equal_approx(angle,value): return true
	for member: WorldRotatingBeam in followers:
		if not member.can_rotate_to(value,transport): return false
	var rider := rider_contact(true) if transport else {}
	var ignore: Array[RID] = [body.get_rid()]
	if not rider.is_empty(): ignore.append(controller.motor.get_rid())
	var shape := RectangleShape2D.new()
	shape.size = (rect_shape.size-Vector2.ONE*0.06).max(Vector2.ONE*0.001)
	# Sample proportional to the maximum swept tip distance; endpoints alone
	# miss a player standing between the horizontal and vertical poses.
	var steps := maxi(1,ceili(absf(deg_to_rad(value-angle))*beam_length/2))
	for i: int in range(1,steps+1):
		var next := lerpf(angle,value,float(i)/steps)
		var radians := deg_to_rad(next)
		var at := global_transform*Transform2D(radians,center_offset().rotated(radians))
		if not fits(shape,at,ignore): return false
		if not rider.is_empty() and not rider_fits(rider_shift(rider.point,next)): return false
	return true

func apply_driven_angle(value: float, transport := true) -> void:
	var contact := rider_contact(true) if transport else {}
	if not contact.is_empty(): move_rider(rider_shift(contact.point,value))
	place_angle(value)
	for member: WorldRotatingBeam in followers: member.apply_driven_angle(value,transport)
	blocked = false

func read_owner_phase() -> void:
	pose = angle_owner.pose
	requested_pose = angle_owner.requested_pose
	stage = angle_owner.stage
	remaining = angle_owner.remaining
	start_angle = angle_owner.start_angle
	goal_angle = angle_owner.goal_angle
	running = angle_owner.running
	blocked = angle_owner.blocked
	motion_clock = angle_owner.motion_clock
	queue_redraw()

func turn_towards(value: float, transport: bool) -> bool:
	blocked = not can_rotate_to(value,transport)
	if not blocked: apply_driven_angle(value,transport)
	queue_redraw()
	return not blocked

func load_direction(contact: Dictionary) -> String:
	if not contact.get("top",false): return "empty"
	var foot := player_shape().global_position+Vector2.DOWN*player_half().y
	var x := to_local(foot).rotated(-deg_to_rad(angle)).x
	if x >= balance_half_width: return "right"
	if x <= -balance_half_width: return "left"
	if load_side == "right" and x > balance_half_width*0.5: return "right"
	if load_side == "left" and x < -balance_half_width*0.5: return "left"
	return "center"

func _physics_process(delta: float) -> void:
	if controller == null or not lifetime.active: return
	prior_angle = angle
	if not drive_id.is_empty(): return
	var step := delta*scale_time
	var advancing := running if rotation_mode in ["continuous","load_tilt"] else stage not in ["idle","safe"]
	match rotation_mode:
		"continuous":
			if running: turn_towards(angle+step*angular_speed_deg*turn_sign(),true)
		"load_tilt":
			load_side = load_direction(rider_contact())
			if running and load_side != "center":
				var side := 1 if load_side == "right" else -1 if load_side == "left" else 0
				var speed := return_speed_deg if side == 0 else tilt_speed_deg
				turn_towards(move_toward(angle,rest_angle_deg+side*max_tilt_deg,speed*step),true)
		"contact_flip": update_flip(step)
		_: update_discrete(step)

	if advancing and not blocked: motion_clock += step
	for member: WorldRotatingBeam in followers: member.read_owner_phase()

func turn_sign() -> float:
	return 1.0 if rotation_direction == "clockwise" else -1.0

func update_discrete(delta: float) -> void:
	if stage == "warning":
		remaining = maxf(0,remaining-delta)
		if remaining > 0: return
		if not can_rotate_to(goal_angle,rotation_mode == "indexed"):
			blocked = true
			queue_redraw()
			return
		stage = "turning"
	if stage != "turning": return
	var next := move_toward(angle,goal_angle,absf(goal_angle-start_angle)*delta/rotate_s)
	if turn_towards(next,rotation_mode == "indexed") and is_equal_approx(next,goal_angle):
		pose = requested_pose
		stage = "idle"

func update_flip(delta: float) -> void:
	match stage:
		"safe":
			if rider_contact().get("top",false):
				stage = "warning"
				remaining = contact_delay_s
		"warning", "danger":
			remaining = maxf(0,remaining-delta)
			if remaining <= 0: stage = "flipping" if stage == "warning" else "returning"
		"flipping","returning":
			var target := 180.0 if stage == "flipping" else 0.0
			var next := move_toward(angle,target,180*delta/rotate_s)
			if turn_towards(next,true) and is_equal_approx(next,target):
				pose = 1 if target == 180 else 0
				stage = "danger" if pose == 1 else "safe"
				remaining = danger_hold_s if pose == 1 else 0.0
	queue_redraw()

func element_state() -> Dictionary:
	return {"angle":angle,"pose":pose,"target_pose":requested_pose,"phase":stage,"remaining":remaining,
		"clock":motion_clock,"start_angle":start_angle,"goal_angle":goal_angle,"running":running,"load":load_side,"blocked":blocked,
		"receipts":shot_receipts.duplicate()}

func element_can_receive(input: String,value: Variant) -> bool:
	if not drive_id.is_empty(): return false
	match rotation_mode:
		"continuous","load_tilt": return input == "set_active" and value is bool
		"step","indexed":
			if stage != "idle": return false
			return (input == "toggle" and value == null) or (input == "set_pose" and WorldRoomValidation.number(value) and value == floorf(value) and value >= 0 and value < angles_deg.size())
	return false

func element_propose(input: String,value: Variant) -> Dictionary:
	var data := element_state()
	if input == "set_active":
		data.running = value
		return data
	var index := (pose+1)%angles_deg.size() if input == "toggle" else int(value)
	if index == pose: return data
	data.target_pose = index
	data.start_angle = angle
	var target: float = angles_deg[index]
	if rotation_mode == "indexed":
		target = angle+turn_sign()*fposmod(turn_sign()*(target-angle),360)
	data.goal_angle = target
	data.phase = "warning"
	data.remaining = warning_s
	return data

func element_restore(data: Dictionary) -> void:
	place_angle(angle_owner.angle if angle_owner != null else float(data.angle))
	motion_clock = data.get("clock",0.0)
	pose = int(data.pose)
	requested_pose = int(data.target_pose)
	stage = str(data.phase)
	remaining = float(data.remaining)
	start_angle = float(data.start_angle)
	goal_angle = float(data.goal_angle)
	running = bool(data.running)
	load_side = str(data.load)
	blocked = bool(data.blocked)
	shot_receipts = data.get("receipts",{}).duplicate()
	if angle_owner != null: read_owner_phase()
	for member: WorldRotatingBeam in followers:
		member.place_angle(angle)
		member.read_owner_phase()

func mechanism_shot(context: Dictionary) -> bool:
	if not accept_shot(context): return false
	if angle_owner != null:
		var shared := context.duplicate()
		shared.collider = angle_owner.hit_part
		angle_owner.mechanism_shot(shared)
		return true
	if not drive_id.is_empty(): return true
	if rotation_mode == "contact_flip":
		if stage == "warning": stage = "safe"; remaining = 0
		elif stage in ["flipping","danger"]: stage = "returning"
	elif element_can_receive("toggle",null):
		element_restore(element_propose("toggle",null))
	queue_redraw()
	return true

func result_at_terminal(kind: String) -> bool:
	return kind == "lower_beam" and stage == "idle" and pose == 0

func install_terminal(kind: String) -> void:
	if kind != "lower_beam": return
	pose = 0
	requested_pose = 0
	remaining = 0
	stage = "idle"
	place_angle(angles_deg[0])

func _draw() -> void:
	draw_set_transform(Vector2.ZERO,deg_to_rad(angle))
	var rect := Rect2(Vector2(-pivot_fraction*beam_length,-beam_thickness/2),Vector2(beam_length,beam_thickness))
	draw_block(rect,Color("736249"),Color("d8bd83"))
	if rotation_mode == "contact_flip":
		var count := maxi(1,ceili(beam_length/12))
		for i: int in count:
			var x := rect.position.x+beam_length*i/count
			var w := beam_length/count
			draw_colored_polygon(PackedVector2Array([Vector2(x,rect.end.y),Vector2(x+w/2,rect.end.y+hazard_depth),Vector2(x+w,rect.end.y)]),Color("b99480"))
	draw_circle(Vector2.ZERO,beam_thickness*0.5+5,Color("392e2d"))
	draw_circle(Vector2.ZERO,beam_thickness*0.5,Color("ed9b57") if stage=="warning" or blocked else Color("b4ae88"))
	draw_line(Vector2.ZERO,Vector2(beam_thickness*0.48,0),Color("382b25"),2)
	if stage == "warning":
		var duration := contact_delay_s if rotation_mode == "contact_flip" else warning_s
		var progress := clampf(1.0-remaining/maxf(duration,0.001),0,1)
		var radius := beam_thickness*0.5+7
		draw_arc(Vector2.ZERO,radius,-PI/2,-PI/2+TAU*maxf(0.01,progress),24,Color("ffbd67"),2)
		if rotation_mode == "contact_flip":
			draw_line(rect.position+Vector2(0,2),Vector2(rect.position.x+rect.size.x*progress,rect.position.y+2),Color("e6a05a"),2)
