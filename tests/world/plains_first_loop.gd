extends "res://tests/world/plains_gates.gd"
## Continuous new game → west circuit → earned H → clock → station. No fixture grants.
var expected_final_cycle:=4
func route(points: Array,rid: String,target: String="") -> bool:
	if app.room.room_id!=rid:check(false,"route expected "+rid+" got "+app.room.room_id);return false
	if not await path(points,rid):check(false,"continuous path "+rid);return false
	await settle()
	if not target.is_empty():check(app.room.room_id==target,rid+" actual door to "+target)
	return failures==0
func hop(at: Vector2,aim: Vector2) -> void:
	app.controller.router.set_source_axis(&"keyboard_mouse",signf(at.x-app.player.position.x))
	app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(9)
	app.controller.router.request_action(&"shoot_release",aim.normalized());await ticks(8)
	app.controller.router.set_jump_held(&"keyboard_mouse",false)
	for i: int in 120:
		await physics_frame
		var dx:=at.x-app.player.position.x
		app.controller.router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>5 else 0)
		if app.player.is_on_floor():break
	app.controller.router.clear("hop_landed");print("HOP ",app.player.position)
func clear_enemies() -> void:
	var hold_x:=app.player.position.x
	for actor: EnemyActor in app.room.enemies.values():
		if actor.motor.position.distance_to(app.player.position)>500:continue
		for i: int in 240:
			await physics_frame
			if actor.health.terminal or app.busy:break
			var dx:=hold_x-app.player.position.x
			app.controller.router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>4 else 0)
			if i%20==0:app.controller.router.request_action(&"shoot_release",(actor.motor.position-app.player.position).normalized())
	app.controller.router.clear("encounter_cleared")
