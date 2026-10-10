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
	check(app.start_plains("plains-ten-integration"), "actual Plains entry starts")
	await frames(5)
	var seeds: Dictionary = {}
	for index: int in range(1, 11):
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
			defeat(app, &"drone", stage.enemy.get_node("Actor").health)
			await frames(2)
		elif kind == &"boss":
			check(index == 10 and app.director.offers.is_empty(), "Boss10 no bypass")
			var encounter := stage.boss.get_node("Encounter") as BossEncounter
			check(not encounter.active and not app._boss_contact.enabled, "generated Boss dormant while player in random entrance")
			var health_before := encounter.health.current
			defeat(app, &"boss", encounter.health)
			await frames(2)
			check(encounter.health.current == health_before and app.current_reward == null and not app.director.stage_complete, "unentered Boss rejects direct damage and cannot award gold")
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
			app.claim_item(app.current_reward.candidates[0].stable_id)
			await frames(4)
			check(app.director.state == DemoRunDirector.State.HOME and app.meta.snapshot().completed_biomes == 1, "gold completes biome and returnsHome")
			break
		elif kind == &"item_reward":
			locate(app, stage.reward_position)
			app.claim_item(app.current_reward.candidates[0].stable_id)
			await frames(2)
		elif kind == &"health_reward":
			locate(app, stage.reward_position)
			app.claim_room_reward()
			await frames(2)
		elif kind == &"coin_reward":
			check(stage.pickups.filter(func(p: Dictionary) -> bool: return p.kind == "coin").size() > 10, "coin room scattered coins")
			for pickup_index: int in stage.pickups.size():
				if stage.pickups[pickup_index].kind == "coin":
					locate(app, stage.pickups[pickup_index].position)
					app._queue_action(app._commit_pickup.bind(pickup_index))
					await frames(2)
					break
		locate(app, stage.exit_positions[0])
		await frames(2)
		check(app.director.stage_complete, "dynamic completion meets own policy")
		var offers := app.director.offers
		check(stage.nearby_exit(stage.exit_positions[0]) == 0 and stage.nearby_exit(stage.exit_positions[1]) == 1, "both generated exits independently selectable")
		if index == 9:
			check(offers[0].next_stage_type_id == &"boss" and offers[1].next_stage_type_id == &"boss", "ninth exits Boss required")
		var choice := index % 2
		locate(app, stage.exit_positions[choice])
		app.choose_exit(offers[choice].exit_id)
		app.choose_exit(offers[choice].exit_id)
		await frames(5)
		check(app.director.stage_index == index + 1 and app.director.stage_type_id == offers[choice].next_stage_type_id, "duplicate queued exit advances exactly once")
	check(seeds.size() == 10, "ten independently generated stages consumed")
	var recorded := app.director.manifest.snapshot()
	check(RunManifest.from_snapshot(recorded) != null and recorded.versions.generated_layout == "plains-run-v1", "generated manifest versions replay-compatible")
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
	app.free()
	print("PLAINS TEN APP: %s assertions / %s failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
