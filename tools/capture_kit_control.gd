extends SceneTree
## Deliberately misuse the old fixed plate to expose its actual limits.
const OUTPUT := "res://build/kit-reuse/"
func _initialize() -> void: run.call_deferred()
func shot(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUTPUT+file)==OK)
func run() -> void:
	root.size = Vector2i(1280,720)
	var scene: Node2D = load("res://game/presentation/experiments/engine_first_2d/room.tscn").instantiate()
	root.add_child(scene)
	while not scene.ready_to_capture: await process_frame
	scene.water.hide();scene.water_front.hide()
	scene.light.enabled = false
	await shot("control-fixed.png")
	scene.slices[0].position = Vector2(96,0)
	await shot("control-forced-parallax.png")
	scene.slices[0].position = Vector2.ZERO
	var camera := root.get_camera_2d()
	camera.position += Vector2(240,120)
	camera.force_update_scroll()
	await shot("control-moved-camera.png")
	quit()
