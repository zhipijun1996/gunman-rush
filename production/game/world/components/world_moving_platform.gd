class_name WorldMovingPlatform
extends WorldCarrierSurface
## Owns one collision surface. A driver may own its pose, never a second clock.
const HARDWARE := preload("res://game/presentation/world/carrier_hardware.gd")

@export var endpoint := Vector2(384,0)
@export var period := 5.0
@export var phase_offset := 0.0
@export var activation_flag := ""
@export var route: Array[Vector2] = []
@export var endpoint_dwell := 0.0
@export_enum("cycle","call_dock","manual_cart","follow_water") var motion_mode := "cycle"
@export var initial_running := true
@export var initial_dock := 0
@export var call_points: Array[Vector2] = [Vector2(-96,0),Vector2(480,0)]
@export var call_radius := 60.0
@export var cart_max_speed := 160.0
@export var cart_acceleration := 320.0
@export var cart_deceleration := 400.0
@export var initial_path_progress := 0.0
@export var water_source_id := ""
@export var draft_offset := 0.0
@export var drive_id := ""

var path := CarrierRoute.new()
var motion_clock := 0.0
var motion_running := true
var activation_state: FixedWorldState
var activation_enabled := true
var bell_controlled := false
var driver: Node
var water: Node
var dock_progress := 0.0
var target_dock := 0
var cart_distance := 0.0
var cart_speed := 0.0

func _ready() -> void:
	super()
	path.configure(endpoint,route)
	activation_enabled = activation_flag.is_empty()
	visible = activation_enabled
	collision_layer = 1 if activation_enabled else 0
	if drive_id.is_empty() and motion_mode in ["cycle","call_dock","manual_cart"] and (not route.is_empty() or motion_mode != "cycle"):
		var rail := HARDWARE.Track.new()
		rail.points = path.points
		if motion_mode == "call_dock": rail.call_points = call_points
		rail.z_index = -3
		add_child(rail)
		rail.top_level = true
		rail.global_position = global_position
	reset_motion()

func _draw() -> void:
	if motion_mode == "manual_cart": HARDWARE.bogie(self,platform_size,cart_distance)
	super()
	if not drive_id.is_empty(): HARDWARE.deck_pin(self,platform_size)
	if motion_mode != "manual_cart" or path.points.is_empty(): return
	var distance := maxf(cart_distance-1,0)
	var forward := path.sample(minf(distance+2,path.length),false)-path.sample(distance,false)
	if forward.is_zero_approx(): return
	forward = forward.normalized()
	if cart_speed < 0: forward = -forward
	var anchor := Vector2(0,-platform_size.y*.5-6)
	var side := forward.orthogonal()*4
	draw_line(anchor-forward*7,anchor+forward*7,Color("d4ae69"),2)
	draw_polyline(PackedVector2Array([anchor+side,anchor+forward*7,anchor-side]),Color("e4c485"),2)


func reset_motion() -> void:
	motion_running = initial_running
	motion_clock = phase_offset
	dock_progress = float(initial_dock)
	target_dock = initial_dock
	cart_distance = path.length * initial_path_progress
	cart_speed = 0.0
	end_driving()
	if drive_id.is_empty() and not position.is_equal_approx(initial_position()): jump_to(initial_position())

func initial_position() -> Vector2:
	match motion_mode:
		"manual_cart": return path_position(cart_distance, false)
		"call_dock": return path_position(dock_progress * path.length, true)
		"follow_water":
			if is_instance_valid(water): return Vector2(origin.x, water.actual_surface_y + draft_offset)
	return sample_position(motion_clock) if motion_mode == "cycle" else origin

func bind_activation(value: FixedWorldState) -> void:
	if activation_flag.is_empty(): return
	activation_state = value
	value.committed.connect(_refresh_activation)
	_refresh_activation(value.revision)

func _refresh_activation(_revision: int) -> void:
	var enabled := activation_state.has(activation_flag)
	if enabled == activation_enabled: return
	if enabled:
		reset_motion()
		if not safe_to_appear(): return
	activation_enabled = enabled
	visible = enabled
	set_deferred("collision_layer", 1 if enabled else 0)

func _physics_process(delta: float) -> void:
	if not activation_enabled:
		if activation_state != null and activation_state.has(activation_flag): _refresh_activation(activation_state.revision)
		return
	if not drive_id.is_empty(): return
	match motion_mode:
		"manual_cart": step_cart(delta)
		"follow_water":
			if not is_instance_valid(water): return
			var target := Vector2(origin.x,water.actual_surface_y + draft_offset)
			var next := position.move_toward(target,water.surface_speed * delta)
			position = position.lerp(next,safe_fraction(next))
		"call_dock":
			if not motion_running: return
			var next_progress := move_toward(dock_progress,float(target_dock),2.0*delta*equipment_time_scale/period)
			var next := path_position(next_progress*path.length,true)
			if safe_fraction(next) >= 1:
				dock_progress = next_progress
				motion_clock += delta*equipment_time_scale
				position = next
		"cycle":
			if not motion_running: return
			var next_clock := motion_clock + delta * equipment_time_scale
			var next := sample_position(next_clock)
			if safe_fraction(next) >= 1:
				motion_clock = next_clock
				position = next

func sample_position(clock: float) -> Vector2:
	return origin+path.cycle(clock,period,endpoint_dwell)

