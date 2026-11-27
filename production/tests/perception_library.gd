extends SceneTree

const CUSTOM_COVER := "res://assets/world_elements/native/forest_bramble.png"
var failures := 0
var checks := 0
var session: OrdinaryRoomSession

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1; printerr("FAIL perception ",label)

func ticks(count: int) -> void:
	for index: int in count: await physics_frame

func row(id: String,definition: String,p: Dictionary) -> Dictionary:
	return {"id":id,"definition_id":definition,"definition_version":1,"properties":p}

func document() -> Dictionary:
	var doc := WorldRoomDocument.read("res://tests/assembly_room.json")
	doc.entities.erase("bell")
	doc.entities.gate.properties.bounds = [664,256,32,128]
	doc.entities.gate.properties.state_scope = "attempt"
	doc.entities.flower = row("flower","switch.light",{"position":[340,280],"light_source_types":["local_light"],"links":[{"output":"active","target":"gate","input":"set_active"}]})
	doc.entities.lamp = row("lamp","environment.local_light",{"position":[248,280],"initial_active":false})
	doc.entities.guide = row("guide","environment.local_light",{"position":[100,130],"light_mode":"guide","route":[[40,0],[40,60]],"move_speed":100,"waypoint_dwell_s":0.25,"light_radius":30})
	doc.entities.reeds = row("reeds","zone.sight_occluder",{"bounds":[352,300,96,84]})
	doc.entities.lure = row("lure","interaction.sound_lure",{"position":[416,350],"cooldown_s":0.2})
	doc.entities.mat = row("mat","interaction.sound_lure",{"trigger_mode":"ground_contact","bounds":[216,372,96,12],"cooldown_s":0.2})
	doc.entities.vines = row("vines","zone.foreground_cover",{"bounds":[130,270,232,114],"fade_out_s":0.2,"restore_s":0.3,"revealed_alpha":0.2})
	doc.entities.grove = row("grove","zone.foreground_cover",{"bounds":[136,276,232,114],"texture_path":CUSTOM_COVER})
	doc.entities.station = row("station","recovery.station",{"position":[160,366]})
	doc.entities.reward = row("reward","equipment.reward",{"position":[160,366],"source_id":"equipment.EQ_LAMP"})
	doc.entities.gear_follower = row("gear_follower","hazard.gear",{"position":[40,40],"drive_id":"carrier_clock"})
	doc.entities.carrier_clock = row("carrier_clock","platform.moving",{"position":[48,40],"endpoint":[64,0]})
	doc.entities.dark = row("dark","zone.environment",{"bounds":[320,220,128,100],"mode":"dark"})
	return doc

func check_reject(definition_id: String, props: Dictionary, label: String) -> void:
	var d := document()
	d.entities.probe = row("probe",definition_id,props)
	var built := WorldRoomDocument.instantiate(d)
	check(built.has("error"),label)
	if built.has("room"): built.room.free()

