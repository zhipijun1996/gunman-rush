extends SceneTree

var failures := 0
var checks := 0

class Store extends WorldSaveService:
	var payload := {}
	var revision := 0
	var writable := true
	func commit(candidate: Dictionary, next: int) -> bool:
		if not writable: return false
		payload = candidate.duplicate(true)
		revision = next
		return true
	func load_profile() -> Dictionary:
		return {"accepted":true,"payload":payload.duplicate(true),"revision":revision}

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)

func _initialize() -> void:
	run.call_deferred()

func ticks(n: int) -> void:
	for i: int in n: await physics_frame

func base() -> Dictionary:
	var doc := WorldRoomDocument.read("res://tests/assembly_room.json")
	doc.entities.erase("patrol")
	doc.entities.erase("gate")
	doc.entities.erase("bell")
	doc.actions = [{"id":"repair","room_id":doc.room_id,"section_id":"main","grants":["opened"]}]
	return doc

func put(doc: Dictionary, id: String,kind: String, at: Vector2, settings := {}) -> void:
	var made := WorldElementCatalog.instantiate_definition(kind,id,at)
	doc.entities.merge(made.entities)
	doc.entities[id].properties.merge(settings,true)

func open(doc: Dictionary,store: WorldSaveService = null) -> OrdinaryRoomSession:
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(doc,store)
	check(error.is_empty(),"ordinary session opens "+error)
	return session

func drain_audio(session: OrdinaryRoomSession) -> void:
	if session.audio_service != null:
		check(await session.audio_service.shutdown(),"room audio playback released before disposal")

func finish(session: OrdinaryRoomSession) -> void:
	await drain_audio(session)
	session.free()

func fire(session: OrdinaryRoomSession) -> void:
	session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(42)

func gates() -> void:
	for dir: String in ["right","left","up","down"]:
		var doc := base()
		doc.entities.floor.properties.rect = [0,520,960,40]
		put(doc,"gate","gate.masonry",Vector2(352,256),{"gate_mode":"directional","pass_direction":dir,"state_scope":"attempt","close_delay":0.12})
		var session := open(doc)
		if session.room == null: await finish(session); continue
		var gate: WorldElementGate = session.room.element_runtime.nodes.gate
		var axis := gate.direction_axis()
		var extent := gate.bounds.size.dot(axis.abs())/2
		var center := gate.bounds.get_center()
		var margin := Vector2(12,18).dot(axis.abs())+2
		session.player.reset_at(center+axis*(extent+margin))
		await ticks(2)
		check(not gate.active,dir+" opposite side locked")
		session.player.reset_at(center-axis*(extent+margin))
		await ticks(3)
		check(gate.active and gate.body.collision_layer == 0,dir+" entry opens")
		session.player.reset_at(center)
		await ticks(4)
		check(gate.active,dir+" stays open while occupied")
		session.player.reset_at(center+axis*(extent+60))
		await ticks(3)
		check(gate.active,dir+" delay")
		await ticks(9)
		check(not gate.active and gate.body.collision_layer == 1,dir+" reclosed")
		await finish(session)

func logic() -> void:
	var doc := base()
	for key: String in ["a","b"]:
		put(doc,key,"switch.shot",Vector2(272,360) if key=="a" else Vector2(420,360),{"state_scope":"attempt","repeat_enabled":true})
	put(doc,"logic","internal.bool_condition",Vector2.ZERO,{"sources":[{"source_id":"a","output":"active"},{"source_id":"b","output":"active"}],"links":[{"output":"active","target":"gate","input":"set_active"}]})
	put(doc,"gate","gate.masonry",Vector2(600,256),{"state_scope":"attempt"})
	var invalid := doc.duplicate(true)
	invalid.entities.logic.properties.sources[0].source_id = "logic"
	check(WorldRoomDocument.instantiate(invalid).has("error"),"condition cycle rejects room")
	var session := open(doc)
	if session.room == null: await finish(session); return
	var gate: WorldElementGate = session.room.element_runtime.nodes.gate
	await ticks(4)
	await fire(session)
	check(session.room.element_runtime.nodes.a.is_open and not gate.active,"all awaits second source")
	session.player.reset_at(Vector2(335,366))
	await ticks(4)
	await fire(session)
	check(gate.active,"second shot opens aggregate gate")
	await finish(session)
	doc.entities.logic.properties.operation = "any"
	doc.entities.logic.properties.invert = true
	session = open(doc)
	if session.room != null:
		check(session.room.element_runtime.nodes.gate.active,"inverted any initialized before gameplay")
		await ticks(4)
		await fire(session)
		check(not session.room.element_runtime.nodes.gate.active,"inverted any closes")
	await finish(session)

