extends "res://tests/level_formal_trace.gd"
## Real Router policy on the original live formal map. No movement/damage injection.
var root_id := ""
var root_motor: EnemyMotor
var root_actor: EnemyActor
var root_cases: Array = []
var _case_start := 0
var _case_name := ""
var _root_home := Vector2.ZERO
var _floor_y := 0.0

func attach(application: DemoApp, selected_strategy: String, wait_ticks: int, selected_policy: String = "kill_from_bank_v1") -> bool:
	if not super.attach(application,selected_strategy,wait_ticks,selected_policy):return false
	for i: int in formal_stage.enemy_manifest.size():
		if formal_stage.enemy_manifest[i].get("behavior_id", "") != "root_bell":continue
		root_id = str(formal_stage.enemy_manifest[i].id)
		root_motor = formal_stage.enemies[i]
		root_actor = root_motor.get_node("Actor")
		_root_home = root_motor.global_position
		_floor_y = _root_home.y+root_actor.definition.collision_size.y*.5
		# Choosing not to shoot this target is input strategy, not enemy disable.
		_bypass_until[root_id] = 1000000
		var behavior: EnemyAttackBehavior = root_actor.attack_behavior
		if behavior.has_signal("pulse_committed"):
			behavior.connect("pulse_committed",func(id: StringName,point: Vector2):event("root_pulse",{"enemy":root_id,"event_id":str(id),"point":SNAPSHOT.pair(point)}))
		if behavior.has_signal("warning_interrupted"):
			behavior.connect("warning_interrupted",func():event("root_interrupted",{"enemy":root_id,"hp":root_actor.health.current}))
	return true # Legacy source can use this same observer and its ordinary policy.

func root_snapshot() -> Dictionary:
	if not is_instance_valid(root_actor):return {}
	var b: EnemyAttackBehavior = root_actor.attack_behavior
	var hazards: Array = []
	for module: PlatformingModule in stage.modules:
		for hazard: ModuleSawHazard in module.hazards:
			if hazard.global_position.distance_to(root_motor.global_position)<900:hazards.append({"position":SNAPSHOT.pair(hazard.global_position),"radius":hazard.definition.radius,"period":hazard.definition.period,"module_clock":module.clock,"initial_phase":hazard.definition.initial_phase,"enabled":hazard.enabled,"source_id":str(hazard.runtime_source_id)})
	return {"id":root_id,"position":SNAPSHOT.pair(root_motor.global_position),"hp":root_actor.health.current,"terminal":root_actor.health.terminal,"state":str(b.state),"time":b.state_time,"serial":b._serial,"goal":SNAPSHOT.pair(b.attack_goal),"cooldown":b.cooldown,"actor_epoch":app.lifetime.actor_epoch,"active":controller.active,"body_size":SNAPSHOT.pair(root_actor.definition.collision_size),"pulse_size":SNAPSHOT.pair(root_actor.definition.get("pulse_size")),"nearby_actual_saws":hazards}

func tick(count: int = 1) -> void:
	for unused: int in count:
		await super.tick(1)
		if not observed_frames.is_empty():observed_frames[-1]["root_bell"] = root_snapshot()

func begin_case(id: String) -> void:
	_case_name = id
	_case_start = trace_ticks+1
	event("root_case_begin",{"id":id,"position":SNAPSHOT.pair(motor.global_position),"health":controller.actor_resources.health.current})
func end_case(ok: bool, extra: Dictionary = {}) -> bool:
	var row := {"id":_case_name,"start_tick":_case_start,"end_tick":trace_ticks,"passed":ok,"position":SNAPSHOT.pair(motor.global_position),"health":controller.actor_resources.health.current,"enemy_hp":root_actor.health.current}
	row.merge(extra)
	root_cases.append(row)
	event("root_case_end",row)
	if not ok:record_check(false,"root formal case "+_case_name)
	return ok
func warning() -> bool:
	for unused: int in 200:
		if root_actor.attack_behavior.state == &"telegraph":return true
		await tick()
	return false

