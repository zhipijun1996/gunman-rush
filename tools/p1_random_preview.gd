extends "res://tools/spatial_golden_preview.gd"
## Ordinary generated plains, original manual controls and inherited bounded cleanup.
var selected_avatar := "p1_girl"

func _initialize() -> void:
	auto_accept_quit=false
	root.close_requested.connect(close_review)
	review_seed="level-design-v2-baseline/01"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):review_seed=arg.trim_prefix("--seed=")
		elif arg.begins_with("--avatar=") and arg.trim_prefix("--avatar=") in ["courier","p1_traveller","p1_girl"]:selected_avatar=arg.trim_prefix("--avatar=")
		elif arg=="--smoke-close":smoke_close=true
		else:
			push_error("Unsupported explicit random-plains review argument")
			quit(2);return
	run.call_deferred()

func run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
	root.title="失序之钟 · P1随机平原与外观本地评审"
	app=DemoApp.new()
	app.p1_random_plains_requested=true
	app.avatar_selection_id=selected_avatar
	app.meta_persistence_enabled=false
	root.add_child(app)
	if not app.start_plains(review_seed):
		push_error("Ordinary random-plains review start rejected")
		await close_review();return
	for unused: int in 180:
		await physics_frame;await process_frame
		if not app._stage_pending and app.stage is PlainsRegionStage:
			var coverage: Dictionary=app.stage.get_meta("p1_random_coverage",{})
			var avatar: Dictionary=(app.get_meta("avatar_presentation") as Node).call("snapshot")
			var expected_owners := 0 if selected_avatar=="courier" else 1
			if coverage.get("selected",[]).is_empty() or coverage.get("collision_changed",true) or avatar.get("selected_id","")!=selected_avatar or avatar.get("painted_owner_count",-1)!=expected_owners or avatar.get("hero_states",[]).is_empty():
				push_error("Actual random-plains presentation/avatar consumer failed")
				await close_review();return
			print("P1 RANDOM REVIEW CONSUMER READY: ",JSON.stringify({"seed":review_seed,"manifest":app.stage.generated.manifest,"coverage":coverage,"avatar":avatar,"geometry":"ordinary generator, no golden or two-bank replacement"}))
			print("P1 RANDOM REVIEW READY: normal start_plains; manual input only; no driver, teleport or save writes")
			if smoke_close:await close_review()
			return
	push_error("Ordinary random-plains review stage timeout")
	await close_review()
