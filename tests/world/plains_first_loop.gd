extends "res://tests/world/plains_gates.gd"
## Continuous new game → west circuit → earned H → clock → station. No fixture grants.
func well_route() -> bool:
	if not await walk(Vector2(256,2702),"P-R08"):return false
	await full_jump(Vector2(400,2670))
	await hop(Vector2(672,2670),Vector2(-1,.1))
	if not await walk(Vector2(768,2670),"P-R08"):return false
	await clear_enemies(112)
	if not await walk(Vector2(768,2670),"P-R08"):return false
	var lift:=app.room.get_node("WellLift") as WorldMovingPlatform
	app.controller.router.request_action(&"shoot_release",(Vector2(704,2616)-app.player.position).normalized())
	await ticks(8)
	app.controller.router.set_source_axis(&"keyboard_mouse",1)
	app.controller.router.set_jump_held(&"keyboard_mouse",true)
	for i: int in 120:
		await physics_frame
		var dx:=832-app.player.position.x
		app.controller.router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>3 else 0)
		if i==32:app.controller.router.set_jump_held(&"keyboard_mouse",false)
		if i>8 and app.player.is_on_floor():break
	app.controller.router.clear("well_board")
	print("WELL BOARD ",app.player.position," cage=",lift.position)
	if absf(app.player.position.y-(lift.position.y-28))>6:return false
	for i: int in 1000:
		await physics_frame
		if lift.position.y<1568:break
	print("WELL DEPART ",app.player.position," cage=",lift.position," floor=",app.player.is_on_floor()," hp=",app.controller.actor_resources.health.current)
	# One accepted airborne shot both parks the cage and recoils left/up to
	# the inspection alcove. This is a real projectile, not a state write.
	app.controller.router.set_source_axis(&"keyboard_mouse",-1)
	app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(9)
	print("WELL AIR SHOT ",app.player.position," aim=",Vector2(960,1480)-app.player.position)
	app.controller.router.request_action(&"shoot_release",(Vector2(960,1480)-app.player.position).normalized())
	await ticks(8);app.controller.router.set_jump_held(&"keyboard_mouse",false)
	for i: int in 150:
		await physics_frame
		var dx:=528-app.player.position.x
		app.controller.router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>4 else 0)
		if app.player.is_on_floor():break
	app.controller.router.clear("inspection_landing")
	print("WELL INSPECTION ",app.player.position," stopped=",not lift.motion_running," cage=",lift.position)
	if lift.motion_running or absf(app.player.position.y-1470)>6:return false
	# Read the visible cross-cam from a grounded recovery alcove before the
	# second departure. Landing is still performed by the production motor.
	await ticks(90)
	await hop(Vector2(832,lift.position.y-28),Vector2(-1,.4))
	print("WELL REBOARD ",app.player.position," cage=",lift.position)
	if not app.player.is_on_floor() or absf(app.player.position.y-(lift.position.y-28))>8:return false
	var cam:=app.room.get_node("well_cam") as WorldGearObstacle
	var previous_x:=cam.wheel.position.x
	for i: int in 400:
		await ticks(1)
		var current_x:=cam.wheel.position.x
		if current_x<previous_x and current_x>780 and current_x<810:break
		previous_x=current_x
	app.controller.router.request_action(&"shoot_release",(Vector2(832,1360)-app.player.position).normalized());await ticks(8)
	for i: int in 1200:
		await physics_frame
		if app.busy:return false
		var dx:=832-app.player.position.x
		app.controller.router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>3 else 0)
		if i%90==0:print("WELL RIDE ",app.player.position," cage=",lift.position," hp=",app.controller.actor_resources.health.current)
		if lift.position.y<180:break
	await hop(Vector2(672,142),Vector2(1,.2))
	return await route([Vector2(672,-18)],"P-R08","P-R06")
func full_jump(at: Vector2,run_frames: int=0) -> Dictionary:
	app.controller.router.set_source_axis(&"keyboard_mouse",signf(at.x-app.player.position.x))
	await ticks(run_frames)
	app.controller.router.set_jump_held(&"keyboard_mouse",true)
	var furthest: float=app.player.position.x if app.player.position.y<=at.y else -INF
	for i: int in 120:
		await ticks(1)
		if app.player.position.y<=at.y:furthest=maxf(furthest,app.player.position.x)
		var dx:=at.x-app.player.position.x
		app.controller.router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>4 else 0)
		if i>8 and app.player.is_on_floor():break
	app.controller.router.clear("full_jump_landed")
	print("FULL JUMP landed=",app.player.position," max_x_above_target=",furthest)
	return {"landed":app.player.position,"furthest":furthest}

