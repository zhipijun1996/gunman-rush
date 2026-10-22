extends SceneTree
## Focused actual App lifecycle checks; damage is an explicit policy fixture.
var app: DemoApp
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)
func ticks(count: int) -> void:
	for tick: int in count:
		await physics_frame
		await process_frame
func body() -> UnderworldPlayer:
	return app.player.get_node("PixelPlainsActor") as UnderworldPlayer
func anchor() -> CourierVisual:
	return app.player.get_node("CourierVisual") as CourierVisual
func damage_request(id: StringName) -> DamageRequest:
	var request := DamageRequest.new()
	request.token = app.lifetime.token()
	request.event_id = id
	request.source_id = &"explicit_presentation_lifecycle_fixture"
	request.target_id = &"player"
	request.amount = 1
	request.health_epoch = app.controller.actor_resources.health.epoch
	request.actor_epoch = app.lifetime.actor_epoch
	request.hit_direction = Vector2.RIGHT
	return request

func run() -> void:
	app = DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	check(app.start_plains("underworld-formal-integrated"), "actual formal entry")
	# Observe the actual authored spawn protection; do not bypass its timer.
	await ticks(48)
	app.player.get_node("KeyboardMouseAdapter").process_mode = Node.PROCESS_MODE_DISABLED
	check(body() is UnderworldPlayer and not anchor().visible, "actual sole visible body and hidden authoritative anchor")
	check(app.player.get_node("PlayerVisualAdapter").process_mode == Node.PROCESS_MODE_DISABLED, "actual pixel consumer disables Adapter processing")
	check(anchor().state == &"idle", "initial segment entry cannot leave hidden anchor hurt")
	app.controller.router.request_action(&"shoot_release", Vector2.UP)
	await ticks(2)
	check(anchor().state == &"recoil" and body()._anchor_recoil_remaining > 0, "real accepted shot retains existing recoil window")
	var hurt := damage_request(&"anchor_interrupt")
	check(app.policy.submit(hurt), "real policy accepts nonterminal fixture")
	await ticks(2)
	check(body()._hurt_remaining > 0 and anchor().state == &"hurt", "committed hurt interrupts hidden recoil")
	check(body()._anchor_recoil_remaining == 0, "hurt cancels pending recoil recovery")
	var hurt_age := body()._hurt_remaining
	var anchor_age := anchor().elapsed
	paused = true
	for tick: int in 8: await process_frame
	check(body()._hurt_remaining == hurt_age and anchor().elapsed == anchor_age, "pause freezes visible hurt and hidden attachment timeline")
	paused = false
	await ticks(24)
	check(body()._hurt_remaining == 0 and anchor().state == &"idle", "accepted hurt recovers both actual layers")
	check(not app.policy.submit(hurt), "duplicate damage cannot replay presentation")
	var stale := damage_request(&"anchor_stale")
	stale.health_epoch -= 1
	check(not app.policy.submit(stale), "stale health epoch rejected by actual policy")
	var hurt_count := body()._accepted_hurt_count
	await ticks(18)
	check(body()._accepted_hurt_count == hurt_count and anchor().state == &"idle", "refused damage cannot restart feedback")
	# Configured-off counterexample demonstrates the original signal-only residue.
	body().recover_weapon_anchor = false
	check(app.policy.submit(damage_request(&"anchor_disabled_counterexample")), "second distinct lifecycle fixture accepted")
	await ticks(28)
	check(body()._hurt_remaining == 0 and anchor().state == &"hurt", "configured-off negative control reproduces old stale anchor")
	body().recover_weapon_anchor = true
	await ticks(2)
	check(anchor().state == &"idle", "re-enabling recovery clears stale pose without damage writes")
	app.controller.router.request_action(&"shoot_release", Vector2.UP)
	await ticks(2)
	check(body()._anchor_recoil_remaining > 0, "second real accepted shot begins recoil")
	check(app.controller.return_to_segment(app.player.position), "accepted explicit same-location segment lifecycle fixture")
	await ticks(2)
	check(body()._anchor_recoil_remaining == 0 and anchor().state == &"idle", "accepted session/return cancels old recoil without replay")
	await ticks(16)
	var previous_id := body().get_instance_id()
	var old_request := damage_request(&"anchor_previous_run")
	var terminal := damage_request(&"anchor_terminal")
	terminal.amount = app.controller.actor_resources.health.current
	check(app.policy.submit(terminal), "real policy accepts terminal fixture")
	await ticks(8)
	check(not is_instance_valid(app.player) and is_instance_valid(app.home_scene), "actual terminal consumer unloads run and returns Home")
	var home_body := app.home_scene.player.get_node("UnderworldPlayer") as UnderworldPlayer
	check(home_body._anchor_recoil_remaining == 0 and (app.home_scene.player.get_node("CourierVisual") as CourierVisual).state == &"idle", "new actual Home body has no previous actor effect")
	check(app.start_plains("underworld-formal-integrated"), "actual second run accepted")
	await ticks(10)
	check(body().get_instance_id() != previous_id and body()._anchor_recoil_remaining == 0, "new run owns fresh presentation state")
	check(not app.policy.submit(old_request), "previous run token cannot affect new actual consumer")
	check(anchor().state == &"idle" and body()._accepted_hurt_count == 0, "new actual consumer remains neutral after old-token refusal")
	app.abandon_run()
	await ticks(4)
	check(await load("res://tests/audio_teardown.gd").drain_world(app), "actual consumers drain audio")
	app.free()
	for tick: int in 6: await process_frame
	DirAccess.make_dir_recursive_absolute("res://build/player-presentation-01")
	FileAccess.open("res://build/player-presentation-01/anchor-tests.json", FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "scope": "Actual App lifecycle policy fixture and configured-off counterexample; no natural combat/visual/user/device acceptance"}, "\t"))
	print("PLAYER ANCHOR TESTS: checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
