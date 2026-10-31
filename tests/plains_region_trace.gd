extends "res://tests/plains_run_trace.gd"
## Every itinerary uses one world and one spawn. No mid-route reset/teleport.
var audio_teardown: Script
var lifetime := DemoLifetime.new()
var region_state := PlainsRegionState.new()
var route_edges := 0

func fixture(manifest: Dictionary, tuning: PlayerTuning) -> bool:
	if is_trace_cancelled(): return false
	if audio_teardown == null: audio_teardown = load("res://tests/audio_teardown.gd")
	if is_instance_valid(world) and not await release_test_world(): return false
	world = Node2D.new()
	tree.root.add_child(world)
	stage = PlainsRegionAssembler.new()
	region_state = PlainsRegionState.new()
	region_state.bind_map(str(manifest.manifest_hash))
	stage.region_state = region_state
	world.add_child(stage)
	var replay: Dictionary = JSON.parse_string(JSON.stringify(manifest))
	if not stage.build(replay,tuning).ok: return false
	motor = PLAYER.instantiate()
	motor.position = stage.world_entry()
	world.add_child(motor)
	controller = motor.get_node("Controller")
	check.call(controller.enable_shot_energy(),"formal route uses real shot energy")
	controller.set_physics_process(false)
	motor.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	controller.action_resources.reset()
	shots = 0
	route_edges=0
	trace_ticks = 0
	safe_trace = true
	continuous_trace = true
	previous_body = Rect2(motor.global_position-Vector2(12,18),Vector2(24,36))
	previous_hazards.clear()
	for module: PlatformingModule in stage.modules:
		for hazard: ModuleSawHazard in module.hazards: previous_hazards[hazard.get_instance_id()] = hazard.global_position
	shot_latch_encounter = GeneratedShotLatchEncounter.new()
	world.add_child(shot_latch_encounter)
	check.call(shot_latch_encounter.setup(replay,stage,controller,lifetime),"region uses production bilateral bells")
	controller.shoot_ability.shot_fired.connect(func(_direction: Vector2,_id: int): shots += 1)
	# Fixture equivalent of the existing DemoApp proximity interaction. The live
	# trace uses DemoApp's own connected consumer, not this fixture callback.
	controller.interact_requested.connect(func():
		for edge: Dictionary in stage.manifest.connections:
			if edge.condition=="backside" and not region_state.opened.has(edge.id) and motor.global_position.distance_to(Vector2(edge.control[0],edge.control[1]))<=90:
				stage.open_shortcut(str(edge.id),motor.global_position)
				break)
	await tick(3)
	if is_trace_cancelled(): return false
	return true

func tutorial() -> bool:
	if is_trace_cancelled(): return false
	for id: String in ["tutorial_gap", "tutorial_recoil", "tutorial_bell_module"]:
		var module := named(id)
		var _cancel_await_1: bool = await move_to(module.world_entry().x)
		if is_trace_cancelled(): return false
		check.call(_cancel_await_1,"continuous tutorial entry " + id)
		await traverse(module)
		if is_trace_cancelled(): return false
		if not motor.is_on_floor() or motor.global_position.distance_to(module.world_exit()) > 2: return false
	return await move_to(0)

func named(id: String) -> PlatformingModule:
	for i: int in stage.manifest.nodes.size():
		if stage.manifest.nodes[i].id == id: return stage.modules[i]
	return null