func world_results() -> void:
	for kind: String in ["open_gate","lower_beam","settle_block"]:
		var doc := base()
		doc.entities.floor.properties.rect = [0,384,400,156]
		var options := {"result_kind":kind,"action_id":"repair"}
		var members := WorldElementCatalog.instantiate_definition("assembly.one_shot_route","bridge",Vector2(368,360),"",options)
		doc.entities.merge(members.entities)
		if kind == "settle_block":
			doc.entities.support = {"id":"support","definition_id":"platform.solid","definition_version":1,"properties":{"rect":[422,520,200,50]}}
		var missing := doc.duplicate(true)
		missing.actions = []
		check(WorldRoomDocument.instantiate(missing).has("error"),"missing action rejected")
		var locked := doc.duplicate(true)
		locked.actions[0].requires = [["earned_key"]]
		var restricted := open(locked)
		if restricted.room != null:
			await ticks(3)
			await fire(restricted)
			await ticks(110)
			var coordinator: WorldPermanentResult = restricted.room.element_runtime.nodes["bridge/coordinator"]
			check(coordinator.phase=="ready" and restricted.state.value.receipts.is_empty() and not coordinator.target.result_at_terminal(kind),kind+" unmet world requirement keeps passage locked")
		await finish(restricted)
		var store := Store.new()
		var session := open(doc,store)
		if session.room == null: await finish(session); continue
		check(session.room.interaction_hosts.is_empty(),"delegated action has no independent player prompt")
		if kind != "open_gate":
			var coordinator: WorldPermanentResult = session.room.element_runtime.nodes["bridge/coordinator"]
			var member: MechanismSolid = coordinator.target
			check(not member.mechanism_shot({"collider":member.hit_part,"packet_id":"direct-hit"}),kind+" result rejects direct trigger")
			await ticks(4)
			session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
			for i: int in 80:
				await ticks(1)
				if coordinator.phase == "executing": break
			check(coordinator.phase == "executing" and session.state.value.receipts.is_empty(),kind+" movement starts before transaction")
			session.room.element_runtime.reset_section("main")
			await ticks(110)
			check(coordinator.phase == "ready" and not coordinator.target.result_at_terminal(kind) and not session.state.value.receipts.has("repair"),kind+" interruption discards pending transaction")
			session.player.reset_at(Vector2(160,366))
		store.writable = false
		await ticks(4)
		await fire(session)
		await ticks(130)
		var result: Node = session.room.element_runtime.nodes["bridge/result"]
		check(not store.payload.has("receipts") and not result.result_at_terminal(kind),kind+" rejected write rolls back")
		store.writable = true
		session.player.reset_at(Vector2(160,366))
		await ticks(6)
		await fire(session)
		await ticks(140)
		check(session.state.value.receipts.has("repair") and result.result_at_terminal(kind),kind+" receipt and terminal")
		session.room.element_runtime.reset_section("main")
		check(result.result_at_terminal(kind),kind+" terminal survives challenge recovery")
		var adjacent := base()
		adjacent.room_id = "adjacent_room"
		adjacent.actions = []
		var next := OrdinaryRoomSession.new()
		root.add_child(next)
		# A successful handoff takes ownership and queues its source for deletion.
		# Wait for that source's audio mixer before giving it to open().
		await drain_audio(session)
		var transition := next.open(adjacent,null,session)
		check(transition.is_empty(),kind+" exit via ordinary room transition "+transition)
		if transition.is_empty():
			await ticks(2)
			session = OrdinaryRoomSession.new()
			root.add_child(session)
			await drain_audio(next)
			transition = session.open(doc,null,next)
			check(transition.is_empty() and session.state.value.receipts.has("repair") and session.room.element_runtime.nodes["bridge/result"].result_at_terminal(kind),kind+" return restores physical route "+transition)
			if not transition.is_empty(): await finish(next)
		else:
			await finish(next)
		await finish(session)
		session = open(doc,store)
		if session.room != null:
			check(session.state.value.receipts.has("repair") and session.room.element_runtime.nodes["bridge/result"].result_at_terminal(kind),kind+" restored without replay")
		await finish(session)

