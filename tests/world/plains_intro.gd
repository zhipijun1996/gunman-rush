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
		if app.player.is_on_floor() and point.y<at.y-30 and absf(dx)<245:
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
func run() -> void:
	await play_intro()
	await finish()
func play_intro() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path=replay_save_path
	for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);check(app.start_new(),"new game");await settle()
	check(await path([Vector2(350,494),Vector2(496,446),Vector2(880,398),Vector2(1264,350),Vector2(1530,350)],"P-R03"),"meadow steps")
	await settle();check(app.room.room_id=="P-R21" and app.state.has("intro_move"),"arrive carriage after actual move/jump")
	if failures>0:return
	await walk(Vector2(320,622),"P-R21")
	if app.room.room_id!="P-R21":check(false,"unexpected room before shooting "+app.room.room_id);return
	for i: int in 150:
		await physics_frame
		if app.state.has("intro_shoot"):break
		if app.room.room_id!="P-R21":check(false,"left carriage before accepted hit");return
		var enemy: EnemyActor=app.room.enemies["P-R21:encounter:01"]
		if i%24==0:app.controller.router.request_action(&"shoot_release",(enemy.motor.position-app.player.position).normalized())
	check(app.state.has("intro_shoot"),"actual projectile hits practice foe")
	check(await walk(Vector2(704,750),"P-R21"),"descend carriage shaft")
	await settle();check(app.room.room_id=="P-R22","arrive first canal bank")
	if failures>0:return
	check(await walk(Vector2(548,718),"P-R22"),"approach first recoil gap")
	await recoil_jump(Vector2.LEFT);await ticks(3)
	check(app.state.has("intro_complete"),"recoil and actual safe landing records tutorial")
	check(await walk(Vector2(1376,718),"P-R22"),"cross first bank")
	await recoil_jump(Vector2(-1,.65).normalized())
	check(await walk(Vector2(2170,654),"P-R22"),"lift over second canal")
	await settle();check(app.room.room_id=="P-R23","quiet shelter")
	if failures>0:return
	check(await path([Vector2(544,422),Vector2(720,350),Vector2(544,278),Vector2(720,142),Vector2(656,142),Vector2(576,-18)],"P-R23"),"shelter roof passage")
	await settle();check(app.room.room_id=="P-R24","overlook")
	check(await path([Vector2(1040,598),Vector2(1104,526),Vector2(1264,478),Vector2(1530,478)],"P-R24"),"station slope")
	await settle();check(app.room.room_id=="P-R01" and app.state.has("station_briefed"),"reach station without forced NPC conversation")
	if failures==0:
		await walk(Vector2(320,622),"P-R01");app.controller.router.request_action(&"interact");await ticks(8)
		check(app.state.value.rest.room=="P-R01" and app.state.value.cycle==2,"explicit rest saves station")
func finish() -> void:
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5);print("PLAINS INTRO: ",failures," failures");quit(failures)
