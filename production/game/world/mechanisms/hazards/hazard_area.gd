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
var visual_clock := 0.0
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
	visual_clock += delta
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
	visual_clock = 0
	element_restore({"clock":start_phase01*(inactive_s+warning_s+active_s),"exposure":{}})

func marker_color() -> Color:
	var profile_data := settings
	if profile_data.is_empty():
		profile_data = resolve_profile(WorldElementCatalog.catalog().definitions["hazard.area"],hazard_profile)
	return Color(profile_data.get("color","dc7059"))

func _draw() -> void:
	if not is_instance_valid(body): clock = start_phase01*(inactive_s+warning_s+active_s)
	var marker := marker_color()
	var live := phase=="active"
	var warning := phase=="warning"
	var strength := 1.0 if live else clampf((clock-inactive_s)/maxf(.000001,warning_s),0,1) if warning else 0.0
	var count := clampi(ceili(rect.size.x/43),1,96)
	var cell := rect.size.x/count
	var shoe := minf(8,rect.size.y*.15)
	var housing := Vector2(minf(30,cell*.8),minf(16,rect.size.y*.28))
	var gas := hazard_profile=="vent_gas"
	draw_rect(rect,Color(marker,.16 if live else .035+.07*strength))
	for i: int in count:
		var x := rect.position.x+(i+.5)*cell
		var at := Vector2(x,rect.end.y-housing.y/2)
		var t := fposmod(visual_clock*(.63 if gas else 1.1)+i*.381966,1.0)
		if strength>0:
			var rise := rect.size.y*(.27+.64*t)*strength
			var width := minf(cell*.42,10.0)
			var layers := clampi(ceili(rise/2),1,48)
			var foot := rect.end.y-shoe
			for k: int in layers:
				var fraction := (k+.5)/layers
				var wave := sin(t*TAU+fraction*(4.9 if gas else 3.4)+i*1.7)
				var xx := x+width*wave*fraction
				var y0 := maxf(rect.position.y,roundf(foot-rise*(k+1)/layers))
				var y1 := clampf(roundf(foot-rise*k/layers),rect.position.y,rect.end.y)
				var half := width*(.34+.6*sin(fraction*PI))*(1-fraction)
				if gas: half *= 1+.46*sin(t*TAU+fraction*10)
				half = maxf(.65,half)
				if y1<=y0: continue
				draw_rect(Rect2(roundf(xx-half),y0,maxf(1,roundf(2*half)),y1-y0),Color(marker,.45*strength))
				if fraction<.7:
					draw_rect(Rect2(roundf(xx-half*.28),y0,maxf(1,roundf(half*.62)),y1-y0),Color(marker.lightened(.4),.68*strength))
			var sprite_scale := minf(minf(cell/96.0,rect.size.y/86.0),.68)*strength
			var particle := Vector2(x,clampf(rect.get_center().y+rect.size.y*.09*sin(t*TAU),rect.position.y+36*sprite_scale,rect.end.y-44*sprite_scale))
			PixelVfx.clip(self,&"dust" if gas else &"ember",particle,t,0,Color(marker,.8),Vector2.ONE*sprite_scale)
		MechanismRegionArt.stamp(self,"hazard",at,housing,Color(.67,.68,.65))
		var plinth := Rect2(at.x-housing.x/2,rect.end.y-shoe,housing.x,shoe)
		MechanismRegionArt.panel(self,plinth)
		if housing.x>=12 and shoe>=3:
			draw_texture_rect_region(BellGateArt.texture(),Rect2(at-Vector2(housing.x*.34,shoe*.35),Vector2(housing.x*.68,shoe*.68)),BellGateArt.CLEAT)
			for slat: int in 4:
				var sx := at.x+(slat-1.5)*housing.x*.105
				draw_rect(Rect2(sx,at.y-shoe*.45,1,shoe*.55),Color("322e2f"))
		if warning or live:
			draw_rect(Rect2(at.x-2,at.y-2,4,2),Color(marker,.35+.65*strength))
	# A thin continuous border remains coextensive with the swept damage rectangle.
	draw_rect(rect,Color(marker,.80 if live else .40 if warning else .28),false,1)
	if not shelters.is_empty():
		for x: float in [rect.position.x,rect.end.x]:
			var sign_x := 1 if x==rect.position.x else -1
			var r := minf(4,minf(rect.size.x,rect.size.y)*.25)
			var jewel := Vector2(x+sign_x*r,rect.position.y+r)
			draw_arc(jewel,r*.7,0,TAU,12,marker,1)