func check_cycles() -> void:
	var d := document()
	d.entities.lamp.properties.position = [900,280]
	d.entities.lamp.properties.light_mode = "guide"
	d.entities.lamp.properties.endpoint = [-570,0]
	d.entities.flower.properties.links = [{"target":"lamp","input":"set_active","output":"active"}]
	var built := WorldRoomDocument.instantiate(d)
	check(built.has("error"),"future moving source swept range closes control loop")
	if built.has("room"): built.room.free()
	d = document()
	d.entities.gate.properties.bounds = [280,250,24,100]
	built = WorldRoomDocument.instantiate(d)
	check(built.has("error"),"controlled gate in fixed light ray closes control loop")
	if built.has("room"): built.room.free()
	check_reject("environment.local_light",{"light_mode":"guide","route":[[45,0],[45,0]]},"zero path segment")
	check_reject("switch.light",{"light_source_types":["equipped_light","equipped_light"]},"duplicate light source")
	check_reject("zone.foreground_cover",{"revealed_alpha":1.1},"alpha range")
	for path: String in ["res://assets/missing_cover.png","user://foreign.png","res://assets/../assets/world_elements/native/forest_bramble.png","res://game/player/player.tscn"]:
		check_reject("zone.foreground_cover",{"texture_path":path},"reject foreground resource "+path)
	var setup := WorldRoomDocument.instantiate(document())
	if setup.has("room"):
		var packed := PackedScene.new()
		check(packed.pack(setup.room)==OK,"pack instance artwork in editor")
		setup.room.free()
		var restored := WorldRoomDocument.extract(packed)
		check(restored.entities.grove.properties.texture_path==CUSTOM_COVER and restored.entities.vines.properties.get("texture_path","")=="","custom and inherited v1 fields survive scene export")
	else: check(false,"valid custom Texture2D instantiates")
	check_reject("interaction.sound_lure",{"audible_radius":0},"lure radius")
	check_reject("zone.sight_occluder",{"bounds":[0,0,0,8]},"reeds bounds")

func check_optics(nodes: Dictionary) -> void:
	var flower: WorldLightFlower = nodes.flower
	var lamp: WorldLocalLight = nodes.lamp
	var guide: WorldLocalLight = nodes.guide
	var network := lamp.network
	var gate: WorldElementGate = nodes.gate
	var order: Array = network.order
	check(order.find("lamp") >= 0 and order.find("lamp") < order.find("flower") and order.find("flower") < order.find("gate"),"optical ordering uses formal lamp and signal edges")
	check(order.find("carrier_clock") >= 0 and order.find("carrier_clock") < order.find("gear_follower"),"runtime shares order including validator-approved drive dependencies")
	check(WorldLightNetwork.intensity(10,10,1,0) == 1 and WorldLightNetwork.intensity(11,10,1,0) == 0,"hard edge")
	check(is_equal_approx(WorldLightNetwork.intensity(90,100,0.8,0.5),0.16),"linear edge")
	lamp.element_restore(lamp.element_propose("set_active",true))
	await ticks(2)
	check(flower.phase == "charging" and not gate.active,"flower charges before gate")
	lamp.element_restore(lamp.element_propose("set_active",false))
	await ticks(3)
	check(flower.phase == "dark" and flower.elapsed == 0,"short flash discarded")
	lamp.element_restore(lamp.element_propose("set_active",true))
	await ticks(18)
	check(flower.accepted and gate.active and gate.body.collision_layer == 0,"sustained light controls real gate")
	lamp.element_restore(lamp.element_propose("set_active",false))
	await ticks(8)
	check(flower.phase == "release_hold" and gate.active,"dark interval holds output")
	lamp.element_restore(lamp.element_propose("set_active",true))
	await ticks(2)
	check(flower.phase == "active" and flower.elapsed == 0,"reillumination cancels release")
	lamp.element_restore(lamp.element_propose("set_active",false))
	await ticks(32)
	check(not flower.accepted and not gate.active and gate.body.collision_layer == 1,"hold expires")
	lamp.position = Vector2(708,340); lamp.light_radius = 320
	lamp.element_restore(lamp.element_propose("set_active",true))
	check(network.sample(Vector2(608,340),["local_light"]) == 0,"closed door occludes light beam")
	gate.element_restore({"active":true})
	await ticks(2)
	check(network.sample(Vector2(608,340),["local_light"]) > 0.9,"open door releases light")
	lamp.position = guide.position
	lamp.brightness = 0.4
	check(is_equal_approx(network.sample(guide.global_position,["local_light"]),1.0),"overlap takes max")
	check(not guide.mechanism_shot({}) and guide.mechanism_shot({"packet_id":"play"}) and not guide.mechanism_shot({"packet_id":"play"}),"guide shot receipt")
	guide.advance_light(0.45)
	check(guide.phase == "waypoint_wait" and is_equal_approx(guide.wait_left,0.20),"waypoint travel plus partial dwell")
	guide.element_restore(guide.element_propose("set_active",false))
	var paused := guide.element_state()
	guide.advance_light(3)
	check(guide.element_state() == paused,"switch freezes path and dwell")
	guide.element_restore(guide.element_propose("set_active",true))
	guide.advance_light(10)
	check(guide.phase == "home" and guide.current.is_zero_approx(),"return traverses intermediate points")
	guide.end_behavior = "dock"; guide.waypoint_dwell_s = 0
	check(guide.mechanism_shot({"packet_id":"again"}),"guide rearmed")
	guide.advance_light(3)
	check(guide.phase == "docked" and guide.current == Vector2(40,60) and not guide.mechanism_shot({"packet_id":"late"}),"dock consumes remaining time and stays")
	var equipped_at := session.player.global_position
	check(network.sample(equipped_at,["equipped_light"]) == 0,"unequipped lamp contributes nothing")
	check(session.equipment_transaction("claim","equipment.EQ_LAMP",session.state.revision),"claim lamp from real equipment source")
	check(session.equipment_transaction("equip","EQ_LAMP",session.state.revision),"equip lamp at actual rest station")
	check(network.sample(equipped_at,["equipped_light"]) > 0.99,"actual equipped lamp contributes")
	check(network.sample(equipped_at+Vector2(300,0),["equipped_light"]) == 0,"equipment light range")

