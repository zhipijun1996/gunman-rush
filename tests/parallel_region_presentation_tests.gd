extends SceneTree
## Presentation/lifetime integration only. Real debug entry, damage policy and
## Home transitions; no position writes, manual Motor steps or traversal claim.
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

static func presentation_errors(app: DemoApp, region: StringName) -> Array[String]:
	var errors: Array[String] = []
	if not is_instance_valid(app.stage) or not app.stage.assembly_ok or not is_instance_valid(app.player):
		return ["actual stage/player missing"]
	var pixel := region == &"plains"
	if app.active_region_id != region: errors.append("actual region differs")
	if pixel and (not app.stage is PlainsRegionStage or app.stage is ThornForestRegionStage): errors.append("actual Plains consumer differs")
	if not pixel:
		if not app.stage is ThornForestRegionStage: errors.append("actual Forest consumer differs")
		elif app.stage.generated.manifest.get("layout_version", "") != "forest-woven-trunk-v12": errors.append("fresh Forest is not v12")
	var actors: Array[Node] = []
	for child: Node in app.player.get_children():
		if child is PixelPlainsActor: actors.append(child)
	if actors.size() != (1 if pixel else 0): errors.append("wrong live pixel actor count")
	if app.player.get_node("CourierVisual").visible == pixel: errors.append("Courier visibility stale")
	if app.player.get_node("PlayerFeedback").visible == pixel: errors.append("feedback visibility stale")
	var adapter := app.player.get_node("PlayerVisualAdapter")
	if (adapter.process_mode == Node.PROCESS_MODE_DISABLED) != pixel: errors.append("original adapter ownership stale")
	if app.get_node("PixelPlainsParallax").visible != pixel: errors.append("pixel background leaks across region")
	if app.get_node("PlainsBackground").visible == pixel: errors.append("original background ownership stale")
	if pixel:
		if not app.stage.get_meta("pixel_formal_style", false): errors.append("formal pixel metadata missing")
		if app.stage.get_node_or_null("PixelRegionScenery") == null: errors.append("actual pixel scenery missing")
	return errors

static func home_errors(app: DemoApp) -> Array[String]:
	var errors: Array[String] = []
	if app.director.state != DemoRunDirector.State.HOME: errors.append("not Home")
	if is_instance_valid(app.player) or is_instance_valid(app.stage): errors.append("ended run still owns player/stage")
	if not is_instance_valid(app.home_scene): errors.append("actual Home consumer missing")
	if not app.get_node("PixelPlainsParallax").visible or app.get_node("PlainsBackground").visible: errors.append("Home background ownership stale")
	for child: Node in app.find_children("*", "Node", true, false):
		if child is PixelPlainsActor: errors.append("pixel run actor survives cleanup")
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
	print("PARALLEL REGION PRESENTATION: %s assertions / %s failures" % [assertions, failures])
	quit(1 if failures else 0)
