extends SceneTree
## One uninterrupted first visit. Every move after the starting room entry
## goes through the same controller, discovery volume and doors as normal play.
const SCENE := preload("res://rooms/world/P02.tscn")
var host: FieldTerracePilot

func _initialize() -> void:
	run.call_deferred()

func ticks(count: int) -> void:
	for i: int in count: await physics_frame

func mark(label: String) -> void:
	print("GRASS_ROUTE ",label," ",Engine.get_process_frames()," ",host.active.room.room_id," ",host.active.player.position)

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

func run() -> void:
	host = SCENE.instantiate()
	root.add_child(host)
	host.enter_room("P02","d001")
	await ticks(5)
	var doc := host.active_doc
	var gate: Dictionary = doc.exits.d009
	var link: Dictionary = host.catalog.lookup("doors","d009").row
	var event := str(link.discovery.event)
	var site := FixedWorldProvider.point(doc.sites[event].at)
	var receiver := FixedWorldProvider.point(gate.spawn)
	var mouth_x := float(gate.point[0])
	var field := FixedWorldProvider.rect(doc.entities.west_field.properties.rect)
	if FixedWorldProvider.point(gate.direction) != Vector2.DOWN or host.active.state.has(event):
		fail("source mouth or fresh discovery state"); return
	if not await walk(field.end.x-104):
		fail("western field"); return
	mark("brink")
	await ticks(36)
	if not await walk(field.end.x+27) or not await supported("P02",site.y):
		fail("drop from western field to lower grass lane"); return
	mark("lane")
	await ticks(32)
	if not await walk(site.x-9) or not host.active.state.has(event) or host.active.state.value.explored.has(link.discovery.target_room):
		fail("approaching grass must discover the door before visiting"); return
	mark("reveal")
	await ticks(60)
	if host.veil.modulate.a>.2 or not await walk(mouth_x):
		fail("grass parting and approach to shaft"); return
	if not await supported(link.discovery.target_room,float(host.read_destination(link.discovery.target_room).exits.d009.spawn[1])):
		fail("gravity must reach the cache floor"); return
	mark("below")
	await ticks(72)
	host.active.controller.router.request_action(&"jump")
	mark("jump")
	if not await supported("P02",receiver.y):
		fail("player jump must reach near receiving bank"); return
	host.active.controller.router.request_action(&"jump_release")
	mark("bank")
	await ticks(37)
	# Use the two real right-bank treads from the landing back to the grass lip.
	var lip_x := float(gate.span[1])-7
	if not await climb_bank(lip_x,receiver.x,(receiver.y+site.y)*.5) or not await climb_bank(lip_x,receiver.x+2,site.y):
		fail("climb from receiving ledge back to grass"); return
	mark("clear")
	await ticks(60)
	mark("end")
	await host.active.audio_service.shutdown()
	host.free()
	quit(0)
