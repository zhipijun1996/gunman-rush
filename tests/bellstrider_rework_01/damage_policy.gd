extends SceneTree
## Actual DemoApp/start_plains integration, with disclosed position/equipment and
## synchronous policy-flush fixtures. This is NOT natural battle, complete weapon
## coverage, two-shot timing, or user/art acceptance. No HP/clock/AI injection.
const TEARDOWN := preload("res://tests/audio_teardown.gd")
var app: Variant
var encounter: BellstriderEncounter
var core: WindkeeperDamageable
var body: WindkeeperDamageable
var assertions := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var setup_observations: Array[Dictionary] = []
var player_damage: Array[Dictionary] = []
var committed: Array[Dictionary] = []
var fired: Array[Dictionary] = []
var packets: Array[Dictionary] = []
var original_manifest := ""
var serial := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	assertions += 1
	if not value:
		failures.append(label)
		printerr("FAIL: ", label)

func ticks(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func cleanup() -> void:
	paused = false
	if is_instance_valid(app):
		app.abandon_run()
		check(await TEARDOWN.drain_world(app), "actual App releases owned audio at teardown")
		app.free()
	app = null
	encounter = null
	core = null
	body = null
	await ticks(2)

func equip_item(enabled: bool) -> void:
	# Uses the real pause-session token and EquipmentService, not runtime maps.
	paused = false
	app.toggle_pause()
	check(paused and app.menu.visible_panel == &"build", "actual pause owns equipment session")
	var desired: Array[StringName] = []
	if enabled:
		var owned: RunItemInstance = app.build.inventory.instance_for_definition(&"P24")
		check(owned != null, "actual reward inventory owns test P24")
		if owned != null: desired.append(owned.instance_id)
	app._submit_equipment(desired, int(app.build.equipment.snapshot().revision), int(app._equipment_session))
	check(app.build.equipment.equipped_ids() == desired, "actual equipment command commits desired selection")
	app.menu.close_panel()

func diagnostic(label: String) -> Dictionary:
	var row := {"label":label,"physics_frame":Engine.get_physics_frames(),"paused":paused}
	if is_instance_valid(app):
		row.merge({"stage_pending":app._stage_pending,"boss_started":app._boss_started,"director_state":int(app.director.state),"lifetime_active":app.lifetime.active,"actor_epoch":app.lifetime.actor_epoch,"stage_epoch":app.lifetime.stage_epoch,"in_boss_core":app._in_boss_core()})
		if is_instance_valid(app.stage):
			row["stage_path"] = str(app.stage.get_path())
			if app.stage is PlainsRegionStage:
				var arena: Rect2 = app.stage.boss_arena
				row["arena"] = [arena.position.x,arena.position.y,arena.size.x,arena.size.y]
		if is_instance_valid(app.player):
			var point: Vector2 = app.player.global_position
			row.merge({"player_position":[point.x,point.y],"player_on_floor":app.player.is_on_floor(),"player_health":app.controller.actor_resources.health.current,"player_terminal":app.controller.actor_resources.health.terminal,"controller_active":app.controller.active,"player_can_process":app.player.can_process(),"controller_can_process":app.controller.can_process()})
	if is_instance_valid(encounter):
		row.merge({"encounter_active":encounter.active,"mode":String(encounter.mode),"clock":encounter.clock,"encounter_can_process":encounter.can_process(),"encounter_physics_enabled":encounter.is_physics_processing(),"encounter_process_mode":encounter.process_mode,"boss_health":encounter.health.current,"fight_seconds":encounter.combat_metrics().fight_seconds})
	setup_observations.append(row.duplicate(true))
	return row

func setup() -> bool:
	await cleanup()
	app = load("res://scripts/demo/demo_app.gd").new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	if not app.start_plains("level-design-v2-baseline/08"):
		check(false, "actual App accepts formal Plains start")
		return false
	var started := Time.get_ticks_msec()
	for index: int in 3600:
		if not app._stage_pending and app.stage is PlainsRegionStage and app.stage.assembly_ok and app._can_interact(): break
		if Time.get_ticks_msec()-started > 60000: break
		await ticks(1)
	check(not app._stage_pending and app.stage is PlainsRegionStage and app.stage.assembly_ok, "actual generated map1 completes original assembly")
	if app._stage_pending or not app.stage is PlainsRegionStage or not app.stage.assembly_ok: return false
	encounter = app.stage.boss.get_node("Encounter") as BellstriderEncounter
	check(encounter != null and app._item_runtime != null, "actual map instantiates Bellstrider and formal ItemRuntime")
	if encounter == null or app._item_runtime == null: return false
	original_manifest = JSON.stringify(app.stage.generated.manifest)
	diagnostic("assembled_before_fixture")
	app.policy.batch_resolved.connect(func(results: Array[DamageResult]) -> void:
		for result: DamageResult in results:
			if result.request.target_id == &"player":
				player_damage.append({"frame":Engine.get_physics_frames(),"source":String(result.request.source_id),"event":String(result.request.event_id),"kind":int(result.request.kind),"hp_lost":result.hp_lost,"lethal":result.lethal,"context":diagnostic("actual_player_damage_commit")}))
	var choices: Array[ItemDefinition] = [ItemCatalogV5.get_item(&"P24")]
	var offer: RewardOffer = app.rewards.create_cache_offer(&"bellstrider_policy_fixture/P24", choices, &"explicit_test_reward")
	check(offer != null, "SETUP real reward service creates disclosed P24 offer")
	if offer == null: return false
	var claim := RewardClaimRequest.new()
	claim.token = app.lifetime.token()
	claim.offer_id = offer.offer_id
	claim.option_id = &"P24"
	claim.claim_id = &"bellstrider_policy_fixture/P24/claim"
	check(app.rewards.claim(claim).accepted(), "SETUP real reward transaction grants P24 without ownership injection")
	equip_item(true)
	await ticks(2)
	check(app._item_runtime.has(&"P24"), "actual ItemRuntime sees authoritative equipped source")
	body = app.stage.boss.get_node("Damageable") as WindkeeperDamageable
	core = encounter._core.get_node("Damageable") as WindkeeperDamageable
	check(core != null and body != null, "actual installed upper bell and armour receivers exist")
	if core == null or body == null: return false
	check(core._health_state == body._health_state and core.damage_epoch == body.damage_epoch, "actual upper bell and policy root own the same HealthState and epoch")
	check(encounter.health.capacity == 40.0 and app.player.tuning.projectile_damage == 1.0 and app.player.tuning.max_air_shots == 1, "formal base HP/damage/air capacity remain configured rather than injected")
	body.damaged.connect(func(context: Dictionary) -> void:
		committed.append({"context":serializable_context(context), "HP":encounter.health.current, "mode":String(encounter.mode), "clock":encounter.clock, "frame":Engine.get_physics_frames()}))
	app.controller.shoot_ability.shot_fired.connect(func(direction: Vector2, id: int) -> void:
		fired.append({"direction":direction, "id":id, "packet":app.controller.shoot_ability.packet_id, "actor_epoch":app.lifetime.actor_epoch}))
	app.controller.shoot_ability.packet_changed.connect(func(reason: StringName, packet: int) -> void:
		packets.append({"reason":String(reason),"packet":packet,"frame":Engine.get_physics_frames(),"weapon":String(app.controller.shoot_ability.weapon.id),"actor_epoch":app.lifetime.actor_epoch}))
	if not await position_on_floor(-1): return false
	# Real App entry/arena containment owns activation; no manual Health or mode.
	if not app._boss_started: app._start_generated_boss()
	check(app._boss_started and encounter.active and app._in_boss_core(), "actual App admits and binds live arena encounter")
	diagnostic("intro_wait_before_resume")
	# position_on_floor deliberately pauses transaction samples. Resume the real
	# tree here so the original intro clock can actually run; no skip/clock edit.
	paused = false
	diagnostic("intro_wait_resumed")
	for index: int in 300:
		if not is_instance_valid(encounter) or not app.lifetime.active: break
		if encounter.mode != &"intro": break
		await ticks(1)
	diagnostic("intro_wait_completed")
	check(is_instance_valid(encounter) and encounter.accepts_combat_damage() and encounter.mode != &"intro", "actual autonomous intro completes before damage samples")
	paused = true
	return app._boss_started and is_instance_valid(encounter) and encounter.accepts_combat_damage()

func position_on_floor(side: int) -> bool:
	paused = false
	var motor: Node2D = app.stage.boss
	var x := motor.global_position.x + float(side)*190.0
	var query := PhysicsRayQueryParameters2D.create(Vector2(x,motor.global_position.y-120),Vector2(x,motor.global_position.y+240),1,[app.player.get_rid()])
	var support: Dictionary = app.player.get_world_2d().direct_space_state.intersect_ray(query)
	check(not support.is_empty() and (support.get("normal",Vector2.ZERO) as Vector2).dot(Vector2.UP) > .7, "SETUP sample has unchanged real supported floor")
	var floor_record := diagnostic("floor_query_before_position")
	floor_record["requested_x"] = x
	if not support.is_empty():
		var at: Vector2 = support.position
		var normal: Vector2 = support.normal
		floor_record.merge({"support_point":[at.x,at.y],"support_normal":[normal.x,normal.y],"support_path":str((support.collider as Node).get_path()),"support_class":(support.collider as Node).get_class()})
	setup_observations[-1] = floor_record
	if support.is_empty():
		paused = true
		return false
	# Position-only integration fixture. Epoch invalidation cancels fictitious
	# sweeps and forbids old packet eligibility after each disclosed relocation.
	app.lifetime.invalidate_actor()
	app.player.reset_at((support.position as Vector2)-Vector2(0,18))
	app.controller.router.clear("bellstrider_damage_policy_position_fixture")
	app.controller.router.activate_device(&"keyboard_mouse")
	await ticks(2)
	diagnostic("floor_resolved_after_two_real_ticks")
	check(app.player.is_on_floor(), "real Motor resolves support after disclosed positioning")
	paused = true
	return app.player.is_on_floor()

func projectile_sample(upper: bool, side: int) -> void:
	if not await position_on_floor(side): return
	paused = false
	for index: int in 30:
		if app.controller.shoot_ability.cooldown_remaining <= 0.0: break
		await ticks(1)
	var hp: float = encounter.health.current
	var shots := fired.size()
	var events := committed.size()
	var point: Vector2 = encounter._core.global_position if upper else app.stage.boss.to_global(Vector2(0,38))
	var unit: Vector2 = (point-app.player.global_position).normalized()
	app.controller.router.aim_direction = unit
	app.controller.router.request_action(&"shoot_release",unit)
	await ticks(14)
	paused = true
	check(fired.size() == shots+1, "real Router emits one actual pulse projectile")
	check(is_equal_approx(hp-encounter.health.current,1.0 if upper else 0.0), "real pulse upper/armour HP result side %s upper=%s" % [side,upper])
	check(committed.size() == events+(1 if upper else 0), "only committed bell hit emits shared primary damage signal")
	if upper and committed.size() > events:
		var context: Dictionary = committed[-1].context
		check(context.damage_type == &"projectile" and (context.hit_direction as Vector2).is_equal_approx(unit), "actual collision preserves real incoming projectile direction")
	observations.append({"kind":"Router pulse", "upper":upper, "side":side, "HP_before":hp, "HP_after":encounter.health.current, "mode":String(encounter.mode), "clock":encounter.clock, "fired_delta":fired.size()-shots, "committed_delta":committed.size()-events})

func serializable_context(context: Dictionary) -> Dictionary:
	var result := context.duplicate(true)
	# Do not retain callback closures/old App worlds in the cross-fixture log.
	for key: Variant in result.keys():
		if result[key] is Callable: result.erase(key)
	return result

func rejected_contexts() -> void:
	check(not committed.is_empty(), "negative provenance mutations start from an actual committed projectile context")
	if committed.is_empty(): return
	var admitted: Dictionary = (committed[-1].context as Dictionary).duplicate(true)
	var admitted_key := "%s:%s" % [admitted.get("session_id",-1),admitted.get("shot_id",-1)]
	check(app._boss_eligible_shots.get(admitted_key,-1) == app.lifetime.actor_epoch, "negative mutations retain a real current-epoch admitted packet")
	var hp := encounter.health.current
	var queue_before: int = app.policy._queue.size()
	var base := admitted.duplicate(true)
	base.event_id = "unadmitted-packet"
	base.shot_id = 2147480000
	check(not core.receive_damage(base), "forged unissued packet cannot enter actual App boss sink")
	var forged_item := admitted.duplicate(true)
	forged_item.event_id = "forged-effect"
	forged_item.item_effect_damage = true
	forged_item.item_origin = &"P24"
	forged_item.damage_type = &"item_effect"
	check(not core.receive_damage(forged_item), "forged effect flag without authoritative proof is rejected")
	for field: String in ["target_epoch","target_actor_id","source_actor_id","session_id"]:
		var altered := admitted.duplicate(true)
		altered.event_id = "wrong/"+field
		altered[field] = -900
		check(not core.receive_damage(altered), "real admitted packet with wrong "+field+" is rejected")
	check(not body.receive_damage(admitted), "armour rejects even matching owner/epoch shape context")
	check(encounter.health.current == hp and app.policy._queue.size() == queue_before, "rejected forged contexts never enqueue or mutate Health")
	if app.policy._queue.size() != queue_before:
		# Preserve the failure, then drain the real transaction before other probes.
		app.policy.resolve_batch()

func effect_transactions() -> void:
	check(core.can_receive_effects() and not body.can_receive_effects(), "only actual upper bell is eligible before AoE bookkeeping")
	check(core.damage_policy_owner() == body and body.damage_policy_owner() == body, "spatial bell and armour share one policy owner")
	var targets: Array[Dictionary] = app.controller.shoot_ability.behavior().receivers(encounter._core.global_position,180.0)
	var selected_core := 0
	var selected_body := 0
	for row: Dictionary in targets:
		if row.receiver == core: selected_core += 1
		if row.receiver == body: selected_body += 1
	check(selected_core == 1 and selected_body == 0, "actual shared AoE enumeration selects upper bell once and never armour")
	var before: Dictionary = encounter.combat_metrics()
	var mode := encounter.mode
	var clock := encounter.clock
	var pose := encounter._core.global_transform
	await ticks(4)
	check(encounter.clock == clock and encounter.mode == mode and encounter._core.global_transform == pose, "actual pause freezes encounter clock and shared bell pose")
	paused = false
	var runtime: ItemRuntime = app._item_runtime
	var hp := encounter.health.current
	check(not runtime.deal(body,1.0,&"body-only",&"P24"), "equipped actual effect cannot authorize armour as damage target")
	check(runtime.deal(core,1.0,&"valid-upper",&"P24"), "equipped actual effect queues through spatial bell and canonical policy proof")
	check(encounter.health.current == hp, "real effect waits for original FrameDamagePolicy commit")
	var applied: Array[DamageResult] = app.policy.resolve_batch()
	check(applied.size() == 1 and applied[0].request.target_id == &"boss" and is_equal_approx(hp-encounter.health.current,1.0), "actual frame policy commits authenticated upper-bell effect once")
	check(not runtime.deal(core,1.0,&"valid-upper",&"P24"), "same authenticated effect receipt cannot pay damage twice")
	check(encounter.mode == mode and encounter.clock == clock and encounter.stage_phase == int(before.group_plan.get("phase",encounter.stage_phase)), "synchronous valid hit never advances or resets the current attack clock/plan")
	var hp_after := encounter.health.current
	check(runtime.deal(core,1.0,&"stale-actor",&"P24"), "stale-actor probe first has a genuine authorized queued effect")
	app.lifetime.invalidate_actor()
	app.policy.resolve_batch()
	check(encounter.health.current == hp_after, "actor epoch invalidation suppresses queued actual effect")
	check(runtime.deal(core,1.0,&"stale-equipment",&"P24"), "equipment probe first has a genuine authorized queued effect")
	equip_item(false)
	# No await separates authoritative equipment mutation and this policy flush.
	app.policy.resolve_batch()
	check(encounter.health.current == hp_after, "authoritative unequip invalidates queued effect before deferred cache notification")
	check(not runtime.deal(core,1.0,&"after-unequip",&"P24"), "removed source cannot create a new effect proof")
	paused = true

func mouse_aim(pressed: bool, viewport_point: Vector2) -> void:
	# Exercise the installed KeyboardMouseAdapter, including its held/release
	# state. A shoot_release command alone deliberately does not start LASER.
	var motion := InputEventMouseMotion.new()
	motion.position = viewport_point
	motion.relative = Vector2(1,-1)
	root.push_input(motion,true)
	var button := InputEventMouseButton.new()
	button.position = viewport_point
	button.button_index = int(app.controller.router.profile.values.mouse_shoot_button)
	button.pressed = pressed
	root.push_input(button,true)

func beam_sample() -> void:
	if not await position_on_floor(-1): return
	paused = false
	check(app.controller.shoot_ability.equip(load("res://resources/weapons/sustained_laser.tres")), "SETUP explicit real Lv2 beam loadout; not progression proof")
	var hp := encounter.health.current
	var before_events := committed.size()
	var ability: ShootAbility = app.controller.shoot_ability
	var packet_before := ability.packet_id
	var viewport_point: Vector2 = app.player.get_canvas_transform()*encounter._core.global_position
	mouse_aim(true,viewport_point)
	await ticks(12)
	var held_engaged: bool = app.controller.router.aim_engaged
	var held_mode: StringName = app.controller.router.aim_mode
	var held_phase := ability.behavior().phase
	var held_packet := ability.packet_id
	var key := "%s:%s" % [app.controller.session_id,held_packet]
	var admitted_epoch: int = app._boss_eligible_shots.get(key,-1)
	var recorded_start := false
	for row: Dictionary in packets:
		if row.reason == "started" and int(row.packet) == held_packet and row.weapon == "sustained_laser" and int(row.actor_epoch) == app.lifetime.actor_epoch: recorded_start = true
	check(held_engaged and held_mode == &"attack", "real mouse adapter holds actual attack aim for LASER")
	check(held_packet > packet_before and recorded_start, "real held beam starts and records one new resource-admitted packet")
	check(admitted_epoch == app.lifetime.actor_epoch, "actual reserved beam packet is admitted by Bell-only started-packet hook")
	check(encounter.health.current < hp and committed.size() > before_events, "real beam ray reaches shared upper bell through actual App policy")
	mouse_aim(false,viewport_point)
	await ticks(1)
	check(not app.controller.router.aim_engaged and ability.behavior().phase != &"beam", "actual mouse release drops aim and ends beam drive")
	observations.append({"kind":"actual mouse adapter held Lv2 beam", "HP_before":hp,"HP_after":encounter.health.current,"committed_delta":committed.size()-before_events,"packet_before":packet_before,"packet":held_packet,"packet_admitted":admitted_epoch,"started_recorded":recorded_start,"held_aim_engaged":held_engaged,"held_aim_mode":String(held_mode),"held_phase":String(held_phase),"release_aim_engaged":app.controller.router.aim_engaged,"release_phase":String(ability.behavior().phase),"viewport_point":[viewport_point.x,viewport_point.y]})
	diagnostic("actual_beam_hold_and_release_completed")
	paused = true

func run() -> void:
	if await setup():
		await projectile_sample(true,-1)
		await projectile_sample(false,-1)
		await projectile_sample(true,1)
		rejected_contexts()
		await effect_transactions()
		check(JSON.stringify(app.stage.generated.manifest) == original_manifest, "integration fixtures preserve original generated Manifest bytes")
	if await setup():
		await beam_sample()
		check(JSON.stringify(app.stage.generated.manifest) == original_manifest, "beam fixture preserves original generated Manifest bytes")
	await cleanup()
	DirAccess.make_dir_recursive_absolute("res://build/bellstrider_rework_01")
	var report := {"checks":assertions,"failures":failures,"observations":observations,"setup_observations":setup_observations,"player_damage":player_damage,"committed":committed,"packets":packets,"scope":"actual App controlled integration fixtures: positioned player, disclosed real reward/equipment and Lv2 loadout; direct negative contexts, authenticated effect handler calls and synchronous policy flush; NOT natural battle/all-types coverage","not_verified":["natural fight","all15 weapon collision paths","hook physical route","G1-G5","two/three shot timing","art/audio/device/user acceptance"],"test_author":"root/guard_review_recovery; independent review of this test must be assigned to another reviewer"}
	var file := FileAccess.open("res://build/bellstrider_rework_01/damage-policy.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("BELLSTRIDER DAMAGE POLICY: %s checks, %s failures" % [assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
