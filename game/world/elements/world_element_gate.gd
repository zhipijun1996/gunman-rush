class_name WorldElementGate
extends Node2D
@export var element_id := ""
@export_enum("permanent", "attempt") var state_scope := "permanent"
@export var bounds := Rect2(0,0,32,128)
@export var appearance := "mill_masonry"
var active := false
var body: StaticBody2D
var visual: UnderworldTerrain
var controller: PlayerController

func _ready() -> void:
	body = StaticBody2D.new(); body.collision_layer = 1; body.collision_mask = 0
	body.position = bounds.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new(); shape.size = bounds.size; collision.shape = shape
	body.add_child(collision); add_child(body)
	visual = UnderworldTerrain.build([bounds]); TerrainMaterialRegistry.install_on(visual, appearance); add_child(visual)

func element_bind(context: Dictionary) -> void:
	controller = context.controller

func element_state() -> Dictionary:
	return {"active":active}

func element_can_receive(input: String, value: bool) -> bool:
	if input != "set_active": return false
	return value or not is_instance_valid(controller) or not bounds.grow(24).has_point(to_local(controller.motor.global_position))

func element_propose(_input: String, value: bool) -> Dictionary:
	return {"active":value}

func element_restore(data: Dictionary) -> void:
	active = bool(data.active)
	body.collision_layer = 0 if active else 1
	visual.visible = not active
