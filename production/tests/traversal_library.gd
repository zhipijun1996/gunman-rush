extends SceneTree
## Exercises the same schema, session, physics bodies and action router as a playable room.
var failures := 0
var checks := 0
var session: OrdinaryRoomSession

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)

func ticks(n: int) -> void:
	for i: int in n: await physics_frame

func document(id: String, props: Dictionary, start := Vector2(160,366), floor_y := 384) -> Dictionary:
	var doc := WorldRoomDocument.read("res://tests/crossing_sensor_demo.json")
	doc.room_id = "traversal-library"
	doc.root.properties.start_point = [start.x,start.y]
	doc.entities.erase("trip")
	doc.entities.erase("gate")
	doc.entities.floor.properties.rect[1] = floor_y
	doc.entities["tested"] = {"id":"tested","definition_id":id,"definition_version":1,"properties":props}
	return doc

func open_case(id: String, props: Dictionary, start := Vector2(160,366), floor_y := 384) -> bool:
	session = OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(document(id,props,start,floor_y))
	check(error.is_empty(),id+" opens: "+error)
	return error.is_empty()

func close_case() -> void:
	if is_instance_valid(session.audio_service): await session.audio_service.shutdown()
	session.free()

func try_grapple() -> void:
	session.controller.traversal.grant(&"grapple")
	check(session.controller.router.request_action(&"grapple",Vector2.RIGHT),"submit H")

func test_hooks() -> void:
	for id: String in ["traversal.hook","traversal.hook_point"]:
		var doc := document(id,{"position":[244,360],"initial_available":false,"cooldown_s":.25,"reactivate_warning_s":1.0})
		var formed := WorldRoomDocument.instantiate(doc)
		check(formed.has("room"),id+" instantiate")
		if not formed.has("room"): continue
		var packed := PackedScene.new()
		packed.pack(formed.room)
		formed.room.free()
		var saved := WorldRoomDocument.extract(packed)
		check(saved.entities.tested.properties.cooldown_s==.25,id+" roundtrip")
		if not await open_case(id,saved.entities.tested.properties): continue
		var anchor: GrappleAnchor = session.room.element_runtime.nodes.tested
		check(anchor.remaining>0 and not anchor.is_in_group(&"grapple_target"),"initial disabled hook")
		await ticks(20)
		await try_grapple()
		await ticks(30)
		var traversal := session.controller.traversal
		if id=="traversal.hook_point":
			check(traversal.state==&"hook_hang","real fixed hook hang")
			check(anchor.attached and not anchor.hook_session.is_empty(),"single active session")
			var state := anchor.element_state()
			anchor.element_restore(state)
			check(anchor.attached,"valid restored hanging session")
			session.controller.router.request_action(&"jump")
			await ticks(2)
			check(not anchor.attached and anchor.remaining>0,"jump detaches and starts cooldown")
			anchor.element_restore(state)
			check(not anchor.attached and anchor.remaining==anchor.cooldown_s,"stale hanging snapshot enters full cooldown")
		else:
			check(anchor.remaining>0 or not traversal.hook_used,"bounce receipt and release")
		await ticks(20)
		check(anchor.is_in_group(&"grapple_target"),"same anchor becomes available")
		await close_case()
	for mode: String in ["cycle","zipline","retract"]:
		var props := {"position":[244,360],"hang_enabled":true,"motion_mode":mode,"initial_active":false,"cooldown_s":.25}
		if mode=="zipline": props.endpoint=[96,48]
		if mode=="retract":
			props.position=[244,232]
			props.endpoint=[0,128]
		if not await open_case("traversal.moving_hook",props,Vector2(160,366),400): continue
		var anchor: MovingGrappleAnchor = session.room.element_runtime.nodes.tested
		session.player.reset_at(Vector2(160,anchor.global_position.y+6))
		await try_grapple()
		await ticks(33)
		check(anchor.attached,"real suspended "+mode+" hook: "+str(session.controller.traversal.state))
		if not anchor.attached:
			await close_case()
			continue
		var old := anchor.position
		anchor.element_restore(anchor.element_propose("set_active",true))
		await ticks(24)
		check(anchor.position != old,mode+" moves/carrier follows")
		anchor.set_equipment_time(0)
		old = anchor.position
		session.controller.traversal.cancel()
		await ticks(20)
		check(anchor.position == old and anchor.remaining==0,"time stop keeps motion, releases eligibility")
		anchor.set_equipment_time(1)
		await ticks(100)
		if mode!="cycle": check(anchor.stage==anchor.idle_stage(),mode+" returns to starting endpoint")
		await close_case()

