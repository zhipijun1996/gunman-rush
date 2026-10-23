extends SceneTree
## Keep the production DemoApp, encounters, contacts, rewards and camera alive.
## Exit 0 means evidence captured, not that the input policy completed the route.
const TRACE := preload("res://tests/level_formal_trace.gd")
const SNAPSHOT := preload("res://tools/level_capability_snapshot.gd")
var output := "res://build/level_formal/capture.json"
var source_commit := ""
var seed_value := "level-design-v2-baseline"
var strategy := "fast"
var encounter_policy := "blind_legacy"
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
			if child.texture is AtlasTexture:
				var atlas_texture := child.texture as AtlasTexture
				row["texture_atlas"] = atlas_texture.atlas.resource_path if atlas_texture.atlas != null else ""
				row["texture_region"] = [atlas_texture.region.position.x, atlas_texture.region.position.y, atlas_texture.region.size.x, atlas_texture.region.size.y]
			if child.has_meta("landmark"):
				var landmark: Dictionary = child.get_meta("landmark")
				row["landmark"] = landmark.duplicate(true)
				row["landmark_id"] = str(landmark.get("asset_id", ""))
			row["role"] = "atmospheric_veil_not_landmark" if child.texture is GradientTexture2D else "scenery_prop"
			row["scale"] = SNAPSHOT.pair(child.scale)
		rows.append(row)
		_inventory_children(child, rows)

