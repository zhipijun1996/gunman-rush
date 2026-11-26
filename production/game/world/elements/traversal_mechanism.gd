class_name TraversalMechanism
extends Node2D

const SHOT_ONLY_LAYER := 1 << 27

@export var element_id := ""
@export var section_id := "main"
@export_enum("attempt") var state_scope := "attempt"
var controller: PlayerController
var lifetime: DemoLifetime
var player_shape: CollisionShape2D

func element_bind(context: Dictionary) -> void:
	controller = context.controller
	lifetime = context.lifetime
	player_shape = controller.motor.get_node("CollisionShape2D")

func live() -> bool:
	return is_instance_valid(controller) and controller.active and lifetime.active and not controller.actor_resources.health.terminal

func player_box() -> Rect2:
	return player_shape.global_transform * player_shape.shape.get_rect()

func element_state() -> Dictionary:
	return {"phase":"ready"}

func element_can_receive(input: String, _value: bool) -> bool:
	return input == "set_active"

func element_propose(_input: String, value: bool) -> Dictionary:
	var data := element_state()
	data.active = value
	return data

static func rectangle(body: PhysicsBody2D, size: Vector2, center := Vector2.ZERO) -> CollisionShape2D:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.position = center
	body.add_child(collision)
	return collision

static func overlap(node: Node2D, shape: Shape2D, at: Transform2D, exclude: Array[RID], mask := 1) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = at
	query.collision_mask = mask
	query.exclude = exclude
	return not node.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