func walk_edge(edge: Dictionary, forward: bool) -> bool:
	if is_trace_cancelled(): return false
	if edge.condition == "backside" and not region_state.opened.has(edge.id):
		if forward: return false
		check.call(stage.open_shortcut(edge.id,motor.global_position),"shortcut really opens from upper side")
		await tick(2)
		if is_trace_cancelled(): return false
	if edge.kind=="drop":
		if not forward: return false
		if not await move_to(float(edge.path[0][0])): return false
		controller.router.set_move_axis(0);controller.router.request_action(&"drop_through")
		for unused: int in 210:
			await tick()
			if is_trace_cancelled(): return false
			if motor.is_on_floor() and absf(motor.global_position.y-float(edge.path[-1][1]))<2: break
	elif edge.kind == "stairs":
		var path: Array = edge.path.duplicate(true)
		if not forward:
			path.reverse()
			# Centre shaft is clear. Real one-way drop, then a grounded exit.
			if not await move_to(float(path[0][0])): return false
			controller.router.request_action(&"drop_through")
			for i: int in 180:
				await tick()
				if is_trace_cancelled(): return false
				if motor.is_on_floor() and absf(motor.global_position.y-float(path[-1][1])) < 2: break
		else:
			var driver = load("res://tests/branch_module_driver.gd").new()
			driver.module = named(edge.id)
			driver.motor = motor
			driver.controller = controller
			driver.tick_callback = tick
			driver.check = check
			for i: int in range(1,path.size()):
				if i==path.size()-1: driver.module=named(str(edge.b))
				if edge.get("shaft_recipe","")=="lift":
					if not await load("res://tests/plains_exploration_motion.gd").carrier(driver,named(edge.id),true,true,named(str(edge.b))): return false
					break
				elif edge.get("shaft_recipe","")=="recoil_shaft" and i<path.size()-1:
					if not await load("res://tests/plains_exploration_motion.gd").recoil_point(driver,Vector2(path[i][0],path[i][1])): return false
				elif not await jump_point(Vector2(path[i][0],path[i][1])): return false
	elif edge.kind == "horizontal":
		var indices: Array = edge.modules.duplicate()
		if not forward: indices.reverse()
		for index: Variant in indices:
			var module: PlatformingModule = stage.modules[int(index)]
			if forward:
				if not await move_to(module.world_entry().x,500): return false
				if not await forward_module(module):
					if is_trace_cancelled(): return false
					print("REGION MODULE FAIL ",module.definition.module_id," actor=",motor.global_position," expected=",module.world_exit())
					return false
			else:
				if not await move_to(module.world_exit().x,500): return false
				if not await reverse_module(module):
					if is_trace_cancelled(): return false
					print("REGION MODULE REVERSE FAIL ",module.definition.module_id," actor=",motor.global_position)
					return false
		var target_id: String = edge.b if forward else edge.a
		var p := PlainsRegionGenerator.new()._point(PlainsRegionGenerator.new()._area(stage.manifest,target_id).position)
		if not await move_to(p.x,500): return false
	elif edge.kind == "diagonal":
		if not forward: return await descending_diagonal(edge)
		var module := named(edge.id+"_ferry")
		if not await move_to(module.world_entry().x): return false
		await traverse(module)
		if is_trace_cancelled(): return false
		var join := named(edge.id+"_join")
		var driver = load("res://tests/branch_module_driver.gd").new()
		driver.module = join
		driver.motor = motor
		driver.controller = controller
		driver.tick_callback = tick
		driver.check = check
		if not await driver.move_to(join.position.x+60): return false
		driver.module = named(str(edge.b))
		for p: Vector2 in [Vector2(210,-148)]:
			if not await jump_point(join.position+p): return false
		if not await move_to(PlainsRegionGenerator.new()._point(PlainsRegionGenerator.new()._area(stage.manifest,edge.b).position).x): return false
	else: return false
	route_edges += 1
	var end := PlainsRegionGenerator.new()._point(PlainsRegionGenerator.new()._area(stage.manifest,edge.b if forward else edge.a).position)
	if not motor.is_on_floor() or motor.global_position.distance_to(end)>=2: print("EDGE FAILED ",edge.id," forward=",forward," actual=",motor.global_position," end=",end)
	check.call(motor.is_on_floor() and motor.global_position.distance_to(end)<2,"actual directed connection ends grounded " + edge.id + (" forward" if forward else " reverse"))
	check.call(controller.jump_ability.used_jumps==0 and controller.action_resources.shot_charges==controller.motor.tuning.max_air_shots,"connection restores resources only by real landing")
	return motor.is_on_floor() and motor.global_position.distance_to(end)<2

