extends SceneTree
## Isolated G1 golden. Never a replacement for the formal campaign/reward consumer.
const AUDIO := preload("res://tests/audio_teardown.gd")
var assertions := 0
var failures := 0
var tick := 0
var world: Node2D
var player: PlayerMotor
var controller: PlayerController
var encounter: RootbellGuardianV2
var policy: FrameDamagePolicy
var life: DemoLifetime
var geometry: Dictionary
var events: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var accepted_shots := 0
var hook_contacts := 0
var defeats := 0
var comparison_rows: Array[Dictionary] = []
var _auto_strategy := ""
var _next_auto_tick := 0
var _caption: Label
var contact: DemoContactEmitter
var seal: BossArenaSeal
var _fire_gates: Dictionary = {}
var _fixture_serial := 0
var _selection := ""
var _h_reaction_delay_frames := 0
var _h_ingress_hold_frames := 12
var _sample_id := ""
class ArenaInk extends Node2D:
	var layout: Dictionary
	func _draw() -> void:
		for row: Dictionary in layout.platforms:
			var a: Array = row.rect
			draw_rect(Rect2(a[0],a[1],a[2],a[3]),Color("47675d") if row.get("one_way",false) else Color("35473c"))
		var safe: Array = layout.safe_return
		draw_circle(Vector2(safe[0],safe[1]+18),8,Color("e0ca7b"))
func _initialize() -> void:
	node_added.connect(_watch_projectile)
	run.call_deferred()
func _watch_projectile(node: Node) -> void:
	if not node is PlayerProjectile: return
	(node as PlayerProjectile).impacted.connect(func(point: Vector2, _direction: Vector2) -> void:
		if not is_instance_valid(encounter) or not is_instance_valid(encounter._bell): return
		var query := PhysicsShapeQueryParameters2D.new()
		var circle := CircleShape2D.new()
		circle.radius = (node as PlayerProjectile).radius
		query.shape = circle
		query.transform = Transform2D(0,point)
		query.collision_mask = 0xFFFFFFFF
		for hit: Dictionary in world.get_world_2d().direct_space_state.intersect_shape(query):
			events.append({"event":"actual_projectile_impact_probe","tick":tick,"collider":hit.get("collider").get_instance_id() if hit.get("collider") is Node else 0,"point":[point.x,point.y]})
			if hit.get("collider") == encounter._bell:
				events.append({"event":"actual_bell_projectile_block","tick":tick,"bell":encounter._bell.get_instance_id(),"point":[point.x,point.y],"boss_hp":encounter.health.current,"bell_id":encounter._bell.get_instance_id() if is_instance_valid(encounter._bell) else 0,"bell_state":String(encounter._bell.state)})
	)
