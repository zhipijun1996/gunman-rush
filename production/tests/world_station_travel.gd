extends SceneTree
## Two independently reached stations exercise the travel menu, safe receiving
## point, redisplay and failed-save rollback. No walking route is inferred.
class Slot extends WorldSaveService:
	var writable := true
	var value := {}
	var revision := 0
	func commit(payload: Dictionary, next: int) -> bool:
		if not writable: return false
		value = payload.duplicate(true)
		revision = next
		return true
	func load_profile() -> Dictionary:
		return {"accepted":true,"payload":value.duplicate(true),"revision":revision}

class StationHost extends WorldGameHost:
	func startup_destination() -> Dictionary:
		return {"ok":true,"room":(storage as Slot).value.get("room","G12")}

var host: StationHost
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in count: await physics_frame

func test(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL station ",message," ",host.active.room.room_id," ",host.active.player.position," ",host.last_error)
	return ok

func open(slot: Slot) -> void:
	host = StationHost.new()
	host.storage = slot
	root.add_child(host)
	await frames(7)

func close() -> void:
	await host.active.audio_service.shutdown()
	host.free()
	await frames(4)

func approach(id: String) -> void:
	var room:=host.active
	var x:=FixedWorldProvider.point(host.active_doc.sites[id].at).x
	var axis:=signf(x-room.player.position.x)
	room.controller.router.set_move_axis(axis)
	for i in 95:
		if (x-room.player.position.x)*axis<3: break
		await frames(1)
	room.controller.router.set_move_axis(0)
	await frames(5)

func press_named(label: String) -> bool:
	for child: Node in host.active.content_sites.menu.choices.get_children():
		if child is Button and child.text==label and not child.is_queued_for_deletion():
			child.pressed.emit()
			return true
	return false

func ring(id: String) -> void:
	host.active.controller.router.request_action(&"interact")
	await frames(3)
	var sites:=host.active.content_sites
	if not sites.menu.visible_panel(): return
	if sites.menu.heading.text=="交互":
		press_named(sites.rows[id].data.name)
		await frames(1)

func settle() -> void:
	for i in 180:
		if not host.crossing: break
		await frames(1)
	await frames(3)

func run() -> void:
	var slot:=Slot.new()
	await open(slot)
	var stations: Array=host.catalog.object("transport").value.stations
	test(stations.size()==12,"read twelve stations from the locked transport table")
	var map := host.route_map as WorldRouteMap
	test(map.known_markers("G12").has("rest") and not map.known_markers("G12").has("station") and map.known_markers("K08").is_empty(),"the visited city shows its actual bench, with no undiscovered station or castle markers")
	var first_pin := map.map_position("G12",host.active.player.position)
	await approach("tp_G12")
	test(first_pin.distance_to(map.map_position("G12",host.active.player.position))>0.01,"actual walking changes the player pin inside the city's surveyed outline")
	test(not host.active.state.value.receipts.has("tp_G12"),"visiting a stop does not activate it")
	await ring("tp_G12")
	test(host.active.state.value.receipts.has("tp_G12") and host.active.state.has("travel_G12"),"safe interaction activates the first station")
	test(map.known_markers("G12").get("station")==map.map_position("G12",FixedWorldProvider.point(host.active_doc.sites.tp_G12.at)),"the real station pin appears at the activated platform")
	test(host.active.content_sites.menu.choices.get_child_count()==0,"an unopened destination cannot be selected")
	host.active.content_sites.menu.close()
	# Independent arrival on foot from the outer court. This fixture only selects
	# the approach; all following station clicks and transfers go through gameplay.
	var court:=host.read_destination("K08")
	var at:=FixedWorldProvider.point(court.sites.tp_K08.at)
	host.enter_room("K08","",court,at+Vector2.RIGHT*68)
	await frames(7)
	await approach("tp_K08")
	await ring("tp_K08")
	test(host.active.state.value.receipts.has("tp_K08"),"activate a real catalog station which defines no separate activation flag")
	var name_g:String
	for stop: Dictionary in stations:
		if stop.id=="tp_G12": name_g=stop.name
	var source:=host.active
	slot.writable=false
	test(press_named(name_g),"select a previously activated destination from the visible list")
	await settle()
	test(host.active==source and source.controller.active and slot.value.room=="K08","failed travel retains the old room, controller and save")
	slot.writable=true
	await ring("tp_K08")
	test(press_named(name_g),"the same journey can be retried")
	await settle()
	test(host.active.room.room_id=="G12" and slot.value.entry=="tp_G12" and host.active.player.is_on_floor(),"arrive at the exact supported station in one saved transfer")
	await close()
	await open(slot)
	var landed:=FixedWorldProvider.point(host.active_doc.get("sites",{}).get("tp_G12",{"at":[0,0]}).at)
	test(host.active.room.room_id=="G12" and host.active.player.position.distance_to(landed)<3,"new session restores the destination station")
	host.travel_station("tp_G12","Y23",host.active.state.revision)
	test(not host.crossing and host.active.room.room_id=="G12","a rest-only room cannot be selected as a station")
	await close()
	print("WORLD STATION travel failures=",failures," checks=",checks)
	quit(1 if failures else 0)
