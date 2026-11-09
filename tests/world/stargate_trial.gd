extends SceneTree
## Continuous real inputs in the packaged workbench draft. No mid-route resets/grants.
var app: FixedWorldApp
var failures := 0
var frame := 0
var route_start_engine_frame := 0
var trace: Array[Dictionary] = []
var stage_events: Array[Dictionary] = []
var start_hp := 0.0
var count_hooks := 0
var count_wall_jumps := 0
var count_air_jumps := 0
var count_shots := 0
var count_landings := 0
var protected_curtains: Dictionary = {}
var continuous_result: Dictionary = {}
var validation_results: Dictionary = {}
var scene_source := ""
var capture := false
var output := "res://build/stargate_trial"

func _initialize() -> void: run.call_deferred()

func snapshot(label: String = "") -> Dictionary:
	var camera_center := app.camera.get_screen_center_position()
	return {"frame":frame,"label":label,"position":[app.player.position.x,app.player.position.y],"velocity":[app.player.velocity.x,app.player.velocity.y],"grounded":app.player.is_on_floor(),"traversal":str(app.controller.traversal.state),"air_shots":app.controller.action_resources.shot_charges,"jumps_used":app.controller.jump_ability.used_jumps,"q_ready":app.q_guard.landing_ready,"q_cooldown":app.q_guard.cooldown,"q_active":app.q_guard.active,"hp":app.controller.actor_resources.health.current,"entry_anchor":[app.entry_anchor.x,app.entry_anchor.y],"camera_center":[camera_center.x,camera_center.y],"camera_zoom":[app.camera.zoom.x,app.camera.zoom.y]}

func ticks(n: int) -> void:
	for i: int in n:
		await physics_frame
		frame += 1
		if app != null and app.player != null and frame%3 == 0: trace.append(snapshot())

func check(ok: bool, label: String) -> bool:
	print("STARGATE ",ok," ",label)
	if not ok: failures += 1
	return ok

func mark(label: String) -> void:
	var row := snapshot(label)
	stage_events.append(row)
	print("STARGATE_EVENT ",JSON.stringify(row))

func controls(axis: float) -> void:
	app.controller.router.set_source_axis(&"keyboard_mouse",axis)

func press_jump() -> void:
	app.controller.router.set_jump_held(&"keyboard_mouse",false)
	await ticks(1)
	app.controller.router.set_jump_held(&"keyboard_mouse",true)

func hook(point: Vector2, label: String) -> bool:
	controls(0)
	app.controller.router.set_jump_held(&"keyboard_mouse",false)
	var half := app.camera.get_viewport_rect().size/(2*app.camera.zoom)
	var view := Rect2(app.camera.get_screen_center_position()-half,half*2).grow(-8)
	check(view.has_point(point),label+" target is visible in the unchanged normal camera before H")
	app.controller.router.request_action(&"grapple",(point-app.player.position-Vector2(0,-6)).normalized())
	for i: int in 100:
		await ticks(1)
		if app.controller.traversal.state == &"hook_hang" and app.controller.traversal.hook_tip.distance_to(point)<16:
			mark(label)
			return check(app.controller.actor_resources.health.current==start_hp,label+" reached without damage")
	return check(false,label+" hook timed out "+JSON.stringify(snapshot()))

func burst(aim: Vector2, label: String) -> bool:
	check(app.q_guard.landing_ready and app.q_guard.cooldown<=0,label+" has true-ground Q eligibility and elapsed cooldown")
	app.controller.router.request_action(&"shoot_release",aim)
	await ticks(10)
	mark(label)
	var body := Rect2(app.player.position-Vector2(12,18),Vector2(24,36))
	for zone: Dictionary in app.room.environment_zones:
		if zone.mode=="phase_light": check(not FixedWorldProvider.rect(zone.bounds).intersects(body),label+" clears the full body before recoil ends")
	return check(app.controller.actor_resources.health.current==start_hp and app.controller.action_resources.shot_charges==0,label+" crosses on the actual one-shot budget")

func wall_chain(direction: float, hook_target: Vector2, label: String) -> bool:
	# A held ring offers real observation time; this never grants ground resources.
	await ticks(18)
	var wall: Rect2=app.room.climbable_walls[0 if direction>0 else 1]
	var half := app.camera.get_viewport_rect().size/(2*app.camera.zoom)
	var view := Rect2(app.camera.get_screen_center_position()-half,half*2).grow(-8)
	check(view.has_point(Vector2(wall.get_center().x,wall.end.y-16)),label+" raised wall is visible before leaving the ring")
	controls(direction)
	await press_jump()
	await ticks(16)
	await press_jump()
	var attached := false
	for i: int in 75:
		await ticks(1)
		if app.controller.traversal.state==&"wall_attach": attached=true;break
	if not check(attached,label+" reaches the raised W wall using D "+JSON.stringify(snapshot())): return false
	mark(label+" attach")
	await press_jump()
	await ticks(1)
	controls(-direction)
	await ticks(15)
	app.controller.router.set_jump_held(&"keyboard_mouse",false)
	return await hook(hook_target,label+" exit hook")

