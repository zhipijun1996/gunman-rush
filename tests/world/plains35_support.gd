extends "res://tests/world/plains35_fixture.gd"

func run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains35_support.json";root.add_child(app)
	var scope:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://config/editor/preview_rooms.json"))
	var args:=OS.get_cmdline_user_args()
	for id:String in scope.graybox_room_ids:
		if not id.begins_with("P-R"):continue
		if not args.is_empty() and id not in args[0].split(","):continue
		await load_room(id,"h" if id in ["P-R10","P-R15","P-R16","P-R17"] else "base")
		for actor:EnemyActor in app.room.enemies.values():actor.set_physics_process(false)
		if app.room.encounter!=null:app.room.encounter.set_physics_process(false)
		for door:Dictionary in app.room.doors:
			var at:=FixedWorldProvider.point(door.landing_contract.safe_standing_position_world_units)
			await fixture(at)
			check(app.player.is_on_floor() and app.player.position.distance_to(at)<3,id+" safe support "+door.id+" "+str(app.player.position))
		for host:Node2D in app.room.interaction_hosts:
			var at:=host.position
			await fixture(at)
			check(app.player.is_on_floor() and app.player.position.distance_to(at)<3,id+" interaction support "+host.name+" "+str(app.player.position))
		if app.room.rest_point!=Vector2.ZERO:
			await fixture(app.room.rest_point)
			check(app.player.is_on_floor() and app.player.position.distance_to(app.room.rest_point)<3,id+" rest support")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(3)
	print("PLAINS35 SUPPORT: ",failures," failures");quit(failures)
