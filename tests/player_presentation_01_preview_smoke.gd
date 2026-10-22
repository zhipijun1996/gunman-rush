extends SceneTree
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
func run() -> void:
	var preview := load("res://scenes/dev/player_presentation_01.tscn").instantiate() as DemoApp
	root.add_child(preview)
	await ticks(60)
	check(preview.lifetime.active and preview.stage is PlainsRegionStage, "standalone Preview starts actual formal Plains")
	check(not preview.meta_persistence_enabled, "standalone Preview preserves session-only meta")
	check(preview.stage.generated.manifest.seed == "underworld-formal-integrated", "standalone Preview freezes actual root Seed")
	var motor := preview.player
	var renderer := motor.get_node("PixelPlainsActor") as UnderworldPlayer
	check(renderer != null and renderer.recover_weapon_anchor, "standalone Preview uses real candidate renderer")
	motor.get_node("KeyboardMouseAdapter").process_mode = Node.PROCESS_MODE_DISABLED
	var start := motor.position
	preview.controller.router.set_move_axis(.55)
	await ticks(10)
	preview.controller.router.set_move_axis(0)
	check(motor.position.x > start.x + 10, "standalone Preview moves only via actual Router/Motor")
	preview.call("_toggle_recovery")
	check(not renderer.recover_weapon_anchor, "standalone Preview switch reaches actual consumer")
	preview.call("_sample_hurt")
	await ticks(28)
	check(renderer._accepted_hurt_count == 1 and renderer._hurt_remaining == 0, "standalone Preview applies and recovers explicit policy fixture damage")
	check((motor.get_node("CourierVisual") as CourierVisual).state == &"hurt", "standalone Preview disabled mode reproduces old anchor state")
	preview.call("_toggle_recovery")
	await ticks(3)
	check((motor.get_node("CourierVisual") as CourierVisual).state == &"idle", "standalone Preview enabled mode recovers actual anchor")
	preview.call("_restart_sample")
	await ticks(18)
	check(preview.lifetime.active and is_instance_valid(preview.player), "standalone Preview can restart its actual formal run")
	preview.abandon_run()
	await ticks(4)
	check(await load("res://tests/audio_teardown.gd").drain_world(preview), "standalone Preview audio drains")
	preview.free()
	for tick: int in 6: await process_frame
	DirAccess.make_dir_recursive_absolute("res://build/player-presentation-01")
	FileAccess.open("res://build/player-presentation-01/preview-smoke.json", FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "scope": "Native real standalone scene and actual control callbacks; not browser pointer/touch GUI, export or deployment approval"}, "\t"))
	print("PLAYER PREVIEW SMOKE: checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