func station_well() -> bool:
	if not await walk(Vector2(1344,622),"P-R01"):return false
	var lift:=app.room.get_node("StationLift") as WorldMovingPlatform
	for i: int in 900:
		await physics_frame
		if lift.position.y>640 and lift.position.y<720:break
	await full_jump(Vector2(1456,lift.position.y-28))
	if absf(app.player.position.y-(lift.position.y-28))>8:return false
	for i: int in 900:
		await physics_frame
		if lift.position.y<240:break
	await full_jump(Vector2(1616,142))
	return await route([Vector2(1786,142)],"P-R01","P-R08")
func western_approach(collect_shoulder: bool=false) -> bool:
	await clear_enemies(320)
	if not await route([Vector2(1472,1390)],"P-R06"):return false
	await hop(Vector2(1264,1166),Vector2(.5,1))
	if absf(app.player.position.y-1166)>8:return false
	if not await walk(Vector2(1216,1166),"P-R06"):return false
	await clear_enemies(112)
	if not await route([Vector2(896,1422),Vector2(646,1422)],"P-R06","P-R13"):return false
	# Descend the two turnbacks, fighting the cliff diver on its own ledge.
	if not await route([Vector2(4928,142),Vector2(4640,366),Vector2(4864,558),Vector2(4640,750)],"P-R13"):return false
	await clear_enemies(200)
	if not await route([Vector2(4864,942),Vector2(4768,1166),Vector2(4960,1390),Vector2(4608,1614),Vector2(4928,1838),Vector2(4576,1998),Vector2(4416,2158),Vector2(3760,2286)],"P-R13"):return false
	await clear_enemies(128)
	if not await walk(Vector2(3504,2286),"P-R13"):return false
	await hop(Vector2(3360,2126),Vector2(.5,1))
	await hop(Vector2(3088,2286),Vector2(1,.4))
	await hop(Vector2(2800,2126),Vector2(.5,1))
	if not await route([Vector2(2592,2286)],"P-R13"):return false
	await clear_enemies(128)
	if not await route([Vector2(1568,2286),Vector2(1360,2510),Vector2(1456,2670),Vector2(1344,2798),Vector2(800,2798)],"P-R13"):return false
	await clear_enemies(128)
	if not await walk(Vector2(800,2798),"P-R13"):return false
	await hop(Vector2(544,2686),Vector2(.6,1))
	if collect_shoulder:
		if not await walk(Vector2(624,2686),"P-R13"):return false
		await hop(Vector2(1024,2574),Vector2(-1,.25))
		if not await walk(Vector2(1024,2574),"P-R13"):return false
		app.controller.router.request_action(&"interact");await ticks(6)
		check(app.state.value.receipts.has("pickup_HP01"),"physical shoulder reward from its lower approach")
		if not await walk(Vector2(1120,2574),"P-R13"):return false
		app.controller.router.request_action(&"interact");await ticks(6)
		check(app.state.has("reward_return_HP01_open"),"reward-side floor hatch opens after committed interaction")
		if not await path([Vector2(1120,2798),Vector2(800,2798)],"P-R13"):return false
		await hop(Vector2(544,2686),Vector2(.6,1))
	if not await walk(Vector2(464,2686),"P-R13"):return false
	await hop(Vector2(240,2574),Vector2(.6,1))
	if not await route([Vector2(6,2574)],"P-R13","P-R04"):return false
	return await field_route()
func maintenance_route() -> bool:
	if not await path([Vector2(384,1134),Vector2(1683,1134)],"P-R05"):return false
	app.controller.router.request_action(&"interact");await ticks(5)
	if not app.state.has("shortcut_p02"):return false
	if not await walk(Vector2(1872,1134),"P-R05"):return false
	var cage:=app.room.get_node("ServiceCage") as WorldMovingPlatform
	app.controller.router.request_action(&"shoot_release",(Vector2(1808,1096)-app.player.position).normalized());await ticks(8)
	await full_jump(Vector2(1936,cage.position.y-28))
	if absf(app.player.position.y-cage.position.y+28)>8:return false
	for i: int in 1500:
		await ticks(1)
		var dx:=cage.position.x-app.player.position.x
		app.controller.router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>3 else 0)
		if cage.position.x>2350 and cage.position.y<240:break
	app.controller.router.clear("maintenance_arrived")
	await full_jump(Vector2(2224,142))
	return await route([Vector2(2054,142)],"P-R05","P-R14")
