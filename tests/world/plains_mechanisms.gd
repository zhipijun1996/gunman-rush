extends "res://tests/world/plains_intro.gd"
## Qualified platform approach, actual projectile switch and durable rollback/revisit.
func shoot(latch: WorldShotLatch) -> void:
	app.controller.router.request_action(&"shoot_release",(latch.bell_position-app.player.position).normalized());await ticks(35)
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_mechanism_fixture.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);app.start_new();await settle();app.load_room("P-R26","");await settle()
	app.player.reset_at(Vector2(500,1150));await ticks(4)
	var latch:=app.room.mechanisms["P-R26:carrier_west"] as WorldShotLatch
	var carrier:=latch.motion_target as WorldMovingPlatform
	var start:=carrier.position
	await ticks(60);check(not carrier.motion_running and carrier.position==start,"control carrier initially parked")
	app.state.storage.blocked=true;await shoot(latch)
	check(not carrier.motion_running and not app.state.value.mechanisms.has(latch.stable_id),"failed save cannot move carrier or claim successful activation")
	app.state.storage.blocked=false;app.player.reset_at(Vector2(500,1150));await ticks(3);await shoot(latch)
	check(carrier.motion_running and carrier.position.distance_to(start)>5,"real shot starts actual carrier after committed state")
	app.player.reset_at(Vector2(500,1150));await ticks(3);await shoot(latch)
	var parked:=carrier.position;var phase:=carrier.motion_clock
	check(not carrier.motion_running,"second real shot parks at current position")
	await ticks(40);check(carrier.position.distance_to(parked)<.1,"parked carrier does not drift")
	app.load_room("P-R27","");await settle();app.load_room("P-R26","");await settle()
	latch=app.room.mechanisms["P-R26:carrier_west"];carrier=latch.motion_target
	check(not carrier.motion_running and absf(carrier.motion_clock-phase)<.01 and carrier.position.distance_to(parked)<.1,"room revisit preserves parked phase")
	app.player.reset_at(Vector2(500,1150));await ticks(3);await shoot(latch)
	check(carrier.motion_running,"parked carrier can always restart from preparation ledge")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8);print("PLAINS MECHANISMS: ",failures," failures");quit(failures)
