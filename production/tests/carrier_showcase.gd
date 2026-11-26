extends SceneTree
## Play the same authored carrier room as a short reproducible controller demonstration.
func _initialize() -> void:
	run.call_deferred()

func ticks(count: int) -> void:
	for i: int in count: await physics_frame

func run() -> void:
	var session := preload("res://tests/carrier_demo.tscn").instantiate() as OrdinaryRoomSession
	root.add_child(session)
	var nodes := session.room.element_runtime.nodes
	if "drives" in OS.get_cmdline_user_args():
		session.player.reset_at(nodes["weights/A"].position+Vector2(0,-31))
		await ticks(150)
		session.controller.router.request_action(&"jump",Vector2.ZERO)
		await ticks(48)
		session.player.reset_at(nodes["wheel/carrier_0"].position+Vector2(0,-29))
		await ticks(200)
	else:
		await ticks(32)
		session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
		await ticks(155)
		session.player.reset_at(nodes["lift/carrier"].position+Vector2(0,-30))
		await ticks(18)
		session.controller.router.request_action(&"shoot_release",Vector2.LEFT)
		await ticks(160)
	await session.audio_service.shutdown()
	session.free()
	quit()
