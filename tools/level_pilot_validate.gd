extends SceneTree
## Isolated design pilot: the existing Module -> Router -> Controller -> Motor.
## Spawn is a fixture; after spawn no position/resource/tuning writes occur.
const PLAYER := preload("res://game/player/player.tscn")
const AUDIO := preload("res://tests/audio_teardown.gd")
const DT := 1.0 / 60.0
var candidate := "plains_overlook_choice"
var strategy := "reward"
var catalog_path := "res://config/level_pilot_candidates.json"
var variant := 0
var genome: Dictionary = {}
var blueprint := ""
var existing := false
var output := "res://build/ai_level_design_v1/pilot.json"
var world: Node2D
var module: PlatformingModule
var motor: PlayerMotor
var controller: PlayerController
var frames: Array[Dictionary] = []
var events: Array[Dictionary] = []
var failures: Array[String] = []
var contacts: Array[Dictionary] = []
var count := 0
var previous := Vector2.ZERO
var event_cursor := 0
var suppress_jump := false
var max_ticks := 2400
var routes: Dictionary = {}
var goal_index := 0
var reward_index := 0
var visited_reward := false
var returned_after_reward := false
var return_index := 0
var pending_step := "spawn"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--candidate="): candidate = arg.trim_prefix("--candidate=")
		elif arg.begins_with("--catalog="): catalog_path = arg.trim_prefix("--catalog=")
		elif arg.begins_with("--variant="): variant = int(arg.trim_prefix("--variant="))
		elif arg.begins_with("--strategy="): strategy = arg.trim_prefix("--strategy=")
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	run.call_deferred()

func point(value: Vector2) -> Array:
	return [value.x,value.y]

func port(id: String, at: Vector2) -> PlatformingModulePort:
	var value := PlatformingModulePort.new()
	value.port_id = StringName(id)
	value.position = at
	return value