func run_route() -> void:
	if root_id.is_empty():
		await super.run_route()
		return
	begin_case("formal_approach")
	if not await tutorial():end_case(false);finish(false,"root_tutorial_failed");return
	current_area = "area_0_1"
	var admission: Dictionary = stage.manifest.root_bell_admission
	var edge_id: String = admission.physical_facts.edge
	var edge: Dictionary = {}
	var full_edge_start := 0
	for value: Dictionary in stage.manifest.connections:
		if value.id==edge_id:edge=value;break
	# Choose the legitimate camp/stair approach. The optional creek-cache island
	# driver's ferry boarding failed in the preserved rendered movie; this policy
	# does not claim to repair or validate that separate discovery excursion.
	if edge.is_empty() or not await follow_to("area_2_1") or not await follow_to(str(edge.a)):end_case(false);finish(false,"root_approach_failed");return
	current_edge = edge_id
	full_edge_start = trace_ticks+1
	for index: Variant in edge.modules:
		var module: PlatformingModule = stage.modules[int(index)]
		if not await move_to(module.world_entry().x,500) or not await forward_module(module):end_case(false);finish(false,"root_neighbor_gear_failed");return
	if not await move_to(_root_home.x-240,180):end_case(false);finish(false,"root_bank_failed");return
	if not end_case(motor.is_on_floor() and root_actor.health.current>0,{"edge":edge_id,"actual_admission":admission}):finish(false,"root_approach_failed");return
	# Local pilot deliberately keeps root alive; other actors retain normal AI.
	_enemy_policy_busy = true
	for delay: int in [0,30,60]:
		begin_case("walk_mark_escape_phase_%s"%delay)
		var before_hp := controller.actor_resources.health.current
		await tick(delay)
		var phase_ready_tick := trace_ticks
		if not await move_to(_root_home.x-150,120) or not await warning():end_case(false);finish(false,"root_warning_failed");return
		var goal := root_actor.attack_behavior.attack_goal
		var serial := root_actor.attack_behavior._serial
		var escape_x := _root_home.x-100 if goal.x < _root_home.x-170 else _root_home.x-240
		if not await move_to(escape_x,120):end_case(false);finish(false,"root_walk_failed");return
		await tick(65)
		if not end_case(controller.actor_resources.health.current==before_hp and root_actor.health.current>0 and root_actor.attack_behavior._serial>serial,{"locked_goal":SNAPSHOT.pair(goal),"same_side_walk_escape":true,"phase_wait":delay,"phase_ready_tick":phase_ready_tick}):finish(false,"root_walk_damage");return
		begin_case("jump_forward_phase_%s"%delay)
		if not await move_to(_root_home.x-90,120):end_case(false);finish(false,"root_takeoff_failed");return
		var ok := await jump_point(Vector2(_root_home.x+220,_floor_y-18))
		if not end_case(ok and controller.actor_resources.health.current==before_hp and root_actor.health.current>0,{"direction":1,"phase_wait":delay}):finish(false,"root_forward_failed");return
		begin_case("jump_return_phase_%s"%delay)
		await wait_for_safe_return_approach(_root_home.x+90)
		if not await move_to(_root_home.x+90,120):end_case(false);finish(false,"root_return_takeoff_failed");return
		ok = await jump_point(Vector2(_root_home.x-240,_floor_y-18))
		if not end_case(ok and controller.actor_resources.health.current==before_hp and root_actor.health.current>0,{"direction":-1,"phase_wait":delay}):finish(false,"root_return_failed");return
	for hit: int in 3:
		begin_case("real_projectile_interrupt_%s"%hit if hit<2 else "real_projectile_death")
		if not await move_to(_root_home.x-150,120) or not await warning():end_case(false);finish(false,"root_shot_warning_failed");return
		var hp := root_actor.health.current
		var aim := (motor.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter).world_direction(motor.get_canvas_transform()*root_motor.global_position)
		controller.router.request_action(&"shoot_release",aim)
		for unused: int in 80:
			await tick()
			if root_actor.health.current<hp:break
		await tick(15)
		if not end_case(root_actor.health.current<hp and (root_actor.health.terminal or root_actor.attack_behavior.state==&"recovery")):finish(false,"root_actual_shot_failed");return
	begin_case("dead_walk_through_and_return")
	var hp := controller.actor_resources.health.current
	var ok := await move_to(_root_home.x+220,240)
	ok = ok and await move_to(_root_home.x-240,240)
	if not end_case(ok and root_actor.health.terminal and controller.actor_resources.health.current==hp):finish(false,"root_dead_walk_failed");return
	begin_case("full_connection_and_gear_return")
	_enemy_policy_busy = false
	var far_area := PlainsRegionGenerator.new()._area(stage.manifest,str(edge.b))
	ok = await move_to(float(far_area.position[0]),500)
	observed_edges.append({"id":edge_id,"forward":true,"start_tick":full_edge_start,"end_tick":trace_ticks,"reached":ok,"recovery_count":_recovery_serial})
	var return_start := trace_ticks+1
	var indices: Array = edge.modules.duplicate()
	indices.reverse()
	for index: Variant in indices:
		var module: PlatformingModule = stage.modules[int(index)]
		ok = ok and await move_to(module.world_exit().x,500)
		ok = ok and await reverse_module(module)
	var near_area := PlainsRegionGenerator.new()._area(stage.manifest,str(edge.a))
	ok = ok and await move_to(float(near_area.position[0]),500)
	observed_edges.append({"id":edge_id,"forward":false,"start_tick":return_start,"end_tick":trace_ticks,"reached":ok,"recovery_count":_recovery_serial})
	if not end_case(ok and motor.is_on_floor() and root_actor.health.terminal and controller.actor_resources.health.current==hp,{"from_area":edge.b,"to_area":edge.a}):finish(false,"root_full_connection_return_failed");return
	finish(true,"route_target_reached")

func wait_for_safe_return_approach(takeoff: float) -> void:
	var b: EnemyAttackBehavior = root_actor.attack_behavior
	# Do not walk back into a still-live mark left behind during the forward jump.
	if b.state in [&"telegraph",&"attack"] and b.attack_goal.x >= takeoff-40 and b.attack_goal.x <= motor.global_position.x+40:
		var escape := _root_home.x+140 if absf(motor.global_position.x-b.attack_goal.x)<45 else motor.global_position.x
		if absf(escape-motor.global_position.x)>1:await move_to(escape,100)
		controller.router.set_move_axis(0)
		for unused: int in 80:
			if b.state not in [&"telegraph",&"attack"]:break
			await tick()
