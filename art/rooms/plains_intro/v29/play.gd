extends SceneTree
## Physically drive the shipped host via the same viewport contacts as a phone.
## The P02 and P03 standalone takes open their real receiving entrance after
## the filmed character has picked up the real P01 weapon in the same session.
const Touch := preload("res://tests/plains_touch_driver.gd")
var touch := Touch.new()
var shell: WorldShell
var host: WorldGameHost
var failed := false

func _initialize() -> void:
	run.call_deferred()

func wait_ticks(count: int) -> void:
	for i in count: await physics_frame

func session_changed(_id: String) -> void:
	touch.attach(host.active)

func mark(id: String) -> void:
	print("V29_FRAME ",id," ",Engine.get_process_frames()," ",host.active.room.room_id," ",host.active.player.position)

func check(condition: bool, message: String) -> bool:
	if not condition:
		failed = true
		printerr("V29_FAIL ",message," room=",host.active.room.room_id," player=",host.active.player.position)
	return condition

func walk_to(x: float, limit := 300) -> bool:
	var actor := host.active.player
	var direction := signf(x-actor.position.x)
	touch.move(direction)
	for i in limit:
		if not is_instance_valid(actor) or host.active.player != actor: break
		if direction*(x-actor.position.x) <= 1:
			touch.move(0)
			return true
		await physics_frame
	touch.move(0)
	return check(false,"walk to x=%.1f" % x)

func land(y: float, limit := 150) -> bool:
	for i in limit:
		if host.active.player.is_on_floor() and absf(host.active.player.position.y-y)<2.5: return true
		await physics_frame
	return check(false,"stand at y=%.1f" % y)

func interact() -> void:
	touch.tap(touch.controls.interact_center)
	await wait_ticks(5)

func vault(x: float, y: float, shoot := Vector2.ZERO, launch_ticks := 8) -> bool:
	touch.move(signf(x-host.active.player.position.x))
	touch.jump(true)
	await wait_ticks(launch_ticks)
	if not shoot.is_zero_approx(): touch.fire(shoot)
	var reached := await walk_to(x)
	touch.jump(false)
	return reached and await land(y)

func collect_weapon() -> bool:
	var session := host.active
	if not check(session.room.room_id=="P01" and not session.state.has("gun") and session.opening != null,"P01 needs a fresh unarmed opening"): return false
	mark("wake")
	for i in 180:
		if session.controller.active and session.player.is_on_floor(): break
		await physics_frame
	if not await walk_to(session.opening.global_position.x): return false
	await wait_ticks(12)
	await interact()
	if not check(session.state.has("gun") and session.controller.shoot_ability.enabled,"touch interaction picked up the gun"): return false
	mark("gun")
	await wait_ticks(28)
	return true

func p01() -> void:
	if not await walk_to(668): return
	touch.jump(true)
	await wait_ticks(7)
	touch.fire(Vector2.DOWN)
	await wait_ticks(30)
	touch.jump(false)
	if not await land(342): return
	mark("loft")
	if not await walk_to(694): return
	var gold: int = host.active.services.ledger().gold
	await interact()
	await wait_ticks(20)
	if not await walk_to(739) or not await walk_to(597) or not await walk_to(692): return
	if not check(host.active.services.ledger().gold==gold+5,"the opened high chest paid five collected coins"): return
	mark("chest")

