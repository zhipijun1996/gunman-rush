extends RefCounted
const PLAYER := preload("res://scenes/player/player.tscn")
const MODULE := preload("res://scenes/generation/modules/windchime_trial.tscn")
var tree: SceneTree
var check: Callable
var world: Node2D
var motor: PlayerMotor
var controller: PlayerController
var scope: DemoLifetime
var latches: Array[ShotLatch]
var ticks := 0
var policy: FrameDamagePolicy
func run(scene_tree: SceneTree, assertion: Callable) -> void:
	tree = scene_tree
	check = assertion
	await create_fixture()
	check.call(latches[0].gate_body.collision_layer == 1 and not latches[0].gate_shape.disabled and latches[0].bell_body.collision_layer == 8, "windchime has a real solid door and a shot-only bell collision layer")
	await walk_to(450, 100)
	check.call(motor.position.x < 450 and motor.position.x > 440, "closed door physically blocks Motor before any switch opens")
	await walk_to(190)
	controller.router.request_action(&"shoot_release", Vector2.UP)
	await frames(24)
	check.call(not latches[0].is_open, "real projectile that misses bell cannot open gate")
	await walk_to(190)
	controller.router.request_action(&"shoot_release", (latches[0].bell_position - motor.position).normalized())
	await frames(25)
	check.call(latches[0].is_open and latches[0].open_count == 1 and latches[0].health.terminal, "real Router release projectile physically hits bell and opens first door once")
	check.call(latches[0].gate_shape.disabled and latches[0].gate_body.collision_layer == 0, "deferred opening actually removes door collision")
	await walk_to(730)
	check.call(motor.position.x > 720, "actual Motor crosses the opened first gate without teleport or position fixture")
	# Fire diagonally from a safe bank before jumping: no precision-frame demand.
	controller.router.request_action(&"shoot_release", (latches[1].bell_position - motor.position).normalized())
	await frames(25)
	check.call(latches[1].is_open, "bank-origin real projectile reaches the well bell before committing to jump")
	await walk_to(730)
	controller.router.set_move_axis(1.0)
	controller.router.set_jump_held(&"keyboard_mouse", true)
	await frames(12)
	var before_y := motor.position.y
	controller.router.request_action(&"shoot_release", Vector2.DOWN)
	await frames(10)
	check.call(motor.position.y < before_y - 100, "actual downward release shot gives existing aerial upward recoil during the gap jump")
	controller.router.set_jump_held(&"keyboard_mouse", false)
	await walk_to(1160, 300)
	await frames(30)
	check.call(motor.position.x > 1150 and motor.is_on_floor() and controller.actor_resources.health.current == 5.0, "real one-jump Motor route crosses both open doors and well to exit without damage")
	check.call(latches[1].open_count == 1, "repeated physical downward shots do not reopen or duplicate switch settlement")
	# Selective return keeps switch instances while invalidating actor requests.
	var segment := SegmentRespawn.new()
	segment.configure(controller, scope)
	segment.add_anchor(&"safe", Vector2(620,582))
	check.call(segment.activate_anchor(&"safe") and segment.return_to_anchor(), "windchime fixture uses actual validated SegmentRespawn")
	check.call(latches[0].is_open and latches[1].is_open and latches[0].open_count == 1, "selective segment return preserves opened doors without scene reset")
	await dispose()
	# Combination route: second door stays closed until this aerial down shot.
	await create_fixture()
	await walk_to(190)
	controller.router.request_action(&"shoot_release", (latches[0].bell_position-motor.position).normalized())
	await frames(25)
	await walk_to(730)
	check.call(not latches[1].is_open, "combo route reaches the well with second gate still closed")
	controller.router.set_move_axis(1.0)
	controller.router.set_jump_held(&"keyboard_mouse", true)
	await frames(12)
	var combo_y := motor.position.y
	controller.router.request_action(&"shoot_release", Vector2.DOWN)
	await frames(10)
	check.call(latches[1].is_open and latches[1].open_count == 1 and motor.position.y < combo_y-100, "the SAME actual aerial downward shot hits bell opens gate and produces upward recoil")
	controller.router.set_jump_held(&"keyboard_mouse", false)
	await walk_to(1160,300)
	await frames(30)
	check.call(motor.position.x>1150 and motor.is_on_floor() and controller.actor_resources.health.current==5.0, "combined shot-and-recoil route physically lands and clears both gates without damage")
	check.call(latches[1]._eligible_shots.is_empty(), "opened latch clears its projectile eligibility ledger")
	await dispose()
	# Wall-blocked projectile fixture proves world geometry remains authoritative.
	await create_fixture()
	var wall := StaticBody2D.new()
	wall.position = Vector2(210, 500)
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16, 200)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	world.add_child(wall)
	await frames(2)
	controller.router.request_action(&"shoot_release", (latches[0].bell_position - motor.position).normalized())
	await frames(25)
	check.call(not latches[0].is_open, "a real blocking wall consumes projectile before it reaches the bell")
	await dispose()
	await create_fixture()
	controller.router.request_action(&"shoot_release", Vector2.UP)
	await frames(1)
	check.call(not latches[0]._eligible_shots.is_empty(), "live projectile records bounded switch eligibility")
	await frames(135)
	check.call(latches[0]._eligible_shots.is_empty() and not latches[0].is_open, "unopened switch expires missed projectile eligibility after configured projectile lifetime")
	await dispose()
	# Pending request fixtures verify cancellation around deferred collision work.
	for mode: String in ["return", "end", "cancel", "pending_cancel", "death"]:
		await create_fixture()
		controller.router.request_action(&"shoot_release", Vector2.RIGHT)
		await frames(1)
		var latch := latches[0]
		var context := {"amount": 1.0, "event_id": mode, "session_id": controller.session_id, "shot_id": controller.shoot_ability._shot_serial, "source_faction": &"player", "source_actor_id": motor.get_instance_id(), "target_actor_id": latch.receiver.actor_id, "target_epoch": latch.health.epoch}
		check.call(latch.receiver.receive_damage(context), "eligible pending shot fixture accepted before " + mode)
		var request := latch._pending.duplicate()
		if mode == "return":
			scope.invalidate_actor()
		elif mode == "end":
			scope.end()
		elif mode == "cancel":
			latch.cancel()
		elif mode == "pending_cancel":
			latch.cancel_pending()
		else:
			controller.die()
		latch._commit_open(request)
		check.call(not latch.is_open and not latch.gate_shape.disabled, "deferred request revalidates life and cannot open after " + mode)
		await dispose()

