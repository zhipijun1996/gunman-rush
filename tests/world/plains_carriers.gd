extends "res://tests/world/plains_gates.gd"
## Qualified carrier/return-visit approaches; Motor carries, grapples and lands normally.
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_carriers_fixture.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);app.start_new();await settle();app.load_room("P-R05","");await settle()
	var carrier:=app.room.get_node("Carrier1") as WorldMovingPlatform
	app.player.reset_at(carrier.position-Vector2(0,30));await ticks(4)
	var before:=app.player.position
	await ticks(70)
	check(app.player.is_on_floor() and app.player.position.distance_to(before)>20,"real carrier transports idle grounded rider")
	for i: int in 300:
		await physics_frame
		if carrier.position.x>1410:break
	await recoil_jump(Vector2(-1,.4).normalized())
	check(await walk(Vector2(1728,526),"P-R05"),"timed carrier departure lands fixed reward bank")
	app.controller.router.request_action(&"interact");await ticks(5);check(app.state.value.receipts.has("pickup_TG02"),"TG02 physical claim")
	var candidate:=app.state.value.duplicate(true);candidate.flags.append("H");app.state.commit(candidate,app.state.revision);app._apply_capabilities()
	app.load_room("P-R20","");await settle();app.player.reset_at(Vector2(1408,878));await ticks(4)
	app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(8)
	for anchor: Vector2 in app.room.hook_points:
		check(await hook(anchor),"canal ring "+str(anchor));app.controller.router.set_jump_held(&"keyboard_mouse",false)
	app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(17);app.controller.router.request_action(&"shoot_release",Vector2.LEFT);await ticks(9);app.controller.router.set_jump_held(&"keyboard_mouse",false)
	check(await walk(Vector2(1888,430),"P-R20"),"H and release land canal bag bank")
	app.controller.router.request_action(&"interact");await ticks(5);check(app.state.value.receipts.has("pickup_EQ_MAP_P02"),"EQ_MAP_P02 physical claim")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8);print("PLAINS CARRIERS: ",failures," failures");quit(failures)
