extends SceneTree

var failures := 0
var checks := 0

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)

func _initialize() -> void:
	run.call_deferred()

func ticks(n: int) -> void:
	for i: int in n: await physics_frame

func document(start := Vector2(96,366)) -> Dictionary:
	var doc := WorldRoomDocument.read("res://tests/assembly_room.json")
	var floor_row: Dictionary = doc.entities.floor
	doc.entities = {"floor":floor_row}
	doc.root.properties.start_point = [start.x,start.y]
	doc.root.properties.region_id = "gear_city"
	return doc

func place(doc: Dictionary,id: String,name: String,at: Vector2,p: Dictionary = {},opts: Dictionary = {}) -> void:
	var made := WorldElementCatalog.instantiate_definition(id,name,at,"gear_city",opts)
	if made.has("error"):
		check(false, "creation "+id+": "+str(made.error))
		return
	if made.entities.has(name): made.entities[name].properties.merge(p,true)
	doc.entities.merge(made.entities)

func open_room(doc: Dictionary) -> OrdinaryRoomSession:
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(doc)
	check(error.is_empty(),"open "+error)
	if not error.is_empty():
		session.free()
		return null
	return session

func close(session: OrdinaryRoomSession) -> void:
	check(await session.audio_service.shutdown(),"release room audio")
	session.free()

func test_modes() -> void:
	var doc := document()
	place(doc,"platform.moving","cart",Vector2(250,290),{"motion_mode":"manual_cart","route":[[240,0],[240,-80]]})
	place(doc,"platform.moving","dock",Vector2(470,220),{"motion_mode":"call_dock","initial_dock":1,"endpoint":[150,0],"period":1.0})
	place(doc,"platform.moving","dwell",Vector2(560,300),{"initial_running":false,"endpoint":[80,0],"period":2,"endpoint_dwell":0.5})
	var session := open_room(doc)
	if session == null: return
	var cart: WorldMovingPlatform = session.room.element_runtime.nodes.cart
	var dock: WorldMovingPlatform = session.room.element_runtime.nodes.dock
	var dwell: WorldMovingPlatform = session.room.element_runtime.nodes.dwell
	check(dwell.sample_position(.45).is_equal_approx(dwell.origin),"cycle starting dwell")
	check(dwell.sample_position(1.75).is_equal_approx(dwell.origin+Vector2(80,0)),"cycle far dwell")
	check(dock.position.is_equal_approx(dock.origin+Vector2(150,0)), "initial far dock")
	session.player.reset_at(dock.origin+dock.call_points[0])
	session._interact()
	await ticks(36)
	check(dock.target_dock == 0 and dock.position.distance_to(dock.origin)<.1,"shore calls stopped carrier")
	session.player.reset_at(dock.origin+Vector2(0,-31))
	await ticks(12)
	check(dock.carries_player(),"real dock passenger standing")
	session._interact()
	await ticks(36)
	check(dock.target_dock==1 and dock.carries_player() and absf(session.player.position.x-dock.position.x)<6,"docked rider travels")
	session.player.reset_at(cart.origin+Vector2(0,-31))
	await ticks(14)
	check(cart.carries_player(),"cart real floor before driving")
	session.controller.router.set_move_axis(1)
	await ticks(6)
	check(cart.cart_speed == 0 and session.controller.driven_cart == null,"ordinary passenger walks independently")
	session._interact()
	await ticks(18)
	check(session.controller.driven_cart == cart and cart.cart_speed>30 and cart.cart_distance>1,"cart accelerates with driver")
	var braking := cart.cart_speed
	session.controller.router.set_move_axis(-1)
	await ticks(4)
	check(cart.cart_speed < braking,"reverse request applies brake first")
	await ticks(38)
	check(cart.cart_speed < 0 or cart.cart_distance == 0,"reversal eventually drives opposite direction")
	session.controller.router.set_move_axis(1)
	await ticks(38)
	var from := cart.cart_distance
	session.controller.router.request_action(&"jump")
	await ticks(4)
	check(session.controller.driven_cart == null and cart.cart_distance>from and not cart.carries_player(),"jump leaves driving and cart coasts")
	session.controller.router.set_move_axis(0)
	await ticks(80)
	check(is_zero_approx(cart.cart_speed),"empty cart brakes to stop")
	var candidate := cart.element_state()
	cart.element_restore(candidate)
	check(is_equal_approx(cart.cart_distance,candidate.distance),"cart position restores along track")
	await close(session)

