extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func ticks(count: int) -> void:
	for i: int in count: await physics_frame

func run() -> void:
	var session := preload("res://tests/perception_demo.tscn").instantiate() as OrdinaryRoomSession
	root.add_child(session)
	var camera := root.get_camera_2d()
	if camera: camera.zoom = Vector2.ONE*1.45
	await ticks(32)
	session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(44)
	session.controller.router.set_move_axis(1)
	for i: int in 340:
		if session.player.position.x > 1010: break
		await physics_frame
	session.controller.router.set_move_axis(0)
	await ticks(35)
	var nodes := session.room.element_runtime.nodes
	var completed: bool = nodes.gate.active and session.player.position.x > 1010 and nodes.mat.serial == 1
	await session.audio_service.shutdown()
	session.free()
	quit(0 if completed else 1)
