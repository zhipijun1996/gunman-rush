class_name WorldDandelionPlatform
extends WorldCarrierSurface

const CANOPY := preload("res://assets/mechanisms/carriers/dandelion_canopy.png")

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
	queue_redraw()

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
	var top := -platform_size.y*.5
	var width := platform_size.x
	var x := -width*.5
	# Pappus marks the support plane. Regional growth and weighted seeds
	# hang below it; only the underside bows as the platform takes weight.
	var pressure := clampf(sink/max_sink,0,1)
	var roots := maxi(1,ceili(width/25.0))
	for i in roots:
		var root_x := x+(i+.5)*width/roots
		var drop := sin(PI*(i+.5)/roots)*(3+pressure*3)
		MechanismRegionArt.stamp(self,"finial",Vector2(root_x,top+11+drop),Vector2(minf(34,width/roots+4),14),Color("#b7b599"))
	var height := minf(27,platform_size.y+4)
	var cap := minf(15,width*.5)
	var tint := Color.WHITE.lerp(MechanismRegionArt.accent(self),.13)
	draw_texture_rect_region(CANOPY,Rect2(x,top,cap,height),Rect2(0,0,cap,27),tint)
	var middle := width-2*cap
	var cursor := 0.0
	while cursor<middle:
		var span := minf(110,middle-cursor)
		draw_texture_rect_region(CANOPY,Rect2(x+cap+cursor,top,span,height),Rect2(17,0,span,27),tint)
		cursor+=span
	draw_texture_rect_region(CANOPY,Rect2(x+width-cap,top,cap,height),Rect2(144-cap,0,cap,27),tint)
