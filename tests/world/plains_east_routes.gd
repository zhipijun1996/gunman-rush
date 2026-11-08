extends "res://tests/world/plains_first_loop.gd"
## Qualified cluster starts; every following room crossing uses actual player input.
## H fixture is declared here; the new-game first loop proves earning H independently.
func setup_at(rid: String) -> void:
	app.controller.router.clear("cluster_fixture");app.load_room("P-R02","");await settle()
	await walk(Vector2(320,494),"P-R02");app.controller.router.request_action(&"interact");await ticks(8)
	app.load_room(rid,"");await settle()
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_east_routes_fixture.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);app.start_new();await settle()
	var candidate:=app.state.value.duplicate(true)
	candidate.flags.append_array(["intro_move","intro_shoot","intro_complete","station_briefed","H"])
	app.state.commit(candidate,app.state.revision);app._apply_capabilities()
	await setup_at("P-R10")
	if not await route([Vector2(448,1774)],"P-R10"):await finish_east();return
	app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(8)
	for anchor: Vector2 in app.room.hook_points:
		check(await hook(anchor),"windmill actual H chain "+str(anchor));app.controller.router.set_jump_held(&"keyboard_mouse",false)
	app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(20);app.controller.router.set_jump_held(&"keyboard_mouse",false)
	if not await route([Vector2(1344,1326),Vector2(1530,1326)],"P-R10","P-R16"):await finish_east();return
	if not await route([Vector2(320,750)],"P-R16"):await finish_east();return
	app.controller.router.request_action(&"interact");await ticks(8)
	check(app.state.value.rest.room=="P-R16","windmill rest before optional Boss")
	await hop(Vector2(576,654),Vector2(-1,.6));await clear_enemies()
	if not await route([Vector2(1786,750)],"P-R16","P-R11"):await finish_east();return
	await setup_at("P-R28")
	if not await route([Vector2(448,622)],"P-R28"):await finish_east();return
	if not await route([Vector2(592,526)],"P-R28"):await finish_east();return
	await clear_enemies();await hop(Vector2(800,622),Vector2(-1,.1));await clear_enemies()
	if not await route([Vector2(2042,622)],"P-R28","P-R29"):await finish_east();return
	if not await route([Vector2(352,654)],"P-R29"):await finish_east();return
	await hop(Vector2(768,942),Vector2(-1,.1))
	if not await route([Vector2(832,942)],"P-R29"):await finish_east();return
	await hop(Vector2(1248,1230),Vector2(-1,.1));await clear_enemies()
	if not await route([Vector2(1440,1518),Vector2(1104,1518)],"P-R29"):await finish_east();return
	if not await route([Vector2(896,1566),Vector2(768,1646)],"P-R29","P-R09"):await finish_east();return
	if not await route([Vector2(1800,622)],"P-R09"):await finish_east();return
	await clear_enemies()
	await setup_at("P-R34")
	if not await route([Vector2(640,526)],"P-R34"):await finish_east();return
	await clear_enemies()
	await hop(Vector2(1440,526),Vector2(-1,.1));await clear_enemies()
	if not await route([Vector2(2080,622),Vector2(2096,550),Vector2(1984,478),Vector2(1808,398)],"P-R34"):await finish_east();return
	await hop(Vector2(2200,398),Vector2(-1,.1))
	if not await route([Vector2(2298,398)],"P-R34","P-R35"):await finish_east();return
	if not await route([Vector2(640,1134)],"P-R35"):await finish_east();return
	await clear_enemies()
	if not await route([Vector2(1200,1134)],"P-R35"):await finish_east();return
	# Cross the real narrow downward opening with an ordinary jump.
	app.controller.router.set_source_axis(&"keyboard_mouse",1)
	app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(24)
	app.controller.router.set_jump_held(&"keyboard_mouse",false)
	if not await route([Vector2(1440,1134),Vector2(1664,1134),Vector2(2208,1134),Vector2(2352,1062),Vector2(2240,990),Vector2(2080,910)],"P-R35"):await finish_east();return
	await hop(Vector2(2400,910),Vector2(-1,.1))
	if not await route([Vector2(2554,910)],"P-R35","P-R18"):await finish_east();return
	if not await route([Vector2(736,782)],"P-R18"):await finish_east();return
	await clear_enemies()
	if not await route([Vector2(1456,878)],"P-R18"):await finish_east();return
	await clear_enemies()
	if not await route([Vector2(1664,878)],"P-R18"):await finish_east();return
	app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(8)
	for anchor: Vector2 in app.room.hook_points:
		check(await hook(anchor),"east fields actual H route "+str(anchor));app.controller.router.set_jump_held(&"keyboard_mouse",false)
	app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(20);app.controller.router.set_jump_held(&"keyboard_mouse",false)
	if not await route([Vector2(2080,206)],"P-R18"):await finish_east();return
	check(app.room.section_at(app.player.position)=="access:H","H arrives forest approach shelf")
	if not await route([Vector2(1888,782),Vector2(2120,878),Vector2(2554,878)],"P-R18","P-R07"):await finish_east();return
	if not await route([Vector2(600,526)],"P-R07"):await finish_east();return
	await clear_enemies()
	if not await route([Vector2(1216,670),Vector2(1088,750)],"P-R07","P-R02"):await finish_east();return

	await setup_at("P-R35")
	if not await route([Vector2(640,1134)],"P-R35"):await finish_east();return
	await clear_enemies()
	await hop(Vector2(1200,1062),Vector2(-.5,1))
	if not await route([Vector2(1200,1062)],"P-R35"):await finish_east();return
	await hop(Vector2(1240,918),Vector2.DOWN)
	if not await route([Vector2(1240,918),Vector2(1424,846),Vector2(1240,774),Vector2(1424,702),Vector2(1240,630),Vector2(1424,558),Vector2(1240,486),Vector2(1424,414),Vector2(1240,342),Vector2(1424,270),Vector2(1200,198),Vector2(1424,142),Vector2(1360,142),Vector2(1280,-18)],"P-R35","P-R33"):await finish_east();return
	if not await route([Vector2(1520,878),Vector2(1840,878)],"P-R33"):await finish_east();return
	check(app.room.enemies.is_empty(),"world clock forecourt preserves quiet landmark")
	if not await route([Vector2(1456,878)],"P-R33"):await finish_east();return
	await hop(Vector2(976,878),Vector2(1,.1))
	if not await route([Vector2(1000,878),Vector2(208,806),Vector2(320,734),Vector2(432,654),Vector2(6,654)],"P-R33","P-R32"):await finish_east();return
	await finish_east()
func finish_east() -> void:
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8);print("PLAINS EAST ROUTES: ",failures," failures");quit(failures)