func make_definition() -> PlatformingModuleDefinition:
	var d := PlatformingModuleDefinition.new()
	d.module_id = StringName(candidate)
	# v2: the playable footprint includes the open air above the upper bough.
	# r1's y=0 authoring rectangle excluded a legal full-held jump from y=94
	# (actual apex -56.39), even though no ceiling collider exists there.
	# Keep the original outside-bounds guard and lower/side boundaries.
	d.definition_version = 3
	d.world_bounds = Rect2(0,-256,840,656)
	if blueprint in ["plains_low_arch","plains_long_meadow","forest_root_meadow"]:
		existing = true
		if blueprint.begins_with("plains_"):
			d = load("res://resources/generation/modules/"+blueprint+".tres").duplicate(true) as PlatformingModuleDefinition
			if d.main_route.is_empty():
				d.main_route.assign([0,d.anchors.size()-1])
		else:
			var source := ForestExplorationModules.build("root_meadow")
			d.world_bounds = Rect2(float(source.world_bounds[0]),float(source.world_bounds[1]),float(source.world_bounds[2]),float(source.world_bounds[3]))
			for row: Dictionary in source.platforms:
				var r: Array = row.rect
				d.platforms.append(Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3])))
				if row.one_way: d.one_way_platform_indices.append(d.platforms.size()-1)
			d.anchors.append(Vector2(source.spawn[0],source.spawn[1]))
			for step: Dictionary in source.steps:
				d.anchors.append(Vector2(step.landing[0],step.landing[1]))
			for index: int in d.anchors.size(): d.main_route.append(index)
			d.entry_port = port("entry",d.anchors[0])
			d.exit_port = port("exit",d.anchors[-1])
			d.module_id = &"forest_root_meadow"
		routes = {"main":d.main_route.duplicate(),"reward":d.main_route.duplicate()}
		goal_index = d.anchors.size()-1
		reward_index = goal_index; return_index = goal_index
		return d
	if blueprint == "plains_overlook_choice":
		d.platforms.assign([Rect2(0,240,800,48),Rect2(220,176,160,16),Rect2(430,112,180,16)])
		d.one_way_platform_indices.assign([1,2])
		d.anchors.assign([Vector2(40,222),Vector2(180,222),Vector2(260,158),Vector2(348,158),Vector2(470,94),Vector2(560,94),Vector2(680,222),Vector2(760,222)])
		routes = {"main":[0,7],"reward":[0,1,2,3,4,5,6,7]}
		reward_index = 5; return_index = 6
	elif blueprint == "plains_backlook_cache":
		d.platforms.assign([Rect2(0,240,220,48),Rect2(300,240,180,48),Rect2(560,240,240,48),Rect2(480,176,120,16),Rect2(270,112,160,16)])
		d.one_way_platform_indices.assign([3,4])
		d.anchors.assign([Vector2(40,222),Vector2(180,222),Vector2(340,222),Vector2(448,222),Vector2(520,158),Vector2(380,94),Vector2(460,222),Vector2(448,222),Vector2(600,222),Vector2(760,222)])
		routes = {"main":[0,1,2,3,8,9],"reward":[0,1,2,3,4,5,6,7,8,9]}
		reward_index = 5; return_index = 6
	elif blueprint == "forest_crown_root_choice":
		d.platforms.assign([Rect2(0,240,220,48),Rect2(620,240,180,48),Rect2(180,288,500,48),Rect2(270,176,160,16),Rect2(500,176,120,16)])
		d.one_way_platform_indices.assign([3,4])
		d.anchors.assign([Vector2(40,222),Vector2(180,222),Vector2(300,158),Vector2(398,158),Vector2(540,158),Vector2(588,158),Vector2(680,222),Vector2(760,222),Vector2(300,270),Vector2(580,270)])
		routes = {"main":[0,1,8,9,6,7],"reward":[0,1,2,3,4,5,6,7]}
		reward_index = 4; return_index = 6
	elif blueprint == "forest_basin_homecoming":
		d.platforms.assign([Rect2(0,176,220,16),Rect2(160,288,480,48),Rect2(60,236,160,8),Rect2(450,224,120,16),Rect2(620,176,180,48)])
		d.one_way_platform_indices.assign([0,2,3])
		d.anchors.assign([Vector2(40,158),Vector2(180,158),Vector2(300,270),Vector2(200,270),Vector2(100,218),Vector2(80,158),Vector2(180,158),Vector2(300,270),Vector2(420,270),Vector2(490,206),Vector2(538,206),Vector2(660,158),Vector2(760,158)])
		routes = {"main":[0,1,2,8,9,10,11,12],"reward":[0,1,2,3,4,5,6,7,8,9,10,11,12]}
		reward_index = 3; return_index = 5
	else:
		return null
	# Consumed relation gene: bypass the actual homecoming cycle while retaining
	# the same geometry, seed and physics. This is a relation, not a title tag.
	if blueprint == "forest_basin_homecoming" and genome.get("route_order","") == "reward_then_progress":
		routes.reward = [0,1,2,3,8,9,10,11,12]
		return_index = 8
	# Deliberate same-relation geometry control for novelty discrimination.
	if variant == 1:
		for index: int in d.one_way_platform_indices:
			if index == 0: continue
			var old := d.platforms[index]
			d.platforms[index] = Rect2(old.position+Vector2(0,-8),old.size)
			for ai: int in d.anchors.size():
				var at := d.anchors[ai]
				if absf(at.y+18-old.position.y)<0.1 and at.x>=old.position.x and at.x<=old.end.x: d.anchors[ai] = at+Vector2(0,-8)
	goal_index = int(routes.main[-1])
	d.entry_port = port("entry",d.anchors[0])
	d.exit_port = port("exit",d.anchors[goal_index])
	d.main_route.assign(routes.main)
	var branch := PackedInt32Array(routes.reward)
	d.branch_routes.assign([branch])
	d.min_jumps = 1
	return d

func check(ok: bool, label: String) -> void:
	if not ok and label not in failures: failures.append(label)

func is_trace_cancelled() -> bool:
	return count >= max_ticks or not contacts.is_empty()

