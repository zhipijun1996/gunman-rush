extends SceneTree
## Real packed DemoApp assembly, synchronous cache equivalence fixtures, bounded CPU samples.
## These deliberate state mutations are fixtures, not a natural playthrough or phone FPS proof.
const TEARDOWN := preload("res://tests/audio_teardown.gd")
const SOURCE := "res://scripts/underworld_plains/underworld_foreground.gd"
const FIXED_SOURCE := "actual_static_geometry_and_functions"
const FIELDS := ["protect", "static", "dynamic", "source_counts", "overflow"]
var checks := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var benchmarks: Array[Dictionary] = []
var scenes: Array[Dictionary] = []
var output := ""
var initial_sha := ""

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures.append(reason)
		push_error(reason)

func frames(count: int) -> void:
	for unused: int in count:
		await physics_frame
		await process_frame

func snapshot(fg: UnderworldForeground) -> Dictionary:
	return {"protect": fg._protect.duplicate(), "static": fg._static_protect.duplicate(), "dynamic": fg._dynamic_protect.duplicate(), "source_counts": fg._source_counts.duplicate(), "overflow": fg._overflow}

func compare(label: String, actual: Dictionary, expected: Dictionary) -> void:
	var equal := true
	for field: String in FIELDS:
		check(actual[field] == expected[field], label + ": exact " + field)
		equal = equal and actual[field] == expected[field]
	var receipt: Dictionary = {"case": label, "equal": equal, "protect_count": actual.protect.size(), "static_count": actual.static.size(), "dynamic_count": actual.dynamic.size(), "source_counts": actual.source_counts, "overflow": actual.overflow}
	if not equal:
		receipt.actual = actual
		receipt.expected = expected
	cases.append(receipt)

func full_case(fg: UnderworldForeground, label: String, hit: bool) -> void:
	# A non-semantic marker distinguishes reuse from replacing the dictionary.
	fg._fixed_protection_cache["test_marker"] = label
	fg._protection()
	check(fg._fixed_protection_cache.has("test_marker") == hit, label + ": expected cache " + ("hit" if hit else "miss"))
	var actual := snapshot(fg)
	# No await between candidate/reference: dynamic actors and UI are identical.
	fg._fixed_protection_cache.clear()
	fg._protection()
	compare(label, actual, snapshot(fg))

func reset_prefix(fg: UnderworldForeground) -> void:
	fg._protect.clear()
	fg._static_protect.clear()
	fg._dynamic_protect.clear()
	fg._source_counts.clear()
	fg._overflow = false

func original_prefix(fg: UnderworldForeground) -> void:
	for rect: Rect2 in fg._fixed_world:
		fg._world_rect(rect, FIXED_SOURCE)

func prefix_case(fg: UnderworldForeground, label: String, count: int, overflow: bool) -> void:
	reset_prefix(fg)
	original_prefix(fg)
	var expected := snapshot(fg)
	check(expected.protect.size() == count and expected.overflow == overflow, label + ": original union/overflow boundary")
	reset_prefix(fg)
	fg._fixed_protection()
	compare(label + "/candidate", snapshot(fg), expected)
	reset_prefix(fg)
	fg._fixed_protection()
	compare(label + "/warm", snapshot(fg), expected)

func synthetic_prefix() -> void:
	# Never added to the tree: exercise the same original union function directly.
	var fg := UnderworldForeground.new()
	fg._protection_canvas = Transform2D.IDENTITY
	fg._protection_viewport = Rect2(0, 0, 1280, 720)
	for i: int in 70:
		fg._fixed_world.append(Rect2(20 + (i % 14) * 70, 20 + (i / 14) * 70, 5, 5))
	prefix_case(fg, "synthetic/70-disjoint", 70, true)
	var enclosure := Rect2(0, 0, 1100, 500)
	fg._fixed_world.append(enclosure)
	prefix_case(fg, "synthetic/enclosure-last-sticky-overflow", 1, true)
	fg._fixed_world.pop_back()
	fg._fixed_world.push_front(enclosure)
	prefix_case(fg, "synthetic/enclosure-first-no-overflow", 1, false)
	fg._fixed_world.assign([Rect2(0, 0, 6, 6), Rect2(3, 4, 6, 6)])
	prefix_case(fg, "synthetic/strict-union-threshold-equal", 2, false)
	fg._fixed_world[1] = Rect2(3, 3, 6, 6)
	prefix_case(fg, "synthetic/strict-union-threshold-below", 1, false)
	fg._fixed_world.assign([Rect2(0, 0, 0, 4), Rect2(-20, -20, 2, 2), Rect2(1280, 0, 8, 8)])
	prefix_case(fg, "synthetic/zero-outside-touching-edge", 0, false)
	fg._fixed_world.clear()
	prefix_case(fg, "synthetic/empty-after-nonempty", 0, false)
	fg.free()

