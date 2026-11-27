extends SceneTree
## Actual inputs across P02 and all four return landings. No player relocation.
const SCENE := preload("res://rooms/world/P02.tscn")
var host: FieldTerracePilot
var frame := 0
var checks := 0
var failures := 0
var shots := 0
var film := false
var departures := {}
var completed := {}

class FaultPilot extends FieldTerracePilot:
	var bad_support := false
	var blocked_body := false

	func read_destination(id: String) -> Dictionary:
		var doc := super.read_destination(id)
		if id=="P02" and bad_support:
			doc.exits.d001.spawn = [190,150]
		if id=="P02" and blocked_body:
			doc.exits.d001.point = [2,401]
		return doc

class RejectingSave extends OrdinaryRoomSession.RoomMemory:
	var refusing := true

	func commit(payload: Dictionary,revision: int) -> bool:
		return false if refusing else super.commit(payload,revision)

func _initialize() -> void:
	run.call_deferred()

func ticks(n: int) -> void:
	for _i: int in n:
		await physics_frame
		frame += 1

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label, " in ", host.active.room.room_id, " at ", host.active.player.position)

func mark(label: String) -> void:
	print("P02 shot ",label," frame=",frame," room=",host.active.room.room_id," player=",host.active.player.position," camera=",root.get_camera_2d().get_screen_center_position())
	if film:
		await ticks(20)

func walk(x: float) -> bool:
	var player := host.active.player
	var side := signf(x-player.position.x)
	host.active.controller.router.set_move_axis(side)
	for _i: int in 300:
		if host.active.player!=player: return false
		if (x-player.position.x)*side<=1:
			host.active.controller.router.set_move_axis(0)
			return true
		await ticks(1)
	host.active.controller.router.set_move_axis(0)
	return false

func stand(y: float, timeout := 100) -> bool:
	for _i: int in timeout:
		if host.active.player.is_on_floor() and absf(host.active.player.position.y-y)<2: return true
		await ticks(1)
	return false

func jump() -> void:
	host.active.controller.router.request_action(&"jump")

func release_jump() -> void:
	host.active.controller.router.request_action(&"jump_release")

func audit_departure(source: String, edge: String, to: String) -> void:
	var gate: Dictionary = host.active_doc.exits[edge]
	var outward := FixedWorldProvider.point(gate.direction)
	var overshoot := (host.active.player.position-FixedWorldProvider.point(gate.point)).dot(outward)
	check(overshoot>=-.01 and overshoot<16,"physical center has just crossed "+source+"/"+edge)
	check(host.crossing and host.curtain.visible and host.curtain.color.a==1 and not host.active.controller.active,"cover locks source controls before handoff")
	departures = {"source":source,"edge":edge,"destination":to,"position":host.active.player.position,"source_gate":gate,"revision":host.active.state.revision}

func audit_swap(id: String) -> void:
	if departures.is_empty(): return
	var gate: Dictionary = host.active_doc.exits[departures.edge]
	var mapped := FieldTerracePilot.Passage.mapped_position(departures.source_gate,gate,departures.position)
	check(host.curtain.visible and host.curtain.color.a==1 and not host.active.controller.active and root.get_camera_2d()==host.follow_camera,"camera and receiving session changed under full cover")
	check(host.active.player.position.distance_to(mapped)<.1,"receiving actor preserves tangent and crossing overshoot")
	check(id==departures.destination and host.active.state.value.entry==departures.edge and host.active.state.revision==departures.revision+1,"one commit records door, room and exploration")

