extends "res://tests/world/plains_intro.gd"
## Native presentation recording: declared station and reward-side starts, actual interactions.
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_feedback_capture.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);app.start_new();await settle();app.load_room("P-R01","");await settle()
	app.player.reset_at(Vector2(560,622));await ticks(90)
	app.controller.router.request_action(&"interact");await ticks(90)
	check(app.ui.page=="dialogue","actual nearby NPC portrait and dialogue")
	app._close_panel();await walk(Vector2(320,622),"P-R01")
	app.controller.router.request_action(&"interact");await ticks(70)
	check(app.state.value.rest.room=="P-R01","rest light and heal cue follow committed rest")
	app.load_room("P-R12","");await settle();app.player.reset_at(Vector2(1104,494));await ticks(60)
	app.controller.router.request_action(&"interact");await ticks(50)
	check(app.state.value.receipts.has("pickup_EQ_MAP_P01"),"bag disappears and collection burst follows committed receipt")
	await walk(Vector2(1152,494),"P-R12");app.controller.router.request_action(&"interact");await ticks(80)
	check(app.state.has("reward_return_EQ_MAP_P01_open"),"unfolded return and bell follow accepted interaction")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8);print("PLAINS FEEDBACK CAPTURE: ",failures," failures");quit(failures)