func capture_frame(force: bool = false) -> void:
	if frame_dir.is_empty() or _capture_busy or driver == null: return
	if driver.trace_ticks == _last_frame: return
	if not force and driver.trace_ticks % frame_stride != 0: return
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
		elif arg.begins_with("--encounter-policy="): encounter_policy = arg.trim_prefix("--encounter-policy=")
		elif arg.begins_with("--map-index="): map_index = arg.trim_prefix("--map-index=").to_int()
		elif arg.begins_with("--phase-wait-ticks="): phase_wait_ticks = arg.trim_prefix("--phase-wait-ticks=").to_int()
		elif arg.begins_with("--max-ticks="): max_ticks = arg.trim_prefix("--max-ticks=").to_int()
		elif arg.begins_with("--frame-dir="): frame_dir = arg.trim_prefix("--frame-dir=")
		elif arg.begins_with("--frame-stride="): frame_stride = arg.trim_prefix("--frame-stride=").to_int()
		elif arg == "--capture-visible": visible_capture = true
	report = {"schema_version": 1, "artifact_kind": "formal_level_capture", "source_commit": source_commit, "engine": Engine.get_version_info().string, "root_seed": seed_value, "map_index": map_index, "profile": "intro" if map_index == 1 else "advanced", "strategy": strategy, "phase_wait_ticks": phase_wait_ticks, "physics_hz": Engine.physics_ticks_per_second, "capture_errors": [], "outcome": "initializing"}
	if source_commit.length() != 40 or not source_commit.is_valid_hex_number(false) or encounter_policy not in ["blind_legacy", "kill_from_bank_v1", "kill_from_bank_v2", "bait_then_bypass_v1"] or strategy not in ["fast", "growth", "deep", "return"] or map_index not in [1, 2] or phase_wait_ticks < 0 or phase_wait_ticks > 600 or max_ticks < 1 or max_ticks > 36000 or frame_stride < 1:
		_startup_failed("invalid bounded capture request")
		return
	if not frame_dir.is_empty() and (not visible_capture or DisplayServer.get_name() == "headless"):
		_startup_failed("screenshots require a real rendering display and --capture-visible")
		return
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	if not frame_dir.is_empty(): DirAccess.make_dir_recursive_absolute(frame_dir)
	report["captured_scope"] = {"consumer": "live DemoApp + PlainsRegionStage", "enemies_instantiated": true, "enemy_tick_owner": "EnemyActor._physics_process calls physics_tick; EnemyMotor self-physics flag is not enemy activity", "enemy_attacks_enabled": true, "enemy_contacts_enabled": true, "environment_damage_enabled": true, "production_rewards_enabled": true, "production_camera_enabled": true, "input": "synthetic InputRouter requests through normally scheduled PlayerController", "reward_choice_input": "production modal callback; not physical GUI", "controller_manual_step": false, "actor_teleport_by_driver": false, "resource_injection": false, "enemy_disable": false, "boss_fight_completion": false, "campaign_map1_to_map2_completion": false, "device_acceptance": "unverified", "subjective_acceptance": "unverified", "rendered_screenshots": not frame_dir.is_empty(), "enemy_strategy": "existing movement policy; evade by traversal, no blanket enemy-kill requirement"}
	if encounter_policy != "blind_legacy": report.captured_scope.enemy_strategy = encounter_policy + "; privileged actual manifest/AI state, not human perception or fairness acceptance"
	report["capture_contract_version"] = 3
	report.captured_scope["resource_claim_evidence"] = "v3: aware resource choices bind actual offer, final cache and complete native wallet/HP/meta ledgers; unselected item/build paths unverified"
	report["runtime_source_hashes"] = runtime_source_hashes()
	report["encounter_policy"] = encounter_policy
	report["policy_basis"] = policy_basis()
	report["entry_context"] = "normal formal map1 start" if map_index == 1 else "independent map2 test entry via actual director stage setup and DemoApp loader; no map1 Boss defeat or campaign transition claim"
	report["capture_source_hashes"] = {}
	for path: String in ["res://tools/level_formal_capture.gd", "res://scripts/art/plains_region_scenery.gd", "res://tests/level_formal_trace.gd", "res://tests/plains_region_trace.gd", "res://tests/plains_run_trace.gd", "res://tests/random_stage_tests.gd"]: report.capture_source_hashes[path] = FileAccess.get_sha256(path)
	app = make_application()
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
		# New campaign directors separate global stage and local region map.
		# Historical directors have only stage_index and retain the old path.
		for property: Dictionary in app.director.get_property_list():
			if property.name=="region_map_index": app.director.set("region_map_index",2)
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
	var expected_seed := PlainsRegionCampaign.seed_for(seed_value,map_index)
	var expected_difficulty := "intro" if map_index==1 else "advanced"
	if str(stage.generated.manifest.seed)!=expected_seed or str(stage.generated.manifest.difficulty)!=expected_difficulty or str(stage.generated.manifest.region)!="plains":
		_startup_failed("requested map Manifest identity failed")
		return
	report["actual_stage_identity"]={"map_index":stage.map_index,"manifest_seed":str(stage.generated.manifest.seed),"manifest_difficulty":str(stage.generated.manifest.difficulty),"region":str(stage.generated.manifest.region)}
	report["manifest"] = stage.generated.manifest.duplicate(true)
	report["formal_run_manifest_initial"] = app.director.manifest.snapshot()
	report["seed"] = stage.generated.manifest.seed
	report["manifest_hash"] = stage.generated.manifest.manifest_hash
	report["initial_scenery_inventory"] = []
	scenery_inventory(stage, report.initial_scenery_inventory)
	driver = make_driver()
	if not driver.attach(app, strategy, phase_wait_ticks, encounter_policy):
		_startup_failed("live driver attachment failed")
		return
	driver.frame_budget = max_ticks
	driver.visible_input_post_draw = visible_capture and DisplayServer.get_name() != "headless"
	driver.observe_input_timing = driver.visible_input_post_draw
	report.captured_scope["input_transport_protocol"] = "visible_post_draw_v1" if driver.visible_input_post_draw else "legacy_physics_process_v1"
	report.captured_scope["input_timing_scope"] = "observer_preconsume_boundary_not_controller_receipt" if driver.observe_input_timing else "not_instrumented"
	if not frame_dir.is_empty(): await capture_frame(true)
	if driver.visible_input_post_draw:
		# Include the initial request, not only continuations from tick().
		await RenderingServer.frame_post_draw
		driver.run_route()
	else:
		driver.run_route.call_deferred()
	while not driver.finished and not driver.terminated:
		await process_frame
		if not frame_dir.is_empty(): capture_frame()
	while _capture_busy: await process_frame
	if not frame_dir.is_empty() and is_instance_valid(app.player): await capture_frame(true)
	if not driver.finished and not driver.current_edge.is_empty():
		driver.observed_edges.append({"id": driver.current_edge, "start_tick": int(driver.observed_edges.back().end_tick) + 1 if not driver.observed_edges.is_empty() else 1, "end_tick": driver.trace_ticks + (1 if driver.events.any(func(e:Dictionary):return e.kind=="run_ended" and e.tick==driver.trace_ticks+1) else 0), "reached": false, "aborted": true, "outcome": driver.outcome})
	report["terminal_observation"] = {"tick": driver.trace_ticks + 1, "capability": driver.final_capability, "runtime": driver.final_runtime} if driver.terminated else {}
	report["outcome"] = driver.outcome
	report["route_reached"] = driver.finished and driver.outcome == "route_target_reached"
	report["frames"] = driver.observed_frames
	report["edges"] = driver.observed_edges
	report["events"] = driver.events
	report["driver_diagnostics"] = driver.diagnostics
	report["policy_observations"] = driver.policy_observations
	report["resource_receipts"] = driver.resource_receipts
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
	# The completed input/physics trace is immutable before teardown. AudioServer
	# releases stopped playback asynchronously; boundedly drain the real backend
	# instead of ignoring resource errors at process exit. These wall seconds and
	# additional rendered transport frames are not gameplay/case duration.
	var cleanup_started := Time.get_ticks_usec()
	var audio_released := true
	audio_released = await preload("res://tests/audio_teardown.gd").drain_world(app)
	report["post_capture_cleanup"] = {"scope":"after_final_observed_frame; not gameplay or driver time", "audio_backend_released":audio_released, "audio_drain_seconds":(Time.get_ticks_usec()-cleanup_started)/1000000.0, "per_service_timeout_msec":1000}
	if not audio_released: report.capture_errors.append("audio backend release timeout after completed capture")
	if not save_report():
		print("LEVEL FORMAL CAPTURE ERROR: cannot save cleanup receipt")
		quit(2)
		return
	print("LEVEL FORMAL CAPTURE: %d frames, %d edges, outcome=%s, capture_errors=%d" % [driver.observed_frames.size(), driver.observed_edges.size(), driver.outcome, report.capture_errors.size()])
	quit(0 if report.capture_errors.is_empty() else 2)

