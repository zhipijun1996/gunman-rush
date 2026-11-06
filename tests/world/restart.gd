extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("CHECK ",ok," ",label)
	if not ok: failures += 1
func run() -> void:
	# This is launched as a separate process after the real Router/Motor route.
	var app := preload("res://game/application/world/fixed_world.tscn").instantiate() as FixedWorldApp
	app.save_path = "user://world_route_test.json"
	root.add_child(app)
	check(app.continue_world(),"new process continues disk world")
	for i: int in 60: await physics_frame
	check(app.room!=null and app.room.room_id=="P-R01","restored room")
	check(app.state.has("H") and app.state.has("boss_P_WINDKEEPER_defeated"),"real victory and reward persist")
	check(app.state.value.receipts.has("get_H") and app.state.value.cycle==2,"unique receipt and cycle persist")
	var revision := app.state.revision
	var candidate := app.state.action_candidate("get_H","P-R14")
	check(candidate==app.state.value,"duplicate award remains unchanged after process restart")
	check(app.state.value.explored.size()==5,"actual exploration retained")
	check(app.player.is_on_floor() and app.controller.traversal.hook_enabled,"physical recovery and H restored")
	app.queue_free()
	for i: int in 5: await physics_frame
	print("WORLD RESTART: %d failures" % failures)
	quit(failures)
