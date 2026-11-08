extends "res://tests/world/plains_intro.gd"
## Explicit no-D approach fixtures test early/repeated recoil attempts at the H+D wall.
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_counterexamples.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);app.start_new();await settle();app.load_room("P-R19","");await settle()
	var candidate:=app.state.value.duplicate(true);candidate.flags.append("H");app.state.commit(candidate,app.state.revision);app._apply_capabilities()
	for frame: int in [9,20,30]:
		for aim: Vector2 in [Vector2.DOWN,Vector2(-.7,1).normalized(),Vector2(-1,.7).normalized()]:
			app.player.reset_at(Vector2(1664,622));app.controller.router.clear("qualified_attempt");await ticks(70)
			app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(frame)
			app.controller.router.request_action(&"shoot_release",aim)
			var high:=app.player.position.y
			for i: int in 75:
				await physics_frame;high=minf(high,app.player.position.y)
				if app.player.is_on_floor():break
			check(high>270,"no-D recoil stays below reward stand: frame "+str(frame)+" min_y="+str(high))
			app._commit_action("pickup_TG04");check(not app.state.value.receipts.has("pickup_TG04"),"no ground/nearby remote award")

	# Highest legal pre-H approach: the middle east doorway. Recoil alone cannot
	# enter the high forest shelf; H acquisition is not replaced by a door flag.
	candidate=app.state.value.duplicate(true);candidate.flags.erase("H");app.state.commit(candidate,app.state.revision);app._apply_capabilities()
	app.load_room("P-R18","");await settle()
	for frame: int in [9,20,30]:
		for aim: Vector2 in [Vector2.DOWN,Vector2(.7,1).normalized(),Vector2(-.7,1).normalized()]:
			app.controller.router.clear("qualified_no_H_attempt");app.player.reset_at(Vector2(2416,654));await ticks(70)
			app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(frame)
			app.controller.router.request_action(&"shoot_release",aim)
			var high:=app.player.position.y
			for i: int in 90:
				await physics_frame;high=minf(high,app.player.position.y)
				if app.player.is_on_floor():break
			check(high>206,"no-H recoil stays below east forest approach: frame "+str(frame)+" min_y="+str(high))

	# The actual high east entry is now above the old test approach. Its stone
	# spine must still keep the independent H preview inaccessible from this side.
	for frame: int in [9,20,30]:
		app.controller.router.clear("high_east_no_H");app.player.reset_at(Vector2(1984,142));await ticks(5)
		app.controller.router.set_source_axis(&"keyboard_mouse",-1)
		app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(frame)
		app.controller.router.request_action(&"shoot_release",Vector2(.7,1).normalized())
		var crossed:=false
		for i: int in 90:
			await ticks(1)
			crossed=crossed or app.room.section_at(app.player.position)=="access:H"
		app.controller.router.clear("high_east_attempt_end")
		check(not crossed,"high east arrival cannot cross the physical H spine: "+str(frame))
	app.load_room("P-R12","");await settle()
	for frame: int in [9,20,30]:
		app.controller.router.clear("cellar_return_reverse");app.player.reset_at(Vector2(1264,878));await ticks(5)
		app.controller.router.set_source_axis(&"keyboard_mouse",-1)
		app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(frame)
		app.controller.router.request_action(&"shoot_release",Vector2(.4,1).normalized())
		var entered:=false
		for i: int in 100:
			await ticks(1)
			entered=entered or app.player.position.y<500
		app.controller.router.clear("cellar_reverse_end")
		check(not entered and not app.state.has("reward_return_EQ_MAP_P01_open"),"cellar through-route does not bypass the reward-side return: "+str(frame))
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8);print("PLAINS COUNTEREXAMPLES: ",failures," failures");quit(failures)
