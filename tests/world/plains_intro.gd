extends SceneTree
## New game to station, real input only. No position, health, ability or progress writes.
var app: FixedWorldApp
var failures:=0
var replay_save_path:="user://plains_intro_replay.json"
func _initialize() -> void:run.call_deferred()
func ticks(n: int) -> void:
	for i: int in n:await physics_frame
func settle() -> void:
	for i: int in 240:
		await physics_frame
		if not app.busy:return
func check(ok: bool,label: String) -> void:
	print("INTRO ",ok," ",label)
	if not ok:failures+=1
func walk(point: Vector2,rid: String) -> bool:
	var held:=0
	for i: int in 700:
		await physics_frame
		if app.busy:continue
		if app.room.room_id!=rid:print("WALK TRANSITION ",rid," -> ",app.room.room_id," at ",app.player.position);return true
		var at:=app.player.position
		if i%120==0:print("WALK ",rid," ",at," -> ",point," hp=",app.controller.actor_resources.health.current)
		if absf(at.x-point.x)<8 and absf(at.y-point.y)<12 and app.player.is_on_floor():
			app.controller.router.clear("waypoint");return true
		var dx:=point.x-at.x
		app.controller.router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>3 else 0)
		if point.y>at.y+40 and absf(dx)<30 and app.player.is_on_floor():app.controller.router.request_action(&"drop_through")
		if app.player.is_on_floor() and point.y<at.y-30 and absf(dx)<300:
			app.controller.router.set_jump_held(&"keyboard_mouse",false);app.controller.router.set_jump_held(&"keyboard_mouse",true);held=32
		elif held>0:
			held-=1
			if held==0:app.controller.router.set_jump_held(&"keyboard_mouse",false)
	printerr("STUCK ",rid," ",app.player.position," -> ",point," ",app.status);return false
func path(points: Array,rid: String) -> bool:
	for p: Vector2 in points:
		if not await walk(p,rid):return false
	return true
func recoil_jump(direction: Vector2) -> void:
	app.controller.router.set_source_axis(&"keyboard_mouse",1)
	app.controller.router.set_jump_held(&"keyboard_mouse",true)
	await ticks(9);app.controller.router.request_action(&"shoot_release",direction)
	await ticks(7);app.controller.router.set_jump_held(&"keyboard_mouse",false)
	for i: int in 100:
		await physics_frame
		if app.player.is_on_floor():break
	app.controller.router.clear("landing")
	print("RECOIL LAND ",app.player.position)
func cross(at: Vector2,aim: Vector2=Vector2.ZERO,shot_frame: int=9) -> bool:
	app.controller.router.clear("approach")
	app.controller.router.set_source_axis(&"keyboard_mouse",signf(at.x-app.player.position.x))
	app.controller.router.set_jump_held(&"keyboard_mouse",true)
	for i: int in 160:
		await physics_frame
		if i==shot_frame and aim!=Vector2.ZERO:app.controller.router.request_action(&"shoot_release",aim.normalized())
		var dx:=at.x-app.player.position.x
		app.controller.router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>4 else 0)
		if i==32:app.controller.router.set_jump_held(&"keyboard_mouse",false)
		if i>8 and app.player.is_on_floor():break
	app.controller.router.clear("cross_landed")
	print("CROSS ",app.room.room_id," ",app.player.position," -> ",at)
	if absf(app.player.position.y-at.y)>8:return false
	return await walk(at,app.room.room_id)
func ride(name: String,origin: Vector2,leave_y: float,destination: Vector2) -> bool:
	var lift:=app.room.get_node(name) as WorldMovingPlatform
	app.controller.router.clear("wait_for_cage")
	var previous:=lift.position.distance_to(origin)
	for i: int in 1800:
		await physics_frame
		if not is_instance_valid(lift):return false
		var current:=lift.position.distance_to(origin)
		if current<1 or (current<160 and current<previous):break
		previous=current
	app.controller.router.set_jump_held(&"keyboard_mouse",true)
	var boarded:=false
	for i: int in 180:
		await physics_frame
		if not is_instance_valid(lift):return false
		var dx:=lift.position.x-app.player.position.x
		app.controller.router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>4 else 0)
		if i==32:app.controller.router.set_jump_held(&"keyboard_mouse",false)
		if i>8 and app.player.is_on_floor() and absf(app.player.position.y-lift.position.y+28)<8:boarded=true;break
	app.controller.router.clear("boarded")
	if not boarded:printerr("BOARD FAILED ",name," ",app.player.position," ",lift.position);return false
	for i: int in 1800:
		await physics_frame
		if not is_instance_valid(lift):return false
		if i%60==0:print("RIDE ",name," rider=",app.player.position," lift=",lift.position," floor=",app.player.is_on_floor())
		if lift.position.y<leave_y:break
	return await cross(destination)
func station_hall() -> bool:
	return await ride("StationLift",Vector2(544,1744),1344,Vector2(1328,1262))
func run() -> void:
	await play_intro()
	await finish()
