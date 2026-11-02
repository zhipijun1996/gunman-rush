extends SceneTree
const BELL_PLATFORM := preload("res://tests/underworld_plains/bell_platform_fixture.gd")
const BELL_PILOT := preload("res://tools/bellstrider_01/legal_input_pilot.gd")
## R3 formal Boss contracts. Phase/state entry is an explicit fixture; every
## tested damage amount below comes from a real Router -> ShootAbility sweep.
var checks := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var world: Node2D
var player: PlayerMotor
var controller: PlayerController
var boss: BossMotor
var encounter: WindkeeperEncounter
var policy: FrameDamagePolicy
var lifetime: DemoLifetime
var contact: DemoContactEmitter
var defeats := 0
var emissions := 0
var trace_roll := false
var roll_frames:Array[Dictionary]=[]
var fixture_damage_events: Array[Dictionary] = []
var flat_roll_trials: Array[Dictionary] = []
var platform_positive: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);printerr("FAIL: ",label)
func frames(n: int) -> void:
	for i: int in n:
		await physics_frame
		if trace_roll:
			roll_frames.append({"tick":Engine.get_physics_frames(),"player":[player.global_position.x,player.global_position.y],"boss":[boss.global_position.x,boss.global_position.y],"mode":String(encounter.mode),"clock":encounter.clock,"hp":controller.actor_resources.health.current,"vy":player.normal_velocity.y,"jump":controller.jump_ability.used_jumps,"contact":str(encounter.body_contact_rect())})
func clear_fixture() -> void:
	if is_instance_valid(world):
		encounter.cancel()
		check(await load("res://tests/audio_teardown.gd").drain_world(world),"fixture audio drains")
		world.free()
		await frames(2)
func fixture(mini: bool, phase: int = 1, at := Vector2(350,582)) -> void:
	await clear_fixture()
	fixture_damage_events.clear()
	world=Node2D.new();world.set_meta("underworld_formal_style",true);root.add_child(world)
	var ground:=StaticBody2D.new();ground.position=Vector2(600,650)
	var ground_shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=Vector2(20000,100);ground_shape.shape=rect;ground.add_child(ground_shape);world.add_child(ground)
	player=preload("res://game/player/player.tscn").instantiate();player.position=at;world.add_child(player)
	controller=player.get_node("Controller")
	lifetime=DemoLifetime.new();policy=FrameDamagePolicy.new();policy.lifetime=lifetime;world.add_child(policy)
	policy.register_target(&"player",controller.actor_resources.health,true)
	policy.register_player_controller(controller)
	policy.batch_resolved.connect(func(results: Array[DamageResult]) -> void:
		for result: DamageResult in results:
			fixture_damage_events.append({"tick": Engine.get_physics_frames(), "target": String(result.request.target_id), "source": String(result.request.source_id), "event": String(result.request.event_id), "amount": result.request.amount, "health": result.health.current}))
	boss=load("res://scenes/bosses/bellstrider.tscn" if mini else "res://scenes/bosses/windkeeper.tscn").instantiate()
	encounter=boss.get_node("Encounter")
	# This direct old-scene fixture retains exact historical v5 timings/36HP;
	# the current factory/App six-move60HP path is covered by pressure tests.
	var definition:WindkeeperDefinition=load("res://resources/bosses/bellstrider.tres" if mini else "res://resources/bosses/legacy/windkeeper_storm_continuous_v5.tres").duplicate(true)
	# Initial-current phase fixtures never submit fake combat damage.
	definition.health_definition.initial_current=(definition.health_definition.max_health if phase==1 else definition.health_definition.max_health*definition.phase_two_health) if mini else (36.0 if phase==1 else 23.0 if phase==2 else 11.0)
	encounter.definition=definition;boss.position=Vector2(650,535);world.add_child(boss)
	encounter.configure_arena(100,1100,player);encounter.set_physics_process(false)
	policy.bind_damageable(&"boss",boss.get_node("Damageable"),encounter.health)
	contact=DemoContactEmitter.new();contact.policy=policy;contact.controller=controller;contact.source_id=&"r3_actual_boss_body";contact.contact_rect_provider=encounter.body_contact_rect;contact.enabled=false;boss.add_child(contact)
	# Match the formal App: bounds alone include empty space around the real rig.
	if encounter is BellstriderEncounter: contact.contact_test_provider=encounter.body_contact_sweep
	defeats=0;emissions=0
	encounter.defeated.connect(func(_e:BossEncounter)->void:defeats+=1)
	encounter.projectile_created.connect(func(shot:BossProjectile)->void:
		emissions+=1
		shot.hit.connect(func(body:Node2D,id:StringName,amount:float)->void:
			if body!=player:return
			var request:=DamageRequest.new();request.token=lifetime.token();request.actor_epoch=lifetime.actor_epoch;request.health_epoch=controller.actor_resources.health.epoch;request.target_id=&"player";request.source_id=&"r3_actual_boss_projectile";request.event_id=id;request.amount=amount;request.hit_direction=shot.direction;policy.submit(request)))
	await frames(4)
	check(encounter.activate(),"actual formal encounter activates")
	encounter.stage_phase=phase;encounter._enter(&"observe",30);encounter.physics_tick(.001)
	await frames(2)

