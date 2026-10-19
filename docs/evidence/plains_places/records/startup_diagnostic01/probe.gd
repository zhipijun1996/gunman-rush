extends SceneTree
class ObservedApp extends DemoApp:
	func abandon_run() -> void:
		print("ACTUAL ABANDON STATUS: ", _status)
		if segment != null and is_instance_valid(stage):
			print("ACTUAL ENTRY: ", stage.spawn, " SAFE: ", segment.is_safe(stage.spawn))
		super.abandon_run()
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var app := ObservedApp.new()
	app.plains_places_candidate_requested = true
	app.avatar_selection_id = "p1_girl"
	app.meta_persistence_enabled = false
	root.add_child(app)
	print("ACTUAL START ACCEPTED: ", app.start_plains("plains-places-first-01"))
	for unused: int in 120:
		await physics_frame
		await process_frame
	print("ACTUAL PENDING: ", app._stage_pending, " STATUS: ", app._status)
	for child: Node in app.get_children():
		if child is GameAudio: await preload("res://tools/observed_audio_teardown.gd").drain_service(child)
	app.queue_free()
	await process_frame
	quit()
