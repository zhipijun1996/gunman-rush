extends SceneTree
## Independent post-boss and pre-boss arrival fixtures. Pickups, trial routes
## and exits below use the actual world host, controller, damage policy and doors.
class Arrival extends WorldGameHost:
	var initial := ""
	func startup_destination() -> Dictionary: return {"ok":true,"room":initial}
var host: Arrival
var failures := 0
var checks := 0
var double_jumps := 0

func _initialize() -> void:
	run.call_deferred()

func frames(n: int) -> void:
	for i in n: await physics_frame

func test(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL canyon/castle ",message," ",host.active.room.room_id," ",host.active.player.position," ",host.last_error)
	return ok

func start(room: String, acquired: Array) -> void:
	host = Arrival.new()
	host.initial = room
	root.add_child(host)
	await frames(6)
	var state := host.active.state
	var saved := state.candidate()
	for flag: String in acquired:
		if flag not in saved.flags: saved.flags.append(flag)
	test(state.commit(saved,state.revision),"load the previously obtained progression fixture")
	bind("")
	host.room_changed.connect(bind)

func bind(_id: String) -> void:
	host.active.controller.jump_ability.accepted_jump.connect(func(kind: StringName,_serial:int,_location:Vector2):
		if kind == &"double": double_jumps+=1)

func close() -> void:
	await host.active.audio_service.shutdown()
	host.free()
	await frames(4)

func move(x: float) -> bool:
	var side := signf(x-host.active.player.position.x)
	var origin:=host.active
	origin.controller.router.set_move_axis(side)
	for i in 360:
		if origin != host.active: return false
		if (x-origin.player.position.x)*side<=1:
			origin.controller.router.set_move_axis(0)
			return true
		await frames(1)
	origin.controller.router.set_move_axis(0)
	return false

func action(id: StringName, aim:=Vector2.ZERO) -> void:
	host.active.controller.router.request_action(id,aim)

func interact() -> void:
	action(&"interact")
	await frames(4)
	var menu:=host.active.content_sites.menu
	if menu!=null and menu.visible: menu.close()
	await frames(3)

func cross(to: String, axis: float) -> bool:
	host.active.controller.router.set_move_axis(axis)
	for i in 300:
		if host.active.room.room_id==to and not host.crossing:
			host.active.controller.router.set_move_axis(0)
			return host.active.player.is_on_floor() and host.last_error.is_empty()
		await frames(1)
	return false

func stable(y: float) -> bool:
	for i in 140:
		if host.active.player.is_on_floor() and absf(host.active.player.position.y-y)<3:return true
		await frames(1)
	return false

func jump_to_altar() -> bool:
	if not await move(191):return false
	action(&"jump")
	if not await move(406): return false
	action(&"jump_release")
	return await move(790) and await stable(578)

func try_double_shelf() -> bool:
	if not await move(746):return false
	var start_count:=double_jumps
	action(&"jump")
	await frames(23)
	action(&"jump_release")
	await frames(1)
	action(&"jump")
	await frames(8)
	host.active.controller.router.set_move_axis(1)
	await frames(8)
	action(&"jump_release")
	await frames(14)
	host.active.controller.router.set_move_axis(0)
	await frames(65)
	return double_jumps>start_count and host.active.player.is_on_floor() and host.active.player.position.x>797 and absf(host.active.player.position.y-278)<3

func canyon() -> void:
	await start("Y02",["W","H"])
	test(not await try_double_shelf(),"same ledge cannot be reached by a second jump before D")
	await close()
	await start("Y23",["W","H"])
	if test(await jump_to_altar(),"jump the old tower mouth and walk up to the artifact"):
		await interact()
		test(not host.active.state.has("D"),"without winning Y20, the distant altar cannot award D")
	var state:=host.active.state
	var past:=state.candidate()
	past.flags.append("encounter_Y20_clear")
	test(state.commit(past,state.revision),"restore the independent completed Y20 encounter fixture")
	await interact()
	test(state.has("D") and state.value.receipts.has("wr_Y02_primary") and host.active.controller.traversal.double_enabled,"interacting at Y23 grants the actual double jump")
	if test(await cross("Y02",1),"walk into the adjoining trial from its low west side"):
		test(await try_double_shelf(),"two accepted jumps carry the player onto the 252-unit north ridge")
		test(await cross("Y24",1),"the upper trail continues into Y24 on foot")
	await close()

func castle() -> void:
	await start("K12",["W","castle_key"])
	if test(await move(990),"walk from the courtyard side to the archive plinth"):
		await interact()
		test(not host.active.state.has("Q") and not host.active.recoil_guard.owned,"the unopened boss condition cannot award protection")
	var state:=host.active.state
	var past:=state.candidate()
	past.flags.append("encounter_K11_clear")
	test(state.commit(past,state.revision),"restore the independent completed K11 encounter fixture")
	await interact()
	test(state.has("Q") and state.value.receipts.has("wr_K12_primary") and host.active.recoil_guard.owned,"the archive plinth grants actual Q and records its unique claim")
	if test(await move(733),"approach the luminous screen from supported ground"):
		var hp:=host.active.controller.actor_resources.health.current
		action(&"jump")
		await frames(4)
		action(&"shoot_release",Vector2.RIGHT)
		host.active.controller.router.set_move_axis(-1)
		var inside := false
		for i in 50:
			if host.active.player.position.x>=657 and host.active.player.position.x<=690 and host.active.recoil_guard.is_protecting():
				inside=true
			if host.active.player.position.x<635: break
			await frames(1)
		host.active.controller.router.set_move_axis(0)
		action(&"jump_release")
		test(inside and host.active.player.position.x<642 and host.active.controller.actor_resources.health.current==hp,"move through the actual phase curtain during recoil protection, with health intact")
		await stable(605)
		if test(await move(415),"approach the exposed downward return shaft"):
			test(await cross("K08",0),"the protected return drops to the supported royal hall")
	await close()

func run() -> void:
	await canyon()
	await castle()
	print("CANYON CASTLE TRIALS failures=",failures," checks=",checks)
	quit(1 if failures else 0)
