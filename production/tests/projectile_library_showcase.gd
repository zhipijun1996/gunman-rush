extends SceneTree
## Replay the same ordinary-room actions with an explicit regional material and fittings.
## --script res://tests/projectile_library_showcase.gd -- echo_mines
func _initialize() -> void:
	run.call_deferred()

func ticks(count: int) -> void:
	for i: int in count: await physics_frame

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var region := args[0] if not args.is_empty() else "echo_mines"
	var doc := WorldRoomDocument.read("res://tests/projectile_library_demo.json")
	doc.root.properties.region_id = region
	doc.root.properties.terrain_material = region
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(doc)
	if not error.is_empty():
		printerr(error)
		session.free()
		quit(1)
		return
	var camera := session.get_viewport().get_camera_2d()
	camera.reparent(session)
	camera.position = Vector2(430,268)
	camera.zoom = Vector2.ONE*1.64
	await ticks(42)
	session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks(70)
	camera.zoom = Vector2.ONE*2.15
	for i: int in 36:
		camera.position = Vector2(430,268).lerp(Vector2(607,267),smoothstep(0,1,float(i)/35))
		await ticks(1)
	session.player.reset_at(Vector2(580,365))
	await ticks(12)
	session.controller.router.request_action(&"shoot_release",Vector2(100,-180).normalized())
	await ticks(58)
	session.controller.router.request_action(&"shoot_release",Vector2(100,-89).normalized())
	await ticks(64)
	await session.audio_service.shutdown()
	session.free()
	quit()
