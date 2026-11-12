extends "res://tests/world/plains35_fixture.gd"
## Declared local approaches exercise real inputs/physics. These are selected
## actions, not a claim of an uninterrupted 35-room playthrough.
func load_room(id:String, stage:String="base") -> void:
	check(await app.review.begin(id,"",stage),id+" formal load")
	await ticks(5)
	# Movement fixtures exclude combat; the actual enemy placements remain intact.
	for enemy:EnemyActor in app.room.enemies.values():
		enemy.cancel_attacks();enemy.process_mode=Node.PROCESS_MODE_DISABLED
		enemy.motor.position=Vector2(-10000,-10000)

func selected(id:String) -> bool:
	var args:=OS.get_cmdline_user_args()
	return args.is_empty() or id in args[0].split(",")

func ride(id:String, carrier_name:String, bell:Vector2=Vector2.ZERO, shore:Vector2=Vector2.ZERO) -> void:
	var lift:=app.room.get_node(carrier_name) as WorldMovingPlatform
	lift.restore_motion(0,false)
	if bell!=Vector2.ZERO:
		await fixture(shore)
		if carrier_name=="EastHoist":
			app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(8)
		app.controller.router.request_action(&"shoot_release",(bell-app.player.position-Vector2(0,-6)).normalized())
		await ticks(25)
		check(lift.motion_running,id+" real shore shot starts "+carrier_name)
	# Separate declared deck fixture checks the whole shaft, without the shot's
	# intentional recoil ejecting an idle rider before boarding starts.
	lift.restore_motion(0,false)
	await fixture(lift.position-Vector2(0,lift.platform_size.y*.5+18))
	check(app.player.is_on_floor(),id+" "+carrier_name+" actual deck contact")
	lift.motion_running=true
	var arrived:=false
	for i:int in int((lift.period*.5+lift.endpoint_dwell+2)*60):
		await ticks(1)
		if lift.position.distance_to(lift.origin+lift.endpoint)<1:
			var expected:=lift.position-Vector2(0,lift.platform_size.y*.5+18)
			arrived=app.player.is_on_floor() and absf(app.player.position.y-expected.y)<5 and absf(app.player.position.x-expected.x)<lift.platform_size.x*.5-12
			break
	check(arrived,id+" "+carrier_name+" rides to terminal with full headroom "+str(app.player.position))

