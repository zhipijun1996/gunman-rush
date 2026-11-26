@tool
class_name WorldEnvironmentShelter
extends Node2D

@export var element_id := ""
@export var section_id := "main"
@export_enum("attempt") var state_scope := "attempt"
@export var control_radius := 14.0
@export var shield_radius := 96.0
@export var protected_sources: Array[String] = []
@export var active_s := 3.0
@export var expiry_warning_s := 0.6
@export var cooldown_s := 2.0

var phase := "ready"
var remaining := 0.0
var receipts := {}
var controller: PlayerController
var lifetime: DemoLifetime
var body: CollisionShape2D
var _frame := -1
var _windows: Array[Vector2] = []
var _hits: Array[float] = []
var source_nodes: Array[WorldHazardArea] = []

static func validate_configuration(p: Dictionary, _row: Dictionary, doc: Dictionary) -> String:
	if p.control_radius <= 0 or p.shield_radius <= p.control_radius: return "shield_radius:must_exceed_control"
	if p.expiry_warning_s <= 0 or p.expiry_warning_s >= p.active_s: return "expiry_warning_s:outside_active_window"
	if p.protected_sources.is_empty(): return "protected_sources:required"
	var seen := {}
	for id: Variant in p.protected_sources:
		if not id is String or seen.has(id): return "protected_sources:invalid_or_repeated"
		seen[id] = true
		var source: Dictionary = doc.entities.get(id,{})
		if source.get("definition_id") != "hazard.area": return "protected_sources:not_hazard_area:"+id
		if source.properties.get("section_id","main") != p.section_id: return "protected_sources:foreign_section:"+id
		var settings := WorldHazardArea.resolve_profile(WorldElementCatalog.catalog().definitions["hazard.area"],source.properties.get("hazard_profile","inherit"))
		if not settings.get("local_shelter_eligible",false): return "protected_sources:ineligible:"+id
	return ""

func element_bind(context: Dictionary) -> void:
	controller = context.controller
	lifetime = context.lifetime
	body = controller.motor.get_node("CollisionShape2D")
	process_physics_priority = 850
	var button := StaticBody2D.new()
	button.collision_layer = 8
	button.collision_mask = 0
	var hit := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = control_radius
	hit.shape = circle
	button.add_child(hit)
	add_child(button)
	for id: String in protected_sources:
		var area: WorldHazardArea = context.runtime.nodes[id]
		source_nodes.append(area)
		area.register_shelter(self)
	reset_attempt()

func _exit_tree() -> void:
	for area: WorldHazardArea in source_nodes:
		if is_instance_valid(area): area.shelters.erase(self)
	source_nodes.clear()

func mechanism_shot(context: Dictionary) -> bool:
	if not is_instance_valid(controller) or not lifetime.active or not controller.active: return false
	if context.get("controller") != controller or context.get("attack_kind") not in ["shot","charged_shot"]: return false
	var packet := str(context.get("packet_id",""))
	if packet.is_empty() or receipts.has(packet): return false
	receipts[packet] = true
	_hits.append(clampf(context.get("hit_fraction",1.0),0,1))
	return true

func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller) or not lifetime.active: return
	_frame = Engine.get_physics_frames()
	_windows.clear()
	# Flight order can differ from the actual order of the contacts in this step.
	_hits.sort()
	var cursor := 0.0
	for at: float in _hits:
		_advance_window(cursor,at,delta)
		if phase == "ready":
			phase = "active"
			remaining = active_s
		cursor = at
	_hits.clear()
	_advance_window(cursor,1.0,delta)
	queue_redraw()

func _advance_window(start: float, end: float, dt: float) -> void:
	var left := (end-start)*dt
	if phase == "active":
		var portion := minf(left,remaining)
		if portion > 0: _windows.append(Vector2(start,start+portion/dt))
		left -= portion
		remaining -= portion
		if remaining <= 0:
			phase = "cooldown"
			remaining = cooldown_s
	if phase == "cooldown":
		remaining = maxf(0,remaining-left)
		if remaining == 0: phase = "ready"

