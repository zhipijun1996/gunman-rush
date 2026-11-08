extends "res://tests/world/plains_first_loop.gd"
## Explicit approach fixtures. Every following displacement uses real player input.
func ability(flags: Array[String]) -> void:
	var candidate:=app.state.value.duplicate(true)
	for flag: String in flags:
		if flag not in candidate.flags:candidate.flags.append(flag)
	app.state.commit(candidate,app.state.revision);app._apply_capabilities()
func start_at(rid: String,at: Vector2) -> void:
	app.load_room(rid,"");await settle();app.player.reset_at(at);await ticks(4)
func collect(id: String) -> void:
	app.controller.router.request_action(&"interact");await ticks(5)
	check(app.state.value.receipts.has(id),"actual reward interaction "+id)
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_acquisitions_fixture.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);app.start_new();await settle()
	await start_at("P-R04",Vector2(432,526))
	check(await walk(Vector2(544,654),"P-R04"),"descend bridge to visible brass cache");await collect("pickup_TG01")
	check(await path([Vector2(632,582),Vector2(744,526)],"P-R04"),"return above rooted thorn strip without resetting")
	await start_at("P-R12",Vector2(672,622))
	app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(11)
	app.controller.router.request_action(&"shoot_release",(app.room.mechanisms["P-R12:air_shutter"].bell_position-app.player.position).normalized());await ticks(25);app.controller.router.clear("cellar_crossed")
	check(await walk(Vector2(1104,462),"P-R12"),"low beam recoil enters hidden cellar storage");await collect("pickup_EQ_MAP_P01")
	await start_at("P-R13",Vector2(624,638));await hop(Vector2(1024,526),Vector2(-1,.25))
	check(await walk(Vector2(1024,526),"P-R13"),"recoil crosses high shoulder gap");await collect("pickup_HP01")
	ability(["H"])
	await start_at("P-R17",Vector2(800,782));app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(8)
	check(await hook(app.room.hook_points[0]),"hidden mill first ring");app.controller.router.set_jump_held(&"keyboard_mouse",false)
	check(await hook(app.room.hook_points[1]),"hidden mill back beam")
	app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(9);app.controller.router.request_action(&"shoot_release",Vector2.LEFT);await ticks(7);app.controller.router.set_jump_held(&"keyboard_mouse",false)
	check(await walk(Vector2(928,430),"P-R17"),"release and recoil to tool bag");await collect("pickup_EQ_MAP_P03")
	await start_at("P-R30",Vector2(1152,878));app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(8)
	for anchor: Vector2 in app.room.hook_points:
		check(await hook(anchor),"low ceiling cave ring "+str(anchor));app.controller.router.set_jump_held(&"keyboard_mouse",false)
	app.controller.router.set_source_axis(&"keyboard_mouse",0);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(1);app.controller.router.set_jump_held(&"keyboard_mouse",false)
	for i: int in 70:
		await physics_frame
		if app.player.position.y>=488 and app.player.velocity.y>0:break
	app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.request_action(&"shoot_release",Vector2.LEFT);await ticks(10)
	check(await walk(Vector2(1696,526),"P-R30"),"release below ceiling to dry bank");await collect("pickup_TG03")
	ability(["D"])
	await start_at("P-R19",Vector2(1440,1134));app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(8)
	for anchor: Vector2 in app.room.hook_points:
		check(await hook(anchor),"root crack H ring "+str(anchor));app.controller.router.set_jump_held(&"keyboard_mouse",false)
	app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(20);app.controller.router.set_jump_held(&"keyboard_mouse",false)
	check(await walk(Vector2(1664,622),"P-R19"),"H reaches inner preparation shelf")
	app.controller.router.set_source_axis(&"keyboard_mouse",0);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(21);print("D FIRST ",app.player.position," used=",app.controller.jump_ability.used_jumps," enabled=",app.controller.traversal.double_enabled);app.controller.router.set_jump_held(&"keyboard_mouse",false);await ticks(1);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(9);print("D SECOND ",app.player.position," used=",app.controller.jump_ability.used_jumps);app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.request_action(&"shoot_release",Vector2(-.7,1).normalized());await ticks(15);app.controller.router.set_jump_held(&"keyboard_mouse",false)
	check(await walk(Vector2(1888,270),"P-R19"),"D and recoil reach upper root pocket");await collect("pickup_TG04")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8);print("PLAINS ACQUISITIONS: ",failures," failures");quit(failures)
