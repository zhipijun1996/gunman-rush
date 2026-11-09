extends SceneTree
## Short real Motor checks for traversal recovery, not a level route replay.
var checks := 0
var failures := 0
var fixture: RefCounted
var actor: PlayerController
var guard: WorldRecoilGuard
var refill_sources: Array[StringName] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("TRAVERSAL REFILL FAIL: ",label)

func setup() -> void:
	if fixture != null and is_instance_valid(fixture.world): fixture.world.free()
	fixture = preload("res://tests/combat_tests.gd").new()
	fixture.tree = self
	await fixture.fixture(Vector2(80,0))
	fixture.world.get_child(0).free() # No landing may hide a failed air refill.
	actor = fixture.controller
	actor.air_focus_ability.enabled = false
	guard = WorldRecoilGuard.new()
	guard.controller = actor
	fixture.world.add_child(guard)
	guard.set_physics_process(false)
	guard.owned = true
	guard.cooldown = 1.25
	refill_sources.clear()
	actor.traversal.traversal_resources_refilled.connect(func(source: StringName) -> void: refill_sources.append(source))
	await physics_frame

func deplete() -> void:
	actor.action_resources.shot_charges = 0
	actor.jump_ability.used_jumps = 2
	actor.traversal.hook_used = true
	guard.landing_ready = false

func wait_state(target: StringName, limit := 60) -> bool:
	for index: int in limit:
		if actor.traversal.state == target: return true
		await fixture.ticks(1)
	return actor.traversal.state == target

func run() -> void:
	await setup()
	actor.traversal.grant(&"grapple")
	actor.traversal.grant(&"double_jump")
	deplete()
	actor.traversal.restore_air_actions()
	check(actor.action_resources.shot_charges==0 and not guard.landing_ready,"generic D/H restore cannot refill ammo or Q")
	var anchor := GrappleAnchor.new()
	anchor.position = Vector2(160,-110)
	anchor.hang_enabled = true
	fixture.world.add_child(anchor)
	actor.traversal.hook_contact.connect(func(_point: Vector2) -> void:
		check(actor.action_resources.shot_charges==0 and not guard.landing_ready,"remote hook-head contact cannot refill"))
	await physics_frame
	actor.router.request_action(&"grapple",(anchor.position-actor.motor.position-Vector2(0,-6)).normalized())
	check(await wait_state(&"hook_hang"),"body reaches the hanging target through real Motor movement")
	check(actor.action_resources.shot_charges==2 and not actor.traversal.hook_used and actor.jump_ability.used_jumps==1,"H arrival restores current cap and owned D/H")
	check(guard.landing_ready and is_equal_approx(guard.cooldown,1.25) and refill_sources==[&"hook_arrival"],"H rearms Q once without clearing cooldown")
	deplete()
	await fixture.ticks(8)
	check(actor.action_resources.shot_charges==0 and not guard.landing_ready and refill_sources.size()==1,"staying on one hook cannot refill each frame")

	await setup()
	actor.traversal.grant(&"wall_climb")
	actor.traversal.grant(&"double_jump")
	actor.traversal.grant(&"grapple")
	var wall: StaticBody2D = fixture.body(Rect2(100,-600,24,1800))
	wall.add_to_group(&"wall_climbable")
	deplete()
	actor.router.set_move_axis(1)
	check(await wait_state(&"wall_attach"),"actual collision and inward input attach to a climbable wall")
	check(actor.action_resources.shot_charges==2 and not actor.traversal.hook_used and actor.jump_ability.used_jumps==1,"first W attachment restores current cap and owned D/H")
	check(guard.landing_ready and is_equal_approx(guard.cooldown,1.25) and refill_sources==[&"wall_attach"],"W rearms Q without clearing cooldown")
	# Fire into recoil toward the wall. The accepted shot cancels the pose but
	# the real body never clears it, so reattachment must not mint another refill.
	actor.action_resources.shot_charges = 1
	guard.cooldown = 0
	actor.router.request_action(&"shoot_release",Vector2.LEFT)
	await fixture.ticks(1)
	check(actor.action_resources.shot_charges==0 and not guard.landing_ready,"accepted wall shot consumes ammo and Q readiness")
	check(await wait_state(&"wall_attach"),"blocked recoil returns to wall attachment")
	check(actor.action_resources.shot_charges==0 and not guard.landing_ready and refill_sources.size()==1,"same-wall pose cancellation cannot refill")
	actor.traversal.hook_used = true
	actor.jump_ability.used_jumps = 2
	actor.router.request_action(&"jump")
	await fixture.ticks(1)
	check(actor.action_resources.shot_charges==0 and not guard.landing_ready and not actor.traversal.hook_used and actor.jump_ability.used_jumps==1,"wall kick restores D/H only")
	await fixture.ticks(12)
	check(await wait_state(&"wall_attach"),"real wall kick separates and returns")
	check(actor.action_resources.shot_charges==2 and guard.landing_ready and refill_sources.size()==2 and guard.cooldown>0,"actual separation rearms the next wall refill while Q cooldown survives")

	await setup()
	actor.traversal.grant(&"wall_climb")
	fixture.body(Rect2(100,-600,24,1800))
	deplete()
	actor.router.set_move_axis(1)
	await fixture.ticks(10)
	check(actor.motor.is_on_wall() and actor.traversal.state!=&"wall_attach" and actor.action_resources.shot_charges==0 and not guard.landing_ready,"ordinary wall collision gives no refill")
	actor.router.set_move_axis(0)
	actor.traversal.grant(&"grapple")
	actor.traversal.hook_used = false
	actor.router.request_action(&"grapple",Vector2.LEFT)
	await fixture.ticks(55)
	check(actor.action_resources.shot_charges==0 and not guard.landing_ready and refill_sources.is_empty(),"missed hook gives no refill")
	fixture.world.free()
	print("TRAVERSAL REFILL: %s checks, %s failures" % [checks,failures])
	quit(1 if failures else 0)