func reverse_module(module: PlatformingModule) -> bool:
	if is_trace_cancelled(): return false
	if stage.manifest.has("creek_discovery") and named(str(stage.manifest.creek_discovery.module))==module:return await discovery_module(module,false)
	var driver = load("res://tests/branch_module_driver.gd").new()
	driver.module = module
	driver.motor = motor
	driver.controller = controller
	driver.tick_callback = tick
	driver.check = check
	var id := str(module.definition.module_id)
	if not await driver.wait_for_shot_energy(2 if id=="plains_windchime_sequence" else 1): return false
	if id in ["plains_thorn_slalom","plains_remote_sequence"]:
		if not await driver.wait_for_shot_energy(2 if id=="plains_remote_sequence" else 1):return false
		return await load("res://tests/plains_cohesion_motion.gd").traverse(driver,module,shot_latch_encounter.for_module(module),false)
	if id in ["plains_thorn_cells","plains_thorn_wall","plains_remote_bell","plains_bell_ferry_control"]:
		return await load("res://tests/plains_interactive_motion.gd").traverse(driver,module,shot_latch_encounter.for_module(module),false)
	if id=="plains_windchime_rush": return await bell_rush(module,false)
	if id=="plains_windchime_well": return await bell_well(module,false)
	if id.begins_with("plains_windchime"):
		var latch: ShotLatch = shot_latch_encounter.for_module(module)
		if not latch.is_open:
			for i: int in (2 if id=="plains_windchime_sequence" else 1):
				if i==1 and not await move_to(module.position.x+405): return false
				var bell := latch.access_bodies[i]
				controller.router.request_action(&"shoot_release",(motor.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter).world_direction(motor.get_canvas_transform()*bell.global_position))
				await tick(30)
				if is_trace_cancelled(): return false
				if not await driver.land(): return false
		check.call(latch.is_open,"reverse entry shoots actual accessible return-side bell")
		if id=="plains_windchime_well": return latch.is_open and await jump_point(module.world_entry()+Vector2(240,0)) and await move_to(module.world_entry().x)
		return latch.is_open and await move_to(module.world_entry().x)
	if id=="plains_ferry_channel": return await load("res://tests/plains_exploration_motion.gd").carrier(driver,module,false)
	if id=="plains_low_arch": return await load("res://tests/plains_exploration_motion.gd").low_arch(driver,module,false)
	if id=="plains_twin_gears": return await load("res://tests/plains_exploration_motion.gd").twin_gears(driver,module,false)
	if id in ["plains_thorn_bridge","plains_recovery_bridge"]:
		var left: Rect2=module.definition.platforms[0]
		var right: Rect2=module.definition.platforms[1]
		if not await move_to(module.position.x+right.position.x+25): return false
		return await jump_point(module.position+Vector2(left.end.x-25,left.position.y-18)) and await move_to(module.world_entry().x)
	if id == "plains_gear_glade" or id=="plains_gear_brook":
		var centre: Vector2=module.definition.saws[0].origin
		if not await move_to(module.position.x+centre.x+90): return false
		if not await jump_point(module.position+Vector2(centre.x-90,282)): return false
		return await move_to(module.world_entry().x)
	if id == "plains_recoil_span":
		if not await move_to(module.position.x+585): return false
		controller.router.set_move_axis(-1)
		controller.router.request_action(&"jump")
		await tick(18)
		if is_trace_cancelled(): return false
		controller.router.request_action(&"shoot_release",Vector2(1,1).normalized())
		await tick()
		if is_trace_cancelled(): return false
		for frame: int in 100:
			controller.router.set_move_axis(clampf((module.position.x+100-motor.global_position.x)/5.5,-1,1))
			await tick()
			if is_trace_cancelled(): return false
			if motor.is_on_floor():
				controller.router.request_action(&"jump_release")
				return absf(motor.global_position.y-module.world_entry().y)<1 and await move_to(module.world_entry().x)
		return false

	return await move_to(module.world_entry().x)

