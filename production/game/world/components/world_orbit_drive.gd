class_name WorldOrbitDrive
extends CarrierDrive

@export var carrier_ids: Dictionary = {}
@export var radius := 160.0
@export var angle_offsets_deg: Dictionary = {}
@export var period := 8.0
@export var initial_angle_deg := 0.0
@export_enum("clockwise","counterclockwise") var direction := "clockwise"
@export var initial_running := false

func element_bind(context: Dictionary) -> void:
	super(context)
	motion_running = initial_running
	apply_targets(targets_at(motion_clock),true)

func targets_at(clock: float) -> Array[Vector2]:
	var targets: Array[Vector2] = []
	var root_angle := initial_angle_deg + clock*360.0/period*(1 if direction == "clockwise" else -1)
	for carrier in carriers:
		var angle := root_angle+float(angle_offsets_deg[carrier_ids.find_key(carrier.element_id)])
		targets.append(position+Vector2.from_angle(deg_to_rad(angle))*radius)
	return targets

func _physics_process(delta: float) -> void:
	if not motion_running: return
	var next := motion_clock+delta*equipment_time_scale
	if apply_targets(targets_at(next)): motion_clock = next

func element_state() -> Dictionary:
	return {"clock":motion_clock,"active":motion_running}

func element_can_receive(input: String,value: Variant) -> bool:
	return input == "set_active" and value is bool

func element_propose(_input: String,value: bool) -> Dictionary:
	return {"clock":motion_clock,"active":value}

func element_restore(data: Dictionary) -> void:
	motion_clock = data.clock
	motion_running = data.active
	apply_targets(targets_at(motion_clock),true)

func _draw() -> void:
	for carrier in carriers:
		draw_line(Vector2.ZERO,to_local(carrier.global_position),Color("645747"),4)
	draw_circle(Vector2.ZERO,14,Color("9f8659"))
