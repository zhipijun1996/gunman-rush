extends "res://tests/world/plains_intro.gd"
## Declared room-start fixtures. Counterexamples preserve firing and bell commits.
func run() -> void:
	var cases: Array[Dictionary]=[{"disabled":"","height":840.0},{"disabled":"","height":850.0},{"disabled":"","height":825.0},{"disabled":"west_transfer","height":850.0},{"disabled":"west_transfer","height":830.0},{"disabled":"west_transfer","height":825.0},{"disabled":"east_transfer","height":840.0}]
	if "--positive-only" in OS.get_cmdline_user_args():cases=cases.slice(0,1)
	for case: Dictionary in cases:
		app=preload("res://game/application/world/fixed_world.tscn").instantiate()
		app.save_path="user://plains_mill_fixture.json"
		for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
		root.add_child(app);app.start_new();await settle();app.load_room("P-R26","");await settle()
		var route:=preload("res://tests/world/plains_mill_route.gd").new()
		route.disable_recoil_at=case.disabled;route.west_departure_y=case.height
		var passed: bool=await route.run(app)
		if str(case.disabled).is_empty():
			check(passed,"two real carriers and both recoil transfers")
			check(app.room.mechanisms["P-R26:carrier_east"].motion_target.motion_running,"second bell remains an actual projectile interaction")
		else:
			check(not passed and route.checkpoint==case.disabled,"no recoil displacement fails declared transfer: "+str(case))
			check(app.controller.shoot_ability._shot_serial>=2,"projectiles retained in no-recoil counterexample")
			check(app.room.mechanisms["P-R26:carrier_west"].motion_target.motion_running,"opened carrier still cannot replace transfer")
			await ticks(180)
			check(app.player.is_on_floor() and app.player.position.y>(250 if case.disabled=="east_transfer" else 1200),"miss returns to real support below unfinished challenge, not upper exit")
		await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8)
	print("PLAINS MILL: ",failures," failures");quit(failures)
