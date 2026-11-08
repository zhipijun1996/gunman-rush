extends "res://tests/world/plains_first_loop.gd"
## Adversarial real-input departures: full hold, edge offsets and coyote time.
## Max x above the landing height distinguishes geometry from a later hazard hit.
func fixture(rid: String) -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://plains_recoil_edges.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);app.start_new();await settle();app.load_room(rid,"");await settle()
func release() -> void:
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8)
func run() -> void:
	for east: bool in [false,true]:
		for delay: int in [0,6,10]:
			await fixture("P-R25")
			check(await walk(Vector2(479,782),"P-R25"),"reach orchard edge through real approach")
			if east:
				await hop(Vector2(864,686),Vector2(-1,.6))
				check(absf(app.player.position.y-686)<8,"first recoil earns west branch before second counterexample")
				check(await walk(Vector2(991,686),"P-R25"),"stand at branch end")
			var serial:=app.controller.shoot_ability._shot_serial
			var result:=await full_jump(Vector2(1408,606) if east else Vector2(864,686),delay)
			check(result.furthest+12<(1248 if east else 736),"full/coyote jump cannot span orchard landing: "+str([east,delay]))
			check(app.controller.shoot_ability._shot_serial==serial,"counterexample adds no shot")
			await release()
	for height: float in [880,850,825]:
		await fixture("P-R26")
		var ride:=preload("res://tests/world/plains_mill_route.gd").new();ride.app=app
		check(await ride.walk_to(384,1262),"reach west bell")
		check(await ride.shoot_bell("P-R26:carrier_west"),"real shot starts carrier")
		check(await ride.walk_to(512,1262),"reach carrier approach")
		var west:=app.room.get_node("Carrier0") as WorldMovingPlatform
		check(await ride.board(west),"board actual carrier")
		for i: int in 420:
			await ticks(1)
			var dx:=west.position.x+70-app.player.position.x
			ride.axis(signf(dx) if absf(dx)>3 else 0)
			if west.position.y<height:break
		var result:=await full_jump(Vector2(1040,686),5)
		check(result.furthest+12<896,"carrier edge/top full jump cannot reach inspection ledge: "+str(height))
		check(app.room.room_id=="P-R26" and app.controller.actor_resources.health.current>0,"miss has real recovery ground")
		await release()
	print("PLAINS RECOIL EDGES: ",failures," failures");quit(failures)
