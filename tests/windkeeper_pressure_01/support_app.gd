extends "res://tests/windkeeper_pressure_01/formal_app.gd"
## Actual formal App support surfaces, ordinary player jump and Boss movement.
## Initial placements, phase trigger and recovered stance are explicit fixtures;
## none of them creates terrain, alters player physics/HP or teleports the Boss.
var support_arena: WindkeeperArena
var authored_supports: Array[Rect2] = []
var phase_support_ready := false

func live_world() -> bool:
	return is_instance_valid(app) and is_instance_valid(encounter) and is_instance_valid(app.stage) and is_instance_valid(app.player) and is_instance_valid(app.controller)

func rect_values(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func foot_probes(label: String, ordinary: bool = true) -> void:
	if not live_world():
		check(false, "support sample retains actual formal App world")
		return
	var metrics: Dictionary = encounter.combat_metrics()
	var supported: Rect2 = metrics.get("support_rect", Rect2())
	check(not bool(metrics.get("airborne", true)) and bool(metrics.get("support_verified", false)) and supported.size.x > 0,
		"actual landed guardian owns a verified nonempty support surface")
	if bool(metrics.get("airborne", true)) or supported.size.x <= 0: return
	var pose: Dictionary = encounter.rig_pose()
	var feet: Array = pose.feet
	var excluded: Array[RID] = [app.player.get_rid(), app.stage.boss.get_rid()]
	var rows: Array[Dictionary] = []
	var checked := 0
	for index: int in 4:
		var lifted := false
		if not ordinary:
			if encounter.mode in [&"platform_warning", &"platform"]: lifted = index == 0
			elif encounter.mode in [&"stomp_warning", &"stomp"]:
				lifted = index == int(encounter.foot_index) or (index < 2 and bool(encounter._group_plan.get("double_stomp", false)))
			elif encounter.mode == &"link": lifted = index == 1
		if lifted:
			rows.append({"foot": index, "advertised_lifted_attack_foot": true})
			continue
		var point: Vector2 = app.stage.boss.to_global(feet[index])
		var radius: float = float(pose.get("foot_radius", 12))
		var query := PhysicsRayQueryParameters2D.create(point - Vector2(0, 2), point + Vector2(0, radius + 3), 1, excluded)
		var hit: Dictionary = app.player.get_world_2d().direct_space_state.intersect_ray(query)
		var physical := (not hit.is_empty() and (hit.get("normal", Vector2.ZERO) as Vector2).dot(Vector2.UP) > .7
			and absf((hit.get("position", Vector2.INF) as Vector2).y - supported.position.y) < 3
			and point.x >= supported.position.x and point.x <= supported.end.x)
		check(physical, "actual support foot ray reaches a real upward platform face: " + label)
		checked += 1
		rows.append({"foot": index, "actual_world_point": point, "radius": radius,
			"physical_support": physical, "surface_point": hit.get("position", Vector2.INF),
			"normal": hit.get("normal", Vector2.ZERO), "collider": str(hit.collider.get_path()) if not hit.is_empty() else ""})
	if ordinary: check(checked == 4, "all four ordinary stance feet have independent actual support probes")
	observations.append({"case": "actual guardian support probes", "label": label, "support_rect": rect_values(supported),
		"state": String(encounter.mode), "ordinary_four_foot_stance": ordinary, "probes": rows})

func phase3_support() -> void:
	if not await setup(): return
	for child: Node in encounter.get_children():
		if child is WindkeeperArena: support_arena = child as WindkeeperArena
	check(support_arena != null and encounter.has_method("bridge_break_ready"),
		"actual formal Arena and explicit grounded bridge-release capability are installed")
	if support_arena == null or not encounter.has_method("bridge_break_ready"): return
	var initial_metrics: Dictionary = encounter.combat_metrics()
	check(bool(initial_metrics.get("supports_bound", false)), "formal encounter binds real map support rectangles")
	var selected := Rect2()
	var farthest := -INF
	for index: int in [1,2,3]:
		var slab: Rect2 = support_arena.module.definition.platforms[index]
		var world_rect := Rect2(support_arena.module.to_global(slab.position), slab.size)
		authored_supports.append(world_rect)
		var distance: float = absf(world_rect.get_center().x - app.stage.boss.global_position.x)
		if distance > farthest:
			farthest = distance
			selected = slab
	var floor_rect: Rect2 = support_arena.module.definition.platforms[0]
	var at: Vector2 = support_arena.module.to_global(Vector2(selected.get_center().x, floor_rect.position.y - 18))
	relocate(at, "ground under a real shelf away from the guardian's initial landing")
	await ticks(3)
	check(app.player.is_on_floor() and not support_arena.broken, "actual floor supports phase-trigger entry before break")
	var player_hp: float = app.controller.actor_resources.health.current
	var target_hp: float = encounter.health.capacity * encounter._config().phase_three_health - 1
	var request := ActorResourceRequest.new(&"explicit-support-third-phase-fixture", encounter.health.epoch,
		encounter.health.current - target_hp, encounter.health.get_instance_id())
	check(encounter.health.apply_damage(request).accepted(), "declared Boss resource fixture triggers actual phase3 health band")
	encounter.set_physics_process(true)
	app.controller.router.set_jump_held(&"keyboard_mouse", true)
	var trace: Array[Dictionary] = []
	var first_break: Dictionary = {}
	var airborne_before_break := false
	var broke_in_air := false
	for index: int in 420:
		await ticks(1)
		if not live_world():
			check(false, "actual phase3 support transition retains live player and arena")
			return
		var metrics: Dictionary = encounter.combat_metrics()
		var airborne: bool = bool(metrics.get("airborne", false))
		var supported: Rect2 = metrics.get("support_rect", Rect2())
		if not support_arena.broken and airborne: airborne_before_break = true
		if support_arena.broken and airborne: broke_in_air = true
		trace.append({"tick": Engine.get_physics_frames(), "Boss": app.stage.boss.global_position,
			"player": app.player.global_position, "player_HP": app.controller.actor_resources.health.current,
			"mode": String(encounter.mode), "airborne": airborne, "broken": support_arena.broken,
			"support_verified": bool(metrics.get("support_verified", false)), "support_rect": rect_values(supported),
			"bridge_break_ready": bool(encounter.bridge_break_ready())})
		if support_arena.broken:
			first_break = trace.back().duplicate(true)
			break
	app.controller.router.set_jump_held(&"keyboard_mouse", false)
	check(not first_break.is_empty() and airborne_before_break and not broke_in_air,
		"guardian performs real support ascent and settles before the actual bridge breaks")
	check(not first_break.is_empty() and bool(first_break.bridge_break_ready) and bool(first_break.support_verified),
		"actual bridge removal is gated by the landed verified guardian")
	var final_metrics: Dictionary = encounter.combat_metrics()
	var final_rect: Rect2 = final_metrics.get("support_rect", Rect2())
	var old_floor_world: Vector2 = support_arena.module.to_global(floor_rect.position)
	check(final_rect.size.x > 0 and final_rect.position.y < old_floor_world.y - 50,
		"phase3 guardian now rests on an actual raised shelf rather than the removed old floor")
	check(app.player.is_on_floor() and app.controller.actor_resources.health.current == player_hp,
		"ordinary base held jump reaches real support without forced player damage during the break")
	check(app.controller.jump_ability.used_jumps <= 1, "phase transition escape uses no ungranted second jump")
	observations.append({"case": "actual phase3 guardian and player support transition", "Boss_HP_trigger_fixture": true,
		"initial_player": at, "actual_first_break": first_break, "airborne_before_break": airborne_before_break, "trace": trace})
	if first_break.is_empty() or not live_world(): return
	# Explicit recovered-stance fixture AFTER the measured real landing. It
	# does not set Actor position or manufacture a support surface.
	encounter.cancel_pending_attacks()
	encounter._enter(&"recover", 1.0)
	await ticks(9)
	if not live_world():
		check(false, "recovered support sample retains actual world")
		return
	encounter.set_physics_process(false)
	foot_probes("phase3 actual first shelf, explicit ordinary recovered stance")
	phase_support_ready = true

func begin_controlled_group(attack: StringName) -> void:
	# Select a specific group only for this bounded support fixture. Ordinary
	# owner preparation, turn, locked takeoff and Motor movement still execute.
	encounter.cancel_pending_attacks()
	encounter._group_plan = {"attacks": [attack], "phase": 3, "sweep_high": true, "double_stomp": false}
	encounter._attack_index = 0
	encounter._preparation_index = -1
	encounter._preparation_hops = 0
	encounter._guarded_attack_index = -1
	encounter._begin_attack()
	encounter.set_physics_process(true)

func recover_supported_stance(label: String) -> bool:
	if not live_world(): return false
	encounter.cancel_pending_attacks()
	encounter._enter(&"recover", 1.0)
	encounter.set_physics_process(true)
	await ticks(9)
	if not live_world(): return false
	encounter.set_physics_process(false)
	foot_probes(label)
	return true

func locked_traverse_snapshot() -> bool:
	if not phase_support_ready or not live_world(): return false
	var before_metrics: Dictionary = encounter.combat_metrics()
	var old_support: Rect2 = before_metrics.get("support_rect", Rect2())
	var start: Vector2 = app.stage.boss.global_position
	begin_controlled_group(&"sweep") # Its real out-of-range preparation must traverse.
	var warning_target := Vector2.INF
	var target_rect := Rect2()
	var took_off := false
	for index: int in 240:
		await ticks(1)
		if not live_world():
			check(false, "actual support traversal retains live App")
			return false
		var metrics: Dictionary = encounter.combat_metrics()
		if encounter.mode == &"traverse_warning":
			warning_target = metrics.get("locked_hop_target", Vector2.INF)
			target_rect = metrics.get("hop_target_rect", Rect2())
		if bool(metrics.get("airborne", false)):
			took_off = true
			break
	check(took_off and warning_target.is_finite() and target_rect != old_support,
		"actual inter-platform travel begins only after a locked readable traversal warning")
	if not took_off: return false
	var locked: Vector2 = encounter.combat_metrics().locked_hop_target
	check(locked == warning_target, "physical takeoff retains its preannounced landing target")
	app.controller.router.set_source_axis(&"keyboard_mouse", signf(old_support.get_center().x - app.player.global_position.x))
	app.controller.router.set_jump_held(&"keyboard_mouse", true)
	var snapshot_checked := false
	var target_changed := false
	var locks_unchanged := true
	var landed := false
	var escape_shot := false
	var trace: Array[Dictionary] = []
	for index: int in 240:
		await ticks(1)
		if not live_world():
			check(false, "normal retarget adversary retains live App and player")
			return false
		var metrics: Dictionary = encounter.combat_metrics()
		var airborne: bool = bool(metrics.get("airborne", false))
		if airborne:
			locks_unchanged = locks_unchanged and (metrics.get("locked_hop_target", Vector2.INF) as Vector2) == locked
		if not snapshot_checked and airborne and index >= 6:
			var saved: Dictionary = encounter.combat_snapshot()
			var position: Vector2 = app.stage.boss.global_position
			var event_count: int = encounter._event_history.size()
			check(bool(saved.pressure.support_motion.active), "actual midair snapshot records in-progress support movement")
			encounter.restore_combat_state(saved)
			check(app.stage.boss.global_position == position and encounter.combat_metrics().locked_hop_target == locked,
				"same-instance midair restore neither teleports body nor changes locked landing")
			check(encounter._event_history.size() == event_count and encounter._projectiles.is_empty(),
				"midair restore cannot replay takeoff or create old attack projectiles")
			snapshot_checked = true
		if index == 12 and not app.player.is_on_floor():
			escape_shot = app.controller.router.request_action(&"shoot_release", Vector2.DOWN)
			check(escape_shot, "real base airborne shot supplies upward recoil for target-switch jump")
		var at: Vector2 = app.player.global_position
		var axis: float = signf(old_support.get_center().x - at.x) if absf(old_support.get_center().x - at.x) > 18 else 0.0
		app.controller.router.set_source_axis(&"keyboard_mouse", axis)
		var query := PhysicsRayQueryParameters2D.create(at + Vector2(0,18), at + Vector2(0,800), 1, [app.player.get_rid(), app.stage.boss.get_rid()])
		var surface: Dictionary = app.player.get_world_2d().direct_space_state.intersect_ray(query)
		if airborne and not surface.is_empty():
			var point: Vector2 = surface.position
			if point.x >= old_support.position.x and point.x <= old_support.end.x and absf(point.y-old_support.position.y)<2:
				target_changed = true
		trace.append({"tick": Engine.get_physics_frames(), "Boss": app.stage.boss.global_position,
			"player": at, "airborne": airborne, "locked_target": metrics.get("locked_hop_target", Vector2.INF),
			"player_now_above_other_real_support": target_changed, "state": String(encounter.mode)})
		if not airborne:
			landed = true
			encounter.set_physics_process(false)
			break
	app.controller.router.set_jump_held(&"keyboard_mouse", false)
	check(landed and locks_unchanged and target_changed,
		"player reaches a different real platform during flight while Boss retains original locked target")
	check(snapshot_checked and app.stage.boss.global_position.distance_to(locked)<1,
		"restored actual trajectory finishes at its original physical landing point")
	check(app.stage.boss.global_position.distance_to(start)>100,
		"inter-platform movement is actual Actor travel rather than an extended limb or fake floor")
	# Finish the already-issued ordinary player movement on the original shelf.
	var player_landed := false
	for index: int in 180:
		if not live_world(): return false
		var at: Vector2 = app.player.global_position
		app.controller.router.set_source_axis(&"keyboard_mouse", signf(old_support.get_center().x-at.x) if absf(old_support.get_center().x-at.x)>18 else 0.0)
		if app.player.is_on_floor() and absf(at.y+18-old_support.position.y)<2 and at.x>=old_support.position.x+12 and at.x<=old_support.end.x-12:
			player_landed = true
			break
		await ticks(1)
	app.controller.router.set_source_axis(&"keyboard_mouse", 0)
	check(player_landed, "normal held jump and one real recoil shot settle player on the other existing shelf")
	observations.append({"case": "locked actual traversal and snapshot", "specific_group_fixture": "out-of-range sweep preparation",
		"old_support": rect_values(old_support), "warned_target": locked, "target_rect": rect_values(target_rect),
		"player_target_changed_by_normal_input": target_changed, "same_instance_midair_snapshot_fixture": snapshot_checked,
		"actual_upward_recoil_request": escape_shot, "trace": trace})
	if not landed or not player_landed: return false
	return await recover_supported_stance("after actual locked inter-platform traversal")

func airborne_lunge_terminal() -> void:
	if not live_world(): return
	begin_controlled_group(&"lunge")
	var warned := Vector2.INF
	var took_off := false
	for index: int in 180:
		await ticks(1)
		if not live_world():
			check(false, "actual phase3 lunge retains live App")
			return
		var metrics: Dictionary = encounter.combat_metrics()
		if encounter.mode == &"lunge_warning": warned = metrics.get("locked_hop_target", Vector2.INF)
		if bool(metrics.get("airborne",false)):
			took_off = true
			break
	check(took_off and warned.is_finite(), "phase3 attacking lunge locks a real platform before physical takeoff")
	if not took_off: return
	var locked: Vector2 = encounter.combat_metrics().locked_hop_target
	check(locked == warned, "actual attacking lunge uses its warned platform landing")
	var player_hp: float = app.controller.actor_resources.health.current
	var wind_before: Vector2 = app.player._local_velocity
	var event_start: int = encounter._event_history.size()
	var defeats := [0]
	encounter.defeated.connect(func(_owner: BossEncounter) -> void: defeats[0] += 1)
	var request := ActorResourceRequest.new(&"explicit-real-airborne-terminal-fixture", encounter.health.epoch,
		encounter.health.current, encounter.health.get_instance_id())
	check(encounter.health.apply_damage(request).accepted(), "declared fatal fixture uses authoritative Boss health transaction during real flight")
	check(not encounter.active and not encounter.body_contact_enabled() and encounter._projectiles.is_empty(),
		"airborne fatal immediately disables new attacks, physical contact and old projectiles")
	check(app.player._local_velocity.is_zero_approx() and app.player._local_duration<=0,
		"airborne terminal leaves no residual active local wind on actual player")
	var delayed_clock := true
	var landed := false
	var trace: Array[Dictionary] = []
	for index: int in 360:
		await ticks(1)
		if not live_world():
			check(false, "terminal flight and collapse preserve actual App until settlement")
			return
		var metrics: Dictionary = encounter.combat_metrics()
		var airborne: bool = bool(metrics.get("airborne",false))
		if airborne and float(metrics.death_age)>0: delayed_clock=false
		if not airborne: landed=true
		trace.append({"tick":Engine.get_physics_frames(),"Boss":app.stage.boss.global_position,
			"airborne":airborne,"death_age":metrics.death_age,"player_HP":app.controller.actor_resources.health.current,"paused":paused})
		if bool(encounter._death_final_sent): break
	check(delayed_clock and landed and app.stage.boss.global_position.distance_to(locked)<1,
		"fatal body completes actual locked landing before advancing mechanical collapse clock")
	var events: Array = encounter._event_history.slice(event_start)
	var impacts := events.filter(func(row:Dictionary)->bool:return row.event==&"windkeeper_death_impact")
	var finals := events.filter(func(row:Dictionary)->bool:return row.event==&"windkeeper_death_final")
	check(defeats[0]==1 and impacts.size()==1 and finals.size()==1,
		"airborne fatal produces one defeat, one post-landing impact and one final settlement")
	check(app.controller.actor_resources.health.current==player_hp,
		"harmless descending corpse and its collapse cannot damage actual nearby player")
	check(not encounter.body_contact_enabled() and app.stage.boss.collision_layer==0 and app.stage.boss.collision_mask==0,
		"actual settled corpse stays harmless and nonblocking")
	observations.append({"case":"actual airborne lunge terminal","fatal_Boss_resource_fixture":true,
		"locked_landing":locked,"wind_before_fatal":wind_before,"active_wind_before_fatal":not wind_before.is_zero_approx(),
		"defeats":defeats[0],"impacts":impacts.size(),"finals":finals.size(),"trace":trace})

func central_moving_escape() -> void:
	if not await setup(): return
	var arena_consumer: WindkeeperArena
	for child: Node in encounter.get_children():
		if child is WindkeeperArena: arena_consumer=child as WindkeeperArena
	check(arena_consumer!=null,"central escape uses actual bridge consumer")
	if arena_consumer==null:return
	var central: Rect2 = arena_consumer.module.definition.platforms[2]
	var neighbour: Rect2 = arena_consumer.module.definition.platforms[3]
	var ground: Rect2 = arena_consumer.module.definition.platforms[0]
	var initial: Vector2 = arena_consumer.module.to_global(Vector2(central.end.x-18,ground.position.y-18))
	var destination: Vector2 = arena_consumer.module.to_global(Vector2(neighbour.get_center().x,neighbour.position.y-18))
	relocate(initial,"original central-ground counterexample position; normal rightward jump escape")
	await ticks(3)
	var hp: float = app.controller.actor_resources.health.current
	var target_hp: float = encounter.health.capacity*encounter._config().phase_three_health-1
	var request := ActorResourceRequest.new(&"explicit-central-moving-phase3-fixture",encounter.health.epoch,
		encounter.health.current-target_hp,encounter.health.get_instance_id())
	check(encounter.health.apply_damage(request).accepted(),"central moving escape uses the declared Boss phase trigger only")
	encounter.set_physics_process(true)
	app.controller.router.set_source_axis(&"keyboard_mouse",1)
	app.controller.router.set_jump_held(&"keyboard_mouse",true)
	var reached := false
	var max_jumps := 0
	var trace: Array[Dictionary] = []
	for index:int in 420:
		await ticks(1)
		if not live_world():
			check(false,"normal central escape retains live player and actual arena")
			return
		var at:Vector2=app.player.global_position
		app.controller.router.set_source_axis(&"keyboard_mouse",1 if at.x<destination.x-18 else 0)
		max_jumps=maxi(max_jumps,app.controller.jump_ability.used_jumps)
		var feet:Vector2=arena_consumer.module.to_local(at)+Vector2(0,18)
		var on_neighbour:bool=app.player.is_on_floor() and absf(feet.y-neighbour.position.y)<2 and feet.x-12>=neighbour.position.x and feet.x+12<=neighbour.end.x
		trace.append({"tick":Engine.get_physics_frames(),"player":at,"Boss":app.stage.boss.global_position,
			"HP":app.controller.actor_resources.health.current,"grounded":app.player.is_on_floor(),"broken":arena_consumer.broken,"on_neighbour":on_neighbour})
		if arena_consumer.broken and on_neighbour:
			reached=true
			break
	app.controller.router.set_jump_held(&"keyboard_mouse",false)
	app.controller.router.set_source_axis(&"keyboard_mouse",0)
	check(reached and arena_consumer.broken,"original central start has a real rightward base-jump route to the neighbouring surviving platform")
	check(max_jumps<=1,"central moving escape requires no ungranted second jump")
	check(app.controller.actor_resources.health.current==hp,"central moving escape preserves actual player HP")
	var env_hits:=player_damage.filter(func(row:Dictionary)->bool:return float(row.HP_lost)>0 and (str(row.source).contains("fall") or str(row.source).contains("bounds")))
	check(env_hits.is_empty(),"central moving escape incurs no environment debit or forced return")
	observations.append({"case":"original central start, normal horizontal escape","initial":initial,"destination":destination,
		"prior_vertical_only_failure_preserved":"build/windkeeper_pressure_01/support-formal-fixture-02.json",
		"route":"normal rightward Router axis plus one held base jump; no position/resource/physics injection after initial placement",
		"reached":reached,"trace":trace,"player_damage":player_damage.duplicate(true)})

func run() -> void:
	await phase3_support()
	if phase_support_ready:
		var traversed := await locked_traverse_snapshot()
		if traversed: await airborne_lunge_terminal()
	await central_moving_escape()
	await cleanup()
	DirAccess.make_dir_recursive_absolute("res://build/windkeeper_pressure_01")
	var file := FileAccess.open("res://build/windkeeper_pressure_01/support_app.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"assertions": assertions, "failures": failures, "observations": observations,
		"coverage_pending": [],
		"scope": "real formal App phase3 support ascent/actual bridge release/four ordinary stance rays/locked platform traversal and lunge/midair snapshot and terminal landing/original-central normal rightward-jump escape; initial positions, Boss phase/fatal transactions and selected group/recovery/snapshot fixtures explicit; no player or terrain injection, not natural fullfight or visual approval"}, "\t"))
	file.close()
	print("WINDKEEPER PRESSURE SUPPORT APP: ", assertions, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
