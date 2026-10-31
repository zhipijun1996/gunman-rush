extends SceneTree
## Actual formal DemoApp routes with explicit position/loadout/capability fixtures.
## No HP, Boss mode, clock, policy admission, resource or invulnerability edits.
## Fixture projectiles/contact sources below are disclosed, not natural attacks.
const TEARDOWN := preload("res://tests/audio_teardown.gd")
var app: Variant
var encounter: BellstriderEncounter
var core: WindkeeperDamageable
var body: WindkeeperDamageable
var assertions := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var contexts: Array[Dictionary] = []
var sink_receipts: Array[Dictionary] = []
var player_results: Array[Dictionary] = []
var packet_events: Array[Dictionary] = []
var fixture_positions: Array[Dictionary] = []
var manifest := ""
var hook_negatives_done := false
var original_sink: Callable

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

func clean_context(context: Dictionary) -> Dictionary:
	var result := context.duplicate(true)
	for key: Variant in result.keys():
		if result[key] is Callable: result.erase(key)
	return result

func cleanup() -> void:
	paused = false
	if is_instance_valid(app):
		if is_instance_valid(app.stage) and app.stage is PlainsRegionStage and app.stage.assembly_ok:
			check(JSON.stringify(app.stage.generated.manifest) == manifest, "fixture preserves actual generated Manifest")
		app.abandon_run()
		check(await TEARDOWN.drain_world(app), "actual App audio/world drain completes")
		app.free()
	app = null
	encounter = null
	core = null
	body = null
	original_sink = Callable()
	await ticks(2)

func position_fixture(point: Vector2, label: String) -> void:
	# Reset only Motor kinematics after an explicitly disclosed relocation.
	# Epoch invalidation prevents an invented swept hit or old packet reuse.
	app.lifetime.invalidate_actor()
	app.controller.router.clear("bellstrider_weapon_routes_position_fixture")
	app.controller.router.activate_device(&"keyboard_mouse")
	app.player.reset_at(point)
	fixture_positions.append({"label":label,"point":point,"actor_epoch":app.lifetime.actor_epoch,"frame":Engine.get_physics_frames()})

func setup() -> bool:
	await cleanup()
	contexts.clear()
	sink_receipts.clear()
	player_results.clear()
	packet_events.clear()
	hook_negatives_done = false
	app = load("res://game/application/demo_app.gd").new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	check(app.start_plains("level-design-v2-baseline/08"), "SETUP formal map1 starts through actual App")
	for index: int in 3600:
		if not app._stage_pending and app.stage is PlainsRegionStage and app.stage.assembly_ok and app._can_interact(): break
		await ticks(1)
	check(not app._stage_pending and app.stage is PlainsRegionStage and app.stage.assembly_ok, "SETUP actual formal map assembles")
	if app._stage_pending or not app.stage is PlainsRegionStage or not app.stage.assembly_ok: return false
	manifest = JSON.stringify(app.stage.generated.manifest)
	encounter = app.stage.boss.get_node("Encounter") as BellstriderEncounter
	check(encounter != null, "SETUP formal map1 uses actual Bellstrider")
	if encounter == null: return false
	body = app.stage.boss.get_node("Damageable") as WindkeeperDamageable
	core = encounter._core.get_node("Damageable") as WindkeeperDamageable
	check(core != null and body != null and core.damage_policy_owner() == body, "SETUP real spatial bell forwards to formal body policy owner")
	if core == null or body == null: return false
	var boss_point: Vector2 = app.stage.boss.global_position
	var x := boss_point.x-190.0
	var ray := PhysicsRayQueryParameters2D.create(Vector2(x,boss_point.y-120),Vector2(x,boss_point.y+240),1,[app.player.get_rid()])
	var support: Dictionary = app.player.get_world_2d().direct_space_state.intersect_ray(ray)
	check(not support.is_empty(), "SETUP disclosed initial position has real unchanged support")
	if support.is_empty(): return false
	position_fixture((support.position as Vector2)-Vector2(0,18),"initial real support")
	await ticks(2)
	check(app.player.is_on_floor(), "SETUP actual Motor resolves initial floor")
	if not app._boss_started: app._start_generated_boss()
	check(app._boss_started and encounter.active and app._in_boss_core(), "SETUP original App arena binding admits encounter")
	# Explicitly run the original intro, unlike a paused synthetic-ready fixture.
	paused = false
	for index: int in 300:
		if encounter.mode != &"intro": break
		await ticks(1)
	check(encounter.accepts_combat_damage() and encounter.mode != &"intro", "SETUP autonomous original intro finishes")
	check(encounter.health.capacity == 40.0 and encounter.health.current == 40.0, "formal untouched 40HP starts each route")
	if not encounter.accepts_combat_damage(): return false
	body.damaged.connect(func(context: Dictionary) -> void:
		contexts.append(clean_context(context)))
	app.policy.batch_resolved.connect(func(results: Array[DamageResult]) -> void:
		for result: DamageResult in results:
			if result.request.target_id == &"player":
				player_results.append({"event":String(result.request.event_id),"source":String(result.request.source_id),"hp_lost":result.hp_lost,"frame":Engine.get_physics_frames()}))
	app.controller.shoot_ability.packet_changed.connect(func(reason: StringName, packet: int) -> void:
		packet_events.append({"reason":reason,"packet":packet,"admitted":app._boss_eligible_shots.get("%s:%s" % [app.controller.session_id,packet],-1),"actor_epoch":app.lifetime.actor_epoch}))
	original_sink = body.damage_sink
	# Instrument admission without changing a returned result or adding a proof.
	body.damage_sink = observe_sink
	paused = true
	return true

