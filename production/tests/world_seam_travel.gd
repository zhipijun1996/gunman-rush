extends SceneTree
## Follow every registered edge in both directions; reload a real slot at both kinds of doorway.
var checks := 0
var failures := 0
var host: WorldGameHost
var slot := PlayableWorldSave.new()
var seen := {}

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL seam ", message)

func ticks(count: int) -> void:
	for i in count: await physics_frame

func boot() -> bool:
	host = WorldGameHost.new()
	host.storage = slot
	root.add_child(host)
	await ticks(8)
	check(host.active != null, "open real world " + host.last_error)
	return host.active != null

func stop_host() -> void:
	if host.active != null: await host.active.audio_service.shutdown()
	host.free()
	await ticks(3)

func reopen(id: String, edge: String) -> void:
	var before := FileAccess.get_file_as_bytes(slot.path)
	await stop_host()
	if not await boot(): return
	var gate: Dictionary = host.active_doc.exits[edge]
	check(host.active.room.room_id == id and host.active.state.value.entry == edge
		and host.active.player.position.distance_to(FixedWorldProvider.point(gate.spawn)) < 2
		and host.active.player.is_on_floor(), "load precise standing entrance "+id+"/"+edge)
	check(before == FileAccess.get_file_as_bytes(slot.path), "loading a doorway is read-only")

func travel(edge: String, destination: String) -> bool:
	var session := host.active
	var source: String = session.room.room_id
	var gate: Dictionary = host.active_doc.exits[edge]
	var center := FixedWorldProvider.point(gate.point)
	var normal := FixedWorldProvider.point(gate.direction)
	var direction := host.catalog.physical_passage(source,edge)
	check(direction.ok and direction.destination == destination and direction.direction == normal, source+"/"+edge+" follows world topology")
	check(WorldPassage.crossed(gate,center-normal*2,center+normal*2) and not WorldPassage.crossed(gate,center+normal*2,center-normal*2), "oriented player crossing "+source+"/"+edge)
	var off_axis := center
	if normal.x == 0: off_axis.x = float(gate.span[1])+1
	else: off_axis.y = float(gate.span[1])+1
	check(not WorldPassage.crossed(gate,off_axis-normal*2,off_axis+normal*2), "outside opening cannot cross "+edge)
	session.player.reset_at(FixedWorldProvider.point(gate.spawn))
	await ticks(3)
	await host.transfer(edge,destination)
	await ticks(8)
	if host.active.room.room_id != destination:
		check(false,source+"/"+edge+" -> "+destination+" "+host.last_error)
		return false
	seen[source+"/"+edge] = true
	var payload: Dictionary = slot.load_profile().payload
	check(payload.room == destination and payload.entry == edge and source in payload.explored and destination in payload.explored, "save visited rooms with exact entrance "+destination+"/"+edge)
	check(host.active.player.is_on_floor() and not host.crossing and host.active.controller.active, "restore control on landing "+destination+"/"+edge)
	return true

func run() -> void:
	slot.configure_world("user://v29_seams_%d.json"%OS.get_process_id(),false,"seams")
	if not await boot():
		quit(1)
		return
	await ticks(120)
	await host.transfer("d223","F08")
	check(host.active.room.room_id=="P01" and not host.active.state.has("forest_slope_return_open"),"a new player cannot open the forest latch from the plains")
	# Start independently on the forest-side fixture to exercise its genuine, one-way latch.
	host.enter_room("F08","")
	await ticks(12)
	host.active.player.reset_at(FixedWorldProvider.point(host.active_doc.sites.d223.at))
	await ticks(3)
	host.active.controller.router.request_action(&"interact")
	await ticks(8)
	check(host.active.state.has("forest_slope_return_open"),"operate the actual latch inside F08")
	for step: Array in [["d223","P01"],["d223","F08"],["d223","P01"],["d001","P02"],["d002","P03"],["d003","P04"],["d003","P03"],["d017","P13"],["d017","P03"],["d002","P02"]]:
		if not await travel(step[0],step[1]): break
		if step[1] == "P13": await reopen("P13","d017")
	if host.active.room.room_id == "P02":
		var site: Dictionary = host.active_doc.sites.discover_p02_low_slope
		host.active.player.reset_at(FixedWorldProvider.point(site.at))
		await ticks(6)
		check(host.active.state.has("discover_p02_low_slope"),"reach the source reveal before using the grassy opening")
		for step: Array in [["d009","P16"],["d009","P02"],["d330","P19"],["d330","P02"],["d001","P01"]]:
			if not await travel(step[0],step[1]): break
			if step[1] == "P02": await reopen("P02",step[0])
	check(seen.size()==14,"visited every direction of seven seams")
	await stop_host()
	for suffix: String in ["",".backup",".tmp",".corrupt"]: DirAccess.remove_absolute(slot.path+suffix)
	print("WORLD SEAM TRAVEL checks=",checks," failures=",failures)
	quit(1 if failures else 0)
