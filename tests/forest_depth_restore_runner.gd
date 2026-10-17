extends SceneTree
## Actual normal-input App entry/earned-state reload; not full Boss admission.
const AUDIO := preload("res://tests/audio_teardown.gd")
var assertions := 0
var failures := 0
var checks: Array[Dictionary] = []
var cases: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions += 1
	checks.append({"label":label,"passed":ok})
	if not ok:
		failures += 1
		printerr("FOREST RESTORE FAIL: "+label)
func frames(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame
func run() -> void:
	await guardian_case()
	await legacy_case()
	var output := "res://build/forest_depth/restore/native/capture.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"Actual DemoApp V6 Guardian normal-input earned-state reload and v1 compatibility; NOT full Boss gameplay admission","engine":Engine.get_version_info(),"assertions":assertions,"failures":failures,"checks":checks,"cases":cases},"\t"))
	file.close()
	print("FOREST DEPTH RESTORE: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)
func guardian_case() -> void:
	var trace: Node=load("res://tests/forest_depth_region_trace.gd").new()
	trace.seed_value="forest-depth-hollow-00";trace.map_index=1;trace.route_name="fast"
	root.add_child(trace)
	for unused: int in 3000:
		if trace.finished: break
		await frames(1)
	check(trace.finished and trace.failures.is_empty(),"actual formal fast route reaches opened gate without position/resource injection")
	if not trace.finished or not trace.failures.is_empty():
		if is_instance_valid(trace.app): await dispose(trace.app)
		trace.free()
		return
	var app: DemoApp=trace.app
	var stage := app.stage as ThornForestRegionStage
	var duel := stage.boss.get_node("Encounter") as RootbellGuardianV2
	check(duel!=null and duel._duel_bound,"actual App physically binds current Guardian arena")
	if duel==null:
		await dispose(app);trace.free();return
	var phase_events: Array[Dictionary]=[]
	var combat_frames: Array[Dictionary]=[]
	duel.duel_event.connect(func(row: Dictionary) -> void: phase_events.append(row.duplicate(true)))
	app.policy.batch_resolved.connect(func(results: Array[DamageResult]) -> void:
		for result: DamageResult in results:
			phase_events.append({"event":"actual_app_policy_result","source":String(result.request.source_id),"target":String(result.request.target_id),"amount":result.request.amount,"event_id":String(result.request.event_id)})
	)
	var earned := await earn_current_restore_state(app,duel,combat_frames)
	check(earned,"normal route entry, actual Body cycle, ordinary bullets and actual Bell counter earn V6 phase2 stagger")
	if not earned:
		cases.append({"id":"guardian_app_reload_failed_preparation","events":phase_events,"combat_frames":combat_frames,"route_frames":trace.frames,"route_events":trace.events})
		await dispose(app);trace.free();return
	app._pause_for_menu()
	check(app._boss_started and duel.active and stage.boss_seal.closed,"actual arena entrance starts Guardian and arms seal")
	check(duel.geometry.root_supports.is_empty() and duel.geometry.side_branches.size()==2,"V6 uses two static branches without retired damageable roots")
	check(duel.stage_phase==2 and duel._cycles>0,"real completed Body cycle and normal damage drive phase2")
	check(phase_events.any(func(row: Dictionary) -> bool: return row.event=="duel_phase_changed" and row.phase==2),"actual Guardian phase transition event emitted")
	check(phase_events.any(func(row: Dictionary) -> bool: return row.event=="bell_counter_committed"),"real returned Bell damage committed through Policy")
	stage.capture_state()
	var saved: Dictionary=app.region_state.boss_state.duplicate(true)
	check(saved.duel_version=="guardian-two-action-cycle-v6" and not saved.has("duel_roots"),"current snapshot has exact V6 identity and excludes retired root ledger")
	var paused_snapshot := duel.combat_snapshot().duplicate(true)
	await frames(3)
	check(paused and duel.combat_snapshot()==paused_snapshot,"actual menu pause freezes Boss simulation and body")
	var state := app.region_state
	var old_stage_id := stage.get_instance_id()
	var old_duel_id := duel.get_instance_id()
	var old_actor_epoch := app.lifetime.actor_epoch
	var old_token := app.lifetime.token()
	var malformed_rows: Array = [null,[],[saved.position[0]],["bad",saved.position[1]],[saved.position[0]+1,saved.position[1]],[INF,saved.position[1]]]
	for malformed: Variant in malformed_rows:
		var invalid := saved.duplicate(true)
		invalid.body_position=malformed
		var before := duel.combat_snapshot()
		var hp := duel.health.current
		check(not app._restore_forest_duel(duel,invalid),"App rejects malformed/mismatched body_position "+str(malformed))
		check(duel.combat_snapshot()==before and duel.health.current==hp,"malformed App restore is side-effect free "+str(malformed))
	for invalid_field: String in ["stage_phase","weak_side","intro_duration","next_bell","duel_roots","duel_version","duel_counter_enabled"]:
		var invalid := saved.duplicate(true)
		invalid[invalid_field] = {"stage_phase":3,"weak_side":0,"intro_duration":INF,"next_bell":1,"duel_roots":{},"duel_version":"guardian-two-action-static-arena-v5","duel_counter_enabled":1}[invalid_field]
		var before := duel.combat_snapshot()
		check(not app._restore_forest_duel(duel,invalid),"App rejects malformed current duel contract "+invalid_field)
		check(duel.combat_snapshot()==before and duel.health.current==saved.health,"invalid duel contract leaves state untouched "+invalid_field)
	await app._load_stage() # Required real unload/create/configure/bind/restore path.
	await process_frame # Flush deferred old-stage disposal while simulation remains paused.
	check(app.stage is ThornForestRegionStage and app.stage.assembly_ok,"App reload reassembled v2 stage")
	var loaded := app.stage as ThornForestRegionStage
	var restored := loaded.boss.get_node("Encounter") as RootbellGuardianV2
	check(loaded.get_instance_id()!=old_stage_id and restored.get_instance_id()!=old_duel_id,"actual old Stage/Boss replaced")
	check(app.region_state==state and state.manifest_hash==loaded.generated.manifest.manifest_hash,"App preserves same hash-bound map state")
	check(app.lifetime.actor_epoch>old_actor_epoch and not app.lifetime.accepts(old_token),"reload invalidates old actor token")
	check(restored.last_restore_accepted and restored.geometry.root_supports.is_empty(),"delayed App restore accepted after current arena binding")
	check(restored.health.current==saved.health,"actual reassembled Boss keeps damaged health")
	check(loaded.boss.position.is_equal_approx(Vector2(saved.position[0],saved.position[1])),"actual reassembled moving body position retained")
	check(restored.stage_phase==saved.stage_phase and restored.stage_phase==2,"HP-triggered Guardian phase2 retained")
	check(restored.weak_side==saved.weak_side and is_equal_approx(restored.intro_duration,float(saved.intro_duration)),"current contract weak-side and intro-duration restored unchanged")
	check(saved.mode=="bell_stagger" and restored.mode==&"bell_stagger" and is_equal_approx(restored.clock,float(saved.clock)),"actually earned Bell stagger resumes bounded remaining clock")
	check(restored.combat_snapshot().duel_counter_enabled==saved.duel_counter_enabled,"current counter-enabled contract retained")
	check(restored.attack_epoch>int(saved.attack_epoch) and restored._flight_token==null,"old attack epoch superseded without flight token replay")
	check(restored._attack_serial==int(saved.serial) and restored._cycles==int(saved.cycles) and restored._next_bell==saved.next_bell,"actual serial/cycles/next-bell retained")
	check(loaded.boss_seal.closed and loaded.boss_seal.walls.all(func(wall: StaticBody2D) -> bool: return wall.collision_layer==1),"App rebinds actual closed seal walls")
	var once: Dictionary=restored.combat_snapshot().duplicate(true)
	# The actual active Boss entrance path performs its second restore.
	app._start_generated_boss()
	check(app._boss_started and restored.active and loaded.restored_boss.is_empty(),"active reload consumes saved Boss through actual App activation")
	check(restored.health.current==saved.health and not restored.combat_snapshot().has("duel_roots"),"activation preserves damaged V6 Boss without retired ledger")
	check(restored.attack_epoch>int(once.attack_epoch),"active restoration issues another fresh attack epoch")
	cases.append({"id":"guardian_app_reload","saved":saved,"after_bound_restore":once,"after_activation":restored.combat_snapshot(),"actor_epoch_before":old_actor_epoch,"actor_epoch_after":app.lifetime.actor_epoch,"malformed_cases":malformed_rows.size(),"invalid_contract_cases":7,"phase_events":phase_events,"combat_frames":combat_frames,"route_frames":trace.frames,"route_events":trace.events,"fixture_setup":"No body/health/phase/cycles/mode injection: actual formal fast route then normal InputRouter combat and earned Bell stagger; integration evidence, not Boss fairness or player acceptance"})
	app._resume_from_menu()
	check(not paused,"actual App resume exits menu pause after active reload")
	await dispose(app)
	trace.free()
func legacy_case() -> void:
	var app := DemoApp.new()
	app.meta_persistence_enabled=false
	root.add_child(app)
	check(app.start_debug_region(&"thorn_forest",1,"restore-legacy",ThornForestRegionGenerator.LEGACY_VERSION),"ordinary explicit v1 App entry accepted")
	await frames(8)
	paused=true
	var stage := app.stage as ThornForestRegionStage
	check(stage!=null and stage.assembly_ok,"v1 actual stage assembled")
	if stage==null or not stage.assembly_ok:
		await dispose(app)
		return
	var boss := stage.boss.get_node("Encounter") as ThornForestEncounter
	check(not boss.has_method("bind_duel"),"v1 retains ordinary old Boss path")
	boss.health.apply_damage(ActorResourceRequest.new(&"restore_legacy_damage",boss.health.epoch,1.0,boss.health.get_instance_id()))
	stage.capture_state()
	var hp := boss.health.current
	var state := app.region_state
	await app._load_stage()
	var restored := app.stage.boss.get_node("Encounter") as ThornForestEncounter
	check(app.region_state==state and app.forest_content_version==ThornForestRegionGenerator.LEGACY_VERSION,"ordinary v1 hash/state/version retained")
	check(restored.health.current==hp and app.stage.boss.scene_file_path=="res://scenes/bosses/thorn_guardian.tscn","ordinary v1 damaged Boss reload preserved")
	cases.append({"id":"legacy_app_reload","health_before":hp,"health_after":restored.health.current,"scene":app.stage.boss.scene_file_path})
	await dispose(app)
func dispose(app: DemoApp) -> void:
	paused=false
	app.abandon_run()
	await frames(4)
	check(await AUDIO.drain_world(app),"owned App audio drained")
	app.free()
	await frames(2)
func earn_current_restore_state(app: DemoApp, duel: RootbellGuardianV2, samples: Array[Dictionary]) -> bool:
	var controller: PlayerController=app.controller
	var player: PlayerMotor=app.player
	var last_hook := -1
	var last_warning := ""
	var jump_until := -1
	var next_shot := 0
	var direction := 1
	for tick: int in 2400:
		if not app.lifetime.active or controller.actor_resources.health.terminal or duel.health.terminal: return false
		if duel.stage_phase==2 and duel._cycles>0 and duel.mode==&"bell_stagger" and duel.clock>0: return true
		if not app._boss_started:
			# Walk from actual gate-ready support into the real arena trigger.
			controller.router.set_move_axis(1)
		else:
			var arena: Array=duel.geometry.boss_arena
			if player.global_position.x>float(arena[0])+float(arena[2])-110: direction=-1
			elif player.global_position.x<float(arena[0])+100: direction=1
			var bell := duel._bell
			if duel.mode in [&"bell_warning",&"bell_watch"] and is_instance_valid(bell) and last_hook!=bell.get_instance_id():
				var branch: Dictionary=duel.geometry.side_branches[0 if bell.facing<0 else 1]
				var x:=float(branch.rect[0])+float(branch.rect[2])*.5
				direction=int(signf(x-player.global_position.x)) if absf(x-player.global_position.x)>4 else 0
			var warning := "%s/%s" % [duel.mode,duel._attack_serial]
			if duel.mode in [&"pursuit_warning",&"bell_warning"] and warning!=last_warning:
				last_warning=warning
				jump_until=tick+12
				if duel.mode==&"pursuit_warning":
					direction=int(signf(player.global_position.x-duel.attack_goal.x))
					if direction==0: direction=-int(signf(duel.motor.global_position.x-player.global_position.x))
			controller.router.set_move_axis(direction)
			controller.router.set_jump_held(&"restore_normal_combat",tick<jump_until)
			if controller.traversal.state==&"free" and not controller.traversal.hook_used and is_instance_valid(bell) and bell.state==&"outbound" and last_hook!=bell.get_instance_id():
				var start:=player.global_position+Vector2(0,-6)
				if start.distance_to(bell.global_position)<controller.traversal.definition.hook_range-12:
					var ray:=PhysicsRayQueryParameters2D.create(start,bell.global_position,0xFFFFFFFF,[player.get_rid()])
					ray.collide_with_areas=true
					if player.get_world_2d().direct_space_state.intersect_ray(ray).get("collider")==bell:
						var predicted:=bell.global_position
						for unused: int in 3:
							var time:=controller.traversal.definition.hook_windup+start.distance_to(predicted)/controller.traversal.definition.hook_flight_speed
							predicted=bell.global_position+bell.velocity*time+Vector2(0,.5*bell.config.bell_gravity*time*time)
						last_hook=bell.get_instance_id()
						controller.router.request_action(&"grapple",(predicted-start).normalized())
			# Real normal bullets earn the low-HP phase, then stop firing so the
			# requested counter state can survive; no HealthState writes or refill.
			if duel.health.current>duel.health.capacity*(duel.definition as BossDuelDefinition).phase2_health_ratio and duel.core_open and tick>=next_shot and not controller.traversal.busy() and controller.traversal.state!=&"hook_kick":
				var half:=duel.definition.collision_size*.5-Vector2(4,4)
				var offsets: Array[Vector2]=[Vector2.ZERO,Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(0,-half.y),Vector2(-half.x,half.y),Vector2(half.x,half.y)]
				for offset: Vector2 in offsets:
					var aim:=duel.motor.global_position+offset
					var ray:=PhysicsRayQueryParameters2D.create(player.global_position+Vector2(0,-6),aim,13,[player.get_rid()])
					if player.get_world_2d().direct_space_state.intersect_ray(ray).get("collider")!=duel.motor: continue
					controller.router.request_action(&"shoot_release",(aim-player.global_position).normalized())
					next_shot=tick+ceili(player.tuning.shot_cooldown*Engine.physics_ticks_per_second)
					break
		samples.append({"tick":tick,"player_position":[player.global_position.x,player.global_position.y],"player_hp":controller.actor_resources.health.current,"energy":controller.actor_resources.stamina.current,"hook_state":String(controller.traversal.state),"boss":duel.combat_snapshot(),"app_boss_started":app._boss_started})
		await frames(1)
	return false
