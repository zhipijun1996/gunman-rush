extends SceneTree
## Genuine rendered movement demonstration. No transform writes after lab spawn.
## Input is produced after each real post-draw boundary, retaining Router TTL.
var style_id := "retro"
var biome_id := "plains"
var report_path := "res://build/style_exploration/motion.json"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--style="): style_id = arg.trim_prefix("--style=")
		elif arg.begins_with("--biome="): biome_id = arg.trim_prefix("--biome=")
		elif arg.begins_with("--motion-report="): report_path = arg.trim_prefix("--motion-report=")
	var lab := preload("res://experiments/terrain/entries/style_lab.tscn").instantiate() as StyleLab
	lab.default_style = style_id
	root.add_child(lab)
	lab.select_biome(biome_id)
	for adapter: String in ["KeyboardMouseAdapter", "GamepadAdapter"]:
		lab.player.get_node(adapter).process_mode = Node.PROCESS_MODE_DISABLED
	lab.overlay.hide()
	var jumps := [0]
	lab.controller.jump_ability.jumped.connect(func() -> void: jumps[0] += 1)
	var initial_epoch := lab.lifetime.actor_epoch
	var initial_steps := lab.player.motion_steps
	var held := 0
	var direction := 1.0
	var observations: Array[Dictionary] = []
	for frame: int in 480:
		await RenderingServer.frame_post_draw
		if frame < 60:
			lab.controller.router.set_move_axis(0)
		else:
			if lab.player.position.x > 2460: direction = -1.0
			lab.controller.router.set_move_axis(direction)
			if lab.player.is_on_floor() and lab.player.is_on_wall() and held == 0:
				lab.controller.router.set_jump_held(&"motion_capture", true)
				held = 8
			elif held > 0:
				held -= 1
				if held == 0: lab.controller.router.set_jump_held(&"motion_capture", false)
		if frame % 30 == 0:
			observations.append({"video_frame": frame, "player": [lab.player.position.x, lab.player.position.y], "camera_node": [lab.camera.position.x, lab.camera.position.y], "screen_center": [lab.camera.get_screen_center_position().x, lab.camera.get_screen_center_position().y]})
	lab.controller.router.clear("motion_capture_end")
	var data := {"kind": "rendered_motion_demonstration", "style": style_id, "biome": biome_id, "seed": lab.sample_seed, "layout_version": lab.layout.version,
		"frames_driven": 480, "nominal_fps": 60, "accepted_jumps": jumps[0], "motor_steps": lab.player.motion_steps - initial_steps,
		"actor_epoch_unchanged": lab.lifetime.actor_epoch == initial_epoch, "claims_full_route_completion": false, "observations": observations}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(data, "\t")); file.close()
	var valid: bool = file != null and jumps[0] > 0 and lab.lifetime.actor_epoch == initial_epoch
	print("STYLE_MOTION style=%s frames=480 jumps=%d valid=%s" % [style_id, jumps[0], valid])
	lab.leave()
	lab.free()
	await process_frame
	await process_frame
	quit(0 if valid else 1)
