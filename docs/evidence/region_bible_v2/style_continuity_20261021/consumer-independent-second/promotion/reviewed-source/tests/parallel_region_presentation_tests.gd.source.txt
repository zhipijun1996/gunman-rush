extends SceneTree
## Presentation/lifetime integration only. Real debug entry, damage policy and
## Home transitions; no position writes, manual Motor steps or traversal claim.
const EXPECTED_CURRENT_FOREST_LAYOUT := "forest-bible-world-v15"
var assertions := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func frames(count: int) -> void:
	for index: int in count:
		await physics_frame

static func presentation_errors(app: DemoApp, region: StringName, expected_forest_layout: String = EXPECTED_CURRENT_FOREST_LAYOUT) -> Array[String]:
	var errors: Array[String] = []
	if not is_instance_valid(app.stage) or not app.stage.assembly_ok or not is_instance_valid(app.player):
		return ["actual stage/player missing"]
	var plains := region == &"plains"
	var pixel: bool = plains or expected_forest_layout == "forest-bible-world-v15"
	if app.active_region_id != region: errors.append("actual region differs")
	if plains and (not app.stage is PlainsRegionStage or app.stage is ThornForestRegionStage): errors.append("actual Plains consumer differs")
	if not plains:
		if not app.stage is ThornForestRegionStage: errors.append("actual Forest consumer differs")
		elif app.stage.generated.manifest.get("layout_version", "") != expected_forest_layout: errors.append("Forest layout differs from independently selected expectation")
	var actors: Array[Node] = []
	for child: Node in app.player.get_children():
		if child is PixelPlainsActor: actors.append(child)
	if actors.size() != (1 if pixel else 0): errors.append("wrong live pixel actor count")
	if pixel and (actors.size() != 1 or not actors[0] is UnderworldPlayer): errors.append("formal actor is not actual UnderworldPlayer")
	if app.player.get_node("CourierVisual").visible == pixel: errors.append("Courier visibility stale")
	if app.player.get_node("PlayerFeedback").visible == pixel: errors.append("feedback visibility stale")
	var adapter := app.player.get_node("PlayerVisualAdapter")
	if (adapter.process_mode == Node.PROCESS_MODE_DISABLED) != pixel: errors.append("original adapter ownership stale")
	if app.get_node("PixelPlainsParallax").visible != plains: errors.append("pixel background leaks across region")
	if app.get_node("PlainsBackground").visible == pixel: errors.append("original background ownership stale")
	if pixel and not plains:
		if not is_instance_valid(app.stage.forest_terrain) or not app.stage.forest_terrain is UnderworldTerrain: errors.append("Forest does not share actual UnderworldTerrain")
		if not ForestBiblePresentation.enabled(app.stage.generated.manifest): errors.append("Forest shared-pixel consumer is not enabled")
	if plains:
		if not app.stage.get_meta("pixel_formal_style", false): errors.append("formal pixel metadata missing")
		if app.stage.get_node_or_null("PixelRegionScenery") == null: errors.append("actual pixel scenery missing")
		if not app.stage.get_node_or_null("PixelRegionScenery") is UnderworldScenery: errors.append("formal scenery is not actual UnderworldScenery")
		if app.stage.terrain_art == null or not app.stage.terrain_art.art is UnderworldTerrain: errors.append("formal terrain is not actual UnderworldTerrain")
		if not app.get_node("PixelPlainsParallax") is UnderworldParallax: errors.append("formal background is not actual UnderworldParallax")
		if not app.stage.get_meta("underworld_formal_style", false): errors.append("formal Underworld metadata missing")
	return errors