func observe_sink(context: Dictionary) -> bool:
	var traversal: TraversalAbility = app.controller.traversal
	if context.get("damage_type",&"") == &"grapple" and not hook_negatives_done:
		hook_negatives_done = true
		check(traversal.state == &"hook_pull" and traversal.hook_target == encounter._core, "actual grapple arrives in hook_pull at real upper-bell anchor")
		var hp := encounter.health.current
		for field: String in ["source_actor_id","attack_id","session_id","target_epoch"]:
			var forged := context.duplicate()
			forged[field] = -903
			forged.event_id = "weapon_routes/forged/"+field
			check(not original_sink.call(forged), "explicit forged grapple "+field+" rejected by real App sink during valid hook")
		check(not body.receive_damage(context), "armour rejects actual authentic grapple context")
		check(encounter.health.current == hp, "negative grapple admission probes do not mutate HP")
	var accepted: bool = original_sink.call(context) == true
	sink_receipts.append({"context":clean_context(context),"accepted":accepted,"hook_state":String(traversal.state),"hook_serial":traversal._serial,"session":app.controller.session_id,"source":app.player.get_instance_id(),"hook_target_is_core":traversal.hook_target == encounter._core,"frame":Engine.get_physics_frames()})
	return accepted

func grapple_route(upper: bool) -> void:
	# Explicit capability fixture via real grant API; Plains progression does
	# not naturally grant H. No traversal state/target/serial is manufactured.
	check(app.controller.traversal.grant(&"grapple"), "SETUP real traversal grant enables disclosed H capability")
	var point: Vector2 = encounter._core.global_position if upper else app.stage.boss.to_global(Vector2(0,38))
	position_fixture(point+Vector2(-170,0),"upper-bell airborne grapple" if upper else "armour airborne grapple")
	var direction: Vector2 = (point-app.player.global_position-Vector2(0,-6)).normalized()
	var hp := encounter.health.current
	paused = false
	app.controller.router.aim_direction = direction
	app.controller.router.request_action(&"grapple",direction)
	var protected_sample := false
	var states: Array[String] = []
	for index: int in 90:
		await ticks(1)
		var traversal: TraversalAbility = app.controller.traversal
		var state := String(traversal.state)
		if not states.has(state): states.append(state)
		if upper and not protected_sample and traversal.state in [&"hook_contact_kick",&"hook_kick"] and not contexts.is_empty():
			observations.append(contact_diagnostic("live_hook_before_synchronous_sample"))
			protected_sample = true
			# No await/physics step or tree pause may cancel this real hook before
			# observing protection. The original batch resolves inside the sample.
			contact_and_projectile_sample()
			observations.append(contact_diagnostic("after_real_player_hit_before_tree_pause"))
			paused = true
			observations.append(contact_diagnostic("after_tree_pause_following_real_player_hit"))
			# Actual damage already cancels H before pause; do not claim this
			# post-pause observation isolates pause as the cancellation cause.
			break
		if not upper and state == "free" and index > 12: break
	paused = true
	if upper:
		check(hook_negatives_done and not contexts.is_empty(), "real Router hook physically reaches bell and commits through App policy")
		check(is_equal_approx(hp-encounter.health.current,app.controller.traversal.definition.hook_damage), "actual accepted grapple removes original configured hook damage once")
		check(protected_sample, "accepted hook reaches live contact-protection sample")
		if not contexts.is_empty():
			var stale := contexts[0].duplicate()
			stale.event_id = "weapon_routes/post_pull_replay"
			check(not original_sink.call(stale), "authentic hook context replay outside hook_pull rejected by actual App")
	else:
		check(states.has("hook_miss") or states.has("hook_retract"), "real physical grapple rejects non-anchor armour")
		check(contexts.is_empty() and encounter.health.current == hp, "Router armour grapple cannot damage boss")
	observations.append({"route":"Router grapple","upper":upper,"HP_before":hp,"HP_after":encounter.health.current,"states":states,"sink":sink_receipts.duplicate(true),"committed":contexts.duplicate(true),"player_results":player_results.duplicate(true)})

