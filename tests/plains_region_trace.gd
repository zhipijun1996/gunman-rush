extends "res://tests/plains_run_trace.gd"
## Every itinerary uses one world and one spawn. No mid-route reset/teleport.
var lifetime := DemoLifetime.new()
var region_state := PlainsRegionState.new()
var route_edges := 0

func fixture(manifest: Dictionary, tuning: PlayerTuning) -> bool:
	if is_instance_valid(world): world.free()
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
	await tick(3)
	return true

func tutorial() -> bool:
	for id: String in ["tutorial_gap", "tutorial_recoil", "tutorial_bell_module"]:
		var module := named(id)
		check.call(await move_to(module.world_entry().x),"continuous tutorial entry " + id)
		await traverse(module)
		if not motor.is_on_floor() or motor.global_position.distance_to(module.world_exit()) > 2: return false
	return await move_to(0)

func named(id: String) -> PlatformingModule:
	for i: int in stage.manifest.nodes.size():
		if stage.manifest.nodes[i].id == id: return stage.modules[i]
	return null

func walk_edge(edge: Dictionary, forward: bool) -> bool:
	if edge.condition == "backside" and not region_state.opened.has(edge.id):
		if forward: return false
		check.call(stage.open_shortcut(edge.id,motor.global_position),"shortcut really opens from upper side")
		await tick(2)
	if edge.kind == "stairs":
		var path: Array = edge.path.duplicate(true)
		if not forward:
			path.reverse()
			# Centre shaft is clear. Real one-way drop, then a grounded exit.
			if not await move_to(float(path[0][0])): return false
			controller.router.request_action(&"drop_through")
			for i: int in 180:
				await tick()
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
				if not await jump_point(Vector2(path[i][0],path[i][1])): return false
	elif edge.kind == "horizontal":
		var indices: Array = edge.modules.duplicate()
		if not forward: indices.reverse()
		for index: Variant in indices:
			var module: PlatformingModule = stage.modules[int(index)]
			if forward:
				if not await move_to(module.world_entry().x,500): return false
				if not await forward_module(module): return false
			else:
				if not await move_to(module.world_exit().x,500): return false
				if not await reverse_module(module): return false
		var target_id: String = edge.b if forward else edge.a
		var p := PlainsRegionGenerator.new()._point(PlainsRegionGenerator.new()._area(stage.manifest,target_id).position)
		if not await move_to(p.x,500): return false
	elif edge.kind == "diagonal":
		if not forward: return await descending_diagonal(edge)
		var module := named(edge.id+"_ferry")
		if not await move_to(module.world_entry().x): return false
		await traverse(module)
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
	check.call(controller.jump_ability.used_jumps==0 and controller.action_resources.shot_charges==2,"connection restores resources only by real landing")
	return motor.is_on_floor() and motor.global_position.distance_to(end)<2

func reverse_module(module: PlatformingModule) -> bool:
	var driver = load("res://tests/branch_module_driver.gd").new()
	driver.module = module
	driver.motor = motor
	driver.controller = controller
	driver.tick_callback = tick
	driver.check = check
	var id := str(module.definition.module_id)
	if id.begins_with("plains_windchime"):
		var latch: ShotLatch = shot_latch_encounter.for_module(module)
		if not latch.is_open:
			for i: int in (2 if id=="plains_windchime_sequence" else 1):
				if i==1 and not await move_to(module.position.x+405): return false
				var bell := latch.access_bodies[i]
				controller.router.request_action(&"shoot_release",(bell.global_position-motor.global_position).normalized())
				await tick(30)
				if not await driver.land(): return false
		check.call(latch.is_open,"reverse entry shoots actual accessible return-side bell")
		return latch.is_open and await move_to(module.world_entry().x)
	if id == "plains_gear_glade":
		if not await move_to(module.position.x+290): return false
		if not await jump_point(module.position+Vector2(50,282)): return false
		return await move_to(module.world_entry().x)
	if id == "plains_recoil_span":
		if not await move_to(module.position.x+585): return false
		controller.router.set_move_axis(-1)
		controller.router.request_action(&"jump")
		await tick(18)
		controller.router.request_action(&"shoot_release",Vector2(1,1).normalized())
		await tick()
		for frame: int in 100:
			controller.router.set_move_axis(clampf((module.position.x+100-motor.global_position.x)/5.5,-1,1))
			await tick()
			if motor.is_on_floor():
				controller.router.request_action(&"jump_release")
				return absf(motor.global_position.y-module.world_entry().y)<1 and await move_to(module.world_entry().x)
		return false

	return await move_to(module.world_entry().x)