static func home_errors(app: DemoApp) -> Array[String]:
	var errors: Array[String] = []
	if app.director.state != DemoRunDirector.State.HOME: errors.append("not Home")
	if is_instance_valid(app.player) or is_instance_valid(app.stage): errors.append("ended run still owns player/stage")
	if not is_instance_valid(app.home_scene): errors.append("actual Home consumer missing")
	if not app.get_node("PixelPlainsParallax").visible or app.get_node("PlainsBackground").visible: errors.append("Home background ownership stale")
	var home_actor: Node = null
	if is_instance_valid(app.home_scene):
		if not is_instance_valid(app.home_scene.player): errors.append("actual Home player missing")
		else:
			if app.home_scene.player.get_parent() != app.home_scene: errors.append("Home player ownership stale")
			home_actor = app.home_scene.player.get_node_or_null("UnderworldPlayer")
		if not home_actor is UnderworldPlayer: errors.append("actual Home UnderworldPlayer missing")
		if not app.home_scene.world is UnderworldHomeWorld: errors.append("actual Home renderer missing")
		if not app.home_scene.parallax is UnderworldParallax: errors.append("actual Home parallax missing")
	var home_actor_count := 0
	for child: Node in app.find_children("*", "Node", true, false):
		if child is PixelPlainsActor:
			# Only the exact actor owned by the actual Home player is legal.
			# Extra actors, including extras inside Home, remain run leaks.
			if child == home_actor and child is UnderworldPlayer:
				home_actor_count += 1
			else: errors.append("pixel run actor survives cleanup")
	if home_actor_count != 1: errors.append("Home must own exactly one UnderworldPlayer")
	if not app.get_node("PixelPlainsParallax") is UnderworldParallax: errors.append("Home background is not actual UnderworldParallax")
	return errors

func run() -> void:
	# Actual embedded Lab owns its actor while director remains HOME. Reject
	# a concurrent formal run before it can mutate the pending region request.
	var lab_app := DemoApp.new()
	lab_app.meta_persistence_enabled = false
	root.add_child(lab_app)
	lab_app._open_style_lab()
	await frames(4)
	check(is_instance_valid(lab_app._style_lab), "actual embedded style lab opens")
	check(not lab_app._uses_pixel_plains_presentation() and not is_instance_valid(lab_app.player) and not is_instance_valid(lab_app.stage), "candidate Lab is not replaced with formal Underworld run")
	check(not lab_app.start_debug_region(&"thorn_forest", 2, "style-concurrent"), "active Lab rejects concurrent region")
	check(lab_app._debug_region == &"", "rejected Lab entry preserves pending region")
	check(not lab_app.start_demo("style-concurrent"), "active Lab rejects concurrent formal run")
	lab_app._show_home()
	check(not is_instance_valid(lab_app.home_scene), "active Lab prevents second Home actor")
	lab_app._style_lab.home_requested.emit()
	await frames(8)
	check(not is_instance_valid(lab_app._style_lab) and is_instance_valid(lab_app.home_scene), "Lab exit returns actual Home")
	if not await load("res://tests/audio_teardown.gd").drain_world(lab_app): failures += 1
	lab_app.free()
	for region: StringName in [&"plains", &"thorn_forest"]:
		for map_index: int in [1, 2]:
			var app := DemoApp.new()
			app.meta_persistence_enabled = false
			root.add_child(app)
			check(app.start_debug_region(region, map_index, "parallel-presentation"), "real debug entry accepted")
			await frames(12)
			check(app.director.region_map_index == map_index, "selected map actually loaded")
			check(presentation_errors(app, region).is_empty(), "%s map%s actual presentation: %s" % [region, map_index, presentation_errors(app, region)])
			if is_instance_valid(app.player) and is_instance_valid(app.policy):
				var ended_player := app.player
				if map_index == 1:
					# Wait out actual spawn protection, then submit a real lethal
					# policy request. No health mutation or fatal callback shortcut.
					await frames(45)
					var request := DamageRequest.new()
					request.token = app.lifetime.token()
					request.event_id = &"presentation_actual_death"
					request.source_id = &"presentation_lifecycle_fixture"
					request.target_id = &"player"
					request.kind = DamageRequest.Kind.ENVIRONMENT
					request.amount = app.controller.actor_resources.health.current
					request.health_epoch = app.controller.actor_resources.health.epoch
					request.actor_epoch = app.lifetime.actor_epoch
					check(app.policy.submit(request), "real lethal policy request accepted")
				else:
					app.abandon_run()
				await frames(8)
				check(not is_instance_valid(ended_player), "ended player actually freed")
				check(home_errors(app).is_empty(), "actual Home cleanup: %s" % [home_errors(app)])
				var next_region: StringName = &"thorn_forest" if region == &"plains" else &"plains"
				check(app.start_debug_region(next_region, map_index, "parallel-reopen"), "reopen other region after cleanup")
				await frames(12)
				check(presentation_errors(app, next_region).is_empty(), "reopened region has no stale owner: %s" % [presentation_errors(app, next_region)])
				app.abandon_run()
				await frames(8)
			if not await load("res://tests/audio_teardown.gd").drain_world(app): failures += 1
			app.free()
	await same_player_roundtrip()
	# Preserve the historical disposal/recreation contract alongside the new
	# default shared-family reuse; an explicit pin is never current evidence.
	await same_player_roundtrip("forest-fruit-routes-v14")
	print("PARALLEL REGION PRESENTATION: %s assertions / %s failures" % [assertions, failures])
	quit(1 if failures else 0)