func descending_diagonal(edge: Dictionary) -> bool:
	if is_trace_cancelled(): return false
	# Alternate safe stair route provides return; reverse diagonal is an explicit
	# moving-platform descent, validated separately rather than teleporting.
	var module := named(edge.id+"_ferry")
	var driver = load("res://tests/branch_module_driver.gd").new()
	driver.module = module
	driver.motor = motor
	driver.controller = controller
	driver.tick_callback = tick
	driver.check = check
	if not await move_to(module.position.x+990): return false
	controller.router.request_action(&"drop_through")
	for i: int in 210:
		controller.router.set_move_axis(-1)
		await tick()
		if is_trace_cancelled(): return false
		if motor.is_on_floor() and absf(motor.global_position.y-module.world_entry().y)<2: break
	return await move_to(PlainsRegionGenerator.new()._point(PlainsRegionGenerator.new()._area(stage.manifest,edge.a).position).x,500)

func path_to(from_id: String,to_id: String) -> Array:
	var todo: Array = [from_id]
	var previous := {from_id: ""}
	var via := {}
	while not todo.is_empty():
		var current: String = todo.pop_front()
		if current == to_id: break
		for e: Dictionary in stage.manifest.connections:
			if (e.kind=="drop" and not e.has("path")) or e.kind not in ["horizontal","stairs","diagonal","drop"] or (e.condition != "open" and not region_state.opened.has(e.id)): continue
			var other := ""
			if e.a == current: other = str(e.b)
			elif e.b == current and e.bidirectional: other = str(e.a)
			if other.is_empty() or previous.has(other): continue
			previous[other]=current
			via[other]={"edge":e,"forward": e.a==current}
			todo.append(other)
	if not previous.has(to_id): return []
	var path: Array = []
	var current := to_id
	while current != from_id:
		path.push_front(via[current])
		current = previous[current]
	return path

func journey(manifest: Dictionary,tuning: PlayerTuning, mode: String) -> void:
	if is_trace_cancelled(): return
	if not await fixture(manifest,tuning):
		if is_trace_cancelled(): return
		check.call(false,"region fixture")
		return
	var _cancel_await_2: bool = await tutorial()
	if is_trace_cancelled(): return
	check.call(_cancel_await_2,"whole-map short tutorial input-only")
	var current := "area_0_1"
	if mode=="fast":
		for step: Dictionary in path_to(current,str(manifest.prep_id)):
			if not await walk_edge(step.edge,step.forward):
				if is_trace_cancelled(): return
				check.call(false,"fast route edge")
				return
	elif mode=="growth":
		var goals: Array=[]
		goals.append(manifest.rewards.filter(func(c: Dictionary): return c.tier=="medium")[0].area)
		goals.append(manifest.merchant_id)
		goals.append(manifest.prep_id)
		for goal: String in goals:
			for step: Dictionary in path_to(current,goal):
				if not await walk_edge(step.edge,step.forward):
					if is_trace_cancelled(): return
					check.call(false,"growth route")
					return
			current=goal
	else:
		# Continuous tour visits every open directed edge, repeatedly rejoins known
		# junctions, then opens both shortcuts and uses them in both directions.
		for e: Dictionary in manifest.connections:
			if e.kind not in ["horizontal","stairs","diagonal","drop"] or (e.kind=="drop" and not e.has("path")): continue
			var source: String = e.a if e.condition=="open" else e.b
			for step: Dictionary in path_to(current,source):
				if not await walk_edge(step.edge,step.forward):
					if is_trace_cancelled(): return
					check.call(false,"continuous tour approach")
					return
			if not await walk_edge(e,e.condition=="open"):
				if is_trace_cancelled(): return
				check.call(false,"tour connection " + e.id)
				return
			current = str(e.b if e.condition=="open" else e.a)
			if not e.bidirectional: continue
			if not await walk_edge(e,e.condition!="open"):
				if is_trace_cancelled(): return
				check.call(false,"tour reverse " + e.id)
				return
			current = source
		for step: Dictionary in path_to(current,str(manifest.prep_id)):
			if not await walk_edge(step.edge,step.forward):
				if is_trace_cancelled(): return
				check.call(false,"tour Boss prep")
				return
	check.call(safe_trace and continuous_trace,"entire itinerary body sweeps avoid hazards with no teleport")
	print("REGION JOURNEY mode=",mode," family=",manifest.family," ticks=",trace_ticks," seconds=",trace_ticks/60.0," shots=",shots," edges=",route_edges," safe=",safe_trace)
	await release_test_world()
	if is_trace_cancelled(): return

