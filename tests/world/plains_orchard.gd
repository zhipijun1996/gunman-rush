extends "res://tests/world/plains_first_loop.gd"
## Declared west-entry fixtures. Both choices use the same live enemies and Motor.
func run() -> void:
	var choices: Array[bool]=[false,true]
	if "--upper-only" in OS.get_cmdline_user_args():choices=[true]
	if "--lower-only" in OS.get_cmdline_user_args():choices=[false]
	for upper: bool in choices:
		app=preload("res://game/application/world/fixed_world.tscn").instantiate()
		app.save_path="user://plains_orchard_fixture.json"
		for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
		root.add_child(app);app.start_new();await settle();app.load_room("P-R25","");await settle()
		check(await walk(Vector2(468,782),"P-R25"),"orchard root shoulder")
		if upper:
			await hop(Vector2(864,686),Vector2(-1,.6))
			check(absf(app.player.position.y-686)<8,"upper west arch via recoil")
			check(await walk(Vector2(976,686),"P-R25"),"read eastern landing from arch")
			await hop(Vector2(1408,606),Vector2(-1,.6))
			check(absf(app.player.position.y-606)<8,"upper east arch via recoil")
			check(await walk(Vector2(1440,606),"P-R25"),"follow upper branch above lower encounters")
			check(await walk(Vector2(1520,606),"P-R25"),"east arch departure toward shared exit")
			await hop(Vector2(1664,782),Vector2(-1,.1))
			check(absf(app.player.position.y-782)<8,"upper route descends to east root shoulder")
		else:
			check(await walk(Vector2(576,878),"P-R25"),"lower route enters orchard aisle")
			await clear_enemies()
			check(await walk(Vector2(1024,878),"P-R25"),"read thorn bed from clear orchard ground")
			await hop(Vector2(1232,878),Vector2(-1,.1))
			check(absf(app.player.position.y-878)<8,"cross visible ground thorns below arches")
			check(await walk(Vector2(1680,782),"P-R25"),"east root shoulder after encounter")
		check(app.room.room_id=="P-R25","route stays in orchard")
		check(await walk(Vector2(1904,878),"P-R25"),"both routes merge at actual windmill approach")
		check(app.controller.actor_resources.health.current>0,"route leaves player alive")
		await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8)
	print("PLAINS ORCHARD: ",failures," failures");quit(failures)