func position_bell_shooter(side: int = -1) -> void:
	# Real locomotion restores an aiming position after recoil; no player reset
	# or HP/resource injection is used to manufacture the forty-hit death case.
	var destination := boss.global_position.x + side*260.0
	for tick: int in 300:
		if absf(player.global_position.x-destination) <= 8.0: break
		controller.router.set_move_axis(clampf((destination-player.global_position.x)/30.0,-1,1))
		await frames(1)
	controller.router.set_move_axis(0)
	await frames(4)
	check(absf(player.global_position.x-destination) <= 14.0,"actual Router locomotion reaches a legal bell shooting position")

func shoot_at(point:Vector2,label:String,expected:float=1) -> void:
	var before:=encounter.health.current
	controller.router.request_action(&"shoot_release",(point-player.global_position).normalized())
	await frames(maxi(24,ceili((point-player.global_position).length()/controller.motor.tuning.projectile_speed*60)+12))
	check(is_equal_approx(encounter.health.current,before-expected),label)
	observations.append({"label":label,"phase":encounter.stage_phase,"mode":String(encounter.mode),"before":before,"after":encounter.health.current,"expected":expected,"player_hp":controller.actor_resources.health.current,"tick":Engine.get_physics_frames(),"shape":str(encounter.body_contact_rect())})

