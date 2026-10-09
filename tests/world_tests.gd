class_name WorldTests
extends RefCounted

const PLAYER := preload("res://scenes/player/player.tscn")
const DT := 1.0 / 60.0
var tree: SceneTree
var check: Callable
var world: Node2D
var motor: PlayerMotor
var controller: PlayerController
var context: WorldContext

func fixture(location: Vector2 = Vector2(80, 150), floor_y: float = 200.0) -> void:
	if is_instance_valid(world):
		world.free()
	world = Node2D.new()
	tree.root.add_child(world)
	platform(Rect2(0, floor_y, 600, 30))
	context = WorldContext.new()
	world.add_child(context)
	context.set_physics_process(false)
	motor = PLAYER.instantiate()
	motor.position = location
	world.add_child(motor)
	controller = motor.get_node("Controller") as PlayerController
	controller.set_physics_process(false)
	context.register_actor(controller, location)
	await tree.physics_frame

func platform(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	return body

func ticks(count: int) -> void:
	for index: int in count:
		await tree.physics_frame
		controller.physics_tick(DT)

func recharge(location: Vector2) -> RechargePoint:
	var point := RechargePoint.new()
	point.position = location
	world.add_child(point)
	point.setup(context)
	return point

func run(scene_tree: SceneTree, assertion: Callable) -> void:
	tree = scene_tree
	check = assertion
	await fixture()
	await ticks(30)
	var point := recharge(motor.position)
	point.set_physics_process(false)
	controller.action_resources.shot_charges = 0
	check.call(not point.try_touch(controller), "grounded contact cannot recharge")
	controller.router.request_action(&"jump")
	await ticks(1)
	controller.action_resources.shot_charges = controller.motor.tuning.max_air_shots
	check.call(not point.try_touch(controller) and point.active, "full resource leaves recharge active")
	controller.action_resources.shot_charges = 0
	controller.shoot_ability.cooldown_remaining = 0.3
	var jump_count := controller.jump_ability.used_jumps
	check.call(point.try_touch(controller), "air recharge queues reward")
	check.call(not point.try_touch(controller), "duplicate trigger queues only one reward")
	check.call(controller.action_resources.shot_charges == 0 and point.active, "reward defers to next controller tick")
	await ticks(1)
	check.call(controller.action_resources.shot_charges == 1 and not point.active, "successful reward consumes one-shot point")
	check.call(controller.jump_ability.used_jumps == jump_count and controller.shoot_ability.cooldown_remaining > 0.25, "recharge preserves jumps and cooldown")
	context.respawn()
	check.call(point.active and controller.active, "checkpoint respawn reactivates recharge")
	await ticks(30)
	controller.router.request_action(&"jump")
	await ticks(1)
	controller.action_resources.shot_charges = 0
	point.try_touch(controller)
	controller.die()
	check.call(point.active and controller.action_resources.shot_charges == 0, "death before reward resolution never consumes point or grants resource")
	context.respawn()
	controller.action_resources.shot_charges = 0
	controller.queue_grant(1, controller.session_id - 1)
	await ticks(1)
	check.call(controller.action_resources.shot_charges == 0, "old session reward is rejected")
	var twin := recharge(Vector2(400, 80))
	point.deactivate()
	check.call(twin.active, "two recharge instances keep independent state")
	await fixture(Vector2(80,80), 500)
	var unloaded_point := recharge(motor.position)
	unloaded_point.set_physics_process(false)
	controller.action_resources.shot_charges = 0
	check.call(unloaded_point.try_touch(controller), "unload regression starts with queued recharge")
	unloaded_point.free()
	await ticks(1)
	check.call(controller.action_resources.shot_charges == 0, "unloaded recharge source cannot grant queued reward")
	check.call(context.objects.is_empty(), "unloaded world object unregisters without old subscriptions")
	print("PASS GROUP: deferred airborne recharge, resource-full/death/old-session/unload guards")

	check.call(SawHazard.swept_contact(Vector2(-100,0),Vector2(100,0),Vector2(12,18),24), "hazard sweep catches high-speed crossing")
	check.call(SawHazard.swept_contact(Vector2(-100,41),Vector2(100,41),Vector2(12,18),24), "hazard sweep includes circular collision radius")
	check.call(not SawHazard.swept_contact(Vector2(-100,44),Vector2(100,44),Vector2(12,18),24), "hazard sweep rejects outside circle edge")
	check.call(not SawHazard.swept_contact(Vector2(35,41),Vector2(40,45),Vector2(12,18),24), "rounded hazard volume rejects expanded-box corner false positive")
	await fixture(Vector2(80,100), 500)
	var saw := SawHazard.new()
	saw.position = Vector2(180,100)
	world.add_child(saw)
	saw.setup(context)
	saw.set_physics_process(false)
	saw._physics_process(DT)
	motor.position = Vector2(280,100)
	saw._physics_process(DT)
	check.call(not controller.active, "real registered actor crossing hazard dies even with no end overlap")
	context.respawn()
	saw.deactivate()
	motor.position = saw.position
	saw._physics_process(DT)
	check.call(controller.active, "disabled hazard does not kill")
	var switch := WorldSwitch.new()
	switch.mechanism = saw
	world.add_child(switch)
	switch.setup(context)
	saw.activate()
	switch._on_body(motor)
	check.call(switch.triggered and not saw.active, "independent pressure switch disables referenced mechanism")
	context.clock = 1.5
	context.respawn()
	check.call(context.clock == 0.0 and saw.active and not switch.triggered, "retry restores deterministic mechanism phase and local switch state")
	print("PASS GROUP: swept hazards, local switch composition, deterministic reset")

	await fixture(Vector2(80,150))
	await ticks(30)
	var checkpoint := SafeCheckpoint.new()
	checkpoint.position = Vector2(80,182)
	world.add_child(checkpoint)
	checkpoint.setup(context)
	checkpoint.set_physics_process(false)
	check.call(checkpoint.try_activate(controller), "safe standing zone activates checkpoint")
	controller.die()
	for index: int in 10:
		context._physics_process(DT)
	check.call(controller.active and motor.position.distance_to(checkpoint.position) < 0.01, "checkpoint restores playable actor within configured 0.15s")
	check.call(controller.action_resources.shot_charges == motor.tuning.max_air_shots and motor.normal_velocity == Vector2.ZERO and motor.recoil_velocity == Vector2.ZERO, "respawn restores resources and clears motion")
	await ticks(30)
	var airborne_checkpoint := SafeCheckpoint.new()
	airborne_checkpoint.position = motor.position
	world.add_child(airborne_checkpoint)
	airborne_checkpoint.setup(context)
	airborne_checkpoint.set_physics_process(false)
	controller.router.request_action(&"jump")
	await ticks(1)
	check.call(not airborne_checkpoint.try_activate(controller), "airborne overlap cannot activate checkpoint")
	await fixture(Vector2(580,150))
	await ticks(30)
	var void_checkpoint := SafeCheckpoint.new()
	void_checkpoint.position = Vector2(620,182)
	world.add_child(void_checkpoint)
	void_checkpoint.setup(context)
	void_checkpoint.set_physics_process(false)
	check.call(not void_checkpoint.try_activate(controller), "player standing inside wide zone cannot activate unsupported spawn")
	await fixture(Vector2(80,150))
	await ticks(30)
	platform(Rect2(103,130,15,70))
	var wall_checkpoint := SafeCheckpoint.new()
	wall_checkpoint.position = Vector2(100,182)
	world.add_child(wall_checkpoint)
	wall_checkpoint.setup(context)
	wall_checkpoint.set_physics_process(false)
	await tree.physics_frame
	check.call(not wall_checkpoint.try_activate(controller), "standing actor cannot activate spawn embedded in wall")
	await fixture(Vector2(80,150))
	await ticks(30)
	platform(Rect2(95,165,30,5))
	var ceiling_checkpoint := SafeCheckpoint.new()
	ceiling_checkpoint.position = Vector2(100,182)
	world.add_child(ceiling_checkpoint)
	ceiling_checkpoint.setup(context)
	ceiling_checkpoint.set_physics_process(false)
	await tree.physics_frame
	check.call(not ceiling_checkpoint.try_activate(controller), "standing actor cannot activate spawn under intersecting low ceiling")
	print("PASS GROUP: shape/ray-verified safe checkpoint and bounded quick respawn")

	await fixture(Vector2(80,70), 250)
	var one_way := OneWayPlatform.new()
	one_way.position = Vector2(80,150)
	world.add_child(one_way)
	await ticks(40)
	check.call(motor.is_on_floor() and motor.position.y < 140, "player stands on independent one-way platform")
	check.call(motor.request_drop_through(), "drop request ignores only standing one-way body")
	await ticks(40)
	check.call(motor.is_on_floor() and motor.position.y > 220 and motor.position.y < 235, "drop retains world collision and lands on solid floor")
	check.call(not motor.request_drop_through(), "solid floor cannot be dropped through")
	check.call(motor.get_collision_exceptions().is_empty(), "one-way exception clears after entire body descends")
	controller.reset_at(Vector2(80,70))
	await ticks(40)
	motor.request_drop_through()
	controller.reset_at(Vector2(80,70))
	check.call(motor.get_collision_exceptions().is_empty(), "respawn clears one-way collision exception")
	await ticks(40)
	check.call(motor.position.y < 140, "one-way platform collides again after respawn")
	print("PASS GROUP: per-platform drop through preserves ordinary world terrain")
	world.free()