func collect_driver_sources(path: String, found: Dictionary) -> void:
	if found.has(path): return
	found[path] = FileAccess.get_sha256(path)
	var regex := RegEx.new()
	regex.compile("res://(?:tests|tools)/[a-zA-Z0-9_/]+[.]gd")
	for match_value: RegExMatch in regex.search_all(FileAccess.get_file_as_string(path)):
		collect_driver_sources(match_value.get_string(), found)

func collect_core_sources(folder: String, found: Dictionary) -> void:
	for filename: String in DirAccess.get_files_at(folder):
		if filename.get_extension() in ["gd", "json", "tres", "tscn", "gdshader"]:
			var path := folder.path_join(filename)
			found[path] = FileAccess.get_sha256(path)
	for dirname: String in DirAccess.get_directories_at(folder): collect_core_sources(folder.path_join(dirname), found)

func runtime_source_hashes() -> Dictionary:
	var found: Dictionary = {"res://project.godot":FileAccess.get_sha256("res://project.godot")}
	for folder: String in ["res://scripts","res://scenes","res://resources","res://config","res://shaders","res://assets"]:
		if DirAccess.dir_exists_absolute(folder):collect_core_sources(folder,found)
	return found

func policy_basis() -> Dictionary:
	var driver_sources: Dictionary = {}
	collect_driver_sources("res://tools/level_formal_capture.gd",driver_sources)
	for path: String in ["res://tools/level_formal.py","res://tools/level_design.py","res://tools/godot.sh"]: driver_sources[path]=FileAccess.get_sha256(path)
	var core: Dictionary = {"res://project.godot":FileAccess.get_sha256("res://project.godot"),"res://assets/characters/courier/courier_visual.gd":FileAccess.get_sha256("res://assets/characters/courier/courier_visual.gd")}
	for folder: String in ["res://scripts/player","res://scripts/input","res://scripts/combat","res://scripts/damage","res://scripts/resources","res://scripts/actors","res://scripts/builds","res://scripts/meta","res://scripts/rewards","res://scripts/shops","res://scripts/save","res://scripts/run","res://resources/player","res://resources/actors","res://resources/items","res://resources/weapons","res://config","res://scenes/player"]:
		if DirAccess.dir_exists_absolute(folder):collect_core_sources(folder,core)
	return {"schema_version":1,"encounter_policy":encounter_policy,"reward_policy":"legacy_auto_claim_v1" if encounter_policy=="blind_legacy" else "two_actual_medium_and_camp_v1","driver_sources":driver_sources,"core_invariants":core,"content_differences":"Full per-side receipt source inventory retained; generator/scenery/DemoApp differences require independent content review, not inferred semantic equivalence"}

func make_application() -> DemoApp:
	return DemoApp.new()

func make_driver() -> RefCounted:
	return TRACE.new()