func audit_arrival(id: String, edge: String, ok: bool) -> void:
	check(ok and host.last_error.is_empty(),"entry finishes without fallback for "+id+"/"+edge)
	check(not host.crossing and not host.curtain.visible and host.active.controller.active and host.active.player.is_on_floor(),"controls return only after uncovered actor has physical support")
	var first: Vector2 = host.entry_trace.front()
	var last: Vector2 = host.entry_trace.back()
	var outward := FixedWorldProvider.point(host.active_doc.exits[edge].direction)
	if outward.x!=0:
		var displacement := (last-first).dot(-outward)
		check(displacement>=12 and displacement<=36,"after reveal a horizontal arrival walks one body width")
	elif outward.y<0:
		check(last.y-first.y>28 and absf(last.x-first.x)<1,"downward arrival falls in line into the well")
	else:
		check(first.y-last.y>=20 and absf(last.y-FixedWorldProvider.point(host.active_doc.exits[edge].spawn).y)<3,"upward arrival completes a real hop to its ledge")
	completed[str(departures.source)+"/"+edge+"/"+id]=true
	departures={}

func bind_audit() -> void:
	host.crossing_started.connect(audit_departure)
	host.room_changed.connect(audit_swap)
	host.crossing_finished.connect(audit_arrival)

func keyboard(code: Key, pressed: bool, echo := false) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.pressed = pressed
	key.echo = echo
	Input.parse_input_event(key)
	await ticks(2)

func wait_attempt(number: int) -> bool:
	for i: int in 400:
		await ticks(1)
		if host.passage_attempts>=number and not host.crossing: return true
	return false

func refused_and_held_input() -> void:
	await host.active.audio_service.shutdown()
	host.free()
	var broken := FaultPilot.new()
	host = broken
	root.add_child(host)
	await ticks(5)
	var original := host.active
	var revision := original.state.revision
	broken.bad_support=true
	await keyboard(KEY_D,true)
	check(await wait_attempt(1) and host.last_error=="arrival_support_missing","missing physical support rejects destination")
	check(host.active==original and original.state.revision==revision and original.controller.active and not host.curtain.visible,"bad receiver preserves source, ledger, camera and control")
	await ticks(40)
	check(host.passage_attempts==1,"holding direction at a refused passage never loops the curtain")
	await keyboard(KEY_D,false)
	broken.bad_support=false
	broken.blocked_body=true
	await keyboard(KEY_D,true)
	check(await wait_attempt(2) and host.last_error=="arrival_body_obstructed","actual solid over mapped entry blocks the full body")
	await keyboard(KEY_D,false)
	broken.blocked_body=false
	var save := RejectingSave.new()
	original.state.storage=save
	await keyboard(KEY_D,true)
	check(await wait_attempt(3) and host.last_error=="room_transition_save_failed","refused atomic save returns to live source")
	check(original.state.revision==revision and "P02" not in original.state.value.explored,"refused transition records no exploration")
	await keyboard(KEY_D,false)
	save.refusing=false
	await keyboard(KEY_A,true)
	await ticks(18)
	await keyboard(KEY_A,false)
	check(original.player.position.x<660,"can walk freely away after rollback")
	await keyboard(KEY_D,true)
	for i: int in 200:
		if host.active!=original and host.crossing: break
		await ticks(1)
	check(host.active!=original and host.crossing and not host.active.controller.active,"the real receiver is still locked during the visible entry")
	var fired := [0]
	host.active.controller.shoot_ability.shot_fired.connect(func(_dir: Vector2,_serial: int):fired[0]+=1)
	await keyboard(KEY_A,true)
	host.active.controller.router.request_action(&"jump")
	host.active.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	check(await wait_attempt(4) and host.active.room.room_id=="P02" and host.active.player.is_on_floor(),"fresh real approach succeeds after failure")
	var arrived := host.active.player.position
	await keyboard(KEY_D,true,true)
	await ticks(35)
	check(host.active.player.position.distance_to(arrived)<1 and host.passage_attempts==4,"held physical key and its OS repeats neither walk on nor bounce back")
	check(host.active.player.is_on_floor() and fired[0]==0 and is_zero_approx(host.active.controller.router.axis),"movement, jump and gun requests made under cover do not leak into restored control")
	await keyboard(KEY_A,false)
	await keyboard(KEY_D,false)
	await keyboard(KEY_D,true)
	await ticks(15)
	check(host.active.player.position.x>arrived.x+40,"release and fresh press restore normal player movement")
	await keyboard(KEY_D,false)