func play_intro() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path=replay_save_path
	for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);check(app.start_new(),"new game");await settle()
	check(await path([Vector2(600,1774),Vector2(880,1710),Vector2(992,1710)],"P-R03"),"meadow short rise")
	check(await cross(Vector2(1232,1646)),"first held jump across a visible low recovery notch")
	check(await walk(Vector2(1632,1646),"P-R03"),"approach second grass bank")
	check(await cross(Vector2(1888,1582)),"repeat with raised landing")
	check(await walk(Vector2(2310,1582),"P-R03"),"walk into carriage")
	await settle();check(app.room.room_id=="P-R21" and app.state.has("intro_move"),"learned move/jump before carriage")
	if failures>0:return
	check(await path([Vector2(352,526),Vector2(736,526),Vector2(848,846)],"P-R21"),"descend beside carriage into cover aisle")
	for i: int in 240:
		await physics_frame
		if i%24==0:
			for enemy: EnemyActor in app.room.enemies.values():
				if not enemy.health.terminal:app.controller.router.request_action(&"shoot_release",(enemy.motor.position-app.player.position).normalized());break
	check(await path([Vector2(944,782),Vector2(1120,846)],"P-R21"),"change firing angle over cover")
	for i: int in 180:
		await physics_frame
		if i%24==0:
			for enemy: EnemyActor in app.room.enemies.values():
				if not enemy.health.terminal:app.controller.router.request_action(&"shoot_release",(enemy.motor.position-app.player.position).normalized());break
	check(app.state.has("intro_shoot"),"real accepted hit records shooting")
	check(await walk(Vector2(1264,782),"P-R21"),"upper cover gives a firing angle")
	for i: int in 100:
		await physics_frame
		if i%24==0:
			var enemy: EnemyActor=app.room.enemies["P-R21:encounter:02"]
			if not enemy.health.terminal:app.controller.router.request_action(&"shoot_release",(enemy.motor.position-app.player.position).normalized())
	check(await path([Vector2(1264,782),Vector2(1440,942),Vector2(1600,1134)],"P-R21"),"drop through an open lower exit")
	await settle();check(app.room.room_id=="P-R22","enter canal from above")
	if failures>0:return
	check(await path([Vector2(912,334),Vector2(736,526),Vector2(544,1038),Vector2(352,1486),Vector2(800,1486)],"P-R22"),"safe descent and first preparation bank")
	if failures>0:return
	check(await cross(Vector2(1168,1390),Vector2(-1,.6)),"first recoil reaches a raised bank")
	check(not app.state.has("intro_complete"),"first success is practice, not tutorial completion")
	for i: int in 100:
		await physics_frame
		if i%24==0:
			var enemy: EnemyActor=app.room.enemies["P-R22:encounter:bank_guard"]
			if not enemy.health.terminal:app.controller.router.request_action(&"shoot_release",(enemy.motor.position-app.player.position).normalized())
	check(await walk(Vector2(1824,1390),"P-R22"),"cross middle bank after light pressure")
	check(await cross(Vector2(2224,1326),Vector2(-1,.45)),"second recoil varies the gap and height")
	check(await path([Vector2(2304,1326),Vector2(2608,1422),Vector2(2528,1294)],"P-R22"),"reach the shutter observation ledge")
	if failures>0:return
	var latch:=app.room.mechanisms["P-R22:practice_shutter"] as WorldShotLatch
	app.controller.router.request_action(&"shoot_release",(latch.bell_position-app.player.position).normalized());await ticks(24)
	check(latch.open_count==0,"stone lip blocks a standing shot")
	check(await path([Vector2(2608,1422),Vector2(2528,1294)],"P-R22"),"missed ground shot recovers through lower step")
	if failures>0:return
	app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true)
	await ticks(11);app.controller.router.request_action(&"shoot_release",(latch.bell_position-app.player.position).normalized())
	await ticks(21);app.controller.router.set_jump_held(&"keyboard_mouse",false)
	for i: int in 120:
		await physics_frame
		if app.player.is_on_floor():break
	app.controller.router.clear("practice_landing")
	print("SHUTTER LAND ",app.player.position," opens=",latch.open_count)
	check(latch.open_count==1 and app.player.position.y<1200,"same airborne shot opens gate and recoils onto final bank")
	check(await walk(Vector2(2864,1134),"P-R22"),"reach the completed practice landing")
	check(app.state.has("intro_complete"),"receipt follows the final real recoil landing")
	check(await walk(Vector2(3270,1134),"P-R22"),"leave completed canal")
	await settle();check(app.room.room_id=="P-R23","quiet shelter after practice")
	if failures>0:return
	check(await path([Vector2(992,526),Vector2(1190,430),Vector2(1380,334),Vector2(1308,334),Vector2(1232,238),Vector2(1088,142),Vector2(1088,-18)],"P-R23"),"shelter roof route")
	await settle();check(app.room.room_id=="P-R24","reach overlook")
	if failures>0:return
	check(await ride("OverlookLift",Vector2(1856,1456),256,Vector2(1152,142)),"ride visible guided cage toward station lights")
	check(await walk(Vector2(1152,-18),"P-R24"),"climb into station entrance")
	await settle();check(app.room.room_id=="P-R01" and app.state.has("station_briefed"),"station arrival is not forced conversation")
	if failures>0:return
	check(await station_hall(),"station cage reaches service hall")
	check(await walk(Vector2(320,1262),"P-R01"),"approach rest station")
	app.controller.router.request_action(&"interact");await ticks(8)
	check(app.state.value.rest.room=="P-R01" and app.state.value.cycle==2,"explicit rest saves arrival")
func finish() -> void:
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5);print("PLAINS INTRO: ",failures," failures");quit(failures)
