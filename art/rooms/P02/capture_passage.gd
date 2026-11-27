extends SceneTree
## Real-time crossing from one controlled approach. Timestamps are rendered-frame indices.
const SCENE := preload("res://rooms/world/P02.tscn")
const SIDES := {"d001":"P01","d002":"P03","d009":"P16","d330":"P19"}
var host: FieldTerracePilot
var started := -1
var swapped := -1
var finished := -1
var inherited := Vector2.ZERO
var received := Vector2.ZERO
var accepted := false
var outgoing_section_y := 0.0
var incoming_section_y := 0.0
var edge := ""
var source := ""
var target := ""

func _initialize() -> void:
	run.call_deferred()

func ticks(n: int) -> void:
	for i: int in n: await physics_frame

func section_screen_y() -> float:
	var gate: Dictionary = host.active_doc.exits[edge]
	var plane := FixedWorldProvider.point(gate.point)
	var direction := FixedWorldProvider.point(gate.direction)
	if direction.x != 0:
		# Probe four world pixels in from the actual boundary. Both values then
		# refer to the supporting ground, not the camera, a sprite or a guessed height.
		var at := plane-direction*4.0
		var query := PhysicsRayQueryParameters2D.create(at,at+Vector2.DOWN*48,1,[host.active.player.get_rid()])
		var hit := host.active.get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): return INF
		plane = hit.position
	return (host.active.room.get_global_transform_with_canvas()*plane).y

func crossing(from: String, id: String, to: String) -> void:
	if id == edge and from == source and to == target:
		started = Engine.get_process_frames()
		inherited = host.passage_sky.center_native
		outgoing_section_y = section_screen_y()

func room_changed(id: String) -> void:
	if id == target and started >= 0:
		swapped = Engine.get_process_frames()
		received = host.passage_sky.center_native

func finish(id: String,id_edge: String,ok: bool) -> void:
	if id == target and id_edge == edge:
		finished = Engine.get_process_frames()
		accepted = ok
		incoming_section_y = section_screen_y()

func run() -> void:
	var arg := OS.get_cmdline_user_args()
	if arg.size() != 2 or not SIDES.has(arg[0]) or arg[1] not in ["from-field","to-field"]:
		printerr("Expected a P02 door ID followed by from-field or to-field"); quit(2); return
	edge = arg[0]
	source = "P02" if arg[1]=="from-field" else str(SIDES[edge])
	target = str(SIDES[edge]) if source=="P02" else "P02"
	host = SCENE.instantiate()
	root.add_child(host)
	await ticks(5)
	if edge=="d009":
		host.enter_room("P02","")
		host.active.player.reset_at(FixedWorldProvider.point(host.active_doc.sites.discover_p02_low_slope.at))
		await ticks(8)
		if not host.active.state.has("discover_p02_low_slope"):
			printerr("Grass passage discovery did not register"); quit(1); return
	if host.active.room.room_id!=source: host.enter_room(source,"")
	var gate: Dictionary = host.active_doc.exits[edge]
	var point := FixedWorldProvider.point(gate.point)
	var dir := FixedWorldProvider.point(gate.direction)
	var at := point - dir*282.
	if edge=="d009" and source=="P02": at.y=558
	if edge=="d330": at=Vector2(1100,590) if source=="P02" else Vector2(point.x,270)
	host.active.player.reset_at(at)
	host.follow_camera.reset_smoothing()
	host.follow_camera.force_update_scroll()
	host.crossing_started.connect(crossing)
	host.room_changed.connect(room_changed)
	host.crossing_finished.connect(finish)
	await ticks(66)
	if dir.y < 0:
		host.active.controller.router.request_action(&"jump")
	else:
		host.active.controller.router.set_move_axis(1.0 if dir.y>0 else dir.x)
	for i: int in 320:
		await physics_frame
		if finished >= 0: break
		if edge=="d330" and dir.y>0 and not host.crossing and host.active.room.room_id==source and host.active.player.position.x>=1167:
			host.active.controller.router.set_move_axis(0)
	if not accepted or swapped < 0 or not host.last_error.is_empty():
		printerr("Capture missed crossing ",source,"/",edge,"/",target," at ",host.active.player.position," ",host.last_error)
		quit(1); return
	host.active.controller.router.set_move_axis(0)
	host.active.controller.router.request_action(&"jump_release")
	await ticks(67)
	print("PASSAGE_FRAMES ",source," ",edge," ",target," ",started," ",swapped," ",finished," crop_delta=",inherited.distance_to(received))
	print("PASSAGE_SECTION ",source," ",edge," ",target," ",outgoing_section_y," ",incoming_section_y)
	await host.active.audio_service.shutdown()
	host.free()
	quit(0)
