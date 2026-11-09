extends "res://tests/world/plains35_fixture.gd"
## Geometry fixture: mount at the lower terminal, then ride the real motor.
## Bell activation itself is covered by plains35_west; this checks full shafts.
func run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://plains35_carriers.json";root.add_child(app);app.workbench.enabled=true
	var args:=OS.get_cmdline_user_args()
	for row:Array in [["P-R02","RoofWinch"],["P-R09","FreightLift"],["P-R12","DrainCage"],["P-R18","IrrigationCage"],["P-R19","RootCage"],["P-R20","BankCage"],["P-R29","GrainLift"],["P-R31","BellFieldCarrier"],["P-R35","JunctionLift"]]:
		if not args.is_empty() and row[0] not in args[0].split(","):continue
		await load_room(row[0])
		for actor:EnemyActor in app.room.enemies.values():actor.set_physics_process(false)
		var lift:=app.room.get_node(row[1]) as WorldMovingPlatform
		lift.restore_motion(0,false)
		await fixture(lift.position-Vector2(0,lift.platform_size.y*.5+18))
		check(app.player.is_on_floor(),row[0]+" lower terminal boarding")
		lift.motion_running=true
		var attached:=true
		var reached_top:=false
		var drop_cooldown:=0
		var ride_frames:=int((lift.period+2*lift.endpoint_dwell)*60)
		for frame:int in ride_frames:
			await ticks(1)
			var expected:=lift.position-Vector2(0,lift.platform_size.y*.5+18)
			var descent:=lift.motion_clock>lift.period*.5+2*lift.endpoint_dwell
			if not descent and lift.position.distance_to(lift.origin+lift.route[-1])<1:
				reached_top=app.player.position.distance_to(expected)<12
			drop_cooldown-=1
			# A descending rider may step onto a one-way landing. Use the real down
			# action to continue; the motor must catch the descending carrier again.
			if descent and app.player.is_on_floor() and expected.y-app.player.position.y>5 and drop_cooldown<=0:
				app.controller.router.request_action(&"drop_through");drop_cooldown=15
			if app.player.position.distance_to(expected)>(160 if descent else 12):
				print("CARRIER LOST ",row[0]," frame=",frame," player=",app.player.position," carrier=",lift.position)
				attached=false;break
		check(reached_top,row[0]+" rider reaches upper terminal")
		var lower_stand:=lift.origin-Vector2(0,lift.platform_size.y*.5+18)
		check(attached and app.player.is_on_floor() and absf(app.player.position.y-lower_stand.y)<4 and absf(app.player.position.x-lower_stand.x)<lift.platform_size.x*.5-16,row[0]+" return with real deck drop-through "+str(app.player.position)+" carrier="+str(lift.position))
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(3)
	print("PLAINS35 CARRIERS: ",failures," failures");quit(failures)
