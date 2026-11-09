extends "res://tests/world/service_ui.gd"
## Explicit presentation fixtures, not a record of acquired exploration.
func capture(label: String) -> void:
	await ticks(12);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/plains_rework/captures/"+label+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/plains_rework/captures")
	root.size=Vector2i(1280,720)
	app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_ui_capture.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);app.start_new();await settle();app.load_room("P-R01","");await settle()
	app.player.reset_at(Vector2(560,622));await ticks(5);app.controller.router.request_action(&"interact");await ticks(8)
	await capture("ui-reclaimer")
	await click_named("查看服务");await capture("ui-services")
	await click_named("告别");app.player.reset_at(Vector2(1152,622));await ticks(5);app.controller.router.request_action(&"interact");await ticks(8)
	await capture("ui-aqi-tea")
	root.size=Vector2i(960,540);await capture("ui-aqi-960")
	app._close_panel();app._pause_world();app.ui.show_pause();await capture("ui-pause-960")
	check(app.ui.shell.rows.get_combined_minimum_size().y<=app.ui.shell.scroll.size.y+1,"small pause exposes all five choices without clipping")
	app._close_panel();root.size=Vector2i(1280,720)
	var candidate:=app.state.value.duplicate(true)
	for rid: String in app.content.data.rooms:
		if rid not in candidate.explored:candidate.explored.append(rid)
	app.state.commit(candidate,app.state.revision);app._pause_world();app.ui.show_map();await capture("ui-map-survey")
	var map: Node
	for node: Node in app.ui.shell.find_children("*","FixedWorldMap",true,false):map=node
	if map is FixedWorldMap:map.focus_player();await capture("ui-map-station")
	app._close_panel();await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8);print("PLAINS UI CAPTURE: ",failures," failures");quit(failures)
