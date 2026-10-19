extends SceneTree
## Real keyboard -> Router -> Controller/Motor, two stationary rings.
## Spawn geometry and cancellation probes are fixtures, not forest route evidence.
var checks := 0
var failures := 0
var fixture: RefCounted
var actor: PlayerController
var keyboard: KeyboardMouseAdapter
var second: GrappleAnchor
var cast_count := 0
var ledger: Array[Dictionary] = []
var rejected_shots := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	ledger.append({"label":label,"passed":ok,"real_usec":Time.get_ticks_usec(),"frame":Engine.get_physics_frames()})
	if not ok:
		failures += 1
		printerr("CHAIN INPUT FAIL: " + label)
func frames(count := 1) -> void:
	for i: int in count:
		await physics_frame
		await process_frame
func wait_state(state: StringName, limit := 100) -> bool:
	for i: int in limit:
		if actor.traversal.state == state: return true
		await frames()
	return false
func mouse(down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = down
	event.position = fixture.motor.get_canvas_transform() * second.global_position
	keyboard._unhandled_input(event)
func cleanup() -> void:
	if fixture != null and is_instance_valid(fixture.world):
		if not await load("res://tests/audio_teardown.gd").drain_world(fixture.world): failures += 1
		fixture.world.free()
func setup() -> bool:
	await cleanup()
	fixture = preload("res://tests/combat_tests.gd").new()
	fixture.tree = self
	await fixture.fixture(Vector2(80, 150))
	actor = fixture.controller
	actor.traversal.grant(&"grapple")
	actor.set_physics_process(true)
	var overlay := InputSetup.attach(fixture.motor, actor.router)
	overlay.set_enabled(false)
	keyboard = fixture.motor.get_node("KeyboardMouseAdapter")
	fixture.motor.get_node("GamepadAdapter").set_physics_process(false)
	var first := GrappleAnchor.new()
	first.position = Vector2(160, -10)
	fixture.world.add_child(first)
	second = GrappleAnchor.new()
	second.position = Vector2(0, -130)
	fixture.world.add_child(second)
	cast_count = 0
	rejected_shots = 0
	actor.shoot_ability.shot_rejected.connect(func(_reason: StringName) -> void: rejected_shots += 1)
	actor.traversal.action_changed.connect(func(state: StringName) -> void:
		if state == &"hook_cast": cast_count += 1)
	await frames(2)
	actor.router.request_action(&"grapple", (first.global_position-fixture.motor.global_position-Vector2(0,-6)).normalized())
	var kicked := await wait_state(&"hook_kick")
	check(kicked and not actor.traversal.hook_used, "first ring real contact restores H and starts unchanged kick")
	return kicked
func early_release() -> void:
	# Enter the kick tail: retain a fixed aim across its remaining <=2 frames,
	# so the default 12px ring is a legal target without changing its collider.
	await frames(2)
	mouse(true)
	await frames()
	check(actor.router.aim_engaged and actor.traversal.state == &"hook_kick", "real RMB hold preaims during first ring kick")
	check(actor.traversal.guide_active and actor.traversal.guide_target_valid, "restored kick preaim displays actual second-ring guide")
	mouse(false)
	await frames()

func run() -> void:
	if await setup():
		await early_release()
		check(actor.traversal.state == &"hook_kick" and cast_count == 1, "early release does not interrupt actual first kick or cast immediately")
		var reached := false
		for i: int in 100:
			if actor.traversal.hook_target == second and actor.traversal.state == &"hook_contact_kick": reached = true; break
			await frames()
		check(reached and fixture.motor.global_position.distance_to(actor.traversal.hook_tip) <= actor.traversal.definition.hook_stop_distance+0.1, "early RMB release chains to real second-ring body contact")
		check(cast_count == 2, "buffered release casts exactly once")
	for reason: String in ["cancel", "device", "disabled", "session", "death", "shot", "queued_shot", "expired"]:
		if not await setup(): break
		await early_release()
		if reason == "cancel": actor.router.clear("chain_cancel")
		elif reason == "device": actor.router.activate_device(&"gamepad")
		elif reason == "disabled": actor.traversal.grant(&"grapple", false)
		elif reason == "session": actor.session_id += 1
		elif reason == "death": actor.die()
		elif reason == "queued_shot":
			var shot_before := actor.shoot_ability.packet_id
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = Vector2(-200, -200)
			click.pressed = true
			keyboard._unhandled_input(click)
			click.pressed = false
			keyboard._unhandled_input(click)
			await frames(2)
			check(actor.shoot_ability.packet_id == shot_before+1 and fixture.motor.recoil_burst_remaining > 0.0, "new real queued shot wins kick-end frame with actual recoil")
		elif reason == "shot":
			check(actor.shoot_ability.try_fire(Vector2.LEFT, false), "real accepted shot overrides queued H without losing recoil")
		elif reason == "expired": OS.delay_msec(125) # Explicit frame-stall TTL negative only.
		await frames(20)
		check(cast_count == 1, "pending early release is discarded on " + reason)
	if await setup():
		actor.traversal.hook_used = true # Explicit unavailable-qualification counterexample.
		check(not actor.traversal.request_hook(Vector2.RIGHT), "kick without restored H cannot buffer")
		actor.traversal.hook_used = false
		actor.traversal.cancel()
		actor.traversal.state = &"hook_pull" # Explicit other-busy-state counterexample.
		check(not actor.traversal.request_hook(Vector2.RIGHT), "non-kick busy states cannot buffer")
	await packet_envelope_negatives()
	await cleanup()
	DirAccess.make_dir_recursive_absolute("res://build/verification")
	var output := FileAccess.open("res://build/verification/grapple_chain_input.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checks,"failures":failures,"ledger":ledger}, "  "))
	output.close()
	print("GRAPPLE CHAIN INPUT: %s checks / %s failures" % [checks, failures])
	quit(1 if failures else 0)

func packet_envelope_negatives() -> void:
	if await setup():
		mouse(true)
		await frames()
		mouse(false)
		var release: Dictionary = actor.router._queue.back().duplicate(true)
		OS.delay_msec(85) # The actual Router packet ages before first consumption.
		await frames()
		var age_at_consumption := Time.get_ticks_usec()/1000000.0-float(release.timestamp)
		check(age_at_consumption >= 0.08 and age_at_consumption < InputRouter.MAX_AGE_SECONDS, "actual H packet consumed at age80-100ms before TTL")
		check(actor.traversal.state == &"hook_kick" and cast_count == 1, "aged release is consumed during real residual kick without immediate cast")
		OS.delay_msec(30) # Original packet is now older than100ms; no TTL renewal.
		await frames(20)
		check(cast_count == 1, "kick tail cannot renew original Router H packet TTL beyond100ms")
	if await setup():
		mouse(true)
		await frames()
		# Real budget API creates an empty-shot fixture, not a shot disable.
		while actor.action_resources.try_consume_shot(false): pass
		mouse(false)
		var h_sequence: int = actor.router._queue.back().sequence
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = Vector2(-200, -200)
		click.pressed = true
		keyboard._unhandled_input(click)
		click.pressed = false
		keyboard._unhandled_input(click)
		check(actor.router.sequence > h_sequence and actor.router._queue.size() == 2, "real H release then newer shot share one Controller input batch")
		await frames(20)
		check(rejected_shots == 1 and actor.shoot_ability.packet_id == 0, "same-batch empty shot is genuinely rejected without packet or recoil")
		check(cast_count == 1, "newer rejected shot still cancels older buffered H by its original sequence")
