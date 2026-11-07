extends SceneTree
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1;printerr("FAIL: ",label)
func run() -> void:
	var app:=preload("res://game/application/world/fixed_world.tscn").instantiate() as FixedWorldApp
	app.save_path="user://world_service_ui_test.json"
	root.add_child(app)
	check(app.continue_world(),"independent process restores service slot")
	for i: int in 80:
		await physics_frame
		if not app.busy: break
	check(app.services.owns("trial_heart") and app.services.ledger().owned.trial_filter.level==2,"ownership and upgrade survive disk restart")
	check(app.services.active("lamp") and app.services.active("filter"),"effective equipment state reconstructed")
	check(app.services.ledger().cycle_uses.get("trial_flask",0)==1,"load does not refresh cycle quota")
	check(app.controller.actor_resources.health.current==4 and app.controller.actor_resources.health.capacity==5,"HP and declarative stats agree after restart")
	check(app.state.has("trial_station_repaired"),"NPC world result survives service save")
	app.queue_free()
	for i: int in 5: await physics_frame
	print("WORLD SERVICE RESTART: %d failures" % failures);quit(failures)
