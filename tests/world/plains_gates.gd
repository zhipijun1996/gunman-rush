extends "res://tests/world/plains_intro.gd"
## Explicit post-H fixtures; H itself is earned separately in plains_boss.gd.
func hook(at: Vector2) -> bool:
	app.controller.router.request_action(&"grapple",(at-app.player.position-Vector2(0,-6)).normalized())
	for i: int in 110:
		await physics_frame
		if i>5 and app.controller.traversal.state==&"hook_hang":
			print("HOOK ",at," held at ",app.player.position);return true
	printerr("HOOK FAILED ",at," from ",app.player.position," state=",app.controller.traversal.state);return false
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_gate_fixture.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);app.start_new();await settle();app.load_room("P-R15","");await settle()
	app.player.reset_at(Vector2(1504,1133));await ticks(5)
	app._commit_action("repair_P");check(not app.state.has("clock_P"),"ground position cannot repair clock")
	app.controller.router.request_action(&"grapple",Vector2.UP);await ticks(8)
	check(app.controller.traversal.state==&"free","pre-H cast does not attach")
	var candidate:=app.state.value.duplicate(true);candidate.flags.append("H");app.state.commit(candidate,app.state.revision);app._apply_capabilities()
	app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(8)
	check(await hook(app.room.hook_points[0]),"first clock anchor")
	app.controller.router.set_jump_held(&"keyboard_mouse",false)
	for i: int in range(1,app.room.hook_points.size()):check(await hook(app.room.hook_points[i]),"clock chain "+str(i))
	app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(20);app.controller.router.set_jump_held(&"keyboard_mouse",false)
	check(await walk(Vector2(1632,686),"P-R15"),"land at clock shelf")
	app.controller.router.request_action(&"interact");await ticks(5);check(app.state.has("clock_P"),"actual upper-section clock interaction")
	check(await walk(Vector2(1728,686),"P-R15"),"walk to return mechanism");app.controller.router.request_action(&"interact");await ticks(5)
	check(app.state.has("shortcut_p01"),"physical return switch")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5);print("PLAINS GATES: ",failures," failures");quit(failures)