func test_surfaces() -> void:
	for mode: String in ["sticky","ice"]:
		if not await open_case("surface.motion",{"bounds":[32,336,1000,32],"surface_mode":mode},Vector2(100,310)): continue
		await ticks(20)
		check(session.player.is_on_floor(),"real support "+mode)
		session.controller.router.set_move_axis(1)
		await ticks(40)
		if mode=="sticky": check(session.player.normal_velocity.x <= session.player.tuning.ground_speed*.5+.01,"sticky caps walking only")
		else:
			var start := session.player.normal_velocity.x
			session.controller.router.set_move_axis(0)
			await ticks(4)
			check(session.player.normal_velocity.x > start-session.player.tuning.ground_deceleration*.06,"ice reduces braking")
		await close_case()
	if await open_case("platform.conveyor",{"bounds":[32,336,1000,32]},Vector2(100,310)):
		await ticks(20)
		var x := session.player.position.x
		await ticks(24)
		check(session.player.position.x > x+15,"floor conveyor moves standing actor")
		var conveyor: WorldConveyor = session.room.element_runtime.nodes.tested
		conveyor.element_restore(conveyor.element_propose("set_active",false))
		x = session.player.position.x
		await ticks(10)
		check(absf(session.player.position.x-x)<1,"disabled conveyor retains support")
		await close_case()
	for pattern: String in ["directional","vortex"]:
		if not await open_case("zone.environment",{"bounds":[0,0,500,500],"mode":"wind","wind_pattern":pattern,"wind_direction":[1,0]},Vector2(190,100),640): continue
		var zone: WorldEnvironmentZone
		for child: Node in session.room.get_children():
			if child is WorldEnvironmentZone: zone=child
		check(zone!=null,"room installs wind")
		await ticks(6)
		check(session.player.wind_velocity.length()>5,"free airborne motor integrates "+pattern)
		if pattern=="vortex":
			check(zone.wind_at(Vector2(350,250)).y>0 and zone.wind_at(Vector2(250,250))==Vector2.ZERO and zone.wind_at(Vector2(10,10))==Vector2.ZERO,"clockwise and zero/corner vortex samples")
			zone.vortex_direction="counterclockwise"
			check(zone.wind_at(Vector2(350,250)).y<0,"reversed tangent")
		await close_case()

func test_launchers() -> void:
	for mode: String in ["contact","surface_normal","radial_pulse"]:
		var props := {"position":[160,344],"launch_mode":mode,"pulse_interval_s":.4,"pulse_warning_s":.1}
		if mode=="radial_pulse": props.position=[160,381]
		if not await open_case("traversal.launcher",props,Vector2(160,245)): continue
		var launcher: WorldLauncher = session.room.element_runtime.nodes.tested
		var launched := false
		for frame: int in 70:
			await physics_frame
			if session.player.normal_velocity.y < -350: launched=true; break
		check(launched and launcher.serial==1,"real actor launched once "+mode)
		await close_case()

