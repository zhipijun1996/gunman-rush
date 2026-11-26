class_name WorldDandelionPlatform
extends WorldCarrierSurface

@export var endpoint := Vector2(160,0)
@export var route: Array[Vector2] = []
@export var period := 8.0
@export var endpoint_dwell := .30
@export var phase_offset := 0.0

@export var sink_speed := 24.0
@export var rise_speed := 32.0
@export var max_sink := 96.0
var sink := 0.0
var path := CarrierRoute.new()
var motion_clock := 0.0

func _ready() -> void:
	super()
	path.configure(endpoint,route)
	reset_attempt()

func sample_position(clock: float) -> Vector2:
	return origin+path.cycle(clock,period,endpoint_dwell)

func _physics_process(delta: float) -> void:
	var step := delta*equipment_time_scale
	var loaded := carries_player()
	var next_clock := motion_clock+step
	var next_sink := move_toward(sink,max_sink if loaded else 0.0,(sink_speed if loaded else rise_speed)*step)
	var next := sample_position(next_clock)+Vector2.DOWN*next_sink
	if safe_fraction(next) < 1.0: return
	motion_clock = next_clock
	sink = next_sink
	position = next

func reset_attempt() -> void:
	equipment_time_scale = 1.0
	element_restore({"clock":phase_offset,"sink":0.0})

func element_state() -> Dictionary:
	return {"clock":motion_clock,"sink":sink}

func element_restore(data: Dictionary) -> void:
	motion_clock = data.clock
	sink = data.sink
	jump_to(sample_position(motion_clock)+Vector2.DOWN*sink)

func _draw() -> void:
	var half := platform_size.x*.5
	var color := Color("e8d9ae")
	draw_line(Vector2(-half,-platform_size.y*.5),Vector2(half,-platform_size.y*.5),color,3)
	for i: int in 9:
		var tip := Vector2(lerpf(-half,half,i/8.0),-platform_size.y*.5)
		draw_line(Vector2(0,platform_size.y*.4),tip,Color("bcae85"),2)
		draw_circle(tip,4,color)
	draw_line(Vector2(0,platform_size.y*.4),Vector2(2,platform_size.y),Color("948661"),3)
