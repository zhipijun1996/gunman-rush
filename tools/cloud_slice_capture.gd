extends SceneTree
## Real accepted input in the shipped ActionStudio. No result/resource injection.
var preview: CloudPreviewBootstrap
var studio: ActionStudio
var frame := 0
var trace: Array[Dictionary] = []
var trace_path := ""
var variant := "after"

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--trace="): trace_path = argument.trim_prefix("--trace=")
		if argument.begins_with("--variant="): variant = argument.trim_prefix("--variant=")
	call_deferred("start")

func start() -> void:
	root.size = Vector2i(1280, 720)
	preview = preload("res://scenes/dev/cloud_preview.tscn").instantiate()
	root.add_child(preview)
	await process_frame
	await process_frame
	studio = preview.app._action_studio
	if not is_instance_valid(studio):
		push_error("Cloud capture did not enter the real ActionStudio")
		quit(1)
		return
	# The local change under review is the new development banner/menu affordance.
	# Before is the identical scene with only that new UI hidden; no gameplay edit.
	preview.banner.visible = variant == "after"
	studio.set_training_static(true)
	studio.controller.air_focus_ability.enabled = false
	studio.controller.router.activate_device(&"gamepad")
	process_frame.connect(drive)

func drive() -> void:
	frame += 1
	var controller := studio.controller
	var cycle := frame % 180
	if cycle == 1: controller.router.set_move_axis(1)
	if cycle == 24: controller.router.set_move_axis(0)
	if cycle == 28: controller.router.request_action(&"jump")
	if cycle == 36: controller.router.request_action(&"jump_release")
	controller.router.set_aim(&"gamepad", Vector2.RIGHT, cycle >= 40 and cycle < 55)
	if cycle == 55: controller.router.request_action(&"shoot_release", Vector2.RIGHT)
	trace.append({"frame": frame, "position": [controller.motor.position.x, controller.motor.position.y],
		"velocity": [controller.motor.velocity.x, controller.motor.velocity.y],
		"recoil": [controller.motor.recoil_velocity.x, controller.motor.recoil_velocity.y],
		"motion_steps": controller.motor.motion_steps,
		"health": controller.actor_resources.health.current})
	if frame >= 720: finish.call_deferred()

func finish() -> void:
	process_frame.disconnect(drive)
	var file := FileAccess.open(trace_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot save cloud slice trace")
		quit(1)
		return
	file.store_string(JSON.stringify({"variant": variant, "frames": trace,
		"scope": "real ActionStudio accepted input; static training target; new development banner on/off; no gameplay benefit claim"}))
	file.close()
	preview.free()
	await process_frame
	await process_frame
	print("CLOUD SLICE: 720 frames")
	quit()