func services() -> void:
	var doc := base()
	put(doc,"retry","recovery.anchor",Vector2(120,300))
	doc.entities.retry.properties.point = [160,366]
	put(doc,"sign","interaction.sign", Vector2(160,348),{"text":"门后可返程"})
	put(doc,"lever","interaction.return_gate",Vector2(350,366),{"action_id":"repair","closed_panels":[[0,-96,32,96]],"return_steps":[[64,-16,64,16]]})
	var store := Store.new()
	var session := open(doc,store)
	if session.room == null: await finish(session); return
	await ticks(5)
	check(not session.recovery.selected.is_empty(),"register actual entry anchor")
	session._interact()
	check(session.sign_reader.reading and session.sign_reader.message.text=="门后可返程","read sign in room")
	session.sign_reader.close()
	check(not paused and session.state.value.receipts.is_empty(),"reading closes without reward")
	var lever: WorldReturnLatch = session.room.interaction_hosts[0]
	check(lever.closed_bodies[0].collision_layer == 1 and lever.opened_bodies[0].collision_layer == 0,"return gate closed initially")
	session.player.reset_at(Vector2(389,359))
	session._interact()
	check(not session.state.value.receipts.has("repair"),"return gate cannot be operated from behind the closed panel")
	session.player.reset_at(Vector2(330,366))
	session._interact()
	await ticks(2)
	check(session.state.value.receipts.has("repair") and lever.closed_bodies[0].collision_layer == 0 and lever.opened_bodies[0].collision_layer == 1,"world receipt opens return gate and steps")
	session.policy.environment_return_requested.emit()
	check(session.player.position.distance_to(Vector2(160,366)) < 1,"environment return to actual entry side")
	await finish(session)
	session = open(doc,store)
	if session.room != null:
		lever = session.room.interaction_hosts[0]
		check(lever.closed_bodies[0].collision_layer == 0 and lever.opened_bodies[0].collision_layer == 1,"return steps and open panels survive reload")
	await finish(session)

func gears() -> void:
	var doc := base()
	put(doc,"wheel","hazard.gear",Vector2(600,230),{"period":4,"endpoint_dwell":1,"travel":[60,0]})
	put(doc,"arc","hazard.gear",Vector2(790,220),{"period":4,"path_mode":"arc","arc_angles_deg":[0,90],"arc_radius":50})
	var session := open(doc)
	if session.room == null: await finish(session); return
	var gear: WorldElementGear = session.room.element_runtime.nodes.wheel
	var arc: WorldElementGear = session.room.element_runtime.nodes.arc
	gear.element_restore({"active":true,"clock":1.1})
	await ticks(15)
	check(gear.hazard.wheel.position.is_equal_approx(Vector2(60,0)),"real teeth dwell at positive end")
	arc.element_restore({"active":false,"clock":1.0})
	await ticks(12)
	check(arc.hazard.wheel.position.distance_to(Vector2(0,50))<0.1,"arc paused at real radius and angle")
	gear.set_equipment_time(0.0)
	var stopped := gear.hazard.clock
	await ticks(15)
	check(is_equal_approx(stopped,gear.hazard.clock) and gear.hazard.wheel.visible,"time stop holds dangerous teeth")
	await finish(session)

