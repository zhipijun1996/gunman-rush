extends "res://tests/world/plains_intro.gd"
## Qualified arena start; combat and reward use real input and accepted damage.
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_boss_replay.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);app.start_new();await settle();app.load_room("P-R14","");await settle()
	app.player.reset_at(Vector2(1572,741));await ticks(5)
	var won:=false
	for tick: int in 7200:
		await physics_frame
		if app.busy:continue
		if app.room.room_id!="P-R14":break
		if app.state.has("boss_P_WINDKEEPER_defeated"):won=true;break
		var encounter:=app.room.encounter as WindkeeperPressureEncounter
		var at:=app.player.position;var target:=app.room.boss.position-Vector2(0,70)
		var destination:=1452.0
		if absf(target.x-at.x)<200:destination=872 if target.x>1192 else 1452
		app.controller.router.set_source_axis(&"keyboard_mouse",signf(destination-at.x) if absf(destination-at.x)>25 else 0)
		if app.player.is_on_floor() and (at.y>638 or "warning" in str(encounter.mode)):
			app.controller.router.set_jump_held(&"keyboard_mouse",false);app.controller.router.set_jump_held(&"keyboard_mouse",true)
		elif tick%45==0:app.controller.router.set_jump_held(&"keyboard_mouse",false)
		if tick%20==0:app.controller.router.request_action(&"shoot_release",(target-at).normalized())
		if tick%180==0:print("BOSS ",at," hp=",app.controller.actor_resources.health.current," boss=",encounter.health.current," ",encounter.mode)
	check(won,"real Windkeeper victory with base gun and no H")
	if won:
		app.controller.router.clear("victory")
		check(await walk(Vector2(1800,1134),"P-R14"),"leave arena and descend reward forecourt")
		app.controller.router.request_action(&"interact");await ticks(5)
		check(app.state.has("H") and app.state.value.receipts.has("get_H"),"physical H pickup")
		var count: int=app.state.value.receipts.size()
		app.controller.router.request_action(&"interact");await ticks(5)
		check(app.state.value.receipts.size()==count,"no duplicate reward")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5);print("PLAINS BOSS: ",failures," failures");quit(failures)
