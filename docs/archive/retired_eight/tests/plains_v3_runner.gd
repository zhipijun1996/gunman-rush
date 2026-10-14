extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	for id: String in ["grass_limestone", "brass_wood_bridge"]:
		for width: float in [12, 48, 80, 144, 320, 1024, 2800]:
			var box := Rect2(50, 100, width, 120)
			var x := box.position.x
			for piece: Dictionary in PlainsTerrainSkin.surface_pieces(box, id):
				var dst: Rect2 = piece.destination
				var src: Rect2 = piece.source
				check(is_equal_approx(dst.position.x, x), "v3 caps and middle meet without geometric gap")
				check(dst.size.is_equal_approx(src.size * 0.2), "v3 caps keep fixed scale on narrow and long platforms")
				check(src.position.x >= 0 and src.end.x <= 2172 and src.end.y <= 724, "v3 crop inside original source")
				x = dst.end.x
			check(is_equal_approx(x, box.end.x), "surface retains exact collision width")
	for id: StringName in [&"combat", &"shop", &"coin_reward", &"health_reward", &"item_reward", &"boss"]:
		check(PlainsV3Assets.stage_icon(id) != null, "six real room types have v3 glyphs")
	check(PlainsTerrainSkin.surface_id(true) == "brass_wood_bridge", "one way collision has wooden slat visual")
	check(PlainsTerrainSkin.surface_id(false) == "grass_limestone", "solid collision has stone visual regardless of thickness")
	for width: float in [8, 24, 70, 120, 320, 900]:
		var danger := Rect2(40, 80, width, 24)
		var covered := danger.position.x
		for piece: Dictionary in PlainsRefreshAssets.bramble_pieces(danger):
			var dst: Rect2 = piece.destination
			var src: Rect2 = piece.source
			check(danger.encloses(dst), "bramble never expands damage silhouette")
			check(dst.position.x <= covered + 0.001, "bramble overlaps continuously without empty tile seam")
			check(dst.size.is_equal_approx(src.size * (24.0 / 366.0)), "bramble preserves natural clump aspect ratio")
			covered = maxf(covered, dst.end.x)
		check(is_equal_approx(covered, danger.end.x), "bramble reaches exact authored hazard end")
	var tuning := PlayerTuning.load_default()
	var data := PlainsStageGenerator.new().generate("v3-presentation-proof", 4, &"coin_reward", tuning)
	check(data.ok, "actual generated room exists")
	var before := JSON.stringify(data)
	var stage := GeneratedDemoStage.new()
	stage.configure(4, &"coin_reward", RoutePlanner.new().offers(RunProfile.formal8(), 4, "v3-presentation-proof", &"stage_4"))
	stage.configure_generated(data, tuning)
	root.add_child(stage)
	await process_frame
	check(JSON.stringify(data) == before, "art never mutates gameplay manifest")
	var dressing := stage.get_node("PlainsSetDressing") as PlainsSetDressing
	check(dressing.presentation_manifest == PlainsSetDressing.plan(stage), "cosmetic plan repeats without advancing gameplay random streams")
	check(dressing.get_child_count() > 0 and dressing.get_child_count() <= 24, "real generated stage receives bounded v3 scenery")
	for child: Node in dressing.get_children():
		check(child is Sprite2D and child.get_child_count() == 0, "dressing has no physics or interaction objects")
		check((child as Sprite2D).modulate == Color.WHITE, "local decoration retains source color and opacity")
	check(PlainsRefreshAssets.object_texture(&"coin").atlas.resource_path.contains("plains_v3"), "actual coin uses latest art")
	check(PlainsRefreshAssets.object_texture(&"heart").atlas.resource_path.contains("plains_v3"), "actual heart remains distinct latest healing icon")
	check(PlainsRefreshAssets.object_texture(&"door").atlas.resource_path.ends_with("windchime_door.png"), "door uses dedicated plains limestone doorway rather than directional sign")
	stage.free()
	if "--prove-failure" in OS.get_cmdline_user_args(): check(false, "intentional failure")
	print("PLAINS V3: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
