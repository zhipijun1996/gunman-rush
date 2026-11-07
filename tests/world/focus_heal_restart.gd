extends SceneTree
var failures:=0
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var app:=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://world_focus_heal_test.json"
	root.add_child(app)
	if not app.continue_world(): failures+=1
	for i: int in 180:
		await physics_frame
		if not app.busy: break
	if app.controller==null or app.controller.actor_resources.health.current!=4 or app.controller.combat_energy.current!=65: failures+=1
	if app.focus_heal.elapsed!=0 or app.controller.router.focus_heal_held(): failures+=1
	if not await WorldAudioLifecycle.drain_world(app): failures+=1
	app.queue_free()
	for i: int in 5: await physics_frame
	print("WORLD HEAL RESTART: %d failures" % failures);quit(failures)
