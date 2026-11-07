extends "res://tests/world/plains_gates.gd"
## Qualified approach fixtures: real long-bridge H movement and water recovery.
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_places_fixture.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);app.start_new();await settle();app.load_room("P-R32","");await settle()
	app.player.reset_at(Vector2(784,750));await ticks(4)
	await recoil_jump(Vector2(-1,.6).normalized())
	check(app.player.position.x<1900 and app.player.position.y>850,"ordinary recoil cannot cross entire high bridge")
	var candidate:=app.state.value.duplicate(true);candidate.flags.append("H");app.state.commit(candidate,app.state.revision);app._apply_capabilities()
	app.player.reset_at(Vector2(784,750));await ticks(4)
	for i: int in 7:check(await hook(app.room.hook_points[i]),"long bridge real anchor "+str(i))
	app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(20);app.controller.router.set_jump_held(&"keyboard_mouse",false)
	check(await walk(Vector2(2080,750),"P-R32"),"H crossing lands far high bank")
	check(app.room.section_at(app.player.position)=="high:H","actual arrival in high section")
	app.controller.router.clear("new_fixture");app.load_room("P-R20","");await settle();app.player.reset_at(Vector2(1728,878));await ticks(5)
	var health:=app.controller.actor_resources.health.current
	app.controller.router.set_source_axis(&"keyboard_mouse",1)
	for i: int in 150:
		await physics_frame
		if app.controller.actor_resources.health.current<health:break
	app.controller.router.clear("water_contact");await ticks(10)
	check(app.controller.actor_resources.health.current==health-1,"real water fall costs exactly one health")
	check(app.player.position.distance_to(Vector2(1728,878))<5,"water returns to actually visited near-side shore")
	check((GameAudio.for_origin(app) as GameAudio).played.get(&"plains_water_splash",0)==1,"one accepted splash sound")
	await walk(Vector2(1776,878),"P-R20")
	app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(32);app.controller.router.set_jump_held(&"keyboard_mouse",false)
	check(await walk(Vector2(2048,878),"P-R20"),"basic jump preserves ungated ground loop")
	check(app.controller.actor_resources.health.current==health-1,"successful crossing takes no extra damage")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8);print("PLAINS PLACES: ",failures," failures");quit(failures)
