extends SceneTree
## Keep the production DemoApp, encounters, contacts, rewards and camera alive.
## Exit 0 means evidence captured, not that the input policy completed the route.
const TRACE := preload("res://tests/level_formal_trace.gd")
const SNAPSHOT := preload("res://tools/level_capability_snapshot.gd")
var output := "res://build/level_formal/capture.json"
var source_commit := ""
var seed_value := "level-design-v2-baseline"
var strategy := "fast"
var map_index := 1
var phase_wait_ticks := 0
var max_ticks := 18000
var frame_dir := ""
var frame_stride := 120
var visible_capture := false
var report: Dictionary = {}
var app: DemoApp
var driver: RefCounted
var _capture_busy := false
var _last_frame := -1
var _screen_records: Array = []

func _initialize() -> void: run.call_deferred()

func save_report() -> bool:
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(report) + "\n")
	file.close()
	return true

func _startup_failed(reason: String) -> void:
	report["outcome"] = "capture_error"
	report["capture_errors"] = [reason]
	save_report()
	print("LEVEL FORMAL CAPTURE ERROR: ", reason)
	quit(2)

func scenery_inventory(node: Node, rows: Array) -> void:
	var under_scenery := node is PlainsRegionScenery
	if under_scenery:
		var descendants: Array = []
		_inventory_children(node, descendants)
		rows.append({"path": str(node.get_path()), "class": "PlainsRegionScenery", "child_count": node.get_child_count(), "descendants": descendants, "declared_area_roles": node.manifest.areas.map(func(a: Dictionary): return {"id": a.id, "role": a.role, "landmark": a.get("landmark", "")}), "support_count": node.supports.size()})
	for child: Node in node.get_children(): scenery_inventory(child, rows)

func _inventory_children(node: Node, rows: Array) -> void:
	for child: Node in node.get_children():
		var row := {"path": str(child.get_path()), "name": str(child.name), "class": child.get_class()}
		if child is Node2D: row["position"] = SNAPSHOT.pair(child.global_position)
		if child is Sprite2D:
			row["texture"] = child.texture.resource_path if child.texture != null else ""
			row["texture_class"] = child.texture.get_class() if child.texture != null else "none"
			row["role"] = "atmospheric_veil_not_landmark" if child.texture is GradientTexture2D else "scenery_prop"
			row["scale"] = SNAPSHOT.pair(child.scale)
		rows.append(row)
		_inventory_children(child, rows)

