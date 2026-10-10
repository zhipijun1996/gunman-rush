extends RefCounted

# RUN-TEN-01 is a fixed-layout biome trial, never a claim that one biome is a run.
func run(tree: SceneTree, check: Callable) -> void:
	var scope := DemoLifetime.new()
	var director := DemoRunDirector.new(scope)
	var transitions: Array[int] = []
	var endings: Array[StringName] = []
	director.stage_entered.connect(func(result: DemoRunResult) -> void: transitions.append(result.stage_index))
	director.run_ended.connect(func(result: DemoRunResult) -> void: endings.append(result.reason))
	check.call(director.start("formal-trial-17", RunProfile.formal()).accepted(), "formal eight-stage profile starts at fixed combat entry")
	check.call(director.profile.stages_per_biome == 8 and not director.profile.development_only, "formal profile remains eight stages and Boss eight")
	check.call(director.finish_biome(scope.token(), &"premature", true).status == DemoRunResult.Status.NOT_READY, "first-stage biome completion is rejected")
	var seen_types: Dictionary = {}
	for index: int in range(1, 8):
		check.call(director.stage_index == index and director.stage_type_id != &"boss", "formal stages one through seven retain exact increasing indices")
		seen_types[director.stage_type_id] = true
		var offers := director.offers
		check.call(offers.size() == 2, "every advancing formal stage exposes exactly two exit definitions")
		for offer: ExitOffer in offers:
			check.call(offer.next_stage_index == index + 1 and StageTypeDefinition.registry().has(offer.next_stage_type_id), "exit advances only one stage and names a registered type")
		if index == 7:
			check.call(offers[0].next_stage_type_id == &"boss" and offers[1].next_stage_type_id == &"boss", "stage seven cannot bypass either route into Boss eight")
		var token := scope.token()
		var selected: ExitOffer = offers[index % 2]
		var event_id := StringName("trial-selection-%s" % index)
		check.call(director.select_exit(token, selected.exit_id, event_id).status == DemoRunResult.Status.NOT_READY, "uncompleted stage rejects route selection")
		check.call(director.complete_stage(token), "stage completion is accepted with the current scope")
		var transition_count := transitions.size()
		var accepted := director.select_exit(token, selected.exit_id, event_id)
		check.call(accepted.status == DemoRunResult.Status.APPLIED and director.stage_type_id == selected.next_stage_type_id, "selected exit commits its disclosed next room type")
		check.call(director.select_exit(token, selected.exit_id, event_id).status == DemoRunResult.Status.REPLAY and transitions.size() == transition_count + 1, "same exit receipt replays without a second transition")
		check.call(director.select_exit(token, offers[1 - index % 2].exit_id, StringName("competitor-%s" % index)).status == DemoRunResult.Status.STALE, "competing old-stage exit is rejected after the first commitment")
	check.call(transitions == [1, 2, 3, 4, 5, 6, 7, 8], "formal trial emits exactly the complete eight-stage progression")
	check.call(director.stage_type_id == &"boss" and director.offers.is_empty(), "Boss eight is mandatory and has no ordinary stage nine exit")
	check.call(seen_types.size() >= 3, "fixed formal route exercises multiple room types with a fixed seed")
	var last_token := scope.token()
	check.call(director.finish_success(last_token, &"wrong-success", true).status == DemoRunResult.Status.NOT_READY, "formal trial never invokes the development whole-demo success contract")
	check.call(director.finish_biome(last_token, &"before-boss-complete", true).status == DemoRunResult.Status.NOT_READY, "gold proof alone cannot bypass Boss completion")
	director.complete_stage(last_token)
	check.call(director.finish_biome(last_token, &"missing-gold", false).status == DemoRunResult.Status.NOT_READY, "Boss completion requires committed gold before ending the biome trial")
	var result := director.finish_biome(last_token, &"biome-proof", true)
	check.call(result.accepted() and result.reason == &"biome_complete" and director.state == DemoRunDirector.State.ENDING_BIOME, "eight-stage trial finishes at an explicit biome boundary rather than run victory")
	check.call(not scope.active and endings == [&"biome_complete"], "biome trial invalidates callbacks and emits its boundary exactly once")
	check.call(director.finish_biome(last_token, &"biome-proof", true).status == DemoRunResult.Status.REPLAY and endings.size() == 1, "biome completion receipt replays without duplicate end events")
	check.call(director.end_failure(&"biome-proof").status == DemoRunResult.Status.CONFLICT, "one settlement ID cannot change from biome completion to death")
	check.call(director.manifest.snapshot().end.reason == "biome_complete" and RunManifest.from_snapshot(director.manifest.snapshot()) != null, "manifest preserves the biome-only boundary in a compatible eight-stage record")
	check.call(director.return_home() and director.state == DemoRunDirector.State.HOME, "fixed biome trial can return to the menu without inventing later biomes")
	check.call(director.start("development", RunProfile.development()).accepted(), "existing short development profile remains available")
	check.call(director.finish_biome(scope.token(), &"development-not-formal", true).status == DemoRunResult.Status.NOT_READY, "development profile cannot settle a formal biome")
	director.end_failure(&"cancel-development")
	director.return_home()
	director.start("formal-fatal", RunProfile.formal())
	for index: int in range(1, 8):
		director.complete_stage(scope.token())
		director.select_exit(scope.token(), director.offers[0].exit_id, StringName("fatal-route-%s" % index))
	director.complete_stage(scope.token())
	var dying_token := scope.token()
	scope.end()
	check.call(director.finish_biome(dying_token, &"fatal-gold", true).status == DemoRunResult.Status.STALE, "zero-health lifetime cancellation beats same-frame biome settlement")
	check.call(director.end_failure(&"player-fatal").accepted() and director.state == DemoRunDirector.State.ENDING_FAILURE, "failure remains the only outcome after lethal scope invalidation")

	# All six registered room definitions instantiate real fixed terrain and actors.
	var world := Node2D.new()
	tree.root.add_child(world)
	var packed_player := preload("res://scenes/player/player.tscn")
	var player: PlayerMotor = packed_player.instantiate()
	player.position = Vector2(100, 580)
	world.add_child(player)
	var player_controller := player.get_node("Controller") as PlayerController
	for type: StringName in StageTypeDefinition.registry():
		var stage := DemoStage.new()
		stage.configure(1, type, [])
		world.add_child(stage)
		await tree.physics_frame
		await tree.physics_frame
		var respawn := SegmentRespawn.new()
		respawn.configure(player_controller, DemoLifetime.new())
		check.call(stage.is_inside_tree() and respawn.is_safe(stage.spawn), "each registered room loads actual fixed terrain with a valid safe entry")
		var definition: StageTypeDefinition = StageTypeDefinition.registry()[type]
		check.call(definition.rule() != null, "each real room uses a valid independent completion policy")
		if type == &"combat":
			check.call(stage.enemy != null and stage.enemy.get_node("Actor").health.current > 0, "combat room instantiates a live patrol target")
		elif type == &"boss":
			check.call(stage.boss != null and stage.boss.get_node("Encounter").health.current > 0, "Boss room instantiates a live independent encounter")
		else:
			var label_found := false
			for child: Node in stage.get_children():
				if child is Label and child.text == DemoStage.ROOM_MARKERS[type].text:
					label_found = true
			check.call(label_found and DemoStage.ROOM_MARKERS.has(type), "reward and shop room definitions render their own explicit interaction markers")
		world.remove_child(stage)
		stage.queue_free()
		await tree.physics_frame
	world.queue_free()
	await tree.process_frame