func run() -> void:
	var tuning_hash:=FileAccess.get_sha256("res://config/player_tuning.json")
	if "--roll-only" in OS.get_cmdline_user_args():
		await roll_trials()
		await finish()
		return
	for mini:bool in [true,false]:
		for phase:int in ([1,2] if mini else [1,2,3]):
			await fixture(mini,phase)
			check(encounter.continuous_combat(),"formal Definition explicitly enables continuous combat")
			check(boss.collision_mask==0,"Boss body is a damage/hit volume, not an impassable wall")
			if mini:
				check(encounter.definition is BellstriderDefinition and encounter.health.capacity==40,"formal Bell uses actual forty-HP declarative definition")
				check(encounter.health.current==(40.0 if phase==1 else 20.0),"explicit phase fixture starts at full forty or half twenty HP")
			var states:Array=[&"observe",&"approach",&"roll_warning",&"roll",&"combo_brake",&"combo_turn",&"combo_warning",&"ring_warning",&"rings",&"lob_aim",&"lob_lock",&"lob",&"neck",&"phase_transition"] if mini else ([&"observe",&"stomp_warning",&"charge",&"neck"] if phase==1 else [&"blade_warning",&"blades",&"back",&"phase_transition"] if phase==2 else [&"chase",&"pier_warning",&"pier_impact",&"pier_open"])
			var index := 0
			for state:StringName in states:
				encounter._enter(state,30);encounter._update_combat_shapes();await frames(2)
				if mini:
					await position_bell_shooter(-1 if index%2==0 else 1)
					await shoot_at(boss.to_global(encounter.core_offset()),"mini phase %d %s actual upper bell accepts one shot"%[phase,state])
					var armour_events := [0]
					var observe_armour := func(_point: Vector2) -> void: armour_events[0] += 1
					encounter.armour_hit.connect(observe_armour)
					await shoot_at(boss.to_global(encounter.definition.collision_offset),"mini phase %d %s actual chassis rejects damage"%[phase,state],0)
					encounter.armour_hit.disconnect(observe_armour)
					check(armour_events[0]==1,"real chassis shot produces exactly one armour response")
				else:
					await shoot_at(boss.global_position+Vector2(0,-15),"main phase %d %s body accepts actual shot"%[phase,state])
				index += 1
			check(encounter.accepts_core_direction({"hit_direction":Vector2.LEFT,"fired_airborne":false}),"continuous combat never locks direction or rune qualification")
			var snapshot:=encounter.combat_snapshot();var hp:=encounter.health.current
			encounter.restore_combat_state(JSON.parse_string(JSON.stringify(snapshot)))
			check(encounter.health.current==hp and encounter.mode==StringName(snapshot.mode) and boss.collision_layer==4,"JSON reload retains phase/mode/HP and actual physical shot blocker")
			paused=true;var clock:=encounter.clock;var pos:=boss.global_position
			await create_timer(.08,true).timeout
			check(encounter.clock==clock and boss.global_position==pos,"paused encounter does not advance or move")
			paused=false
			encounter._enter(&"intro",10);encounter._update_combat_shapes();await frames(2)
			await shoot_at(boss.global_position,"intro rejects real swept shot",0)
			encounter.cancel();await shoot_at(boss.global_position,"inactive encounter rejects real swept shot",0)
	await roll_trials()
	# Actual Motor approach: the first four input ticks stay just outside the
	# defined chassis; subsequent accepted motion crosses the real side edge.
	await fixture(true,1,Vector2(550,582))
	contact.enabled=true
	var edge_hp:=controller.actor_resources.health.current
	for i:int in 4:
		controller.router.set_move_axis(1);await frames(1)
	check(controller.actor_resources.health.current==edge_hp,"real movement just outside contact edge does not hurt")
	for i:int in 3:
		controller.router.set_move_axis(1);await frames(1)
	check(controller.actor_resources.health.current<edge_hp,"real Motor crossing actual side edge accepts contact damage")
	controller.router.set_move_axis(0)
	# Actual upper-bell projectiles kill the full forty-HP fixture once. The
	# low armour has its own negative shots; this is not the old body/core overlap.
	await fixture(true)
	encounter._enter(&"neck",30);encounter._update_combat_shapes();await frames(2)
	await position_bell_shooter()
	await shoot_at(boss.to_global(encounter.core_offset()),"actual upper bell consumes one shot and only one HP")
	for i:int in 39:
		await position_bell_shooter()
		if i%8==0:
			await shoot_at(boss.to_global(encounter.definition.collision_offset),"interleaved physical armour never reduces the forty-HP target",0)
		await shoot_at(boss.to_global(encounter.core_offset()),"real projectile lethal chain %d"%i)
	check((encounter as BellstriderEncounter).combat_metrics().accepted_hits==40,"full forty HP requires forty actual base-one HP-changing hits")
	check(encounter.health.terminal and defeats==1 and not encounter.active and boss.collision_layer==0,"real projectile terminal emits one defeat and disables body")
	check(encounter._projectiles.is_empty(),"terminal encounter cancels all owned projectiles")
	await shoot_at(boss.global_position,"dead body rejects later real projectile",0)
	check(defeats==1,"late real projectile cannot emit duplicate defeat")
	check(tuning_hash==FileAccess.get_sha256("res://config/player_tuning.json"),"player physics source unchanged")
	await finish()