func run() -> void:
	replay_save_path="user://plains_full_loop_replay.json"
	await play_intro()
	if failures>0:await done();return
	if not await route([Vector2(6,622)],"P-R01","P-R08"):await done();return
	var bell:=app.room.mechanisms["P-R08:well_lift"] as WorldShotLatch
	var lift:=bell.motion_target as WorldMovingPlatform
	app.controller.router.request_action(&"shoot_release",(bell.bell_position-app.player.position).normalized());await ticks(8)
	app.controller.router.set_jump_held(&"keyboard_mouse",true)
	for i: int in 80:
		await physics_frame
		var dx:=lift.position.x-app.player.position.x
		app.controller.router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>3 else 0)
		if i==30:app.controller.router.set_jump_held(&"keyboard_mouse",false)
		if i>10 and app.player.is_on_floor():break
	app.controller.router.clear("lift_boarded");print("BOARD ",app.player.position," lift=",lift.position," running=",lift.motion_running)
	for i: int in 560:
		await physics_frame
		if app.player.position.y<180:break
	print("TOP ",app.player.position," lift=",lift.position)
	await hop(Vector2(672,142),Vector2(1,.2))
	if not await route([Vector2(592,142),Vector2(512,-18)],"P-R08","P-R06"):await done();return
	await hop(Vector2(640,878),Vector2(1,.2));await clear_enemies()
	if not await route([Vector2(6,878)],"P-R06","P-R13"):await done();return
	if not await route([Vector2(1120,750),Vector2(944,798)],"P-R13"):await done();return
	await hop(Vector2(672,750),Vector2(1,.2))
	await hop(Vector2(448,750),Vector2(1,.1));await clear_enemies()
	if not await route([Vector2(6,750)],"P-R13","P-R04"):await done();return
	if not await route([Vector2(1840,390),Vector2(1664,318),Vector2(1840,238),Vector2(1920,238),Vector2(2042,238)],"P-R04","P-R25"):await done();return
	if not await route([Vector2(448,878)],"P-R25"):await done();return
	await clear_enemies()
	if not await route([Vector2(912,878)],"P-R25"):await done();return
	await hop(Vector2(1200,878),Vector2(-1,.1));await clear_enemies()
	if not await route([Vector2(2042,878)],"P-R25","P-R26"):await done();return
	if not await route([Vector2(480,1262)],"P-R26"):await done();return
	await clear_enemies()
	if not await route([Vector2(1840,1262),Vector2(1872,1190),Vector2(1728,1118),Vector2(1872,1046),Vector2(1968,974),Vector2(1728,910),Vector2(1584,838),Vector2(1424,766),Vector2(1248,694),Vector2(1072,622),Vector2(896,550),Vector2(1072,478),Vector2(1248,406),Vector2(1072,334),Vector2(896,262),Vector2(944,190),Vector2(1168,142),Vector2(1104,142),Vector2(1024,-18)],"P-R26","P-R27"):await done();return
	if not await route([Vector2(912,494)],"P-R27"):await done();return
	await hop(Vector2(320,494),Vector2(1,.2))
	await walk(Vector2(320,494),"P-R27");app.controller.router.request_action(&"interact");await ticks(8)
	check(app.state.value.rest.room=="P-R27","explicit west shelter rest")
	if not await route([Vector2(720,542),Vector2(1008,494),Vector2(1146,494)],"P-R27","P-R05"):await done();return
	if not await route([Vector2(320,878),Vector2(1683,878)],"P-R05"):await done();return
	app.controller.router.request_action(&"interact");await ticks(5);check(app.state.has("shortcut_p02"),"open slow-platform return from correct side")
	if not await route([Vector2(208,806),Vector2(320,734),Vector2(432,662),Vector2(544,590),Vector2(656,518),Vector2(752,430),Vector2(6,430)],"P-R05","P-R14"):await done();return
	if not await route([Vector2(1776,846)],"P-R14"):await done();return
	await hop(Vector2(1936,742),Vector2(-1,.6))
	if not await route([Vector2(1572,742)],"P-R14"):await done();return
	var won:=false
	for tick: int in 7200:
		await physics_frame
		if app.busy:continue
		if app.room.room_id!="P-R14":break
		if app.state.has("boss_P_WINDKEEPER_defeated"):won=true;break
		var encounter:=app.room.encounter as WindkeeperPressureEncounter
		var at:=app.player.position;var target:=app.room.boss.position-Vector2(0,70)
		var destination:=1452.0
		if absf(target.x-at.x)<200:destination=872 if target.x>1192 else 1452
		app.controller.router.set_source_axis(&"keyboard_mouse",signf(destination-at.x) if absf(destination-at.x)>25 else 0)
		if app.player.is_on_floor() and (at.y>638 or "warning" in str(encounter.mode)):
			app.controller.router.set_jump_held(&"keyboard_mouse",false);app.controller.router.set_jump_held(&"keyboard_mouse",true)
		elif tick%45==0:app.controller.router.set_jump_held(&"keyboard_mouse",false)
		if tick%20==0:app.controller.router.request_action(&"shoot_release",(target-at).normalized())
		if tick%180==0:print("BOSS ",at," hp=",app.controller.actor_resources.health.current," boss=",encounter.health.current," ",encounter.mode)
	check(won,"real Windkeeper victory with base gun and no H")
	if won:
		app.controller.router.clear("victory")
		check(await walk(Vector2(1800,1134),"P-R14"),"leave arena and descend reward forecourt")
		app.controller.router.request_action(&"interact");await ticks(5)
		check(app.state.has("H") and app.state.value.receipts.has("get_H"),"physical H pickup")
		var count: int=app.state.value.receipts.size()
		app.controller.router.request_action(&"interact");await ticks(5)
		check(app.state.value.receipts.size()==count,"no duplicate reward")
	if not won:await done();return
	if not await route([Vector2(1928,1134)],"P-R14"):await done();return
	app.controller.router.request_action(&"interact");await ticks(5);check(app.state.has("shortcut_p03"),"open defeated arena return gate")
	if not await route([Vector2(1264,1182),Vector2(1088,1262)],"P-R14","P-R15"):await done();return
	if not await route([Vector2(1016,1182),Vector2(1504,1134)],"P-R15"):await done();return
	app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(8)
	for anchor: Vector2 in app.room.hook_points:
		check(await hook(anchor),"earned H climbs clock anchors")
		app.controller.router.set_jump_held(&"keyboard_mouse",false)
	app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(20);app.controller.router.set_jump_held(&"keyboard_mouse",false)
	if not await route([Vector2(1632,686)],"P-R15"):await done();return
	app.controller.router.request_action(&"interact");await ticks(5);check(app.state.has("clock_P"),"repair clock with actually earned H")
	if not await route([Vector2(1728,686)],"P-R15"):await done();return
	app.controller.router.request_action(&"interact");await ticks(5);check(app.state.has("shortcut_p01"),"open real clock return")
	if not await route([Vector2(1992,1134),Vector2(1504,1134),Vector2(1184,1182),Vector2(1024,1262)],"P-R15","P-R32"):await done();return
	if not await route([Vector2(1200,1134),Vector2(6,1134)],"P-R32","P-R31"):await done();return
	if not await route([Vector2(6,878)],"P-R31","P-R01"):await done();return
	if not await route([Vector2(320,622)],"P-R01"):await done();return
	app.controller.router.request_action(&"interact");await ticks(8)
	check(app.state.value.rest.room=="P-R01" and app.state.value.cycle==expected_final_cycle,"continuous clock loop returns and explicitly rests at station")
	for flag: String in ["H","clock_P","shortcut_p01","shortcut_p02","shortcut_p03"]:check(app.state.has(flag),"earned and persisted "+flag)
	await done()
func done() -> void:
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8);print("PLAINS FIRST LOOP: ",failures," failures");quit(failures)