func test_bubble() -> void:
	if not await open_case("traversal.rising_bubble",{"position":[200,320],"rise_distance":96.0,"respawn_delay_s":.15},Vector2(170,310)): return
	var bubble: WorldRisingBubble = session.room.element_runtime.nodes.tested
	await ticks(18)
	check(bubble.stage=="rising" and bubble.position.y < 308,"bubble captures and carries real body")
	var jumps := session.controller.jump_ability.used_jumps
	session.controller.router.request_action(&"jump")
	await ticks(2)
	check(bubble.stage=="cooldown" and session.player.bubble_carrier==null,"first jump pops bubble")
	check(session.controller.jump_ability.used_jumps==jumps,"bubble exit preserves jump charges")
	await ticks(30)
	check(bubble.stage in ["ready","spawn_wait","rising"],"bubble respawns or waits for clearance")
	await close_case()

func test_portals() -> void:
	if not await open_case("traversal.portal_pair",{"position":[256,366],"paired_offset":[320,0]}): return
	var pair: WorldPortalPair = session.room.element_runtime.nodes.tested
	await ticks(5)
	session.controller.router.set_move_axis(1)
	await ticks(47)
	check(session.player.position.x>596,"walk through entry exits on opposite side")
	session.controller.router.set_move_axis(-1)
	await ticks(57)
	check(session.player.position.x<240,"exit unlocks after full body departs")
	pair.element_restore(pair.element_propose("set_active",false))
	session.player.reset_at(Vector2(220,366))
	session.controller.router.set_move_axis(1)
	await ticks(25)
	check(session.player.position.x<500,"disabled portal leaves normal movement")
	await close_case()

func test_block() -> void:
	if not await open_case("traversal.pull_block",{"position":[400,326],"endpoint":[160,0],"rest_progress":1.0,"ring_offset":[-60,0],"body_size":[96,32]},Vector2(310,332),350): return
	var block: WorldPullBlock = session.room.element_runtime.nodes.tested
	await try_grapple()
	await ticks(35)
	check(block.stage=="linked" and session.controller.traversal.state==&"object_pull","hook attaches to external ring without pulling player")
	check(block.progress < 160 and session.player.position.x<350,"object moves toward player")
	var progress := block.progress
	block.set_equipment_time(0)
	await ticks(10)
	check(is_equal_approx(block.progress,progress),"pull block holds under enchantment")
	session.controller.router.request_action(&"jump")
	await ticks(2)
	check(session.controller.traversal.state!=&"object_pull" and block.stage=="return_wait","jump releases linkage")
	block.set_equipment_time(1)
	await ticks(200)
	check(is_equal_approx(block.progress,160),"block returns to rest")
	await close_case()

func add_entity(doc: Dictionary, id: String, type: String, props: Dictionary) -> void:
	doc.entities[id] = {"id":id,"definition_id":type,"definition_version":1,"properties":props}