func discovery_module(module: PlatformingModule,forward: bool) -> bool:
	if is_trace_cancelled(): return false
	var driver=load("res://tests/branch_module_driver.gd").new();driver.module=module;driver.motor=motor;driver.controller=controller;driver.tick_callback=tick;driver.check=check
	module.set_meta("discovery_latch",shot_latch_encounter.for_module(module))
	return await load("res://tests/plains_creek_discovery_motion.gd").traverse(driver,module,named("creek_cache_bank"),Callable(),forward)

func forward_module(module: PlatformingModule) -> bool:
	if is_trace_cancelled(): return false
	if stage.manifest.has("creek_discovery") and named(str(stage.manifest.creek_discovery.module))==module:return await discovery_module(module,true)
	var id := str(module.definition.module_id)
	var waiter=load("res://tests/branch_module_driver.gd").new();waiter.module=module;waiter.motor=motor;waiter.controller=controller;waiter.tick_callback=tick;waiter.check=check
	if id in ["plains_thorn_slalom","plains_remote_sequence"]:
		if not await waiter.wait_for_shot_energy(2 if id=="plains_remote_sequence" else 1):return false
		return await load("res://tests/plains_cohesion_motion.gd").traverse(waiter,module,shot_latch_encounter.for_module(module),true)
	if not await waiter.wait_for_shot_energy(2 if id=="plains_windchime_sequence" else 1): return false
	if id in ["plains_thorn_cells","plains_thorn_wall","plains_remote_bell","plains_bell_ferry_control"]:
		return await load("res://tests/plains_interactive_motion.gd").traverse(waiter,module,shot_latch_encounter.for_module(module),true)
	if id=="plains_windchime_rush": return await bell_rush(module,true)
	if id=="plains_windchime_well": return await bell_well(module,true)
	if not id.begins_with("plains_windchime"):
		if id in ["plains_ferry_channel","plains_low_arch","plains_twin_gears"]:
			return await load("res://tests/branch_module_driver.gd").new().traverse(module,motor,tick,check)
		await traverse(module)
		if is_trace_cancelled(): return false
		return motor.is_on_floor() and motor.global_position.distance_to(module.world_exit())<2
	var latch: ShotLatch = shot_latch_encounter.for_module(module)
	if not latch.is_open:
		var before := latch.open_count
		if not await move_to(module.position.x+140): return false
		var bells: Array = [latch.bell_body]
		if id=="plains_windchime_sequence" and latch.sequence_step==0: bells.append(latch._second_body)
		elif id=="plains_windchime_sequence": bells=[latch._second_body]
		for body: StaticBody2D in bells:
			if body==latch._second_body and not await move_to(module.position.x+210): return false
			controller.router.request_action(&"shoot_release",(motor.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter).world_direction(motor.get_canvas_transform()*body.global_position))
			await tick(30)
			if is_trace_cancelled(): return false
		check.call(latch.is_open and latch.open_count==before+1,"one accepted opening for real forward bell traversal")
	if id=="plains_windchime_well":
		if not await move_to(module.position.x+250): return false
		if not await jump_point(module.position+Vector2(430,282)): return false
	return latch.is_open and await move_to(module.world_exit().x)