func connect_shots(_id: String) -> void:
	host.active.controller.shoot_ability.shot_fired.connect(func(_direction: Vector2,_packet: int): shots += 1)

func cross(id: String, side: float) -> bool:
	var start := host.active
	start.controller.router.set_move_axis(side)
	for _i: int in 300:
		await ticks(1)
		if host.active!=start and not host.crossing:
			host.active.controller.router.set_move_axis(0)
			return host.last_error.is_empty() and host.active.player.is_on_floor() and host.active.room.room_id==id and host.active.state.value.room==id
	start.controller.router.set_move_axis(0)
	return false

func climb(x: float, y: float, label: String) -> void:
	jump()
	await ticks(10)
	check(await walk(x),label+" clears tread")
	release_jump()
	check(await stand(y),label+" lands")

func plain_cross(side: float, x: float, y: float) -> void:
	var previous := shots
	host.active.controller.router.set_move_axis(side)
	jump()
	await ticks(42)
	release_jump()
	check(await walk(x) and await stand(y) and shots==previous,"upper route clears open channel with a plain jump")

func recoil_cross(side: float, x: float, elevation := .55) -> void:
	var before := shots
	host.active.controller.router.set_move_axis(side)
	jump()
	await ticks(12)
	host.active.controller.router.request_action(&"shoot_release",Vector2(-side,elevation).normalized())
	await ticks(31)
	release_jump()
	check(await walk(x) and await stand(366) and shots==before+1,"single backwards recoil clears the main break")

func check_late_jump(x: float, label: String) -> void:
	check(await walk(x),label+" enters the coyote window")
	var serial := host.active.controller.jump_ability.accepted_serial
	host.active.controller.router.set_move_axis(1)
	jump()
	await ticks(90)
	release_jump()
	host.active.controller.router.set_move_axis(0)
	check(serial+1==host.active.controller.jump_ability.accepted_serial and host.active.player.position.x<720 and await stand(558),label+" still requires recoil")

func alternate_crossing() -> void:
	await host.active.audio_service.shutdown()
	host.free()
	host = SCENE.instantiate()
	root.add_child(host)
	host.room_changed.connect(connect_shots)
	connect_shots(host.active.room.room_id)
	await ticks(8)
	check(await cross("P02",1),"enter fresh field for alternate west crossing")
	check(await walk(426),"start at original lip")
	host.active.controller.router.set_move_axis(1)
	jump()
	await ticks(86)
	release_jump()
	host.active.controller.router.set_move_axis(0)
	check(await stand(558),"ordinary miss reaches basin again")
	jump()
	await ticks(7)
	host.active.controller.router.request_action(&"shoot_release",Vector2.DOWN)
	await ticks(19)
	check(await walk(815) and await stand(366),"basin's vertical recoil can land on bell platform")
	release_jump()
	await ticks(3)
	check(not host.landed_on_terrace,"vertical trick from underneath stays silent")
	jump()
	await ticks(65)
	release_jump()
	check(not host.landed_on_terrace and await stand(366),"same-platform hop stays silent")
	check(await walk(962),"reach east fork")
	await plain_cross(1,1240,398)
	check(await walk(1151),"approach from east")
	await plain_cross(-1,840,366)
	check(not host.landed_on_terrace,"entering the bell terrace from eastern road stays silent")
	check(await walk(650) and await stand(558),"return to the basin")
	check(await walk(592),"approach western rooted mound")
	await climb(546,510,"lower west takeoff")
	await climb(507,462,"upper west takeoff")
	await recoil_cross(1,809,.9)
	await ticks(2)
	check(host.landed_on_terrace and host.active.audio_service.played.get(&"mechanism_bell",0)==1,"western retry tread recoil rings once")