func roll_trials()->void:
	# Preserve both original flat-floor actions. PR122 upper-bell contact makes
	# the original late jump a real negative; the no-hurt positive follows below.
	for jump:bool in [false,true]:
		await fixture(true,1,Vector2(430,582))
		trace_roll=true
		contact.enabled=true;encounter.direction=-1;encounter._enter(&"roll_warning",.85);encounter.set_physics_process(true)
		if jump:
			await frames(68)
			controller.router.set_jump_held(&"r3_roll_jump",true)
			controller.router.set_move_axis(1)
		var before:=controller.actor_resources.health.current
		var observed_from := Engine.get_physics_frames()
		if jump:
			for n:int in 78:
				controller.router.set_move_axis(1)
				await frames(1)
		else: await frames(150)
		check(controller.actor_resources.health.current<before,"original late flat-floor held jump meets current upper-bell contact" if jump else "standing in real roll lane takes contact damage")
		if jump:
			check(fixture_damage_events.any(func(row: Dictionary) -> bool: return row.target == "player" and row.source == "r3_actual_boss_body" and int(row.tick) >= observed_from and float(row.amount) > 0.0), "late-jump negative observes a real player policy settlement")
		check(encounter.mode in [&"neck",&"observe",&"ring_warning"],"roll has bounded travel then recovery")
		flat_roll_trials.append({"trial": "late_jump" if jump else "standing", "first_tick": observed_from, "last_tick": Engine.get_physics_frames(), "player_hp_before": before, "player_hp_after": controller.actor_resources.health.current, "actual_policy_events": fixture_damage_events.duplicate(true)})
		controller.router.set_jump_held(&"r3_roll_jump",false)
		trace_roll=false
	await platform_roll_positive()