func check(ok: bool, label: String) -> void:
	assertions += 1
	print("FOREST BOSS DEPTH CHECK: ","PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func frames(count: int) -> void:
	for i: int in count:
		_auto_fire()
		if is_instance_valid(contact) and is_instance_valid(encounter): contact.enabled = encounter.body_contact_enabled()
		await physics_frame
		await process_frame
		tick += 1
		if is_instance_valid(_caption) and is_instance_valid(encounter):
			_caption.text = "ISOLATED BOSS GOLDEN | " + _auto_strategy + " | tick %s\nBoss %s/%s | Player %s | phase %s | %s | CORE %s" % [tick,encounter.health.current,encounter.health.capacity,controller.actor_resources.health.current,encounter.stage_phase,encounter.mode,encounter.core_open]
		if is_instance_valid(player) and tick % 1 == 0:
			var moved := false
			if not samples.is_empty() and is_instance_valid(encounter._bell):
				var previous: Dictionary = samples[-1]
				if previous.get("bell_id",0)==encounter._bell.get_instance_id() and previous.get("bell_p",[]).size()==2:
					moved = encounter._bell.global_position.distance_to(Vector2(previous.bell_p[0],previous.bell_p[1]))>0.1
			samples.append({"fixture":_fixture_serial,"tick":tick,"p":[player.position.x,player.position.y],"hp":controller.actor_resources.health.current,"mode":String(encounter.mode),"boss_hp":encounter.health.current,"boss_p":[encounter.motor.position.x,encounter.motor.position.y],"boss_steps":(encounter.motor as ForestBossMotor).motion_steps,"phase":encounter.stage_phase,"bell_moved":moved,"bell_id":encounter._bell.get_instance_id() if is_instance_valid(encounter._bell) else 0,"bell_state":String(encounter._bell.state) if is_instance_valid(encounter._bell) else "absent","bell_p":[encounter._bell.global_position.x,encounter._bell.global_position.y] if is_instance_valid(encounter._bell) else [],"hook":String(controller.traversal.state),"floor":player.is_on_floor()})
func slab(row: Dictionary) -> void:
	var a: Array = row.rect
	var body := StaticBody2D.new()
	body.position = Vector2(a[0]+a[2]*.5,a[1]+a[3]*.5)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(a[2],a[3])
	shape.shape = rect
	shape.one_way_collision = row.get("one_way",false)
	body.add_child(shape)
	body.set_meta(&"arena_platform_id",String(row.id))
	if shape.one_way_collision: body.add_to_group(&"one_way_platform")
	world.add_child(body)
func fixture(ablate_bell: bool = false, ablate_counter: bool = false) -> void:
	await cleanup()
	_fixture_serial += 1
	world = Node2D.new()
	root.add_child(world)
	geometry = ForestBossArenaFactory.new().from_prep(Vector2.ZERO,1)
	_auto_strategy = ""
	_fire_gates.clear()
	var ink := ArenaInk.new()
	ink.layout = geometry
	world.add_child(ink)
	var camera := Camera2D.new()
	camera.position = Vector2(geometry.arena_center[0],geometry.arena_center[1]-210)
	world.add_child(camera)
	var canvas := CanvasLayer.new()
	world.add_child(canvas)
	_caption = Label.new()
	_caption.position = Vector2(18,18)
	canvas.add_child(_caption)
	check(geometry.get("ok",false),"factory produces isolated guardian geometry")
	for row: Dictionary in geometry.platforms: slab(row)
	for row: Dictionary in geometry.hook_anchors:
		var anchor := GrappleAnchor.new()
		anchor.position = Vector2(row.position[0],row.position[1])
		world.add_child(anchor)
	player = load("res://game/player/player.tscn").instantiate() as PlayerMotor
	var spawn: Array = geometry.safe_return
	player.position = Vector2(spawn[0],spawn[1]) # Initial spawn only.
	world.add_child(player)
	controller = player.get_node("Controller") as PlayerController
	controller.enable_shot_energy()
	controller.traversal.grant(&"grapple")
	controller.shoot_ability.shot_fired.connect(func(aim: Vector2, serial: int) -> void:
		accepted_shots += 1
		events.append({"event":"accepted_shot","tick":tick,"serial":serial,"aim":[aim.x,aim.y]})
	)
	controller.traversal.hook_contact.connect(func(point: Vector2) -> void:
		hook_contacts += 1
		events.append({"event":"hook_contact","tick":tick,"point":[point.x,point.y],"target":controller.traversal.hook_target.get_class() if is_instance_valid(controller.traversal.hook_target) else "none","bell_target":is_instance_valid(encounter) and controller.traversal.hook_target is GuardianRootBellV2})
	)
	life = DemoLifetime.new()
	policy = FrameDamagePolicy.new()
	policy.lifetime = life
	world.add_child(policy)
	policy.register_target(&"player",controller.actor_resources.health,true)
	policy.batch_resolved.connect(func(results: Array[DamageResult]) -> void:
		for result: DamageResult in results:
			events.append({"event":"policy_result","tick":tick,"source":String(result.request.source_id),"target":String(result.request.target_id),"id":String(result.request.event_id),"physics_frame":result.request.physics_tick,"hp":result.health.current,"amount":result.request.amount})
	)
	var body := load("res://scenes/bosses/rootbell_guardian_v2.tscn").instantiate() as BossMotor
	body.position = Vector2(geometry.boss_position[0],geometry.boss_position[1])
	if ablate_bell or ablate_counter:
		var local_encounter := body.get_node("Encounter") as RootbellGuardianV2
		local_encounter.definition = local_encounter.definition.duplicate(true)
		if ablate_bell: (local_encounter.definition as BossDuelDefinition).bell_enabled = false
		if ablate_counter: (local_encounter.definition as BossDuelDefinition).bell_counter_enabled = false
	world.add_child(body)
	encounter = body.get_node("Encounter") as RootbellGuardianV2
	check(policy.bind_damageable(&"boss",encounter.damageable,encounter.health),"one formal-style boss health policy binding")
	check(encounter.bind_duel(geometry,controller,policy,life),"static side terrain binds without another Boss health registration")
	check(encounter.bind_duel(geometry,controller,policy,life),"identical duel bind is idempotent")
	encounter.duel_event.connect(func(row: Dictionary) -> void:
		var value := row.duplicate(true)
		value["tick"] = tick
		value["fixture"] = _fixture_serial
		events.append(value)
	)
	encounter.projectile_created.connect(func(shot: BossProjectile) -> void:
		shot.hit.connect(func(_target: Node2D, id: StringName, amount: float) -> void:
			var request := DamageRequest.new()
			request.token = life.token()
			request.event_id = id
			request.source_id = &"guardian_hammer"
			request.target_id = &"player"
			request.amount = amount
			request.actor_epoch = life.actor_epoch
			request.health_epoch = controller.actor_resources.health.epoch
			policy.submit(request)
		)
	)
	contact = DemoContactEmitter.new()
	contact.policy = policy
	contact.controller = controller
	contact.source_id = &"guardian_body_contact"
	contact.half_size = encounter.definition.collision_size*.5
	body.add_child(contact)
	encounter.defeated.connect(func(_boss: BossEncounter) -> void: defeats += 1)
	var a: Array = geometry.boss_arena
	check(encounter.configure_arena(a[0],a[0]+a[2],player),"real boss bounds configure")
	encounter.configure_forest_floor(a[1]+a[3])
	check(encounter.activate(),"real boss activates without phase/health injection")
	seal=BossArenaSeal.new()
	world.add_child(seal)
	var arena_rect:=Rect2(a[0],a[1],a[2],a[3])
	seal.setup(arena_rect,arena_rect,controller,encounter,life)
	check(seal.arm(),"production BossArenaSeal arms only after full player entry")
	await frames(110)
	check(seal.closed and seal.close_count==1,"production seal really closes two physical walls before comparison")
func cleanup() -> void:
	if not is_instance_valid(world): return
	controller.router.clear("forest_boss_depth_cleanup")
	controller.active = false
	life.end()
	encounter.cancel()
	var receipt: Dictionary = AUDIO.stop_fallback_voices(world)
	world.free()
	world = null
	player = null
	encounter = null
	controller = null
	policy = null
	life = null
	check(await AUDIO.wait_fallback_release(receipt),"owned audio voices drain before strict exit")
func walk_to(x: float, limit: int = 240) -> bool:
	for i: int in limit:
		if absf(player.position.x-x)<5:
			controller.router.set_move_axis(0)
			await frames(2)
			return true
		controller.router.set_move_axis(signf(x-player.position.x))
		await frames(1)
	controller.router.set_move_axis(0)
	return false
func wait_mode(wanted: StringName, limit: int = 300) -> bool:
	for i: int in limit:
		if encounter.mode == wanted: return true
		await frames(1)
	return false
func fire(point: Vector2) -> void:
	controller.router.request_action(&"shoot_release",(point-player.position).normalized())
	await frames(25)
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="): _selection=argument.trim_prefix("--only=")
	if not _selection.is_empty():
		if _selection=="tolerance":
			for settings: Array in [[0,9],[0,12],[0,15],[3,12],[6,12],[9,12]]:
				_h_reaction_delay_frames=int(settings[0])
				_h_ingress_hold_frames=int(settings[1])
				_sample_id="H_delay%s_hold%s" % settings
				await compare_strategy("H")
		elif _selection in ["H","ground_walk_shoot","jump_no_H","jump_peek_no_H","stationary_shoot","evade_then_stationary"]: await compare_strategy(_selection)
		else:
			push_error("Unknown explicit movie scenario")
			quit(2)
			return
		await cleanup()
		write_capture_and_exit()
		return
	await fixture(true) # Explicit bell ablation isolates actual body/ordinary terrain.
	var pristine := encounter.combat_snapshot()
	for invalid: Variant in [null,7,[],"bad"]:
		var malformed := pristine.duplicate(true)
		malformed["duel_roots"] = invalid
		encounter.restore_combat_state(malformed)
		check(not encounter.last_restore_accepted and encounter.combat_snapshot()==pristine,"retired root-state field rejects atomically")
	var wrong_version := pristine.duplicate(true)
	wrong_version["duel_version"] = "wrong"
	encounter.restore_combat_state(wrong_version)
	check(not encounter.last_restore_accepted and encounter.combat_snapshot()==pristine,"unknown duel version rejects")
	var invalid_position := pristine.duplicate(true)
	invalid_position.body_position = [INF,1]
	encounter.restore_combat_state(invalid_position)
	check(not encounter.last_restore_accepted and encounter.combat_snapshot()==pristine,"nonfinite body position rejects whole restore")
	var start := tick
	var original_body := encounter.motor.global_position
	check(encounter.core_open,"normal core is vulnerable without a root or H key")
	check(await wait_mode(&"pursuit_warning"),"real current support creates committed body warning")
	var locked := encounter.attack_goal
	await walk_to(220)
	check(await wait_mode(&"landing_recovery",180),"actual body flies to old terrain and physically lands")
	check(encounter.motor.global_position.distance_to(original_body)>100,"real BossMotor motion changes body location")
	check(encounter.attack_goal==locked and encounter._cycles>=1,"actual completed Body cycle preserves the locked old support point")
	var terrain_collision := false
	for event: Dictionary in events:
		if int(event.get("tick",0))>=start and event.get("event","")=="body_collision" and event.get("kind","")=="terrain": terrain_collision=true
	check(terrain_collision,"ordinary terrain actual collider event is present")
	var hp_before := encounter.health.current
	await fire(encounter.motor.global_position)
	check(encounter.health.current==hp_before-1,"ordinary normal bullet damages the normally open core")
	var pause_position := encounter.motor.global_position
	var pause_clock := encounter.clock
	paused=true
	for i: int in 5: await process_frame
	check(encounter.motor.global_position==pause_position and encounter.clock==pause_clock,"pause freezes actual body motion and action clock")
	paused=false
	check(await wait_mode(&"pursuit_flight",240),"cancellation case has an actual committed body flight")
	var old_epoch := encounter.attack_epoch
	encounter.cancel_pending_attacks()
	check(encounter.attack_epoch==old_epoch+1 and encounter.mode!=&"pursuit_flight","cancel stops old flight without teleporting player")
	cases.append({"id":"normal_core_motion_terrain_pause_cancel","start_tick":start,"end_tick":tick,"boss_hp":encounter.health.current,"player_hp":controller.actor_resources.health.current})
	await bell_mechanism_case()
	await stationary_impact_case()
	await static_branch_case()
	await compare_strategy("H")
	await compare_strategy("H",false,true)
	await compare_strategy("ground_walk_shoot")
	await compare_strategy("jump_no_H")
	await compare_strategy("jump_peek_no_H")
	await compare_strategy("stationary_shoot")
	await compare_strategy("evade_then_stationary")
	await compare_strategy("H",true,true)
	await cleanup()
	write_capture_and_exit()
func write_capture_and_exit() -> void:
	var out := "res://build/forest_depth/boss/native"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): out=argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out+"/capture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"isolated guardian candidate; stage evidence is per capture, not formal rewards/player/device acceptance","version":ForestBossArenaFactory.VERSION,"mechanic_version":RootbellGuardianV2.DUEL_VERSION,"scenario_selection":_selection,"arena":geometry.boss_arena,"assertions":assertions,"failures":failures,"cases":cases,"comparisons":comparison_rows,"events":events,"samples":samples},"\t"))
	file.close()
	file=null
	print("FOREST BOSS DEPTH: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)
func _fire_gate(reason: String) -> void:
	_fire_gates[reason]=int(_fire_gates.get(reason,0))+1
func _auto_fire() -> void:
	if _auto_strategy.is_empty() or not is_instance_valid(encounter) or encounter.health.terminal: return
	if not encounter.core_open:
		_fire_gate("core_intro")
		return
	if controller.traversal.busy() or controller.traversal.state==&"hook_kick":
		_fire_gate("actual_traversal_busy")
		return
	if tick<_next_auto_tick:
		_fire_gate("normal_cooldown")
		return
	# All moving strategies clear the actual old danger point before recoil.
	if _auto_strategy not in ["stationary_shoot","evade_then_stationary"] and encounter.mode in [&"pursuit_warning",&"pursuit_flight"] and player.global_position.distance_to(encounter.attack_goal-Vector2(0,18)) < encounter.definition.collision_size.x+24:
		_fire_gate("clearing_committed_danger")
		return
	# All six strategies may aim at actually visible physical body edges, not
	# just its centre. Bell geometry must earn its interception of each ray.
	var half := encounter.definition.collision_size*.5-Vector2(4,4)
	var points: Array[Vector2] = [Vector2.ZERO,Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(0,-half.y),Vector2(-half.x,half.y),Vector2(half.x,half.y)]
	var aim := Vector2(INF,INF)
	var aim_offset := Vector2.ZERO
	for offset: Vector2 in points:
		var candidate := encounter.motor.global_position+offset
		var query := PhysicsRayQueryParameters2D.create(player.global_position+Vector2(0,-6),candidate,13,[player.get_rid()])
		var hit := world.get_world_2d().direct_space_state.intersect_ray(query)
		if hit.get("collider") == encounter.motor:
			aim = candidate
			aim_offset = offset
			break
	if not aim.is_finite():
		_fire_gate("no_visible_body_point")
		return
	if encounter.mode==&"pursuit_flight":
		var lead := minf(player.global_position.distance_to(aim)/player.tuning.projectile_speed,maxf(0,(encounter.definition as BossDuelDefinition).pursuit_flight_seconds-encounter._flight_age))
		aim += encounter.motor.velocity*lead+Vector2(0,.5*(encounter.definition as BossDuelDefinition).pursuit_gravity*lead*lead)
	_fire_gate("shoot_requested")
	controller.router.request_action(&"shoot_release",(aim-player.global_position).normalized())
	_next_auto_tick=tick+ceili(player.tuning.shot_cooldown*Engine.physics_ticks_per_second)
	events.append({"event":"legal_combo_request","tick":tick,"strategy":_auto_strategy,"aim_offset":[aim_offset.x,aim_offset.y],"aim":[aim.x,aim.y],"from":[player.position.x,player.position.y]})
func compare_strategy(strategy: String, stop_at_phase2: bool = false, ablate_counter: bool = false) -> void:
	await fixture(false,ablate_counter)
	var start:=tick
	var event_start:=events.size()
	var shots_start:=accepted_shots
	var hooks_start:=hook_contacts
	var defeats_start:=defeats
	var initial_hp:=controller.actor_resources.health.current
	var initial_stamina:=controller.actor_resources.stamina.current
	var initial_boss:=encounter.health.current
	var initially_sealed:=seal.closed
	var direction:=1
	var last_reacted_attack: StringName
	var last_bell_hook: int = -1
	var next_peek_jump := tick
	var last_bell_launch_jump := -1
	var first_bell_evaded := false
	var offensive_arrived := false
	var budget:=2400
	var stop_reason:="budget"
	_auto_strategy=strategy
	_next_auto_tick=tick
	events.append({"event":"comparison_start","tick":tick,"strategy":strategy})
	while tick-start<budget and not encounter.health.terminal and not controller.actor_resources.health.terminal:
		if stop_at_phase2 and encounter.stage_phase==2: break
		if controller.traversal.state in [&"hook_contact_kick",&"hook_kick"] and controller.traversal.hook_target is GuardianRootBellV2: offensive_arrived = true
		if strategy=="H" and offensive_arrived and encounter.mode not in [&"pursuit_warning",&"pursuit_flight"]:
			var engage_x := encounter.motor.global_position.x-player.global_position.x
			direction = int(signf(engage_x)) if absf(engage_x)>165 else 0
		if player.position.x>float(geometry.boss_arena[0])+float(geometry.boss_arena[2])-110: direction=-1
		elif player.position.x<float(geometry.boss_arena[0])+100: direction=1
		if player.position.y>float(geometry.arena_center[1])+40 or player.position.x<float(geometry.boss_arena[0])-20 or player.position.x>float(geometry.boss_arena[0])+float(geometry.boss_arena[2])+20:
			stop_reason="escaped_arena"
			break
		if strategy=="jump_peek_no_H":
			var dx := encounter.motor.global_position.x-player.global_position.x
			direction = int(signf(dx)) if absf(dx)>130 else 0
			if encounter.mode in [&"pursuit_warning",&"pursuit_flight"] and absf(player.global_position.x-encounter.attack_goal.x)<100:
				direction = -int(signf(encounter.motor.global_position.x-player.global_position.x))
		if strategy=="H" and not offensive_arrived and encounter.mode in [&"bell_warning",&"bell_watch"] and is_instance_valid(encounter._bell):
			if last_bell_hook != encounter._bell.get_instance_id():
				var branch_row: Dictionary = geometry.side_branches[0 if encounter._bell.facing < 0 else 1]
				var branch_x := float(branch_row.rect[0])+float(branch_row.rect[2])*.5
				direction = int(signf(branch_x-player.global_position.x)) if absf(branch_x-player.global_position.x)>4 else 0
			else:
				var dx := encounter.motor.global_position.x-player.global_position.x
				direction = int(signf(dx)) if absf(dx)>130 else 0
		controller.router.set_move_axis(0 if strategy in ["stationary_shoot","evade_then_stationary"] else direction)
		if strategy=="evade_then_stationary" and not first_bell_evaded and is_instance_valid(encounter._bell) and encounter._bell.state==&"outbound" and player.global_position.distance_to(encounter._bell.global_position)<190:
			first_bell_evaded = true
			controller.router.set_jump_held(&"boss_depth",true)
			await frames(12)
			controller.router.set_jump_held(&"boss_depth",false)
		if strategy=="H" and controller.traversal.state==&"free" and player.is_on_floor() and is_instance_valid(encounter._bell) and encounter._bell.state in [&"outbound",&"returning"] and last_bell_launch_jump != encounter._bell.get_instance_id():
			var live_distance := player.global_position.distance_to(encounter._bell.global_position)
			if live_distance < controller.traversal.definition.hook_range+player.tuning.ground_speed*0.2:
				last_bell_launch_jump=encounter._bell.get_instance_id()
				controller.router.set_move_axis(signf(encounter._bell.global_position.x-player.global_position.x))
				controller.router.set_jump_held(&"boss_depth",true)
				events.append({"event":"actual_bell_ingress_jump","tick":tick,"bell_id":encounter._bell.get_instance_id(),"distance":live_distance,"hold_frames":_h_ingress_hold_frames})
				await frames(_h_ingress_hold_frames)
				controller.router.set_jump_held(&"boss_depth",false)
		if strategy=="jump_peek_no_H" and player.is_on_floor() and tick>=next_peek_jump:
			var peek_ray := PhysicsRayQueryParameters2D.create(player.global_position+Vector2(0,-6),encounter.motor.global_position,13,[player.get_rid()])
			if world.get_world_2d().direct_space_state.intersect_ray(peek_ray).get("collider") != encounter.motor or encounter.mode in [&"bell_warning",&"pursuit_warning"]:
				controller.router.set_jump_held(&"boss_depth",true)
				await frames(12)
				controller.router.set_jump_held(&"boss_depth",false)
				next_peek_jump=tick+12
		if strategy=="H" and controller.traversal.state==&"free" and is_instance_valid(encounter._bell) and encounter._bell.state in [&"outbound",&"returning"] and not controller.traversal.hook_used and last_bell_hook!=encounter._bell.get_instance_id():
			var hook_from := player.global_position+Vector2(0,-6)
			var bell_goal := encounter._bell.global_position
			if hook_from.distance_to(bell_goal) < controller.traversal.definition.hook_range-12 and can_intercept_bell(encounter._bell,hook_from):
				var sight := PhysicsRayQueryParameters2D.create(hook_from,bell_goal,0xFFFFFFFF,[player.get_rid()])
				sight.collide_with_areas = true
				if world.get_world_2d().direct_space_state.intersect_ray(sight).get("collider") == encounter._bell:
					var candidate := encounter._bell
					last_bell_hook = candidate.get_instance_id()
					if _h_reaction_delay_frames>0: await frames(_h_reaction_delay_frames)
					if is_instance_valid(candidate) and candidate==encounter._bell and controller.traversal.state==&"free":
						hook_from=player.global_position+Vector2(0,-6)
						bell_goal=candidate.global_position
						var fresh_sight := PhysicsRayQueryParameters2D.create(hook_from,bell_goal,0xFFFFFFFF,[player.get_rid()])
						fresh_sight.collide_with_areas=true
						if hook_from.distance_to(bell_goal)<controller.traversal.definition.hook_range-12 and can_intercept_bell(candidate,hook_from) and world.get_world_2d().direct_space_state.intersect_ray(fresh_sight).get("collider")==candidate:
							events.append({"event":"moving_bell_hook_request","tick":tick,"from":[hook_from.x,hook_from.y],"goal":[bell_goal.x,bell_goal.y],"distance":hook_from.distance_to(bell_goal),"reaction_delay_frames":_h_reaction_delay_frames})
							controller.router.request_action(&"grapple",(moving_bell_aim(candidate,hook_from)-hook_from).normalized())
		if encounter.mode in [&"pursuit_warning",&"bell_warning"] and last_reacted_attack!=StringName("%s/%s" % [encounter.mode,encounter._attack_serial]):
			last_reacted_attack=StringName("%s/%s" % [encounter.mode,encounter._attack_serial])
			if strategy=="H" and encounter.mode==&"pursuit_warning":
				direction = int(signf(player.global_position.x-encounter.attack_goal.x))
				if direction==0: direction=-int(signf(encounter.motor.global_position.x-player.global_position.x))
				controller.router.set_move_axis(direction)
				controller.router.set_jump_held(&"boss_depth",true)
				await frames(12)
				controller.router.set_jump_held(&"boss_depth",false)
			elif strategy=="jump_no_H":
				controller.router.set_jump_held(&"boss_depth",true)
				await frames(12)
				controller.router.set_jump_held(&"boss_depth",false)
		await frames(1)
	if encounter.health.terminal: stop_reason="normal_projectile_defeat"
	elif controller.actor_resources.health.terminal: stop_reason="player_dead"
	_auto_strategy=""
	controller.router.set_move_axis(0)
	controller.router.set_jump_held(&"boss_depth",false)
	if stop_at_phase2:
		check(encounter.stage_phase==2 and not encounter.health.terminal,"normal real bullets reach a non-default live phase2 without HP or phase injection")
		var saved := encounter.combat_snapshot()
		for bad: Dictionary in [{"cycles":0},{"stage_phase":1.5},{"stage_phase":3},{"weak_side":0},{"weak_side":"left"},{"intro_duration":INF},{"next_bell":1}]:
			var malformed := saved.duplicate(true)
			malformed.merge(bad,true)
			encounter.restore_combat_state(malformed)
			check(not encounter.last_restore_accepted and encounter.combat_snapshot()==saved,"malformed phase/side/intro/action restore rejects atomically")
		encounter.restore_combat_state(saved)
		check(encounter.last_restore_accepted and encounter.stage_phase==saved.stage_phase and encounter.weak_side==saved.weak_side and encounter.intro_duration==saved.intro_duration,"actual non-default phase2 restore preserves phase, side and intro duration")
		await frames(2)
		check(encounter.stage_phase==2,"restored phase2 remains correct on actual subsequent physics ticks")
		cases.append({"id":"actual_phase2_restore","start_tick":start,"end_tick":tick,"saved_phase":saved.stage_phase,"restored_phase":encounter.stage_phase,"boss_hp":encounter.health.current,"player_hp":controller.actor_resources.health.current})
		return
	var hits:=0
	var launches:=0
	var staggers:=0
	var core_hits_while_moving:=0
	var moving_bell_hooks:=0
	var counter_hits:=0
	var counter_damage:=0.0
	var bell_launches:=0
	var phase1_body_launches:=0
	var phase2_body_launches:=0
	var phase2_overlap_frames:=0
	for sample: Dictionary in samples:
		if start<=int(sample.tick) and int(sample.tick)<=tick and sample.get("phase")==2 and sample.get("mode")=="pursuit_flight" and sample.get("bell_state") in ["outbound","returning"] and sample.get("bell_moved",false): phase2_overlap_frames+=1
	for index: int in range(event_start,events.size()):
		var event: Dictionary=events[index]
		if event.get("event")=="policy_result" and event.get("target")=="boss" and String(event.get("source","")).begins_with("guardian_bell_counter:"):
			counter_hits+=1
			counter_damage+=float(event.amount)
		if event.get("event","")=="hook_contact" and event.get("bell_target",false): moving_bell_hooks+=1
		if event.get("event","")=="bell_launch": bell_launches+=1
		if event.get("event","")=="body_launch":
			launches+=1
			if event.get("phase")==1: phase1_body_launches+=1
			if event.get("phase")==2: phase2_body_launches+=1
		if event.get("event","")=="policy_result" and event.get("target","")=="boss": hits+=1
	var body_routes: Array[Dictionary] = []
	var max_phase2_floor_travel := 0.0
	for launch: Dictionary in events.slice(event_start):
		if launch.get("event")!="body_launch": continue
		for collision: Dictionary in events.slice(event_start):
			if collision.get("event")!="body_collision" or collision.get("attack_id")!=launch.attack_id: continue
			var actual_end := Vector2(collision.body_position[0],collision.body_position[1])
			var actual_start := Vector2(launch.from[0],launch.from[1])
			var horizontal := absf(actual_end.x-actual_start.x)
			body_routes.append({"phase":launch.phase,"from":launch.from,"goal":launch.goal,"end":collision.body_position,"horizontal_travel":horizontal,"platform_id":collision.platform_id,"normal":collision.normal})
			if launch.phase==2 and absf(actual_start.y-(float(geometry.arena_center[1])-encounter.definition.collision_size.y*.5))<3:
				max_phase2_floor_travel=maxf(max_phase2_floor_travel,horizontal)
			break
	var row_id := "H_pure_shift" if ablate_counter else strategy
	if not _sample_id.is_empty(): row_id=_sample_id
	var row:={"id":row_id,"reaction_delay_frames":_h_reaction_delay_frames,"ingress_hold_frames":_h_ingress_hold_frames,"counter_enabled":not ablate_counter,"fire_gates":_fire_gates.duplicate(true),"body_routes":body_routes,"max_phase2_floor_travel":max_phase2_floor_travel,"offensive_arrived":offensive_arrived,"counter_hits":counter_hits,"counter_damage":counter_damage,"learning_cycle_covered":bell_launches>=2 and launches>=2 and phase1_body_launches>0 and phase2_body_launches>0 and phase2_overlap_frames>0,"start_tick":start,"end_tick":tick,"budget_ticks":budget,"initially_sealed":initially_sealed,"seal_close_count":seal.close_count,"elapsed_ticks":tick-start,"stop_reason":stop_reason,"initial_boss_hp":initial_boss,"boss_hp":encounter.health.current,"initial_player_hp":initial_hp,"player_hp":controller.actor_resources.health.current,"initial_stamina":initial_stamina,"final_stamina":controller.actor_resources.stamina.current,"accepted_shots":accepted_shots-shots_start,"hook_contacts":hook_contacts-hooks_start,"moving_bell_hooks":moving_bell_hooks,"defeats":defeats-defeats_start,"boss_hits":hits,"body_launches":launches,"bell_launches":bell_launches,"phase1_body_launches":phase1_body_launches,"phase2_body_launches":phase2_body_launches,"phase2_overlap_frames":phase2_overlap_frames,"staggers":staggers,"event_start":event_start,"event_end":events.size()}
	comparison_rows.append(row)
	events.append({"event":"comparison_end","tick":tick,"strategy":strategy})
	check(tick-start<=budget+20,"strategy %s obeys common real-input time budget" % strategy)
	check(stop_reason!="escaped_arena" and initially_sealed and seal.close_count==1,"strategy %s remains in the real sealed arena, no infinite fall score" % strategy)
	if strategy=="H":
		check(moving_bell_hooks>0,"intended complete H fight actually hooks the moving bell, not only a fixed ring")
		check(encounter.health.terminal and not controller.actor_resources.health.terminal and defeats-defeats_start==1,"intended normal-resource H fight survives and actually defeats the complete Boss once")
		if not ablate_counter: check(counter_hits>0,"active counter hypothesis commits actual returned-weapon damage through normal Boss policy")
		else: check(counter_hits==0,"pure-shift ablation has no counter damage or hidden player resource grant")
	if strategy!="H": check(hook_contacts==hooks_start,"strategy %s has no H contacts" % strategy)
	print("FOREST BOSS COMPARISON: ",JSON.stringify(row))

func can_intercept_bell(bell: GuardianRootBellV2, start: Vector2) -> bool:
	if bell.state==&"outbound": return true
	var toward := bell.global_position.direction_to(bell.owner_motor.global_position)
	var closing := (bell.velocity-bell.owner_motor.velocity).dot(toward)
	if closing<=0: return true
	var half := encounter.definition.collision_size*.5
	var owner_extent := absf(toward.x)*half.x+absf(toward.y)*half.y
	var until_owner := maxf(0,bell.global_position.distance_to(bell.owner_motor.global_position)-owner_extent-bell.config.bell_radius-bell.motion_safe_margin)/closing
	var travel := start.distance_to(bell.global_position)
	var definition := controller.traversal.definition
	var until_arrival := definition.hook_windup+travel/definition.hook_flight_speed+maxf(0,travel-definition.hook_stop_distance)/definition.hook_pull_speed+definition.hook_contact_seconds
	return until_owner>until_arrival
func moving_bell_aim(bell: GuardianRootBellV2, start: Vector2) -> Vector2:
	# Actual accepted H has windup and head travel; lead the live target rather
	# than changing range/speed or calling a successful contact result.
	var predicted := bell.global_position
	for i: int in 3:
		var time := controller.traversal.definition.hook_windup+start.distance_to(predicted)/controller.traversal.definition.hook_flight_speed
		predicted = bell.global_position+bell.velocity*time
		if bell.state==&"outbound": predicted += Vector2(0,.5*bell.config.bell_gravity*time*time)
	return predicted
func bell_mechanism_case() -> void:
	await fixture()
	var start := tick
	var hp := encounter.health.current
	check(is_instance_valid(encounter._bell) and encounter._bell.state == &"held","normal intro actually presents a solid held metal bell")
	check(encounter._bell.get_node_or_null("Damageable") == null and encounter._bell.is_in_group(&"grapple_target"),"metal bell is an indestructible real hook target, not armour or a damage refund")
	# Initial ground-to-core ray hits the real counter-branch side first.
	# Jump with the real router to clear that side before testing the bell.
	controller.router.set_jump_held(&"boss_depth",true)
	await frames(12)
	controller.router.set_jump_held(&"boss_depth",false)
	await fire(encounter.motor.global_position-Vector2(0,encounter.definition.collision_size.y*.5-4))
	var blocked := false
	for event: Dictionary in events:
		if int(event.get("tick",0)) >= start and event.get("event") == "actual_bell_projectile_block": blocked = true
	check(blocked and encounter.health.current == hp,"normal real projectile impacts the actual bell collider before the normally vulnerable core")
	check(await wait_mode(&"bell_watch",180),"readable warning launches the real bell inside the former cheap-fire window")
	var mobile_hook := false
	var actual_arrival := false
	for i: int in 120:
		if not is_instance_valid(encounter._bell): break
		var start_point := player.global_position+Vector2(0,-6)
		var goal := encounter._bell.global_position
		if start_point.distance_to(goal) <= controller.traversal.definition.hook_range and not controller.traversal.hook_used:
			var ray := PhysicsRayQueryParameters2D.create(start_point,goal,0xFFFFFFFF,[player.get_rid()])
			ray.collide_with_areas = true
			var hit := world.get_world_2d().direct_space_state.intersect_ray(ray)
			if hit.get("collider") == encounter._bell:
				controller.router.request_action(&"grapple",(moving_bell_aim(encounter._bell,start_point)-start_point).normalized())
				for contact_tick: int in 90:
					await frames(1)
					if controller.traversal.state==&"hook_kick" and controller.traversal.hook_target is GuardianRootBellV2:
						actual_arrival=true
						break
				for event: Dictionary in events:
					if int(event.get("tick",0)) >= start and event.get("bell_target",false): mobile_hook = true
				break
		await frames(1)
	check(actual_arrival,"real Motor reaches the moving bell and enters accepted kick, not only head contact")
	check(mobile_hook,"real H projectile contacts the moving metal bell, with no H-based core gate")
	check(encounter.core_open,"moving-bell H contact never toggles the normally open core")
	var clock_before := encounter.clock
	var bell_before := encounter._bell.global_position if is_instance_valid(encounter._bell) else Vector2.ZERO
	paused = true
	for i: int in 5: await process_frame
	check(encounter.clock == clock_before and (not is_instance_valid(encounter._bell) or encounter._bell.global_position == bell_before),"pause freezes actual bell and body clocks")
	paused = false
	var old_bell := encounter._bell
	var hp_before_cancel := encounter.health.current
	encounter.cancel_pending_attacks()
	await frames(90)
	check(encounter.health.current==hp_before_cancel,"cancelled real armed counter cannot apply a late Boss hit")
	check(not is_instance_valid(old_bell),"epoch cancellation removes the real owned bell without a late weapon contact")
	cases.append({"id":"solid_moving_bell_block_and_H","start_tick":start,"end_tick":tick,"projectile_block":blocked,"mobile_hook":mobile_hook,"actual_arrival":actual_arrival,"boss_hp":encounter.health.current,"player_hp":controller.actor_resources.health.current})
func stationary_impact_case() -> void:
	await fixture(true) # Isolate actual body impact from the separate bell weapon.
	var start:=tick
	var initial_hp:=controller.actor_resources.health.current
	var event_start:=events.size()
	var collision_found:=false
	for i: int in 180:
		for index: int in range(event_start,events.size()):
			if events[index].get("event","")=="body_collision" and events[index].get("kind","")=="player": collision_found=true
		if collision_found: break
		await frames(1)
	await frames(2)
	check(collision_found,"standing still receives an actual KinematicCollision player impact")
	check(controller.actor_resources.health.current==initial_hp-1,"real body collision damages player once through normal damage policy")
	var applied:=false
	for index: int in range(event_start,events.size()):
		if events[index].get("event","")=="policy_result" and events[index].get("target","")=="player": applied=true
	check(applied,"standing physical impact has an actual player Policy result, not only contact geometry")
	var after_impact_hp:=controller.actor_resources.health.current
	await frames(8)
	check(controller.actor_resources.health.current==after_impact_hp,"after the one physical impact HP remains stable for eight ticks (Emitter cadence, not an independent iFrame rejection proof)")
	cases.append({"id":"stationary_physical_impact","start_tick":start,"end_tick":tick,"initial_player_hp":initial_hp,"player_hp":controller.actor_resources.health.current,"collision_found":collision_found})


func static_branch_case() -> void:
	await fixture()
	var start := tick
	check(geometry.root_supports.is_empty() and geometry.side_branches.size()==2,"retired breakable roots become two explicit static branches")
	var targets: Array = []
	for key: StringName in policy._targets.keys(): targets.append(String(key))
	targets.sort()
	check(targets==["boss","player"],"only actual Boss and Player own policy targets; no hidden root Health")
	var branches: Array[Dictionary] = []
	for row: Dictionary in geometry.side_branches:
		var actual: StaticBody2D
		for node: Node in world.get_children():
			if node is StaticBody2D and node.get_meta(&"arena_platform_id","")==String(row.id): actual=node
		check(is_instance_valid(actual),"static side branch has one real terrain body "+String(row.id))
		if not is_instance_valid(actual): continue
		var shape := actual.get_child(0) as CollisionShape2D
		var rectangle := shape.shape as RectangleShape2D
		check(actual.get_node_or_null("Damageable")==null and shape.one_way_collision,"ordinary one-way branch supports landings without a root damage/refund gate")
		branches.append({"id":row.id,"position":[actual.position.x,actual.position.y],"size":[rectangle.size.x,rectangle.size.y],"collision_layer":actual.collision_layer,"one_way":shape.one_way_collision,"damageable":false})
	cases.append({"id":"static_side_branch_contract","start_tick":start,"end_tick":tick,"policy_targets":targets,"branches":branches})
