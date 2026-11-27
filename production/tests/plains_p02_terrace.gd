extends SceneTree
## P02 pilot. The route uses one ordinary player's input router, from the authored spawn.
const SCENE := preload("res://rooms/world/P02.tscn")
var session: FieldTerracePilot
var checks := 0
var failures := 0
var shots := 0
var film := false
var frame := 0

func _initialize() -> void:
	run.call_deferred()

func ticks(count: int) -> void:
	for _i: int in count:
		await physics_frame
		frame += 1

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL ", label, " at ", session.player.position)

func walk(target: float) -> bool:
	var direction := signf(target - session.player.position.x)
	session.controller.router.set_move_axis(direction)
	for _i: int in 290:
		if (target - session.player.position.x) * direction <= 1:
			session.controller.router.set_move_axis(0)
			return true
		await ticks(1)
	session.controller.router.set_move_axis(0)
	return false

func landed(height: float, timeout := 90) -> bool:
	for _i: int in timeout:
		if session.player.is_on_floor() and absf(session.player.position.y - height) < 2:
			return true
		await ticks(1)
	return false

func mark(label: String) -> void:
	var camera := root.get_camera_2d()
	print("P02 shot ",label," frame=",frame," player=",session.player.position," camera=",camera.get_screen_center_position())

func jump() -> void:
	session.controller.router.request_action(&"jump")

func let_go() -> void:
	session.controller.router.request_action(&"jump_release")

func climb(target_x: float, floor_y: float, label: String) -> void:
	jump()
	await ticks(11)
	check(await walk(target_x), label + " clears outer corner")
	let_go()
	check(await landed(floor_y), label + " stands on tread")

func recoil_cross(direction: float, target_x: float, floor_y: float) -> void:
	var before := shots
	session.controller.router.set_move_axis(direction)
	jump()
	await ticks(12)
	session.controller.router.request_action(&"shoot_release", Vector2(-direction, .55).normalized())
	await ticks(31)
	let_go()
	check(await walk(target_x) and await landed(floor_y) and shots == before+1, "cross gap with one rearward shot")

func miss_from_return_step(lip_x: float, label: String) -> void:
	# Jump after walking off the edge to include the controller's coyote-time allowance.
	check(await walk(lip_x), label + " reaches outside edge")
	session.controller.router.set_move_axis(1)
	var serial := session.controller.jump_ability.accepted_serial
	var before_shots := shots
	jump()
	await ticks(94)
	let_go()
	session.controller.router.set_move_axis(0)
	check(session.controller.jump_ability.accepted_serial == serial+1, label + " accepts late jump")
	check(shots == before_shots and session.player.position.x < 736 and await landed(554), label + " cannot skip recoil")