func benchmark(fg: UnderworldForeground, context: String) -> void:
	var canvas := fg._protection_canvas
	var rows: Array[Dictionary] = []
	# Include the common reset in every duration. Forced miss is NOT the old code;
	# the direct original loop is separately measured without cache allocation.
	for round_index: int in 2:
		var modes: Array[String] = ["warm", "forced_miss", "original", "moving_candidate", "moving_original"]
		if round_index == 1:
			modes.reverse()
		for mode: String in modes:
			fg._protection_canvas = canvas
			reset_prefix(fg)
			fg._fixed_protection()
			var begin := Time.get_ticks_usec()
			for i: int in 32:
				reset_prefix(fg)
				if mode.begins_with("moving_"):
					fg._protection_canvas = canvas
					fg._protection_canvas.origin += Vector2(i + 1, 0)
				if mode == "original" or mode == "moving_original":
					original_prefix(fg)
				else:
					if mode == "forced_miss":
						fg._fixed_protection_cache.clear()
					fg._fixed_protection()
			var elapsed := Time.get_ticks_usec() - begin
			rows.append({"mode": mode, "round": round_index, "iterations": 32, "total_usec": elapsed, "mean_usec": float(elapsed) / 32.0})
	fg._protection_canvas = canvas
	fg._fixed_protection_cache.clear()
	fg._protection()
	benchmarks.append({"context": context, "fixed_world_count": fg._fixed_world.size(), "scope": "Synchronous fixed-prefix CPU including shared reset; no FPS/GPU/device claim. Moving cases translate canvas by 1 px each call. Two reversed-order rounds, 64 calls per mode.", "rows": rows})

func exercise_scene(app: DemoApp, scene: Node, context: String) -> void:
	var fg := scene.get_node_or_null("UnderworldForeground") as UnderworldForeground
	check(fg != null, context + ": real scene has foreground")
	if fg == null:
		return
	var was_processing := fg.is_processing()
	fg.set_process(false)
	fg._protection()
	scenes.append({"context": context, "scene_path": scene.scene_file_path, "fixed_world_count": fg._fixed_world.size(), "tracked_count": fg._tracked.size(), "viewport": fg._protection_viewport, "canvas": fg._protection_canvas, "player": fg._actor.global_position})
	check(not fg._fixed_world.is_empty(), context + ": actual fixed geometry is nonempty")
	for i: int in 3:
		full_case(fg, context + "/stationary-%d" % i, true)
	var geometry: Array[Rect2] = fg._fixed_world.duplicate()
	var extra := fg._protection_canvas.affine_inverse() * Rect2(400, 200, 22, 25)
	fg._fixed_world.append(extra)
	full_case(fg, context + "/geometry-add", false)
	var cached_geometry: Array = fg._fixed_protection_cache.world.duplicate()
	fg._fixed_world[0] = fg._fixed_world[0].grow(1)
	check(fg._fixed_protection_cache.world == cached_geometry, context + ": world cache does not alias geometry array")
	full_case(fg, context + "/geometry-edit", false)
	fg._fixed_world.reverse()
	full_case(fg, context + "/geometry-reorder", false)
	fg._fixed_world.assign(geometry)
	full_case(fg, context + "/geometry-remove-restore", false)
	var cached: Dictionary = fg._fixed_protection_cache.duplicate(true)
	fg._protect.append(Rect2(9, 9, 1, 1))
	fg._static_protect.append(Rect2(8, 8, 1, 1))
	fg._source_counts["alias_poison"] = 999
	check(fg._fixed_protection_cache == cached, context + ": miss result arrays and counts do not alias cache")
	full_case(fg, context + "/alias-after-miss", true)
	fg._protection()
	cached = fg._fixed_protection_cache.duplicate(true)
	fg._protect.clear()
	fg._static_protect.clear()
	fg._source_counts["alias_poison"] = 888
	check(fg._fixed_protection_cache == cached, context + ": hit result arrays and counts do not alias cache")
	full_case(fg, context + "/alias-after-hit", true)
	var camera := root.get_camera_2d()
	check(camera != null, context + ": real active camera exists")
	if camera != null:
		var old_offset := camera.offset
		var old_zoom := camera.zoom
		var before := root.get_canvas_transform()
		camera.offset += Vector2(17, 9)
		camera.force_update_scroll()
		check(root.get_canvas_transform() != before, context + ": camera fixture actually changes canvas")
		full_case(fg, context + "/camera-offset", false)
		camera.zoom *= 1.125
		camera.force_update_scroll()
		full_case(fg, context + "/camera-zoom", false)
		camera.offset = old_offset
		camera.zoom = old_zoom
		camera.force_update_scroll()
		full_case(fg, context + "/camera-restore", false)
	var old_size := root.size
	var old_scale_size := root.content_scale_size
	var old_scale_mode := root.content_scale_mode
	var old_visible := root.get_visible_rect()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 540)
	if camera != null:
		camera.force_update_scroll()
	check(root.get_visible_rect() != old_visible, context + ": viewport fixture actually changes visible rect")
	full_case(fg, context + "/viewport-resize", false)
	root.size = old_size
	root.content_scale_size = old_scale_size
	root.content_scale_mode = old_scale_mode
	if camera != null:
		camera.force_update_scroll()
	full_case(fg, context + "/viewport-restore", false)
	var actor_position := fg._actor.global_position
	var old_dynamic := fg._dynamic_protect.duplicate()
	fg._actor.global_position += Vector2(37, -11)
	full_case(fg, context + "/dynamic-actor", true)
	check(fg._dynamic_protect != old_dynamic, context + ": actor fixture changes dynamic output")
	fg._actor.global_position = actor_position
	full_case(fg, context + "/dynamic-restore", true)
	var layer := CanvasLayer.new()
	var ui := ColorRect.new()
	ui.position = Vector2(300, 180)
	ui.size = Vector2(60, 50)
	ui.color = Color(1, 1, 1, 0.9)
	layer.add_child(ui)
	root.add_child(layer)
	full_case(fg, context + "/ui-visible", true)
	var visible_ui: int = int(fg._source_counts.get("actual_visible_ui", 0))
	ui.hide()
	full_case(fg, context + "/ui-hidden", true)
	check(int(fg._source_counts.get("actual_visible_ui", 0)) == visible_ui - 1, context + ": tracked UI fixture changes source count")
	ui.show()
	ui.position += Vector2(100, 20)
	full_case(fg, context + "/ui-moved", true)
	layer.free()
	full_case(fg, context + "/ui-removed", true)
	if context == "plains":
		app.toggle_pause()
		check(paused, "plains: actual pause menu pauses tree")
	else:
		paused = true # Explicit pause fixture; Home navigation itself does not pause.
	full_case(fg, context + "/paused", true)
	if context == "plains":
		app.menu.requested_resume.emit()
	else:
		paused = false
	check(not paused, context + ": resumed tree")
	full_case(fg, context + "/resumed", true)
	benchmark(fg, context)
	full_case(fg, context + "/after-benchmark", true)
	fg.set_process(was_processing)

