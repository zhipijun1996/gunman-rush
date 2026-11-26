class_name WorldShotRail
extends WorldCarrierSurface

@export var stations: Array[Vector2] = [Vector2.ZERO,Vector2(192,0),Vector2(384,0)]
@export var start_station := 0
@export var move_speed := 160.0
@export var settle_s := 0.10
@export var direction_dot_min := 0.50
var station := 0
var destination := 0
var moving_progress := 0.0
var settle_remaining := 0.0
var hit_packets: Dictionary = {}
var impact_face: Area2D
var flash_left := 0.0

func _ready() -> void:
	super()
	station = start_station
	destination = station
	jump_to(origin+stations[station])
	for side: int in [-1,1]:
		var face := Area2D.new()
		face.name = "ImpulseFaceLeft" if side < 0 else "ImpulseFaceRight"
		face.set_meta("carrier_impulse_face",true)
		face.position = Vector2(side*(platform_size.x*.5-4),-platform_size.y*.5-13)
		face.collision_layer = 8
		face.collision_mask = 0
		var collision := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(10,28)
		collision.shape = rect
		face.add_child(collision)
		add_child(face)

func mechanism_shot(context: Dictionary) -> bool:
	var face: Node = context.get("collider")
	if not face is Area2D or face.get_parent()!=self or not face.has_meta("carrier_impulse_face"): return false
	var packet: Variant = context.get("packet_id")
	if packet == null or hit_packets.has(packet): return false
	if context.get("source_faction","player") != "player": return false
	hit_packets[packet] = true
	impact_face = face
	flash_left = .14
	queue_redraw()
	if destination != station or settle_remaining > 0: return true
	var direction: Vector2 = context.get("hit_direction",Vector2.ZERO)
	if direction.is_zero_approx(): return false
	var scores := {}
	for offset: int in [-1,1]:
		var candidate := station+offset
		if candidate < 0 or candidate >= stations.size(): continue
		var path_direction := to_global(stations[candidate])-to_global(stations[station])
		var dot := direction.normalized().dot(path_direction.normalized())
		if dot >= direction_dot_min: scores[candidate] = dot
	if scores.size() == 1: destination = scores.keys()[0]
	elif scores.size() == 2:
		var a: int = scores.keys()[0]
		var b: int = scores.keys()[1]
		if not is_equal_approx(scores[a], scores[b]): destination = a if scores[a] > scores[b] else b
	return true

func _physics_process(delta: float) -> void:
	if flash_left > 0:
		flash_left = maxf(0,flash_left-delta)
		queue_redraw()
	var step := delta*equipment_time_scale
	if destination == station:
		settle_remaining = maxf(0, settle_remaining-step)
		return
	var distance := stations[station].distance_to(stations[destination])
	var progress := minf(1.0,moving_progress+step*move_speed/distance)
	var next := origin+stations[station].lerp(stations[destination],.5-.5*cos(PI*progress))
	if safe_fraction(next) < 1.0: return
	position = next
	moving_progress = progress
	if progress >= 1:
		station = destination
		moving_progress = 0
		settle_remaining = settle_s
	queue_redraw()

func _draw() -> void:
	var hardware := preload("res://game/presentation/world/carrier_hardware.gd")
	for i: int in range(1,stations.size()):
		hardware.Track.segment(self,origin-position+stations[i-1],origin-position+stations[i])
	for stop in stations: hardware.stop_block(self,origin-position+stop)
	super()
	for side: int in [-1,1]:
		var center := Vector2(side*(platform_size.x*.5-4),-platform_size.y*.5-13)
		var face := Rect2(center-Vector2(5,14),Vector2(10,28))
		draw_rect(face,Color("#352e2c"))
		MechanismRegionArt.panel(self,face.grow(-1))
		draw_rect(Rect2(center+Vector2(side*3-1,-11),Vector2(2,22)),Color("#d2ac67"))
		for y: float in [-8,0,8]:
			draw_rect(Rect2(center+Vector2(-3,y),Vector2(6,2)),Color("#eac679"))
			draw_rect(Rect2(center+Vector2(-2,y+2),Vector2(4,1)),Color("#775942"))
		hardware.stop_block(self,center+Vector2(0,15))

	if flash_left > 0 and is_instance_valid(impact_face):
		var fade := flash_left/.14
		draw_arc(impact_face.position,8+14*(1-fade),0,TAU,14,Color(1,.88,.59,fade),2)

func reset_attempt() -> void:
	flash_left = 0.0
	equipment_time_scale = 1.0
	hit_packets.clear()
	element_restore({"station":start_station,"destination":start_station,"progress":0.0,"settle":0.0})

func element_state() -> Dictionary:
	return {"station":station,"destination":destination,"progress":moving_progress,"settle":settle_remaining}

func element_restore(data: Dictionary) -> void:
	station = int(data.station)
	destination = int(data.destination)
	moving_progress = data.progress
	settle_remaining = data.settle
	jump_to(origin+stations[station].lerp(stations[destination],.5-.5*cos(PI*moving_progress)))