# Explicit presentation integration fixture, not natural campaign progression:
# Forest currently exits to its boundary, so a reverse region is not a legal
# reward. Rebuild through the actual app loader without replacing the player,
# altering positions, stepping Motor, or changing any production route guard.
func reload_presentation_region(app: DemoApp, region: StringName) -> void:
	# Old stage captures only its own state; the destination receives a distinct
	# state keyed exactly as the real loader looks it up, never an old map hash.
	var previous_state := (app.stage as PlainsRegionStage).region_state
	var destination_state := PlainsRegionState.new()
	app.active_region_id = region
	app.region_states.clear()
	app.region_states[app.director.stage_index] = destination_state
	app.region_state = destination_state
	app._region_loaded_map = 0
	print("PRESENTATION_RELOAD_BEFORE " + JSON.stringify({"region":String(region),"campaign":app.campaign.snapshot(),"hook_enabled":app.controller.traversal.hook_enabled,"previous_hash":previous_state.manifest_hash,"destination_hash":destination_state.manifest_hash,"distinct_state":previous_state != destination_state}))
	app._stage_entered(DemoRunResult.new())
	await frames(12)
	print("PRESENTATION_RELOAD_AFTER " + JSON.stringify({"region":String(region),"status":app._status,"player_valid":is_instance_valid(app.player),"stage_valid":is_instance_valid(app.stage),"campaign":app.campaign.snapshot(),"destination_hash":destination_state.manifest_hash}))
	check(is_instance_valid(app.stage) and app.stage is PlainsRegionStage and (app.stage as PlainsRegionStage).region_state == destination_state and app.region_state == destination_state and destination_state != previous_state, "actual loader binds independent destination region state")
	if is_instance_valid(app.stage) and app.stage is PlainsRegionStage:
		check(destination_state.manifest_hash == (app.stage as PlainsRegionStage).generated.manifest.manifest_hash, "destination state hash equals actual assembled manifest")

