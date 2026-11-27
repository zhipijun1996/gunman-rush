extends SceneTree
## Camera metadata joins the same validated room document and editor round trip.
const Contract := preload("res://game/world/levels/room_camera_contract.gd")
var failures := 0
var checks := 0
class MemoryStore extends WorldSaveService:
	var saved := {}
	var sequence := 0
	func load_profile() -> Dictionary:
		return {"accepted":true,"payload":saved.duplicate(true),"revision":sequence}
	func commit(candidate: Dictionary,revision: int) -> bool:
		saved=candidate.duplicate(true)
		sequence=revision
		return true

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL room camera ",label)

func reject(source: Dictionary, camera: Variant, label: String) -> void:
	var invalid := source.duplicate(true)
	invalid.camera = camera
	check(WorldRoomDocument.instantiate(invalid).has("error"),label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var road := WorldRoomDocument.read("res://rooms/world/P03.json")
	var compiler := Contract.resolve(road)
	check(Contract.validate(road.camera,road.bounds).is_empty(),"P03 camera validates")
	check(compiler.zones[0].zoom==road.camera.zoom and compiler.zones[1].zoom==road.camera.zoom,"both compositions inherit the room zoom")
	check(FixedWorldProvider.point(compiler.zones[1].offset)==Vector2(0,-52) and compiler.links[0].direction==-1,"upper-road shift and reverse vertical passage")
	var doc := road.duplicate(true)
	doc.erase("camera")
	var plain := Contract.resolve(doc)
	check(plain.zones[0].trigger==road.bounds and plain.zones[0].display==road.bounds and not plain.zones[0].has("zoom"),"unconfigured camera inherits the full room bounds and global zoom")
	for id: String in ["P01","P02"]:
		var pilot := WorldRoomDocument.read("res://rooms/world/"+id+".json")
		check(Contract.resolve(pilot).zones[0].zoom==pilot.camera.zoom,id+" retains its accepted frame")
	var camera: Dictionary = road.camera.duplicate(true)
	camera.zones[1].zoom = 1.8
	camera.zones[1].conceal = [[140,135,42,25]]
	check(Contract.resolve({"bounds":road.bounds,"camera":camera}).zones[1].zoom==1.8,"authored per-zone zoom overrides its room value")
	doc.camera = camera
	var made := WorldRoomDocument.instantiate(doc)
	check(made.has("room"),"composed room instantiates")
	if made.has("room"):
		var room := made.room as FixedWorldRoom
		var packed := PackedScene.new()
		check(packed.pack(room)==OK and WorldRoomDocument.extract(packed).get("camera",{})==camera,"camera survives a scene/editor round trip")
		room.configure({"doors":[],"camera":Contract.resolve(doc),"world_geometry":WorldRoomSpace.document_geometry(doc.bounds,doc.exits)})
		root.add_child(room)
		check(room.camera_concealers.has("old_road"),"authored concealment built from native terrain")
		if room.camera_concealers.has("old_road"):
			room.update_camera_concealment("valley",{})
			check(room.camera_concealers.old_road.visible,"hide upper niche while away")
			room.update_camera_concealment("valley",{"a":camera.zones[0],"b":camera.zones[1],"portal":camera.links[0]})
			check(not room.camera_concealers.old_road.visible,"both sides revealed while crossing")
		room.free()
	reject(road,{"zones":{}},"zone rows require a list")
	reject(road,{"profile":"invalid"},"unknown profile")
	reject(road,{"zoom":0},"zero zoom")
	reject(road,{"zoom":"1.6"},"non numeric zoom")
	reject(road,{"camera_zoom":2},"misspelled field")
	for field: String in ["trigger","display","zoom","look_y","follow_range","look_down","conceal","id"]:
		var wrong := camera.duplicate(true)
		wrong.zones[1][field] = {"trigger":[0,0,0,20],"display":[3800,4200,20,20],"zoom":-1,"look_y":[100,90],"follow_range":[-3,90],"look_down":7,"conceal":[[3800,4200,4,8]],"id":"valley"}[field]
		reject(road,wrong,field+" rejected")
	for field: String in ["a","b","band","display","axis","direction"]:
		var wrong := camera.duplicate(true)
		wrong.links[0][field] = {"a":"old_road","b":"missing","band":[0,0,4,-12],"display":[0,400,32,32],"axis":"diagonal","direction":1}[field]
		reject(road,wrong,"link "+field+" rejected")
	var forest := preload("system_room_fixture.gd").duel("F11","enc_F11","enemy.forest_antler","hollow_antler")
	var fight: Dictionary = forest.camera.zones[1]
	check(Contract.validate(forest.camera,forest.bounds,forest.sites).is_empty(),"real forest boss has a matching authored arena")
	var arena: Dictionary = Contract.resolve(forest).zones[1]
	check(arena.arena and not arena.look_up and not arena.look_down and arena.encounter=="enc_F11","fixed battle frame suppresses manual look")
	var unknown: Dictionary = forest.camera.duplicate(true)
	unknown.zones[1].encounter="enc_F_IN01"
	reject(forest,unknown,"cannot enable a different room's encounter")
	var bad_profile: Dictionary = forest.camera.duplicate(true)
	bad_profile.zones[1].profile="horizontal_follow"
	reject(forest,bad_profile,"encounter framing needs the fixed-arena profile")
	reject(forest,{"zones":[fight]},"empty or all-conditional encounters need a free exploration frame")
	var duplicate := camera.duplicate(true)
	duplicate.links.append(duplicate.links[0].duplicate(true))
	reject(road,duplicate,"ambiguous overlapping links")
	var conditional := road.duplicate(true)
	conditional.camera.zones[1].requires = [["W"],["H","core_T"]]
	conditional.camera.links[0].mechanism = "bridge_latch"
	conditional.entities.bridge_latch = {"id":"bridge_latch","definition_id":"gate.masonry","definition_version":1,"properties":{"bounds":[360,54,20,58]}}
	check(not WorldRoomDocument.view(conditional).has("error"),"flag alternatives and a local permanent bool may condition authored framing")
	await saved_conditions(conditional)
	conditional.entities.bridge_latch.properties.state_scope="attempt"
	reject(conditional,conditional.camera,"attempt-local latch cannot be used for persistent camera transition")
	conditional.entities.erase("bridge_latch")
	reject(conditional,conditional.camera,"absent latch cannot control a camera transition")
	conditional.camera.links[0].erase("mechanism")
	conditional.camera.zones[1].requires = ["W"]
	reject(conditional,conditional.camera,"flat flag expression would break the world-state clause consumer")
	conditional.camera.zones[1].requires = [[]]
	reject(conditional,conditional.camera,"an empty alternative would open a locked camera condition")
	print("ROOM CAMERA CONTRACT failures=",failures," checks=",checks)
	quit(1 if failures else 0)

func saved_conditions(doc: Dictionary) -> void:
	var world := WorldContentCatalog.new()
	check(world.load_locked().ok and world.load_bindings("res://config/imported_world/bindings.json").ok,"load the authoritative game world")
	var storage := MemoryStore.new()
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(doc,storage,null,world)
	check(error.is_empty(),"start the actual conditional room "+error)
	if not error.is_empty():
		session.free()
		return
	var resolver := session.camera.zones
	var upper: Dictionary = doc.camera.zones[1]
	var passage: Dictionary = doc.camera.links[0]
	check(not resolver.available(upper) and not resolver.available(passage),"initial flags and unopened masonry keep their compositions unavailable")
	var progress := session.state.candidate()
	progress.flags.append("H")
	check(session.state.commit(progress,session.state.revision) and not resolver.available(upper),"only half of the alternative flag clause is insufficient")
	progress=session.state.candidate()
	progress.flags.append("core_T")
	progress.mechanisms["bridge_latch"] = session.room.element_runtime.packet("bridge_latch",{"active":true})
	check(session.state.commit(progress,session.state.revision) and resolver.available(upper),"complete alternative from the persistent game state")
	await session.audio_service.shutdown()
	session.free()
	await physics_frame
	session=OrdinaryRoomSession.new()
	root.add_child(session)
	error=session.open(doc,storage,null,world)
	check(error.is_empty(),"restore the same room "+error)
	if error.is_empty():
		check(session.camera.zones.available(upper) and session.camera.zones.available(passage),"save reload restores real gate and flags for both camera conditions")
		await session.audio_service.shutdown()
	session.free()
