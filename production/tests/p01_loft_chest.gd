extends SceneTree
## Actual action host, touch input, coin motion and persisted separate pickup receipts.
const DOCUMENT := "res://rooms/world/P01.json"
const ID := "p01_loft_coin_chest"
var catalog := WorldContentCatalog.new()
var checks := 0
var failures := 0

class Storage extends WorldSaveService:
	var writable := true
	var payload := {}
	var revision := 0
	func commit(next: Dictionary, revision_value: int) -> bool:
		if not writable: return false
		payload = next.duplicate(true)
		revision = revision_value
		return true
	func load_profile() -> Dictionary:
		return {"accepted":true,"revision":revision,"payload":payload.duplicate(true)}

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL P01 chest ",detail)

func frames(count: int) -> void:
	for tick in count: await physics_frame

func open_room(storage: Storage) -> OrdinaryRoomSession:
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(WorldRoomDocument.read(DOCUMENT),storage,null,catalog)
	check(error.is_empty(),"open the production document: "+error)
	if error.is_empty():
		for tick in 180:
			await physics_frame
			if session.controller.active and session.player.grounded_contact(): break
	return session

func close(session: OrdinaryRoomSession) -> void:
	if session.audio_service != null: await session.audio_service.shutdown()
	session.free()
	await frames(2)

func press_touch(session: OrdinaryRoomSession) -> void:
	session.touch_controls.set_enabled(true)
	await frames(1)
	for pressed: bool in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 2
		event.position = session.touch_controls.interact_center
		event.pressed = pressed
		root.push_input(event,true)
		await frames(2)

func invalid_docs() -> void:
	var doc := WorldRoomDocument.read(DOCUMENT)
	for changes: Dictionary in [{"amount":0},{"amount":2.5},{"support_id":"missing"},{"repeat":true}]:
		var broken := doc.duplicate(true)
		for action: Dictionary in broken.actions:
			if action.id == ID: action.merge(changes,true)
		var made := WorldRoomDocument.instantiate(broken)
		check(made.has("error"),"reject inconsistent chest "+str(changes))
		if made.has("room"): made.room.free()

func run() -> void:
	check(catalog.load_locked().ok and catalog.load_bindings("res://config/imported_world/bindings.json").ok,"locked world and room bindings")
	var store := Storage.new()
	var session := await open_room(store)
	if session.room==null:
		await close(session)
		quit(1)
		return
	var chest := session.room.physical_action(ID)
	if chest==null:
		check(false,"authored action chest")
		await close(session)
		quit(1)
		return
	invalid_docs()
	var at := chest.position
	var amount: int = chest.action.amount
	var baseline: int = session.services.ledger().gold
	var chest_source := "income:chest:P01/"+ID
	session.player.reset_at(Vector2(at.x,270))
	await frames(4)
	await press_touch(session)
	check(session.player.grounded_contact() and not session.state.value.receipts.has(ID),"touch below the loft cannot open it")
	session.player.reset_at(at+Vector2.UP*13)
	await press_touch(session)
	check(not session.player.grounded_contact() and not session.state.value.receipts.has(ID),"a nearby airborne player cannot open it")
	session.player.reset_at(at+Vector2.RIGHT*24)
	await frames(5)
	check(chest.available(session.player.position,"main") and chest.chest_sprite.visible and not chest.chest_sprite.get_meta("underworld_chest_open"),"standing on the specified support exposes the real closed chest")
	var before_rejection := store.revision
	store.writable=false
	await press_touch(session)
	check(store.revision==before_rejection and not store.payload.get("receipts",{}).has(ID) and not chest.chest_sprite.get_meta("underworld_chest_open") and session.services.ledger().drops.is_empty(),"a rejected save neither opens the lid nor scatters currency")
	store.writable=true
	await press_touch(session)
	var ledger := session.services.ledger()
	var issued := 0
	for unit: Dictionary in ledger.drops.values(): issued+=int(unit.amount)
	check(session.controller.router.current_device==&"touch" and store.payload.receipts.has(ID) and store.payload.receipts.has(chest_source) and chest.chest_sprite.get_meta("underworld_chest_open"),"touch interaction commits entitlement and visible open lid together")
	check(issued==amount and ledger.gold==baseline,"physical coins exist before wallet collection")
	await close(session)
	session = await open_room(store)
	chest = session.room.physical_action(ID)
	check(chest.chest_sprite.get_meta("underworld_chest_open") and not session.room.loot.pickups.is_empty(),"reload restores open chest and uncollected coins")
	session.player.reset_at(at+Vector2.LEFT*28)
	await frames(4)
	var before_repeat := session.state.revision
	await press_touch(session)
	check(session.state.revision==before_repeat and session.services.ledger().drops.size()==ledger.drops.size(),"opening input after reload does not create more coins")
	# Stand in pickup range of the actual bouncing unit, with the real loot
	# Area and bank transaction still running. A rejected pickup must survive.
	store.writable = false
	await frames(45)
	for tick in 18:
		if session.room.loot.pickups.is_empty(): break
		var unit: Dictionary = session.room.loot.pickups[0]
		session.player.reset_at(Vector2(unit.position)+Vector2.UP*6)
		await frames(1)
	check(session.services.ledger().gold==baseline and not session.services.ledger().drops.is_empty(),"failed pickup remains in the world ledger")
	store.writable=true
	for tick in 110:
		var units := session.services.ledger().drops as Dictionary
		if units.is_empty(): break
		for unit: Dictionary in session.room.loot.pickups:
			if units.has(unit.id):
				session.player.reset_at(Vector2(unit.position)+Vector2.UP*5)
				break
		await physics_frame
	check(session.services.ledger().gold==baseline+amount and session.services.ledger().drops.is_empty(),"actual pickups bank exactly the authored total")
	await close(session)
	session=await open_room(store)
	chest=session.room.physical_action(ID)
	session.player.reset_at(at)
	await frames(5)
	var final_revision := store.revision
	await press_touch(session)
	check(chest.chest_sprite.get_meta("underworld_chest_open") and session.state.revision==final_revision and session.services.ledger().gold==baseline+amount,"collected and reopened profile cannot pay again")
	await close(session)
	print("P01 LOFT CHEST failures=",failures," checks=",checks)
	quit(1 if failures else 0)