func burst_bell() -> void:
	var doc := base()
	put(doc,"bell","switch.shot",Vector2(580,360),{"state_scope":"attempt","repeat_enabled":true,"access_points":[[236,360]]})
	var session := open(doc)
	if session.room == null: await finish(session); return
	var weapon := WeaponDefinition.new()
	weapon.id = &"triple_machine_gun"
	weapon.tier = 2
	weapon.mode = WeaponDefinition.Mode.MACHINE
	weapon.branch = &"machine_gun"
	weapon.rounds = 3
	var ability := session.controller.shoot_ability
	check(ability.equip(weapon),"equip the three-round burst through the formal weapon interface")
	var registrations: Array[Vector2i] = []
	ability.shot_fired.connect(func(_aim: Vector2, shot: int): registrations.append(Vector2i(ability.packet_id,shot)))
	var bell: WorldElementSwitch = session.room.element_runtime.nodes.bell
	await ticks(4)
	session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(6)
	check(bell.open_count == 1,"first real round reaches the remote bell")
	# The two later rounds travel to a different physical receiver of the same root.
	session.player.reset_at(Vector2(505,366))
	await ticks(36)
	check(registrations.size()==3 and registrations[0].x==registrations[2].x and registrations[0].y!=registrations[2].y,"one real machine-gun packet registers three different projectiles")
	check(bell.is_open and bell.open_count==1,"late rounds hitting the primary bell cannot toggle the same root a second time")
	await fire(session)
	check(registrations.size()==6 and registrations[0].x!=registrations[3].x and not bell.is_open and bell.open_count==2,"independent follow-up burst toggles once")
	await finish(session)

func bell_and_gear_enchantments() -> void:
	var doc := base()
	var at := Vector2(160,366)
	put(doc,"camp","recovery.station",at)
	for item: String in ["103","105"]:
		put(doc,"reward"+item,"equipment.reward",at,{"source_id":"equipment."+item})
	put(doc,"drive","platform.moving",Vector2(650,190),{"endpoint":[36,0],"period":5,"platform_size":[32,16]})
	put(doc,"wheel","hazard.gear",Vector2(378,356),{"drive_id":"drive","travel":[2,0]})
	put(doc,"peer","hazard.gear",Vector2(590,310),{"drive_id":"drive","travel":[30,0]})
	put(doc,"bell","switch.shot",Vector2(840,360),{"state_scope":"attempt","access_points":[[255,360]]})
	var session := open(doc,Store.new())
	if session.room == null: await finish(session); return
	await ticks(4)
	var nodes := session.room.element_runtime.nodes
	var drive: WorldMovingPlatform = nodes.drive
	var wheel: WorldElementGear = nodes.wheel
	var peer: WorldElementGear = nodes.peer
	var bell: WorldElementSwitch = nodes.bell
	for item: String in ["103","105"]:
		check(session.equipment_transaction("claim","equipment."+item,session.state.revision),"collect time core "+item)
	check(session.equipment_transaction("equip","103",session.state.revision),"equip time acceleration at station")
	session.equipment.activate_selected(Vector2.RIGHT)
	var energy := session.controller.combat_energy.current
	await fire(session)
	check(bell.open_count == 1 and bell.is_open,"remote real shot opens the shared root")
	check(not bell.receiver.grants_combat_energy and not bell.access_bodies[0].get_node("Damageable").grants_combat_energy and session.controller.combat_energy.current == energy and session.equipment.fx.time.is_empty(),"remote bell grants no combat energy or time target")
	await fire(session)
	check(not session.equipment.fx.time.has("wheel") and not session.equipment.fx.time.has("peer") and session.equipment.fx.time.has("drive"),"shot at moving teeth applies enchantment only to their driver")
	var before := drive.motion_clock
	await ticks(12)
	check(is_equal_approx(drive.motion_clock-before,12.0/60.0*1.5) and is_equal_approx(wheel.hazard.clock,drive.motion_clock) and is_equal_approx(peer.hazard.clock,drive.motion_clock),"accelerated shared clock advances exactly once for both followers")
	check(session.controller.combat_energy.current==energy,"shot at moving gear gives no combat energy")
	session.player.reset_at(at)
	await ticks(3)
	check(session.equipment_transaction("unequip","103",session.state.revision) and session.equipment_transaction("equip","105",session.state.revision),"exchange time cores at station")
	if not session.equipment.fx.enchanted: session.equipment.activate_selected(Vector2.RIGHT)
	await fire(session)
	before = drive.motion_clock
	var teeth_position := wheel.hazard.wheel.global_position
	var rotation := wheel.hazard.wheel.rotation
	await ticks(10)
	check(is_zero_approx(drive.equipment_time_scale) and is_equal_approx(drive.motion_clock,before) and is_equal_approx(wheel.hazard.wheel.rotation,rotation) and wheel.hazard.wheel.global_position.is_equal_approx(teeth_position),"real stop round freezes both rotation and physical teeth")
	var health := session.controller.actor_resources.health
	var hp := health.current
	session.player.reset_at(teeth_position)
	await ticks(4)
	check(health.current<hp and is_equal_approx(wheel.hazard.clock,before),"stopped follower still damages player on physical tooth contact")
	session.player.reset_at(at)
	await ticks(180)
	check(drive.motion_clock>before and is_equal_approx(wheel.hazard.clock,drive.motion_clock) and is_equal_approx(drive.equipment_time_scale,1),"expiration resumes shared motion at normal speed")
	await finish(session)