func rise_then_cross(at: Vector2,use_recoil: bool=false) -> void:
	app.controller.router.set_source_axis(&"keyboard_mouse",0)
	app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(9)
	if use_recoil:
		app.controller.router.request_action(&"shoot_release",Vector2.DOWN);await ticks(9)
	else:await ticks(9)
	for i: int in 120:
		await ticks(1)
		var dx:=at.x-app.player.position.x
		app.controller.router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>4 else 0)
		if i==22:app.controller.router.set_jump_held(&"keyboard_mouse",false)
		if i>5 and app.player.is_on_floor():break
	app.controller.router.clear("ledge_landed")
	print("LEDGE ",app.player.position," target=",at)

func field_route() -> bool:
	# Fight through the planted field before turning up the orchard shoulder.
	if not await walk(Vector2(1536,974),"P-R04"):return false
	await clear_enemies(180)
	if not await walk(Vector2(1440,1134),"P-R04"):return false
	await clear_enemies(96)
	if not await path([Vector2(1200,1038),Vector2(1120,1038)],"P-R04"):return false
	await clear_enemies()
	if not await walk(Vector2(736,1038),"P-R04"):return false
	await hop(Vector2(944,862),Vector2(-.4,1))
	if absf(app.player.position.y-862)>8:return false
	await full_jump(Vector2(752,750))
	if not await walk(Vector2(608,750),"P-R04"):return false
	await rise_then_cross(Vector2(736,526),true)
	if absf(app.player.position.y-526)>8:return false
	await hop(Vector2(496,382),Vector2(.7,1))
	await hop(Vector2(752,270),Vector2(-.7,1))
	return await route([Vector2(800,174),Vector2(954,174)],"P-R04","P-R25")
func route(points: Array,rid: String,target: String="") -> bool:
	if app.room.room_id!=rid:check(false,"route expected "+rid+" got "+app.room.room_id);return false
	if not await path(points,rid):check(false,"continuous path "+rid);return false
	await settle()
	if not target.is_empty():
		var paired:=false
		for entry: Dictionary in app.content.room(target).doors:
			if entry.target_room==rid and entry.id==app.state.value.entry:paired=true
		check(app.room.room_id==target and paired,rid+" actual paired door to "+target+" (not a death return)")
	return failures==0
func hop(at: Vector2,aim: Vector2,shot_frame: int=9) -> void:
	app.controller.router.set_source_axis(&"keyboard_mouse",signf(at.x-app.player.position.x) if absf(at.x-app.player.position.x)>8 else 0)
	app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(shot_frame)
	app.controller.router.request_action(&"shoot_release",aim.normalized());await ticks(8)
	app.controller.router.set_jump_held(&"keyboard_mouse",false)
	var high:=app.player.position.y
	for i: int in 120:
		await physics_frame
		high=minf(high,app.player.position.y)
		var dx:=at.x-app.player.position.x
		app.controller.router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>5 else 0)
		if app.player.is_on_floor():break
	app.controller.router.clear("hop_landed");print("HOP ",app.player.position," apex=",high)
func clear_enemies(max_vertical: float=INF) -> void:
	var hold_x:=app.player.position.x
	for actor: EnemyActor in app.room.enemies.values():
		if actor.motor.position.distance_to(app.player.position)>500 or absf(actor.motor.position.y-app.player.position.y)>max_vertical:continue
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
	if not await station_well():check(false,"station lift to eastern well");await done();return
	if not await well_route():check(false,"well machinery route");await done();return
	if not await western_approach():check(false,"junction, shoulder and field continuous route");await done();return
	if not await route([Vector2(432,782),Vector2(576,878)],"P-R25"):await done();return
	await clear_enemies()
	if not await route([Vector2(1024,878)],"P-R25"):await done();return
	await hop(Vector2(1232,878),Vector2(-1,.1))
	if not await route([Vector2(1680,782),Vector2(1904,878),Vector2(2042,878)],"P-R25","P-R26"):await done();return
	var mill_route:=preload("res://tests/world/plains_mill_route.gd").new()
	if not await mill_route.run(app):check(false,"mill physical route "+mill_route.checkpoint);await done();return
	if not await route([Vector2(1104,142),Vector2(1184,-18)],"P-R26","P-R27"):await done();return
	if not await route([Vector2(984,494)],"P-R27"):await done();return
	await full_jump(Vector2(784,494))
	if not await route([Vector2(320,494)],"P-R27"):await done();return
	app.controller.router.request_action(&"interact");await ticks(8)
	check(app.state.value.rest.room=="P-R27","explicit west shelter rest")
	if not await walk(Vector2(480,494),"P-R27"):await done();return
	await rise_then_cross(Vector2(592,382))
	if not await walk(Vector2(768,382),"P-R27"):await done();return
	await full_jump(Vector2(928,270))
	if not await route([Vector2(1146,270)],"P-R27","P-R05"):await done();return
	if not await maintenance_route():check(false,"stable road and guided maintenance cage to Boss");await done();return
	if not await forecourt_climb():check(false,"forecourt stairs reach actual arena entry");await done();return
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
		check(await path([Vector2(1936,910),Vector2(1872,990),Vector2(1696,1134),Vector2(1800,1134)],"P-R14"),"leave arena and descend reward forecourt")
		app.controller.router.request_action(&"interact");await ticks(5)
		check(app.state.has("H") and app.state.value.receipts.has("get_H"),"physical H pickup")
		var count: int=app.state.value.receipts.size()
		app.controller.router.request_action(&"interact");await ticks(5)
		check(app.state.value.receipts.size()==count,"no duplicate reward")
	if not won:await done();return
	check(await clock_return(),"earned H gallery, clock repair and physical station return")

	await done()
