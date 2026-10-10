extends SceneTree
var assertions := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("BLUEPRINT SCHEDULE: " + message)
func _initialize() -> void:
	var counts := {"bridge_crossing": 0, "windmill_ascent": 0}
	for sample: int in 200:
		var seed := "rhythm-%d" % sample
		var previous := ""
		for index: int in range(1, 9):
			var type: StringName = &"boss" if index == 8 else &"combat"
			var plan := PlainsBlueprintSchedule.plan(seed, index, type)
			check(plan == PlainsBlueprintSchedule.plan(seed, index, type), "same seed/index reproduces schedule")
			check(plan.slot == index and plan.version == PlainsBlueprintSchedule.VERSION, "slot and algorithm version are recorded")
			if index < 8:
				check(plan.blueprint_id in PlainsBlueprintSchedule.BLUEPRINTS and plan.blueprint_id != previous, "consecutive action slots alternate actual blueprint requests")
				previous = plan.blueprint_id
				if index == 5: counts[plan.blueprint_id] += 1
			else:
				check(plan.blueprint_id == "fixed_boss_core", "Boss8 retains authored encounter")
			if index < 8:
				check(PlainsBlueprintSchedule.plan(seed, index, &"shop").blueprint_id == "sanctuary" and PlainsBlueprintSchedule.plan(seed, index, &"health_reward").phase == "respite", "service rooms interrupt pressure without consuming random draws")
	for id: String in counts:
		check(counts[id] >= 60 and counts[id] <= 140, "fixed stage across seeds has neither dominant nor vanishing blueprint")
	# Exercise actual consumer, including reduced-capability fallback metadata.
	for mode: String in ["default", "zero_actions"]:
		var tuning := PlayerTuning.load_default()
		if mode == "zero_actions":
			tuning.max_jumps = 0
			tuning.max_air_shots = 0
		for index: int in [1, 4, 5, 8]:
			var type: StringName = &"boss" if index == 8 else &"combat"
			var generated := PlainsStageGenerator.new().generate("schedule-consumer", index, type, tuning)
			check(generated.ok, "actual consumer retains compatible stage")
			if generated.ok:
				check(generated.manifest.blueprint_plan == PlainsBlueprintSchedule.plan("schedule-consumer", index, type), "actual manifest preserves requested schedule even for explicit compatibility fallback")
				check(RandomStageGenerator.new().validate_manifest(generated.manifest, tuning).ok, "scheduled actual geometry passes strict validation")
	if "--verify-failure-exit" in OS.get_cmdline_user_args(): check(false, "intentional nonzero probe")
	print("BLUEPRINT SCHEDULE SAMPLE: fixed_stage=5 seeds=200 %s" % counts)
	print("BLUEPRINT SCHEDULE: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)