func land(target_x: float, label: String) -> bool:
	await press_jump()
	for i: int in 150:
		var dx := target_x-app.player.position.x
		controls(signf(dx) if absf(dx)>3 else 0)
		if i==7: app.controller.router.set_jump_held(&"keyboard_mouse",false)
		await ticks(1)
		if app.player.is_on_floor():
			controls(0)
			await ticks(2)
			mark(label)
			return check(app.controller.actor_resources.health.current==start_hp,label+" is real ground contact")
	return check(false,label+" did not land "+JSON.stringify(snapshot()))

func picture(name: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")

func finish() -> void:
	var report := {"schema":1,"room_id":"V-R12","stage":"hwdq","scene_sha256":scene_source,"physics_hz":Engine.physics_ticks_per_second,"real_input_only":true,"complete":failures==0,"failures":failures,"frames":frame,"hooks":count_hooks,"wall_jumps":count_wall_jumps,"extra_air_jumps":count_air_jumps,"shots":count_shots,"landings":count_landings,"protected_curtains":protected_curtains,"continuous_route":continuous_result,"validation":validation_results,"events":stage_events,"trace":trace}
	var file := FileAccess.open(output+"/trace.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	await WorldAudioLifecycle.drain_world(app)
	app.queue_free()
	await process_frame
	await process_frame
	print("STARGATE TRIAL: ",failures," failures")
	quit(failures)

func setup_trial() -> bool:
	root.size=Vector2i(1280,720)
	capture = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(output)
	scene_source = FileAccess.get_sha256("res://game/world/regions/V/rooms/V-R12.tscn")
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://stargate_trial_campaign.json"
	root.add_child(app)
	app.workbench.enabled=true
	var scene := preload("res://game/world/regions/V/rooms/V-R12.tscn").instantiate() as FixedWorldRoom
	var draft := WorldRoomDraft.extract(scene)
	scene.free()
	draft.base_content_version=app.content.workbench_base_version()
	draft.revision=1
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FixedWorldProvider.WORKBENCH_CATALOG))
	var contract: Dictionary=catalog.rooms["V-R12"]
	draft.geometry={"bounds":contract.world_geometry.bounds_world_units,"space_rects":contract.world_geometry.space_rects,"doors":contract.doors}
	await app.workbench._handle({"channel":"gunman-workbench","type":"load_draft","request_id":"stargate_trial","revision":1,"draft":draft,"stage":"hwdq","paused":false})
	if not check(app.workbench.last_event.get("type")=="draft_loaded","real bridge loads isolated V-R12 hwdq "+JSON.stringify(app.workbench.last_event)): return false
	start_hp=app.controller.actor_resources.health.current
	var normal_guard := app.policy.transient_protection
	app.policy.transient_protection=func(request: DamageRequest) -> bool:
		var accepted: bool=normal_guard.call(request)
		if accepted and request.hazard_category==&"phase_light":
			var id := str(request.source_id)
			protected_curtains[id]=int(protected_curtains.get(id,0))+1
		return accepted
	app.controller.traversal.hook_contact.connect(func(_point: Vector2) -> void: count_hooks+=1)
	app.controller.traversal.action_changed.connect(func(action: StringName) -> void: if action==&"wall_kick": count_wall_jumps+=1)
	app.controller.jump_ability.jumped.connect(func() -> void: if app.controller.jump_ability.used_jumps==2: count_air_jumps+=1)
	app.controller.shoot_ability.shot_fired.connect(func(_direction: Vector2,_id: int) -> void: count_shots+=1)
	app.controller.landed.connect(func() -> void: count_landings+=1)
	await ticks(90)
	count_landings=0
	route_start_engine_frame=Engine.get_physics_frames()
	mark("entry")
	await picture("01-entry-normal-camera")
	return true

func lower_launch_route() -> bool:
	controls(1)
	await press_jump()
	await ticks(12)
	if not await hook(Vector2(320,1656),"lower rise"): return false
	if not await hook(Vector2(480,1544),"lower crown"): return false
	await picture("02-lower-fold-normal-camera")
	if not await hook(Vector2(560,1744),"lower downward fold"): return false
	if not await burst(Vector2.LEFT,"lower Q right"): return false
	if not await hook(Vector2(768,1712),"lower recoil recovery"): return false
	if not await hook(Vector2(880,1584),"east launch"): return false
	return failures==0

