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
	var world := load(scene_path).instantiate() as FixedWorldApp
	world.save_path = "user://ci_fixed_world.json"
	for suffix: String in ["", ".backup", ".corrupt", ".tmp"]: DirAccess.remove_absolute(world.save_path+suffix)
	root.add_child(world)
	check(world.title.visible,"normal entry opens fixed-world title")
	check(world.start_new(),"normal new-world entry accepted")
	for i: int in 40: await physics_frame
	check(world.room != null and world.room.room_id == "P-R03" and world.player.is_on_floor(),"new world loads actual tutorial with grounded player")
	check(is_instance_valid(world.controller) and world.controller.actor_resources.health.current>0,"formal player starts alive")
	check(world.room.element_runtime.nodes.size()>0,"formal room binds registered interactive elements")
	world.return_title()
	for unused:int in 4:await process_frame
	check(world.title.visible,"formal lifecycle returns to title")
	check(await WorldAudioLifecycle.drain_world(world),"owned audio drains before teardown")
	world.queue_free()
	for unused:int in 3:await process_frame
	print("CI SMOKE: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
