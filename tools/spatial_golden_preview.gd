extends SceneTree
## Explicit local review entry. No automatic gameplay driver or save writes.
var app: DemoApp
var closing := false
var review_seed := "against-wind-golden-v1"

func _initialize() -> void:
	auto_accept_quit = false
	root.close_requested.connect(close_review)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): review_seed = arg.trim_prefix("--seed=")
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.title = "失序之钟 · 实验黄金空间本地评审（未正式准入）"
	app = DemoApp.new()
	app.spatial_golden_requested = true
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
