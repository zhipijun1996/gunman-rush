extends RefCounted

func run(_tree: SceneTree, check: Callable) -> void:
	var formal := RunProfile.formal()
	var short := RunProfile.development()
	check.call(formal.is_valid(true) and formal.stages_per_biome == 10 and formal.boss_stage == 10, "formal run profile remains ten stages with boss ten")
	check.call(short.is_valid() and not short.is_valid(true), "three-stage fixture explicitly rejected by formal build validation")
	var invalid := RunProfile.formal()
	invalid.boss_stage = 9
	check.call(not invalid.is_valid(), "formal boss cannot be moved to stage nine")
	var definitions := StageTypeDefinition.registry()
	check.call(definitions.size() == 6, "six independent stage type definitions registered")
	for definition: StageTypeDefinition in definitions.values():
		check.call(definition.is_valid(), "stage definition has explicit completion rule and presentation identity")
	var health_definition := HealthDefinition.new()
	health_definition.resource_id = &"completion_fixture"
	health_definition.max_health = 2.0
	health_definition.initial_current = 2.0
	var health := HealthState.new()
	health.configure(health_definition)
	var combat_rule: StageCompletionRule = definitions[&"combat"].rule()
	check.call(not combat_rule.evaluate(Vector2(1100, 500), health, true) and not combat_rule.evaluate(Vector2.ZERO, null, false), "target defeat completion rejects alive and missing targets regardless of position")
	health.apply_damage(ActorResourceRequest.new(&"completion_kill", health.epoch, 2.0, health.get_instance_id()))
	check.call(combat_rule.evaluate(Vector2.ZERO, health, false), "target defeat completion consumes actual terminal HealthState")
	var shop_rule: StageCompletionRule = definitions[&"shop"].rule()
	check.call(shop_rule.evaluate(Vector2(981, 500), null, false) and not shop_rule.evaluate(Vector2(980, 500), null, true), "shop reach rule allows skipping purchases and respects finish threshold")
	var item_rule: StageCompletionRule = definitions[&"item_reward"].rule()
	check.call(not item_rule.evaluate(Vector2(1100, 500), null, false) and not item_rule.evaluate(Vector2(500, 500), null, true) and item_rule.evaluate(Vector2(1100, 500), null, true), "item completion requires both committed claim and reaching finish")
	var claim_rule: StageCompletionRule = definitions[&"health_reward"].rule()
	check.call(claim_rule.evaluate(Vector2.ZERO, null, true) and not claim_rule.evaluate(Vector2(1100, 500), null, false), "claim-only reward rule separated from spatial completion")
	check.call(not shop_rule.evaluate(Vector2(NAN, 0), null, true) and not shop_rule.evaluate(Vector2.ZERO, null, true, INF), "nonfinite completion inputs rejected")
	var custom := StageTypeDefinition.new()
	custom.type_id = &"event_custom"
	custom.display_name = "Event"
	custom.icon_id = &"event"
	custom.completion_component = StageCompletionRule.new()
	custom.completion_component.rule_id = &"event_claim"
	custom.completion_component.goal = StageCompletionRule.Goal.CLAIM
	check.call(custom.is_valid() and custom.rule().evaluate(Vector2.ZERO, null, true), "new stage type injects completion component without editing loader or registry switch")
	var detached_rule := custom.rule()
	detached_rule.goal = StageCompletionRule.Goal.REACH_FINISH
	check.call(custom.rule().goal == StageCompletionRule.Goal.CLAIM, "rule consumers cannot mutate shared stage definition")
	custom.completion_component = null
	custom.completion_rule = &"unknown_policy"
	check.call(not custom.is_valid(), "unknown completion identifier explicitly rejected")
	check.call(BiomeDefinition.new().is_valid(), "biome pool remains separate from stage type")
	var planner := RoutePlanner.new()
	var before_boss := planner.offers(formal, 9, "42", &"stage_9")
	check.call(before_boss.size() == 2 and before_boss[0].next_stage_index == 10 and before_boss[1].next_stage_type_id == &"boss" and before_boss[0].next_stage_type_id == &"boss", "both formal stage nine exits require stage ten boss")
	check.call(planner.offers(formal, 10, "42", &"stage_10").is_empty(), "boss stage has no ordinary bypass exit")
	var baseline := RunRandomStream.new("42", "map", "stage_1")
	var changed := RunRandomStream.new("42", "map", "stage_1")
	var reward := RunRandomStream.new("42", "reward", "stage_1")
	for index: int in 12:
		reward.next_int(100000)
	check.call(baseline.next_int(100000) == changed.next_int(100000), "extra reward draws cannot disturb map stream")
	var route_a := RunRandomStream.new("42", "route", "stage_1")
	var route_b := RunRandomStream.new("42", "route", "stage_1")
	var identical := true
	for index: int in 20:
		identical = identical and route_a.next_int(100000) == route_b.next_int(100000)
	check.call(identical, "stable SHA256 counter stream reproduces across independent instances")
	var director := DemoRunDirector.new()
	var entered: Array[DemoRunResult] = []
	var ended: Array[DemoRunResult] = []
	director.stage_entered.connect(func(result: DemoRunResult) -> void: entered.append(result))
	director.run_ended.connect(func(result: DemoRunResult) -> void: ended.append(result))
	check.call(director.start("42").accepted() and director.stage_index == 1 and director.stage_type_id == &"combat", "new run starts fixed first combat stage from home")
	var token := director.lifetime.token()
	var exits := director.offers
	check.call(exits.size() == 2 and exits[0].next_stage_type_id == &"shop" and exits[1].next_stage_type_id == &"item_reward", "development exits reveal two distinct next-stage types")
	var offer_id := exits[0].exit_id
	exits[0].next_stage_type_id = &"boss"
	check.call(director.offers[0].next_stage_type_id == &"shop", "UI cannot mutate director-owned exit offers")
	check.call(not director.select_exit(token, offer_id, &"premature").accepted(), "exit cannot switch before explicit stage completion")
	check.call(director.complete_stage(token), "valid current stage completion accepted")
	var transition := director.select_exit(token, offer_id, &"choose-shop")
	check.call(transition.accepted() and director.stage_index == 2 and director.stage_type_id == &"shop", "selection affects actual next-stage type and advances one stage")
	transition.stage_index = 999
	var replay := director.select_exit(token, offer_id, &"choose-shop")
	check.call(replay.status == DemoRunResult.Status.REPLAY and replay.stage_index == 2 and entered.size() == 2, "matching exit retry returns detached receipt and emits no second transition")
	check.call(director.select_exit(token, director.offers[1].exit_id, &"choose-shop").status == DemoRunResult.Status.CONFLICT, "same selection id cannot be repurposed for another exit")
	check.call(not director.select_exit(token, director.offers[1].exit_id, &"old-callback").accepted(), "uncommitted old-stage callback cannot advance new stage")
	var stage_two_token := director.lifetime.token()
	director.complete_stage(stage_two_token)
	director.select_exit(stage_two_token, director.offers[0].exit_id, &"choose-boss")
	check.call(director.stage_index == 3 and director.stage_type_id == &"boss" and director.offers.is_empty(), "short fixture stage three is mandatory boss without exits")
	var boss_token := director.lifetime.token()
	director.complete_stage(boss_token)
	check.call(not director.finish_success(boss_token, &"win", false).accepted(), "boss success cannot finish without committed gold reward receipt")
	check.call(director.finish_success(boss_token, &"win", true).accepted() and not director.lifetime.active, "committed gold permits terminal demo success and cancels old lifetime")
	check.call(director.finish_success(boss_token, &"win", true).status == DemoRunResult.Status.REPLAY and ended.size() == 1, "same success settlement cannot fire a second run-ended signal")
	check.call(not director.end_failure(&"late-death").accepted(), "terminal success cannot be replaced by a later death callback")
	var summary := director.manifest.snapshot()
	var meta := MetaProgression.new()
	check.call(meta.settle(&"win", true, summary) and meta.settle(&"win", true, summary) and meta.snapshot().completed_runs == 1 and meta.snapshot().meta_currency == 0, "home settlement idempotent and does not convert run money")
	check.call(not meta.settle(&"win", false, summary), "conflicting home settlement rejected")
	check.call(director.return_home() and director.start("42").accepted(), "terminal run returns to independent home and starts another run")
	check.call(director.manifest.snapshot().decisions.is_empty() and meta.snapshot().completed_runs == 1, "new run clears route facts while independent meta survives")
	var failure_token := director.lifetime.token()
	check.call(director.end_failure(&"dead").accepted(), "health-zero integration may immediately terminate run")
	check.call(not director.complete_stage(failure_token) and not director.select_exit(failure_token, director.offers[0].exit_id, &"after-death").accepted(), "death invalidates uncommitted stage and exit actions")
	check.call(director.end_failure(&"dead").status == DemoRunResult.Status.REPLAY, "same death receipt is idempotent")
	var first := replay_run("seed-with-large-integer-18446744073709551615")
	var second := replay_run("seed-with-large-integer-18446744073709551615")
	check.call(first.canonical_json() == second.canonical_json(), "same string seed, locked versions and decisions reproduce full manifest")
	check.call(RunManifest.compatible(first.snapshot()), "current manifest records supported schema and algorithms")
	var restored := RunManifest.from_snapshot(first.snapshot())
	check.call(restored != null and restored.canonical_json() == first.canonical_json(), "versioned manifest imports exact actual route and content rather than resampling")
	var wrong_boss := first.snapshot()
	wrong_boss.stages[2].type_id = "shop"
	check.call(not RunManifest.compatible(wrong_boss), "manifest cannot claim an ordinary final stage bypasses required boss")
	var unsupported := first.snapshot()
	unsupported.schema_version = 99
	check.call(not RunManifest.compatible(unsupported), "unknown manifest schema explicitly incompatible")
	var detached := first.snapshot()
	detached.stages.clear()
	check.call(first.snapshot().stages.size() == 3, "manifest snapshots detached from actual recorded content")
	check.call(not first.record_output(1, &"layout", {"id": "different"}), "conflicting immutable actual layout output cannot silently overwrite replay facts")

func replay_run(seed: String) -> RunManifest:
	var director := DemoRunDirector.new()
	director.start(seed)
	director.manifest.record_configuration(["fixed_demo_v1"], {"physics": "fixture_hash"}, {"character": "prototype"})
	for index: int in 2:
		director.manifest.record_output(index + 1, &"layout", {"id": "fixed_%s" % index, "stable_objects": ["floor", "enemy"]})
		var token := director.lifetime.token()
		director.complete_stage(token)
		director.select_exit(token, director.offers[0].exit_id, StringName("choice_%s" % index))
	director.manifest.record_output(3, &"boss", {"template": "clockwork_guardian", "gold": "fixture_gold"})
	var token := director.lifetime.token()
	director.complete_stage(token)
	director.finish_success(token, &"success", true)
	return director.manifest
