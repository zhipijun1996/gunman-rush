@tool
class_name WorldCrumblePlatform
extends StaticBody2D

@export var element_id := ""
@export var section_id := "main"
@export_enum("attempt") var state_scope := "attempt"
@export var platform_size := Vector2(96,16)
@export var one_way := true
@export_enum("step","wall_attach","cycle","jump_toggle") var trigger_mode := "step"
@export_enum("left","right","both") var attach_face := "both"
@export var solid_s := 2.0
@export var crack_s := .60
@export var absent_s := 2.0
@export var reform_s := .25
@export var start_phase01 := 0.0
@export var jump_bounds := Rect2(-384,-256,768,512)
@export var jump_types: Array[String] = ["ground","double","wall"]
@export var initial_solid := true
var phase := "idle"
var elapsed := 0.0
var solid := true
var desired := true
var resume_phase := "idle"
var resume_elapsed := 0.0
var last_jump := -1
var scale_time := 1.0
var controller: PlayerController
var lifetime: DemoLifetime
var body: CollisionShape2D
var surface: CollisionShape2D

static func validate_configuration(p: Dictionary,_row: Dictionary,_doc: Dictionary) -> String:
	if p.trigger_mode == "wall_attach" and p.one_way: return "wall_attach:requires_solid_sides"
	if p.solid_s <= 0 or p.crack_s <= 0 or p.reform_s <= 0: return "crumble_duration:positive_required"
	if p.start_phase01 < 0 or p.start_phase01 >= 1: return "start_phase01:outside_cycle"
	if p.trigger_mode == "jump_toggle":
		if p.jump_types.is_empty(): return "jump_types:required"
		var seen := {}
		for kind: Variant in p.jump_types:
			if kind not in ["ground","double","wall"] or seen.has(kind): return "jump_types:invalid_or_duplicate"
			seen[kind] = true
	return ""

func element_bind(context: Dictionary) -> void:
	controller = context.controller
	lifetime = context.lifetime
	body = controller.motor.get_node("CollisionShape2D")
	surface = WorldHazardGeometry.rectangle_shape(platform_size,one_way)
	add_child(surface)
	if one_way: add_to_group("one_way_platform")
	controller.jump_ability.accepted_jump.connect(_jump)
	collision_mask = 0
	process_physics_priority = 200
	reset_attempt()

func _occupied() -> bool:
	return surface.shape.collide(surface.global_transform,body.shape,body.global_transform)

func _set_solid(value: bool) -> void:
	solid = value
	collision_layer = 1 if value else 0

func _restore_solid(stage: String, at: float) -> void:
	if _occupied():
		resume_phase = stage
		resume_elapsed = at
		phase = "reform_wait"
		elapsed = 0
		_set_solid(false)
	else:
		phase = stage
		elapsed = at
		_set_solid(true)

func _jump(kind: StringName,serial: int,center: Vector2) -> void:
	if trigger_mode != "jump_toggle" or not lifetime.active or not controller.active or serial <= last_jump: return
	last_jump = serial
	if str(kind) not in jump_types or not jump_bounds.has_point(to_local(center)): return
	desired = not desired
	if desired == solid: phase = "solid" if solid else "absent"
	else: phase = "appearing" if desired else "vanishing"
	elapsed = 0
	queue_redraw()

func _wall_trigger() -> bool:
	var traversal := controller.traversal
	if not traversal.wall_enabled or traversal.state != &"wall_attach": return false
	for i: int in controller.motor.get_slide_collision_count():
		var hit := controller.motor.get_slide_collision(i)
		if hit.get_collider() != self or absf(hit.get_normal().x) < .9: continue
		var face := "left" if hit.get_normal().x < 0 else "right"
		if attach_face == "both" or attach_face == face: return true
	return false

func _duration(stage: String) -> float:
	match stage:
		"solid": return solid_s
		"cracking","vanishing": return crack_s
		"absent": return absent_s
	return reform_s

