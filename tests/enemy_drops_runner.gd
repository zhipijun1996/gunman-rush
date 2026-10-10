extends SceneTree
## Scene fixtures inject positions/HP; they prove settlement, not manual traversal.
var assertions := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for _index: int in count:
		await physics_frame
func damage(app: DemoApp, id: StringName, health: HealthState, event: StringName) -> void:
	var request := DamageRequest.new()
	request.token = app.lifetime.token()
	request.event_id = event
	request.source_id = &"drop_fixture"
	request.target_id = id
	request.amount = health.capacity
	request.health_epoch = health.epoch
	request.actor_epoch = app.lifetime.actor_epoch
	check(app.policy.submit(request), "Real frame policy accepts fixture damage")
func _run() -> void:
	var a := EnemyDropService.new()
	var b := EnemyDropService.new()
	check(a.configure("drop-seed", "stage_1") and b.configure("drop-seed", "stage_1"), "Valid demo config")
	check(a.configuration.weights.coin > a.configuration.weights.note and a.configuration.weights.note > a.configuration.weights.heart, "Demo coin > note > heart weights")
	var first := a.settle(&"a")
	var second := a.settle(&"b")
	check(b.settle(&"b") == second and b.settle(&"a") == first, "Enemy streams reproduce independent of kill order")
	check(a.settle(&"a").is_empty(), "One enemy settles once")
	var counts := {"coin": 0, "note": 0, "heart": 0, "none": 0}
	for index: int in 1000:
		var output := a.settle(StringName("sample_%s" % index))
		check(output.stream_position == 1 and output.content_version == EnemyDropService.CONTENT_VERSION, "Versioned stream output")
		counts[output.kind] += 1
	check(counts.coin > counts.note and counts.note > counts.heart and counts.none > 0, "Deterministic 1000 sample frequency ordering with optional empty drop")
	for invalid: Dictionary in [{}, {"version": 1, "weights": {"coin": -1}, "amounts": {}}, {"version": 1, "weights": {"coin": 1, "note": 0, "heart": 0, "none": 0}, "amounts": {"coin": 0, "note": 1, "heart": 1}}]:
		check(not EnemyDropService.valid_configuration(invalid), "Reject malformed/drop amount configuration")
	for kind: String in ["coin", "note", "heart", "none"]:
		var config := a.configuration.duplicate(true)
		for key: String in config.weights:
			config.weights[key] = 1 if key == kind else 0
		var forced := EnemyDropService.new()
		check(forced.configure("forced", "stage_1", config) and forced.settle(&"enemy").kind == kind, "Each configurable outcome supported")
	var app := preload("res://scenes/demo/demo.tscn").instantiate() as DemoApp
	app.meta_persistence_enabled = false
	root.add_child(app)
	await frames(2)
	check(app.start_plains("enemy-drop-contact-fixture"), "Start real generated room")
	await frames(6)
	var stage := app.stage as GeneratedDemoStage
	check(app.director.stage_complete and not stage.enemy.get_node("Actor").health.terminal, "Exit available while enemy alive")
	var initial_pickups := stage.pickups.size()
	var config := a.configuration.duplicate(true)
	config.weights = {"coin": 0, "note": 0, "heart": 1, "none": 0}
	check(app._enemy_drops.configure(app.director.seed, "stage_1", config), "Force heart for deterministic contact fixture")
	damage(app, &"drone", stage.enemy.get_node("Actor").health, &"kill_heart")
	app.policy.resolve_batch()
	check(stage.pickups.size() == initial_pickups + 1, "Killed enemy creates one physical heart pickup")
	var drop: Dictionary = stage.pickups.back()
	check(drop.kind == "heart" and drop.id == "drop_drone", "Stable heart id and type")
	app.policy.resolve_batch()
	check(stage.pickups.size() == initial_pickups + 1, "Repeated batch cannot repeat kill loot")
	var output: Dictionary = app.director.manifest.snapshot().stages[0].outputs.enemy_drop_drone
	check(output.kind == "heart" and output.stream_position == 1 and output.position == [drop.position.x, drop.position.y], "Manifest records actual outcome and pickup position")
	app.player.reset_at(drop.position)
	await frames(3)
	check(not drop.claimed, "Full-health heart stays available")
	var health := app.controller.actor_resources.health
	var before := health.capacity - 2
	health.apply_damage(ActorResourceRequest.new(&"heart_fixture_loss", health.epoch, 2, health.get_instance_id()))
	app.player.reset_at(drop.position)
	await frames(3)
	check(drop.claimed and health.current == before + 1, "Contact heals current health without interaction")
	var hp := health.current
	await frames(3)
	check(health.current == hp, "Claimed contact heart heals once")
	app._environment_return()
	check(drop.claimed and stage.pickups.size() == initial_pickups + 1, "Segment return retains killed enemy and claimed loot")
	app.abandon_run()
	await frames(3)
	check(app.start_plains("enemy-drop-fatal-fixture"), "Start same-frame fatal test")
	await frames(6)
	await frames(40)
	var old_stage := app.stage as GeneratedDemoStage
	var old_service := app._enemy_drops
	damage(app, &"drone", old_stage.enemy.get_node("Actor").health, &"fatal_enemy")
	damage(app, &"player", app.controller.actor_resources.health, &"fatal_player")
	app.policy.resolve_batch()
	check(not app.lifetime.active and app.controller.actor_resources.health.terminal, "Player death wins same-frame enemy kill immediately")
	check(not old_service._settled.has(&"drone"), "Fatal batch never settles delayed enemy reward")
	await frames(4)
	check(app.director.state == DemoRunDirector.State.HOME, "Fatal batch returns to Home after deferred cleanup")
	app.free()
	# Aerial authored placement is checked against the assembled collision world.
	var data := PlainsStageGenerator.new().generate("aerial-fixture", 7, &"combat", PlayerTuning.load_default())
	check(data.ok, "Late generated combat fixture")
	var late := GeneratedDemoStage.new()
	late.configure(7, &"combat", [])
	late.configure_generated(data, PlayerTuning.load_default())
	root.add_child(late)
	await frames(2)
	var airborne := 0
	for index: int in late.enemies.size():
		var actor := late.enemies[index].get_node("Actor") as EnemyActor
		check(actor.definition.aerial == late.enemy_manifest[index].aerial, "Typed aerial definition recorded in enemy manifest")
		if actor.definition.aerial:
			airborne += 1
			var position_now: Vector2 = late.enemy_manifest[index].position[0] * Vector2.RIGHT + late.enemy_manifest[index].position[1] * Vector2.DOWN
			var volume := Rect2(position_now - Vector2(actor.definition.patrol_half_width + 20, 30), Vector2(actor.definition.patrol_half_width * 2 + 40, 54))
			for danger: Rect2 in late.assembler.world_dangers():
				check(not volume.intersects(danger.grow(12)), "Air patrol envelope avoids hazards")
	check(airborne > 0, "Late room contains actual aerial patrol")
	late.free()
	if "--verify-failure" in OS.get_cmdline_user_args():
		check(false, "Intentional failure probe")
	print("ENEMY DROPS: %s assertions, %s failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
