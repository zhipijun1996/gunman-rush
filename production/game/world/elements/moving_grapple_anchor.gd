class_name MovingGrappleAnchor
extends GrappleAnchor

@export var endpoint := Vector2(192,0)
@export var route: Array[Vector2] = []
@export_enum("cycle","zipline","retract") var motion_mode := "cycle"
@export var period := 4.0
@export var endpoint_dwell := 0.20
@export var phase_offset := 0.0
@export var zipline_speed := 240.0
@export var return_speed := 160.0
@export var return_delay_s := 0.80
@export var retract_warning_s := 0.20
@export var retract_speed := 96.0
@export var retracted_length := 48.0
@export var initial_active := true
var path := CarrierRoute.new()
var origin := Vector2.ZERO
var distance := 0.0
var path_clock := 0.0
var time_scale := 1.0
var wait_left := 0.0
var running := true
var stage := "cycle"
var blocked := false

func _ready() -> void:
	path.configure(endpoint,route)
	origin = position
	running = initial_active
	path_clock = phase_offset
	if motion_mode == "cycle":
		position = origin + sample_path(path_clock)
	else:
		hang_enabled = true
		distance = endpoint.length() if motion_mode == "retract" else 0.0
		position = origin + endpoint.normalized()*distance
		stage = idle_stage()
	super._ready()
	# Bullets can enchant a moving head even during hook cooldown or occupied travel.
	var shot_zone := Area2D.new()
	shot_zone.collision_layer = TraversalMechanism.SHOT_ONLY_LAYER
	shot_zone.collision_mask = 0
	var shot_shape := CollisionShape2D.new()
	var capture := CircleShape2D.new()
	capture.radius = 12
	shot_shape.shape = capture
	shot_zone.add_child(shot_shape)
	add_child(shot_zone)
	process_physics_priority = -100

func idle_stage() -> String:
	return "extended_idle" if motion_mode == "retract" else "upper_idle"

func sample_path(at: float) -> Vector2:
	return path.cycle(at,period,endpoint_dwell)

func hook_begin(ability: TraversalAbility, token: String) -> bool:
	if not super.hook_begin(ability,token): return false
	if motion_mode != "cycle":
		stage = "boarding"
		wait_left = 0
	return true

func hook_arrive(token: String) -> void:
	super.hook_arrive(token)
	if not attached or motion_mode == "cycle": return
	if motion_mode == "zipline":
		stage = "riding_down"
	else:
		wait_left = retract_warning_s
		stage = "retract_warning" if wait_left > 0 else "retracting"
		if is_equal_approx(distance,retracted_length): stage = "retracted_hold"

func hook_end(token: String) -> void:
	if token != hook_session or token.is_empty(): return
	super.hook_end(token)
	begin_return()

func begin_return() -> void:
	if motion_mode == "cycle": return
	wait_left = return_delay_s
	stage = "return_wait"
	var home := endpoint.length() if motion_mode == "retract" else 0.0
	if is_equal_approx(distance,home): stage = idle_stage()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not running or time_scale <= 0: return
	var dt := delta*time_scale
	if motion_mode == "cycle":
		var next := origin+sample_path(path_clock+dt)
		blocked = not space_for_rider(next)
		if blocked:
			var lower := 0.0
			var upper := dt
			for subdivision: int in 10:
				var middle := (lower+upper)*.5
				if space_for_rider(origin+sample_path(path_clock+middle)): lower = middle
				else: upper = middle
			dt = lower
		path_clock += dt
		position = origin+sample_path(path_clock)
		queue_redraw()
		return
	if stage in ["return_wait","retract_warning"]:
		var consumed := minf(wait_left,dt)
		wait_left -= consumed
		dt -= consumed
		if wait_left > 0: return
		if stage == "retract_warning": stage = "retracting"
		else: stage = "extending" if motion_mode == "retract" else "returning"
	var target := distance
	var speed := return_speed
	match stage:
		"riding_down": target = endpoint.length(); speed = zipline_speed
		"retracting": target = retracted_length; speed = retract_speed
		"extending": target = endpoint.length()
		"returning": target = 0
		_: return
	var step := move_toward(distance,target,speed*dt)
	var next_position := origin+endpoint.normalized()*step
	blocked = not space_for_rider(next_position)
	if blocked:
		var contact := KinematicCollision2D.new()
		var motor := holder.controller.motor
		if motor.test_move(motor.global_transform,next_position-position,contact):
			step = move_toward(distance,step,contact.get_travel().length())
	position = origin+endpoint.normalized()*step
	distance = step
	queue_redraw()
	if distance == target:
		if stage == "riding_down": stage = "lower_hold"
		elif stage == "retracting": stage = "retracted_hold"
		else: stage = idle_stage()

func space_for_rider(next: Vector2) -> bool:
	if not attached or not is_instance_valid(holder) or position.is_equal_approx(next): return true
	return not holder.controller.motor.test_move(holder.controller.motor.global_transform,next-position)

func reset_attempt() -> void:
	super.reset_attempt()
	running = initial_active
	path_clock = phase_offset
	distance = endpoint.length() if motion_mode == "retract" else 0.0
	stage = "cycle" if motion_mode == "cycle" else idle_stage()
	wait_left = 0
	blocked = false
	position = origin + (sample_path(path_clock) if motion_mode == "cycle" else endpoint.normalized()*distance)
	queue_redraw()

func set_equipment_time(scale: float) -> void:
	time_scale = scale

func element_can_receive(input: String, _value: bool) -> bool:
	return input == "set_active"

func element_propose(_input: String, value: bool) -> Dictionary:
	var data := element_state()
	data.active = value
	return data

func element_state() -> Dictionary:
	return {"phase":stage,"active":running,"clock":path_clock,"distance":distance,"wait":wait_left,"blocked":blocked,"eligibility":eligibility_state()}

func element_restore(data: Dictionary) -> void:
	stage = data.phase
	running = data.active
	path_clock = data.clock
	distance = data.distance
	wait_left = data.wait
	blocked = data.blocked
	restore_eligibility(data.eligibility)
	position = origin + (sample_path(path_clock) if motion_mode == "cycle" else endpoint.normalized()*distance)
	if motion_mode != "cycle" and stage in ["boarding","riding_down","lower_hold","retract_warning","retracting","retracted_hold"] and hook_session.is_empty(): begin_return()
	queue_redraw()

func _draw() -> void:
	super._draw()
	var start := origin-position
	var points: Array[Vector2] = [start]
	if motion_mode == "cycle" and not route.is_empty():
		for point: Vector2 in route: points.append(start+point)
	else: points.append(start+endpoint)
	for i: int in range(1,points.size()): draw_dashed_line(points[i-1],points[i],Color("726345"),2,9)
	if motion_mode == "retract": draw_line(start,Vector2.ZERO,Color("699154") if stage!="retract_warning" else Color("edbd68"),4)
