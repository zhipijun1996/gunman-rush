class_name WorldCarrierSurface
extends AnimatableBody2D
## Real physical deck used by the configurable carrier, shot rail and seed.

@export var element_id := ""
@export_enum("permanent","attempt") var state_scope := "attempt"
@export var section_id := "main"
@export var platform_size := Vector2(128,24)
@export var one_way := false

var origin := Vector2.ZERO
var equipment_time_scale := 1.0
var controller: PlayerController
var shape_node: CollisionShape2D

func _ready() -> void:
	origin = position
	process_physics_priority = -100
	collision_layer = 1
	collision_mask = 0
	shape_node = CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = platform_size
	shape_node.shape = rectangle
	shape_node.one_way_collision = one_way
	add_child(shape_node)
	if one_way: add_to_group("one_way_platform")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func element_bind(context: Dictionary) -> void:
	controller = context.controller

func set_equipment_time(value: float) -> void:
	equipment_time_scale = value

func _draw() -> void:
	if one_way: UnderworldTerrain.draw_one_way(self,Rect2(-platform_size/2,platform_size))
	else: UnderworldTerrain.draw_moving(self,Rect2(-platform_size/2,platform_size))

func jump_to(point: Vector2) -> void:
	sync_to_physics = false
	position = point
	sync_to_physics = true

func safe_to_appear() -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape_node.shape
	query.transform = global_transform
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query,1).is_empty() and not overlaps_player()

func overlaps_player() -> bool:
	if not is_instance_valid(controller): return false
	var player_shape := controller.motor.get_node("CollisionShape2D") as CollisionShape2D
	return shape_node.shape.collide(global_transform,player_shape.shape,player_shape.global_transform)

func carries_player() -> bool:
	if not is_instance_valid(controller) or not controller.active or controller.actor_resources.health.terminal: return false
	var motor := controller.motor
	if not motor.is_on_floor(): return false
	for i: int in motor.get_slide_collision_count():
		var hit := motor.get_slide_collision(i)
		if hit.get_collider() == self and hit.get_normal().dot(Vector2.UP) > 0.7: return true
	# At a seam the solver can report just one floor even when both decks
	# touch the feet. Test the actual foot span against this top surface.
	var body := motor.get_node("CollisionShape2D") as CollisionShape2D
	var actor := body.global_transform * body.shape.get_rect()
	var deck := shape_node.global_transform * shape_node.shape.get_rect()
	var contact_gap := motor.safe_margin*2 + .01
	if absf(actor.end.y-deck.position.y)>contact_gap: return false
	if minf(actor.end.x,deck.end.x) <= maxf(actor.position.x,deck.position.x): return false
	return body.shape.collide_with_motion(body.global_transform,Vector2.DOWN*contact_gap,shape_node.shape,shape_node.global_transform,Vector2.ZERO)

## The body and rider are cast against physical terrain before committing their next pose.
func safe_fraction(next: Vector2) -> float:
	return sweep_fraction(position,next)

func sweep_fraction(from: Vector2,next: Vector2) -> float:
	var delta_pos := next-from
	if delta_pos.is_zero_approx(): return 1.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape_node.shape
	query.transform = global_transform
	var initial_offset: Vector2 = get_parent().global_transform.basis_xform(from-position)
	query.transform.origin += initial_offset
	query.motion = get_parent().global_transform.basis_xform(delta_pos)
	query.collision_mask = 1
	var excluded: Array[RID] = [get_rid()]
	if is_instance_valid(controller): excluded.append(controller.motor.get_rid())
	query.exclude = excluded
	var fraction := float(get_world_2d().direct_space_state.cast_motion(query)[0])
	if carries_player():
		var rider := controller.motor
		var player_shape := rider.get_node("CollisionShape2D") as CollisionShape2D
		query.shape = player_shape.shape
		query.transform = player_shape.global_transform
		query.transform.origin += initial_offset
		# An AnimatableBody publishes its new pose one physics frame before the
		# CharacterBody rides it. Include that pending lift in headroom casts.
		var top := (shape_node.global_transform * shape_node.shape.get_rect()).position.y
		var feet := (player_shape.global_transform * player_shape.shape.get_rect()).end.y
		query.transform.origin.y += minf(0.0,top-feet)
		query.margin = rider.safe_margin
		query.exclude = [get_rid(),rider.get_rid()]
		var world := get_world_2d().direct_space_state
		var rider_fraction := float(world.cast_motion(query)[0])
		if rider_fraction >= 1.0:
			# cast_motion skips pairs already within the margin. An adjacent
			# ceiling must still stop the next upward step.
			query.transform.origin += query.motion
			query.motion = Vector2.ZERO
			if not world.intersect_shape(query,1).is_empty(): rider_fraction = 0.0
		fraction = minf(fraction,rider_fraction)
	elif is_instance_valid(controller):
		var player_shape := controller.motor.get_node("CollisionShape2D") as CollisionShape2D
		if not one_way or (delta_pos.y < 0 and controller.motor.global_position.y < global_position.y):
			var shape := shape_node.shape
			if shape.collide_with_motion(query.transform,query.motion,player_shape.shape,player_shape.global_transform,Vector2.ZERO):
				var low := 0.0
				var high := fraction
				for i in 12:
					var middle := .5*(low+high)
					if shape.collide_with_motion(query.transform,query.motion*middle,player_shape.shape,player_shape.global_transform,Vector2.ZERO):
						high = middle
					else:
						low = middle
				fraction = low
	return fraction
