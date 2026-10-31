extends SceneTree
## Native local fixtures. Combat assertions use InputRouter -> accepted projectile
## -> Damageable -> FrameDamagePolicy; phase setup is labelled as a fixture.
var assertions := 0
var failures := 0
var world: Node2D
var player: PlayerMotor
var controller: PlayerController
var policy: FrameDamagePolicy
var life: DemoLifetime
var evidence: Array[Dictionary] = []
var trace: Array[Dictionary] = []
var tick := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions += 1
	print("FOREST ECOLOGY CHECK: ", "PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func slab(rect: Rect2, one_way := false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.one_way_collision = one_way
	body.add_child(shape)
	if one_way: body.add_to_group(&"one_way_platform")
	world.add_child(body)
	return body
func fixture(upper_branch := false) -> void:
	if is_instance_valid(world): world.free()
	world = Node2D.new()
	root.add_child(world)
	slab(Rect2(-400,300,1600,40))
	if upper_branch: slab(Rect2(100,210,180,12),true)
	player = preload("res://game/player/player.tscn").instantiate()
	player.position = Vector2(180,192) if upper_branch else Vector2(180,282)
	world.add_child(player)
	controller = player.get_node("Controller")
	controller.enable_shot_energy()
	life = DemoLifetime.new()
	policy = FrameDamagePolicy.new()
	policy.lifetime = life
	world.add_child(policy)
	policy.register_target(&"player",controller.actor_resources.health,true)
	policy.batch_resolved.connect(func(results: Array[DamageResult]) -> void:
		for result: DamageResult in results:
			trace.append({"kind":"damage","tick":tick,"target":String(result.request.target_id),"event_id":String(result.request.event_id),"hp":result.health.current})
	)
	controller.shoot_ability.shot_fired.connect(func(aim: Vector2, id: int) -> void: trace.append({"kind":"accepted_shot","tick":tick,"id":id,"aim":[aim.x,aim.y]}))
	await frames(4)
func frames(count: int) -> void:
	for i: int in count:
		await physics_frame
		await process_frame
		tick += 1
func enemy(name_id: String, position_value: Vector2) -> EnemyActor:
	var scene := load("res://scenes/enemies/%s.tscn" % name_id) as PackedScene
	var body := scene.instantiate() as EnemyMotor
	body.position = position_value
	world.add_child(body)
	var result := body.get_node("Actor") as EnemyActor
	policy.bind_damageable(&"forest_enemy",result.damageable,result.health)
	result.bind_encounter(controller,policy,life,&"forest_enemy",[])
	return result
func boss(name_id: String) -> ThornForestEncounter:
	var body := (load("res://scenes/bosses/%s.tscn" % name_id) as PackedScene).instantiate() as BossMotor
	body.position = Vector2(460,252)
	world.add_child(body)
	var result := body.get_node("Encounter") as ThornForestEncounter
	policy.bind_damageable(&"forest_boss",result.damageable,result.health)
	result.projectile_created.connect(func(shot: BossProjectile) -> void:
		shot.hit.connect(func(_body: Node2D, id: StringName, amount: float) -> void:
			var request := DamageRequest.new()
			request.token = life.token()
			request.event_id = id
			request.source_id = &"forest_boss"
			request.target_id = &"player"
			request.amount = amount
			request.actor_epoch = life.actor_epoch
			request.health_epoch = controller.actor_resources.health.epoch
			policy.submit(request)
		)
	)
	result.configure_arena(-200,1000,player)
	result.activate()
	result.skip_intro()
	return result
func wait_state(behavior: EnemyAttackBehavior, wanted: StringName, limit := 250) -> bool:
	for i: int in limit:
		if behavior.state == wanted: return true
		await frames(1)
	return false
func shoot_at(point: Vector2) -> void:
	controller.router.request_action(&"shoot_release",(point-player.global_position).normalized())
	await frames(30)
func run() -> void:
	await fixture()
	var lantern := enemy("forest_lantern",Vector2(320,220))
	check(lantern.definition.is_valid(),"live-anchor Definition valid")
	check(lantern.attack_behavior is ForestLanternBehavior and lantern.motor.is_in_group(&"grapple_target"),"real actor/motor registered as moving grapple target")
	var home := lantern.motor.global_position
	await frames(190)
	check(lantern.motor.global_position.distance_to(home)>10 and absf(lantern.motor.global_position.x-home.x)<=lantern.definition.patrol_half_width+1,"dwell/turn/travel creates bounded real motion")
	var before := lantern.motor.global_position
	paused = true
	for i: int in 5: await process_frame
	check(lantern.motor.global_position==before,"pause freezes moving live anchor")
	paused = false
	controller.active=false
	await frames(40)
	check(lantern.motor.global_position==before,"inactive target stops live-anchor movement")
	evidence.append({"case":"lantern_motion_pause_inactive","tick":tick})
	await fixture()
	lantern = enemy("forest_lantern",Vector2(320,220))
	controller.traversal.grant(&"grapple")
	controller.router.request_action(&"grapple",(lantern.motor.global_position-player.global_position).normalized())
	var saw_pull := false
	var saw_contact := false
	var saw_kick := false
	for i: int in 80:
		await frames(1)
		saw_pull = saw_pull or controller.traversal.state == &"hook_pull"
		saw_contact = saw_contact or controller.traversal.state == &"hook_contact_kick"
		saw_kick = saw_kick or controller.traversal.state == &"hook_kick"
	check(saw_pull and saw_contact and saw_kick,"real H catches live forest lantern, contacts and performs incoming-side kick")
	check(lantern.health.current==lantern.health.capacity-controller.traversal.definition.hook_damage,"live forest anchor receives exactly the accepted grapple damage")
	await frames(70)
	check(player.is_on_floor() and controller.actor_resources.health.current==controller.actor_resources.health.capacity,"live-anchor traversal has intact permanent floor recovery")
	evidence.append({"case":"actual_lantern_H_contact_kick_recovery","tick":tick})
	await fixture()
	var sentry := enemy("forest_seed_sentry",Vector2(360,282))
	var behavior := sentry.attack_behavior as ForestSeedSentryBehavior
	check(sentry.definition.is_valid() and behavior!=null,"branch sentry Definition/behavior valid")
	check(await wait_state(behavior,&"telegraph"),"grounded target locks a real support surface")
	var mark := behavior.attack_goal
	var initial_health := controller.actor_resources.health.current
	await frames(125)
	check(controller.actor_resources.health.current==initial_health-1,"ballistic seed reaches old branch and real policy commits one hit")
	check(behavior.attack_goal==mark,"seed never tracks target after warning")
	evidence.append({"case":"standing_branch_seed_actual_damage","tick":tick})
	await fixture()
	sentry = enemy("forest_seed_sentry",Vector2(360,282))
	behavior = sentry.attack_behavior as ForestSeedSentryBehavior
	check(await wait_state(behavior,&"telegraph"),"escape case warning visible")
	mark = behavior.attack_goal
	controller.router.set_move_axis(-1)
	await frames(40)
	controller.router.set_move_axis(0)
	await frames(70)
	check(controller.actor_resources.health.current==controller.actor_resources.health.capacity and behavior.attack_goal==mark,"real walk away from fixed old branch avoids damage, no kill or resource grant")
	evidence.append({"case":"old_branch_nonkill_escape","tick":tick})
	await fixture()
	sentry = enemy("forest_seed_sentry",Vector2(360,282))
	behavior = sentry.attack_behavior as ForestSeedSentryBehavior
	check(await wait_state(behavior,&"attack"),"cancellation fixture has actual seed in flight")
	check(behavior._projectiles.size()==1,"one bounded real seed instance")
	var old_seed := behavior._projectiles[0]
	life.invalidate_actor()
	await frames(2)
	check(not is_instance_valid(old_seed) or old_seed.spent,"actor epoch cancels flight, never recreates old patch")
	await frames(90)
	check(controller.actor_resources.health.current==controller.actor_resources.health.capacity,"cancelled old seed leaves no late damage")
	await fixture()
	sentry = enemy("forest_seed_sentry",Vector2(360,282))
	behavior = sentry.attack_behavior as ForestSeedSentryBehavior
	check(await wait_state(behavior,&"telegraph"),"real projectile fixture warning starts")
	await shoot_at(sentry.motor.global_position)
	check(sentry.health.current==2,"actual accepted bullet reaches sentry through Damageable and FrameDamagePolicy")
	await frames(35)
	await shoot_at(sentry.motor.global_position)
	await frames(35)
	await shoot_at(sentry.motor.global_position)
	check(sentry.health.terminal and sentry.motor.collision_layer==0,"three real accepted bullets defeat sentry and remove grapple collision")
	check(behavior._projectiles.is_empty(),"real defeat cancels all owned seeds")
	evidence.append({"case":"real_three_bullet_sentry_defeat","tick":tick})
	await fixture()
	sentry = enemy("forest_seed_sentry",Vector2(360,282))
	behavior = sentry.attack_behavior as ForestSeedSentryBehavior
	slab(Rect2(260,100,24,200))
	await frames(150)
	check(behavior._serial==0,"solid tree occludes sensing and stops unseen seed attack")
	await fixture(true)
	sentry=enemy("forest_seed_sentry",Vector2(360,170))
	behavior=sentry.attack_behavior as ForestSeedSentryBehavior
	check(await wait_state(behavior,&"telegraph"),"higher one-way branch can be acquired as a real supported mark")
	check(absf(behavior.attack_goal.y-210)<1,"mark is actual high branch top, never enemy home or lower floor")
	await fixture()
	sentry=enemy("forest_seed_sentry",Vector2(360,282))
	behavior=sentry.attack_behavior as ForestSeedSentryBehavior
	behavior.cooldown=0.7
	controller.router.set_jump_held(&"forest_air_negative",true)
	controller.router.request_action(&"jump")
	await frames(8)
	behavior.cooldown=0
	check(not player.is_on_floor(),"unsupported-air negative uses an actual accepted jump")
	await frames(6)
	check(behavior.state==&"idle" and behavior._serial==0,"no supported branch under airborne target means no fabricated mark")
	controller.router.set_jump_held(&"forest_air_negative",false)
	for boss_id: String in ["thorn_guardian","thorn_queen"]:
		await fixture()
		var encounter := boss(boss_id)
		check(encounter.definition.is_valid(),boss_id+" self-contained forest Definition valid")
		check(encounter.get_script().resource_path=="res://game/bosses/thorn_forest/thorn_forest_encounter.gd",boss_id+" is independent forest encounter")
		var loops := 0
		while not encounter.core_open and loops<300:
			await frames(1)
			loops+=1
		check(encounter.core_open,boss_id+" has bounded warning/seed/patch/open learning cycle")
		var boss_health := encounter.health.current
		await shoot_at(encounter.motor.global_position)
		check(encounter.health.current==boss_health-1,boss_id+" real accepted bullet damages open heart")
		encounter.cancel_pending_attacks()
		boss_health=encounter.health.current
		await shoot_at(encounter.motor.global_position)
		check(encounter.health.current==boss_health,boss_id+" armour rejects actual bullet outside open window")
		# State/phase fixture only: no claim that this is real combat progression.
		encounter.stage_phase=2
		encounter.weak_side=-1
		encounter.core_open=true
		check(encounter.accepts_core_direction({"hit_direction":Vector2.RIGHT}) and not encounter.accepts_core_direction({"hit_direction":Vector2.LEFT}),boss_id+" phase 2 actual damage receiver accepts lit-side direction only")
		var snapshot := encounter.combat_snapshot()
		encounter.restore_combat_state(snapshot)
		check(not encounter.core_open and encounter.mode==&"observe" and encounter._projectiles.is_empty(),boss_id+" restored actor cancels stale attack with recovery")
		controller.active=false
		await frames(80)
		check(encounter._projectiles.is_empty() and not encounter.core_open,boss_id+" inactive target cancels pending attack and cannot restart")
		controller.active=true
		encounter.cancel()
		await frames(80)
		check(not encounter.active and encounter._projectiles.is_empty(),boss_id+" stage cancel leaves no late projectiles")
		evidence.append({"case":boss_id+"_real_hit_armour_phase_fixture_cancel","tick":tick})
	# Whole local health fight: no HP/phase changes, no PlayerMotor relocation,
	# no resource injection. The fixture has an open lower floor and no
	# formal arena seal/camera/branch obstruction, so it cannot sign those.
	for boss_id: String in ["thorn_guardian","thorn_queen"]:
		await fixture()
		var encounter := boss(boss_id)
		var shots_at_start := trace.filter(func(e: Dictionary) -> bool: return e.kind=="accepted_shot").size()
		var defeated_count := [0]
		encounter.defeated.connect(func(_value: BossEncounter) -> void: defeated_count[0]+=1)
		var next_shot := 0
		var last_mode: StringName = &""
		var destination := 180.0
		var phases_seen: Dictionary = {}
		for i: int in 9000:
			if encounter.health.terminal or controller.actor_resources.health.terminal: break
			phases_seen[encounter.stage_phase]=true
			if encounter.mode != last_mode:
				last_mode=encounter.mode
				if encounter.mode==&"branch_warning":
					destination=200.0 if player.global_position.x>460 else 690.0
				elif encounter.core_open:
					destination=230.0 if encounter.stage_phase==1 or encounter.weak_side<0 else 690.0
			var offset := destination-player.global_position.x
			controller.router.set_move_axis(0 if absf(offset)<12 else 1 if offset>0 else -1)
			if encounter.core_open and i>=next_shot and (encounter.stage_phase==1 or (player.global_position.x-460)*encounter.weak_side>60):
				controller.router.request_action(&"shoot_release",(encounter.motor.global_position-player.global_position).normalized())
				next_shot=i+30
			await frames(1)
		controller.router.set_move_axis(0)
		check(encounter.health.terminal and defeated_count[0]==1,boss_id+" continuous actual bullets complete whole local fight and emit defeat once")
		check(phases_seen.has(2) and (boss_id!="thorn_queen" or phases_seen.has(3)),boss_id+" continuous combat visits all distinct phases without HP injection")
		check(not controller.actor_resources.health.terminal,boss_id+" actual movement escapes old patches and survives")
		var actual_shots := trace.filter(func(e: Dictionary) -> bool: return e.kind=="accepted_shot").size()-shots_at_start
		evidence.append({"case":boss_id+"_continuous_local_bullet_fight","tick":tick,"defeated":encounter.health.terminal,"player_hp":controller.actor_resources.health.current,"accepted_shots":actual_shots,"phases":phases_seen.keys(),"scope":"local lower-floor arena; formal H branches/seal/camera not claimed"})
	world.free()
	await frames(3)
	var output_dir := "res://build/forest_playable/ecology/native"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output_dir=argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir+"/capture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"native local actors, actual InputRouter bullets and policy; no complete formal routes/real Boss defeat claimed","assertions":assertions,"failures":failures,"cases":evidence,"trace":trace},"  "))
	file.close()
	print("FOREST ECOLOGY: %s assertions, %s failures" % [assertions,failures])
	quit(0 if failures==0 else 1)
