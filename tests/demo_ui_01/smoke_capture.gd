extends SceneTree
var app: DemoApp
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i: int in n: await process_frame
func shot(name: String) -> void:
	await frames(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/verification/demo-ui-01-01/"+name+".png")
func run() -> void:
	root.size = Vector2i(1280,720)
	app = DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	await shot("title")
	app.menu.show_pause()
	await shot("pause")
	app.menu.hide_home()
	paused = false
	app.start_plains("level-design-v2-baseline/08")
	await frames(12)
	await shot("hud")
	app.open_region_map()
	await shot("map")
	app.close_region_map()
	app.free()
	await frames(6)
	print("DEMO UI SMOKE COMPLETE")
	quit()