func test_water_and_load() -> void:
	var doc := document()
	place(doc,"zone.water_level","water",Vector2(220,96),{"bounds":[220,96,352,224],"low_surface_y":220,"high_surface_y":32,"surface_speed":60})
	for pair: Array in [["float",320],["other",480]]:
		place(doc,"platform.moving",pair[0],Vector2(pair[1],300),{"motion_mode":"follow_water","water_source_id":"water","platform_size":[90,16],"draft_offset":-8})
	place(doc,"platform.solid","ceiling",Vector2(256,148),{"rect":[256,148,124,32]})
	place(doc,"platform.windchime_dandelion","seed",Vector2(710,250),{"endpoint":[40,0],"period":5,"max_sink":35})
	var session := open_room(doc)
	if session==null: return
	var water: WorldWaterLevel = session.room.element_runtime.nodes.water
	var carrier: WorldMovingPlatform = session.room.element_runtime.nodes.float
	var other: WorldMovingPlatform = session.room.element_runtime.nodes.other
	check(is_equal_approx(carrier.position.y,water.actual_surface_y-8),"initial water position and draft")
	water.element_restore(water.element_propose("set_active",true))
	await ticks(65)
	check(is_equal_approx(other.position.y,water.actual_surface_y-8) and carrier.position.x==320,"multiple floats track one water surface")
	check(is_equal_approx(water.volume.bounds.position.y,water.actual_surface_y) and water.volume.bounds.end == water.bounds.end,"physical hazard and draw use actual surface")
	water.element_restore(water.element_propose("set_active",false))
	var prior := water.level
	await ticks(3)
	check(water.level>prior,"water reverses before reaching high level")
	water.element_restore(water.element_propose("set_active",true))
	await ticks(200)
	check(carrier.position.y > water.actual_surface_y+35 and absf(other.position.y-water.actual_surface_y+8)<.1, "blocked float lags, free float and water continue")
	for child: Node in session.room.get_children():
		if child is StaticBody2D and child.has_meta("world_ground") and child.get_meta("world_ground").position == Vector2(256,148):
			child.collision_layer = 0
	var lagged := carrier.position.y
	await ticks(4)
	check(carrier.position.y < lagged and lagged-carrier.position.y < 6,"unblocked float follows at bounded speed")
	await ticks(100)
	check(is_equal_approx(carrier.position.y,water.actual_surface_y-8),"float catches up after water has stopped")
	var seed: WorldDandelionPlatform = session.room.element_runtime.nodes.seed
	session.player.reset_at(seed.position+Vector2(0,-31))
	await ticks(74)
	check(seed.sink>12 and seed.carries_player(),"dandelion sinks under real top contact")
	seed.set_equipment_time(0)
	var frozen := seed.position
	await ticks(12)
	check(seed.position == frozen and seed.carries_player(),"time stop retains carrier support")
	seed.set_equipment_time(1)
	session.player.reset_at(Vector2(96,366))
	await ticks(100)
	check(is_zero_approx(seed.sink),"dandelion rises back to drift path")
	await close(session)