func bell_rush(module: PlatformingModule,forward: bool) -> bool:
	if is_trace_cancelled(): return false
	var latch: ShotLatch=shot_latch_encounter.for_module(module)
	if not await move_to(module.position.x+(140 if forward else 755)): return false
	var body: StaticBody2D=latch.bell_body if forward else latch.access_bodies[0]
	controller.router.request_action(&"shoot_release",(motor.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter).world_direction(motor.get_canvas_transform()*body.global_position))
	await tick(25)
	if is_trace_cancelled(): return false
	if not latch.is_open: return false
	if not forward:
		if not await move_to(module.position.x+435): return false
		if not await jump_point(module.position+Vector2(255,282)): return false
	else:
		if not await move_to(module.position.x+255): return false
		if not await jump_point(module.position+Vector2(435,282)): return false
	return await move_to((module.world_exit() if forward else module.world_entry()).x)

func bell_well(module: PlatformingModule, forward: bool) -> bool:
	if is_trace_cancelled(): return false
	var latch: ShotLatch=shot_latch_encounter.for_module(module)
	if not forward and not latch.is_open:
		if not await move_to(module.world_exit().x-50): return false
		var body: StaticBody2D=latch.access_bodies[0]
		controller.router.request_action(&"shoot_release",(motor.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter).world_direction(motor.get_canvas_transform()*body.global_position))
		await tick(30)
		if is_trace_cancelled(): return false
		if not latch.is_open: print("WELL RETURN SHOT FAILED actor=",motor.global_position," bell=",body.global_position," projectiles=",controller.shoot_ability.get_projectiles().size());return false
	if not await move_to(module.position.x+(265 if forward else 395)):
		if is_trace_cancelled(): return false
		print("WELL BANK FAILED ",forward," actor=",motor.global_position)
		return false
	controller.router.set_move_axis(1 if forward else -1)
	controller.router.request_action(&"jump")
	await tick(14)
	if is_trace_cancelled(): return false
	if not latch.is_open:
		var bell: StaticBody2D=latch.bell_body
		controller.router.request_action(&"shoot_release",(motor.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter).world_direction(motor.get_canvas_transform()*bell.global_position))
		await tick(10)
		if is_trace_cancelled(): return false
		check.call(latch.is_open,"well opens by actual airborne downward shot")
	if not latch.is_open: return false
	var driver=load("res://tests/branch_module_driver.gd").new()
	driver.module=module;driver.motor=motor;driver.controller=controller;driver.tick_callback=tick;driver.check=check
	controller.router.request_action(&"jump_release")
	for unused: int in 120:
		var target: float=module.position.x+(430 if forward else 250)
		controller.router.set_move_axis(clampf((target-motor.global_position.x)/5.5,-1,1))
		await tick()
		if is_trace_cancelled(): return false
		if motor.is_on_floor(): break
	var result: bool=motor.is_on_floor() and await move_to((module.world_exit() if forward else module.world_entry()).x)
	if is_trace_cancelled(): return false
	if not result: print("WELL LAND FAILED ",forward," actor=",motor.global_position)
	return result

func open_backside_shortcut(_edge: Dictionary) -> bool:
	# Legacy assembled fixtures retain their original proximity interaction.
	# The live formal App overrides this actuator for its attack-only latch.
	controller.router.request_action(&"interact")
	await tick(3)
	if is_trace_cancelled(): return false
	return region_state.opened.has(_edge.id)