func run() -> void:
	film = "--film" in OS.get_cmdline_user_args()
	session = SCENE.instantiate()
	root.add_child(session)
	if session.room == null:
		printerr("P02 pilot scene failed to open")
		quit(1)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--overview="):
			await capture_overview(argument.trim_prefix("--overview="))
			return
	session.controller.shoot_ability.shot_fired.connect(func(_direction: Vector2, _packet: int): shots += 1)
	await ticks(12)
	check(await landed(366), "west arrival on runway")
	mark("arrival")
	check(session.panorama.texture.resource_path.ends_with("irrigation_panorama.webp") and session.veil.z_index>0 and session.bell_mount.material is ShaderMaterial,"pilot art installed in authored layers")
	var eye := root.get_camera_2d().get_screen_center_position()
	var visible_half := root.get_visible_rect().size.x/(2*root.get_camera_2d().zoom.x)
	check(eye.x+visible_half>=session.bell_mount.position.x+session.bell_mount.texture.get_width()*.5, "full bell arch visible at entry")
	check(not session.state.has(session.DISCOVERY) and not session.notice.visible,"entry preserves hidden pocket and uninterrupted sightline")
	if film: await ticks(30)
	check(await walk(426), "walk to brink")
	mark("brink")
	# Negative control: a full running jump with no release and no shot must miss the far bank.
	session.controller.router.set_move_axis(1)
	jump()
	await ticks(85)
	let_go()
	session.controller.router.set_move_axis(0)
	check(shots == 0 and session.player.position.x < 736 and await landed(554), "plain jump misses and survives on basin floor")
	await ticks(2)
	mark("safe_miss")
	check(session.retry_hint_shown and session.notice.visible and not session.landed_on_terrace,"safe miss offers a single retry hint")
	if not film:
		# An optional vertical trick from below reaches the bell terrace, but it
		# is not the west-to-east lesson. Neither that landing nor its next hop rings.
		jump()
		await ticks(7)
		session.controller.router.request_action(&"shoot_release", Vector2.DOWN)
		await ticks(18)
		check(await walk(812) and await landed(390),"vertical shot from basin can reach east lip")
		await ticks(2)
		check(not session.landed_on_terrace,"basin entry does not claim the lesson")
		jump()
		await ticks(64)
		let_go()
		check(await landed(390) and not session.landed_on_terrace,"hop on bell terrace leaves bells silent")
		check(await walk(655) and await landed(554),"return to safe floor after alternate approach")
	check(await walk(317) and await landed(554), "find west pocket under field")
	check(await walk(197) and await landed(554), "reach west doorway")
	await ticks(3)
	mark("west_pocket")
	check(session.state.has(session.DISCOVERY) and session.state.value.receipts.has(session.DISCOVERY), "grass approach commits discovery")
	check(session.veil.modulate.a<.35 and session.active_edge=="d009" and session.notice.visible, "grass parts and west passage identifies its destination")
	if film: await ticks(24)
	check(await walk(273) and await landed(554), "receiving side of west doorway is supported")
	check(await walk(539), "return below earthen steps")
	await climb(500,472,"lower west")
	if not film:
		await miss_from_return_step(548,"western lower tread")
		check(await walk(539),"return below lower tread")
		await climb(500,472,"lower west retry")
	await climb(455,430,"upper west")
	if not film:
		await miss_from_return_step(512,"western upper tread")
		check(await walk(539),"return below upper tread")
		await climb(500,472,"lower west retry")
		await climb(455,430,"upper west retry")
	await climb(378,366,"west field")
	check(await walk(426), "return to original brink")
	await recoil_cross(1,821,390)
	await ticks(2)
	mark("bell_terrace")
	check(session.landed_on_terrace and session.chime_time>0 and session.bell_mount.material.get_shader_parameter("age")<1.0, "physical landing rings suspended bells")
	if film: await ticks(24)
	check(await walk(1036) and await landed(622), "descend through open drainage shaft")
	check(await walk(1232) and await landed(622), "reach eastern culvert return apron")
	check(await walk(1320) and await landed(622), "reach eastern culvert door")
	await ticks(2)
	mark("drain")
	check(session.active_edge=="d330" and session.notice.visible,"east culvert identifies its destination")
	if film: await ticks(24)
	check(await walk(1035), "walk out under drainage stairs")
	await climb(1076,530,"lower drain")
	await climb(1114,466,"upper drain")
	await climb(1190,412,"east road")
	check(await walk(1593) and await landed(412),"reach eastern exit on flat field")
	await ticks(2)
	mark("east_road")
	check(session.active_edge=="d002", "east main edge identifies its destination")
	if not film:
		session.controller.router.set_move_axis(1)
		await ticks(30)
		check(session.player.is_on_wall() and session.player.position.x<1648,"east room boundary keeps player in room")
		check(await walk(1152), "return to eastern crossing")
		session.controller.router.set_move_axis(-1)
		jump()
		await ticks(32)
		let_go()
		check(await walk(747) and await landed(390), "return across upper drainage shaft to bell pier")
		check(await walk(992),"start direct upper road from bell terrace")
		var previous_shots := shots
		session.controller.router.set_move_axis(1)
		jump()
		await ticks(32)
		let_go()
		check(await walk(1190) and await landed(412) and shots == previous_shots, "ordinary jump skips the optional culvert")
		check(await walk(1152), "turn back at road edge")
		session.controller.router.set_move_axis(-1)
		jump()
		await ticks(32)
		let_go()
		check(await walk(747) and await landed(390), "east return without entering culvert")
		await recoil_cross(-1,353,366)
		check(await walk(51) and await landed(366), "return to western field door")
		await ticks(2)
		check(session.active_edge=="d001" and session.notice.visible,"west main edge identifies its destination")
		session.controller.router.set_move_axis(-1)
		await ticks(30)
		check(session.player.is_on_wall() and session.player.position.x>0,"west room boundary keeps player in room")
		await miss_from_return_step(464,"western main brink")
	print("P02 TERRACE failures=", failures, " checks=", checks, " frames=",frame)
	await session.audio_service.shutdown()
	session.free()
	quit(1 if failures else 0)

func capture_overview(path: String) -> void:
	# Inspection-only view of the very same installed room, at native world pixels.
	root.content_scale_size = Vector2i(1648,768)
	root.size = Vector2i(1648,768)
	var overview := Camera2D.new()
	session.add_child(overview)
	overview.global_position = Vector2(824,384)
	overview.make_current()
	session.equipment_menu.hide()
	await ticks(3)
	overview.force_update_scroll()
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image()
	var error := result.save_png(path)
	print("P02 panorama ",result.get_size()," ",path," ",error)
	await session.audio_service.shutdown()
	session.free()
	quit(0 if error==OK and result.get_size()==Vector2i(1648,768) else 1)
