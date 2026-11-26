extends SceneTree
## Authored instances exercise the real player in both regional art reviews.
func _initialize() -> void:
	run.call_deferred()

func ticks(count: int) -> void:
	for i: int in count: await physics_frame

func run() -> void:
	var options := OS.get_cmdline_user_args()
	var region := "gear_city"
	for arg in options:
		if arg.begins_with("region="): region=arg.trim_prefix("region=")
	var doc := WorldRoomDocument.read("res://tests/carrier_demo.json")
	doc.root.properties.region_id=region
	doc.root.properties.terrain_material=region
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var error := session.open(doc)
	if not error.is_empty():
		printerr(error)
		session.free()
		quit(1)
		return
	var nodes := session.room.element_runtime.nodes
	if "drives" in options:
		session.player.reset_at(nodes["weights/A"].position+Vector2(0,-31))
		await ticks(145)
		session.controller.router.request_action(&"jump",Vector2.ZERO)
		await ticks(32)
		session.player.reset_at(nodes["wheel/carrier_0"].position+Vector2(0,-29))
		await ticks(155)
		session.player.reset_at(nodes.cart.position+Vector2(0,-29))
		await ticks(15)
		session._interact()
		session.controller.router.set_move_axis(1)
		await ticks(142)
		session.controller.router.set_move_axis(0)
		session.player.reset_at(nodes.seed.position+Vector2(0,-30))
		await ticks(145)
		session.controller.router.request_action(&"jump")
		await ticks(45)
	else:
		await ticks(24)
		session.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
		await ticks(125)
		session.player.reset_at(nodes["lift/carrier"].position+Vector2(0,-30))
		await ticks(17)
		session.controller.router.request_action(&"shoot_release",Vector2.LEFT)
		await ticks(110)
		session.player.reset_at(nodes.dock.position+Vector2(0,-31))
		await ticks(14)
		session._interact()
		await ticks(112)
		session.player.reset_at(nodes["basin/float"].position+Vector2(0,-29))
		await ticks(16)
		session.controller.router.request_action(&"shoot_release",Vector2(1,-.10).normalized())
		await ticks(184)
	print("CARRIER SHOWCASE region=",region," route=","drives" if "drives" in options else "rail"," seed_sink=",nodes.seed.sink," water_y=",nodes.basin.actual_surface_y)
	await session.audio_service.shutdown()
	session.free()
	quit()