func prepare_output() -> bool:
	output = "res://build/mobile_web_fps_04/native-cache-%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	output = ProjectSettings.globalize_path(output)
	if DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output):
		push_error("Refusing to overwrite native cache evidence: " + output)
		return false
	return DirAccess.make_dir_recursive_absolute(output) == OK

func run() -> void:
	if not prepare_output():
		quit(1)
		return
	var begin := Time.get_ticks_usec()
	var old_fps := Engine.max_fps
	Engine.max_fps = 60
	initial_sha = FileAccess.get_sha256(SOURCE)
	root.size = Vector2i(1280, 720)
	synthetic_prefix()
	var packed := load("res://scenes/demo/demo.tscn") as PackedScene
	check(packed != null, "real demo.tscn loads")
	if packed != null:
		var app := packed.instantiate() as DemoApp
		packed = null
		check(app != null, "real packed scene instantiates DemoApp")
		if app != null:
			app.meta_persistence_enabled = false
			root.add_child(app)
			await frames(6)
			app.menu.requested_enter_home.emit()
			await frames(6)
			check(is_instance_valid(app.home_scene), "real Home is assembled")
			if is_instance_valid(app.home_scene):
				exercise_scene(app, app.home_scene, "home")
			check(app.start_plains("mobile-fps-04"), "formal seeded Plains starts")
			await frames(6)
			check(app.stage is PlainsRegionStage, "real Plains stage is assembled")
			if app.stage is PlainsRegionStage:
				exercise_scene(app, app.stage, "plains")
			paused = false
			check(await TEARDOWN.drain_world(app), "real SFX/BGM teardown drains")
			app.free()
			await frames(4)
	check(FileAccess.get_sha256(SOURCE) == initial_sha, "production source stays unchanged during run")
	Engine.max_fps = old_fps
	var report: Dictionary = {"schema": 1, "checks": checks, "failures": failures, "source_sha256": initial_sha, "scene": "res://scenes/demo/demo.tscn", "seed": "mobile-fps-04", "elapsed_msec": float(Time.get_ticks_usec() - begin) / 1000.0, "scope": "Functional exact-output synchronous fixtures and direct CPU prefix microbenchmark; no visual, gameplay-route, Web FPS or phone acceptance claim.", "scenes": scenes, "cases": cases, "benchmarks": benchmarks}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		check(false, "report output opens")
	else:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	print("FOREGROUND_FIXED_CACHE checks=%d failures=%d output=%s" % [checks, failures.size(), output])
	quit.call_deferred(0 if failures.is_empty() else 1)
