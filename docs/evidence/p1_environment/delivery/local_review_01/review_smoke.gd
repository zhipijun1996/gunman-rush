extends "res://tools/plains_environment_preview.gd"
func run() -> void:
	await super.run()
	if app == null or closing: return
	for unused: int in 90:
		await physics_frame
		await process_frame
	var image_path := OS.get_environment("REVIEW_SCREENSHOT_PATH")
	if not image_path.is_empty():
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(image_path) != OK:
			push_error("Candidate package GUI image failed")
	await close_review()
	print("ENVIRONMENT PACK SMOKE COMPLETE: original manual entry; bounded app/audio release; no gameplay driver")
