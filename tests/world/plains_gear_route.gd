extends "res://tests/world/plains_first_loop.gd"
## Declared P-R05 entry; moving supports, reward and return all use real input.
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://plains_gear_route_fixture.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);app.start_new();await settle();app.load_room("P-R05","");await settle()
	var ride:=preload("res://tests/world/plains_mill_route.gd").new();ride.app=app
	check(await walk(Vector2(544,1022),"P-R05"),"enter optional gear challenge from main ground")
	var first:=app.room.get_node("Carrier0") as WorldMovingPlatform
	check(await ride.shoot_bell("P-R05:drive_shuttle"),"real bell starts carrier and coupled gear")
	check(await ride.board(first),"board first slow carrier")
	for _i: int in 1000:
		await ticks(1)
		var dx:=first.position.x-24-app.player.position.x
		ride.axis(signf(dx) if absf(dx)>3 else 0)
		var gear:=app.room.get_node("drive_gear") as WorldGearObstacle
		if first.position.x>830 and gear.wheel.position.y>871:break
	app.controller.router.set_source_axis(&"keyboard_mouse",1)
	app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(9)
	var drive_latch:=app.room.mechanisms["P-R05:drive_shuttle"] as WorldShotLatch
	app.controller.router.request_action(&"shoot_release",(drive_latch.bell_position-app.player.position).normalized());await ticks(8)
	app.controller.router.set_jump_held(&"keyboard_mouse",false)
	check(await walk(Vector2(1104,910),"P-R05"),"air shot recoil lands inspection pier")
	check(not first.motion_running,"same airborne shot parks the shared drive")
	var gear_clock: float=app.room.get_node("drive_gear").clock;await ticks(20)
	check(app.room.get_node("drive_gear").clock==gear_clock,"parked drive freezes gear too")
	check(absf(app.player.position.y-910)<8,"first carrier to inspection pier")
	check(await walk(Vector2(1200,910),"P-R05"),"prepare second carrier departure")
	var second:=app.room.get_node("Carrier1") as WorldMovingPlatform
	check(await ride.board(second),"board second slow carrier")
	for _i: int in 360:
		await ticks(1)
		if second.position.x>1410:break
	await hop(Vector2(1632,782),Vector2(-1,.4))
	check(absf(app.player.position.y-782)<8,"second carrier to gear bank")
	check(await walk(Vector2(1728,782),"P-R05"),"approach visible time gear")
	app.controller.router.request_action(&"interact");await ticks(6)
	check(app.state.value.receipts.has("pickup_TG02"),"earned gear through full challenge")
	check(await walk(Vector2(1800,782),"P-R05"),"reach reward-side release")
	var hatch:=app.room.get_node("RewardReturn") as WorldReturnLatch
	app.state.storage.blocked=true
	app.controller.router.request_action(&"interact");await ticks(6)
	check(not app.state.has(hatch.action_id) and hatch.hatch_opening==0 and hatch.closed_bodies[0].collision_layer==1,"failed save leaves hatch visibly and physically closed")
	app.state.storage.blocked=false
	app.controller.router.request_action(&"interact");await ticks(6)
	check(app.state.has("reward_return_TG02_open"),"committed return hatch")
	check(not hatch.closed_bodies[0].collision_layer,"accepted opening clears the return bulkhead")
	check(await walk(Vector2(1872,1134),"P-R05"),"drop through single-direction return shaft")
	check(await walk(Vector2(1683,1134),"P-R05"),"return beneath reward structure to main route")
	app.controller.router.request_action(&"interact");await ticks(6)
	check(app.state.has("shortcut_p02"),"main-road bridge remains reachable")
	# From the return floor, jumping/recoiling upward cannot reverse the reward drop.
	check(await walk(Vector2(1872,1134),"P-R05"),"approach open shaft from main route")
	await hop(Vector2(1872,782),Vector2.DOWN)
	check(app.player.position.y>1056,"opened hatch does not create reverse climb")
	check(await maintenance_route(),"stable main route and guided cage reach Boss approach after collection return")
	await settle();check(app.room.room_id=="P-R14","main route actually enters boss forecourt")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8)
	print("PLAINS GEAR ROUTE: ",failures," failures");quit(failures)
