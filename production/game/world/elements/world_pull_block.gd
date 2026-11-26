class_name WorldPullBlock
extends Node2D

@export var element_id := ""
@export var section_id := "main"
@export_enum("attempt") var state_scope := "attempt"
@export var endpoint := Vector2(192,0)
@export var body_size := Vector2(96,64)
@export var ring_offset := Vector2(0,-44)
@export var ring_radius := 12.0
@export var rest_progress := 0.0
@export var pull_speed := 128.0
@export var return_speed := 64.0
@export var return_delay_s := 0.50
var origin := Vector2.ZERO
var progress := 0.0
var stage := "rest"
var wait_left := 0.0
var blocked := false
var time_scale := 1.0
var controller: PlayerController
var ring: PullRing
var block_body: AnimatableBody2D
var body_shape: CollisionShape2D
var geometry: RectangleShape2D

class PullRing extends Area2D:
	var block: WorldPullBlock
	var session := ""
	var holder: TraversalAbility

	func is_pull_ring() -> bool:
		return true

	func must_release(ability: TraversalAbility) -> bool:
		var motor := ability.controller.motor
		if block.supports(motor): return true
		if not ability.wall_enabled or motor.grounded_contact() or not motor.wall_contact(): return false
		return motor.get_wall_normal().x * ability.controller.router.axis < -.1

	func hook_begin(ability: TraversalAbility, token: String) -> bool:
		if not session.is_empty() or block.supports(ability.controller.motor): return false
		holder = ability
		session = token
		block.stage = "linked"
		block.wait_left = 0
		return true

	func hook_end(token: String) -> void:
		if token == "" or token != session: return
		session = ""
		holder = null
		block.begin_return()

func _ready() -> void:
	block_body = AnimatableBody2D.new()
	origin = position
	progress = rest_progress*endpoint.length()
	block_body.position = endpoint.normalized()*progress
	block_body.set_meta("pull_block",true)
	block_body.collision_layer = 1
	block_body.collision_mask = 1
	body_shape = TraversalMechanism.rectangle(block_body,body_size)
	add_child(block_body)
	geometry = body_shape.shape
	ring = PullRing.new()
	ring.block = self
	ring.position = ring_offset
	ring.collision_layer = 8
	ring.collision_mask = 0
	var capture := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = ring_radius
	capture.shape = circle
	ring.add_child(capture)
	ring.add_to_group(&"grapple_target")
	block_body.add_child(ring)
	process_physics_priority = 700

func element_bind(context: Dictionary) -> void:
	controller = context.controller

func supports(motor: PlayerMotor) -> bool:
	for i: int in motor.get_slide_collision_count():
		var hit := motor.get_slide_collision(i)
		if hit.get_normal().y >= -.7: continue
		var support := hit.get_collider() as PhysicsBody2D
		var excluded: Array[RID] = [motor.get_rid()]
		while support != null:
			if support == block_body: return true
			# A stack of physical cargo can transmit the rider's load too.
			var crate := support.get_parent() as WorldPushCrate
			if crate == null or not crate.grounded or support.get_rid() in excluded: break
			excluded.append(support.get_rid())
			var query := PhysicsShapeQueryParameters2D.new()
			var feet := RectangleShape2D.new()
			feet.size = Vector2(crate.body_size.x-0.1,1)
			query.shape = feet
			query.transform = support.global_transform
			query.transform.origin.y += crate.body_size.y*.5+.25
			query.collision_mask = 1
			query.exclude = excluded
			var supports_below := get_world_2d().direct_space_state.intersect_shape(query)
			support = null
			for below: Dictionary in supports_below:
				if below.collider == block_body: return true
				if below.collider.get_parent() is WorldPushCrate: support = below.collider
	return false

func begin_return() -> void:
	wait_left = return_delay_s
	stage = "rest" if is_equal_approx(progress,rest_progress*endpoint.length()) else "return_wait"

func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller) or not controller.active or time_scale <= 0: return
	var dt := delta*time_scale
	if stage == "return_wait":
		var elapsed := minf(dt,wait_left)
		wait_left -= elapsed
		dt -= elapsed
		if wait_left > 0: return
		stage = "returning"
	if stage not in ["linked","returning"]: return
	var axis := endpoint.normalized()
	var target := rest_progress*endpoint.length()
	var speed := return_speed
	if stage == "linked":
		var source := controller.motor.global_position+Vector2(0,-6)
		target = clampf((get_parent().to_local(source)-origin-ring_offset).dot(axis),0,endpoint.length())
		speed = pull_speed
	var next := move_toward(progress,target,speed*dt)
	var move := axis*(next-progress)
	if move.is_zero_approx(): return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = geometry
	query.transform = body_shape.global_transform
	query.motion = move
	query.collision_mask = 1
	query.exclude = [block_body.get_rid()]
	var motor := controller.motor
	var supported := supports(motor)
	if supported: query.exclude = [block_body.get_rid(),motor.get_rid()]
	var safe := get_world_2d().direct_space_state.cast_motion(query)[0]
	var rider_hit := KinematicCollision2D.new()
	if supported and motor.test_move(motor.global_transform,move,rider_hit):
		if rider_hit.get_collider() != block_body: safe = minf(safe,rider_hit.get_travel().length()/move.length())
	blocked = safe < 1
	progress += (next-progress)*safe
	block_body.position = axis*progress
	if stage == "returning" and is_equal_approx(progress,target): stage = "rest"
	queue_redraw()

func reset_attempt() -> void:
	if is_instance_valid(ring.holder) and ring.holder.hook_target == ring: ring.holder.cancel()
	ring.session = ""
	ring.holder = null
	progress = rest_progress*endpoint.length()
	block_body.position = endpoint.normalized()*progress
	stage = "rest"
	blocked = false
	wait_left = 0
	queue_redraw()

func set_equipment_time(scale: float) -> void:
	time_scale = scale

func element_state() -> Dictionary:
	return {"phase":stage,"progress":progress,"wait":wait_left,"blocked":blocked,"session":ring.session}

func element_restore(data: Dictionary) -> void:
	progress = data.progress
	wait_left = data.wait
	blocked = data.blocked
	stage = data.phase
	block_body.position = endpoint.normalized()*progress
	if stage == "linked" and (ring.session != data.session or not is_instance_valid(ring.holder)): begin_return()

func _draw() -> void:
	var start := Vector2.ZERO
	draw_line(start,start+endpoint,Color("6a6255"),4)
	draw_set_transform(endpoint.normalized()*progress,0)
	draw_rect(Rect2(-body_size*.5,body_size),Color("555d62"))
	draw_rect(Rect2(-body_size*.5,body_size),Color("b39c77"),false,2)
	draw_line(Vector2(0,-body_size.y*.5),ring_offset,Color("a38151"),3)
	draw_arc(ring_offset,ring_radius,0,TAU,24,Color("fed58a") if stage=="linked" else Color("bda572"),3)