func deep_trial(id: String) -> bool:
	if is_trace_cancelled(): return false
	var ferry:=named(id+"_ferry")
	var entry:=named(id+"_entry")
	var driver=load("res://tests/branch_module_driver.gd").new()
	driver.module=entry
	driver.motor=motor
	driver.controller=controller
	driver.tick_callback=tick
	driver.check=check
	for p: Vector2 in [Vector2(90,-100),Vector2(-90,-200),Vector2(-230,-300)]:
		if not await jump_point(entry.position+p): return false
	driver.module=ferry
	if not await jump_point(ferry.world_entry()): return false
	if not await move_to(ferry.world_entry().x,500): return false
	if str(ferry.definition.module_id).begins_with("plains_windchime") or ferry.definition.module_id==&"plains_remote_sequence":
		if not await forward_module(ferry): return false
	else:
		await traverse(ferry)
		if is_trace_cancelled(): return false
	if motor.global_position.distance_to(ferry.world_exit())>2: return false
	var recoil:=named(id+"_recoil")
	if not await move_to(recoil.world_entry().x,500): return false
	if str(recoil.definition.module_id).begins_with("plains_windchime") or recoil.definition.module_id==&"plains_remote_sequence":
		if not await forward_module(recoil): return false
	else:
		await traverse(recoil)
		if is_trace_cancelled(): return false
	if motor.global_position.distance_to(recoil.world_exit())>2: return false
	var reward_area:=PlainsRegionGenerator.new()._area(stage.manifest,id)
	var reward:=Vector2(reward_area.position[0],reward_area.position[1])
	if not await move_to(reward.x): return false
	check.call(motor.is_on_floor() and motor.global_position.distance_to(reward)<2,"real optional challenge reaches tier cache")
	var connection: Dictionary={}
	for e: Dictionary in stage.manifest.connections:
		if e.a==id and e.kind=="drop": connection=e
	var destination:=PlainsRegionGenerator.new()._area(stage.manifest,connection.b)
	var target:=Vector2(destination.position[0],destination.position[1])
	# Drop through the actual one-way reward landing and steer to the other junction.
	controller.router.set_move_axis(0)
	controller.router.request_action(&"drop_through")
	await tick()
	if is_trace_cancelled(): return false
	for i: int in 280:
		var aim_x: float=float(connection.escape_x) if motor.global_position.y<float(connection.clear_y) else target.x
		controller.router.set_move_axis(clampf((aim_x-motor.global_position.x)/5.5,-1,1))
		await tick()
		if is_trace_cancelled(): return false
		if motor.is_on_floor():
			# Return may touch a known upper bank and its real locked hatch.
			# Request the same input used in the live App; never mutate gate/opened.
			for shortcut: Dictionary in stage.manifest.connections:
				if shortcut.condition!="backside" or region_state.opened.has(shortcut.id): continue
				if motor.global_position.distance_to(Vector2(shortcut.control[0],shortcut.control[1]))>90: continue
				var shortcut_opened: bool = await open_backside_shortcut(shortcut)
				if is_trace_cancelled(): return false
				check.call(region_state.opened.has(shortcut.id),"reward return opens actual nearby upper-side hatch through input")
				if not shortcut_opened or not region_state.opened.has(shortcut.id): return false
			if absf(motor.global_position.y-target.y)<2:
				if not await move_to(target.x): return false
				break
			controller.router.request_action(&"drop_through")
	controller.router.set_move_axis(0)
	await tick(3)
	if is_trace_cancelled(): return false
	check.call(motor.is_on_floor() and motor.global_position.distance_to(target)<2,"one-way challenge has real different-node evacuation")
	if motor.global_position.distance_to(target)>=2: print("DEEP EVAC FAIL actual=",motor.global_position," target=",target," drop_body=",motor._drop_body)
	return motor.is_on_floor() and motor.global_position.distance_to(target)<2

