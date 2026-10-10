extends SceneTree
var assertions := 0
var failures := 0
var motor_coverage := {false: 0, true: 0}
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	for kind: StringName in [&"combat", &"coin_reward", &"item_reward", &"shop", &"health_reward"]:
		for index: int in [1, 4, 7]:
			for seed_id: int in 3:
				var data := PlainsStageGenerator.new().generate("density_%s" % seed_id, index, kind, PlayerTuning.load_default())
				check(data.ok, "generated density fixture")
				if not data.ok: continue
				var stage := GeneratedDemoStage.new()
				stage.configure(index, kind, [])
				stage.configure_generated(data, PlayerTuning.load_default())
				root.add_child(stage)
				var plan := stage.encounter_plan
				check(plan == PlainsEncounterPlanner.plan(stage), "independent encounter plan reproduces exactly")
				check(plan.enemies.size() == stage.enemies.size(), "all recorded actors instantiated")
				check(plan.enemies.size() <= plan.requested_count, "budget bounded")
				for actor: Dictionary in plan.enemies:
					var point := Vector2(actor.position[0], actor.position[1])
					var floor_point := point + Vector2(0, plan.config.aerial_elevation if actor.aerial else 0)
					check(PlainsEncounterPlanner.unsafe_reason(stage, PlainsEncounterPlanner.envelope(point, actor.patrol_radius), floor_point, actor.aerial, plan.config).is_empty(), "full patrol envelope safe")
				if kind in [&"shop", &"health_reward"]: check(stage.enemies.is_empty(), "service rooms stay peaceful")
				print("DENSITY %s stage%s seed%s requested%s actual%s routes%s" % [kind, index, seed_id, plan.requested_count, stage.enemies.size(), plan.routes])
				if kind == &"combat": print("REJECTS %s" % plan.rejections)
				stage.free()
	await integration()
	check(motor_coverage[false] > 0 and motor_coverage[true] > 0, "actual guarded passage covers ground and aerial variants")
	print("PLAINS ENCOUNTER DENSITY: %s assertions, %s failures" % [assertions, failures])
	quit(1 if failures else 0)

func frames(count: int) -> void:
	for frame: int in count: await physics_frame

func integration() -> void:
	for kind: StringName in [&"coin_reward", &"item_reward"]:
		var app := preload("res://scenes/demo/demo.tscn").instantiate() as DemoApp
		app.meta_persistence_enabled = false
		root.add_child(app)
		await frames(2)
		var fixture_seed := passage_seed(kind)
		check(not fixture_seed.is_empty() and app.start_plains(fixture_seed), "start real app with independently selected ground/aerial coverage seed")
		await frames(6)
		app.lifetime.stage_epoch += 1
		app.lifetime.invalidate_actor()
		app.director._enter_stage(2, kind)
		app._load_stage()
		await frames(6)
		var stage := app.stage as GeneratedDemoStage
		check(stage.enemies.size() >= 1, "reward room contains guards")
		check(app._enemy_contacts.size() == stage.enemies.size(), "all reward guards get actual contact emitters")
		check(app.director.stage_complete, "living guards do not lock nonboss exit")
		var snapshot := app.director.manifest.snapshot()
		check(RunManifest.compatible(snapshot), "complete encounter plan survives manifest validation")
		var altered := snapshot.duplicate(true)
		altered.stages[1].outputs.enemy_layout.requested_count += 1
		check(not RunManifest.compatible(altered), "altered encounter budget rejected on replay")
		for data: Dictionary in stage.enemy_manifest:
			check(app.policy._targets.has(StringName(data.id)), "every enemy uses formal health policy")
		await patrol_passage(app, stage, false)
		await patrol_passage(app, stage, true)
		var target := stage.enemies[0]
		var actor := target.get_node("Actor") as EnemyActor
		var original_health := actor.health.current
		# Position fixture isolates actual release -> projectile -> formal damage;
		# it is not a claim of traversing the whole generated level.
		app.lifetime.invalidate_actor()
		app.player.reset_at(target.global_position - Vector2(55, 0))
		app.controller.router.request_action(&"shoot_release", Vector2.RIGHT)
		await frames(6)
		check(actor.health.current < original_health, "real released shot damages reward guard through formal batch")
		var recorded_health := actor.health.current
		var actor_id := target.get_instance_id()
		var plan_before := stage.encounter_plan.duplicate(true)
		app._environment_return()
		check(target.get_instance_id() == actor_id and actor.health.current == recorded_health and stage.encounter_plan == plan_before, "segment return preserves guard health and exact plan")
		var stale_shots := app.controller.shoot_ability.get_projectiles().size()
		check(stale_shots == 0, "segment return cancels old actor projectiles")
		app.lifetime.invalidate_actor()
		app.player.reset_at(stage.exit_positions[0])
		app.controller.motor.reset_motion()
		check(app.choose_exit(stage.exits[0].exit_id), "reward room exit remains usable with living guards")
		await frames(2)
		check(app.exit_modal.opened, "actual exit confirmation opens without clearing guards")
		app.abandon_run()
		await frames(3)
		app.free()

