extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for _index: int in count:
		await physics_frame
func run() -> void:
	var app := preload("res://scenes/demo/demo.tscn").instantiate() as DemoApp
	app.meta_persistence_enabled = false
	app.meta.grant_notes(9, &"home_fixture_notes")
	root.add_child(app)
	await frames(4)
	check(app.menu.visible_panel == &"title" and app.home_scene == null, "Boot owns title input and does not create a Run")
	app.menu.requested_enter_home.emit()
	await frames(8)
	check(is_instance_valid(app.home_scene) and app.menu.visible_panel.is_empty(), "Title request creates actual walkable Home")
	check(app.player == null and app.wallet == null and not app.lifetime.active, "Home does not initialize temporary run wallet/lifetime")
	var home := app.home_scene
	var actor := home.player
	check(actor.is_on_floor() and home.controller.actor_resources.health.current == 5, "Actual home motor rests on safe ground with meta-derived base health")
	var began := actor.position
	home.controller.router.set_source_axis(&"keyboard_mouse", 1.0)
	await frames(82)
	home.controller.router.set_source_axis(&"keyboard_mouse", 0.0)
	await frames(3)
	check(actor.position.x > began.x + 350 and home.nearest_id == &"upgrade", "Real Motor walking reaches upgrade NPC without teleport")
	home.controller.router.request_action(&"interact")
	await frames(3)
	check(home.input_blocked and app.menu.visible_panel == &"home_function", "Nearby intent opens functional NPC panel and cancels input")
	check(home.controller.router.axis == 0 and actor.normal_velocity == Vector2.ZERO, "Opening panel clears old movement and speed")
	var before_purchase := actor.position
	app.menu.requested_upgrade.emit()
	await frames(3)
	check(app.meta.snapshot().notes == 4 and app.meta.snapshot().upgrades.vitality == 1, "NPC purchase uses the real independent permanent wallet")
	check(actor.position == before_purchase and home.input_blocked and app.menu.visible_panel == &"home_function", "Purchase preserves NPC context rather than restarting home")
	app.menu.close_panel()
	await frames(3)
	check(not home.input_blocked and app.menu.visible_panel.is_empty(), "Closing returns input to Home without replaying a gesture")
	var keyboard := actor.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter
	var hold := InputEventKey.new()
	hold.physical_keycode = KEY_W
	hold.pressed = true
	Input.parse_input_event(hold)
	await frames(2)
	home.set_input_blocked(true)
	var held_blocked := keyboard._blocked_until_release.has(KEY_W)
	home.set_input_blocked(false)
	check(held_blocked and keyboard._blocked_until_release.has(KEY_W), "Physical held W remains blocked after panel closes")
	home.set_input_blocked(true)
	var release := InputEventKey.new()
	release.physical_keycode = KEY_W
	release.pressed = false
	Input.parse_input_event(release)
	await frames(2)
	home.set_input_blocked(false)
	check(not keyboard._blocked_until_release.has(KEY_W), "Real W released under covered panel does not swallow next interaction")
	home.controller.router.set_source_axis(&"keyboard_mouse", 1.0)
	await frames(102)
	home.controller.router.set_source_axis(&"keyboard_mouse", 0.0)
	await frames(3)
	check(home.nearest_id == &"departure", "Real walk reaches the fixed adventure gate")
	home.controller.router.request_action(&"interact")
	await frames(3)
	check(home.input_blocked and app.menu.visible_panel == &"home_function", "Gate opens departure confirmation")
	app.menu.requested_plains.emit("home-app-test")
	await frames(10)
	check(app.generated_plains and app.director.stage_index == 1 and app.home_scene == null and is_instance_valid(app.player), "Departure creates one formal run and unloads Home and its HUD")
	check(app.controller.actor_resources.health.capacity == 6 and app.wallet.balance == 0, "New run applies upgraded baseline and has its own fresh coin wallet")
	check(not app.start_plains("duplicate-gate"), "Second departure cannot create another run")
	app.abandon_run()
	await frames(10)
	check(is_instance_valid(app.home_scene) and app.director.state == DemoRunDirector.State.HOME and app.player == null, "Run end returns once to real Home")
	check(app.home_scene.controller.actor_resources.health.capacity == 6 and app.meta.snapshot().notes == 4, "Home preserves permanent progress and recomputes fresh baseline")
	app.queue_free()
	await process_frame
	if "--failure-probe" in OS.get_cmdline_user_args():
		check(false, "intentional failure probe")
	print("HOME APP: %s assertions, %s failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
