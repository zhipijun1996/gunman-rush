extends "res://tools/spatial_golden_preview.gd"
## Manual full-region review, original controls and close lifecycle; no automation.
func _initialize() -> void:
	auto_accept_quit = false
	root.close_requested.connect(close_review)
	review_seed = "regional-art-01"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): review_seed = arg.trim_prefix("--seed=")
		elif arg == "--smoke-close": smoke_close = true
		else: push_error("Unsupported regional review argument");quit(2);return
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	root.title = "失序之钟 · 完整平原联合美术实验（未正式准入）"
	app = make_review_application()
	app.set("plains_regional_art_candidate_requested",true)
	app.avatar_selection_id = "p1_girl"
	app.meta_persistence_enabled = false
	root.add_child(app)
	if not app.start_plains(review_seed):
		push_error("Regional art review start rejected");await close_review();return
	for unused: int in 180:
		await physics_frame
		await process_frame
		if not app._stage_pending and app.stage is PlainsRegionStage:
			if not app.stage.has_method("get_regional_art_snapshot"):
				push_error("Actual regional consumer missing");await close_review();return
			var snapshot: Dictionary = app.stage.call("get_regional_art_snapshot")
			if not snapshot.get("ready",false):
				push_error("Actual regional art not ready");await close_review();return
			print("PLAINS REGIONAL ART REVIEW READY: ",JSON.stringify(snapshot))
			var adapter := app.get_meta("avatar_presentation",null) as Node
			var avatar: Dictionary = adapter.call("snapshot") if is_instance_valid(adapter) else {}
			if avatar.get("selected_id")!="p1_girl" or avatar.get("painted_owner_count")!=1:
				push_error("Regional review actual avatar missing or duplicated");await close_review();return
			print("PLAINS REGIONAL ART AVATAR READY: ",JSON.stringify(avatar))
			print("Manual controls only; no route driver, save writes or formal art admission")
			if smoke_close: await close_review()
			return
	push_error("Regional art review stage timeout")
	await close_review()

func make_review_application() -> DemoApp:
	return DemoApp.new()
