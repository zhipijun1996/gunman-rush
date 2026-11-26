@tool
class_name WorldHazardArea
extends Node2D

@export var element_id := ""
@export var section_id := "main"
@export_enum("attempt") var state_scope := "attempt"
@export var rect := Rect2(0,0,128,24)
@export var hazard_profile := "inherit"
@export_enum("steady","cycle") var hazard_mode := "steady"
@export var inactive_s := 1.8
@export var warning_s := 0.4
@export var active_s := 1.2
@export var start_phase01 := 0.0
static var _profiles: Dictionary = {}
var clock := 0.0
var exposure := WorldHazardExposure.new()
var shelters: Array[WorldEnvironmentShelter] = []
var previous: Rect2
var body: CollisionShape2D
var lifetime: DemoLifetime
var settings: Dictionary
var phase: String:
	get:
		if hazard_mode == "steady": return "active"
		if clock < inactive_s: return "inactive"
		if clock < inactive_s+warning_s: return "warning"
		return "active"

static func profile(id: String) -> Dictionary:
	if _profiles.is_empty(): _profiles = JSON.parse_string(FileAccess.get_file_as_string("res://config/environment_hazards.json"))
	return _profiles.get(id,{})

static func resolve_profile(definition: Dictionary,id: String) -> Dictionary:
	return profile(definition.bindings.hazard_profile if id == "inherit" else id)

static func validate_configuration(p: Dictionary,row: Dictionary,_doc: Dictionary) -> String:
	if resolve_profile(WorldElementCatalog.catalog().definitions[row.definition_id],p.hazard_profile).is_empty(): return "hazard_profile:unknown"
	if p.hazard_mode == "cycle" and (p.inactive_s <= 0 or p.warning_s <= 0 or p.active_s <= 0): return "hazard_cycle:positive_stages_required"
	if not (p.start_phase01 >= 0 and p.start_phase01 < 1): return "start_phase01:outside_cycle"
	return ""

func element_bind(context: Dictionary) -> void:
	body = context.controller.motor.get_node("CollisionShape2D")
	context.controller.motor.repositioned.connect(rebase)
	lifetime = context.lifetime
	settings = resolve_profile(WorldElementCatalog.catalog().definitions[get_meta("definition_id","hazard.area")],hazard_profile)
	exposure.init(context,element_id,settings)
	process_physics_priority = 910
	reset_attempt()

func register_shelter(shelter: WorldEnvironmentShelter) -> void:
	if not shelters.has(shelter): shelters.append(shelter)

func rebase() -> void:
	previous = WorldHazardGeometry.body_rect(body)
	exposure.touching = false

func _physics_process(delta: float) -> void:
	if not is_instance_valid(body) or not lifetime.active: return
	var current := WorldHazardGeometry.body_rect(body)
	var bounds := global_transform * rect
	var contact := WorldHazardGeometry.sweep(previous,current,bounds,bounds)
	var cuts: Array[float] = [0,1]
	var protected_windows: Array[Vector2] = []
	if contact.x < contact.y:
		cuts.append(contact.x)
		cuts.append(contact.y)
		for shelter: WorldEnvironmentShelter in shelters:
			if not is_instance_valid(shelter): continue
			for window: Vector2 in shelter.protection_intervals(previous,current):
				cuts.append(window.x)
				cuts.append(window.y)
				protected_windows.append(window)
	cuts.sort()
	for i: int in range(1,cuts.size()):
		var start := cuts[i-1]
		var end := cuts[i]
		if end <= start: continue
		var middle := (start+end)*.5
		if middle < contact.x or middle > contact.y:
			exposure.update((end-start)*delta,false,false)
			continue
		var protected := false
		for window: Vector2 in protected_windows:
			if middle >= window.x and middle < window.y:
				protected = true
				break
		integrate_contact(clock+start*delta,(end-start)*delta,protected)
	var period := inactive_s+warning_s+active_s
	if hazard_mode == "cycle": clock = fposmod(clock+delta,period)
	previous = current
	queue_redraw()

func integrate_contact(start: float, duration: float, protected: bool) -> void:
	if hazard_mode == "steady":
		exposure.update(duration,true,protected)
		return
	var safe_s := inactive_s+warning_s
	var period := safe_s+active_s
	var phase_time := fposmod(start,period)
	var left := duration
	while left > 0:
		var dangerous := phase_time >= safe_s
		var boundary := period if dangerous else safe_s
		var portion := minf(left,boundary-phase_time)
		exposure.update(portion,dangerous,protected)
		left -= portion
		phase_time = 0 if dangerous else safe_s

func element_state() -> Dictionary:
	return {"clock":clock,"exposure":exposure.snapshot()}

func element_restore(data: Dictionary) -> void:
	clock = data.clock
	previous = WorldHazardGeometry.body_rect(body)
	exposure.restore(data.exposure)
	queue_redraw()

func reset_attempt() -> void:
	element_restore({"clock":start_phase01*(inactive_s+warning_s+active_s),"exposure":{}})

func marker_color() -> Color:
	var profile_data := settings
	if profile_data.is_empty():
		profile_data = resolve_profile(WorldElementCatalog.catalog().definitions["hazard.area"],hazard_profile)
	return Color(profile_data.get("color","dc7059"))

func _draw() -> void:
	if not is_instance_valid(body): clock = start_phase01*(inactive_s+warning_s+active_s)
	var marker := marker_color()
	if not shelters.is_empty():
		var anchor := rect.position + rect.size*.5
		var radius := minf(4.0,minf(rect.size.x,rect.size.y)*.4)
		draw_arc(anchor,radius,0,TAU,16,marker,2)
	if phase == "inactive":
		draw_rect(rect,Color(.8,.6,.4,.3),false,1)
		return
	var color := marker
	var factor := clampf((clock-inactive_s)/maxf(warning_s,.000001),0,1) if phase == "warning" else 1.0
	color.a = .14+.32*factor
	draw_rect(rect,color)
	color.a = .45+.45*factor
	draw_rect(rect,color,false,1)
	var width := minf(rect.size.x,8.0)
	for i: int in range(0,ceili(rect.size.x-width)+1,18):
		var origin := rect.position+Vector2(i,rect.size.y)
		draw_line(origin,origin+Vector2(width,-rect.size.y*factor),color,2)
