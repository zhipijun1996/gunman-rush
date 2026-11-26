extends SceneTree

const DEMO := "res://tests/hazard_library_demo.json"
var failures := 0
var checked := 0

func _initialize() -> void:
	if "showcase" in OS.get_cmdline_user_args():
		showcase.call_deferred()
	else:
		run.call_deferred()

func check(ok: bool,label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("FAIL HAZARD ",label)

func ticks(n: int) -> void:
	for i: int in n: await physics_frame

func fixture() -> Dictionary:
	return WorldRoomDocument.read(DEMO)

func invalid(id: String,change: Dictionary) -> void:
	var doc := fixture()
	doc.entities[id].properties.merge(change,true)
	var result := WorldRoomDocument.instantiate(doc)
	check(result.has("error"),"reject "+id+" "+str(change))
	if result.has("room"): result.room.free()

func configuration() -> void:
	for change: Dictionary in [{"shield_radius":14},{"protected_sources":[]},{"protected_sources":["missing"]},{"protected_sources":["plate"]},{"protected_sources":["heat","heat"]},{"expiry_warning_s":3}]:
		invalid("shelter",change)
	invalid("heat",{"hazard_profile":"contact"})
	invalid("heat",{"hazard_profile":"unknown"})
	invalid("heat",{"active_s":0})
	invalid("heat",{"start_phase01":1})
	invalid("step",{"trigger_mode":"wall_attach","one_way":true})
	invalid("blink",{"jump_types":["ground","ground"]})
	invalid("blink",{"jump_types":[]})
	invalid("teeth",{"extend_s":0})
	invalid("teeth",{"start_phase01":1})
	invalid("plate",{"release_hold_s":-0.1})
	var doc := fixture()
	doc.root.properties.section_volumes = [{"id":"other","bounds":[0,0,50,50]}]
	doc.entities.heat.properties.section_id = "other"
	var invalid_binding := WorldRoomDocument.instantiate(doc)
	check(invalid_binding.has("error"),"reject foreign section shelter")
	if invalid_binding.has("room"): invalid_binding.room.free()
	var with_strip := fixture()
	with_strip.entities.strip = make_row("strip","hazard.spikes",{"bounds":[624,376,72,24],"facing":"up","host_id":"floor"})
	var supported_strip := WorldRoomDocument.instantiate(with_strip)
	check(supported_strip.has("room"),"authored C05 explicit supporting surface is legal")
	if supported_strip.has("room"): supported_strip.room.free()
	with_strip.entities.strip.properties.bounds = [624,348,72,24]
	var detached_strip := WorldRoomDocument.instantiate(with_strip)
	check(str(detached_strip.get("error","")).contains("spike_attachment_invalid"),"authored C05 rejects a gap below the spike roots")
	if detached_strip.has("room"): detached_strip.room.free()
	var host := {"component":"array:platforms","properties":{"rect":[32,32,64,64]}}
	var faces := {"up":[32,16,64,16],"down":[32,96,64,16],"left":[16,32,16,64],"right":[96,32,16,64]}
	for face: String in faces:
		var props := {"bounds":faces[face],"facing":face}
		check(WorldElementCatalog.spike_attachment_valid(props,host),face+" alignment")
		var direction: int = {"up":PlatformThornDefinition.Face.TOP,"down":PlatformThornDefinition.Face.BOTTOM,
			"left":PlatformThornDefinition.Face.LEFT,"right":PlatformThornDefinition.Face.RIGHT}[face]
		var danger := FixedWorldProvider.rect(props.bounds)
		var support := FixedWorldProvider.rect(host.properties.rect)
		var plan := UnderworldHazardTiles.surface_plan(danger,direction,support)
		var coverage := Rect2()
		for part: Dictionary in plan:
			coverage = coverage.merge(part.danger_world) if coverage.has_area() else part.danger_world
			check(support.encloses(part.root_world) or support == part.root_world or support.intersection(part.root_world) == part.root_world,face+" embedded roots stay on support")
		check(coverage == danger, face+" visible hazard ends match contact envelope")
		props.bounds = [0,0,10,10]
		check(not WorldElementCatalog.spike_attachment_valid(props,host),face+" detached")

func run() -> void:
	configuration()
	var doc := fixture()
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(doc)
	if not error.is_empty():
		check(false,error)
		quit(1)
		return
	await ticks(28)
	var plate: WorldPressurePlate = session.room.element_runtime.nodes.plate
	var gate: WorldElementGate = session.room.element_runtime.nodes.gate
	check(plate.active and plate.occupied and gate.active,"true top contact enables gate")
	session.player.reset_at(Vector2(242,381))
	await ticks(20)
	check(not plate.occupied and plate.active and gate.active,"release hold")
	await ticks(30)
	check(not plate.active and gate.active and plate.sent_active,"gate waits while body remains")
	session.player.reset_at(Vector2(315,381))
	await ticks(5)
	check(not gate.active and not plate.sent_active,"wait clears")
	var step: WorldCrumblePlatform = session.room.element_runtime.nodes.step
	session.player.reset_at(Vector2(360,320))
	await ticks(21)
	check(step.phase == "cracking" and step.solid,"standing starts cracking")
	var age := step.elapsed
	session.player.reset_at(Vector2(400,330))
	await ticks(4)
	check(step.elapsed >= age and step.phase == "cracking","leaving does not reset crack timer")
	await ticks(36)
	check(not step.solid,"crumble removes real collision")
	step.element_restore({"phase":"reforming","elapsed":.25,"solid":false,"desired":true,"resume_phase":"idle","resume_elapsed":0,"jump_serial":0})
	session.player.reset_at(Vector2(360,355))
	await ticks(2)
	check(step.phase == "reform_wait" and not step.solid,"no solid around player")
	session.player.reset_at(Vector2(285,382))
	await ticks(3)
	check(step.phase == "idle" and step.collision_layer == 1,"blocked shape safely respawns")
	var blink: WorldCrumblePlatform = session.room.element_runtime.nodes.blink
	blink.reset_attempt()
	blink.set_equipment_time(0)
	await ticks(8)
	session.controller.router.request_action(&"jump",Vector2.ZERO)
	await ticks(4)
	check(blink.desired and not blink.solid and is_zero_approx(blink.elapsed),"accepted ground jump changes target during freeze")
	var serial := session.controller.jump_ability.accepted_serial
	blink._jump(&"ground",serial,session.player.global_position)
	check(blink.desired,"duplicate action ignored")
	blink.set_equipment_time(1)
	await ticks(24)
	check(blink.solid,"resume completes reform")
	session.controller.traversal.grant(&"double_jump")
	session.player.reset_at(Vector2(285,382))
	await ticks(10)
	session.controller.router.request_action(&"jump",Vector2.ZERO)
	await ticks(4)
	var ground_target := blink.desired
	session.controller.router.request_action(&"jump",Vector2.ZERO)
	await ticks(3)
	check(blink.desired != ground_target,"real double jump toggles again")
	var saved := blink.element_state()
	blink.reset_attempt()
	blink.element_restore(saved)
	check(blink.element_state() == saved,"crumble snapshot restoration")
	await spike_checks(session)
	await shelter_checks(session)
	await cycle_and_reset(session)
	check(await session.audio_service.shutdown(),"audio released")
	session.free()
	await advanced_checks()
	await coordinated_outputs()
	await shield_scope("hazard.periodic_emitter",{"position":[900,366],"emit_mode":"stream","warning_time":1.2,"stream_duration_s":1.0})
	await shield_scope("hazard.cyclic_press",{"position":[1020,338],"body_size":[100,36],"stroke":16,"hazard_depth":26,"initial_running":false})
	print("HAZARD LIBRARY failures=",failures," checks=",checked)
	quit(1 if failures else 0)

func spike_checks(session: OrdinaryRoomSession) -> void:
	var teeth: WorldRetractingSpikes = session.room.element_runtime.nodes.teeth
	teeth.mode = "signal"
	teeth.reset_attempt()
	teeth.element_restore(teeth.element_propose("set_active",true))
	await ticks(10)
	check(teeth.phase == "warning" and teeth.extension() == 0,"signal warns without contact")
	await ticks(15)
	check(teeth.phase == "extending" and teeth.extension() > 0,"signal starts real extension")
	teeth.set_equipment_time(0)
	var ext := teeth.extension()
	await ticks(8)
	check(is_equal_approx(teeth.extension(),ext),"time stop retains actual dangerous shape")
	teeth.element_restore(teeth.element_propose("set_active",false))
	teeth.set_equipment_time(1)
	await ticks(30)
	check(teeth.phase == "retracted" and teeth.extension() == 0,"latest target applied after extension")
	for face: String in ["up","down","left","right"]:
		teeth.facing = face
		var full := teeth.envelope(1)
		var half := teeth.envelope(.5)
		check(full == teeth.bounds and is_equal_approx(half.get_area(),full.get_area()*.5),face+" half and full hazard")
	teeth.mode = "cycle"
	teeth.start_phase01 = .7
	teeth.reset_attempt()
	check(teeth.phase == "exposed","cycle offset reaches exposed stage")
	var state := teeth.element_state()
	teeth.element_restore(teeth.element_propose("set_active",false))
	await ticks(6)
	check(teeth.elapsed == state.elapsed,"cycle pause holds hazard")

func shelter_checks(session: OrdinaryRoomSession) -> void:
	var heat: WorldHazardArea = session.room.element_runtime.nodes.heat
	var shelter: WorldEnvironmentShelter = session.room.element_runtime.nodes.shelter
	session.player.reset_at(Vector2(904,381))
	await ticks(6)
	shelter.active_s = 0.6
	shelter.expiry_warning_s = .2
	shelter.cooldown_s = 0
	session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(28)
	check(shelter.phase == "active","real bullet activates fixed shelter")
	var remaining := shelter.remaining
	shelter.mechanism_shot({"controller":session.controller,"attack_kind":"shot","packet_id":"busy-test"})
	check(shelter.remaining == remaining,"busy packet preserves deadline")
	session.player.reset_at(Vector2(1020,380))
	heat.hazard_mode = "steady"
	await ticks(2)
	var amount := session.controller.actor_resources.health.current
	var data := heat.exposure.snapshot()
	await ticks(2)
	check(heat.exposure.pulse == data.pulse and session.controller.actor_resources.health.current == amount,"body inside shield blocks bound source")
	await ticks(36)
	check(shelter.phase == "ready" and heat.exposure.pulse > 0,"expiry releases exposure and zero cooldown rearms")
	shelter.reset_attempt()
	check(shelter.receipts.is_empty() and shelter.phase == "ready","attempt reset")
	session.player.reset_at(Vector2(144,320))
	await ticks(4)
	heat.hazard_mode = "cycle"
	for fraction: float in [0.0,.55,.90]:
		heat.start_phase01 = fraction
		heat.reset_attempt()
		var phase := heat.phase
		check(phase == ("inactive" if fraction == 0 else "warning" if fraction < .60 else "active"),"cycle phase "+str(fraction))

func cycle_and_reset(session: OrdinaryRoomSession) -> void:
	var nodes := session.room.element_runtime.nodes
	var step: WorldCrumblePlatform = nodes.step
	var blink: WorldCrumblePlatform = nodes.blink
	var heat: WorldHazardArea = nodes.heat
	var teeth: WorldRetractingSpikes = nodes.teeth
	step.trigger_mode = "cycle"
	step.solid_s = .5
	step.crack_s = .5
	step.reform_s = .5
	step.absent_s = .5
	session.player.reset_at(Vector2(695,368))
	for i: int in 4:
		step.start_phase01 = i*.25+.125
		step.reset_attempt()
		check(step.phase == ["solid","cracking","absent","reforming"][i] and is_equal_approx(step.elapsed,.25) and step.solid==(i<2),"G01 cycle authored offset "+str(i))
		step._physics_process(.3)
		check(step.phase == ["cracking","absent","reforming","solid"][i] and is_equal_approx(step.elapsed,.05),"G01 integrates past boundary "+str(i))
	blink.reset_attempt()
	blink._jump(&"ground",blink.last_jump+1,blink.global_position)
	blink._jump(&"ground",blink.last_jump+1,blink.global_position)
	check(not blink.solid and not blink.desired and blink.phase == "absent","successive accepted jumps cancel materialization")
	blink._jump(&"ground",blink.last_jump+1,blink.global_position+Vector2(5000,0))
	check(not blink.desired,"range excludes distant jump")
	teeth.facing = "up"
	teeth.set_equipment_time(0)
	var health := session.controller.actor_resources.health
	var before := health.current
	session.player.reset_at(Vector2(641,379))
	await ticks(4)
	check(teeth.extension() == 1 and health.current < before,"stationary exposed G05 remains lethal while time is stopped")
	session.player.reset_at(Vector2(290,380))
	session.room.element_runtime.reset_section("main")
	check(step.phase=="reforming" and is_equal_approx(step.elapsed,.25),"section reset rebuilds authored G01 phase")
	check(heat.exposure.pulse==0 and is_equal_approx(heat.clock,heat.start_phase01*(heat.active_s+heat.warning_s+heat.inactive_s)),"section reset restores C11 exposure and offset")
	check(nodes.shelter.phase=="ready" and nodes.shelter.receipts.is_empty(),"section reset withdraws G36 protection")
	check(teeth.scale_time==1 and teeth.running and blink.last_jump==session.controller.jump_ability.accepted_serial,"section reset clears local time and rebinds accepted jump generation")

func make_row(id: String, definition: String, properties: Dictionary) -> Dictionary:
	return {"id":id,"definition_id":definition,"definition_version":1,"properties":properties}

func advanced_checks() -> void:
	var doc := fixture()
	doc.root.properties.start_point = [262,250]
	doc.entities.wall = make_row("wall","platform.crumble",{"position":[322,304],"platform_size":[32,176],"one_way":false,"trigger_mode":"wall_attach","attach_face":"left"})
	doc.entities.blink.properties.jump_types = ["wall"]
	doc.entities.plate.properties.accepted_load = "player_and_marked_weight"
	doc.entities.box = make_row("box","terrain.push_crate",{"position":[144,260],"body_size":[48,48],"pressure_weight":true})
	doc.entities.second = make_row("second","zone.environment_shelter",{"position":[1060,366],"protected_sources":["heat"]})
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(doc)
	if not error.is_empty():
		check(false,error)
		session.free()
		return
	var elements := session.room.element_runtime.nodes
	var wall: WorldCrumblePlatform = elements.wall
	var blink: WorldCrumblePlatform = elements.blink
	var plate: WorldPressurePlate = elements.plate
	session.controller.router.set_move_axis(1)
	await ticks(20)
	check(wall.phase == "idle","ordinary side touch does not crack")
	check(not plate.occupied or elements.box.pressure_bounds().has_area(),"airborne crate cannot trigger")
	session.controller.traversal.grant(&"wall_climb")
	session.player.reset_at(Vector2(276,255))
	for i: int in 36:
		if session.controller.traversal.state == &"wall_attach" and wall.phase == "cracking": break
		await physics_frame
	check(session.controller.traversal.state == &"wall_attach" and wall.phase == "cracking","qualified attachment to marked face")
	session.controller.router.request_action(&"jump")
	await ticks(3)
	check(blink.desired and session.player.normal_velocity.x < 0,"formal wall kick triggers filtered listener")
	check(plate.occupied and plate.active and elements.box.pressure_bounds().has_area(),"marked grounded crate bears on plate")
	session.controller.router.set_move_axis(0)
	wall.reset_attempt()
	session.player.reset_at(Vector2(364,245))
	session.controller.router.set_move_axis(-1)
	await ticks(18)
	check(wall.phase == "idle","wrong climbing face remains stable")
	session.controller.router.set_move_axis(0)
	var shelter: WorldEnvironmentShelter = elements.shelter
	var second: WorldEnvironmentShelter = elements.second
	var heat: WorldHazardArea = elements.heat
	# A single physics step contains two active intervals and one unprotected gap.
	shelter.reset_attempt()
	shelter.active_s = .10
	shelter.cooldown_s = 0
	check(not shelter.mechanism_shot({"controller":session.controller,"attack_kind":"explosion","packet_id":"blast"}),"explosion cannot start shield")
	check(not shelter.mechanism_shot({"attack_kind":"shot","packet_id":"foreign"}),"foreign shot cannot start shield")
	shelter.mechanism_shot({"controller":session.controller,"attack_kind":"shot","packet_id":"start","hit_fraction":0.0})
	shelter.mechanism_shot({"controller":session.controller,"attack_kind":"shot","packet_id":"next","hit_fraction":.8})
	shelter._physics_process(.25)
	var center := Rect2(shelter.global_position-Vector2(12,18),Vector2(24,36))
	var windows := shelter.protection_intervals(center,center)
	check(windows.size()==2 and windows[0].is_equal_approx(Vector2(0,.4)) and windows[1].is_equal_approx(Vector2(.8,1)), "substep expiry, rearming and new contact")
	var edge := center
	edge.position.x += shelter.shield_radius-2
	check(shelter.protection_intervals(edge,edge).is_empty(),"center inside but body corner outside")
	check(not shelter.protection_intervals(edge,center).is_empty(),"moving body enters entirely partway through step")
	shelter.active_s = 3
	shelter.reset_attempt()
	second.reset_attempt()
	second.mechanism_shot({"controller":session.controller,"attack_kind":"shot","packet_id":"second","hit_fraction":0})
	session.player.reset_at(second.global_position)
	heat.hazard_mode = "steady"
	await ticks(4)
	check(heat.exposure.pulse == 0 and heat.shelters.size() == 2,"overlapping second shelter independently protects same registered source")
	# Integrate a safe/active boundary at a non-integral tick fraction.
	session.player.reset_at(Vector2(258,380))
	heat.inactive_s = 1
	heat.warning_s = .5
	heat.active_s = 1
	heat.hazard_mode = "cycle"
	heat.exposure.restore({})
	heat.integrate_contact(1.45,.1,false)
	check(heat.exposure.pulse == 1 and is_equal_approx(heat.exposure.cooldown,.65), "exposure integrates only dangerous subinterval")
	var cooldown := heat.exposure.cooldown
	heat.integrate_contact(1.6,.2,true)
	check(is_equal_approx(heat.exposure.cooldown,cooldown),"shelter pauses source's existing exposure")
	var swept := WorldHazardGeometry.sweep(Rect2(0,10,4,4),Rect2(100,10,4,4),Rect2(24,0,16,20),Rect2(24,0,16,20))
	check(swept.is_equal_approx(Vector2(.2,.4)),"complete high-speed traversal yields subframe contacts")
	check(await session.audio_service.shutdown(),"advanced audio released")
	session.free()

func coordinated_outputs() -> void:
	var doc := fixture()
	var sources := [{"source_id":"plate","output":"active"},{"source_id":"plate","output":"occupied"}]
	doc.entities.plate.properties.links = []
	doc.entities.both = make_row("both","internal.bool_condition",{"operation":"all","sources":sources,"links":[{"output":"active","target":"immediate","input":"set_active"}]})
	doc.entities.held = make_row("held","internal.bool_condition",{"operation":"any","sources":sources,"links":[{"output":"active","target":"gate","input":"set_active"}]})
	doc.entities.immediate = make_row("immediate","gate.masonry",{"bounds":[1280,292,32,108],"state_scope":"attempt"})
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(doc)
	if not error.is_empty():
		check(false,error)
		session.free()
		return
	var nodes := session.room.element_runtime.nodes
	await ticks(30)
	check(nodes.both.active and nodes.held.active and nodes.immediate.active and nodes.gate.active,"both ports committed on real load")
	session.player.reset_at(Vector2(254,381))
	await ticks(12)
	check(not nodes.plate.occupied and nodes.plate.active and not nodes.both.active and nodes.held.active and not nodes.immediate.active and nodes.gate.active,"ALL and ANY differ during hold, with independent gates")
	await ticks(40)
	check(not nodes.plate.active and nodes.plate.sent_active and nodes.held.active and nodes.gate.active,"blocked close retains committed graph")
	session.player.reset_at(Vector2(300,381))
	await ticks(6)
	check(not nodes.plate.sent_active and not nodes.held.active and not nodes.gate.active,"clearance approves previously blocked transition through bool graph")
	check(await session.audio_service.shutdown(),"condition audio released")
	session.free()

func shield_scope(definition: String, properties: Dictionary) -> void:
	var doc := fixture()
	doc.root.properties.start_point = [904,381]
	doc.entities.danger = make_row("danger",definition,properties)
	doc.entities.shelter.properties.protected_sources = ["danger"]
	var invalid_binding := WorldRoomDocument.instantiate(doc)
	check(str(invalid_binding.get("error","")).contains("protected_sources:not_hazard_area"),"reject binding actual "+definition)
	if invalid_binding.has("room"): invalid_binding.room.free()
	doc.entities.shelter.properties.protected_sources = ["heat"]
	doc.entities.heat.properties.hazard_mode = "steady"
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(doc)
	if not error.is_empty():
		check(false,error)
		session.free()
		return
	var nodes := session.room.element_runtime.nodes
	await ticks(8)
	session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(30)
	check(nodes.shelter.phase == "active","real bullet produced local protection for "+definition)
	var health := session.controller.actor_resources.health
	var before := health.current
	session.player.reset_at(Vector2(1020,381))
	await ticks(50)
	check(nodes.shelter.phase == "active" and nodes.heat.exposure.pulse == 0 and health.current < before,"in-shelter "+definition+" hurts while registered C11 stays suppressed")
	check(await session.audio_service.shutdown(),"scope audio released")
	session.free()

## Record either route with Godot --write-movie and -- showcase [shield].
func showcase() -> void:
	var doc := fixture()
	var shield_route := "shield" in OS.get_cmdline_user_args()
	for option: String in OS.get_cmdline_user_args():
		if option.begins_with("region="):
			var region := option.trim_prefix("region=")
			if not WorldElementCatalog.region_known(region):
				printerr("Unknown showcase region ",region)
				quit(1)
				return
			doc.root.properties.region_id = region
			doc.root.properties.terrain_material = region
	if shield_route:
		doc.root.properties.start_point = [904,381]
		doc.entities.heat.properties.start_phase01 = .55
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(doc)
	if not error.is_empty():
		printerr(error)
		session.free()
		quit(1)
		return
	await ticks(28)
	if shield_route:
		session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
		await ticks(24)
		session.controller.router.set_move_axis(1)
		while session.player.global_position.x < 1020: await physics_frame
		session.controller.router.set_move_axis(0)
		await ticks(200)
	else:
		session.controller.router.set_move_axis(1)
		while session.player.global_position.x < 290: await physics_frame
		session.controller.router.request_action(&"jump")
		while session.player.global_position.x < 360: await physics_frame
		session.controller.router.set_move_axis(0)
		await ticks(125)
		session.controller.router.set_move_axis(1)
		while session.player.global_position.x < 565: await physics_frame
		session.controller.router.set_move_axis(0)
		await ticks(125)
	await session.audio_service.shutdown()
	session.free()
	quit()
