extends SceneTree
## One uninterrupted first visit. Every move after the starting room entry
## goes through the same controller, discovery volume and doors as normal play.
const SCENE := preload("res://tests/plains_test_host.tscn")
var host: FieldTerracePilot
var discovery_event := ""

func _initialize() -> void:
	run.call_deferred()

func ticks(count: int) -> void:
	for i: int in count: await physics_frame

func sampled_reveal() -> float:
	if host.active.room.room_id!="P02": return -1.0
	var cover: WorldForegroundCover = host.active.room.element_runtime.nodes.grass_cutaway
	# A fixed point on the throat's eastern grass/root face, in level coordinates.
	var point := cover.to_local(Vector2(269,592))
	for tile: Dictionary in cover.chunks.values():
		var area: Rect2 = tile.area
		if not area.has_point(point): continue
		var image: Image = tile.image
		var texel := Vector2i((point-area.position)/area.size*Vector2(image.get_size()))
		return image.get_pixelv(texel).r
	return -1.0

func mark(label: String) -> void:
	var camera := host.follow_camera.get_screen_center_position()
	var at := host.active.player.position
	var evidence := {"stage":label,"frame":Engine.get_process_frames(),"room":host.active.room.room_id,
		"player":[at.x,at.y],"reveal_at_grass":sampled_reveal(),"camera":[camera.x,camera.y],"zoom":host.follow_camera.zoom.x,
		"known":host.active.state.has(discovery_event),"visited":host.active.state.value.explored.has("P16")}
	print("GRASS_ROUTE ",JSON.stringify(evidence))

func fail(reason: String) -> void:
	printerr("Grass route failed: ",reason," in ",host.active.room.room_id," at ",host.active.player.position," ",host.last_error)
	quit(1)

func walk(x: float) -> bool:
	var session := host.active
	var sign_x := signf(x-session.player.position.x)
	session.controller.router.set_move_axis(sign_x)
	for i: int in 240:
		if session!=host.active: return false
		if (x-session.player.position.x)*sign_x<=.8:
			session.controller.router.set_move_axis(0)
			return true
		await physics_frame
	session.controller.router.set_move_axis(0)
	return false

func supported(room_id: String, y: float) -> bool:
	for i: int in 150:
		await physics_frame
		if host.active.room.room_id==room_id and not host.crossing and host.active.player.is_on_floor() and absf(host.active.player.position.y-y)<2:
			return host.last_error.is_empty()
	return false

func climb_bank(lip_x: float, bank_x: float, y: float) -> bool:
	if not await walk(lip_x): return false
	host.active.controller.router.request_action(&"jump")
	host.active.controller.router.set_move_axis(-1)
	await ticks(4)
	host.active.controller.router.set_move_axis(0)
	await ticks(7)
	host.active.controller.router.request_action(&"jump_release")
	return await walk(bank_x) and await supported("P02",y)

func vault_gap(side: float, end_x: float, fire_after: int) -> bool:
	# A separate first-visit observation from each bank, in one save. The
	# overhead traversal keeps the player outside both observation points.
	host.active.controller.router.set_move_axis(side)
	host.active.controller.router.request_action(&"jump")
	await ticks(fire_after)
	host.active.controller.router.request_action(&"shoot_release",Vector2(-side,0.15).normalized())
	var reached := await walk(end_x)
	host.active.controller.router.request_action(&"jump_release")
	return reached

func run() -> void:
	host = SCENE.instantiate()
	root.add_child(host)
	if "--touch-hud" in OS.get_cmdline_user_args():
		host.room_changed.connect(func(_id: String): host.active.touch_controls.set_enabled(true))
	if not await preload("res://tests/plains_start_input.gd").take_ground_gun(host):
		printerr("Cannot prepare the P01 ground weapon"); quit(1); return
	host.enter_room("P02","d001")
	await ticks(5)
	if host.active.room.room_id!="P02": fail("P02 did not open"); return
	var doc := host.active_doc
	var gate: Dictionary = doc.exits.d009
	var link: Dictionary = host.catalog.lookup("doors","d009").row
	var event := str(link.discovery.event)
	discovery_event = event
	var receiver := FixedWorldProvider.point(gate.spawn)
	var mouth_x := float(gate.point[0])
	var field := FixedWorldProvider.rect(doc.entities.west_field.properties.rect)
	if FixedWorldProvider.point(gate.direction) != Vector2.DOWN or host.active.state.has(event):
		fail("source mouth or fresh discovery state"); return
	if not await walk(field.end.x+27) or not await supported("P02",558) or not await walk(404):
		fail("drop from the western field to the lower lane"); return
	if not await vault_gap(-1,145,5):
		fail("approach the grass from the west"); return
	host.active.controller.router.set_move_axis(-1)
	await ticks(90)
	var west_stop := host.active.player.position
	var touched_wall := false
	for i: int in 24:
		await physics_frame
		touched_wall = touched_wall or host.active.player.is_on_wall()
	if not touched_wall or host.active.player.position.distance_to(west_stop)>3 or west_stop.x<=32 or host.active.room.room_id!="P02":
		fail("westward movement must stop at the solid foot of the hill"); return
	host.active.controller.router.set_move_axis(0)
	await ticks(40)
	if host.active.state.has(event): fail("looks from the west must leave the map hidden"); return
	mark("west_far")
	if not await walk(156) or not await vault_gap(1,412,6) or not await supported("P02",558):
		fail("return above the grass to the eastern bank"); return
	if not await walk(463) or not await walk(440):
		fail("approach observation from the east"); return
	await ticks(52)
	if host.active.state.has(event): fail("looks from the east must leave the map hidden"); return
	mark("east_far")
	await ticks(55)
	if not await walk(352):
		fail("stop short of discovery"); return
	await ticks(40)
	if host.active.state.has(event) or host.active.room.room_id!="P02":
		fail("nearby grass is not the discovery or transition plane"); return
	mark("clue")
	await ticks(20)
	host.active.controller.router.set_move_axis(-1)
	for i: int in 30:
		await physics_frame
		if host.active.state.has(event): break
	if not host.active.state.has(event) or host.active.state.value.explored.has(link.discovery.target_room):
		fail("the first close approach must reveal before the first visit"); return
	mark("discover")
	if not await walk(305): fail("reach grass observation"); return
	await ticks(50)
	mark("revealed")
	await ticks(37)
	if not await walk(mouth_x) or not await supported(link.discovery.target_room,float(host.read_destination(link.discovery.target_room).exits.d009.spawn[1])):
		fail("gravity must reach the cache floor"); return
	mark("below")
	await ticks(55)
	host.active.controller.router.request_action(&"jump")
	mark("jump")
	if not await supported("P02",receiver.y):
		fail("player jump must reach the near receiving bank"); return
	host.active.controller.router.request_action(&"jump_release")
	mark("bank")
	await ticks(22)
	var lip_x := float(gate.span[1])-7
	if not await climb_bank(lip_x,receiver.x,636) or not await climb_bank(lip_x,receiver.x+2,558):
		fail("climb from receiving ledge to the grass"); return
	mark("clear")
	if not await walk(460) or not await walk(440):
		fail("revisit the east viewpoint"); return
	await ticks(62)
	if not host.active.state.has(event) or not host.active.state.value.explored.has(link.discovery.target_room):
		fail("leaving the grass must keep discovery and visit"); return
	mark("restored")
	if not await walk(305): fail("revisit the grass"); return
	await ticks(52)
	mark("revisit")
	await ticks(30)
	mark("end")
	await host.active.audio_service.shutdown()
	host.free()
	quit(0)
