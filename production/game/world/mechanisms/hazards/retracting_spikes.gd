@tool
class_name WorldRetractingSpikes
extends Node2D

@export var element_id := ""
@export var section_id := "main"
@export_enum("attempt") var state_scope := "attempt"
@export var bounds := Rect2(0,0,96,24)
@export_enum("up","down","left","right") var facing := "up"
@export_enum("cycle","signal") var mode := "cycle"
@export var retracted_s := 1.50
@export var warning_s := 0.35
@export var extend_s := 0.15
@export var exposed_s := 1.0
@export var retract_s := 0.20
@export var start_phase01 := 0.0

const STAGES := ["retracted","warning","extending","exposed","retracting"]
var phase := "retracted"
var elapsed := 0.0
var target := false
var running := true
var scale_time := 1.0
var body: CollisionShape2D
var lifetime: DemoLifetime
var previous: Rect2
var exposure := WorldHazardExposure.new()
var atlas: Texture2D

static func validate_configuration(p: Dictionary,_row: Dictionary,_doc: Dictionary) -> String:
	if p.warning_s <= 0 or p.extend_s <= 0 or p.retract_s <= 0: return "spike_stage:positive_time_required"
	return "" if p.start_phase01 >= 0 and p.start_phase01 < 1 else "start_phase01:outside_cycle"

func _duration() -> float:
	match phase:
		"retracted": return retracted_s
		"warning": return warning_s
		"extending": return extend_s
		"exposed": return exposed_s
	return retract_s

func extension() -> float:
	match phase:
		"extending": return clampf(elapsed/extend_s,0,1)
		"exposed": return 1.0
		"retracting": return clampf(1-elapsed/retract_s,0,1)
	return 0.0

func envelope(fraction: float) -> Rect2:
	var rect := bounds
	if facing in ["up","down"]:
		rect.size.y *= fraction
		if facing == "up": rect.position.y = bounds.end.y-rect.size.y
	else:
		rect.size.x *= fraction
		if facing == "left": rect.position.x = bounds.end.x-rect.size.x
	return rect

func element_bind(context: Dictionary) -> void:
	body = context.controller.motor.get_node("CollisionShape2D")
	context.controller.motor.repositioned.connect(rebase)
	lifetime = context.lifetime
	exposure.init(context,element_id,WorldHazardArea.profile("contact"))
	# The bolted root can be hit even while the blade is fully inside its housing.
	var socket := StaticBody2D.new()
	var base := envelope(0)
	var horizontal := facing in ["up","down"]
	var width := minf(12, bounds.size.x if horizontal else bounds.size.y)
	socket.position = base.get_center()
	socket.collision_layer = 8
	socket.collision_mask = 0
	var hit_shape := WorldHazardGeometry.rectangle_shape(Vector2(width,6) if horizontal else Vector2(6,width))
	socket.add_child(hit_shape)
	add_child(socket)
	var room: FixedWorldRoom = context.room
	var composer := room.get_node("TerrainComposer") as TerrainComposer
	var material_id := composer.material_at(base.get_center(),room.terrain_material)
	material_id = WorldElementCatalog.skin_value(self,"hazard.retracting_spikes","material",material_id)
	atlas = WorldSurfaceStyles.texture(WorldSurfaceStyles.choose("",material_id))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	process_physics_priority = 910
	reset_attempt()

func rebase() -> void:
	previous = WorldHazardGeometry.body_rect(body)
	exposure.touching = false

func _next_stage() -> void:
	phase = STAGES[(STAGES.find(phase)+1)%STAGES.size()]
	elapsed = 0.0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(body) or not lifetime.active: return
	var current := WorldHazardGeometry.body_rect(body)
	var cursor := 0.0
	while cursor < delta:
		var first := extension()
		var stable := mode == "signal" and phase in ["retracted","exposed"]
		if stable and (phase == "retracted") == target:
			_next_stage()
			stable = false
		var scaled := scale_time if running and not stable else 0.0
		var portion := delta-cursor
		if scaled > 0: portion = minf(portion,maxf(0,_duration()-elapsed)/scaled)
		elapsed += portion*scaled
		var last := extension()
		if portion > 0:
			var a := WorldHazardGeometry.interpolate(previous,current,cursor/delta)
			var b := WorldHazardGeometry.interpolate(previous,current,(cursor+portion)/delta)
			_contact(portion,a,b,first,last)
			cursor += portion
		if not stable and scaled > 0 and elapsed >= _duration()-1.0e-10: _next_stage()
	previous = current
	queue_redraw()

func _contact(dt: float, a: Rect2, b: Rect2, first: float, last: float) -> void:
	if maxf(first,last) <= 0:
		exposure.update(dt,false,false)
		return
	var window := WorldHazardGeometry.sweep(a,b,global_transform*envelope(first),global_transform*envelope(last))
	if window.x >= window.y:
		exposure.update(dt,false,false)
		return
	if window.x > 0: exposure.update(window.x*dt,false,false)
	exposure.update((window.y-window.x)*dt,true,false)
	if window.y < 1: exposure.update((1-window.y)*dt,false,false)

func _initial_phase() -> void:
	phase = "retracted"
	elapsed = 0.0
	if mode == "cycle":
		var position_s := start_phase01*(retracted_s+warning_s+extend_s+exposed_s+retract_s)
		for i: int in STAGES.size():
			if position_s < _duration(): break
			position_s -= _duration()
			_next_stage()
		elapsed = position_s

func reset_attempt() -> void:
	target = false
	running = true
	scale_time = 1.0
	_initial_phase()
	exposure.restore({})
	rebase()
	queue_redraw()

func element_can_receive(input: String, _value: bool) -> bool:
	return input == "set_active"

func element_state() -> Dictionary:
	return {"phase":phase,"elapsed":elapsed,"target":target,"running":running,"exposure":exposure.snapshot()}

func element_propose(_input: String, value: bool) -> Dictionary:
	var data := element_state()
	if mode == "signal": data.target = value
	else: data.running = value
	return data

func element_restore(data: Dictionary) -> void:
	phase = data.phase
	elapsed = data.elapsed
	target = data.target
	running = data.running
	exposure.restore(data.get("exposure",{}))
	queue_redraw()

func set_equipment_time(value: float) -> void:
	scale_time = value

func _draw() -> void:
	if not is_instance_valid(body): _initial_phase()
	var horizontal := facing in ["up","down"]
	var root_rect := envelope(0)
	var origin := root_rect.position
	var direction := Vector2.RIGHT if horizontal else Vector2.DOWN
	var length := bounds.size.x if horizontal else bounds.size.y
	var color := Color("eda354") if phase == "warning" else Color("638080")
	draw_line(origin,origin+direction*length,color,2)
	var socket_size := Vector2(minf(length,12),6) if horizontal else Vector2(6,minf(length,12))
	draw_rect(Rect2(root_rect.get_center()-socket_size*.5,socket_size),color.lightened(.2))
	var raised := extension()
	if raised <= 0: return
	var face: int = {"up":PlatformThornDefinition.Face.TOP, "down":PlatformThornDefinition.Face.BOTTOM,
		"left":PlatformThornDefinition.Face.LEFT, "right":PlatformThornDefinition.Face.RIGHT}[facing]
	UnderworldHazardTiles.draw_band(self,envelope(raised),face,Rect2(),atlas)