func p02() -> void:
	mark("field")
	if not await walk_to(353): return
	await wait_ticks(12)
	if not await vault(705,413.8593,Vector2(-1,.55),11): return
	if not check(host.lesson_progress.has("landed"),"backward shot and a real landing rang the bell"): return
	mark("bell")
	await wait_ticks(35)
	if not await walk_to(608) or not await land(576): return
	if not await walk_to(512): return
	if not await vault(474,542): return
	if not await vault(433,494): return
	if not await walk_to(388) or not await land(576): return
	if not await walk_to(306) or not await land(576): return
	await wait_ticks(24)
	if not check(host.active.state.has("discover_p02_low_slope"),"approaching the local grass reveals the route"): return
	if not await walk_to(239): return
	for i in 120:
		if host.active.room.room_id=="P16" and not host.crossing: break
		await physics_frame
	if not check(host.active.room.room_id=="P16" and not host.crossing,"the hidden passage reaches P16"): return
	for i in 90:
		if host.active.player.is_on_floor(): break
		await physics_frame
	if not check(host.active.player.is_on_floor(),"stood on the receiving P16 floor"): return
	mark("grass")

func switchback(takeoff: float,x: float,surface: float) -> bool:
	if not await walk_to(takeoff): return false
	touch.jump(true)
	await wait_ticks(10)
	var reached := await walk_to(x)
	await wait_ticks(13)
	touch.jump(false)
	return reached and await land(surface-18)

func p03() -> void:
	mark("ravine")
	if not await switchback(155,250,1340): return
	var gold: int = host.active.services.ledger().gold
	await interact()
	if not check(host.active.services.ledger().gold==gold+5,"collected the actual ravine coins"): return
	if not await switchback(309,353,1240): return
	if not await switchback(366,455,1136): return
	await wait_ticks(22)
	mark("turn")
	if not await switchback(434,359,1040): return
	if not await switchback(341,231,943): return
	var guard: EnemyActor = host.active.room.enemies.ridge_watch_sentry
	for i in 4:
		if guard.health.terminal: break
		if not await walk_to(226): return
		touch.fire(host.active.player.position.direction_to(guard.motor.position+Vector2(0,4)))
		await wait_ticks(30)
	if not check(guard.health.terminal,"cleared the sentry from the uphill route"): return
	if not await switchback(238,296,846): return
	await wait_ticks(35)
	for step: Vector3 in [Vector3(382,435,743),Vector3(411,353,645),Vector3(291,226,540),Vector3(238,300,442),Vector3(365,418,341),Vector3(402,337,249),Vector3(254,199,168)]:
		if not await switchback(step.x,step.y,step.z): return
	if not await walk_to(52) or not await land(150): return
	if not check(not host.active.controller.traversal.wall_enabled,"first-visit switchback without W"): return
	mark("old_road")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or args[0] not in ["P01","P02","P03"]:
		printerr("Expected P01, P02 or P03")
		quit(1)
		return
	var id := args[0]
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	shell = scene.instantiate()
	root.add_child(shell)
	for i in 10: await process_frame
	var begin := shell.page_host.find_child("BeginAdventure",true,false) as Button
	if begin==null:
		printerr("Title has no New Game button")
		shell.queue_free()
		await process_frame
		await process_frame
		quit(1)
		return
	var pos := begin.get_global_rect().get_center()
	touch.viewport = root
	touch.finger(Touch.USE,pos,true)
	await wait_ticks(3)
	touch.lift(Touch.USE)
	for i in 4: await process_frame
	host = shell.world
	if host==null or host.active==null:
		printerr("Could not start through the title: ",shell.page," ",shell.notice.text if shell.notice else "")
		shell.queue_free()
		await process_frame
		await process_frame
		quit(1)
		return
	host.room_changed.connect(session_changed)
	session_changed("P01")
	if await collect_weapon():
		if id!="P01":
			host.enter_room(id,"d001" if id=="P02" else "d002")
			await wait_ticks(6)
		if check(host.active.room.room_id==id and host.last_error.is_empty(),"take starts at the receiving entrance"):
			if id=="P01": await p01()
			elif id=="P02": await p02()
			else: await p03()
	await wait_ticks(16)
	if not failed: print("V29_PLAY ",id," failures=0")
	await host.active.audio_service.shutdown()
	await wait_ticks(6)
	shell.queue_free()
	await process_frame
	await process_frame
	quit(1 if failed else 0)