func forecourt_climb() -> bool:
	if not await walk(Vector2(1696,1134),"P-R14"):return false
	await rise_then_cross(Vector2(1808,990))
	if not await walk(Vector2(1856,990),"P-R14"):return false
	await rise_then_cross(Vector2(1744,846))
	await full_jump(Vector2(1936,742))
	return app.player.is_on_floor() and absf(app.player.position.y-742)<8
func clock_return() -> bool:
	if not await route([Vector2(1928,1166)],"P-R14"):return false
	app.controller.router.request_action(&"interact");await ticks(5)
	check(app.state.has("shortcut_p03"),"open defeated arena return gate")
	if not await forecourt_climb():return false
	app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(8)
	for anchor: Vector2 in app.room.hook_points:
		if not await hook(anchor):return false
		app.controller.router.set_jump_held(&"keyboard_mouse",false)
	app.controller.router.set_source_axis(&"keyboard_mouse",1)
	app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(20)
	app.controller.router.set_jump_held(&"keyboard_mouse",false)
	if not await route([Vector2(4400,366),Vector2(4512,494)],"P-R14","P-R15"):return false
	# Two shaft turns lead into the clock chamber; the repair itself remains H locked.
	await full_jump(Vector2(832,846))
	if not await path([Vector2(1024,1134),Vector2(800,1358),Vector2(640,1646),Vector2(1008,2158),Vector2(1208,2318),Vector2(944,2462),Vector2(1208,2606),Vector2(944,2750),Vector2(1208,2894),Vector2(944,3038),Vector2(1104,3182),Vector2(1504,3182)],"P-R15"):return false
	app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(8)
	for i: int in 3:
		if not await hook(app.room.hook_points[i]):return false
		app.controller.router.set_jump_held(&"keyboard_mouse",false)
	app.controller.router.set_source_axis(&"keyboard_mouse",1)
	app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(20)
	app.controller.router.set_jump_held(&"keyboard_mouse",false)
	if not await walk(Vector2(1632,2734),"P-R15"):return false
	app.controller.router.request_action(&"interact");await ticks(5)
	check(app.state.has("clock_P"),"repair clock with actually earned H")
	if not await walk(Vector2(1728,2734),"P-R15"):return false
	app.controller.router.request_action(&"interact");await ticks(5)
	check(app.state.has("shortcut_p01"),"open real clock return")
	if not await route([Vector2(1992,3182),Vector2(1904,3182),Vector2(1792,3310)],"P-R15","P-R32"):return false
	if not await route([Vector2(1008,1134),Vector2(144,1166),Vector2(6,1166)],"P-R32","P-R31"):return false
	# Descend beyond the sentry line, then use the low stonework as recoil cover.
	if not await route([Vector2(1392,878)],"P-R31"):return false
	await clear_enemies(128)
	if not await walk(Vector2(1296,878),"P-R31"):return false
	await hop(Vector2(992,750),Vector2(1,.65),15)
	if not await route([Vector2(704,878),Vector2(512,766),Vector2(320,654),Vector2(6,654)],"P-R31","P-R01"):return false
	if not await station_hall():return false
	app.controller.router.request_action(&"interact");await ticks(8)
	check(app.state.value.rest.room=="P-R01","continuous clock loop returns and explicitly rests at station")
	for flag: String in ["H","clock_P","shortcut_p01","shortcut_p02","shortcut_p03"]:
		check(app.state.has(flag),"earned and persisted "+flag)
	return failures==0
func done() -> void:
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8);print("PLAINS FIRST LOOP: ",failures," failures");quit(failures)