func test_recovery() -> void:
	var doc := document("traversal.hook_point",{"position":[244,360],"cooldown_s":.4})
	doc.root.properties.section_volumes = [{"id":"second","bounds":[700,0,550,640]}]
	add_entity(doc,"on_entry","recovery.anchor",{"bounds":[96,300,180,84],"point":[160,366]})
	add_entity(doc,"wrong_side","recovery.anchor",{"bounds":[96,300,180,84],"point":[430,366]})
	# The central ray sees through the gate gap. Neither the actor nor a retry may fit.
	add_entity(doc,"locked_bottom","platform.solid",{"rect":[360,368,16,16]})
	add_entity(doc,"locked_top","platform.solid",{"rect":[360,220,16,143]})
	add_entity(doc,"next","traversal.moving_hook",{"position":[790,260],"section_id":"second","initial_active":false})
	add_entity(doc,"cycle","traversal.moving_hook",{"position":[500,140],"phase_offset":.5})
	session = OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(doc)
	check(error.is_empty(),"C12 ordinary room opens "+error)
	if not error.is_empty(): return
	await ticks(7)
	check(session.recovery.selected.get("id")=="on_entry","C12 registers real entering side and rejects a body-width lock")
	var fixed: GrappleAnchor = session.room.element_runtime.nodes.tested
	var foreign: MovingGrappleAnchor = session.room.element_runtime.nodes.next
	var cycle: MovingGrappleAnchor = session.room.element_runtime.nodes.cycle
	foreign.element_restore(foreign.element_propose("set_active",true))
	await try_grapple()
	await ticks(27)
	check(fixed.attached and session.controller.traversal.state==&"hook_hang","C12 armed during real hanging session")
	var age := session.lifetime.actor_epoch
	var foreign_clock := foreign.path_clock
	session.controller.action_resources.shot_charges = 0
	session.controller.jump_ability.used_jumps = 1
	session.controller.traversal.hook_used = true
	session.controller.shoot_ability.cooldown_remaining = .7
	session.policy.environment_return_requested.emit()
	check(session.player.position.distance_to(Vector2(160,366))<.01 and session.lifetime.actor_epoch==age+1,"formal retry uses recorded side and invalidates departed actor")
	check(not fixed.attached and fixed.hook_session.is_empty() and fixed.remaining==0 and session.controller.traversal.state==&"free","retry terminates H and resets local anchor eligibility")
	check(is_equal_approx(cycle.path_clock,.5) and foreign.running and foreign.path_clock==foreign_clock,"retry restores local progress and preserves adjacent section")
	check(session.controller.action_resources.shot_charges==0 and session.controller.jump_ability.used_jumps==1 and session.controller.traversal.hook_used and is_equal_approx(session.controller.shoot_ability.cooldown_remaining,.7),"retry itself preserves spent air actions and shot cooldown")
	await ticks(3)
	check(session.player.is_on_floor() and session.controller.jump_ability.used_jumps==0,"normal physical landing then grants ground actions")
	session.player.reset_at(Vector2(850,366))
	await ticks(4)
	age = session.lifetime.actor_epoch
	session.policy.environment_return_requested.emit()
	check(session.recovery.selected.is_empty() and session.lifetime.actor_epoch==age and session.player.position.x>800,"crossing a challenge boundary drops the prior retry")
	await close_case()

func test_wall_belt() -> void:
	for direction: float in [-100.0,100.0]:
		if not await open_case("platform.conveyor",{"bounds":[300,40,30,380],"surface_mode":"wall","wall_face":"left","surface_speed":direction},Vector2(286,135),540): continue
		session.controller.traversal.grant(&"wall_climb")
		session.controller.router.set_move_axis(1)
		await ticks(13)
		var y := session.player.position.y
		var state := session.controller.traversal.state
		await ticks(13)
		check(state==&"wall_attach" and (session.player.position.y-y)*signf(direction)>5,"wall belt transports actual W attachment "+str(direction))
		await close_case()

func test_portal_facings() -> void:
	for facing: String in ["left","right","up","down"]:
		if not await open_case("traversal.portal_pair",{"position":[256,220],"paired_offset":[320,0],"facings":["left",facing]},Vector2(180,220)): continue
		await ticks(2)
		var pair: WorldPortalPair = session.room.element_runtime.nodes.tested
		var normal: Vector2 = pair.NORMALS[facing]
		var box := pair.player_box()
		session.player.recoil_velocity = Vector2(120,0)
		session.player.recoil_burst_remaining = .2
		session.controller.action_resources.shot_charges = 0
		var sent := pair.try_pass(0,box,Vector2(210,220),Vector2(245,220))
		check(sent and (session.player.global_position-pair.center(1)).dot(normal)>20,"exit on outside of "+facing)
		check(session.player.recoil_velocity.distance_to(normal*120)<.001 and is_equal_approx(session.player.recoil_burst_remaining,.2) and session.controller.action_resources.shot_charges==0,"rotates real impulse keeping timer and charges "+facing)
		check(not pair.try_pass(0,box,Vector2(210,220),Vector2(245,220)),"one transfer per physics step")
		await close_case()
	if await open_case("traversal.portal_pair",{"position":[256,220],"paired_offset":[320,153],"facings":["left","down"]},Vector2(180,220)):
		await ticks(2)
		var pair: WorldPortalPair = session.room.element_runtime.nodes.tested
		var at := session.player.position
		check(not pair.try_pass(0,pair.player_box(),Vector2(210,220),Vector2(245,220)) and pair.blocked and session.player.position == at,"solid at exit rejects transfer before moving actor")
		await close_case()

