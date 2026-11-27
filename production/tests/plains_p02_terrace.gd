extends SceneTree
## Actual inputs across P02 and all four return landings. No player relocation.
const SCENE := preload("res://tests/plains_test_host.tscn")
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
			doc.exits.d001.point[1] = doc.entities.west_field.properties.rect[1]+24
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
	for _i: int in 640:
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
		check(last.y-first.y>28 and absf(last.x-first.x)<1,"downward arrival falls in the same lane until supported")
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
	check(await preload("res://tests/plains_start_input.gd").take_ground_gun(host),"prepare the live west road by picking up the P01 gun")
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
	check(original.player.position.x<float(WorldRoomDocument.read("res://rooms/world/P01.json").exits.d001.spawn[0])-28,"can walk freely away after rollback")
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
	for _i: int in 640:
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

func climb_recess(lip: float, into_shaft: float, landing_x: float, landing_y: float, launch_frames: int, coast_frames: int, label: String) -> void:
	check(await walk(lip),label+" from the narrow outer lip")
	jump()
	host.active.controller.router.set_move_axis(into_shaft)
	await ticks(launch_frames)
	host.active.controller.router.set_move_axis(0)
	await ticks(coast_frames)
	release_jump()
	check(await walk(landing_x) and await stand(landing_y),label+" with player-controlled steering")

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
	check(await walk(x) and await stand(413.8593) and shots==before+1,"single backwards recoil clears the main break")

func run() -> void:
	film = "--film" in OS.get_cmdline_user_args()
	host=SCENE.instantiate()
	root.add_child(host)
	if host.active == null:
		printerr("P02 field failed to open")
		quit(1)
		return
	bind_audit()
	host.room_changed.connect(connect_shots)
	connect_shots(host.active.room.room_id)
	check(await preload("res://tests/plains_start_input.gd").take_ground_gun(host),"take the gun from the P01 starting ground")
	check(await cross("P02",1) and await stand(float(host.active_doc.exits.d001.spawn[1])),"walk from the birthplace into the west field")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--overview="):
			await overview(arg.trim_prefix("--overview="))
			return
	var lip:=Vector2(270,617)
	var inside:=Vector2(242,736)
	check(not host.active.state.has("discover_p02_low_slope") and preload("p02_grass_mask.gd").opacity(host.active,lip)>.95 and preload("p02_grass_mask.gd").opacity(host.active,inside)>.95,"first view keeps the grass mouth and lower shaft covered")
	await mark("arrival")
	check(await walk(354),"walk to the release edge")
	host.active.controller.router.set_move_axis(1)
	jump()
	await ticks(82)
	release_jump()
	host.active.controller.router.set_move_axis(0)
	check(shots==0 and host.active.player.position.x<648 and await stand(576),"a full unassisted jump reaches the safe retry floor")
	check(host.retry_hint_shown and not host.landed_on_terrace,"the missed trial shows its hint without ringing")
	await mark("retry_basin")
	check(await walk(518),"walk back to the three visible west treads")
	await climb(474,542,"lower retry step")
	await climb(435,494,"upper retry step")
	await climb(335,413.8593,"return to full west field")
	check(await walk(354),"regain takeoff edge")
	await recoil_cross(1,726)
	await ticks(2)
	check(host.landed_on_terrace and host.active.audio_service.played.get(&"mechanism_bell",0)==1,"backward fire and the actual landing ring once")
	await mark("bell_landing")
	check(await walk(784),"stand where both eastern routes can be read")
	var camera:=root.get_camera_2d()
	var view:=root.get_visible_rect().size/camera.zoom
	var eye:=camera.get_screen_center_position()
	check(Rect2(eye-view*.5,view).has_point(Vector2(897,664)) and Rect2(eye-view*.5,view).has_point(Vector2(998,468)),"the fork camera contains the upper landing and lower well shoulder")
	await mark("fork_lower")
	check(await walk(805) and await stand(478),"upper soil step")
	check(await walk(835) and await stand(530),"middle soil step")
	check(await walk(865) and await stand(582),"lower soil step")
	check(await walk(896) and await stand(646),"stop on dry shoulder before the vertical well")
	check(await walk(960) and await cross("P19",0) and await stand(float(host.active_doc.exits.d330.spawn[1])),"real fall through the drain enters the P19 receiver")
	jump()
	check(await cross("P02",0) and await stand(786.8593),"the reverse hop reaches the west wall recess")
	release_jump()
	await climb_recess(920,1,898,718,4,6,"middle well recess")
	await climb_recess(920,1,898,646,4,6,"upper well recess")
	await climb(864,582,"lower well bank")
	await climb(842,530,"middle well bank")
	await climb(806,478,"upper well bank")
	await climb(762,413.8593,"return to the bell")
	check(host.active.audio_service.played.get(&"mechanism_bell",0)==0,"returning to the bell from the drain stays silent")
	await mark("fork_upper")
	check(await walk(784),"approach upper fork again")
	await plain_cross(1,1062,449.8593)
	check(await walk(1268),"reach the second planted field")
	await climb(1334,425.8593,"reach the shared eastern high road")
	var east: EnemyActor=host.active.room.enemies.east_road_grub
	for i in 250:
		if east.motor.position.x-host.active.player.position.x<107 and east.brain.direction<0: break
		await ticks(1)
	await plain_cross(1,1580,425.8593)
	check(await cross("P03",1) and await stand(float(host.active_doc.exits.d002.spawn[1])),"surface route reaches the registered P03 entrance")
	await mark("p03_arrival")
	check(await cross("P02",-1) and await stand(float(host.active_doc.exits.d002.spawn[1])),"P03 returns to the east field")
	await refused_and_held_input()
	await host.active.audio_service.shutdown()
	host.free()
	print("P02 TERRACE failures=",failures," checks=",checks," frames=",frame)
	quit(1 if failures else 0)

func overview(path: String) -> void:
	var dims:=Vector2i(ceili(float(host.active_doc.bounds[2])),ceili(float(host.active_doc.bounds[3])))
	root.content_scale_size=dims
	root.size=dims
	var camera:=Camera2D.new()
	host.add_child(camera)
	camera.position=Vector2(dims)*.5
	camera.make_current()
	host.game_hud.set_overlay_hidden(true)
	host.active.equipment_menu.hide()
	host.room_title.hide()
	await ticks(4)
	camera.force_update_scroll()
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	var error:=image.save_png(path)
	print("P02 panorama ",image.get_size()," ",path," ",error)
	await host.active.audio_service.shutdown()
	host.free()
	quit(0 if error==OK and image.get_size()==dims else 1)