func node_diagnostic(node: Node) -> Dictionary:
	if not is_instance_valid(node): return {"valid":false}
	var script: Script = node.get_script() as Script
	return {"valid":true,"path":String(node.get_path()) if node.is_inside_tree() else "<outside_tree>","class":node.get_class(),"script":script.resource_path if script != null else "","id":node.get_instance_id()}

func contact_diagnostic(label: String) -> Dictionary:
	var traversal: TraversalAbility = app.controller.traversal
	var target: Node2D = traversal._contact_target
	var receiver: Damageable = target.get_node_or_null("Damageable") as Damageable if is_instance_valid(target) else null
	var owner: Damageable = receiver.damage_policy_owner() if is_instance_valid(receiver) else null
	var owner_parent: Node = owner.get_parent() if is_instance_valid(owner) else null
	return {"route":"hook protection diagnostic","label":label,"paused":paused,"frame":Engine.get_physics_frames(),"state":String(traversal.state),"traversal_session":traversal._session,"controller_session":app.controller.session_id,"controller_active":app.controller.active,"contact_remaining":traversal._contact_remaining,"contact_target":node_diagnostic(target),"hook_target":node_diagnostic(traversal.hook_target),"receiver":node_diagnostic(receiver),"policy_owner":node_diagnostic(owner),"policy_owner_parent":node_diagnostic(owner_parent),"boss":node_diagnostic(app.stage.boss),"owner_parent_is_boss":owner_parent == app.stage.boss,"receiver_is_owner":receiver == owner,"protects_boss":traversal.protects_contact(app.stage.boss),"router_epoch":app.controller.router.epoch,"router_sequence":app.controller.router.sequence}

func contact_and_projectile_sample() -> void:
	var traversal: TraversalAbility = app.controller.traversal
	observations.append(contact_diagnostic("live_synchronous_protection_assertion"))
	check(not paused, "protection sample observes actual live hook before Router pause cancellation")
	check(traversal.protects_contact(app.stage.boss), "real accepted hook protects only its canonical mechanical body contact")
	var unrelated := Node2D.new()
	app.stage.add_child(unrelated)
	unrelated.global_position = app.player.global_position
	check(not traversal.protects_contact(unrelated), "real hook does not protect unrelated actor contact")
	var contacts_before: int = app.policy._queue.size()
	app._boss_contact._physics_process(0.0)
	check(app.policy._queue.size() == contacts_before, "actual own-body contact emitter adds no request while hook protection is active")
	# A disclosed real projectile fixture exercises physical overlap, production
	# BossProjectile hit emission, actual App routing and original FramePolicy.
	var hp: float = app.controller.actor_resources.health.current
	var projectile := BossProjectile.new()
	app.stage.add_child(projectile)
	projectile.configure(encounter.definition,&"weapon_routes/physical_projectile",Vector2.RIGHT,app.player,app.stage.boss)
	app._boss_projectile_created(projectile)
	check(not traversal.protects_contact(projectile), "real hook does not blanket-protect the Boss projectile source")
	projectile.global_position = app.player.global_position
	projectile.set_physics_process(false)
	projectile.advance_frozen_contact()
	check(app.policy._queue.size() == contacts_before+1, "physical BossProjectile enters actual App policy during real hook protection")
	var other := DemoContactEmitter.new()
	other.policy = app.policy
	other.controller = app.controller
	other.source_id = &"weapon_routes/unrelated_contact"
	unrelated.add_child(other)
	# Both sources are sampled before the same original policy batch. Resolving
	# one first would legitimately give the other a monster iframe, confounding
	# contact admission with ordinary post-hit protection.
	var queue_before: int = app.policy._queue.size()
	other._physics_process(0.0)
	check(app.policy._queue.size() == queue_before+1, "actual unrelated overlapping contact emitter remains eligible during hook protection")
	var results: Array[DamageResult] = app.policy.resolve_batch()
	var projectile_committed := false
	for result: DamageResult in results:
		if result.request.source_id == &"boss_projectile" and result.hp_lost > 0.0: projectile_committed = true
	check(projectile_committed and app.controller.actor_resources.health.current < hp, "physical BossProjectile commits player damage through actual App during real hook protection")
	unrelated.queue_free()
	observations.append({"route":"disclosed physical projectile/contact fixtures during genuine hook","own_body_rect":encounter.body_contact_rect(),"player_position":app.player.global_position,"HP_before":hp,"HP_after":app.controller.actor_resources.health.current,"own_body_overlap_not_required":"this proves emitter suppression at current hook pose; does not claim an unprotected body collision occurred"})