func run() -> void:
	film = "--film" in OS.get_cmdline_user_args()
	host = SCENE.instantiate()
	root.add_child(host)
	if host.active==null:
		printerr("P02 pilot failed to open its arrival passage")
		quit(1)
		return
	bind_audit()
	host.room_changed.connect(connect_shots)
	connect_shots(host.active.room.room_id)
	await ticks(8)
	check(host.active.room.room_id=="P01" and await stand(270),"start inside the P01 receiving passage")
	await mark("p01_approach")
	check(await cross("P02",1) and await stand(366),"actually enter P02 from the west")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--overview="):
			await overview(arg.trim_prefix("--overview="))
			return
	var eye := root.get_camera_2d().get_screen_center_position()
	check(eye.x+root.get_visible_rect().size.x/(2*root.get_camera_2d().zoom.x)>=host.bell_mount.position.x+73,"full bell landmark visible at spawn")
	check(not host.active.state.has(host.DISCOVERY) and not host.route_map.known_rooms().has("P16"), "grass passage starts undiscovered")
	check(not host.notice.visible and host.panorama.texture.resource_path.ends_with("irrigation_panorama.webp"), "arrival is unobstructed")
	await mark("arrival")
	check(await walk(426),"reach western brink")
	await mark("brink")
	host.active.controller.router.set_move_axis(1)
	jump()
	await ticks(83)
	release_jump()
	host.active.controller.router.set_move_axis(0)
	check(shots==0 and host.active.player.position.x<720 and await stand(558),"full ordinary jump misses and reaches the retry basin")
	await ticks(2)
	check(host.retry_hint_shown and not host.landed_on_terrace,"safe miss shows one retry hint")
	await mark("retry_basin")
	check(await walk(592),"approach rooted field steps")
	await climb(546,510,"lower field step")
	if not film:
		await check_late_jump(600,"outer lower step")
		check(await walk(590),"retry lower step")
		await climb(546,510,"lower field step")
	await climb(505,462,"upper field step")
	if not film:
		await check_late_jump(554,"outer upper step")
		check(await walk(590),"retry upper step")
		await climb(546,510,"lower field step")
		await climb(505,462,"upper field step")
	check(await walk(459) and await stand(558),"step behind rooted terrace onto grassy lower route")
	check(await walk(307) and await stand(558) and host.active.state.has(host.DISCOVERY),"reaching low grass commits discovery")
	await mark("grass")
	check(host.route_map.known_rooms().has("P16"),"discovered P16 is visible on map")
	check(await walk(106) and await stand(590),"short grassy slope is traversable on foot")
	check(await cross("P16",-1) and await stand(270),"actual d009 opens the P16 receiving passage")
	await mark("p16_arrival")
	check(await walk(239),"reach coin cache")
	host.active.controller.router.request_action(&"interact")
	await ticks(3)
	var purse: Dictionary = host.catalog.lookup("coin_caches","coin20_P16").row
	check(host.active.state.value.receipts.has("income:coin20_P16") and host.active.state.value.services.gold==purse.amount,"P16 coin cache uses the catalog quantity")
	check(await walk(111),"reach health fragment")
	host.active.controller.router.request_action(&"interact")
	await ticks(3)
	check(host.active.state.value.inventory.get("health_shard",0)==1 and host.active.state.value.receipts.has("wr_P16_primary"),"P16 fragment committed exactly once")
	await mark("p16_fragment")
	host.active.controller.router.request_action(&"interact")
	await ticks(2)
	check(host.active.state.value.inventory.get("health_shard",0)==1,"a second interaction never grants a duplicate fragment")
	check(await cross("P02",1) and await stand(590),"walk back through d009 with secure footing")
	check(host.active.state.has(host.DISCOVERY) and host.veil.modulate.a<=.18 and host.active.state.value.inventory.get("health_shard",0)==1,"discovery and fragment survive return")
	check(await walk(459) and await stand(558),"grass return ramp needs no jump")
	await climb(508,462,"west shoulder from sheltered side")
	if film:
		await mark("recovery_launch")
		await recoil_cross(1,817,.9)
	else:
		await climb(404,366,"west launch field")
		check(await walk(426),"return to launch")
		await recoil_cross(1,817)
	await ticks(2)
	check(host.landed_on_terrace and host.chime_time>0 and host.active.audio_service.played.get(&"mechanism_bell",0)==1,"valid western recoil landing rings actual bell")
	await mark("bell_landing")
	check(await walk(962) and await stand(366),"look across both eastern choices before jumping")
	var view := root.get_visible_rect().size/root.get_camera_2d().zoom
	eye = root.get_camera_2d().get_screen_center_position()
	check(Rect2(eye-view*.5,view).has_point(Vector2(1100,608)) and Rect2(eye-view*.5,view).has_point(Vector2(1160,416)),"fork camera shows well shoulder and upper landing together")
	await mark("fork_upper")
	await plain_cross(1,1240,398)
	check(await cross("P03",1) and await stand(270),"d002 reaches P03 via upper branch")
	await mark("p03_arrival")
	check(await cross("P02",-1) and await stand(398),"P03 leads west back into P02")
	check(await walk(1151),"approach reverse upper jump")
	await plain_cross(-1,941,366)
	check(await walk(959) and await stand(366),"revisit same fork and deliberately descend")
	await mark("fork_lower")
	check(await walk(987) and await stand(430),"upper soil step")
	check(await walk(1028) and await stand(486),"middle soil step")
	check(await walk(1065) and await stand(534),"lower soil step")
	check(await walk(1101) and await stand(590),"stop on dry shoulder before vertical well")
	await mark("well_lip")
	check(await walk(1167),"move into opened well")
	check(await cross("P19",0) and await stand(270),"real fall through d330 enters P19")
	await mark("p19_arrival")
	jump()
	check(await cross("P02",0) and await stand(714),"upward doorway hop lands on the near well ledge without new directional input")
	release_jump()
	check(await walk(1128),"approach the outer edge of the receiving stone")
	jump()
	host.active.controller.router.set_move_axis(1)
	await ticks(2)
	host.active.controller.router.set_move_axis(0)
	await ticks(5)
	release_jump()
	check(await walk(1104) and await stand(653),"short player-controlled jump rounds the middle recessed well tread")
	check(await walk(1128),"reach the filtered shaft from middle tread")
	jump()
	host.active.controller.router.set_move_axis(1)
	await ticks(5)
	host.active.controller.router.set_move_axis(0)
	await ticks(5)
	check(await walk(1100) and await stand(590),"regain upper well shoulder")
	release_jump()
	check(host.active.state.value.explored.has("P03") and host.active.state.value.explored.has("P16") and host.active.state.value.explored.has("P19"),"physical visits survive session transitions")
	await climb(1064,534,"lower well return")
	await climb(1028,486,"middle well return")
	await climb(987,430,"upper well return")
	await climb(932,366,"bell embankment return")
	check(await walk(731),"return to eastern brink")
	await recoil_cross(-1,350)
	check(await cross("P01",-1) and await stand(270),"d001 returns to P01 on foot")
	check(await cross("P02",1) and await stand(366),"P01 can re-enter the field again")
	await mark("return_home")
	if not film:
		await check_late_jump(464,"furthest accepted western launch")
		check(completed.size()==8,"all four paired doors audited in both directions")
		await alternate_crossing()
		await refused_and_held_input()

	print("P02 TERRACE failures=",failures," checks=",checks," frames=",frame)
	await host.active.audio_service.shutdown()
	host.free()
	quit(1 if failures else 0)

func overview(path: String) -> void:
	root.content_scale_size=Vector2i(1648,768)
	root.size=Vector2i(1648,768)
	var camera := Camera2D.new()
	host.add_child(camera)
	camera.position=Vector2(824,384)
	camera.make_current()
	host.active.equipment_menu.hide()
	host.room_title.hide()
	await ticks(4)
	camera.force_update_scroll()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	print("P02 panorama ",image.get_size()," ",path," ",error)
	await host.active.audio_service.shutdown()
	host.free()
	quit(0 if error==OK and image.get_size()==Vector2i(1648,768) else 1)
