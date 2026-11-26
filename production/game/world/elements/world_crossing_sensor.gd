@tool
class_name WorldCrossingSensor
extends Node2D

@export var element_id := ""
@export var section_id := "main"
@export_enum("attempt") var state_scope := "attempt"
@export var links: Array[Dictionary] = []
@export var line_points: Array[Vector2] = [Vector2(0,-48), Vector2(0,48)]:
	set(value):
		line_points = value
		queue_redraw()
@export_enum("both", "negative_to_positive", "positive_to_negative") var cross_direction := "both"
@export_enum("once", "toggle") var trigger_mode := "once"

var active := false
var latched := false
var last_side := 0
var previous := Vector2.ZERO
var touched_line := false
var flash_remaining := 0.0
var pending := false
var player_shape: CollisionShape2D
var controller: PlayerController
var lifetime: DemoLifetime
var runtime: WorldElementRuntime
var submit: Callable
var segment := SegmentShape2D.new()

func element_bind(context: Dictionary) -> void:
	controller = context.controller
	lifetime = context.lifetime
	player_shape = controller.motor.get_node("CollisionShape2D")
	runtime = context.runtime
	submit = context.submit
	segment.a = line_points[0]
	segment.b = line_points[1]
	process_physics_priority = 1150
	controller.motor.repositioned.connect(rebase)
	controller.motor.weapon_blinked.connect(func(_from: Vector2, _to: Vector2): rebase())
	rebase()

func side(point: Vector2) -> int:
	var distance := (point - segment.a).dot((segment.b - segment.a).normalized().orthogonal())
	return 0 if is_zero_approx(distance) else int(signf(distance))

func rebase() -> void:
	previous = to_local(player_shape.global_position)
	last_side = side(previous)
	latched = false
	touched_line = false
	pending = false

func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller) or not lifetime.active or not controller.active: return
	if flash_remaining>0:
		flash_remaining = maxf(0,flash_remaining-delta)
		queue_redraw()
	var current := to_local(player_shape.global_position)
	var next_side := side(current)
	if current != previous:
		if Geometry2D.segment_intersects_segment(previous, current, segment.a, segment.b) != null:
			touched_line = true
		# A step can land exactly on the line and leave on the following tick.
		if next_side == 0:
			touched_line = current.distance_squared_to(Geometry2D.get_closest_point_to_segment(current, segment.a, segment.b)) < 0.000001
		else:
			if last_side != 0 and last_side != next_side and touched_line and not latched:
				var direction := "negative_to_positive" if next_side > 0 else "positive_to_negative"
				var allowed := cross_direction == "both" or cross_direction == direction
				if allowed and (trigger_mode == "toggle" or not active): pending = true
				latched = true
			last_side = next_side
			touched_line = false
		previous = current
	if latched and not segment.collide(global_transform, player_shape.shape, player_shape.global_transform):
		latched = false
	if can_commit(): submit.call(element_id)

func can_commit() -> bool:
	return pending and runtime.can_signal(self, not active)

func element_state() -> Dictionary:
	return {"active":active, "side":last_side, "latched":latched}

func proposed_state() -> Dictionary:
	var result := element_state()
	result.active = not active
	return result

func element_signal() -> Dictionary:
	return {"output":"active", "value":not active}

func element_restore(data: Dictionary) -> void:
	flash_remaining = 0
	active = data.active
	last_side = int(data.side)
	latched = data.latched
	queue_redraw()

func accept_committed() -> void:
	pending = false
	flash_remaining = .38
	queue_redraw()

func _draw() -> void:
	if line_points.size() != 2: return
	var color := Color("8bdec2") if active else Color("ebbd70")
	var a := line_points[0]
	var b := line_points[1]
	var axis := a.direction_to(b)
	var tangent := axis.orthogonal()
	var strength := flash_remaining/.38
	draw_line(a,b,Color(color,.22+.13*strength),3)
	draw_dashed_line(a,b,Color(color,.68+.32*strength),1,4 if active else 7)
	if strength>0:
		var pulse := a.lerp(b,1-strength)
		PixelVfx.glint(self,pulse,4,color,strength)
	for i: int in 2:
		var tip := a if i==0 else b
		var inward := axis if i==0 else -axis
		# Opposed optical heads aim into the actual sensing segment.
		draw_set_transform(tip,inward.angle(),Vector2.ONE)
		MechanismRegionArt.stamp(self,"mount",Vector2(-6,0),Vector2(17,19))
		MechanismRegionArt.stamp(self,"finial",Vector2(-3,0),Vector2(13,15))
		for sign_y: float in [-1.0,1.0]:
			draw_texture_rect_region(BellGateArt.texture(),Rect2(-4,sign_y*4-2,9,4),BellGateArt.GUIDE)
		MechanismRegionArt.stamp(self,"lamp",Vector2(2,0),Vector2(7,8))
		draw_rect(Rect2(4,-2,2,4),color)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	if cross_direction != "both":
		var normal := tangent if cross_direction=="negative_to_positive" else -tangent
		var anchor := a+axis*minf(15,a.distance_to(b)*.28)
		var nose := anchor+normal*4
		draw_polyline(PackedVector2Array([anchor-axis*3,nose,anchor+axis*3]),color,1)
	if runtime == null: return
	for link: Dictionary in links:
		var target: Node2D = runtime.nodes.get(link.target)
		if target == null: continue
		var bounds: Variant = target.get("bounds")
		var at := target.to_global(bounds.get_center()) if bounds is Rect2 else target.global_position
		draw_dashed_line(b, to_local(at), Color(color,0.45), 1, 4)