func authoring() -> void:
	var doc := base()
	var bad := doc.duplicate(true)
	put(bad,"notice","interaction.sign",Vector2(160,300),{"text":"示意","unsupported_radius":64})
	check(str(WorldRoomDocument.instantiate(bad).get("error","")).contains("unsupported_radius"),"unknown array mechanism fields return the field name")
	var placed := WorldElementCatalog.instantiate_definition("assembly.windchime_windmill","mill",Vector2(350,220),"",{"angle_offsets_deg":[0,120,240]})
	doc.entities.merge(placed.entities)
	var origin := doc.duplicate(true)
	var edited := WorldRoomGroups.copy_group(doc,"mill","new",Vector2(96,4))
	check(not edited.has("error") and doc == origin,"copy leaves original windmill intact")
	if edited.has("error"): return
	var refs: Dictionary = edited.entities["new/drive"].properties.carrier_ids
	check(refs.size()==3 and refs.carrier_2 == "new/carrier_2" and edited.entities["new/carrier_0"].properties.drive_id=="new/drive","copy rewrites dictionary and scalar references")
	check(edited.entities["new/bell"].properties.links[0].target=="new/drive","copy rewrites signal target")
	var moved := WorldRoomGroups.move_group(edited,"new",Vector2(20,-16))
	check(not moved.has("error") and FixedWorldProvider.point(moved.entities["new/drive"].properties.position) == FixedWorldProvider.point(origin.entities["mill/drive"].properties.position)+Vector2(116,-12),"move preserves offsets")
	var loose := WorldRoomGroups.detach_group(moved,"new")
	check(not loose.has("error") and not loose.entities["new/drive"].has("assembly_id") and loose.entities["new/carrier_2"].properties.drive_id=="new/drive","detaching preserves operational links")
	doc.entities.merge(WorldElementCatalog.instantiate_definition("assembly.one_shot_route","shortcut",Vector2(500,260),"",{"action_id":"repair"}).entities)
	check(WorldRoomGroups.copy_group(doc,"shortcut","second",Vector2.ZERO).has("error"),"external action cannot be copied implicitly")
	doc.actions.append({"id":"other","room_id":doc.room_id,"section_id":"main","grants":["other_path"]})
	edited = WorldRoomGroups.copy_group(doc,"shortcut","second",Vector2(28,0),{"action:repair":"other"})
	check(not edited.has("error") and edited.entities["second/action"].properties.action_id == "other" and edited.entities["second/action"].properties.action_owner_id == "second/coordinator","copied action has independent host and receipt")

func run() -> void:
	await authoring()
	await gates()
	await logic()
	await services()
	await gears()
	await burst_bell()
	await bell_and_gear_enchantments()
	await world_results()
	print("MECHANISM INTEGRATION failures=",failures," checks=",checks)
	quit(1 if failures else 0)