func test_sphere_normals() -> void:
	var center := Vector2(430,228)
	for normal: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.DOWN,Vector2(-1,-1).normalized()]:
		var start := center+normal*120
		if not await open_case("traversal.launcher",{"position":[center.x,center.y],"launch_mode":"surface_normal","sphere_radius":32,"launch_speed":500},start,600): continue
		var launcher: WorldLauncher = session.room.element_runtime.nodes.tested
		await ticks(2)
		session.player.start_weapon_burst(-normal,1300,.3)
		var launched := false
		for frame: int in 12:
			await physics_frame
			if launcher.serial>0:
				launched = session.player.normal_velocity.normalized().dot(normal)>.70
				break
		check(launched and launcher.serial==1,"sphere actual outward normal at "+str(normal))
		await close_case()

func test_bubble_ceiling() -> void:
	var doc := document("traversal.rising_bubble",{"position":[300,300],"bubble_radius":36,"rise_distance":180},Vector2(296,294),430)
	add_entity(doc,"ceiling","platform.solid",{"rect":[220,156,180,25]})
	session = OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(doc)
	check(error.is_empty(),"G26 ceiling fixture "+error)
	if not error.is_empty(): return
	var bubble: WorldRisingBubble = session.room.element_runtime.nodes.tested
	await ticks(12)
	check(session.player.bubble_carrier==bubble,"G26 side capture")
	for i: int in 130:
		await physics_frame
		if bubble.stage=="cooldown": break
	check(bubble.stage=="cooldown" and session.player.bubble_carrier==null,"G26 ceiling ends carrier")
	check(absf(session.player.position.y-(181+bubble.bubble_radius))<2.0,"G26 stops entire envelope at nearest ceiling "+str(session.player.position))
	await close_case()

func validation() -> void:
	for row: Array in [
		["traversal.hook",{"cooldown_s":0,"initial_available":false}],
		["traversal.hook_point",{"cooldown_s":-1}],
		["traversal.moving_hook",{"motion_mode":"zipline","endpoint":[64,0]}],
		["traversal.moving_hook",{"motion_mode":"retract","endpoint":[48,0],"retracted_length":48}],
		["traversal.launcher",{"launch_mode":"radial_pulse","pulse_warning_s":2.0}],
		["zone.environment",{"bounds":[0,0,64,32],"mode":"wind","wind_pattern":"vortex"}],
		["surface.motion",{"reverse_acceleration_scale":0}],
		["platform.conveyor",{"bounds":[0,0,-2,30]}],
		["traversal.rising_bubble",{"rise_speed":0}],
		["traversal.rising_bubble",{"bubble_radius":20.0}],
		["traversal.portal_pair",{"facings":["AA","BB"]}],
		["traversal.pull_block",{"ring_offset":[0,0]}]]:
		var result := WorldRoomDocument.instantiate(document(row[0],row[1]))
		check(result.has("error"),"reject invalid "+str(row))
		if result.has("room"):result.room.free()

func run() -> void:
	validation()
	await test_hooks()
	await test_surfaces()
	await test_launchers()
	await test_bubble()
	await test_portals()
	await test_block()
	await test_wall_belt()
	await test_portal_facings()
	await test_recovery()
	await test_sphere_normals()
	await test_bubble_ceiling()
	check(checks >= 130,"all gameplay cases exercised")
	print("TRAVERSAL LIBRARY failures=",failures," checks=",checks)
	quit(1 if failures else 0)
