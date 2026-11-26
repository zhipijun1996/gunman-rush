extends SceneTree
const Foundry = preload("res://tests/beam_library_demo.gd")
var failures := 0
var checks := 0
var session: OrdinaryRoomSession
var nodes := {}
func _initialize() -> void: run.call_deferred()
func check(value: bool,label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL ",label)
func ticks(count: int) -> void:
	for i: int in count: await physics_frame
func emit(receiver: Node,input: String,value: Variant) -> void:
	check(receiver.element_can_receive(input,value),"accept "+input)
	receiver.element_restore(receiver.element_propose(input,value))
func shot(target: MechanismSolid,id: int) -> bool:
	return target.call("mechanism_shot",{"collider":target.hit_part,"attack_kind":"shot","packet_id":"test:%d"%id,"controller":session.controller})
func snap(target: Node) -> void:
	var before: Dictionary = target.element_state()
	target.element_restore(before)
	check(before == target.element_state(),"state restore " + str(target.element_id))

func check_contracts() -> void:
	var doc := Foundry.layout()
	check(not doc.has("error"),"all fixture definitions expand")
	if doc.has("error"): return
	for pair: Array in [["beam","rotate_s",0],["beam","angles_deg",[90,450]],["beam","initial_pose",3],
		["weight","landing_offset",[10,192]],["weight","landing_offset",[0,170]],["press","hazard_depth",120],
		["growth","initial_length",500],["crate","max_push_speed",-1]]:
		var invalid := doc.duplicate(true)
		invalid.entities[pair[0]].properties[pair[1]] = pair[2]
		var result := WorldRoomDocument.instantiate(invalid)
		check(result.has("error"),"reject "+str(pair))
		if result.has("room"): result.room.free()
	for opts: Dictionary in [{"members_order":[]},{"members_order":["x","x"]},{"beam_size":[0,12]},
		{"deployed_angles_deg":{"board_0":90}},{"member_offsets":{"bad":[0,0]}}]:
		check(WorldElementCatalog.instantiate_definition("assembly.windchime_bell_walkway","w",Vector2.ZERO,"",opts).has("error"),"reject wave "+str(opts))
	for placement: Array in [["beam",1040,268],["weight",1498,330],["press",1680,410],["growth",1378,354]]:
		var invalid := doc.duplicate(true)
		invalid.entities.beam.properties.rotation_mode = "contact_flip"
		invalid.entities.merge(WorldElementCatalog.instantiate_definition("platform.solid","obstacle",Vector2(placement[1],placement[2])).entities)
		invalid.entities.obstacle.properties.rect = [placement[1],placement[2],8,8]
		var result := WorldRoomDocument.instantiate(invalid)
		check(result.has("error") and "mechanism_sweep" in str(result.get("error")),"whole envelope catches fixed obstacle "+placement[0])
		if result.has("room"): result.room.free()
	var extended := WorldElementCatalog.instantiate_definition("assembly.windchime_bell_walkway","custom",Vector2(3250,200),"gear_city",{"members_order":["first","next","last","extra"],"member_offsets":{"extra":[540,96]}})
	check(not extended.has("error") and extended.entities.has("custom/extra"),"custom ordered members expanded")
	if not extended.has("error"):
		doc.entities.merge(extended.entities)
		var model := WorldRoomDocument.instantiate(doc)
		check(model.has("room"),"custom members load " + str(model.get("error","")))
		if model.has("room"):
			var packed := PackedScene.new()
			check(packed.pack(model.room)==OK,"pack custom group")
			model.room.free()
			var encoded := WorldRoomDocument.extract(packed)
			check(encoded.entities["custom/drive"].properties.members_order[3]=="custom/extra","stable references survive packing")
			check(encoded.entities["custom/extra"].assembly_definition_id=="assembly.windchime_bell_walkway","source survives packing")

func check_simple() -> void:
	var beam: WorldRotatingBeam = nodes.beam
	emit(beam,"toggle",null)
	check(not beam.element_can_receive("toggle",null),"busy step rejects duplicate")
	await ticks(50)
	check(beam.pose==1 and is_equal_approx(beam.angle,90),"two-pose step reaches vertical")
	emit(beam,"set_pose",0)
	await ticks(50)
	check(beam.result_at_terminal("lower_beam"),"lower beam terminal")
	beam.rotation_mode="indexed"; beam.angles_deg=[0.,60.,180.]
	beam.rotation_direction="counterclockwise"
	emit(beam,"toggle",null)
	await ticks(50)
	check(beam.pose==1 and is_equal_approx(beam.angle,-300),"counterclockwise indexed")
	emit(beam,"set_pose",2)
	await ticks(50)
	emit(beam,"toggle",null)
	await ticks(50)
	check(beam.pose==0,"indexed wraps")
	beam.rotation_mode="continuous"
	var at := beam.angle
	beam.set_equipment_time(0)
	await ticks(6)
	check(beam.angle==at,"continuous time stop")
	beam.set_equipment_time(1)
	await ticks(6)
	check(beam.angle < at,"continuous counterclockwise")
	emit(beam,"set_active",false)
	at = beam.angle
	await ticks(4)
	check(beam.angle==at,"continuous pause")
	beam.rotation_mode="load_tilt"; beam.running=true
	beam.place_angle(0)
	session.player.reset_at(beam.global_position+Vector2(52,-beam.beam_thickness/2-18))
	await ticks(24)
	check(beam.load_side=="right" and beam.angle>0,"real player's weight tilts right")
	session.player.reset_at(Vector2(160,494))
	await ticks(90)
	check(is_zero_approx(beam.angle),"empty tilt returns to rest")
	beam.rotation_mode="contact_flip";beam.stage="safe";beam.pose=0
	session.player.reset_at(beam.global_position+Vector2(30,-28))
	await ticks(12)
	check(beam.stage=="warning","actual landing arms flip")
	session.player.reset_at(Vector2(160,494))
	check(shot(beam,1) and beam.stage=="safe","shot cancels warning")
	session.player.reset_at(beam.global_position+Vector2(30,-28))
	await ticks(8)
	session.player.reset_at(Vector2(160,494))
	await ticks(85)
	check(beam.stage=="danger" and is_equal_approx(beam.angle,180),"unloaded flip continues to danger")
	check(shot(beam,2) and beam.stage=="returning","danger hit reverses")
	check(not shot(beam,2),"flip packet deduplicated")
	await ticks(32)
	check(beam.stage=="safe" and is_zero_approx(beam.angle),"flip returns safe")
	snap(beam)
	var growth: WorldExtendingTerrain = nodes.growth
	var original := growth.length_now
	check(shot(growth,3) and shot(growth,4) and not shot(growth,3),"growth shot receipts")
	await ticks(45)
	check(is_equal_approx(growth.length_now,original+64) and growth.body.position==Vector2.ZERO,"centered growth")
	await ticks(150)
	check(is_equal_approx(growth.length_now,original),"growth retracts")
	growth.growth_mode="rooted";growth.axis=Vector2.UP
	growth.install_length(original)
	check(shot(growth,5),"root growth")
	await ticks(25)
	check(is_equal_approx(growth.body.position.y,-growth.length_now/2),"root remains fixed")
	snap(growth)
	var weight: WorldFallingWeight = nodes.weight
	check(weight.pressure_bounds()==Rect2(),"suspended weight exerts no pressure")
	emit(weight,"release",null)
	await ticks(10)
	check(weight.phase=="warning" and weight.body.position==Vector2.ZERO,"weight warns")
	await ticks(70)
	check(weight.result_at_terminal("settle_block"),"weight reached supported landing " + str(weight.body.position))
	check(weight.pressure_bounds().has_area(),"settled weight qualifies")
	snap(weight)
	var press: WorldCyclicPress = nodes.press
	check(is_equal_approx(press.cycle(),4.15),"press derived period")
	press.set_equipment_time(0)
	var clock := press.clock
	await ticks(12)
	check(press.clock==clock and press.danger.enabled,"time stop leaves teeth dangerous")
	press.set_equipment_time(1)
	var phases := {}
	for i: int in 265:
		phases[press.phase] = true
		await physics_frame
	check(phases.size()==5,"complete pressure head cycle")
	snap(press)
	var crate: WorldPushCrate = nodes.crate
	check(crate.pressure_bounds().has_area(),"weight-marked grounded crate")
	session.player.reset_at(crate.global_position+crate.body.position+Vector2(-48,14))
	session.controller.router.set_move_axis(1)
	await ticks(50)
	session.controller.router.set_move_axis(0)
	check(crate.body.position.x>15,"character pushes grounded crate")
	var stopped := crate.body.position.x
	await ticks(20)
	check(is_equal_approx(crate.body.position.x,stopped),"crate does not coast")
	snap(crate)
func check_groups() -> void:
	var wave: WorldSequenceWave = nodes["walkway/drive"]
	check(is_equal_approx(wave.total_duration(),3.15),"wave total from members and stages")
	session.player.reset_at(Vector2(160,494))
	await ticks(8)
	session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(25)
	check(wave.running,"formal shot starts wave")
	check(not wave.element_can_receive("trigger",false),"busy wave ignores retrigger")
	wave.set_equipment_time(0)
	var at := wave.elapsed
	await ticks(8)
	check(wave.elapsed==at,"shared wave time stop")
	wave.set_equipment_time(1)
	await ticks(55)
	check(nodes["walkway/board_0"].angle < nodes["walkway/board_2"].angle,"ordered boards advance independently in same phase")
	await ticks(180)
	check(not wave.running and wave.accepted and is_equal_approx(nodes["walkway/board_2"].angle,90),"wave ends folded")
	session.player.reset_at(Vector2(160,494))
	await ticks(5)
	session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(30)
	check(wave.running and not wave.accepted,"opposite output starts second wave")
	var flip: WorldRouteSwitch = nodes["flip/drive"]
	check(is_equal_approx(nodes["flip/bridge_a"].angle,0) and is_equal_approx(nodes["flip/bridge_b"].angle,90),"initial complementary bridge")
	# A direct request with no accepted source packet may prepare but never commit.
	check(not flip.element_can_receive("set_active",true),"route warning before acceptance")
	await ticks(25)
	check(flip.phase=="ready" and flip.element_can_receive("set_active",true),"safe full group ready")
	flip.element_restore(flip.element_propose("set_active",true))
	await ticks(12)
	check(nodes["flip/bridge_a"].angle>0 and absf(nodes["flip/bridge_a"].angle+nodes["flip/bridge_b"].angle-90)<.1,"bridges share phase")
	await ticks(24)
	check(flip.phase=="idle" and nodes["flip/bridge_a"].pose==1 and nodes["flip/bridge_b"].pose==0,"both new poses")
	var routes: WorldRouteSwitch = nodes["routes/driver"]
	var gate_a: WorldElementGate = nodes["routes/gate_a"]
	var gate_b: WorldElementGate = nodes["routes/gate_b"]
	check(gate_a.active and not gate_b.active,"two distinct gate roots")
	session.player.reset_at(gate_a.to_global(gate_a.bounds.get_center()))
	check(not routes.element_can_receive("set_active",true),"arm gate warning")
	await ticks(18)
	check(not routes.element_can_receive("set_active",true) and gate_a.active and not gate_b.active,"occupied route preserves both gates")
	session.player.reset_at(Vector2(160,494))
	await ticks(3)
	emit(routes,"set_active",true)
	check(not gate_a.active and gate_b.active,"complementary targets commit together")
	snap(routes)
	snap(wave)

func attach_linked_beams(doc: Dictionary) -> void:
	for entry: Array in [["wheel",Vector2(3400,240)],["wheel_slave",Vector2(3160,245)],["dial",Vector2(3600,340)],["dial_slave",Vector2(3250,422)]]:
		doc.entities.merge(WorldElementCatalog.instantiate_definition("platform.rotating_beam",entry[0],entry[1]).entities)
		doc.entities[entry[0]].properties.rotation_mode = "continuous" if entry[0].begins_with("wheel") else "indexed"
	doc.entities.wheel_slave.properties.merge({"drive_id":"wheel","initial_angle_deg":120,"angular_speed_deg":160},true)
	doc.entities.dial_slave.properties.merge({"drive_id":"dial","rotate_s":1.9},true)
	doc.entities.dial.properties.angles_deg = [0,90,150]
	doc.entities.gear_bell.properties.links.append({"target":"wheel_slave","input":"set_active","output":"active"})

func verify_linked_beams() -> void:
	var wheel: WorldRotatingBeam = nodes.wheel
	var linked: WorldRotatingBeam = nodes.wheel_slave
	check(wheel.running and linked.running and wheel.angle>0 and wheel.angle==linked.angle and wheel.motion_clock==linked.motion_clock,"continuous follower uses single angle and accepted start")
	var dial: WorldRotatingBeam = nodes.dial
	var hand: WorldRotatingBeam = nodes.dial_slave
	# The follower reaches down to the floor at 90 degrees. A grounded player
	# blocks the complete indexed turn from the far end of that beam only.
	session.player.reset_at(Vector2(3264,494))
	await ticks(5)
	check(shot(hand,9821),"indexed axle routes shot to independent driving beam")
	await ticks(25)
	check(dial.blocked and hand.blocked and is_zero_approx(dial.angle) and hand.angle==dial.angle,"occupied follower blocks both moving solids")
	session.player.reset_at(Vector2(3100,494))
	await ticks(32)
	check(dial.pose==1 and hand.pose==1 and dial.angle==hand.angle and dial.stage=="idle","one accepted angle change resumes at both axle positions")
	check(shot(dial,9822) and shot(hand,9822),"one packet may touch both hit parts")
	await ticks(50)
	check(dial.pose==2 and hand.pose==2 and is_equal_approx(hand.angle,150),"root owns pose table and packet once despite follower defaults")

func nested_document() -> Dictionary:
	var doc := Foundry.layout()
	for group: String in ["routes","flip","walkway"]:
		var bell := group+"/bell"
		var first := group+"_condition"
		var last := group+"_output"
		var original: Array = doc.entities[bell].properties.links
		doc.entities[bell].properties.links = []
		for id: String in [first,last]:
			var result := WorldElementCatalog.instantiate_definition("internal.bool_condition",id,Vector2(120,160))
			doc.entities.merge(result.entities)
		doc.entities[first].properties.sources = [{"source_id":bell,"output":"active"}]
		doc.entities[first].properties.invert = group != "flip"
		doc.entities[last].properties.sources = [{"source_id":first,"output":"active"}]
		doc.entities[last].properties.links = original
	doc.entities["routes/bell"].properties.access_points = [[2926,420]]
	doc.entities["flip/bell"].properties.access_points = [[2130,420]]
	doc.entities["flip/bridge_a"].properties.position = [2100,375]
	for entry: Array in [["platform.moving","gear_rail",Vector2(3800,265)],["hazard.gear","slave",Vector2(3800,130)],["switch.shot","gear_bell",Vector2(3550,494)]]:
		var result := WorldElementCatalog.instantiate_definition(entry[0],entry[1],entry[2])
		doc.entities.merge(result.entities)
	doc.entities.slave.properties.drive_id = "gear_rail"
	doc.entities.gear_bell.properties.merge({"repeat_enabled":true,"state_scope":"attempt","links":[{"target":"slave","input":"set_active","output":"active"}]},true)
	var mixed := WorldElementCatalog.instantiate_definition("assembly.dual_route_switch","mixed",Vector2(300,220),"gear_city",
		{"target_bindings":{"gate_b":{"definition":"platform.rotating_beam","input":"set_pose","active":1,"inactive":0}}})
	doc.entities.merge(mixed.entities)
	doc.entities["mixed/bell"].properties.access_points = [[300,420]]
	doc.entities["mixed/gate_b"].properties.position = [560,160]
	doc.entities["mixed/gate_b"].properties.rotate_s = 1.1
	doc.entities.merge(WorldElementCatalog.instantiate_definition("platform.rotating_beam","spike_board",Vector2(945,180)).entities)
	doc.entities.spike_board.properties.merge({"rotation_mode":"contact_flip","initial_pose":1,"danger_hold_s":100.0},true)
	doc.entities.merge(WorldElementCatalog.instantiate_definition("terrain.extending","elevator_root",Vector2(1160,422)).entities)
	doc.entities.elevator_root.properties.merge({"growth_mode":"rooted","growth_axis":[0,-1]},true)
	attach_linked_beams(doc)
	return doc

func fire_from(at: Vector2,direction: Vector2) -> void:
	session.player.reset_at(at)
	await ticks(5)
	session.controller.router.request_action(&"shoot_release",direction)

func verify_nested_controls() -> void:
	var doc := nested_document()
	for pair: Array in [["wheel","dial_slave"],["dial","dial_slave"],["wheel_slave","dial"]]:
		var invalid_drive := doc.duplicate(true)
		invalid_drive.entities[pair[0]].properties.drive_id = pair[1]
		var result := WorldRoomDocument.instantiate(invalid_drive)
		check(result.has("error"),"reject mismatched or recursive angular source "+str(pair))
		if result.has("room"): result.room.free()
	var invalid := doc.duplicate(true)
	invalid.entities.gear_bell.properties.links.append({"target":"gear_rail","input":"set_active","output":"active"})
	var refused := WorldRoomDocument.instantiate(invalid)
	check(refused.has("error"),"double writer through gear rejected on authoring")
	if refused.has("room"): refused.room.free()
	session = OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(doc)
	check(error.is_empty(),"open nested control fixture: "+error)
	if not error.is_empty():
		session.free()
		return
	nodes = session.room.element_runtime.nodes
	await ticks(8)
	var routes: WorldRouteSwitch = nodes["routes/driver"]
	var flip: WorldRouteSwitch = nodes["flip/drive"]
	var wave: WorldSequenceWave = nodes["walkway/drive"]
	var gate_b: WorldElementGate = nodes["routes/gate_b"]
	var bell: WorldElementSwitch = nodes["routes/bell"]
	check(routes.phase=="idle" and routes.accepted and gate_b.active and not nodes["routes/gate_a"].active,"inverted initial route hydrated through both conditions")
	check(wave.accepted and not wave.running and bell.open_count==0,"inverted trigger baseline hydrates quietly")
	var gate_x := gate_b.to_global(gate_b.bounds.get_center()).x
	await fire_from(Vector2(gate_x,494),Vector2.UP)
	await ticks(35)
	check(routes.holds_request(bell.element_id) and not bell.is_open and routes.blocked and nodes.routes_output.active and gate_b.active,"occupied route holds source, both conditions and gates")
	var receipt: String = bell.pending_commit.get("id","")
	await fire_from(Vector2(gate_x,494),Vector2.UP)
	await ticks(25)
	check(not receipt.is_empty() and bell.pending_commit.get("id","")==receipt and routes.blocked,"repeated shot preserves first live request")
	session.player.reset_at(Vector2(3200,494))
	await ticks(10)
	check(bell.open_count==1 and bell.is_open and not nodes.routes_output.active and not routes.accepted and not gate_b.active,"release atomically commits nested source and gates once")
	var flip_bell: WorldElementSwitch = nodes["flip/bell"]
	await fire_from(Vector2(2130,494),Vector2.UP)
	await ticks(32)
	check(flip.holds_request(flip_bell.element_id) and flip.blocked and not nodes.flip_output.active and not flip.accepted,"P02 obstructed full sweep holds both boards")
	flip_bell.cancel_pending()
	await ticks(3)
	check(flip.phase=="idle" and not flip.blocked and flip_bell.open_count==0,"cancelled nested request cannot commit")
	await fire_from(Vector2(2130,494),Vector2.UP)
	await ticks(30)
	session.player.reset_at(Vector2(1950,494))
	await ticks(50)
	check(flip_bell.open_count==1 and nodes.flip_output.active and flip.accepted and nodes["flip/bridge_a"].pose==1 and nodes["flip/bridge_b"].pose==0,"P02 retries original root after full sweep clears")
	await fire_from(Vector2(160,494),Vector2.RIGHT)
	await ticks(28)
	var wave_bell: WorldElementSwitch = nodes["walkway/bell"]
	check(wave.running and not wave.accepted and wave_bell.open_count==1,"first false edge after inverted hydration launches P04")
	await fire_from(Vector2(160,494),Vector2.RIGHT)
	await ticks(195)
	check(not wave.running and not wave.accepted and wave_bell.open_count==1 and not nodes.walkway_output.active,"P04 rejects busy repeat with no deferred extra wave")
	await fire_from(Vector2(160,494),Vector2.RIGHT)
	await ticks(25)
	check(wave.running and wave.accepted and wave_bell.open_count==2,"new shot after wave finishes accepted")
	var rail: WorldMovingPlatform = nodes.gear_rail
	check(not rail.motion_running and is_zero_approx(rail.motion_clock),"gear input hydration reaches real motion owner")
	await fire_from(Vector2(3450,494),Vector2.RIGHT)
	await ticks(32)
	check(rail.motion_running and rail.motion_clock>0 and nodes.slave.hazard.clock_source==rail,"gear boolean starts its single upstream motion clock")
	await verify_linked_beams()
	await fire_from(Vector2(300,494),Vector2.UP)
	await ticks(32)
	var mixed: WorldRouteSwitch = nodes["mixed/driver"]
	var dial: WorldRotatingBeam = nodes["mixed/gate_b"]
	var mixed_bell: WorldElementSwitch = nodes["mixed/bell"]
	check(mixed.phase=="executing" and mixed.accepted and mixed_bell.open_count==1 and not nodes["mixed/gate_a"].active and dial.stage!="idle","mixed gate and finite rotation accept at the same time")
	await fire_from(Vector2(300,494),Vector2.UP)
	await ticks(100)
	check(mixed.phase=="idle" and dial.pose==1 and mixed.accepted and mixed_bell.open_count==1,"heterogeneous route waits for actual rotation and discards busy repeat")
	await verify_enchantment()
	await verify_solid_contacts()
	check(await session.audio_service.shutdown(),"nested fixture releases audio")
	session.free()

func verify_solid_contacts() -> void:
	var growth: WorldExtendingTerrain = nodes.elevator_root
	session.player.reset_at(growth.global_position+Vector2.UP*(growth.length_now+18))
	await ticks(10)
	var at := session.player.global_position.y
	check(shot(growth,9812),"root receives growth while supporting player")
	await ticks(20)
	check(is_equal_approx(growth.length_now,growth.initial_length+growth.growth_per_hit) and absf(at-session.player.global_position.y-growth.growth_per_hit)<1 and session.player.is_on_floor(),"actual moving root tip carries full player body")
	var beam: WorldRotatingBeam = nodes.beam
	await fire_from(Vector2(1040,494),Vector2.UP)
	await ticks(54)
	check(beam.pose==1,"actual projectile from below strikes G08 pivot")
	var weight: WorldFallingWeight = nodes.weight
	session.player.reset_at(weight.hit_part.global_position+Vector2.LEFT*80)
	session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(90)
	check(weight.phase=="settled" and weight.hit_part.collision_layer==0,"actual projectile releases marked pin and pin disappears after landing")
	var hazard: WorldRotatingBeam = nodes.spike_board
	var health := session.controller.actor_resources.health
	var before := health.current
	hazard.set_equipment_time(0)
	session.player.reset_at(hazard.global_position+Vector2.UP*(hazard.beam_thickness/2+18))
	await ticks(12)
	check(hazard.stage=="danger" and is_equal_approx(hazard.angle,180) and health.current<before,"frozen rotating back face deals official environment damage")

func verify_enchantment() -> void:
	var equipment := session.equipment
	var flip: WorldRouteSwitch = nodes["flip/drive"]
	var board_a: WorldRotatingBeam = nodes["flip/bridge_a"]
	var board_b: WorldRotatingBeam = nodes["flip/bridge_b"]
	var id := 9801
	equipment.primary_packet_started(id,Vector2.RIGHT)
	equipment.packets[id].levels={"105":1}
	equipment.packets[id].enchantment=true
	equipment.mechanism_hit(board_a,id)
	equipment.mechanism_hit(board_b,id)
	equipment.mechanism_hit(nodes["routes/driver"],id)
	check(equipment.fx.time.keys()==[flip.element_id] and equipment.packets[id].seen.keys()==["time:"+flip.element_id],"two board hits stop one owner; route signal coordinator immune")
	await ticks(3)
	await fire_from(Vector2(2130,494),Vector2.UP)
	await ticks(22)
	session.player.reset_at(Vector2(1950,494))
	check(flip.phase=="warning","frozen driving clock accepts route intent and preserves warning")
	var at := flip.motion_clock
	await ticks(16)
	check(flip.motion_clock==at and flip.scale_time==0 and board_a.scale_time==1 and board_b.scale_time==1,"time core only scales owner")
	await ticks(202)
	check(flip.scale_time==1 and flip.motion_clock>at and equipment.fx.time.is_empty(),"shared clock resumes when equipment duration elapses")

func demonstrate() -> void:
	var camera := session.player.get_viewport().get_camera_2d()
	camera.zoom = Vector2(1.4,1.4)
	await ticks(26)
	session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(194)
	session.player.reset_at(Vector2(1040,494))
	await ticks(24)
	session.controller.router.request_action(&"shoot_release",Vector2.UP)
	await ticks(72)
	session.player.reset_at(Vector2(1280,494))
	await ticks(18)
	session.controller.router.request_action(&"shoot_release",Vector2.UP)
	await ticks(35)
	session.controller.router.request_action(&"shoot_release",Vector2.UP)
	await ticks(116)
	session.player.reset_at(Vector2(1400,250))
	session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(65)
	session.player.reset_at(Vector2(1828,494))
	await ticks(12)
	session.controller.router.set_move_axis(1)
	await ticks(62)
	session.controller.router.set_move_axis(0)
	await ticks(24)

func run() -> void:
	check_contracts()
	session = OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(Foundry.layout())
	check(error.is_empty(),"open real foundry: "+error)
	if error.is_empty():
		nodes = session.room.element_runtime.nodes
		if "--film" in OS.get_cmdline_user_args(): await demonstrate()
		else:
			await check_groups()
			await check_simple()
		check(await session.audio_service.shutdown(),"audio released")
	session.free()
	if "--film" not in OS.get_cmdline_user_args(): await verify_nested_controls()
	print("BEAM LIBRARY failures=",failures," checks=",checks)
	quit(1 if failures else 0)
