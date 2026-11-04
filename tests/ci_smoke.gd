extends SceneTree

var failures := 0
var assertions := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var scene_path: String = ProjectSettings.get_setting("application/run/main_scene")
	var app: DemoApp = load(scene_path).instantiate()
	app.meta_persistence_enabled = false
	root.add_child(app)
	for unused: int in 3:
		await process_frame
	check(is_instance_valid(app.menu), "configured main scene creates its menu")
	check(app.menu.visible_panel == &"title", "configured main scene opens the title")
	app.menu._start_title_adventure()
	await process_frame
	check(is_instance_valid(app.home_scene), "title start creates the playable home")
	check(app.start_plains("ci-smoke"), "normal Explore entry starts the real Plains run")
	for unused: int in 600:
		await physics_frame
		if is_instance_valid(app.stage) and is_instance_valid(app.player):
			break
	check(is_instance_valid(app.stage) and is_instance_valid(app.player), "normal run creates a stage and player")
	if is_instance_valid(app.player):
		for unused: int in 30:
			await physics_frame
		check(is_instance_valid(app.controller) and app.player.is_inside_tree(), "player survives startup frames with its controller")
		check(app.controller.actor_resources.health.current > 0, "normal run starts alive")
	app.menu.requested_home.emit()
	for unused: int in 3:
		await process_frame
	check(app.director.state == DemoRunDirector.State.HOME and is_instance_valid(app.home_scene), "run cleanup returns to home")
	check(await preload("res://tests/audio_teardown.gd").drain_world(app), "owned audio drains before test teardown")
	app.queue_free()
	for unused: int in 3:
		await process_frame
	print("CI SMOKE: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