func finish()->void:
	await clear_fixture()
	DirAccess.make_dir_recursive_absolute("res://build/underworld_r3/boss")
	var f:=FileAccess.open("res://build/underworld_r3/boss/continuous_combat.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations,"roll_frames":roll_frames,"flat_roll_trials":flat_roll_trials,"platform_positive":platform_positive,"scope":"actual formal resources and real Router/ShootAbility/body/core physics; state entries explicit fixtures; not complete user normal battle acceptance"},"\t"));f.close()
	print("UNDERWORLD R3 BOSS: %d checks, %d failures"%[checks,failures.size()]);quit(1 if not failures.is_empty() else 0)

func platform_roll_positive() -> void:
	await clear_fixture()
	var actual_app: DemoApp = await BELL_PLATFORM.create_formal_app(self)
	var actual_stage: PlainsRegionStage = actual_app.stage as PlainsRegionStage if is_instance_valid(actual_app) else null
	var actual_boss: BossMotor = actual_stage.boss as BossMotor if is_instance_valid(actual_stage) else null
	var actual_encounter: BellstriderEncounter = actual_boss.get_node_or_null("Encounter") as BellstriderEncounter if is_instance_valid(actual_boss) else null
	var actual_controller: PlayerController = actual_app.controller if is_instance_valid(actual_app) else null
	var actual_player: PlayerMotor = actual_app.player as PlayerMotor if is_instance_valid(actual_app) else null
	var observer: RefCounted = BELL_PLATFORM.new()
	observer.platform_scope = "first"
	var pilot: RefCounted = BELL_PILOT.new()
	pilot.mode = "cautious2"
	pilot.platform_scope = "first"
	var actual_boss_health: HealthState
	var actual_player_health: HealthState
	var actual_events: Array[Dictionary] = []
	var health_events: Array[Dictionary] = []
	var lifecycle_events: Array[Dictionary] = []
	var actual_trace: Array[Dictionary] = []
	var validator_failures: Array[String] = []
	var initial_hp := -1.0
	var end_reason := "entry_unavailable"
	var live: Callable = func() -> bool:
		return is_instance_valid(actual_app) and is_instance_valid(actual_stage) and is_instance_valid(actual_boss) and is_instance_valid(actual_encounter) and is_instance_valid(actual_controller) and is_instance_valid(actual_player) and not actual_stage.is_queued_for_deletion() and not actual_boss.is_queued_for_deletion() and actual_app.stage == actual_stage and actual_app.controller == actual_controller and actual_app.player == actual_player and actual_app.lifetime != null and actual_app.lifetime.active and actual_app.director != null and actual_app.director.state == DemoRunDirector.State.IN_STAGE
	var entry_live: bool = live.call()
	check(entry_live, "current roll positive creates the actual formal App world")
	if entry_live:
		actual_boss_health = actual_encounter.health
		actual_player_health = actual_controller.actor_resources.health
		initial_hp = actual_player_health.current
		observer.battle_boss_health = actual_boss_health
		# Connect real owners before the shared one-time entry placement. Signal
		# observers store only values; no replacement damage or lifecycle pipeline.
		actual_encounter.presentation_event.connect(observer.observe_bell_event)
		actual_encounter.damageable.damaged.connect(observer.observe_boss_damage)
		actual_controller.shoot_ability.shot_fired.connect(func(_aim: Vector2, id: int) -> void:
			observer.observe_actual_shot(id, actual_encounter, actual_controller))
		actual_app.policy.batch_resolved.connect(func(results: Array[DamageResult]) -> void:
			for result: DamageResult in results:
				actual_events.append({"tick": Engine.get_physics_frames(), "target": String(result.request.target_id), "event": String(result.request.event_id), "amount": result.request.amount, "health": result.health.current}))
		var observe_health: Callable = func(result: ActorResourceResult, target: StringName) -> void:
			health_events.append({"tick": Engine.get_physics_frames(), "target": String(target), "operation": String(result.operation), "status": int(result.status), "event_id": String(result.event_id), "amount_applied": result.amount_applied, "health": result.snapshot.current})
		actual_boss_health.changed.connect(observe_health.bind(&"boss"))
		actual_player_health.changed.connect(observe_health.bind(&"player"))
		actual_encounter.defeated.connect(func(_owner: BossEncounter) -> void:
			lifecycle_events.append({"tick": Engine.get_physics_frames(), "event": "boss_defeated", "health": actual_boss_health.current, "terminal": actual_boss_health.terminal}))
		actual_app.policy.player_fatal.connect(func() -> void:
			lifecycle_events.append({"tick": Engine.get_physics_frames(), "event": "player_fatal"}))
		actual_app.director.run_ended.connect(func(result: DemoRunResult) -> void:
			lifecycle_events.append({"tick": Engine.get_physics_frames(), "event": "run_ended", "reason": String(result.reason), "event_id": String(result.event_id), "status": int(result.status)}))
		var actual_map := actual_stage.map_index == 1 and actual_app.director.region_map_index == 1 and str(actual_stage.generated.manifest.seed) == PlainsRegionCampaign.seed_for(actual_app.director.seed, 1) and str(actual_stage.generated.manifest.manifest_hash).length() == 64
		var actual_definition := actual_encounter.definition is BellstriderDefinition and is_equal_approx(actual_boss_health.capacity, 40.0) and is_equal_approx(actual_boss_health.current, 40.0)
		var actual_base := is_equal_approx(actual_controller.shoot_ability.weapon.damage, 1.0) and actual_controller.shoot_ability.weapon.rounds == 1 and actual_player.tuning.max_jumps == 1 and actual_controller.jump_ability.maximum_jumps() == 1 and not actual_controller.traversal.hook_enabled
		check(actual_map, "roll positive uses actual connected map1 identity and campaign seed")
		check(actual_definition, "roll positive starts at current formal Bell forty HP")
		check(actual_base, "roll positive retains actual base-one weapon, one jump and no hook")
		platform_positive = {"entry": "actual DemoApp map1 shared fixture", "manifest_seed": actual_stage.generated.manifest.seed, "manifest_hash": actual_stage.generated.manifest.manifest_hash, "initial_boss_HP": actual_boss_health.current, "initial_player_HP": actual_player_health.current, "initial_rounds": actual_controller.action_resources.shot_charges, "initial_energy": actual_controller.actor_resources.stamina.current, "combat_frame_limit": 7200, "scope": "first autonomous roll group; not a complete fight"}
		if actual_map and actual_definition and actual_base:
			await BELL_PLATFORM.place_initial_entry(self, actual_app, actual_boss)
			var activated: bool = live.call() and actual_app._boss_started and is_equal_approx(actual_boss_health.current, 40.0) and is_equal_approx(actual_player_health.current, actual_player_health.capacity) and is_equal_approx(actual_player_health.current, initial_hp) and not actual_player_health.terminal
			check(activated, "shared initial room placement activates the real Boss without resource damage")
			if activated:
				end_reason = "original_7200_frame_budget_exhausted"
				for _frame: int in 7200:
					if not bool(live.call()):
						end_reason = "actual_world_released"
						break
					pilot.platform_observation = BELL_PLATFORM.platform_observation(actual_stage, actual_player, actual_controller, actual_encounter)
					var metrics: Dictionary = actual_encounter.combat_metrics()
					var actual_units: Array[Dictionary] = BELL_PLATFORM.reward_units(actual_stage)
					pilot.step(actual_app, actual_encounter, metrics, actual_units)
					actual_trace.append({"tick": Engine.get_physics_frames(), "player": [actual_player.global_position.x, actual_player.global_position.y], "boss": [actual_boss.global_position.x, actual_boss.global_position.y], "player_HP": actual_player_health.current, "boss_HP": actual_boss_health.current, "grounded": actual_player.is_on_floor(), "normal_velocity": [actual_player.normal_velocity.x, actual_player.normal_velocity.y], "state": String(actual_encounter.mode), "clock": actual_encounter.clock, "group": metrics.get("groups_started", 0), "groups_completed": metrics.get("groups_completed", 0), "group_plan": metrics.get("group_plan", {}).duplicate(true), "used_jumps": actual_controller.jump_ability.used_jumps, "rounds": actual_controller.action_resources.shot_charges, "energy": actual_controller.actor_resources.stamina.current, "router_axis": actual_controller.router.axis, "trial": pilot.platform_snapshot(), "support_observation": pilot.platform_observation.duplicate(true)})
					# Drain the actual sampled tick, including policy callbacks, before
					# accepting its group-complete label or deciding a failure.
					await physics_frame
					if not bool(live.call()):
						end_reason = "actual_world_released"
						break
					if not str(pilot.platform_failure).is_empty():
						end_reason = "actual_platform_procedure_failed"
						break
					if str(pilot.platform_trial.get("phase", "")) == "complete":
						end_reason = "actual_first_group_completed"
						break
	var shared_checks: Dictionary = observer.validate_first_group(pilot, actual_events, lifecycle_events, validator_failures)
	var shared_pass := not shared_checks.is_empty()
	for key: String in shared_checks:
		var ok := bool(shared_checks[key])
		check(ok, "shared current platform roll proof: " + key)
		shared_pass = shared_pass and ok
	var no_player_settlement := not actual_events.any(func(row: Dictionary) -> bool: return row.target == "player")
	check(no_player_settlement, "actual App entry and complete first group have no player policy settlement")
	var actual_positive: bool = shared_pass and no_player_settlement and end_reason == "actual_first_group_completed" and bool(live.call()) and actual_player_health != null and initial_hp > 0.0 and is_equal_approx(actual_player_health.current, initial_hp)
	check(actual_positive, "held base jump clears actual full body roll")
	platform_positive.merge({"passed": actual_positive, "end_reason": end_reason, "checks": shared_checks, "validator_failures": validator_failures, "trace": actual_trace, "inputs": pilot.input_rows.duplicate(true), "ledger": pilot.platform_trials.duplicate(true), "damage_events": actual_events.duplicate(true), "health_events": health_events.duplicate(true), "lifecycle_events": lifecycle_events.duplicate(true), "final_player_HP": actual_player_health.current if actual_player_health != null else null, "final_boss_HP": actual_boss_health.current if actual_boss_health != null else null}, true)
	if is_instance_valid(actual_app):
		if is_instance_valid(actual_app.controller) and is_instance_valid(actual_app.controller.router):
			actual_app.controller.router.set_source_axis(&"keyboard_mouse", 0.0)
			actual_app.controller.router.set_jump_held(&"keyboard_mouse", false)
		actual_app.abandon_run()
		check(await load("res://tests/audio_teardown.gd").drain_world(actual_app), "actual positive App audio drains")
		actual_app.free()
		await frames(2)