func check_sight_and_sound(nodes: Dictionary) -> void:
	var reeds: WorldSightReeds = nodes.reeds
	var a := Vector2(330,349); var b := Vector2(480,349)
	check(WorldLightNetwork.sight_blocked(session.room,a,b),"opposite sides")
	check(WorldLightNetwork.sight_blocked(session.room,Vector2(360,349),Vector2(390,350)),"both inside")
	check(not WorldLightNetwork.sight_blocked(session.room,Vector2(320,300),Vector2(500,300)),"tangent is clear")
	reeds.element_restore({"active":false})
	check(not WorldLightNetwork.sight_blocked(session.room,a,b),"disabled reeds release sight")
	var lure: WorldSoundLure = nodes.lure
	var enemy: EnemyActor = session.room.enemies.patrol
	enemy.motor.reset_at(Vector2(510,368))
	await ticks(3)
	check(lure.mechanism_shot({"packet_id":"sound"}) and not lure.mechanism_shot({"packet_id":"sound"}),"sound shot dedup")
	check(enemy.investigation_owner == lure,"real nearby patrol accepts reachable investigation")
	var duration := enemy.investigation_left
	await ticks(6)
	check(enemy.investigation_goal.x < enemy.motor.global_position.x and enemy.investigation_left == duration,"timer waits for arrival")
	await ticks(280)
	check(enemy.investigation_owner == null, "investigation completes and patrol resumes")
	lure.stand_search_radius = 4
	check(lure.mechanism_shot({"packet_id":"new"}) and enemy.investigation_owner == null,"unreachable stand refused")
	var mat: WorldSoundLure = nodes.mat
	session.player.reset_at(Vector2(245,310))
	await ticks(45)
	check(mat.serial == 1 and mat.contacting and mat.last_emission.x >= 216 and mat.last_emission.x <= 312,"real landing makes one sound at foot")
	await ticks(28)
	check(mat.serial == 1,"sustained support never retriggers on cooldown")
	session.player.reset_at(Vector2(680,350))
	await ticks(4)
	check(not mat.contacting,"departure releases contact")
	var before := mat.serial
	check(mat.element_can_receive("sound",null),"external pulse ready")
	mat.element_restore(mat.element_propose("sound",null))
	check(mat.serial == before+1 and mat.last_emission == Vector2(264,372),"external mat pulse uses top center")