func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller) or not lifetime.active or not controller.active: return
	if phase == "idle":
		if trigger_mode == "step" and WorldHazardGeometry.supported(controller.motor,self) or trigger_mode == "wall_attach" and _wall_trigger():
			phase = "cracking"
		else: return
	var left := delta*scale_time
	if left <= 0: return
	if phase == "reform_wait": _restore_solid(resume_phase,resume_elapsed)
	while left > 0 and phase not in ["idle","reform_wait"]:
		if trigger_mode == "jump_toggle" and phase in ["solid","absent"]: break
		var step := minf(left,maxf(0,_duration(phase)-elapsed))
		elapsed += step
		left -= step
		if elapsed < _duration(phase)-1.0e-9: break
		elapsed = 0
		match phase:
			"solid": phase = "cracking"
			"cracking","vanishing":
				_set_solid(false)
				phase = "absent"
			"absent": phase = "reforming"
			"reforming","appearing": _restore_solid("idle" if trigger_mode in ["step","wall_attach"] else "solid",0)
	queue_redraw()

func _initial_phase() -> void:
	elapsed = 0
	desired = initial_solid if trigger_mode == "jump_toggle" else true
	phase = "idle"
	if trigger_mode == "cycle":
		var t := start_phase01*(solid_s+crack_s+absent_s+reform_s)
		for stage: String in ["solid","cracking","absent","reforming"]:
			phase = stage
			if t < _duration(stage): break
			t -= _duration(stage)
		elapsed = t
	elif trigger_mode == "jump_toggle": phase = "solid" if desired else "absent"

func reset_attempt() -> void:
	last_jump = controller.jump_ability.accepted_serial
	scale_time = 1
	_initial_phase()
	if phase in ["solid","cracking","idle"]: _restore_solid(phase,elapsed)
	else: _set_solid(false)
	queue_redraw()

func element_state() -> Dictionary:
	return {"phase":phase,"elapsed":elapsed,"solid":solid,"desired":desired,"resume_phase":resume_phase,"resume_elapsed":resume_elapsed,"jump_serial":last_jump}

func element_restore(data: Dictionary) -> void:
	phase = data.phase
	elapsed = data.elapsed
	desired = data.desired
	resume_phase = data.resume_phase
	resume_elapsed = data.resume_elapsed
	last_jump = int(data.jump_serial)
	if data.solid: _restore_solid(phase,elapsed)
	else: _set_solid(false)
	queue_redraw()

func set_equipment_time(value: float) -> void:
	scale_time = value

func _draw() -> void:
	if not is_instance_valid(controller):
		_initial_phase()
		solid = phase in ["solid","cracking","idle"]
	var rect := Rect2(-platform_size*.5,platform_size)
	if solid:
		UnderworldTerrain.draw_moving(self,rect)
		var count := maxi(1,ceili(platform_size.x/32))
		for i: int in count:
			var x := rect.position.x+(i+.5)*platform_size.x/count
			var strength := clampf(elapsed/maxf(crack_s,.00001),0,1) if phase in ["cracking","vanishing"] else 0.0
			draw_polyline(PackedVector2Array([Vector2(x,rect.position.y),Vector2(x-3,0),Vector2(x+2,rect.end.y*strength)]),Color("d39664").darkened(.5-.45*strength),1)
	else:
		var color := Color("d9ac74") if phase in ["appearing","reforming","reform_wait"] else Color("65777a")
		draw_rect(rect,Color(color,.2))
		draw_rect(rect,color,false,1)
	if trigger_mode == "jump_toggle": draw_circle(rect.get_center(),2,Color("b5efc3") if desired else Color("af8577"))

	if trigger_mode == "wall_attach":
		for side: String in ["left","right"]:
			if attach_face != "both" and attach_face != side: continue
			var x := rect.position.x if side == "left" else rect.end.x
			var inset := minf(4,rect.size.x/2)*(1 if side == "left" else -1)
			var count := maxi(1,ceili(rect.size.y/28))
			for i: int in count:
				var y := rect.position.y+(i+.5)*rect.size.y/count
				var height := minf(5,rect.size.y/count*.5)
				draw_polyline(PackedVector2Array([Vector2(x,y-height),Vector2(x+inset,y),Vector2(x,y+height)]),Color("ce9765"),1)