func test_groups_and_rail() -> void:
	var doc := document()
	place(doc,"assembly.counterweight_pair","pair",Vector2(280,242),{},{"upper_offsets":{"A":[-96,-80],"B":[96,-80]},"stroke":{"A":130,"B":180}})
	place(doc,"assembly.windchime_windmill","hub",Vector2(680,160),{},{"radius":64,"angle_offsets_deg":[0,120,270],"initial_angle_deg":90,"direction":"counterclockwise","platform_size":[50,12]})
	place(doc,"platform.shot_rail","rail",Vector2(440,245),{"stations":[[0,0],[120,0],[120,-80]],"move_speed":140})
	var session := open_room(doc)
	if session == null: return
	var nodes := session.room.element_runtime.nodes
	var drive: WorldCounterweight = nodes["pair/drive"]
	var a: WorldMovingPlatform = nodes["pair/A"]
	var b: WorldMovingPlatform = nodes["pair/B"]
	var orbit: WorldOrbitDrive = nodes["hub/drive"]
	var first: WorldMovingPlatform = nodes["hub/carrier_0"]
	check(orbit.carriers.size()==3 and first.position.distance_to(orbit.position+Vector2(0,64))<.1,"windmill layout and initial angle")
	orbit.element_restore(orbit.element_propose("set_active",true))
	await ticks(15)
	check(orbit.motion_clock>0 and first.position.x>orbit.position.x and first.rotation==0,"counterclockwise orbit; horizontal deck")
	first.set_equipment_time(0)
	var at := first.position
	await ticks(12)
	check(first.position == at,"enchanting one carrier freezes common wheel")
	var ay := a.position.y
	var by := b.position.y
	session.player.reset_at(a.position+Vector2(0,-31))
	await ticks(28)
	check(a.carries_player() and a.position.y>ay+6 and b.position.y<by-8 and drive.progress>.5,"single rider advances complementary progress")
	session.player.reset_at(Vector2(96,366))
	await ticks(120)
	check(is_equal_approx(drive.progress,.5),"unloaded weights settle at authored rest")
	var rail: WorldShotRail = nodes.rail
	var face := rail.get_node("ImpulseFaceLeft")
	var hit := {"collider":face,"hit_direction":Vector2.RIGHT,"packet_id":1}
	check(rail.mechanism_shot(hit) and rail.destination==1,"impact face accepts nearest aligned neighbor")
	await ticks(15)
	rail.mechanism_shot({"collider":face,"hit_direction":Vector2.UP,"packet_id":2})
	check(rail.destination==1 and rail.station==0,"moving rail retains original destination")
	await ticks(55)
	check(rail.station==1 and rail.position.is_equal_approx(rail.origin+Vector2(120,0)),"rail stops precisely at station")
	rail.mechanism_shot({"collider":face,"hit_direction":Vector2(-1,-1),"packet_id":3})
	check(rail.destination==rail.station,"ambiguous equal directions preserve station")
	await close(session)

func test_two_supports() -> void:
	var doc := document()
	place(doc,"assembly.counterweight_pair","bridge",Vector2(370,230),{},{"upper_offsets":{"A":[-48,-64],"B":[48,-64]},"stroke":{"A":128,"B":128},"platform_sizes":{"A":[96,18],"B":[96,18]}})
	var session := open_room(doc)
	if session==null: return
	var pair: WorldCounterweight = session.room.element_runtime.nodes["bridge/drive"]
	session.player.reset_at(Vector2(370,202))
	await ticks(24)
	check(pair.carriers[0].carries_player() and pair.carriers[1].carries_player() and is_equal_approx(pair.progress,.5),"player spanning two adjacent decks holds shared progress")
	session.player.reset_at(pair.carriers[1].position+Vector2(0,-28))
	await ticks(120)
	check(is_zero_approx(pair.progress) and pair.carriers[1].carries_player(),"B load reaches legal end and keeps its passenger")
	await close(session)