func protection_intervals(from: Rect2, to: Rect2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if _frame != Engine.get_physics_frames() or _windows.is_empty(): return result
	var inside := _containment_interval(from,to)
	for window: Vector2 in _windows:
		var intersection := Vector2(maxf(inside.x,window.x),minf(inside.y,window.y))
		if intersection.x < intersection.y: result.append(intersection)
	return result

## The intersection of the four swept corner/circle intervals contains exactly
## the times when the entire axis-aligned player rectangle is inside the circle.
func _containment_interval(from: Rect2, to: Rect2) -> Vector2:
	var interval := Vector2(0,1)
	for corner: Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN,Vector2.ONE]:
		var start := to_local(from.position + corner*from.size)
		var motion := to_local(to.position + corner*to.size)-start
		var a := motion.length_squared()
		var c := start.length_squared()-shield_radius*shield_radius
		if a <= 0.000000001:
			if c > 0.000001: return Vector2(1,0)
			continue
		var b := start.dot(motion)
		var disc := b*b-a*c
		if disc < 0: return Vector2(1,0)
		var root := sqrt(disc)
		interval.x = maxf(interval.x,(-b-root)/a)
		interval.y = minf(interval.y,(-b+root)/a)
	return interval

func element_state() -> Dictionary:
	return {"phase":phase,"remaining":remaining,"receipts":receipts.duplicate()}

func element_restore(data: Dictionary) -> void:
	phase = data.phase
	remaining = data.remaining
	receipts = data.receipts.duplicate()
	_frame = -1
	_hits.clear()
	_windows.clear()
	queue_redraw()

func reset_attempt() -> void:
	element_restore({"phase":"ready","remaining":0,"receipts":{}})

func _draw() -> void:
	var color := Color("e9a352")
	if not source_nodes.is_empty() and is_instance_valid(source_nodes[0]):
		color = source_nodes[0].marker_color()
	var enabled := phase == "active"
	if enabled and remaining < expiry_warning_s: color = color.lerp(Color.WHITE,absf(sin(remaining*20)))
	if enabled:
		draw_circle(Vector2.ZERO,shield_radius,Color(color,.105))
		draw_arc(Vector2.ZERO,shield_radius,0,TAU,96,Color(color,.78),2)
		var inside := body!=null and _containment_interval(WorldHazardGeometry.body_rect(body),WorldHazardGeometry.body_rect(body)).x==0
		var inner := maxf(1,shield_radius-3)
		var turn := fposmod((active_s-remaining)*.22,TAU/12)
		for i: int in 12:
			var angle := i*TAU/12+turn
			var point := Vector2.from_angle(angle)
			draw_arc(Vector2.ZERO,inner,angle+.07,angle+.34,8,Color(color,.8 if inside else .32),1)
			draw_line(point*(shield_radius-6),point*(shield_radius-2),Color(color,.85),2)
		if inside: draw_arc(Vector2.ZERO,shield_radius-5,0,TAU,96,Color(color,.34),1)
	var radius := control_radius
	var iris_tint := Color(.56,.61,.61) if phase=="cooldown" else Color.WHITE
	for i: int in 4:
		var angle := PI*.25+i*PI*.5
		var normal := Vector2.from_angle(angle)
		draw_set_transform(Vector2.ZERO,angle,Vector2.ONE)
		var outer := radius*1.52 if enabled else radius*1.10 if phase=="ready" else radius*.83
		draw_texture_rect_region(BellGateArt.texture(),Rect2(radius*.52,-radius*.18,outer-radius*.25,radius*.36),BellGateArt.GUIDE,iris_tint)
		MechanismRegionArt.stamp(self,"mount",Vector2(outer,0),Vector2(radius*.8,radius*.72),iris_tint)
		if enabled: draw_rect(Rect2(outer-radius*.10,-1,3,2),color)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	MechanismRegionArt.stamp(self,"finial",Vector2.ZERO,Vector2.ONE*radius*1.90,iris_tint)
	draw_circle(Vector2.ZERO,radius*.51,Color("282d31"))
	MechanismRegionArt.stamp(self,"lamp",Vector2.ZERO,Vector2(radius*.94,radius*1.17),iris_tint)
	if phase!="cooldown":
		PixelVfx.glint(self,Vector2(0,-1),minf(4,radius*.3),color,.82 if enabled else .52)
	var slice := TAU/maxi(1,source_nodes.size())
	for i: int in source_nodes.size():
		if not is_instance_valid(source_nodes[i]): continue
		var marker := source_nodes[i].marker_color()
		draw_arc(Vector2.ZERO,control_radius+2, i*slice, (i+1)*slice,20,marker,2)
	if phase in ["active","cooldown"]:
		var duration := active_s if enabled else cooldown_s
		var progress := clampf(remaining/maxf(duration,.000001),0,1)
		draw_arc(Vector2.ZERO,control_radius+5,-PI/2,-PI/2+TAU*progress,32,color,2)
