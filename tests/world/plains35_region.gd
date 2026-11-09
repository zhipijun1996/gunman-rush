extends "res://tests/world/plains35_fixture.gd"

func run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains35_region.json";root.add_child(app);app.workbench.enabled=true
	var cases:Array=[
	["P-R05",Vector2(1024,206),Vector2(1328,142),Vector2(-.92,.392)],
	["P-R14",Vector2(512,1230),Vector2(352,1102),Vector2.ZERO],
	["P-R14",Vector2(352,1102),Vector2(384,942),Vector2.DOWN],
	["P-R14",Vector2(384,942),Vector2(400,742),Vector2.DOWN],
	["P-R31",Vector2(1104,878),Vector2(1440,878),Vector2.LEFT],
	["P-R34",Vector2(1264,366),Vector2(1600,366),Vector2.LEFT],
	["P-R35",Vector2(448,1966),Vector2(480,1806),Vector2.DOWN],
	["P-R35",Vector2(480,1806),Vector2(512,1646),Vector2.DOWN],
	["P-R02",Vector2(832,878),Vector2(960,804),Vector2.ZERO],
	["P-R07",Vector2(640,942),Vector2(976,1006),Vector2.LEFT],
	["P-R18",Vector2(944,1134),Vector2(1264,1134),Vector2.LEFT],
	["P-R28",Vector2(1072,1390),Vector2(1408,1390),Vector2.LEFT],
	["P-R29",Vector2(432,622),Vector2(784,558),Vector2(-.92,.392)],
	["P-R09",Vector2(1488,1070),Vector2(1808,942),Vector2(-.6,.8)],
	["P-R16",Vector2(512,1166),Vector2(576,878),Vector2.DOWN],
	["P-R11",Vector2(288,1198),Vector2(400,1134),Vector2.ZERO],
	["P-R32",Vector2(752,1006),Vector2(1056,1006),Vector2.LEFT],
	["P-R33",Vector2(1152,910),Vector2(1008,814),Vector2.ZERO],
	["P-R33",Vector2(1008,814),Vector2(944,558),Vector2.DOWN],
	["P-R30",Vector2(688,238),Vector2(944,302),Vector2.LEFT]]
	var args:=OS.get_cmdline_user_args()
	var current:=""
	for row:Array in cases:
		if not args.is_empty() and row[0] not in args[0].split(","):continue
		if row[0]!=current:
			await load_room(row[0]);current=row[0]
			for actor:EnemyActor in app.room.enemies.values():actor.set_physics_process(false)
			if app.room.encounter!=null:app.room.encounter.set_physics_process(false)
		await hop(row[1],row[2],row[3],current+" key crossing")
	for row:Array in [["P-R15",Vector2(976,3758),Vector2(1136,3840),0],["P-R10",Vector2(832,2222),Vector2(800,2176),0],["P-R17",Vector2(640,846),Vector2(448,624),12],["P-R20",Vector2(1456,942),Vector2(1664,752),12],["P-R30",Vector2(656,878),Vector2(800,736),0],["P-R19",Vector2(1328,2174),Vector2(1472,2136),0]]:
		if not args.is_empty() and row[0] not in args[0].split(","):continue
		await load_room(row[0],"h")
		for actor:EnemyActor in app.room.enemies.values():actor.set_physics_process(false)
		await hook(row[1],row[2],row[0]+" actual H anchor",row[3])
	for id:String in ["P-R14","P-R11"]:
		if not args.is_empty() and id not in args[0].split(","):continue
		await load_room(id)
		var arena:=app.room.arena_bounds
		await fixture(Vector2(arena.position.x+80,arena.end.y-18))
		await ticks(8)
		check(app.room.battle_started and app.room.seals.size()==2,id+" actual arena entry activates encounter and seals")
		check(app.room.boss!=null and arena.has_point(app.room.boss.position),id+" boss fits relocated arena")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(3)
	print("PLAINS35 REGION: ",failures," failures");quit(failures)
