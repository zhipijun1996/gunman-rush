extends "res://tests/world/plains_intro.gd"
## Declared east-orchard approach, then normal door crossing in both directions.
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_thresholds.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);app.start_new();await settle();app.load_room("P-R25","");await settle()
	app.player.reset_at(Vector2(1904,878));await ticks(90)
	check(await walk(Vector2(2042,878),"P-R25"),"walk through actual building entrance")
	await settle();check(app.room.room_id=="P-R26" and not app.room.interior_material().is_empty(),"facade leads to enclosed mill")
	check(await walk(Vector2(384,1262),"P-R26"),"enter mill preparation aisle")
	await ticks(75)
	check(await walk(Vector2(6,1262),"P-R26"),"walk back toward outside light")
	await settle();check(app.room.room_id=="P-R25" and app.room.interior_material().is_empty(),"same doorway returns to orchard")
	await ticks(60)
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8)
	print("PLAINS THRESHOLDS: ",failures," failures");quit(failures)
