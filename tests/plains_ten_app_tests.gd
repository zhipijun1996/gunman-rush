extends SceneTree
## Scene integration fixture: positions/damage injected; generation traversal has separate Motor tests.
var assertions := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, text: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(text)
func frames(count: int) -> void:
	for unused: int in count:
		await physics_frame
func locate(app: DemoApp, point: Vector2) -> void:
	app.lifetime.invalidate_actor()
	app.player.reset_at(point)
func defeat(app: DemoApp, id: StringName, health: HealthState) -> void:
	var damage := DamageRequest.new()
	damage.token = app.lifetime.token()
	damage.event_id = StringName("fixture_%s_%s" % [id, app.director.stage_index])
	damage.source_id = &"integration_fixture"
	damage.target_id = id
	damage.amount = health.capacity
	damage.health_epoch = health.epoch
	damage.actor_epoch = app.lifetime.actor_epoch
	app.policy.submit(damage)
func _run() -> void:
	var app := preload("res://scenes/demo/demo.tscn").instantiate() as DemoApp
	app.meta_persistence_enabled = false
	root.add_child(app)
	await frames(2)
	app.meta = MetaProgression.new()
	var started := app.start_plains("plains-ten-integration")
	check(started, "actual Plains entry starts")
	if not started:
		app.free()
		quit(1)
		return
	await frames(5)
	var seeds: Dictionary = {}
	for index: int in range(1, 9):
		check(app.director.stage_index == index and app.stage is GeneratedDemoStage, "actual stage index and generated consumer %s" % index)
		if not app.stage is GeneratedDemoStage:
			break
		var stage := app.stage as GeneratedDemoStage
		check(stage.assembly_ok and stage.assembler.modules.size() >= 8, "stage assembles its own modules")
		var map_seed: String = str(stage.generated.manifest.seed)
		check(not seeds.has(map_seed), "each stage independent seed")
		seeds[map_seed] = true
		check(app.director.manifest.snapshot().stages[index - 1].outputs.generated_layout == stage.generated.manifest, "actual generated output recorded")
		for pickup_index: int in stage.pickups.size():
			var pickup: Dictionary = stage.pickups[pickup_index]
			if pickup.kind == "note":
				locate(app, pickup.position)
				var before: int = app.meta.snapshot().notes
				app._queue_action(app._commit_pickup.bind(pickup_index))
				app._queue_action(app._commit_pickup.bind(pickup_index))
				await frames(2)
				check(pickup.claimed and app.meta.snapshot().notes == before + pickup.amount, "note claimed once behind batch commit")
				var manifest_before: Dictionary = stage.generated.manifest.duplicate(true)
				app._environment_return()
				check(pickup.claimed and stage.generated.manifest == manifest_before, "return preserves pickups and map")
				break
		var kind := app.director.stage_type_id
		if kind == &"combat":
			check(stage.enemies.size() >= 1 and stage.enemies.size() <= (1 if index <= 3 else (2 if index <= 6 else 3)), "combat actual safe enemy count matches pressure budget")
			for enemy_index: int in stage.enemies.size():
				var enemy_actor := stage.enemies[enemy_index].get_node("Actor") as EnemyActor
				defeat(app, StringName("drone" if enemy_index == 0 else "drone_%s" % enemy_index), enemy_actor.health)
				if enemy_index < stage.enemies.size() - 1:
					await frames(2)
					check(app.director.stage_complete, "living ordinary enemies never lock exits; defeat remains optional index=%s" % index)
			await frames(2)
		elif kind == &"boss":
			check(index == 8 and app.director.offers.is_empty(), "Boss8 no bypass")
			var encounter := stage.boss.get_node("Encounter") as BossEncounter
			check(not encounter.active and not app._boss_contact.enabled, "generated Boss dormant while player in random entrance")
			var health_before := encounter.health.current
			defeat(app, &"boss", encounter.health)
			await frames(2)
			check(encounter.health.current == health_before and app.current_reward == null and not app.director.stage_complete, "unentered Boss rejects direct damage and cannot award gold: hp=%s before=%s complete=%s reward=%s rule=%s" % [encounter.health.current, health_before, app.director.stage_complete, app.current_reward, app._completion_rule.goal])
			locate(app, Vector2(stage.boss_arena.position.x + 70, stage.boss_arena.end.y - 18))
			await frames(2)
			check(encounter.active and app._boss_started and app._boss_contact.enabled, "entering actual core activates Boss and contact")
			var receiver := stage.boss.get_node("Damageable") as Damageable
			var context := {"event_id": "unarmed_boss_shot", "amount": 1.0, "source_faction": &"player", "target_actor_id": receiver.actor_id, "target_epoch": receiver.damage_epoch, "session_id": app.controller.session_id, "shot_id": -7}
			check(not receiver.receive_damage(context) and encounter.health.current == health_before, "projectile fired without active-core qualification cannot damage Boss")
			app._record_boss_shot(Vector2.RIGHT, -7)
			check(receiver.receive_damage(context), "core-qualified projectile reaches real frame damage policy")
			await frames(2)
			check(encounter.health.current == health_before - 1, "qualified projectile commits exactly one damage")
			locate(app, stage.spawn)
			await frames(2)
			check(encounter.active and not app._boss_contact.enabled and app._boss_eligible_shots.is_empty(), "retreat keeps Boss state but disables contacts and cancels old-shot eligibility")
			context.event_id = "buffer_boss_shot"
			check(not receiver.receive_damage(context), "buffer shots cannot farm Boss health")
			locate(app, Vector2(stage.boss_arena.position.x + 70, stage.boss_arena.end.y - 18))
			await frames(2)
			defeat(app, &"boss", encounter.health)
			await frames(2)
			check(app.current_reward != null and app.current_reward.gold, "Boss gold guaranteed")
			locate(app, stage.reward_position)
			await frames(2)
			check(app.exit_modal.opened and paused, "Boss contact previews reward before consent")
			app._confirm_generated_exit()
			await frames(2)
			check(app.reward_modal.opened and paused, "Boss confirmation opens paused guaranteed-gold modal")
			if app.current_reward == null:
				app.free()
				quit(1)
				return
			var gold_id := app.current_reward.candidates[0].stable_id
			check(app._claim_modal_item(gold_id), "gold modal grants once")
			check(not app._claim_modal_item(gold_id), "closed gold modal rejects duplicate")
			await frames(4)
			check(app.director.state == DemoRunDirector.State.HOME and app.meta.snapshot().completed_biomes == 1, "gold completes biome and returnsHome")
			break
		elif kind == &"item_reward":
			locate(app, stage.spawn)
			check(not app._commit_claim(app.current_reward.candidates[0].stable_id), "pre-exit marker cannot award an item")
			await frames(2)
			check(not app.rewards.get_offer(app.current_reward.offer_id).claimed, "item remains unclaimed before exit")
		elif kind == &"health_reward":
			locate(app, stage.spawn)
			app.claim_room_reward()
			await frames(2)
			check(not app.simple_reward.claimed, "health reward remains unclaimed before exit")
		elif kind == &"coin_reward":
			check(stage.pickups.filter(func(p: Dictionary) -> bool: return p.kind == "coin").size() > 10, "coin room scattered coins")
			for pickup_index: int in stage.pickups.size():
				if stage.pickups[pickup_index].kind == "coin":
					locate(app, stage.pickups[pickup_index].position)
					app._queue_action(app._commit_pickup.bind(pickup_index))
					await frames(2)
					break
		var offers := app.director.offers
		check(stage.nearby_exit(stage.exit_positions[0]) == 0 and stage.nearby_exit(stage.exit_positions[1]) == 1, "both generated exits independently selectable")
		check(stage.exit_positions[0].distance_to(stage.exit_positions[1]) > 190, "formal exits are physically separated")
		if index == 7:
			check(offers[0].next_stage_type_id == &"boss" and offers[1].next_stage_type_id == &"boss", "seventh exits Boss required")
		var choice := index % 2
		locate(app, stage.exit_positions[choice])
		await frames(2)
		check(app.exit_modal.opened and app.director.stage_index == index, "exit proximity previews without advancing")
		app._confirm_generated_exit()
		await frames(2)
		if kind == &"item_reward":
			check(app.reward_modal.opened and paused and app.director.stage_index == index, "exit contact opens item modal before transition")
			check(app._pending_exit == offers[choice].exit_id, "contact locks chosen route during choice")
			var selected := app.current_reward.candidates[0].stable_id
			var rejected := app.current_reward.candidates[1].stable_id
			check(app._claim_modal_item(selected), "modal applies selected item")
			check(not app._claim_modal_item(rejected), "other candidate cannot also be claimed")
		await frames(5)
		check(app.director.stage_index == index + 1 and app.director.stage_type_id == offers[choice].next_stage_type_id, "duplicate queued exit advances exactly once")
	check(seeds.size() == 8, "eight independently generated stages consumed")
	var recorded := app.director.manifest.snapshot()
	check(RunManifest.from_snapshot(recorded) != null and recorded.versions.generated_layout == PlainsStageGenerator.VERSION, "generated manifest versions replay-compatible")
	var old_version := recorded.duplicate(true)
	old_version.versions.generated_layout = "plains-run-v3-eight-spatial"
	check(RunManifest.from_snapshot(old_version) == null, "old spatial generator header cannot masquerade as the current branch manifest")
	check(RunManifest.from_snapshot(JSON.parse_string(JSON.stringify(recorded))) != null, "serialized JSON with numeric floats and typed jump array replays")
	var tampered := recorded.duplicate(true)
	tampered.stages[0].outputs.generated_layout.nodes[0].offset[0] += 20
	check(RunManifest.from_snapshot(tampered) == null, "outer RunManifest rejects altered actual nested geometry")
	app.meta.grant_notes(50, &"fixture_note_bank")
	var before_upgrade: int = app.meta.snapshot().notes
	app._purchase_meta_upgrade()
	check(app.meta.snapshot().notes < before_upgrade and app.meta.snapshot().upgrades.vitality == 1, "Home button consumer purchases permanent upgrade")
	check(app.start_plains("plains-ten-integration"), "same seed new run begins")
	await frames(5)
	check(app.controller.actor_resources.health.capacity == 6, "permanent vitality applies to fresh health before Build capture")
	var initial: Dictionary = app.director.manifest.snapshot().initial_character
	check(initial.current_health == 6 and initial.maximum_health == 6 and initial.permanent_upgrades.vitality == 1 and initial.meta_content_version == 1 and app.director.manifest.snapshot().config_hashes.meta_upgrades == FileAccess.get_sha256("res://config/meta_upgrades.json"), "actual initial HP permanent upgrades and meta content hash/version are recorded")
	var fresh := app.stage as GeneratedDemoStage
	# Permanent HP does not change movement, so its recorded geometry stays identical.
	check(fresh.generated.manifest == recorded.stages[0].outputs.generated_layout, "same seed and movement reproduce recorded first map")
	var note_index := -1
	for index: int in fresh.pickups.size():
		if fresh.pickups[index].kind == "note":
			note_index = index
			break
	check(note_index >= 0, "fresh map includes independent permanent note")
	if note_index >= 0:
		await frames(40) # Actual spawn protection must elapse before this lethal-damage fixture.
		locate(app, fresh.pickups[note_index].position)
		var bank_before: int = app.meta.snapshot().notes
		app._queue_action(app._commit_pickup.bind(note_index))
		defeat(app, &"player", app.controller.actor_resources.health)
		await frames(5)
		check(app.director.state == DemoRunDirector.State.HOME and app.meta.snapshot().notes == bank_before, "same-frame fatal damage cancels queued note grant")
	check(app.meta.snapshot().upgrades.vitality == 1, "death preserves permanent upgrade")
	# Reach a completed combat exit in the same batch as fatal player damage.
	check(app.start_plains("plains-exit-death-priority"), "fresh exit death-priority run starts")
	await frames(5)
	await frames(40)
	var fatal_stage := app.stage as GeneratedDemoStage
	defeat(app, &"drone", fatal_stage.enemy.get_node("Actor").health)
	await frames(2)
	check(app.director.stage_complete, "combat completed before exit death race")
	locate(app, fatal_stage.exit_positions[0])
	app.choose_exit(fatal_stage.exits[0].exit_id)
	defeat(app, &"player", app.controller.actor_resources.health)
	await frames(5)
	check(app.director.state == DemoRunDirector.State.HOME, "fatal batch wins over contact and queued exit")
	check(not app.reward_modal.opened and app.meta.snapshot().failed_runs == 2, "death cancels modal and no success settlement")
	# Explicit late-room pressure fixture, independent of the sampled route choices.
	var late_data := PlainsStageGenerator.new().generate("plains-pressure-fixture", 7, &"combat", PlayerTuning.load_default())
	check(late_data.ok, "late combat map generated for enemy placement")
	var late_stage := GeneratedDemoStage.new()
	late_stage.configure(7, &"combat", [])
	late_stage.configure_generated(late_data, PlayerTuning.load_default())
	root.add_child(late_stage)
	await frames(2)
	check(late_stage.enemies.size() == 3 and late_stage.enemy_manifest.size() == 3, "late combat distributes three real enemies")
	check(not late_stage.combat_completed(), "enemy-clear query still reports living enemies separately from open-access exit policy")
	var distinct_modules: Dictionary = {}
	for data: Dictionary in late_stage.enemy_manifest:
		distinct_modules[data.module_index] = true
	check(distinct_modules.size() == 3, "three enemies occupy different route modules")
	var ids_before := late_stage.enemies.map(func(drone: EnemyMotor): return drone.get_instance_id())
	late_stage.set_completed(false)
	check(late_stage.enemies.map(func(drone: EnemyMotor): return drone.get_instance_id()) == ids_before, "presentation/completion update cannot respawn enemies")
	late_stage.free()
	app.free()
	print("PLAINS TEN APP: %s assertions / %s failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
