extends "res://tests/world/plains_region_routes.gd"
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
	if not await route([Vector2(688,654)],"P-R16"):await finish_east();return
	await hop(Vector2(1040,590),Vector2(-1,.3))
	await full_jump(Vector2(1376,750))
	if not await route([Vector2(1786,750)],"P-R16","P-R11"):await finish_east();return
	await setup_at("P-R28")
	if not await route([Vector2(448,622)],"P-R28"):await finish_east();return
	if not await route([Vector2(592,526)],"P-R28"):await finish_east();return
	await clear_enemies();await walk(Vector2(688,526),"P-R28");await hop(Vector2(1088,462),Vector2.LEFT,15)
	await clear_enemies()
	if not await route([Vector2(1280,526)],"P-R28"):await finish_east();return
	await full_jump(Vector2(1664,526))
	if not await route([Vector2(2042,622)],"P-R28","P-R29"):await finish_east();return
	if not await route([Vector2(352,654)],"P-R29"):await finish_east();return
	await hop(Vector2(768,942),Vector2(-1,.1))
	if not await route([Vector2(832,942)],"P-R29"):await finish_east();return
	# Descend through the open lower cargo passage; shutter high route is checked separately.
	if not await route([Vector2(920,1566),Vector2(1120,1518),Vector2(1248,1518)],"P-R29"):await finish_east();return
	await clear_enemies()
	if not await route([Vector2(1440,1518),Vector2(1104,1518)],"P-R29"):await finish_east();return
	if not await route([Vector2(896,1566),Vector2(768,1646)],"P-R29","P-R09"):await finish_east();return
	if not await route([Vector2(1800,622)],"P-R09"):await finish_east();return
	await clear_enemies()
	await setup_at("P-R34")
	if not await route([Vector2(640,526)],"P-R34"):await finish_east();return
	await clear_enemies()
	await walk(Vector2(688,526),"P-R34");await hop(Vector2(1040,462),Vector2(-1,.3))
	await walk(Vector2(1168,462),"P-R34");await full_jump(Vector2(1480,526));await clear_enemies()
	if not await route([Vector2(2080,622),Vector2(1920,510),Vector2(1664,398)],"P-R34"):await finish_east();return
	check(await market_cross(),"market ferry joins raised east doorway")
	if failures>0:await finish_east();return
	if not await route([Vector2(2298,398)],"P-R34","P-R35"):await finish_east();return
	if not await route([Vector2(640,1134)],"P-R35"):await finish_east();return
	await clear_enemies()
	if not await route([Vector2(1200,1134)],"P-R35"):await finish_east();return
	# Cross the real narrow downward opening with an ordinary jump.
	app.controller.router.set_source_axis(&"keyboard_mouse",1)
	app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(24)
	app.controller.router.set_jump_held(&"keyboard_mouse",false)
	if not await route([Vector2(1440,1134),Vector2(1504,1134),Vector2(1600,1006),Vector2(1760,1006)],"P-R35"):await finish_east();return
	await full_jump(Vector2(1952,974))
	if not await route([Vector2(2080,910),Vector2(2304,910)],"P-R35"):await finish_east();return
	if not await route([Vector2(2554,910)],"P-R35","P-R18"):await finish_east();return
	if not await route([Vector2(736,782),Vector2(880,782)],"P-R18"):await finish_east();return
	await clear_enemies()
	if not await route([Vector2(1056,878)],"P-R18"):await finish_east();return
	await hop(Vector2(1328,718),Vector2(-1,.6))
	if not await route([Vector2(1504,718)],"P-R18"):await finish_east();return
	await clear_enemies()
	if not await route([Vector2(1664,878)],"P-R18"):await finish_east();return
	app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(8)
	for anchor: Vector2 in app.room.hook_points:
		check(await hook(anchor),"east fields actual H route "+str(anchor));app.controller.router.set_jump_held(&"keyboard_mouse",false)
	app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(20);app.controller.router.set_jump_held(&"keyboard_mouse",false)
	if not await route([Vector2(2080,206)],"P-R18"):await finish_east();return
	check(app.room.section_at(app.player.position)=="access:H","H arrives forest approach shelf")
	if not await route([Vector2(1888,782),Vector2(1968,782)],"P-R18"):await finish_east();return
	await full_jump(Vector2(2200,878))
	if not await route([Vector2(2554,878)],"P-R18","P-R07"):await finish_east();return
	if not await route([Vector2(600,526),Vector2(688,526)],"P-R07"):await finish_east();return
	await clear_enemies()
	await full_jump(Vector2(960,622))
	if not await route([Vector2(1216,670),Vector2(1088,750)],"P-R07","P-R02"):await finish_east();return

	await setup_at("P-R35")
	if not await route([Vector2(640,1134)],"P-R35"):await finish_east();return
	await clear_enemies()
	if not await route([Vector2(1168,1134)],"P-R35"):await finish_east();return
	check(await ride_up("JunctionLift","P-R35:JunctionLift",Vector2(1168,1072),180),"junction freight lift replaces twenty ladder rungs")
	await full_jump(Vector2(1424,142))
	if not await route([Vector2(1360,142),Vector2(1280,-18)],"P-R35","P-R33"):await finish_east();return
	if not await route([Vector2(1520,878),Vector2(1840,878)],"P-R33"):await finish_east();return
	check(app.room.enemies.is_empty(),"world clock forecourt preserves quiet landmark")
	if not await route([Vector2(1456,878)],"P-R33"):await finish_east();return
	await hop(Vector2(976,878),Vector2(1,.1))
	if not await route([Vector2(1000,878),Vector2(736,878),Vector2(656,766),Vector2(592,654),Vector2(6,654)],"P-R33","P-R32"):await finish_east();return
	await finish_east()
func finish_east() -> void:
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8);print("PLAINS EAST ROUTES: ",failures," failures");quit(failures)