func test_real_shots() -> void:
	var doc := WorldRoomDocument.read("res://tests/carrier_demo.json")
	var session := open_room(doc)
	if session==null: return
	var rail: WorldShotRail = session.room.element_runtime.nodes.shuttle
	var lift: WorldMovingPlatform = session.room.element_runtime.nodes["lift/carrier"]
	var bell: WorldElementSwitch = session.room.element_runtime.nodes["lift/bell"]
	await ticks(12)
	check(rail.carries_player(), "actual player at rail firing station")
	session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(29)
	check(rail.destination == 1 and rail.station == 0 and rail.moving_progress>0 and rail.hit_packets.size()==1,"player gun strikes endplate and initiates travel")
	var receipt: Variant = rail.hit_packets.keys()[0] if not rail.hit_packets.is_empty() else "missing"
	await ticks(110)
	check(rail.station==1,"physical shot completes segment")
	var duplicate := {"collider":rail.get_node("ImpulseFaceRight"),"hit_direction":Vector2.LEFT,"packet_id":receipt}
	check(not rail.mechanism_shot(duplicate) and rail.destination==1,"same attack cannot drive rail again")
	check(not lift.motion_running and not bell.is_open,"C16 starts stationary")
	session.player.reset_at(lift.position+Vector2(0,-30))
	await ticks(12)
	session.controller.router.request_action(&"shoot_release",Vector2.LEFT)
	await ticks(38)
	check(bell.is_open and lift.motion_running and lift.position.y < lift.origin.y,"actual bell shot starts C16 motion")
	session.room.element_runtime.reset_section("main")
	check(rail.station == 0 and is_zero_approx(rail.moving_progress) and not lift.motion_running,"challenge reset reinstalls both start states")
	await close(session)

func test_time_equipment() -> void:
	var doc := WorldRoomDocument.read("res://tests/carrier_demo.json")
	var spawn := Vector2(300,281)
	place(doc,"recovery.station","rest",spawn)
	place(doc,"equipment.reward","clock_reward",spawn,{"source_id":"equipment.105"})
	place(doc,"platform.moving","cart",Vector2(680,375),{"motion_mode":"manual_cart"})
	var session := open_room(doc)
	if session==null: return
	await ticks(12)
	check(session.equipment_transaction("claim","equipment.105",session.state.revision) and session.equipment_transaction("equip","105",session.state.revision),"claim and equip actual time-stop core at station")
	var gear := session.equipment
	gear.activate_selected(Vector2.RIGHT)
	session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(16)
	var nodes := session.room.element_runtime.nodes
	var rail: WorldShotRail = nodes.shuttle
	check(rail.destination == 1 and rail.equipment_time_scale == 0 and gear.fx.time.has("shuttle"),"enchanted player projectile strikes and freezes rail")
	var held := rail.position
	await ticks(135)
	check(rail.position == held,"rail holds exact accepted motion while enchanted")
	await ticks(85)
	check(rail.position.x>held.x+30 and rail.equipment_time_scale==1,"rail resumes its original move after real enchant expires")
	gear.primary_packet_started(842,Vector2.RIGHT)
	gear.mechanism_hit(nodes["wheel/carrier_1"],842)
	gear.mechanism_hit(nodes["wheel/carrier_3"],842)
	gear.mechanism_hit(nodes.cart,842)
	await ticks(3)
	var orbit: WorldOrbitDrive = nodes["wheel/drive"]
	check(gear.fx.time.has("wheel/drive") and orbit.equipment_time_scale == 0 and not gear.fx.time.has("wheel/carrier_1"),"one enchant on orbit owner for multiple struck members")
	check(not gear.fx.time.has("cart"),"manual carts are incompatible with time equipment")
	await close(session)