func check_cover(nodes: Dictionary) -> void:
	var cover: WorldForegroundCover = nodes.vines
	session.player.reset_at(Vector2(180,354))
	cover._process(1)
	check(not cover.chunks.is_empty(),"visible vine chunks installed")
	var tile: Dictionary = cover.chunks[Vector2i.ZERO]
	var image: Image = tile.image
	check(image.get_pixel(8,14).r8 == 255 and image.get_pixel(31,1).r8 == 0,"only player neighborhood reveals")
	session.player.reset_at(Vector2(700,350))
	cover._process(0.10)
	check(image.get_pixel(8,14).r > 0.55 and image.get_pixel(8,14).r < 0.85,"previous hole restores gradually after teleport")
	cover._process(1)
	check(image.get_pixel(8,14).r8 == 0,"old region restored")
	cover.fade_out_s = 0; cover.restore_s = 0
	session.player.reset_at(Vector2(180,354)); cover._process(0.0001)
	check(image.get_pixel(8,14).r8 == 255,"zero transition reveals immediately")
	cover.element_restore({})
	check(cover.chunks.is_empty(),"attempt reset clears old mask")
	check(cover.closed_regions()==[cover.bounds],"entire foreground visible immediately at reset before camera processing")
	var custom: WorldForegroundCover=nodes.grove
	check(custom.skin.resource_path==CUSTOM_COVER and cover.skin.resource_path!=CUSTOM_COVER,"individual texture overrides the regional default only on its own instance")
	custom.element_restore({})
	check(custom.closed_regions()==[custom.bounds],"initial view is fully covered even if camera has not solved")
	session.player.reset_at(Vector2(180,354))
	custom._process(1)
	var masked: Dictionary=custom.chunks[Vector2i.ZERO]
	var mat: ShaderMaterial=masked.rect.material
	check(mat.get_shader_parameter("vines")==custom.skin and mat.get_shader_parameter("texture_origin")==Vector2.ZERO,"shader uses the instance texture from the local top left")
	check(mat.get_shader_parameter("texture_span").is_equal_approx(masked.area.size/custom.skin.get_size()),"render samples one source pixel per world unit")
	var area_sum := 0.0
	for rect: Rect2 in custom.closed_regions(): area_sum+=rect.get_area()
	for part: Dictionary in custom.chunks.values():
		area_sum+=part.area.get_area()
		for rect: Rect2 in custom.closed_regions(): check(not rect.intersects(part.area),"unmasked art never draws beneath an open tile")
	check(is_equal_approx(area_sum,custom.bounds.get_area()),"mask tiles and closed fill exactly cover the rectangle")
	check(masked.image.get_pixel(7,13).r8==255,"custom foreground opens under the player")
	var candidate:=session.state.candidate()
	candidate.flags.append("discovered_path")
	check(session.state.commit(candidate,session.state.revision),"discover path while nearby")
	session.player.reset_at(Vector2(700,350))
	custom._process(1)
	check(masked.image.get_pixel(7,13).r8==0 and session.state.has("discovered_path"),"distant cover is closed while the separate discovery remains saved")

func check_controller_shots() -> void:
	var doc := WorldRoomDocument.read("res://tests/perception_demo.json")
	doc.entities.guard = row("guard","enemy.charger",{"point":[485,368],"max_health":5})
	var real := OrdinaryRoomSession.new(); root.add_child(real)
	var error := real.open(doc)
	if not error.is_empty():
		check(false,error); real.free(); return
	var nodes := real.room.element_runtime.nodes
	var guard: EnemyActor = real.room.enemies.guard
	real.player.reset_at(Vector2(224,366))
	await ticks(3)
	check(not guard.attack_behavior._can_engage(),"formal attack AI denied LOS through active reeds")
	nodes.reeds.element_restore({"active":false})
	check(guard.attack_behavior._can_engage(),"formal AI rediscovers visible player")
	nodes.reeds.element_restore({"active":true})
	real.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(36)
	check(nodes.guide.phase not in ["home","docked"] and nodes.guide.current.length() > 0,"actual gun shot through foliage starts guide")
	await ticks(150)
	check(nodes.guide.phase == "docked" and nodes.gate.active and nodes.flower.accepted,"travelling light opens gate after dock")
	# Issue a second shot along a parallel stretch of reeds; the cocoon itself remains at its fixed start.
	real.player.reset_at(Vector2(380,366))
	guard.motor.reset_at(Vector2(515,368))
	nodes.reeds.position = Vector2(160,0)
	await ticks(3)
	var health := guard.health.current
	real.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(36)
	check(guard.health.current < health,"reeds permit actual damage to rear target")
	check(await real.audio_service.shutdown(),"controller demonstration audio shutdown")
	real.free()

