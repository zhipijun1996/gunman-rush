extends "res://tests/world/plains_intro.gd"
## Qualified arena start; existing weakpoint, contact and attack clocks remain active.
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_bellstrider_fixture.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);app.start_new();await settle();app.load_room("P-R11","");await settle()
	app.player.reset_at(Vector2(1856,878));await ticks(5)
	var won:=false
	for tick: int in 7200:
		await physics_frame
		if app.busy:continue
		if app.room.room_id!="P-R11":break
		if app.state.has("boss_P_BELLSTRIDER_defeated"):won=true;break
		var encounter:=app.room.encounter as BellstriderEncounter
		var at:=app.player.position;var target:=app.room.boss.position+encounter.core_offset()
		var destination:=1728.0 if target.x<1152 else 576.0
		app.controller.router.set_source_axis(&"keyboard_mouse",signf(destination-at.x) if absf(destination-at.x)>25 else 0)
		if app.player.is_on_floor():
			app.controller.router.set_jump_held(&"keyboard_mouse",false);app.controller.router.set_jump_held(&"keyboard_mouse",true)
		elif tick%45==0:app.controller.router.set_jump_held(&"keyboard_mouse",false)
		if tick%20==0:app.controller.router.request_action(&"shoot_release",(target-at).normalized())
		if tick%180==0:print("BELLSTRIDER ",at," hp=",app.controller.actor_resources.health.current," boss=",encounter.health.current," ",encounter.mode)
	check(won,"real Bellstrider weakpoint victory with base gun")
	if won:
		app.controller.router.clear("victory")
		check(await walk(Vector2(2112,878),"P-R11"),"walk to safe outer tray")
		app.controller.router.request_action(&"interact");await ticks(5)
		check(app.state.value.receipts.has("pickup_part_triple"),"physical triple part claim")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8);print("PLAINS BELLSTRIDER: ",failures," failures");quit(failures)
