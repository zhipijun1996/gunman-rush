extends SceneTree
## Rehearse the F19 scene door on two independent standing platforms. Knock,
## travel to its independent interior, restore that entrance and walk back.
const EDGE := "s_ninja_home"
const FLAG := "discover_f19_bamboo_door"
var failures := 0
var checks := 0
var host: ReachedForest

class Slot extends WorldSaveService:
	var writable := true
	var saved := {}
	var latest := 0

	func commit(payload: Dictionary, revision: int) -> bool:
		if not writable: return false
		saved = payload.duplicate(true)
		latest = revision
		return true

	func load_profile() -> Dictionary:
		return {"accepted":true,"payload":saved.duplicate(true),"revision":latest}

class ReachedForest extends WorldGameHost:
	func has_room(id: String) -> bool:
		return id in ["F19","F_IN01"] or super.has_room(id)
	func read_destination(id: String) -> Dictionary:
		if id not in ["F19","F_IN01"]: return super.read_destination(id)
		var doc := preload("system_room_fixture.gd").flat(id)
		doc.sites["s_ninja_home"] = {"at":doc.root.properties.start_point}
		return doc
	func startup_destination() -> Dictionary:
		var slot := storage as Slot
		return {"ok":true,"room":slot.saved.get("room","F19")}

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL world interior ",label)

func frames(count: int) -> void:
	for i: int in count: await physics_frame

func open(slot: Slot) -> bool:
	host = ReachedForest.new()
	host.storage = slot
	root.add_child(host)
	await frames(12)
	check(host.active != null,"open registered source with the world host")
	return host.active != null

func interact() -> void:
	for press: bool in [true,false]:
		var key := InputEventKey.new()
		key.keycode = KEY_UP
		key.pressed = press
		Input.parse_input_event(key)
		await frames(3)

func travel(to: String) -> bool:
	await interact()
	for i: int in 140:
		if not host.crossing and host.active.room.room_id == to:
			return host.active.player.is_on_floor() and host.last_error.is_empty()
		await frames(1)
	return false

func close() -> void:
	if host.active != null: await host.active.audio_service.shutdown()
	host.free()
	await frames(3)

func run() -> void:
	var slot := Slot.new()
	if await open(slot):
		var source := host.active
		var handle := FixedWorldProvider.point(host.active_doc.sites[EDGE].at)
		check(source.player.is_on_floor() and source.player.position.distance_to(handle)<44,"arrive on supported ground at the F19 door")
		await frames(30)
		check(not source.state.has(FLAG) and not host.route_map.known_rooms().has("F_IN01"),"standing by the curtain does not knock or reveal the interior")
		slot.writable = false
		await interact()
		check(not source.state.has(FLAG) and not source.state.value.receipts.has(FLAG) and host.active==source,"a failed discovery write keeps the closed door and original session")
		slot.writable = true
		await interact()
		check(source.state.has(FLAG) and source.state.value.receipts.has(FLAG) and host.active==source,"one real knock reveals the door separately from travel")
		check(host.route_map.known_rooms().has("F_IN01"),"the committed discovery reveals the interior on the map")
		slot.writable = false
		await interact()
		for i: int in 140:
			if not host.crossing: break
			await frames(1)
		check(host.active==source and source.controller.active and slot.saved.room=="F19","a failed passage write keeps the player and saved room on the source side")
		slot.writable = true
		if await travel("F_IN01"):
			check(host.active.state.value.entry==EDGE and "F_IN01" in host.active.state.value.explored,"the separate map layer and its exact arrival door are saved together")
			await close()
			if await open(slot):
				var arrival := FixedWorldProvider.point(host.active_doc.sites[EDGE].at)
				check(host.active.room.room_id=="F_IN01" and host.active.player.position.distance_to(arrival)<3 and host.active.player.is_on_floor(),"reload at the interior handle")
				check(await travel("F19") and host.active.state.has(FLAG),"ordinary interaction returns through the same door with the discovery intact")
		else: check(false,"second real interaction traverses into F_IN01")
	await close()
	print("WORLD INTERIOR DOORS failures=",failures," checks=",checks)
	quit(1 if failures else 0)