func check_regional_art() -> void:
	var atlases := {}
	var foregrounds := {}
	var doc := WorldRoomDocument.read("res://tests/perception_demo.json")
	for region: String in WorldElementCatalog.catalog().mechanism_regions:
		doc.root.properties.region_id = region
		doc.root.properties.terrain_material = region
		var preview := OrdinaryRoomSession.new()
		root.add_child(preview)
		var error := preview.open(doc)
		if not error.is_empty():
			check(false,"regional room "+region+" "+error)
			preview.free()
			continue
		var nodes := preview.room.element_runtime.nodes
		var atlas := (nodes.guide.art as Texture2D)
		atlases[atlas.resource_path] = true
		foregrounds[nodes.vines.skin.resource_path] = true
		check(nodes.flower.art == atlas,"regional flower and moving light use the same physical instrument family: "+region)
		if region == "thorn_forest":
			check(nodes.reeds.tall_art == WorldSightReeds.TALL and nodes.mat.mat_art == WorldSoundLure.MAT and atlas == LightInstrumentArt.ATLAS,"native forest art is retained")
		else:
			check(atlas.get_width() >= 5*LightInstrumentArt.CELL and nodes.reeds.tall_art is AtlasTexture and nodes.mat.charm_art is AtlasTexture,"regional lamp, shoot and sound-part frames: "+region)
			if nodes.reeds.tall_art is AtlasTexture and nodes.mat.charm_art is AtlasTexture:
				check(nodes.reeds.tall_art.atlas == atlas and nodes.reeds.cut_art.region == LightInstrumentArt.CUT_BANK and nodes.mat.charm_art.atlas == atlas and nodes.mat.mat_art.region == LightInstrumentArt.MAT,"real consumer uses corresponding sheet windows: "+region)
		await preview.audio_service.shutdown()
		preview.free()
	check(atlases.size()==16 and foregrounds.size()==16,"all regions have distinct instrument and foreground artwork")

func run() -> void:
	check_cycles()
	session = OrdinaryRoomSession.new(); root.add_child(session)
	var error := session.open(document())
	if not error.is_empty():
		printerr("FAIL perception open ",error); quit(1); return
	await ticks(4)
	var nodes := session.room.element_runtime.nodes
	await check_optics(nodes)
	await check_sight_and_sound(nodes)
	check_cover(nodes)
	session.room.element_runtime.reset_section("main")
	check(nodes.mat.serial == 0 and nodes.lure.cooldown_left == 0 and nodes.lure.packets.is_empty(),"reset clears hearing cooldown, attack receipts and carpet baseline")
	check(nodes.guide.phase == "home" and nodes.guide.current == Vector2.ZERO and nodes.guide.receipts.is_empty(),"reset returns guide and clears shot receipts")
	check(not nodes.flower.accepted and not nodes.flower.desired and nodes.flower.elapsed == 0,"reset clears flower timers before fresh illumination sampling")
	check(await session.audio_service.shutdown(),"audio shutdown")
	session.free()
	await check_controller_shots()
	await check_regional_art()
	print("PERCEPTION LIBRARY failures=",failures," checks=",checks)
	quit(1 if failures else 0)
