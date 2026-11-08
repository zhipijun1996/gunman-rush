extends "res://tests/world/plains_first_loop.gd"
## Full local approach plus independent counterexamples; all movement after entry is input.
func fixture() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_cellar.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);app.start_new();await settle();app.load_room("P-R12","");await settle()
func release() -> void:
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8)
func shoot_cross(fire: int,shoot: bool=true) -> void:
	var latch:=app.room.mechanisms["P-R12:air_shutter"] as WorldShotLatch
	app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true)
	await ticks(fire)
	if shoot:app.controller.router.request_action(&"shoot_release",(latch.bell_position-app.player.position).normalized())
	for i: int in 100:
		await ticks(1)
		if i>8 and app.player.is_on_floor():break
	app.controller.router.clear("shutter_landing")
func run() -> void:
	await fixture()
	check(await path([Vector2(400,878),Vector2(512,782),Vector2(672,878)],"P-R12"),"enter lower aisle past real buttress")
	await clear_enemies()
	check(await path([Vector2(672,878),Vector2(752,750),Vector2(672,622)],"P-R12"),"physical lower approach to visible shutter pocket")
	var latch:=app.room.mechanisms["P-R12:air_shutter"] as WorldShotLatch
	app.controller.router.request_action(&"shoot_release",(latch.bell_position-app.player.position).normalized());await ticks(24)
	check(latch.open_count==0,"stone lip blocks a standing shot; no airborne flag required")
	check(await path([Vector2(752,750),Vector2(672,622)],"P-R12"),"retry via approach pedestal after blocked ground shot")
	await shoot_cross(11)
	check(absf(app.player.position.y-462)<8 and latch.open_count==1,"one airborne shot opens shutter and recoils onto storage bank")
	check(await walk(Vector2(1104,462),"P-R12"),"actual storage reward approach")
	app.controller.router.request_action(&"interact");await ticks(6)
	check(app.state.value.receipts.has("pickup_EQ_MAP_P01"),"earned cellar equipment")
	check(await walk(Vector2(1152,462),"P-R12"),"reward-side return lever")
	app.controller.router.request_action(&"interact");await ticks(6)
	check(app.state.has("reward_return_EQ_MAP_P01_open"),"accepted short return")
	check(await path([Vector2(1264,558),Vector2(1200,654),Vector2(1280,750),Vector2(1408,878)],"P-R12"),"return to main floor without repeating shutter")
	check(not app.state.value.mechanisms.has("P-R12:air_shutter"),"short opening is not a permanent save entitlement")
	app.load_room("P-R12","");await settle()
	check(not app.room.mechanisms["P-R12:air_shutter"].is_open,"room reentry rebuilds timed shutter closed")
	await release()
	if "--positive-only" in OS.get_cmdline_user_args():print("PLAINS CELLAR: ",failures," failures");quit(failures);return
	for mode: String in ["late","no_recoil","miss"]:
		await fixture();app.player.reset_at(Vector2(672,622));await ticks(3)
		if mode=="no_recoil":app.controller.recoil_ability.enabled=false
		await shoot_cross(23 if mode=="late" else 11,mode!="miss")
		latch=app.room.mechanisms["P-R12:air_shutter"]
		if mode=="late":
			check(absf(app.player.position.y-462)<8 and latch.open_count==1,"later legal shot also reaches reward side")
			await ticks(90);check(latch.is_open,"expired shutter waits while player overlaps the doorway")
			check(await walk(Vector2(912,462),"P-R12"),"leave the doorway normally")
		else:
			check(app.player.position.y>600,"missing shot or recoil cannot reach storage: "+mode)
			check(latch.open_count==(1 if mode=="no_recoil" else 0),"counterexample retains actual projectile result: "+mode)
		await ticks(90);check(not latch.is_open,"window expires without sticking open")
		await release()
	# Adversarial open-door fixtures isolate geometry from timer/collision: legal ledge edges.
	for edge: float in [688,703,714]:
		for delay: int in [0,6]:
			await fixture();app.player.reset_at(Vector2(edge,622));await ticks(3)
			latch=app.room.mechanisms["P-R12:air_shutter"]
			latch.open_seconds=0;latch.restore_region_opened(true);await ticks(2)
			var result:=await full_jump(Vector2(912,462),delay)
			check(result.furthest+12<832,"already-open shutter does not allow full/edge/coyote jump: "+str([edge,delay]))
			await release()
	# Declared timer fixture at the same launch ledge; freeze while the real hit is open.
	await fixture();app.player.reset_at(Vector2(672,622));await ticks(3)
	app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(11)
	latch=app.room.mechanisms["P-R12:air_shutter"]
	app.controller.router.request_action(&"shoot_release",(latch.bell_position-app.player.position).normalized());await ticks(12)
	check(latch.is_open,"accepted timed opening before pause")
	paused=true;var clock:=latch._clock;await ticks(90);check(latch._clock==clock and latch.is_open,"pause freezes the playable window")
	paused=false;app.controller.router.clear("resume");await ticks(100)
	check(not latch.is_open,"timer closes after resumed game time")
	await release();print("PLAINS CELLAR: ",failures," failures");quit(failures)
