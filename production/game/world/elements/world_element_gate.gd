class_name WorldElementGate
extends Node2D
@export var element_id := ""
@export_enum("permanent", "attempt") var state_scope := "permanent"
@export var section_id := "main"
@export_enum("left","right","up","down") var pass_direction := "right"
@export var close_delay := 0.30
var requested_open := false
var release_remaining := 0.0
@export_enum("signal","directional") var gate_mode := "signal"
@export var bounds := Rect2(0,0,32,128)
@export var appearance := "inherit"
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
	var material_id := appearance
	if material_id == "inherit":
		material_id = WorldElementCatalog.skin_value(self,str(get_meta("definition_id","gate.masonry")),"material","mill_masonry")
	visual = UnderworldTerrain.build([bounds], {}, TerrainMaterialRegistry.appearance(material_id))
	add_child(visual)

func element_bind(context: Dictionary) -> void:
	controller = context.controller
	set_physics_process(gate_mode == "directional")

func element_state() -> Dictionary:
	return {"active":active,"requested_open":requested_open,"release_remaining":release_remaining}

func element_can_receive(input: String, value: bool) -> bool:
	if input != "set_active": return false
	if value or not is_instance_valid(controller): return true
	var player_shape := controller.motor.get_node("CollisionShape2D") as CollisionShape2D
	var gate_shape := body.get_child(0) as CollisionShape2D
	return not gate_shape.shape.collide(gate_shape.global_transform, player_shape.shape, player_shape.global_transform)

func element_propose(_input: String, value: bool) -> Dictionary:
	return {"active":value,"requested_open":value,"release_remaining":0.0}

func element_restore(data: Dictionary) -> void:
	requested_open = data.get("requested_open", data.active)
	release_remaining = data.get("release_remaining", 0.0)
	set_open(data.active)

func set_open(value: bool) -> void:
	active = value
	queue_redraw()
	body.collision_layer = 0 if active else 1
	visual.visible = not active

func _physics_process(delta: float) -> void:
	if gate_mode != "directional" or not is_instance_valid(controller) or not controller.active: return
	var shape := controller.motor.get_node("CollisionShape2D") as CollisionShape2D
	var player_rect: Rect2 = (global_transform.affine_inverse() * shape.global_transform) * shape.shape.get_rect()
	var axis := direction_axis()
	var approach := bounds
	var margin := absf(axis.dot(player_rect.size))
	if axis.x != 0:
		approach.size.x = margin
		approach.position.x = bounds.position.x-margin if axis.x > 0 else bounds.end.x
	else:
		approach.size.y = margin
		approach.position.y = bounds.position.y-margin if axis.y > 0 else bounds.end.y
	if requested_open or approach.intersects(player_rect) or bounds.intersects(player_rect):
		release_remaining = close_delay
		if not active: set_open(true)
	elif active:
		release_remaining = maxf(0.0, release_remaining-delta)
		if release_remaining == 0: set_open(false)

func direction_axis() -> Vector2:
	match pass_direction:
		"left": return Vector2.LEFT
		"up": return Vector2.UP
		"down": return Vector2.DOWN
		_: return Vector2.RIGHT

func _draw() -> void:
	if gate_mode != "directional": return
	var axis := direction_axis()
	var center := bounds.get_center()
	var side := axis.orthogonal()
	var extent := absf(bounds.size.dot(axis))*0.5+8.0
	var entry := center-axis*extent
	draw_polyline(PackedVector2Array([entry-axis*4+side*5,entry+axis*3,entry-axis*4-side*5]),Color("e4bc79"),2.0)
	var exit := center+axis*extent
	draw_line(exit-side*5,exit+side*5,Color("957667"),3.0)

func result_at_terminal(kind: String) -> bool:
	return kind == "open_gate" and active

func install_terminal(kind: String) -> void:
	if kind == "open_gate": element_restore({"active":true})