func tick(n: int = 1) -> void:
	for unused: int in n:
		if count >= max_ticks: return
		await physics_frame
		var requests: Array = []
		for action: Dictionary in controller.router._queue:
			requests.append({"type":str(action.type),"direction":point(action.direction),"sequence":action.sequence})
		if suppress_jump:
			controller.router.cancel_actions_for(&"jump")
		var axis := controller.router.axis
		var motion_before := motor.motion_steps
		controller.physics_tick(DT)
		if motor.motion_steps-motion_before != 1: check(false,"not_exactly_one_real_motor_step")
		count += 1
		var pos := motor.global_position
		var shape := motor.get_node("CollisionShape2D") as CollisionShape2D
		var half := (shape.shape as RectangleShape2D).size / 2.0
		var swept := Rect2(previous-half,half*2.0).merge(Rect2(pos-half,half*2.0))
		for danger: Rect2 in module.world_static_dangers():
			if swept.intersects(danger,true): contacts.append({"frame":count,"kind":"static_full_body_sweep","danger":[danger.position.x,danger.position.y,danger.size.x,danger.size.y]})
		if not module.definition.world_bounds.grow(24).has_point(pos):
			check(false,"outside_candidate_bounds")
		if pos.distance_to(previous) > 30.0: check(false,"unexpected_discontinuity")
		var new_events := events.slice(event_cursor)
		event_cursor = events.size()
		if motor.is_on_floor() and pos.distance_to(module.definition.anchors[reward_index]) < 14.0:
			visited_reward = true
		if visited_reward and motor.is_on_floor() and pos.distance_to(module.definition.anchors[return_index]) < 14.0:
			returned_after_reward = true
		frames.append({"frame":count,"position":point(pos),"normal_velocity":point(motor.normal_velocity),"velocity":point(motor.normal_velocity+motor.recoil_velocity),"recoil_velocity":point(motor.recoil_velocity),"grounded":motor.is_on_floor(),"motion_steps":motor.motion_steps,"requested_actions":requests,"accepted_events":new_events,"accepted_actions":new_events,"axis":axis,"shots":controller.action_resources.shot_charges,"stamina":controller.actor_resources.stamina.current,"jump_suppressed":suppress_jump,"step":pending_step})
		previous = pos

func direct_recoil(target: Vector2) -> bool:
	controller.router.request_action(&"jump")
	for frame: int in 170:
		controller.router.set_move_axis(clampf((target.x-motor.position.x)/5.5,-1.0,1.0))
		if frame == 18: controller.router.request_action(&"shoot_release",Vector2.DOWN)
		await tick()
		if frame > 20 and motor.is_on_floor():
			controller.router.request_action(&"jump_release")
			controller.router.set_move_axis(0)
			await tick(3)
			return absf(target.y-motor.position.y)<1.0 and absf(target.x-motor.position.x)<14.0
	return false


func short_jump_to(driver: Variant, target: Vector2, release_frame := 6) -> bool:
	# Same legal Router inputs as the generic full-held driver, but cut ascent.
	# This tests the lower route rather than accidentally landing on its upper
	# alternative. It does not move the body or reset any state.
	controller.router.request_action(&"jump")
	for frame: int in 110:
		controller.router.set_move_axis(clampf((target.x-motor.position.x)/5.5,-1.0,1.0))
		if frame == release_frame: controller.router.request_action(&"jump_release")
		await tick()
		if is_trace_cancelled(): return false
		if frame > 3 and motor.is_on_floor():
			controller.router.set_move_axis(0)
			controller.router.request_action(&"jump_release")
			await tick(2)
			var supported: bool = driver._floor_contains_segment(motor.position,target)
			if absf(target.y-motor.position.y) >= 1.0 or not supported:
				check(false,"short_release_landed_on_wrong_actual_support")
				return false
			return await driver.move_to(target.x)
	check(false,"short_release_bounded_driver_did_not_land")
	return false

func backlook_route(driver: Variant, include_reward: bool) -> bool:
	pending_step = "short_release_crossing_below_upper_cache"
	if not await driver.move_to(208.0): return false
	if not await short_jump_to(driver,module.definition.anchors[2]): return false
	if include_reward:
		pending_step = "backlook_climb_reverse_and_actual_return"
		if not await driver.follow_path(module,motor,tick,check,[2,3,4,5,6,7]): return false
	pending_step = "late_takeoff_full_jump_clears_overhead_receiver"
	# A full jump remains legal and avoids landing on the intermediate branch
	# when it starts at the real bank edge and continues beyond that branch.
	if not await driver.move_to(466.0): return false
	if not await driver.jump_to(Vector2(660.0,222.0)): return false
	return await driver.move_to(module.definition.exit_port.position.x)