func test_unlock_and_ceiling() -> void:
	var doc := document()
	doc.actions = [{"id":"power","room_id":doc.room_id,"section_id":"main","grants":["lift_power"],"requires":[]}]
	place(doc,"platform.moving","locked",Vector2(200,240),{"activation_flag":"lift_power","initial_running":false})
	place(doc,"zone.water_level","basin",Vector2(480,128),{"bounds":[480,128,256,192],"low_surface_y":192,"high_surface_y":32,"surface_speed":90})
	place(doc,"platform.moving","float",Vector2(580,300),{"motion_mode":"follow_water","water_source_id":"basin","draft_offset":-8,"platform_size":[90,16]})
	place(doc,"platform.solid","roof",Vector2(526,180),{"rect":[526,180,120,24]})
	var session := open_room(doc)
	if session == null: return
	var nodes := session.room.element_runtime.nodes
	var locked: WorldMovingPlatform = nodes.locked
	var carrier: WorldMovingPlatform = nodes.float
	var basin: WorldWaterLevel = nodes.basin
	check(not locked.visible and locked.collision_layer == 0,"locked carrier starts with no collider")
	session.player.reset_at(locked.origin)
	var candidate := session.state.action_candidate("power",doc.room_id)
	check(not candidate.is_empty() and session.state.commit(candidate,session.state.revision),"actual world unlock transaction")
	await ticks(1)
	check(not locked.visible,"unlock waits while player occupies spawn space")
	session.player.reset_at(carrier.position + Vector2(0,-27))
	await ticks(12)
	check(locked.visible and locked.collision_layer==1 and carrier.carries_player(),"unlock installs collider when clear")
	check(not basin.volume.visible and not basin.volume.is_physics_processing(),"empty water has no rendering or contact")
	basin.element_restore(basin.element_propose("set_active",true))
	await ticks(115)
	check(carrier.position.y>244 and carrier.position.y<252 and carrier.carries_player() and is_equal_approx(basin.actual_surface_y,160),"ceiling stops actual rider and platform together while water continues")
	check(session.controller.actor_resources.health.current < session.controller.actor_resources.health.capacity,"submerged rider receives real water damage")
	check(basin.volume.bounds.intersects(Rect2(session.player.position-Vector2(12,18),Vector2(24,36))),"submerged rider inside actual hazardous water")
	session.room.element_runtime.reset_section("main")
	check(basin.level==192 and is_equal_approx(carrier.position.y,basin.actual_surface_y-8),"water and follower restore the same initial level")
	await close(session)

func test_float_validation() -> void:
	for obstacle in ["spawn","platform","polygon","headroom","shore"]:
		var doc := document()
		place(doc,"zone.water_level","source",Vector2(250,100),{"bounds":[250,100,200,240]})
		place(doc,"platform.moving","float",Vector2(350,240),{"motion_mode":"follow_water","water_source_id":"source"})
		match obstacle:
			"spawn": doc.root.properties.start_point=[350,260]
			"platform": place(doc,"platform.solid","terrain",Vector2.ZERO,{"rect":[340,258,80,16]})
			"polygon": place(doc,"terrain.polygon","terrain",Vector2.ZERO,{"points":[[340,258],[400,260],[380,280]]})
			"headroom": place(doc,"platform.solid","roof",Vector2.ZERO,{"rect":[335,208,30,12]})
			"shore": doc.entities.float.properties.position=[640,230]
		var result := WorldRoomDocument.instantiate(doc)
		check(result.has("error"),"reject unsafe float geometry "+obstacle)
		if result.has("room"): result.room.free()

func test_invalid() -> void:
	for spec: Array in [["platform.moving",{"motion_mode":"manual_cart","route":[[0,0]]}],["platform.moving",{"activation_flag":"does_not_exist"}],
			["platform.moving",{"motion_mode":"call_dock","initial_dock":1.5}],
			["platform.moving",{"motion_mode":"follow_water","water_source_id":"absent"}],
			["zone.water_level",{"high_surface_y":192}],["platform.shot_rail",{"stations":[[0,0],[0,0]]}],
			["platform.windchime_dandelion",{"sink_speed":0}]]:
		var doc := document()
		place(doc,spec[0],"bad",Vector2.ZERO,spec[1])
		var result := WorldRoomDocument.instantiate(doc)
		check(result.has("error"),"invalid options rejected "+str(spec))
		if result.has("room"):result.room.free()
	for spec: Array in [["assembly.windchime_windmill",{"angle_offsets_deg":[0,360]}],["assembly.counterweight_pair",{"stroke":{"A":192,"B":0}}]]:
		check(WorldElementCatalog.instantiate_definition(spec[0],"bad",Vector2.ZERO,"gear_city",spec[1]).has("error"),"invalid group rejected")

func run() -> void:
	test_invalid()
	test_float_validation()
	await test_modes()
	await test_real_shots()
	await test_time_equipment()
	await test_unlock_and_ceiling()
	await test_water_and_load()
	await test_groups_and_rail()
	await test_two_supports()
	print("CARRIER LIBRARY failures=",failures," checks=",checks)
	quit(1 if failures else 0)