func patrol_passage(app: DemoApp, stage: GeneratedDemoStage, aerial: bool) -> void:
	var selected := -1
	for index: int in stage.enemy_manifest.size():
		var data: Dictionary = stage.enemy_manifest[index]
		if stage.assembler.modules[int(data.module_index)].definition.module_id == &"plains_patrol_meadow" and int(data.route) > 0 and bool(data.aerial) == aerial:
			selected = index
			break
	if selected < 0:
		print("ENCOUNTER MOTOR: no %s branch guard in this fixture" % ("aerial" if aerial else "ground"))
		return
	motor_coverage[aerial] += 1
	var data: Dictionary = stage.enemy_manifest[selected]
	var module: PlatformingModule = stage.assembler.modules[int(data.module_index)]
	var target := stage.enemies[selected]
	var direction := signf(module.world_exit().x - module.world_entry().x)
	app.lifetime.invalidate_actor()
	app.controller.router.clear("density_fixture_entry")
	app.player.reset_at(module.world_entry())
	await frames(3)
	var hp := app.controller.actor_resources.health.current
	var jump_sent := false
	var passed := false
	for tick: int in 180:
		app.controller.router.set_move_axis(direction)
		var distance := (target.global_position.x - app.player.global_position.x) * direction
		if not data.aerial and not jump_sent and distance < 80 and app.player.is_on_floor():
			app.controller.router.request_action(&"jump")
			jump_sent = true
		await frames(1)
		if (module.world_exit().x - app.player.global_position.x) * direction < 8:
			passed = true
			break
	app.controller.router.set_move_axis(0)
	print("ENCOUNTER MOTOR: type=%s aerial=%s direction=%s passed=%s hp=%s" % [stage.stage_type, data.aerial, direction, passed, app.controller.actor_resources.health.current])
	check(passed, "real Motor crosses guarded meadow from actual entry to exit")
	check(app.controller.actor_resources.health.current == hp, "ground-jump or aerial-underpass avoids live formal enemy contact without damage")
	check(not (target.get_node("Actor") as EnemyActor).health.terminal, "actual traversal bypasses living guard without required kill")

func passage_seed(kind: StringName) -> String:
	for index: int in 32:
		var candidate := "density-passage-%s" % index
		var generated := PlainsStageGenerator.new().generate(candidate, 2, kind, PlayerTuning.load_default())
		if not generated.ok: continue
		var variants: Dictionary = {}
		for data: Dictionary in generated.encounter_plan.enemies:
			if int(data.route) > 0 and generated.manifest.nodes[int(data.module_index)].module_id == "plains_patrol_meadow":
				variants[bool(data.aerial)] = true
		if variants.size() == 2: return candidate
	return ""
