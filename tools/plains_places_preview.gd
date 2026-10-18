extends "res://tools/spatial_golden_preview.gd"
## Manual controls only. Reuse the original bounded audio/scene close lifecycle.

func _initialize() -> void:
	auto_accept_quit = false
	root.close_requested.connect(close_review)
	review_seed = "plains-places-first-01"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): review_seed = arg.trim_prefix("--seed=")
		elif arg == "--smoke-close": smoke_close = true
		else:
			push_error("Unsupported explicit places review argument")
			quit(2)
			return
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.title = "失序之钟 · 风铃平原场所原型实验（未正式准入）"
	app = DemoApp.new()
	app.set("plains_places_candidate_requested", true)
	app.avatar_selection_id = "p1_girl"
	app.meta_persistence_enabled = false
	root.add_child(app)
	if not app.start_plains(review_seed):
		push_error("Places review start rejected")
		await close_review()
		return
	for unused: int in 180:
		await physics_frame
		await process_frame
		if not app._stage_pending and app.stage is PlainsRegionStage:
			if not app.stage.has_method("get_environment_snapshot") or not app.stage.get("environment_plan") is Dictionary:
				push_error("Places review actual consumer missing")
				await close_review()
				return
			print("PLAINS PLACES REVIEW READY: ", JSON.stringify(app.stage.call("get_environment_snapshot")))
			var avatar: Dictionary = (app.get_meta("avatar_presentation") as Node).call("snapshot")
			if avatar.get("selected_id") != "p1_girl" or avatar.get("painted_owner_count") != 1:
				push_error("Places review actual avatar missing or duplicated")
				await close_review()
				return
			print("PLAINS PLACES AVATAR READY: ", JSON.stringify(avatar))
			print("Manual controls only; explicit independent candidate; no route driver or save writes")
			if smoke_close: await close_review()
			return
	push_error("Places review stage timeout")
	await close_review()
