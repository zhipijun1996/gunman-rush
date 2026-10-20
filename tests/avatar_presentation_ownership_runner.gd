extends SceneTree
## Real TITLE/Home/Forest consumers: selection owns exactly one visible body.
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for tick: int in count:await physics_frame

func visible_bodies(player: PlayerMotor) -> int:
	var count := 0
	for child: Node in player.get_children():
		if child is CanvasItem and (child is CourierVisual or child is PixelPlainsActor or child.has_meta("avatar_presentation_owned")):
			if (child as CanvasItem).visible and not child.is_queued_for_deletion():count += 1
	return count

func run() -> void:
	var app := preload("res://scenes/demo/demo.tscn").instantiate() as DemoApp
	app.meta_persistence_enabled = false
	root.add_child(app)
	await frames(3)
	app.menu.requested_enter_home.emit()
	await frames(8)
	var avatar := app.get_meta("avatar_presentation") as AvatarPresentation
	var player := app.home_scene.player
	var original := player.get_node("CourierVisual") as CourierVisual
	var generated := player.get_node("UnderworldPlayer") as UnderworldPlayer
	check(visible_bodies(player) == 1 and generated.visible and not original.visible, "Default Home shows only generated body after real avatar bind")
	for id: String in ["p1_traveller", "p1_girl", "courier", "p1_traveller", "courier"]:
		check(avatar.select_avatar(id), "Actual catalog selection accepts " + id)
		check(visible_bodies(player) == 1 and not original.visible, "Home selection has exactly one body and keeps anchor hidden " + id)
		check(generated.visible == (id == "courier"), "Home default body visibility follows appearance ownership " + id)
	check(not avatar.select_avatar("missing_avatar") and visible_bodies(player) == 1 and generated.visible, "Rejected selection leaves default Home body intact")
	avatar.bind_player(player)
	check(visible_bodies(player) == 1 and generated.visible and not original.visible, "Repeated Home binding is idempotent")
	check(app.start_debug_region(&"thorn_forest", 1, "avatar-ownership"), "Real Forest consumer starts")
	await frames(10)
	player = app.player
	original = player.get_node("CourierVisual") as CourierVisual
	check(visible_bodies(player) == 1 and original.visible, "Forest restores its original default body")
	check(avatar.select_avatar("p1_girl") and visible_bodies(player) == 1 and not original.visible, "Forest selected body replaces original")
	check(avatar.select_avatar("courier") and visible_bodies(player) == 1 and original.visible, "Forest selection returns to its original body")
	app.abandon_run()
	await frames(10)
	player = app.home_scene.player
	check(visible_bodies(player) == 1 and player.get_node("UnderworldPlayer").visible and not player.get_node("CourierVisual").visible, "Actual Forest return rebinds the sole generated Home body")
	check(await load("res://tests/audio_teardown.gd").drain_world(app), "Actual audio playback releases")
	var app_ref: WeakRef = weakref(app)
	app.queue_free()
	for attempt: int in 8:
		if app_ref.get_ref() == null:break
		await process_frame
	check(app_ref.get_ref() == null, "Actual App owner releases before exit")
	print("AVATAR OWNERSHIP: %s assertions, %s failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