func adventure(manifest: Dictionary,tuning: PlayerTuning) -> void:
	if is_trace_cancelled(): return
	if not await fixture(manifest,tuning):
		if is_trace_cancelled(): return
		check.call(false,"deep fixture")
		return
	if not await tutorial():
		if is_trace_cancelled(): return
		check.call(false,"deep tutorial")
		return
	var current: String="area_0_1"
	for id: String in ["deep_high","deep_region_top"]:
		var entry: String=""
		for e: Dictionary in manifest.connections:
			if e.b==id and e.kind=="challenge": entry=str(e.a)
		for step: Dictionary in path_to(current,entry):
			if not await walk_edge(step.edge,step.forward):
				if is_trace_cancelled(): return
				check.call(false,"deep approach")
				return
		if not await deep_trial(id):
			if is_trace_cancelled(): return
			check.call(false,"deep trial " + id)
			return
		for e: Dictionary in manifest.connections:
			if e.a==id and e.kind=="drop": current=str(e.b)
	for step: Dictionary in path_to(current,str(manifest.prep_id)):
		if not await walk_edge(step.edge,step.forward):
			if is_trace_cancelled(): return
			check.call(false,"deep Boss approach")
			return
	check.call(safe_trace and continuous_trace,"deep entire itinerary is continuous, swept safe and base-resource-only")
	print("REGION JOURNEY mode=deep family=",manifest.family," ticks=",trace_ticks," seconds=",trace_ticks/60.0," shots=",shots," safe=",safe_trace)
	await release_test_world()
	if is_trace_cancelled(): return

func jump_point(target: Vector2) -> bool:
	if is_trace_cancelled(): return false
	controller.router.request_action(&"jump")
	for frame: int in 120:
		controller.router.set_move_axis(clampf((target.x-motor.global_position.x)/5.5,-1,1))
		await tick()
		if is_trace_cancelled(): return false
		if frame>3 and motor.is_on_floor():
			controller.router.request_action(&"jump_release")
			await tick(2)
			if is_trace_cancelled(): return false
			if absf(motor.global_position.y-target.y)>1:
				print("REGION JUMP FAILED target=",target," actual=",motor.global_position)
				return false
			if not await move_to(target.x): return false
			var feet:=motor.global_position+Vector2(0,18)
			for offset: float in [-11.0,0.0,11.0]:
				var ray:=PhysicsRayQueryParameters2D.create(feet+Vector2(offset,-0.1),feet+Vector2(offset,8),motor.collision_mask,[motor.get_rid()])
				var hit:=motor.get_world_2d().direct_space_state.intersect_ray(ray)
				if hit.is_empty() or (hit.normal as Vector2).dot(Vector2.UP)<0.7: return false
			return motor.global_position.distance_to(target)<1
	return false

func tutorial_return(manifest: Dictionary,tuning: PlayerTuning) -> void:
	if is_trace_cancelled(): return
	if not await fixture(manifest,tuning):
		if is_trace_cancelled(): return
		check.call(false,"tutorial return fixture")
		return
	if not await tutorial():
		if is_trace_cancelled(): return
		check.call(false,"tutorial forward")
		return
	for id: String in ["tutorial_bell_module","tutorial_recoil","tutorial_gap"]:
		var module:=named(id)
		if not await move_to(module.world_exit().x,500):
			if is_trace_cancelled(): return
			check.call(false,"tutorial return approach")
			return
		if str(module.definition.module_id)=="plains_meadow_gap":
			if not await move_to(module.position.x+335) or not await jump_point(module.position+Vector2(130,342)) or not await move_to(module.world_entry().x):
				if is_trace_cancelled(): return
				check.call(false,"tutorial gap reverse")
				return
		elif not await reverse_module(module):
			if is_trace_cancelled(): return
			check.call(false,"tutorial reverse " + id)
			return
	check.call(motor.global_position.distance_to(stage.world_entry())<2 and safe_trace and continuous_trace,"tutorial and recoil have real full return to spawn without warp")
	print("REGION TUTORIAL RETURN ticks=",trace_ticks," shots=",shots," safe=",safe_trace)
	await release_test_world()
	if is_trace_cancelled(): return

func release_test_world() -> bool:
	if not is_instance_valid(world): return true
	var receipt: Dictionary = audio_teardown.stop_fallback_voices(world)
	world.free()
	var released: bool = await audio_teardown.wait_fallback_release(receipt,1000)
	check.call(released,"region fixture owned fallback backend released before replacement or exit")
	return released