func path_position(distance: float,smooth: bool) -> Vector2:
	return origin+path.sample(distance,smooth)

func step_cart(delta: float) -> void:
	if is_instance_valid(controller) and controller.driven_cart == self:
		if not motion_running or not carries_player() or controller.traversal.busy(): end_driving()
	var axis := controller.router.sample_axes() if is_instance_valid(controller) and controller.driven_cart == self else 0.0
	var desired := axis*cart_max_speed
	var distance := 0.0
	if cart_speed*desired < 0.0:
		var braking := minf(delta,absf(cart_speed)/cart_deceleration)
		var speed := move_toward(cart_speed,0,cart_deceleration*braking)
		distance = (cart_speed+speed)*.5*braking
		cart_speed = speed
		delta -= braking
	var rate := cart_acceleration if absf(desired)>absf(cart_speed) else cart_deceleration
	var ramp := minf(delta,absf(desired-cart_speed)/rate)
	var next_speed := move_toward(cart_speed,desired,rate*ramp)
	distance += .5*(next_speed+cart_speed)*ramp + next_speed*(delta-ramp)
	cart_speed = next_speed
	var next_distance := clampf(cart_distance+distance,0.0,path.length)
	# Traverse the polyline segment by segment, including corners crossed in one tick.
	var stops: Array[float] = []
	var cumulative := 0.0
	var previous := Vector2.ZERO
	for point in path.points:
		cumulative += previous.distance_to(point)
		if cumulative > minf(cart_distance,next_distance) and cumulative < maxf(cart_distance,next_distance): stops.append(cumulative)
		previous = point
	if next_distance < cart_distance: stops.reverse()
	stops.append(next_distance)
	var at := position
	for stop in stops:
		var next := path_position(stop,false)
		var fraction := sweep_fraction(at,next)
		cart_distance = lerpf(cart_distance,stop,fraction)
		at = path_position(cart_distance,false)
		if fraction < 1.0:
			cart_speed = 0
			break
	position = at
	if not is_zero_approx(distance): queue_redraw()
	if (cart_distance <= 0 and cart_speed < 0) or (cart_distance >= path.length and cart_speed > 0): cart_speed = 0

func end_driving() -> void:
	if is_instance_valid(controller) and controller.driven_cart == self: controller.driven_cart = null

func interact() -> bool:
	if not activation_enabled or not motion_running or not drive_id.is_empty(): return false
	if motion_mode == "manual_cart" and carries_player():
		controller.driven_cart = null if controller.driven_cart == self else self
		return true
	if motion_mode == "call_dock":
		var dock := -1
		if carries_player(): dock = 1-target_dock
		else:
			for i: int in call_points.size():
				if controller.motor.position.distance_to(origin+call_points[i]) <= call_radius: dock = i
		if dock >= 0:
			if is_equal_approx(dock_progress,float(target_dock)): target_dock = dock
			return true
	return false

func set_equipment_time(value: float) -> void:
	if is_instance_valid(driver): driver.set_equipment_time(value)
	elif motion_mode in ["cycle","call_dock"]: equipment_time_scale = value

func set_motion_running(value: bool) -> void:
	motion_running = value
	if not value: end_driving()

func bind_bell_control() -> void:
	bell_controlled = true
	motion_running = false

func restore_motion(clock: float, running: bool) -> void:
	motion_clock = clock
	set_motion_running(running)
	if drive_id.is_empty() and not position.is_equal_approx(initial_position()): jump_to(initial_position())

func element_bind(context: Dictionary) -> void:
	super(context)
	driver = context.runtime.nodes.get(drive_id)
	water = context.runtime.nodes.get(water_source_id)
	if motion_mode == "follow_water" and water != null: jump_to(initial_position())
	controller.motor.repositioned.connect(end_driving)

func reset_attempt() -> void:
	equipment_time_scale = 1.0
	reset_motion()
	if motion_mode == "follow_water" and water != null:
		var initial: float = water.high_surface_y if water.initial_level == "high" else water.low_surface_y
		jump_to(Vector2(origin.x,water.bounds.position.y+initial+draft_offset))

func element_state() -> Dictionary:
	var data := {"active":motion_running,"clock":motion_clock}
	match motion_mode:
		"manual_cart": data.merge({"distance":cart_distance,"speed":cart_speed})
		"call_dock": data.merge({"progress":dock_progress,"dock":target_dock})
		"follow_water": data["height"] = position.y
	return data

func element_can_receive(input: String, value: Variant) -> bool:
	if not drive_id.is_empty() or motion_mode == "follow_water": return false
	if input == "call_dock":
		return motion_mode == "call_dock" and motion_running and value in [0,1,0.0,1.0]
	return input == "set_active" and value is bool

func element_propose(input: String, value: Variant) -> Dictionary:
	var data := element_state()
	if input == "call_dock":
		if is_equal_approx(dock_progress,float(target_dock)): data.dock = int(value)
	else: data.active = value
	return data

func element_restore(data: Dictionary) -> void:
	dock_progress = float(data.get("progress",dock_progress))
	target_dock = int(data.get("dock",target_dock))
	cart_distance = float(data.get("distance",cart_distance))
	cart_speed = float(data.get("speed",cart_speed))
	restore_motion(float(data.clock),bool(data.active))
	if data.has("height"): jump_to(Vector2(origin.x,data.height))
