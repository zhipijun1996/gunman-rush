extends SceneTree
var assertions := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var tuning := PlayerTuning.load_default()
	var planner := RoutePlanner.new()
	for index: int in [1, 4, 7, 8]:
		var seed := "signpost-%d" % index
		var type: StringName = &"boss" if index == 8 else &"coin_reward"
		var data := PlainsStageGenerator.new().generate(seed, index, type, tuning)
		check(data.ok, "Actual formal generated fixture succeeds")
		if not data.ok:
			continue
		var stage := GeneratedDemoStage.new()
		var offers := planner.offers(RunProfile.formal8(), index, seed, StringName("stage_%d" % index))
		stage.configure(index, type, offers)
		stage.configure_generated(data, tuning)
		root.add_child(stage)
		await process_frame
		if index == 8:
			check(stage.route_signpost == null, "Boss has no fictional next route sign")
		else:
			var signpost: RouteSignpost = stage.route_signpost
			check(is_instance_valid(signpost), "Branched generated level installs a world signpost")
			if is_instance_valid(signpost):
				check(signpost.routes.size() == 2, "Both actual terminal routes are disclosed before selecting")
				var fork: PlatformingModule = stage.assembler.modules[int(data.manifest.fork_node)]
				check(signpost.position.distance_to(fork.position + fork.definition.anchors[1]) < 90, "Sign is at the safe fork decision point")
				for route_index: int in 2:
					var row: Dictionary = signpost.routes[route_index]
					var offer: ExitOffer = offers[route_index]
					check(row.exit_id == offer.exit_id and row.type_id == offer.next_stage_type_id and row.icon_id == offer.icon_id and row.label == offer.label, "Displayed destination comes from the actual door offer")
					check(row.direction == (Vector2.UP if route_index == 0 else Vector2.RIGHT), "Each arrow follows the corresponding branch start, not remote door bearing")
					check(stage.nearby_exit(signpost.position) == -1, "Sign itself cannot act as a mid-route exit")
					if index == 7:
						check(row.type_id == &"boss", "Both pre-Boss signs accurately advertise Boss")
				check(not stage.reward_available and stage.coins_collected == 0, "Installing signs does not grant rewards")
				check(signpost.get_child_count() == 0, "Presentation has no collision, trigger or focus-catching control")
		stage.free()
	if "--verify-failure-exit" in OS.get_cmdline_user_args():
		check(false, "Intentional nonzero-exit probe")
	print("ROUTE SIGNPOST: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)
