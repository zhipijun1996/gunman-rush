extends SceneTree
## Explicit local review entry. No automatic gameplay driver or save writes.
const VISUAL_SAMPLE_CATALOGS := ["res://resources/visual_development/candidate.json", "res://resources/visual_development/painted_terrain_candidate.json", "res://resources/visual_development/p1_candidate.json"]
var app: DemoApp
var closing := false
var review_seed := "against-wind-golden-v1"
var visual_sample := ""
var open_meadow := false
var formal_painted := false
var explicit_seed := false
var smoke_close := false # Explicit startup/lifecycle test; never drives input.

func _initialize() -> void:
	auto_accept_quit = false
	root.close_requested.connect(close_review)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): review_seed = arg.trim_prefix("--seed=");explicit_seed=true
		elif arg=="--formal-painted":formal_painted=true
		elif arg=="--smoke-close":smoke_close=true
		elif arg.begins_with("--visual-layout="):
			if arg.trim_prefix("--visual-layout=") != "open-meadow":
				push_error("Unsupported explicit visual layout")
				quit(2)
				return
			open_meadow = true
		elif arg.begins_with("--visual-sample="):
			visual_sample = arg.trim_prefix("--visual-sample=")
			if visual_sample not in VISUAL_SAMPLE_CATALOGS:
				push_error("Unsupported explicit visual sample catalog")
				quit(2)
				return
	if formal_painted:
		if open_meadow or visual_sample not in ["","res://resources/visual_development/painted_terrain_candidate.json"]:
			push_error("Formal painted review preserves formal geometry and uses only its admitted candidate catalog")
			quit(2);return
		visual_sample="res://resources/visual_development/painted_terrain_candidate.json"
		if not explicit_seed:review_seed="level-design-v2-baseline/08"
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.title = "失序之钟 · 正式几何两薄岸表现候选（后段保留原貌）" if formal_painted else "失序之钟 · 实验黄金空间本地评审（未正式准入）"
	app = DemoApp.new()
	app.spatial_golden_requested = not formal_painted
	app.set("visual_language_sample_path", visual_sample)
	app.set("visual_language_open_meadow_requested", open_meadow)
	app.meta_persistence_enabled = false
	root.add_child(app)
	if not app.start_plains(review_seed):
		push_error("Spatial golden review start rejected")
		await close_review()
		return
	for unused: int in 180:
		await physics_frame
		await process_frame
		if not app._stage_pending and app.stage is PlainsRegionStage:
			if formal_painted:
				var painted := load("res://scripts/art/painted_formal_terrain_sample.gd").new() as Node2D
				app.stage.add_child(painted);painted.call("install",app.stage)
				var actual: Dictionary=painted.call("measured_nodes")
				if actual.get("status","")!="candidate_installed_not_art_admitted" or actual.get("selected",[]).size()!=2 or actual.get("actors",{}).get("hero_states",[]).size()<1 or not actual.get("actors",{}).get("saw",false):
					push_error("Formal painted manual consumer failed; baseline preserved on refused geometry")
					await close_review();return
				print("FORMAL PAINTED REVIEW CONSUMER READY: ",JSON.stringify(actual))
				print("FORMAL PAINTED REVIEW READY: normal start_plains, two thin banks only; manual input; no automatic driver, teleport, promotion or save writes; seed=",review_seed)
				if smoke_close:await close_review()
				return
			if not visual_sample.is_empty():
				var observed: Dictionary = {}
				for child: Node in app.stage.get_children():
					if child.has_method("measured_nodes"):
						observed = child.call("measured_nodes")
				if str(observed.get("catalog_path", "")) != visual_sample or str(observed.get("catalog_sha256", "")) != FileAccess.get_sha256(visual_sample) or not bool(observed.get("root_body", false)) or not bool(observed.get("saw", false)):
					push_error("Explicit visual review consumer failed to load candidate catalog, enemy or saw")
					await close_review()
					return
				print("VISUAL LANGUAGE REVIEW CONSUMER READY: ", JSON.stringify(observed))
			print("SPATIAL GOLDEN REVIEW READY: explicit development map1 via normal start_plains; manual input only; no automatic driver, teleport, formal promotion or save writes; seed=", review_seed)
			return
	push_error("Spatial golden review stage timeout")
	await close_review()

func close_review() -> void:
	if closing: return
	closing = true
	paused = true
	var released := true
	if is_instance_valid(app):
		if is_instance_valid(app.controller): app.controller.router.clear("review_close")
		for child: Node in app.get_children():
			if child is GameAudio:
				released = await preload("res://tools/observed_audio_teardown.gd").drain_service(child) and released
		app.queue_free()
		app = null
		await process_frame
		await process_frame
	if not released: push_error("Spatial golden review audio release timeout")
	quit(0 if released else 2)
