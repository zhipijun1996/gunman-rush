extends SceneTree
## The P01/F08 latch, receiving geometry and the consumption of a saved G08 right.
const ROOT := "res://rooms/world/"
const SIDES := ROOT+"p02_connections/"
const FLAG := "forest_slope_return_open"
var catalog := WorldContentCatalog.new()
var failures := 0
var checks := 0

class Storage extends WorldSaveService:
	var writable := true
	var saved := {}
	var rev := 0
	func commit(candidate: Dictionary, revision: int) -> bool:
		if not writable: return false
		saved = candidate.duplicate(true)
		rev = revision
		return true
	func load_profile() -> Dictionary:
		return {"accepted":true,"payload":saved.duplicate(true),"revision":rev}

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL world shortcut ",text)

func frames(n: int) -> void:
	for tick in n: await physics_frame

func open_room(id: String, store: Storage, edge := "") -> OrdinaryRoomSession:
	var s := OrdinaryRoomSession.new()
	root.add_child(s)
	var path := (ROOT if id in ["P01","P03"] else SIDES)+id+".json"
	var error := s.open(WorldRoomDocument.read(path),store,null,catalog,edge)
	check(error.is_empty(),id+" "+error)
	await frames(3)
	return s

func close(s: OrdinaryRoomSession) -> void:
	if s.audio_service != null: await s.audio_service.shutdown()
	s.free()
	await frames(2)

func press_up(s: OrdinaryRoomSession) -> void:
	var keyboard: KeyboardMouseAdapter = s.player.get_node("KeyboardMouseAdapter")
	for pressed: bool in [true,false]:
		var key := InputEventKey.new()
		key.keycode = KEY_UP
		key.pressed = pressed
		keyboard._unhandled_input(key)
		await frames(3)

func shut_from_plains() -> void:
	var room := await open_room("P01",Storage.new())
	if room.controller == null: await close(room); return
	var gate := room.room.get_node("ForestShortcutGate")
	room.player.reset_at(gate.position+Vector2(63,-18))
	room.controller.router.set_move_axis(-1)
	await frames(45)
	room.controller.router.set_move_axis(0)
	await press_up(room)
	check(gate.wall.collision_layer==1 and room.player.position.x>gate.position.x and room.player.is_on_floor(),"outside collision holds a walking body")
	check(not room.state.has(FLAG) and not catalog.passage_access("P01","d223",room.state.value.flags).matches,"outer key cannot open the inner latch")
	check(catalog.shortcut_candidate(room.state,"F08","d223").is_empty(),"claim rejects a spoofed source room")
	await close(room)

func forest_latch() -> void:
	var store := Storage.new()
	var s := await open_room("F08",store)
	if s.controller==null: await close(s); return
	var gate := s.room.get_node("ForestShortcutGate")
	check(not gate.opened and not catalog.passage_access("F08","d223",s.state.value.flags).matches,"starting in the forest does not issue a shortcut")
	await press_up(s)
	check(not gate.opened,"cannot release the latch from across the room")
	s.controller.router.set_move_axis(1)
	for tick in 160:
		await physics_frame
		if s.player.position.x>=gate.latch.x-4: break
	s.controller.router.set_move_axis(0)
	await frames(4)
	store.writable=false
	await press_up(s)
	check(not gate.opened and gate.wall.collision_layer==1 and not s.state.has(FLAG),"failed storage keeps timber and collision closed")
	store.writable=true
	await press_up(s)
	var rev := s.state.revision
	check(gate.opened and gate.wall.collision_layer==0 and s.state.value.receipts.has(FLAG),"nearby forest-side key commits one permanent unlock")
	await press_up(s)
	check(s.state.revision==rev and catalog.passage_access("P01","d223",s.state.value.flags).matches and catalog.passage_access("F08","d223",s.state.value.flags).matches,"same receipt opens both directions once")
	await close(s)
	s=await open_room("F08",store)
	if s.controller!=null:
		check(s.room.get_node("ForestShortcutGate").opened and s.state.revision==rev,"load reinstalls the physically open gate")
	await close(s)

func ability_and_receivers() -> void:
	var acquired := catalog.lookup("events","W").row as Dictionary
	check(acquired.room=="G08" and not acquired.automatic_on_entry and not catalog.condition_match(acquired,[]).matches and catalog.condition_match(acquired,["encounter_G07_clear"]).matches,"G08 requires its documented defeat and an explicit device pickup")
	check(catalog.passage_access("P03","d017",[]).matches and catalog.passage_access("P13","d017",[]).matches,"inner climb never turns the eastern door into a global W lock")
	for side: Array in [["P04","d003"],["P13","d017"]]:
		var s := await open_room(side[0],Storage.new(),side[1])
		if s.controller!=null:
			check(s.player.is_on_floor(),"supported receiving tread in "+side[0])
			var at := s.player.position
			s.controller.router.set_move_axis(-1 if side[0]=="P04" else 1)
			await frames(15)
			s.controller.router.set_move_axis(0)
			check(s.player.position.distance_to(at)>40,"real inward movement in "+side[0])
		await close(s)
	var store := Storage.new()
	var room := await open_room("P13",store,"d017")
	if room.controller == null: await close(room); return
	check(not room.controller.traversal.has_capability(&"wall_climb"),"a fresh game cannot attach to the ridge")
	# Rehydrate a profile containing the actual G08 fact; this slice has no G08 pickup.
	check(room.checkpoint(),"create a real room checkpoint before replaying the granted profile")
	store.saved.flags.append(acquired.event)
	await close(room)
	room = await open_room("P13",store)
	if room.controller!=null:
		check(room.controller.traversal.has_capability(&"wall_climb") and not room.controller.traversal.has_capability(&"grapple"),"saved W restores only wall traversal")
	await close(room)

func run() -> void:
	check(catalog.load_locked().ok and catalog.load_bindings("res://config/imported_world/bindings.json").ok,"load world contract")
	if failures==0:
		await shut_from_plains()
		await forest_latch()
		await ability_and_receivers()
	print("WORLD SHORTCUTS failures=",failures," checks=",checks)
	quit(1 if failures else 0)