func crown_lower_route(driver: Variant) -> bool:
	pending_step = "walk_off_to_lower_root_without_jumping_into_upper_branch"
	if not await driver.move_to(300.0): return false
	if not await driver.land(): return false
	if absf(motor.position.y-270.0)>=1.0:
		check(false,"walk_off_did_not_reach_lower_root")
		return false
	if not await driver.move_to(600.0): return false
	pending_step = "lower_root_to_shared_exit"
	if not await driver.jump_to(Vector2(680.0,222.0)): return false
	return await driver.move_to(module.definition.exit_port.position.x)

func basin_reward_route(driver: Variant) -> bool:
	pending_step = "actual_descent_and_basin_reward_location"
	if not await driver.follow_path(module,motor,tick,check,[0,1,2,3]): return false
	pending_step = "short_release_to_return_mushroom_below_departure"
	if not await short_jump_to(driver,module.definition.anchors[4]): return false
	pending_step = "actual_homecoming_then_onward_ascent"
	return await driver.follow_path(module,motor,tick,check,[4,5,6,7,8,9,10,11,12])

func run() -> void:
	if strategy not in ["main","reward","direct","near_reward","no_jump"]:
		printerr("LEVEL PILOT invalid strategy"); quit(2); return
	if variant not in [0,1]: printerr("LEVEL PILOT invalid variant"); quit(2); return
	var catalogue: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	if not catalogue is Dictionary or catalogue.get("schema_version") != 1:
		printerr("LEVEL PILOT invalid catalogue"); quit(2); return
	var selected: Dictionary = {}
	for row: Dictionary in catalogue.get("candidates",[]):
		if str(row.id) == candidate: selected = row; break
	if selected.is_empty(): printerr("LEVEL PILOT candidate absent from catalogue"); quit(2); return
	blueprint = str(selected.get("blueprint",candidate))
	genome = selected.get("gene",{})
	if genome.get("route_order","") not in ["existing_main","reward_then_progress","reward_then_return_then_progress"]:
		printerr("LEVEL PILOT unknown route_order gene"); quit(2); return
	var definition := make_definition()
	if definition == null or not definition.is_valid():
		printerr("LEVEL PILOT invalid candidate definition: "+candidate); quit(2); return
	world = Node2D.new()
	root.add_child(world)
	module = PlatformingModule.new()
	module.definition = definition
	world.add_child(module)
	motor = PLAYER.instantiate() as PlayerMotor
	motor.position = definition.entry_port.position # Initial fixture spawn only.
	world.add_child(motor)
	controller = motor.get_node("Controller") as PlayerController
	controller.set_physics_process(false)
	motor.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	if not controller.enable_shot_energy():
		printerr("LEVEL PILOT shot energy profile unavailable"); quit(2); return
	controller.jump_ability.jumped.connect(func() -> void: events.append({"frame":count+1,"type":"jump_executed"}))
	controller.shoot_ability.shot_fired.connect(func(direction: Vector2, serial: int) -> void: events.append({"frame":count+1,"type":"shot_fired","direction":point(direction),"serial":serial}))
	controller.router.action_rejected.connect(func(reason: String) -> void: events.append({"frame":count+1,"type":"router_rejected","reason":reason}))
	previous = motor.position
	await physics_frame
	await process_frame
	await tick(6)
	var actual_entry := module.port_accepts(definition.entry_port,motor)
	var tuning := {"max_jumps":motor.tuning.max_jumps,"max_air_shots":motor.tuning.max_air_shots,"ground_speed":motor.tuning.ground_speed,"recoil_mode":motor.tuning.recoil_mode,"source_sha256":FileAccess.get_sha256("res://config/player_tuning.json")}
	var driver = load("res://tests/branch_module_driver.gd").new()
	# Configure the existing helper once for the finite local input policies.
	driver.module = module
	driver.motor = motor
	driver.controller = controller
	driver.tick_callback = tick
	driver.check = check
	var reached := false
	if strategy == "direct":
		pending_step = "strong_sample_full_held_jump_plus_downward_recoil_direct_to_reward"
		reached = await direct_recoil(definition.anchors[reward_index])
	elif strategy == "near_reward":
		# A strong legal alternative: approach beneath the prize first, then
		# full-jump from the actual nearby support. Never teleport to the takeoff.
		pending_step = "walk_under_reward_then_one_full_jump"
		if blueprint == "plains_overlook_choice":
			reached = await driver.move_to(definition.anchors[reward_index].x)
			if reached: reached = await driver.land()
		elif blueprint == "forest_crown_root_choice":
			reached = await driver.move_to(300.0)
			if reached: reached = await driver.land()
			if reached: reached = await driver.move_to(definition.anchors[reward_index].x)
			if reached: reached = await driver.land()
		else:
			check(false,"near_reward_policy_not_implemented_for_this_blueprint")
		if reached: reached = await driver.jump_to(definition.anchors[reward_index])
	else:
		suppress_jump = strategy == "no_jump"
		pending_step = "reward_and_return" if strategy != "main" else "cheap_main_full_held_jump"
		var route: Array = routes.main if strategy == "main" else routes.reward
		if existing and blueprint == "plains_low_arch":
			reached = await driver.traverse(module,motor,tick,check)
		elif blueprint == "plains_backlook_cache":
			reached = await backlook_route(driver,strategy != "main")
		elif blueprint == "forest_crown_root_choice" and strategy == "main":
			reached = await crown_lower_route(driver)
		elif blueprint == "forest_basin_homecoming" and strategy != "main" and genome.get("route_order","") == "reward_then_return_then_progress":
			reached = await basin_reward_route(driver)
		else:
			reached = await driver.follow_path(module,motor,tick,check,route)
	var targets_reward := strategy in ["direct","near_reward"]
	var terminal_target: Vector2 = definition.anchors[reward_index] if targets_reward else definition.exit_port.position
	var actual_goal := motor.is_on_floor() and motor.position.distance_to(terminal_target) < 14.0
	var actual_exit := module.port_accepts(definition.exit_port,motor) if not targets_reward else false
	var safe := contacts.is_empty() and failures.is_empty()
	var branch_complete := strategy != "reward" or (visited_reward and returned_after_reward)
	var passed := reached and actual_goal and safe and branch_complete
	var input_identity := {"catalog_item":selected,"candidate":candidate,"strategy":strategy,"variant":variant,"tuning":tuning}
	var data := {"id":candidate,"condition":strategy,"ok":passed,"real_motor":true,"source_fingerprint":FoundryCatalog.basis(),"input_fingerprint":JSON.stringify(input_identity).sha256_text(),"schema_version":1,"candidate":candidate,"strategy":strategy,"blueprint":blueprint,"variant":variant,"genome":genome,"catalog_path":catalog_path.trim_prefix("res://"),"catalog_sha256":FileAccess.get_sha256(catalog_path),"seed":"level-pilot-v1/"+candidate,"scope":"isolated_existing_Module_Router_Controller_Motor_reachability_only","runtime_consumer":"game/world/components/platforming_module.gd","source_hash":FileAccess.get_sha256("res://tools/level_pilot_validate.gd"),"engine":Engine.get_version_info().string,"tuning":tuning,"passed":passed,"driver_reached":reached,"actual_goal":actual_goal,"entry_contract":actual_entry,"exit_contract":actual_exit,"visited_reward_location":visited_reward,"returned_after_reward":returned_after_reward,"reward_claim":"unverified_no_reward_entity_in_this_fixture","frames":frames,"events":events,"danger_contacts":contacts,"failures":failures,"geometry":[],"anchors":[],"routes":routes,"midroute_injection":false,"resource_override":false,"initial_fixture_spawn_override":true,"manual_motor_step":false,"manual_controller_tick":true,"physics_step":"same existing Controller.physics_tick/manual consumer pattern as Foundry; no extra Motor step","production_pool":false,"fun":"unverified","device":"unverified","strong_alternative_scope":"one full-held-jump plus legal downward recoil sample, not exhaustive reachability"}
	if strategy == "near_reward": data.strong_alternative_scope = "walk from spawn beneath reward then one full jump; bounded legal strategy"
	for rect: Rect2 in definition.platforms: data.geometry.append([rect.position.x,rect.position.y,rect.size.x,rect.size.y])
	for at: Vector2 in definition.anchors: data.anchors.append(point(at))
	var clean := await AUDIO.drain_world(world)
	data.audio_released = clean
	data.passed = passed and clean
	data.ok = data.passed
	data.exit_code = 0 if data.passed else 1
	world.free()
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	print("LEVEL PILOT RECEIPT_SHA256: "+FileAccess.get_sha256(output))
	print("LEVEL PILOT: "+("PASS" if data.passed else "FAIL")+" / "+candidate+" / "+strategy+" / frames="+str(count)+" / "+str(failures))
	quit(0 if data.passed else 1)
