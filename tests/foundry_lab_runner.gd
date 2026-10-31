extends SceneTree
## Consumer checks: real replay node, capabilities, pause, damage and feedback.
var failures := 0
var assertions := 0
var app: DemoApp
var lab: FoundryLab

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error("FOUNDRY LAB: " + label)
func ticks(n: int) -> void:
	for unused: int in n: await physics_frame
	# Attempt initialization also awaits an idle frame; physics catch-up alone
	# must not be mistaken for completed UI/world initialization.
	await process_frame

func run() -> void:
	check(FoundryCatalog.tuning_for("hook") == null, "unimplemented hook fails closed")
	check(FoundryLab.clean_feedback([null, 3, {}, {"rating": "keep"}]).is_empty(), "malformed feedback is discarded before typed iteration")
	check(FoundryCatalog.generate("height_then_precision", 0, 0, "negative", "hook").is_empty(), "hook is never advertised as physically verified")
	var batch := FoundryCatalog.batch()
	check(batch.get("accepted", []).size() >= 24, "current-basis verified batch is available")
	if batch.is_empty(): quit(1); return
	var manifest: Dictionary = batch.accepted[0].manifest
	check(FoundryCatalog.valid(manifest), "disk-loaded manifest preserves checksum and exact geometry")
	var forged := manifest.duplicate(true)
	forged.nodes[1].offset[0] += 10
	forged.hash = FoundryCatalog.checksum(forged)
	check(not FoundryCatalog.valid(forged), "rehashed geometry tampering is rejected")
	forged = manifest.duplicate(true)
	forged.capability_profile = "air_chain"
	forged.hash = FoundryCatalog.checksum(forged)
	check(not FoundryCatalog.valid(forged), "profile cannot be relabelled without reconstruction")
	app = DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	var before := app.meta.snapshot()
	app._open_foundry()
	await ticks(7)
	lab = app._foundry
	check(is_instance_valid(lab) and lab.ready_for_play, "main menu consumer loads shared actual player")
	var default_tuning := PlayerTuning.load_default()
	var base_tuning := FoundryCatalog.tuning_for("base")
	check(base_tuning != null and lab.player.tuning.max_jumps == 1 and lab.player.tuning.max_jumps == base_tuning.max_jumps and base_tuning.max_jumps == default_tuning.max_jumps and lab.player.tuning.max_air_shots == base_tuning.max_air_shots and base_tuning.max_air_shots == default_tuning.max_air_shots, "base profile leaves default movement contract intact")
	check(lab.player.is_on_floor(), "initial spawn has real support")
	for index: int in mini(6, lab.entries.size()):
		lab.choose(index, true)
		await ticks(2)
		await ticks(int(lab.entries[index].ticks) + 20)
		check(not lab.route_player.running and lab.route_player.cursor == lab.route_player.frames.size() and lab.route_player.max_error <= 2.0, "actual replay node matches disk recording including moving platforms %d" % index)
		check(lab.player.is_on_floor() and lab.player.global_position.distance_to(lab.stage.exit_point()) < 1.0, "actual replay reaches exact supported exit %d" % index)
	var clock := lab.stage.modules[0].clock
	var position := lab.player.global_position
	lab.toggle_pause()
	for unused: int in 20: await process_frame
	check(lab.stage.modules[0].clock == clock and lab.player.global_position == position, "paused actor and mechanisms do not advance")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	check(not paused, "Esc resumes paused world through ALWAYS input consumer")
	check(lab.rate("boring"), "feedback uses separate local file")
	check(lab.feedback.back().rating == "boring" and lab.feedback.back().basis == lab.selected.basis, "feedback carries evidence basis")
	check(app.meta.snapshot() == before, "practice and feedback never settle permanent rewards")
	lab.select_profile(1)
	await ticks(7)
	var double_jump_tuning := FoundryCatalog.tuning_for("double_jump")
	check(double_jump_tuning != null and lab.player.tuning.max_jumps == 2 and lab.player.tuning.max_jumps == double_jump_tuning.max_jumps and lab.player.tuning.max_air_shots == double_jump_tuning.max_air_shots and double_jump_tuning.max_air_shots == default_tuning.max_air_shots, "double jump profile uses existing ability configuration")
	await controller_jump_check(lab.controller)
	await ticks(4)
	check(lab.controller.jump_ability.used_jumps == 2, "second jump actually executes in the air")
	lab.select_profile(2)
	await ticks(7)
	check(lab.player.tuning.max_air_shots == 4, "multi-air profile raises action capacity without changing default file")
	var phase := lab.stage.modules[0].clock
	var hp := lab.controller.actor_resources.health.current
	var energy := lab.controller.actor_resources.stamina.current
	lab._return()
	await ticks(2)
	check(lab.stage.modules[0].clock >= phase and lab.controller.actor_resources.health.current == hp, "segment return preserves phase and HP")
	check(lab.controller.actor_resources.stamina.current <= energy + 2, "segment return does not refill energy")
	lab.leave()
	await ticks(3)
	check(not is_instance_valid(app._foundry) and not paused, "leaving releases isolated consumer and returns Home")
	check(PlayerTuning.load_default().max_jumps == 1 and PlayerTuning.load_default().max_air_shots == 1, "development profiles never mutate current one-round default configuration")
	if not "--prove-skip-drain" in OS.get_cmdline_user_args():
		var audio := GameAudio.for_origin(app) as GameAudio
		check(audio != null and await preload("res://tests/audio_teardown.gd").drain_world(app), "audio playback actually releases before host exit")
	app.free()
	await process_frame
	print("FOUNDRY LAB: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)

func controller_jump_check(controller: PlayerController) -> void:
	controller.router.request_action(&"jump")
	await ticks(4)
	controller.router.request_action(&"jump_release")
	await ticks(1)
	controller.router.request_action(&"jump")