func create_fixture() -> void:
	world = Node2D.new()
	tree.root.add_child(world)
	var module: PlatformingModule = MODULE.instantiate()
	world.add_child(module)
	motor = PLAYER.instantiate()
	motor.position = Vector2(120, 582)
	world.add_child(motor)
	controller = motor.get_node("Controller")
	controller.set_physics_process(false)
	scope = DemoLifetime.new()
	policy = FrameDamagePolicy.new()
	policy.lifetime = scope
	world.add_child(policy)
	policy.register_target(&"player", controller.actor_resources.health, true)
	var danger := DemoContactEmitter.new()
	danger.policy = policy
	danger.controller = controller
	danger.kind = DamageRequest.Kind.ENVIRONMENT
	danger.position = Vector2(640,705)
	danger.half_size = Vector2(640,15)
	world.add_child(danger)
	latches = []
	for data: Array in [[Vector2(270,535),Rect2(460,330,24,270)], [Vector2(790,640),Rect2(960,330,24,270)]]:
		var latch := ShotLatch.new()
		world.add_child(latch)
		latch.setup(controller, scope, data[0], data[1])
		latches.append(latch)
	await frames(3)
func frames(count: int) -> void:
	for _i: int in count:
		await tree.physics_frame
		controller.physics_tick(1.0/60.0)
		ticks += 1
func walk_to(x: float, limit: int = 240) -> void:
	for _i: int in limit:
		controller.router.set_move_axis(clampf((x-motor.position.x)/5.0,-1.0,1.0))
		await frames(1)
		if absf(motor.position.x-x)<2.0 and motor.is_on_floor():
			break
	controller.router.set_move_axis(0.0)
func dispose() -> void:
	controller.router.clear("fixture_end")
	controller.active = false
	controller.shoot_ability.clear_projectiles()
	for latch: ShotLatch in latches:
		latch.cancel()
	scope.end()
	world.queue_free()
	await tree.physics_frame
	await tree.physics_frame