func run() -> void:
	root.size=Vector2i(1280,720)
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://approved_draft_actions.json";root.add_child(app)
	if selected("P-R04"):
		await load_room("P-R04")
		await hop(Vector2(1512,910),Vector2(1184,910),Vector2.RIGHT,"P04 recoil broken span")
		await hop(Vector2(608,910),Vector2(640,686),Vector2.DOWN,"P04 upward recoil shoulder")
		await hop(Vector2(80,1198),Vector2(208,1070),Vector2.ZERO,"P04 west cache return")
	if selected("P-R05"):
		await load_room("P-R05")
		await fixture(Vector2(192,366))
		app.controller.router.request_action(&"shoot_release",(Vector2(224,320)-app.player.position-Vector2(0,-6)).normalized());await ticks(25)
		check((app.room.get_node("Carrier0") as WorldMovingPlatform).motion_running,"P05 real shot starts drive")
		await hop(Vector2(1024,206),Vector2(1312,142),Vector2.LEFT,"P05 final recoil to unique gear bank")
	if selected("P-R07"):
		await load_room("P-R07","h")
		await hop(Vector2(640,942),Vector2(1008,1006),Vector2.LEFT,"P07 cross spike shoulder to upper route")
		await hop(Vector2(1744,1518),Vector2(1952,1358),Vector2.DOWN,"P07 return up open east shaft")
	if selected("P-R09"):
		await load_room("P-R09")
		await ride("P09","FreightLift")
		await hop(Vector2(240,1166),Vector2(352,1070),Vector2.ZERO,"P09 pipe cache return")
		await shutter_combo()
	if selected("P-R17"):
		await load_room("P-R17","h")
		await hook(Vector2(640,846),Vector2(448,624),"P17 first original hook",12)
		await fixture(Vector2(768,1262))
		app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(16)
		app.controller.router.request_action(&"shoot_release",Vector2.DOWN)
		for i:int in 60:
			await ticks(1)
			if app.player.position.y<1028:app.controller.router.set_source_axis(&"keyboard_mouse",1)
			if app.player.position.x>864:app.controller.router.set_source_axis(&"keyboard_mouse",0)
			if app.player.is_on_floor():break
		check(app.player.is_on_floor() and absf(app.player.position.y-1038)<5,"P17 rise beside solid roof before turning onto it "+str(app.player.position))
		app.controller.router.clear("roof return complete")
	if selected("P-R19"):
		await load_room("P-R19")
		await ride("P19","RootCage")
		await ride("P19","MiddleCage",Vector2(944,1472),Vector2(880,1518))
		await ride("P19","UpperCage",Vector2(992,928),Vector2(1040,942))
	if selected("P-R28"):
		await load_room("P-R28")
		await hop(Vector2(1744,1070),Vector2(1600,846),Vector2(.2,.98),"P28 recoil back up alternating shaft")
		await hop(Vector2(224,1646),Vector2(352,1518),Vector2.ZERO,"P28 lower cache first recovery")
		await hop(Vector2(384,1518),Vector2(496,1390),Vector2.ZERO,"P28 lower cache second recovery")
	if selected("P-R29"):
		await load_room("P-R29")
		await ride("P29","GrainLift")
		await hop(Vector2(416,622),Vector2(752,558),Vector2.LEFT,"P29 west to broad middle beam")
		await attic_combo()
	if selected("P-R30"):
		await load_room("P-R30","h")
		await ride("P30","PumpFerry",Vector2(224,576),Vector2(304,622))
		await hop(Vector2(432,430),Vector2(250,238),Vector2(.5,.866),"P30 return to west entrance")
	if selected("P-R31"):
		await load_room("P-R31")
		await hop(Vector2(928,878),Vector2(1216,878),Vector2.LEFT,"P31 recoil across culvert")
		await ride("P31","WestHoist",Vector2(1808,864),Vector2(1744,878))
		await ride("P31","EastHoist",Vector2(1856,464),Vector2(1824,526))
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
	print("APPROVED ACTIONS: ",failures," failures");quit(failures)

func attic_combo() -> void:
	await fixture(Vector2(800,558))
	app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true)
	for i:int in 35:
		await ticks(1)
		if app.player.position.x>=896:break
	app.controller.router.request_action(&"shoot_release",(Vector2(912,448)-app.player.position).normalized())
	app.controller.router.set_source_axis(&"keyboard_mouse",-1)
	var opened:=false
	for i:int in 80:
		await ticks(1)
		opened=opened or app.room.mechanisms["P-R29:review03:attic_hatch"].is_open
		if app.player.position.x<784:app.controller.router.set_source_axis(&"keyboard_mouse",0)
		if app.player.is_on_floor():break
	check(opened and app.player.is_on_floor() and absf(app.player.position.y-286)<5,"P29 one shot opens attic and recoils onto reward bank "+str(app.player.position))
	app.controller.router.clear("attic check")

func shutter_combo() -> void:
	await fixture(Vector2(2048,1006));app.controller.router.set_source_axis(&"keyboard_mouse",1)
	for i:int in 60:
		await ticks(1)
		if app.player.position.x>=2190 and app.player.position.y>=1080:break
	app.controller.router.request_action(&"shoot_release",(Vector2(2080,1112)-app.player.position).normalized())
	var opened:=false
	for i:int in 80:
		await ticks(1)
		opened=opened or app.room.mechanisms["P-R09:review02:air_shutter"].is_open
		if app.player.position.x>=2480:app.controller.router.set_source_axis(&"keyboard_mouse",0)
		if app.player.is_on_floor():break
	check(opened and app.player.is_on_floor() and app.player.position.x>2384 and absf(app.player.position.y-1134)<5,"P09 falling return shot opens shutter and propels across "+str(app.player.position))
	app.controller.router.clear("shutter check")
