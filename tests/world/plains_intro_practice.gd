extends "res://tests/world/plains_intro.gd"
## Declared local approach fixtures; each attempt still uses actual physics,
## projectiles, transient gate state and the common damage/return controller.
func run() -> void:
	for mode: String in ["positive","no_shot","no_recoil"]:
		app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://intro_practice_fixture.json"
		for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
		root.add_child(app);app.start_new();await settle();app.load_room("P-R22","");await settle()
		app.player.reset_at(Vector2(2528,1294));await ticks(3)
		var latch:=app.room.mechanisms["P-R22:practice_shutter"] as WorldShotLatch
		check(app.player.is_on_floor(),"declared actual preparation ledge "+mode)
		if mode=="no_recoil":
			app.controller.recoil_ability.enabled=false
		app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true)
		await ticks(11)
		print("AIR AIM ",mode," ",app.player.position," aim=",latch.bell_position-app.player.position)
		if mode!="no_shot":app.controller.router.request_action(&"shoot_release",(latch.bell_position-app.player.position).normalized())
		await ticks(21);app.controller.router.set_jump_held(&"keyboard_mouse",false)
		for i: int in 120:
			await physics_frame
			if app.player.is_on_floor():break
		app.controller.router.clear("landed")
		print("PRACTICE RESULT ",mode," ",app.player.position," gate=",latch.open_count)
		if mode=="positive":check(latch.open_count==1 and app.player.position.y<1200,"air shot and recoil clear the shutter")
		else:
			check(app.player.position.y>1200,"cannot complete without "+mode)
			check(latch.open_count==(1 if mode=="no_recoil" else 0),"real projectile result preserved in control "+mode)
		await ticks(90);check(not latch.is_open,"transient window closes after departure")
		await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5)
	for bay: int in 2:
		for delay: int in [0,6]:
			app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://intro_edges_fixture.json"
			for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
			root.add_child(app);app.start_new();await settle();app.load_room("P-R22","");await settle()
			app.player.reset_at(Vector2(838,1486) if bay==0 else Vector2(1862,1390));await ticks(3)
			check(app.player.is_on_floor(),"legal outer ledge before full/coyote jump")
			app.controller.router.set_source_axis(&"keyboard_mouse",1);await ticks(delay)
			app.controller.router.set_jump_held(&"keyboard_mouse",true)
			var furthest:float=app.player.position.x
			for i: int in 100:
				await physics_frame
				if app.player.position.y+18<=(1408 if bay==0 else 1344):furthest=maxf(furthest,app.player.position.x)
			app.controller.router.clear("counter_landed")
			print("BAY COUNTER ",bay," delay=",delay," furthest=",furthest)
			check(furthest+12<(1056 if bay==0 else 2112),"full/coyote jump cannot reach raised practice bank")
			await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5)
	print("PLAINS INTRO PRACTICE: ",failures," failures");quit(failures)