func capture_frame(force: bool = false) -> void:
	if frame_dir.is_empty() or _capture_busy or driver == null: return
	if not force and (driver.trace_ticks == _last_frame or driver.trace_ticks % frame_stride != 0): return
	_capture_busy = true
	var tick: int = driver.trace_ticks
	_last_frame = tick
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var file := frame_dir.path_join("frame_%06d.png" % tick)
	var error := image.save_png(file)
	_screen_records.append({"tick": tick, "path": file, "sha256": FileAccess.get_sha256(file) if error == OK else "", "width": image.get_width(), "height": image.get_height(), "error": error, "edge": driver.current_edge})
	_capture_busy = false

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source-commit="): source_commit = arg.trim_prefix("--source-commit=")
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--seed="): seed_value = arg.trim_prefix("--seed=")
		elif arg.begins_with("--strategy="): strategy = arg.trim_prefix("--strategy=")
		elif arg.begins_with("--map-index="): map_index = arg.trim_prefix("--map-index=").to_int()
		elif arg.begins_with("--phase-wait-ticks="): phase_wait_ticks = arg.trim_prefix("--phase-wait-ticks=").to_int()
		elif arg.begins_with("--max-ticks="): max_ticks = arg.trim_prefix("--max-ticks=").to_int()
		elif arg.begins_with("--frame-dir="): frame_dir = arg.trim_prefix("--frame-dir=")
		elif arg.begins_with("--frame-stride="): frame_stride = arg.trim_prefix("--frame-stride=").to_int()
		elif arg == "--capture-visible": visible_capture = true
	report = {"schema_version": 1, "artifact_kind": "formal_level_capture", "source_commit": source_commit, "engine": Engine.get_version_info().string, "root_seed": seed_value, "map_index": map_index, "profile": "intro" if map_index == 1 else "advanced", "strategy": strategy, "phase_wait_ticks": phase_wait_ticks, "physics_hz": Engine.physics_ticks_per_second, "capture_errors": [], "outcome": "initializing"}
	if source_commit.length() != 40 or not source_commit.is_valid_hex_number(false) or strategy not in ["fast", "growth", "deep", "return"] or map_index not in [1, 2] or phase_wait_ticks < 0 or phase_wait_ticks > 600 or max_ticks < 1 or max_ticks > 36000 or frame_stride < 1:
		_startup_failed("invalid bounded capture request")
		return
	if not frame_dir.is_empty() and (not visible_capture or DisplayServer.get_name() == "headless"):
		_startup_failed("screenshots require a real rendering display and --capture-visible")
		return
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	if not frame_dir.is_empty(): DirAccess.make_dir_recursive_absolute(frame_dir)
	report["captured_scope"] = {"consumer": "live DemoApp + PlainsRegionStage", "enemies_instantiated": true, "enemy_tick_owner": "EnemyActor._physics_process calls physics_tick; EnemyMotor self-physics flag is not enemy activity", "enemy_attacks_enabled": true, "enemy_contacts_enabled": true, "environment_damage_enabled": true, "production_rewards_enabled": true, "production_camera_enabled": true, "input": "synthetic InputRouter requests through normally scheduled PlayerController", "reward_choice_input": "production modal callback; not physical GUI", "controller_manual_step": false, "actor_teleport_by_driver": false, "resource_injection": false, "enemy_disable": false, "boss_fight_completion": false, "campaign_map1_to_map2_completion": false, "device_acceptance": "unverified", "subjective_acceptance": "unverified", "rendered_screenshots": not frame_dir.is_empty(), "enemy_strategy": "existing movement policy; evade by traversal, no blanket enemy-kill requirement"}
	report["entry_context"] = "normal formal map1 start" if map_index == 1 else "independent map2 test entry via actual director stage setup and DemoApp loader; no map1 Boss defeat or campaign transition claim"
	report["capture_source_hashes"] = {}
	for path: String in ["res://tools/level_formal_capture.gd", "res://tests/level_formal_trace.gd", "res://tests/plains_region_trace.gd", "res://tests/plains_run_trace.gd", "res://tests/random_stage_tests.gd"]: report.capture_source_hashes[path] = FileAccess.get_sha256(path)
	app = DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	if not app.start_plains(seed_value):
		_startup_failed("formal start rejected")
		return
	for unused: int in 120:
		await physics_frame
		await process_frame
		if not app._stage_pending and app.stage is PlainsRegionStage: break
	if not app.stage is PlainsRegionStage or app._stage_pending:
		_startup_failed("formal stage did not become ready")
		return
	if map_index == 2:
		# Test setup only: use real stage loader without forging a mini-Boss kill,
		# completion flag, reward receipt or campaign-transition event.
		app.lifetime.stage_epoch += 1
		app.lifetime.actor_epoch += 1
		app.director._enter_stage(2, &"boss")
		app._stage_entered(DemoRunResult.new())
		for unused: int in 120:
			await physics_frame
			await process_frame
			if not app._stage_pending and app.stage is PlainsRegionStage and app.stage.map_index == 2: break
	if not app.stage is PlainsRegionStage or app._stage_pending or app.stage.map_index != map_index:
		_startup_failed("requested map test entry failed")
		return
	var stage := app.stage as PlainsRegionStage
	report["manifest"] = stage.generated.manifest.duplicate(true)
	report["formal_run_manifest_initial"] = app.director.manifest.snapshot()
	report["seed"] = stage.generated.manifest.seed
	report["manifest_hash"] = stage.generated.manifest.manifest_hash
	report["initial_scenery_inventory"] = []
	scenery_inventory(stage, report.initial_scenery_inventory)
	driver = TRACE.new()
	if not driver.attach(app, strategy, phase_wait_ticks):
		_startup_failed("live driver attachment failed")
		return
	driver.frame_budget = max_ticks
	if not frame_dir.is_empty(): await capture_frame(true)
	driver.run_route.call_deferred()
	while not driver.finished and not driver.terminated:
		await process_frame
		if not frame_dir.is_empty(): capture_frame()
	while _capture_busy: await process_frame
	if not frame_dir.is_empty() and is_instance_valid(app.player): await capture_frame(true)
	if not driver.finished and not driver.current_edge.is_empty():
		driver.observed_edges.append({"id": driver.current_edge, "start_tick": int(driver.observed_edges.back().end_tick) + 1 if not driver.observed_edges.is_empty() else 1, "end_tick": driver.trace_ticks + 1, "reached": false, "aborted": true, "outcome": driver.outcome})
	report["terminal_observation"] = {"tick": driver.trace_ticks + 1, "capability": driver.final_capability, "runtime": driver.final_runtime} if driver.terminated else {}
	report["outcome"] = driver.outcome
	report["route_reached"] = driver.finished and driver.outcome == "route_target_reached"
	report["frames"] = driver.observed_frames
	report["edges"] = driver.observed_edges
	report["events"] = driver.events
	report["driver_diagnostics"] = driver.diagnostics
	report["initial_capability"] = driver.initial_capability
	report["final_capability"] = driver.final_capability
	report["initial_runtime"] = driver.initial_runtime
	report["final_runtime"] = driver.final_runtime
	report["formal_run_manifest_final"] = app.director.manifest.snapshot()
	report["screenshots"] = _screen_records
	report["tick_count"] = driver.trace_ticks
	if driver.observed_frames.is_empty(): report.capture_errors.append("empty observation trace")
	if not save_report():
		print("LEVEL FORMAL CAPTURE ERROR: cannot write output")
		quit(2)
		return
	print("LEVEL FORMAL CAPTURE: %d frames, %d edges, outcome=%s, capture_errors=%d" % [driver.observed_frames.size(), driver.observed_edges.size(), driver.outcome, report.capture_errors.size()])
	quit(0 if report.capture_errors.is_empty() else 2)
