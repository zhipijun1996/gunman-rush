extends "res://tests/world/plains35_fixture.gd"

func run() -> void:
	root.size=Vector2i(1280,720)
	app=load("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains35_fixture.json";root.add_child(app);app.workbench.enabled=true
	for id: String in ["P-R04","P-R25","P-R26","P-R27"]:
		await load_room(id)
		for actor:EnemyActor in app.room.enemies.values():actor.set_physics_process(false)
		for door:Dictionary in app.room.doors:
			var at:=FixedWorldProvider.point(door.landing_contract.safe_standing_position_world_units)
			await fixture(at)
			check(app.player.is_on_floor() and app.player.position.distance_to(at)<3,id+" safe support "+door.id+" "+str(app.player.position))
	await load_room("P-R04")
	for actor:EnemyActor in app.room.enemies.values():actor.set_physics_process(false)
	await hop(Vector2(1512,910),Vector2(1184,910),Vector2.RIGHT,"P04 first broken span")
	await hop(Vector2(1000,910),Vector2(672,910),Vector2.RIGHT,"P04 second broken span")
	await hop(Vector2(608,910),Vector2(640,686),Vector2.DOWN,"P04 recoil stone shoulder")
	await hop(Vector2(736,686),Vector2(928,526),Vector2(-.4,.916515),"P04 fold right")
	await hop(Vector2(1088,526),Vector2(1168,302),Vector2.DOWN,"P04 shaft rise")
	await hop(Vector2(1200,302),Vector2(1344,142),Vector2.DOWN,"P04 orchard lip")
	await fixture(Vector2(480,1198));app._interact();await ticks(8)
	check(app.state.has("found_TG01"),"P04 actual original gear receipt")
	await load_room("P-R25")
	for actor:EnemyActor in app.room.enemies.values():actor.set_physics_process(false)
	await hop(Vector2(320,1102),Vector2(320,942),Vector2.DOWN,"P25 lower entry shoulder")
	await hop(Vector2(320,942),Vector2(480,846),Vector2.ZERO,"P25 enter orchard")
	await hop(Vector2(2144,750),Vector2(2400,654),Vector2.LEFT,"P25 exit step")
	await hop(Vector2(2400,654),Vector2(2608,558),Vector2.LEFT,"P25 mill exit")
	await load_room("P-R26")
	await hop(Vector2(800,1390),Vector2(960,1332),Vector2.ZERO,"P26 west carrier boarding")
	app.controller.router.request_action(&"shoot_release",(Vector2(960,1280)-app.player.position).normalized());await ticks(20)
	var lift:=app.room.get_node("Carrier0") as WorldMovingPlatform
	check(lift.motion_running,"P26 real bullet starts carrier")
	for frame:int in 600:
		await ticks(1)
		if lift.position.y<=864.1:break
	check(app.player.is_on_floor() and absf(app.player.position.y-836)<4,"P26 rider reaches west top "+str(app.player.position))
	await hop(Vector2(1008,836),Vector2(1280,686),Vector2(-.4,.916515),"P26 right up transfer")
	await hop(Vector2(1760,686),Vector2(1936,596),Vector2.ZERO,"P26 east carrier boarding")
	app.controller.router.request_action(&"shoot_release",(Vector2(1936,544)-app.player.position).normalized());await ticks(20)
	lift=app.room.get_node("Carrier1") as WorldMovingPlatform
	check(lift.motion_running,"P26 real bullet starts second carrier")
	for frame:int in 600:
		await ticks(1)
		if lift.position.y<=384.1:break
	check(app.player.is_on_floor() and absf(app.player.position.y-356)<4,"P26 diagonal rider to east top "+str(app.player.position))
	await hop(Vector2(2192,356),Vector2(2112,142),Vector2.DOWN,"P26 left up exit")
	await load_room("P-R27")
	await hop(Vector2(640,718),Vector2(848,558),Vector2.DOWN,"P27 from lower door into shelter")
	await hop(Vector2(640,558),Vector2(512,430),Vector2.ZERO,"P27 broad west step")
	await hop(Vector2(576,430),Vector2(624,270),Vector2.DOWN,"P27 upper stone step")
	await hop(Vector2(704,270),Vector2(768,142),Vector2.ZERO,"P27 guardian approach")
	await fixture(Vector2(768,142))
	app.controller.router.set_jump_held(&"keyboard_mouse",true)
	for frame:int in 600:
		await ticks(1)
		if app.room.room_id=="P-R14" and not app.busy and app.player.is_on_floor():break
	check(app.room.room_id=="P-R14" and not app.busy and app.player.is_on_floor(),"P27 actual upper doorway into guardian approach "+str(app.player.position))
	app.controller.router.clear("doorway check complete")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(3)
	print("PLAINS35: ",failures," failures");quit(failures)
