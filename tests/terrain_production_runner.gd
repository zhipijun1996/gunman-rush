extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
func frames(count: int) -> void:
	for i: int in count: await physics_frame
func run() -> void:
	# Real default consumer, without the Lab opt-in. Outcome fixture below only
	# exercises map transitions; it does not claim player completion of a route.
	var app := DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	await frames(3)
	check(app.start_plains("terrain-production"), "default plains launch succeeds")
	await frames(5)
	for map_index: int in [1, 2]:
		var stage := app.stage as PlainsRegionStage
		check(stage != null and stage.map_index == map_index, "actual formal map installed")
		check(not app._terrain_study_requested, "formal art does not require development opt-in")
		var art := stage.terrain_art
		check(is_instance_valid(art) and art.enabled, "approved paint enabled by default")
		check(not is_instance_valid(art.toggle), "formal entry has no art comparison UI")
		var manifest := JSON.stringify(stage.generated.manifest)
		var body_count := stage.find_children("*", "CollisionShape2D", true, false).size()
		var moving_count := 0
		for module: PlatformingModule in stage.assembler.modules:
			check(module.terrain_candidate_preview, "legacy solid paint suppressed")
			for node: Node in module.get_children():
				if node is ModuleMovingPlatform:
					moving_count += 1
					var platform := node as ModuleMovingPlatform
					check(is_instance_valid(platform.painted_art) and platform.painted_art.visible, "moving solid shares approved material")
					for quad: ColorRect in platform.painted_art.get_children():
						check(quad.material.get_shader_parameter("body_local_material"), "moving brushwork uses body-local coordinates")
		check(moving_count > 0, "seed exercises real moving platforms")
		for value: bool in [false, true, false, true]:
			art.set_candidate(value)
			check(JSON.stringify(stage.generated.manifest) == manifest, "presentation never changes manifest")
			check(stage.find_children("*", "CollisionShape2D", true, false).size() == body_count, "presentation never changes collision ownership")
		if map_index == 1:
			check(await load("res://tests/plains_campaign_fixture.gd").second_map(app, self), "formal second map lifecycle fixture")
	app.abandon_run()
	await frames(3)
	check(app.start_plains("terrain-production-restart"), "restart launches normally")
	await frames(3)
	check(app.stage.terrain_art.enabled and not is_instance_valid(app.stage.terrain_art.toggle), "restart preserves default without leaking study UI")
	app.abandon_run()
	await frames(3)
	if not await load("res://tests/audio_teardown.gd").drain_world(app):
		failures += 1;push_error("TEST AUDIO TEARDOWN: playback did not release within 1000ms");quit(1);return
	app.free()
	await frames(3)
	# Variable-width single rows: exact outline, including sub-tile thickness,
	# half-cell lengths, input partitions and tightly stacked rows.
	for height: float in [8.5, 24, 32]:
		for width: float in [8, 32, 64, 96, 192, 383.5, 640]:
			var solids: Array[Rect2] = [Rect2(-17.25, 3.5, width, height)]
			var art := PlainsTileComposer.build_rectangles(solids)
			check(art != null, "single row fits supported boundary budget")
			var area := 0.0
			for quad: ColorRect in art.get_children():
				var rect := Rect2(quad.position, quad.size)
				check(solids[0].encloses(rect), "terminal paint never exceeds physical outline")
				area += rect.get_area()
			check(is_equal_approx(area, width * height), "thin row retains complete body")
			art.free()
	print("TERRAIN PRODUCTION: %s assertions, %s failures" % [checks, failures])
	quit(1 if failures else 0)
