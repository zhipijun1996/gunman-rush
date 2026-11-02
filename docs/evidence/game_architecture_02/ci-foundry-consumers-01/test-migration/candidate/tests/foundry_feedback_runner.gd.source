extends SceneTree
var failures := 0
var assertions := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error("LAB FEEDBACK: " + label)
func ticks(n: int) -> void:
	for i: int in n: await physics_frame
	await process_frame
func run() -> void:
	var app := DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	var before := app.meta.snapshot()
	app._open_foundry()
	await ticks(10)
	var lab: FoundryLab = app._foundry
	lab.open_feedback()
	check(paused and lab._feedback_panel.visible, "feedback pauses world")
	lab._feedback_note.text = "这里看不清落点，希望调整敌人和平台。"
	lab.save_feedback()
	check(not paused and not lab._feedback_panel.visible, "saving restores prior pause")
	check(lab.feedback.back().note.contains("敌人") and lab.feedback.back().manifest.hash == lab.selected.hash, "note includes exact reproduction manifest")
	check(lab.feedback_bundle().schema == 2 and lab.feedback_bundle().records.size() == lab.feedback.size(), "versioned export includes records")
	lab.toggle_pause()
	lab.open_feedback()
	lab.close_feedback()
	check(paused, "cancel retains preexisting pause")
	lab.toggle_pause()
	lab.toggle_enemies()
	await ticks(10)
	var found := false
	for index: int in 6:
		lab.choose(index)
		await ticks(10)
		if lab.encounter.actors.size() > 0:
			found = true
			var actor: EnemyActor = lab.encounter.actors[0]
			var hp := actor.health.current
			var id := actor.get_instance_id()
			lab._return()
			await ticks(3)
			check(actor.get_instance_id() == id and actor.health.current == hp, "segment return preserves enemy instance and health")
			check(not lab.request(lab.selected, true), "enemy mode cannot claim pure-platform replay verification")
			lab.rate("hard", "敌人挡住落点")
			check(lab.feedback.back().enemy_mode and lab.feedback.back().enemy_spawns.size() > 0, "enemy feedback contains reproduced spawn plan")
			break
	check(found, "at least one enemy-equipped sample actually materializes")
	lab._fatal()
	lab.open_feedback()
	check(lab._feedback_panel.visible and paused, "failed attempt still accepts feedback")
	lab.close_feedback()
	check(app.meta.snapshot() == before, "feedback and enemies do not settle permanent rewards")
	lab.leave()
	await ticks(4)
	if not "--prove-skip-drain" in OS.get_cmdline_user_args():
		var audio := GameAudio.for_origin(app) as GameAudio
		check(audio != null and await preload("res://tests/audio_teardown.gd").drain_world(app), "audio playback actually releases before host exit")
	app.free()
	await process_frame
	print("LAB FEEDBACK: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)