func same_player_roundtrip(recorded_forest_layout := "") -> void:
	var expected_forest_layout: String = recorded_forest_layout if not recorded_forest_layout.is_empty() else EXPECTED_CURRENT_FOREST_LAYOUT
	var shared_forest: bool = expected_forest_layout == "forest-bible-world-v15"
	for map_index: int in [1, 2]:
		var app := DemoApp.new()
		app.meta_persistence_enabled = false
		root.add_child(app)
		check(app.start_debug_region(&"plains", map_index, "underworld-same-player-roundtrip"), "same-player fixture enters actual Plains")
		await frames(12)
		var player_id := app.player.get_instance_id()
		var first_visual := app.player.get_node_or_null("PixelPlainsActor")
		var first_id: int = first_visual.get_instance_id() if first_visual != null else 0
		check(first_visual is UnderworldPlayer and presentation_errors(app, &"plains").is_empty(), "first formal factory creates actual UnderworldPlayer and full Underworld consumer")
		# Use the real reward ledger, not a motor-only grant: the Forest generator
		# requires the accepted H-only campaign snapshot as well as hook_enabled.
		var reward_token := app.lifetime.token()
		check(app.campaign.begin_reward(&"plains", reward_token), "presentation fixture begins actual Plains core reward")
		check(app.campaign.claim(&"grapple", reward_token, not app.controller.actor_resources.health.terminal), "presentation fixture accepts actual campaign H reward")
		check(app.controller.traversal.grant(&"grapple"), "explicit presentation fixture grants legal Forest debug ability")
		check(app.campaign.abilities == [&"grapple"] and app.controller.traversal.hook_enabled, "Forest fixture has exact accepted H-only campaign and motor capability")
		# Only the named historical fixture overrides the recorded choice.
		# An unpinned App has already resolved its real current layout; an
		# empty internal capability is invalid and must not replace that choice.
		if not recorded_forest_layout.is_empty():
			app._forest_layout_version = recorded_forest_layout
		await reload_presentation_region(app, &"thorn_forest")
		check(is_instance_valid(app.player) and app.player.get_instance_id() == player_id, "Plains to Forest retains same actual player")
		if not is_instance_valid(app.player):
			# Fail closed with the actual generation status above, no null abort.
			if not await load("res://tests/audio_teardown.gd").drain_world(app): failures += 1
			app.free()
			return
		var forest_visual := app.player.get_node_or_null("PixelPlainsActor")
		if shared_forest:
			check(is_instance_valid(first_visual) and forest_visual == first_visual and forest_visual is UnderworldPlayer and presentation_errors(app, &"thorn_forest", expected_forest_layout).is_empty(), "current Forest reuses the single actual UnderworldPlayer and owns its regional background")
		else:
			check(not is_instance_valid(first_visual) and presentation_errors(app, &"thorn_forest", expected_forest_layout).is_empty(), "recorded v14 Forest disposes actual Underworld player presentation and retains historical Forest guards")
		await reload_presentation_region(app, &"plains")
		check(is_instance_valid(app.player), "return loader retains actual run player")
		if not is_instance_valid(app.player):
			if not await load("res://tests/audio_teardown.gd").drain_world(app): failures += 1
			app.free()
			return
		var returned_visual := app.player.get_node_or_null("PixelPlainsActor")
		check(app.player.get_instance_id() == player_id, "Forest to Plains retains same actual player")
		if shared_forest:
			check(returned_visual is UnderworldPlayer and returned_visual.get_instance_id() == first_id and returned_visual == forest_visual, "current shared-region roundtrip retains exactly the same actual UnderworldPlayer")
		else:
			check(returned_visual is UnderworldPlayer and returned_visual.get_instance_id() != first_id, "recorded v14 return factory creates fresh actual UnderworldPlayer, not legacy PixelPlainsActor")
		check(presentation_errors(app, &"plains").is_empty(), "same-player return restores full Underworld terrain scenery actor and background")
		# Preserve the actual run presentation as an explicit stale-owner negative.
		# Disable presentation processing only; never mutate player gameplay state.
		returned_visual.process_mode = Node.PROCESS_MODE_DISABLED
		app.player.remove_child(returned_visual)
		app.add_child(returned_visual)
		app.abandon_run()
		await frames(8)
		check(home_errors(app).has("pixel run actor survives cleanup"), "actual retained run actor is rejected despite legal Home actor")
		app.remove_child(returned_visual)
		returned_visual.free()
		check(home_errors(app).is_empty(), "same-player roundtrip retains real Home cleanup")
		if not await load("res://tests/audio_teardown.gd").drain_world(app): failures += 1
		app.free()