func weapon_route(identity: StringName) -> void:
	var weapon := load("res://resources/weapons/%s.tres" % identity) as WeaponDefinition
	check(weapon != null and app.controller.shoot_ability.equip(weapon), "SETUP real disclosed loadout "+String(identity))
	if weapon == null: return
	var point: Vector2 = encounter._core.global_position
	position_fixture(point+Vector2(-85 if identity == &"recoil_bomb" else -150,0),"airborne real weapon "+String(identity))
	var direction: Vector2 = (point-app.player.global_position).normalized()
	var hp := encounter.health.current
	var blasts: Array[Vector2] = []
	var transitions: Array[Dictionary] = []
	var behavior: WeaponActionRuntime = app.controller.shoot_ability.behavior()
	behavior.blast_fired.connect(func(at: Vector2) -> void: blasts.append(at))
	behavior.entity_transition.connect(func(entity: WeaponEntity, action: StringName) -> void:
		transitions.append({"kind":String(entity.kind),"action":String(action),"packet":entity.packet}))
	paused = false
	app.controller.router.aim_direction = direction
	app.controller.router.request_action(&"shoot_release",direction)
	var actual_entity := false
	for index: int in 90:
		await ticks(1)
		for entity: WeaponEntity in behavior.current_entities():
			if entity.kind == &"boomerang" and entity.packet == app.controller.shoot_ability.packet_id: actual_entity = true
		if not contexts.is_empty(): break
	paused = true
	check(not packet_events.is_empty(), "real Router reserves packet via original ShootAbility for "+String(identity))
	var admitted := false
	for event: Dictionary in packet_events:
		if event.reason == &"started" and int(event.admitted) == int(event.actor_epoch): admitted = true
	check(admitted, "actual Bell-only started-packet hook admits original reserve_packet for "+String(identity))
	check(encounter.health.current < hp and not contexts.is_empty(), "actual physical "+String(identity)+" reaches main bell and commits HP")
	if identity == &"recoil_bomb":
		check(blasts.size() == 1, "actual Lv1 bomb executes one real AoE burst")
		check(is_equal_approx(hp-encounter.health.current,weapon.damage), "actual AoE pays configured damage once despite body and bell sharing Health")
	else:
		check(actual_entity, "actual live WeaponEntity boomerang spawned and travelled before its accepted collision")
	if not contexts.is_empty():
		var context: Dictionary = contexts[-1]
		check(context.damage_type == &"weapon" and int(context.shot_id) == app.controller.shoot_ability.packet_id, "actual nonpulse runtime collision carries reserved shot_id into real App")
		var before := encounter.health.current
		check(not core.receive_damage(context), "exact committed nonpulse event cannot pay twice")
		check(not body.receive_damage(context), "actual nonpulse collision context cannot authorize armour")
		var unissued := context.duplicate()
		unissued.event_id = "weapon_routes/unissued_nonpulse"
		unissued.shot_id = 2147480001
		check(not core.receive_damage(unissued), "actual nonpulse context with unissued packet cannot enter App sink")
		app.policy.resolve_batch()
		check(encounter.health.current == before, "duplicate/armour probes preserve committed HP")
	observations.append({"route":"Router "+String(identity),"HP_before":hp,"HP_after":encounter.health.current,"blasts":blasts,"actual_live_entity":actual_entity,"transitions":transitions,"packet_events":packet_events.duplicate(true),"sink":sink_receipts.duplicate(true),"committed":contexts.duplicate(true)})

func run() -> void:
	if await setup(): await grapple_route(true)
	if await setup(): await grapple_route(false)
	if await setup(): await weapon_route(&"recoil_bomb")
	if await setup(): await weapon_route(&"remote_boomerang")
	await cleanup()
	DirAccess.make_dir_recursive_absolute("res://build/bellstrider_rework_01")
	var report := {"checks":assertions,"failures":failures,"observations":observations,"fixture_positions":fixture_positions,"scope":"actual formal App controlled fixtures: explicit capability/loadout and airborne positioning; positive Router hook, bomb AoE and physical WeaponEntity; explicit negative context mutation; disclosed BossProjectile and unrelated contact fixtures; synchronous live protection sample before pause, and explicit policy flushes. Player damage then pause cancel the real hook; post-pause diagnostics do not isolate pause as the cause. No Boss HP/state/clock or admission injection. Not a natural battle.","uncovered":["all15 weapon paths and Lv3 skills","natural boss-emitted projectile during hook","unprotected owned-body collision at identical hook pose","full battle/two-shot/third-shot rhythm","visual/audio/device/user acceptance"],"test_author":"root/boss_motion; requires independent review and root engine lease"}
	var file := FileAccess.open("res://build/bellstrider_rework_01/weapon-routes.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("BELLSTRIDER WEAPON ROUTES: %s checks, %s failures" % [assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
