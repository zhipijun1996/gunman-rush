class_name MechanismSolid
extends Node2D
## A movable authored rectangle. The moving face and its rider are checked
## together, before either is advanced. The player keeps their own rotation.
@export var element_id := ""
@export var section_id := "main"
@export_enum("attempt","permanent") var state_scope := "attempt"
var body: StaticBody2D
var collision: CollisionShape2D
var rect_shape := RectangleShape2D.new()
var controller: PlayerController
var runtime: WorldElementRuntime
var lifetime: DemoLifetime
var policy: FrameDamagePolicy
var blocked := false
var shot_receipts := {}
var hit_part: Area2D

func make_solid(size: Vector2, local_center := Vector2.ZERO) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body = StaticBody2D.new()
	collision = CollisionShape2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	rect_shape.size = size
	collision.shape = rect_shape
	body.add_child(collision)
	body.position = local_center
	add_child(body)
	process_physics_priority = -110

func element_bind(context: Dictionary) -> void:
	controller = context.controller
	lifetime = context.lifetime
	policy = context.policy
	runtime = context.runtime

func shot_part(point: Vector2, radius: float) -> void:
	hit_part = Area2D.new()
	hit_part.collision_layer = 8
	hit_part.collision_mask = 0
	hit_part.position = point
	var circle := CircleShape2D.new()
	circle.radius = radius
	var hit_collision := CollisionShape2D.new()
	hit_collision.shape = circle
	hit_part.add_child(hit_collision)
	add_child(hit_part)

func equipment_hit_part(collider: Node) -> bool:
	return collider == (hit_part as Node if is_instance_valid(hit_part) else body as Node)

var result_owned := false

func accept_shot(context: Dictionary) -> bool:
	if result_owned: return false
	if context.get("collider") != hit_part or not is_instance_valid(controller) or not controller.active: return false
	var packet := str(context.get("packet_id",""))
	if packet.is_empty() or shot_receipts.has(packet): return false
	shot_receipts[packet] = true
	return true

func player_shape() -> CollisionShape2D:
	return controller.motor.get_node("CollisionShape2D")

func player_half() -> Vector2:
	return (player_shape().shape as RectangleShape2D).size * 0.5

func rider_contact(allow_wall := false) -> Dictionary:
	if not is_instance_valid(controller) or not controller.active: return {}
	var motor := controller.motor
	for i: int in motor.get_slide_collision_count():
		var hit := motor.get_slide_collision(i)
		if hit.get_collider() != body: continue
		var top := motor.is_on_floor() and hit.get_normal().dot(Vector2.UP) >= cos(motor.floor_max_angle)
		var wall := allow_wall and motor.is_on_wall() and controller.traversal.state == &"wall_attach"
		if top or wall: return {"point":hit.get_position(),"normal":hit.get_normal(),"top":top}
	return {}

func query_shape(shape: Shape2D, at: Transform2D, ignore: Array[RID]) -> PhysicsShapeQueryParameters2D:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = at
	query.collision_mask = 1
	query.exclude = ignore
	return query

func fits(shape: Shape2D, at: Transform2D, ignore: Array[RID]) -> bool:
	var query := query_shape(shape,at,ignore)
	return get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func travel_fraction(motion: Vector2, ignore_player := false) -> float:
	if motion.is_zero_approx(): return 1.0
	var exclude: Array[RID] = [body.get_rid()]
	if ignore_player and is_instance_valid(controller): exclude.append(controller.motor.get_rid())
	var probe := RectangleShape2D.new()
	probe.size = (rect_shape.size - Vector2.ONE*0.04).max(Vector2.ONE*0.001)
	var query := query_shape(probe,body.global_transform,exclude)
	query.motion = motion
	return get_world_2d().direct_space_state.cast_motion(query)[0]

func rider_fits(shift: Vector2) -> bool:
	if shift.is_zero_approx(): return true
	var player_collision := player_shape()
	var exclude: Array[RID] = [body.get_rid(),controller.motor.get_rid()]
	var query := query_shape(player_collision.shape,player_collision.global_transform,exclude)
	query.motion = shift
	var space := get_world_2d().direct_space_state
	if space.cast_motion(query)[0] < 0.99999: return false
	# A cast can omit a shape that is already touching the starting margin.
	var probe := RectangleShape2D.new()
	probe.size = (player_half()*2-Vector2.ONE*0.04).max(Vector2.ONE*0.001)
	query.shape = probe
	query.transform.origin += shift
	query.motion = Vector2.ZERO
	return space.intersect_shape(query,1).is_empty()

func move_rider(shift: Vector2) -> void:
	if shift != Vector2.ZERO:
		controller.motor.global_position += shift
		controller.motor.force_update_transform()

func make_hazard(rect: Rect2) -> DemoContactEmitter:
	var emitter := DemoContactEmitter.environment_rect(rect,policy,controller,StringName(element_id))
	add_child(emitter)
	return emitter
