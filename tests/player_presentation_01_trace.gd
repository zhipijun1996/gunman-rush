extends SceneTree
## Real formal App consumer. Only Router intents drive movement/shooting.
## Explicit fixture damage enters the production batched policy, not combat proof.
const SEED := "underworld-formal-integrated"
const FRAMES := 720
var app: DemoApp
var rows: Array[Dictionary] = []
var events: Array[Dictionary] = []
var failures: Array[String] = []
var output := "res://build/player-presentation-01/trace.json"
var capture := false
var accepted_shots := 0
var accepted_hurts := 0
var sampled_states: Dictionary = {}
var manifest := ""

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func serial(value: Variant) -> Variant:
	if value is Vector2: return [value.x, value.y]
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[str(key)] = serial(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(serial(item))
		return result
	return value

func fixture_damage(id: StringName, terminal := false) -> void:
	var request := DamageRequest.new()
	request.token = app.lifetime.token()
	request.event_id = id
	request.source_id = &"player_presentation_01_explicit_lifecycle_fixture"
	request.target_id = &"player"
	request.kind = DamageRequest.Kind.MONSTER
	request.amount = app.controller.actor_resources.health.current if terminal else 1.0
	request.hit_direction = Vector2.RIGHT
	request.health_epoch = app.controller.actor_resources.health.epoch
	request.actor_epoch = app.lifetime.actor_epoch
	var accepted := app.policy.submit(request)
	events.append({"tick": rows.size(), "event": "fixture_damage_submitted", "id": id, "accepted": accepted, "terminal": terminal})
	check(accepted, "explicit lifecycle fixture must enter actual policy")

func sample(tick: int) -> void:
	if not is_instance_valid(app.player):
		rows.append({"tick": tick, "consumer": "returned_home", "home_exists": is_instance_valid(app.home_scene)})
		return
	var motor := app.player
	var body := motor.get_node_or_null("PixelPlainsActor") as UnderworldPlayer
	if body == null:
		rows.append({"tick": tick, "consumer": "no_run_body"})
		return
	var courier := motor.get_node("CourierVisual") as CourierVisual
	var receipt := body.animation_receipt()
	sampled_states[body.animation_state] = true
	rows.append(serial({"tick": tick, "consumer": "formal_plains", "body": receipt,
		"courier_state": courier.state, "courier_elapsed": courier.elapsed,
		"courier_arm_position": courier.arm.position, "courier_body_transform": str(courier.body.transform),
		"courier_muzzle_local": motor.to_local(courier.visible_muzzle_position()),
		"courier_visible": courier.visible, "adapter_mode": motor.get_node("PlayerVisualAdapter").process_mode,
		"health": app.controller.actor_resources.health.current,
		"health_terminal": app.controller.actor_resources.health.terminal,
		"position": motor.position, "velocity": motor.velocity, "motion_steps": motor.motion_steps,
		"recoil_velocity": motor.recoil_velocity, "camera": app._run_camera.get_screen_center_position(),
		"shot_energy": app.controller.actor_resources.stamina.current,
		"controller_active": app.controller.active, "session": app.controller.session_id,
		"accepted_shots": accepted_shots, "accepted_hurts": accepted_hurts}))

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--trace="): output = arg.trim_prefix("--trace=")
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	app = DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	check(app.start_plains(SEED), "ordinary formal entry accepted")
	for tick: int in 8: await physics_frame
	manifest = app.stage.generated.manifest.manifest_hash
	check(manifest == "ac5a6654b8aab5ceb53451a767b9efaa665b3d0ec3a45e661ce976cbdb967d5f", "frozen formal map identity")
	app.player.get_node("KeyboardMouseAdapter").process_mode = Node.PROCESS_MODE_DISABLED
	app.controller.shoot_ability.shot_fired.connect(func(direction: Vector2, id: int) -> void:
		accepted_shots += 1
		events.append(serial({"tick": rows.size(), "event": "accepted_shot", "id": id, "direction": direction})))
	app.controller.actor_resources.health.changed.connect(func(result: ActorResourceResult) -> void:
		if result.operation == &"damage" and result.status == ActorResourceResult.Status.APPLIED:
			accepted_hurts += 1
			events.append({"tick": rows.size(), "event": "applied_damage", "id": result.event_id, "amount": result.amount_applied, "terminal": result.snapshot.terminal}))
	for tick: int in FRAMES:
		if is_instance_valid(app.player) and app.lifetime.active:
			var router := app.controller.router
			if tick == 0: router.aim_direction = Vector2.RIGHT
			if tick == 60: router.set_move_axis(.55)
			if tick == 80: router.set_move_axis(-.55)
			if tick == 90:
				router.aim_direction = Vector2.UP
				router.request_action(&"shoot_release", Vector2.UP)
			if tick == 95: fixture_damage(&"presentation_01_hurt_a")
			if tick == 100: router.set_move_axis(0)
			if tick == 300: router.set_move_axis(.55)
			if tick == 320: router.set_move_axis(-.55)
			if tick == 340: router.set_move_axis(0)
			if tick == 380:
				router.aim_direction = Vector2.DOWN
				router.request_action(&"shoot_release", Vector2.DOWN)
			if tick == 385: fixture_damage(&"presentation_01_hurt_b")
			if tick == 600: fixture_damage(&"presentation_01_terminal", true)
		await physics_frame
		if capture: await RenderingServer.frame_post_draw
		else: await process_frame
		sample(tick)
	check(accepted_shots == 2, "two actual accepted shots")
	check(accepted_hurts == 3, "two actual nonterminal and one terminal policy commits")
	check(sampled_states.has("run") and sampled_states.has("hurt") and sampled_states.has("idle"), "real moving hurt recovery states observed")
	check(is_instance_valid(app.home_scene), "actual terminal run returns Home")
	var report := {"schema": "player-presentation-01-trace-v1", "seed": SEED, "manifest": manifest,
		"resolution": [1280,720], "fps": 60, "entry": "DemoApp.start_plains normal spawn; actual run camera",
		"driver_sha256": FileAccess.get_sha256("res://tests/player_presentation_01_trace.gd"),
		"scope": "Actual Router movement/shots and explicitly submitted production-policy damage lifecycle fixture; not natural combat/user/device approval",
		"capture": capture, "failures": failures, "accepted_shots": accepted_shots,
		"accepted_hurts": accepted_hurts, "states": sampled_states.keys(), "events": events, "frames": rows}
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	check(await load("res://tests/audio_teardown.gd").drain_world(app), "audio teardown drains actual consumers")
	app.free()
	for tick: int in 6: await process_frame
	print("PLAYER PRESENTATION 01: frames=", rows.size(), " shots=", accepted_shots, " damage=", accepted_hurts, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
