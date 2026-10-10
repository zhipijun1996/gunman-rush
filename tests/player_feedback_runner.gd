extends SceneTree
const PLAYER := preload("res://scenes/player/player.tscn")
const DT := 1.0 / 60.0
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0, 200)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4000, 40)
	shape.shape = rectangle
	floor_body.add_child(shape)
	world.add_child(floor_body)
	var motor: PlayerMotor = PLAYER.instantiate()
	motor.position = Vector2(0, 130)
	world.add_child(motor)
	var controller: PlayerController = motor.get_node("Controller")
	controller.set_physics_process(false)
	var feedback: PlayerFeedback = motor.get_node("PlayerFeedback")
	await physics_frame
	for tick: int in 30:
		await physics_frame
		controller.physics_tick(DT)
	check(motor.is_on_floor(), "actual collision establishes grounded contact")
	check(is_equal_approx(motor.tuning.focus_time_scale, 0.2), "focus uses requested twenty percent timescale")
	var start := motor.position.x
	check(controller.shoot_ability.try_fire(Vector2.LEFT, true), "grounded shot fires normally")
	check(is_equal_approx(motor.recoil_velocity.x, 715.0), "ground shot samples reduced recoil at fire instant")
	for tick: int in 9:
		await physics_frame
		motor.step(0.0, DT)
	check(absf(motor.position.x - start - 100.1) < 0.2, "real grounded burst travels reduced 100.1 units")
	motor.reset_at(Vector2(0, -100))
	await physics_frame
	motor.step(0.0, DT)
	check(not motor.is_on_floor(), "real airborne fixture has no floor contact")
	controller.shoot_ability.cooldown_remaining = 0.0
	controller.action_resources.reset()
	start = motor.position.x
	check(controller.shoot_ability.try_fire(Vector2.LEFT, false), "airborne shot fires normally")
	check(is_equal_approx(motor.recoil_velocity.x, 1100.0), "airborne recoil retains original full burst speed")
	for tick: int in 9:
		await physics_frame
		motor.step(0.0, DT)
	check(absf(motor.position.x - start - 154.0) < 0.2, "real airborne burst retains 154-unit distance")
	motor.reset_at(Vector2(0, 130))
	controller._was_grounded = false
	for tick: int in 30:
		await physics_frame
		controller.physics_tick(DT)
	controller.shoot_ability.cooldown_remaining = 0.0
	controller.router.request_action(&"jump")
	controller.router.request_action(&"shoot_release", Vector2.DOWN)
	controller.physics_tick(DT)
	check(absf(motor.recoil_velocity.y + 1100.0) < 0.01, "same-frame jump and fire retains airborne strength despite old contact cache")
	motor.clear_recoil()
	feedback.max_particles = 12
	for index: int in 20:
		feedback._shot(Vector2.RIGHT, index)
	check(feedback._particles.size() <= 12, "presentation pool remains bounded during fire spam")
	feedback.effects_enabled = false
	feedback._shot(Vector2.DOWN, 99)
	check(feedback._particles.is_empty(), "low effects mode stops and clears particles")
	var motion := motor.normal_velocity
	var recoil := motor.recoil_velocity
	feedback.effects_enabled = true
	feedback._land()
	check(motor.normal_velocity == motion and motor.recoil_velocity == recoil, "cosmetic landing does not mutate motor")
	feedback.clear()
	controller.router.request_action(&"shoot_release", Vector2.DOWN)
	controller.router.clear("focus_lost")
	controller.physics_tick(DT)
	check(motor.recoil_velocity.is_zero_approx() and feedback._particles.is_empty(), "cancelled fire request produces neither recoil nor muzzle particles")
	var camera := StageCameraRig.new()
	world.add_child(camera)
	camera.configure(motor, Rect2(-2000, -2000, 4000, 4000))
	check(camera.zoom == Vector2(1.6, 1.6), "viewing proportion increases without changing player body")
	check((motor.get_node("CollisionShape2D").shape as RectangleShape2D).size == Vector2(24, 36), "player physics dimensions remain invariant")
	world.free()
	print("PLAYER FEEDBACK: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