func lower_route() -> bool:
	if not await lower_launch_route(): return false
	if not await wall_chain(1,Vector2(800,1024),"east D-W-H"): return false
	if not await land(720,"relay"): return false
	check(app.entry_anchor.distance_to(Vector2(720,1198))<2,"relay records only after real safe-platform arrival")
	await picture("03-relay-normal-camera")
	return failures==0

func walk_ground(target_x: float, label: String) -> bool:
	app.controller.router.set_jump_held(&"keyboard_mouse",false)
	for i: int in 240:
		var dx := target_x-app.player.position.x
		controls(signf(dx) if absf(dx)>3 else 0)
		await ticks(1)
		if absf(dx)<=4 and app.player.is_on_floor():
			controls(0)
			mark(label)
			return true
	return check(false,label+" walk did not finish")

func verify_return() -> void:
	await walk_ground(864,"return lever approach")
	app.controller.router.request_action(&"interact")
	await ticks(15)
	if not check(app.state.has("starbridge_v12_return_open"),"actual goal-side interaction opens only the return bridge"): return
	# Declared counterexample starts after the completed flight: no traversal powers.
	var candidate := app.state.value.duplicate(true)
	for id: String in ["H","W","D","Q"]: candidate.flags.erase(id)
	check(app.state.commit(candidate,app.state.revision),"isolated post-goal no-ability fixture commits")
	app._apply_capabilities()
	check(not app.controller.traversal.hook_enabled and not app.controller.traversal.wall_enabled and not app.controller.traversal.double_enabled and not app.q_guard.owned,"return uses no H/W/D/Q")
	if not await walk_ground(120,"return bridge crossing"): return
	app.controller.router.request_action(&"drop_through")
	var returned := false
	for i: int in 210:
		await ticks(1)
		if app.player.is_on_floor() and app.player.position.y>1800: returned=true;break
	controls(0)
	await ticks(2)
	validation_results.return_without_abilities=check(returned and app.controller.actor_resources.health.current==start_hp and app.entry_anchor.distance_to(Vector2(144,1838))<2,"return bridge and safe fall reach original entrance without powers or damage")
	mark("return entrance")
	await picture("06-return-normal-camera")

func run() -> void:
	if not await setup_trial(): await finish();return
	if not await lower_route(): await finish();return
	while app.q_guard.cooldown>0: await ticks(1)
	await ticks(45)
	if not await hook(Vector2(704,1024),"upper launch"): await finish();return
	if not await burst(Vector2.RIGHT,"upper Q left"): await finish();return
	if not await hook(Vector2(496,1024),"upper recoil recovery"): await finish();return
	controls(-1)
	await press_jump()
	await ticks(12)
	if not await hook(Vector2(352,864),"west launch"): await finish();return
	if not await wall_chain(-1,Vector2(448,304),"west D-W-H"): await finish();return
	await picture("04-upper-switchback-normal-camera")
	if not await hook(Vector2(640,400),"high fold"): await finish();return
	controls(1)
	await press_jump()
	await ticks(12)
	if not await hook(Vector2(824,256),"finish catch"): await finish();return
	if not await land(880,"finish"): await finish();return
	check(Rect2(796,280,216,40).has_point(app.player.position),"continuous entry-to-finish safe-platform arrival")
	check(count_hooks>=12 and count_wall_jumps>=2 and count_air_jumps>=2 and count_shots==2,"repeated actual H/W/D and two actual ground-qualified Q shots")
	check(count_landings==2,"exactly relay and finish landing between entry and goal")
	check(protected_curtains.size()==2,"two different actual light curtains were accepted by the real Q consumer")
	continuous_result={"completed":failures==0,"entry_frame":90,"finish_frame":frame,"entry_engine_frame":route_start_engine_frame,"finish_engine_frame":Engine.get_physics_frames(),"seconds":float(Engine.get_physics_frames()-route_start_engine_frame)/Engine.physics_ticks_per_second,"hooks":count_hooks,"wall_jumps":count_wall_jumps,"extra_air_jumps":count_air_jumps,"shots":count_shots,"landings":count_landings,"protected_curtains":protected_curtains.duplicate(true),"hp_remaining":app.controller.actor_resources.health.current}
	await picture("05-finish-normal-camera")
	await ticks(90)
	await verify_return()
	await finish()