func descending_diagonal(edge: Dictionary) -> bool:
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
			if e.kind not in ["horizontal","stairs","diagonal"] or (e.condition != "open" and not region_state.opened.has(e.id)): continue
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
	if not await fixture(manifest,tuning): check.call(false,"region fixture"); return
	check.call(await tutorial(),"whole-map short tutorial input-only")
	var current := "area_0_1"
	if mode=="fast":
		for step: Dictionary in path_to(current,str(manifest.prep_id)):
			if not await walk_edge(step.edge,step.forward): check.call(false,"fast route edge"); return
	elif mode=="growth":
		var goals: Array=[]
		goals.append(manifest.rewards.filter(func(c: Dictionary): return c.tier=="medium")[0].area)
		goals.append(manifest.merchant_id)
		goals.append(manifest.prep_id)
		for goal: String in goals:
			for step: Dictionary in path_to(current,goal):
				if not await walk_edge(step.edge,step.forward): check.call(false,"growth route"); return
			current=goal
	else:
		# Continuous tour visits every open directed edge, repeatedly rejoins known
		# junctions, then opens both shortcuts and uses them in both directions.
		for e: Dictionary in manifest.connections:
			if e.kind not in ["horizontal","stairs","diagonal"]: continue
			var source: String = e.a if e.condition=="open" else e.b
			for step: Dictionary in path_to(current,source):
				if not await walk_edge(step.edge,step.forward): check.call(false,"continuous tour approach"); return
			if not await walk_edge(e,e.condition=="open"): check.call(false,"tour connection " + e.id); return
			current = str(e.b if e.condition=="open" else e.a)
			if not e.bidirectional: continue
			if not await walk_edge(e,e.condition!="open"): check.call(false,"tour reverse " + e.id); return
			current = source
		for step: Dictionary in path_to(current,str(manifest.prep_id)):
			if not await walk_edge(step.edge,step.forward): check.call(false,"tour Boss prep"); return
	check.call(safe_trace and continuous_trace,"entire itinerary body sweeps avoid hazards with no teleport")
	print("REGION JOURNEY mode=",mode," family=",manifest.family," ticks=",trace_ticks," seconds=",trace_ticks/60.0," shots=",shots," edges=",route_edges," safe=",safe_trace)
	world.free()

func forward_module(module: PlatformingModule) -> bool:
	var id := str(module.definition.module_id)
	if not id.begins_with("plains_windchime"):
		await traverse(module)
		return motor.is_on_floor() and motor.global_position.distance_to(module.world_exit())<2
	var latch: ShotLatch = shot_latch_encounter.for_module(module)
	if not latch.is_open:
		var before := latch.open_count
		if not await move_to(module.position.x+140): return false
		var bells: Array = [latch.bell_body]
		if id=="plains_windchime_sequence" and latch.sequence_step==0: bells.append(latch._second_body)
		elif id=="plains_windchime_sequence": bells=[latch._second_body]
		for body: StaticBody2D in bells:
			controller.router.request_action(&"shoot_release",(body.global_position-motor.global_position).normalized())
			await tick(30)
		check.call(latch.is_open and latch.open_count==before+1,"one accepted opening for real forward bell traversal")
	return latch.is_open and await move_to(module.world_exit().x)

func deep_trial(id: String) -> bool:
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
	await traverse(ferry)
	if motor.global_position.distance_to(ferry.world_exit())>2: return false
	var recoil:=named(id+"_recoil")
	if not await move_to(recoil.world_entry().x,500): return false
	await traverse(recoil)
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
	# Walk off the reward ledge to a different junction; no checkpoint warp.
	controller.router.set_move_axis(1)
	await tick(35)
	for i: int in 280:
		controller.router.set_move_axis(clampf((target.x-motor.global_position.x)/5.5,-1,1))
		await tick()
		if motor.is_on_floor():
			if absf(motor.global_position.y-target.y)<2: break
			controller.router.request_action(&"drop_through")
	controller.router.set_move_axis(0)
	await tick(3)
	check.call(motor.is_on_floor() and motor.global_position.distance_to(target)<2,"one-way challenge has real different-node evacuation")
	return motor.is_on_floor() and motor.global_position.distance_to(target)<2

func adventure(manifest: Dictionary,tuning: PlayerTuning) -> void:
	if not await fixture(manifest,tuning): check.call(false,"deep fixture"); return
	if not await tutorial(): check.call(false,"deep tutorial"); return
	var current: String="area_0_1"
	for id: String in ["deep_high","deep_region_top"]:
		var entry: String=""
		for e: Dictionary in manifest.connections:
			if e.b==id and e.kind=="challenge": entry=str(e.a)
		for step: Dictionary in path_to(current,entry):
			if not await walk_edge(step.edge,step.forward): check.call(false,"deep approach"); return
		if not await deep_trial(id): check.call(false,"deep trial " + id); return
		for e: Dictionary in manifest.connections:
			if e.a==id and e.kind=="drop": current=str(e.b)
	for step: Dictionary in path_to(current,str(manifest.prep_id)):
		if not await walk_edge(step.edge,step.forward): check.call(false,"deep Boss approach"); return
	check.call(safe_trace and continuous_trace,"deep entire itinerary is continuous, swept safe and base-resource-only")
	print("REGION JOURNEY mode=deep family=",manifest.family," ticks=",trace_ticks," seconds=",trace_ticks/60.0," shots=",shots," safe=",safe_trace)
	world.free()

func jump_point(target: Vector2) -> bool:
	controller.router.request_action(&"jump")
	for frame: int in 120:
		controller.router.set_move_axis(clampf((target.x-motor.global_position.x)/5.5,-1,1))
		await tick()
		if frame>3 and motor.is_on_floor():
			controller.router.request_action(&"jump_release")
			await tick(2)
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
	if not await fixture(manifest,tuning): check.call(false,"tutorial return fixture"); return
	if not await tutorial(): check.call(false,"tutorial forward"); return
	for id: String in ["tutorial_bell_module","tutorial_recoil","tutorial_gap"]:
		var module:=named(id)
		if not await move_to(module.world_exit().x,500): check.call(false,"tutorial return approach"); return
		if str(module.definition.module_id)=="plains_meadow_gap":
			if not await move_to(module.position.x+335) or not await jump_point(module.position+Vector2(130,342)) or not await move_to(module.world_entry().x): check.call(false,"tutorial gap reverse"); return
		elif not await reverse_module(module): check.call(false,"tutorial reverse " + id); return
	check.call(motor.global_position.distance_to(stage.world_entry())<2 and safe_trace and continuous_trace,"tutorial and recoil have real full return to spawn without warp")
	print("REGION TUTORIAL RETURN ticks=",trace_ticks," shots=",shots," safe=",safe_trace)
	world.free()
