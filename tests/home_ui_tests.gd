extends SceneTree
var assertions := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)
func frames(count: int) -> void:
	for unused: int in count:
		await physics_frame
func _run() -> void:
	var home := HomeScene.new()
	root.add_child(home)
	await frames(8)
	check(home.player is PlayerMotor and home.controller is PlayerController, "Home uses real motor and controller")
	check(home.player.is_on_floor(), "Home real body grounded on independent collision floor")
	check(not home.controller.shoot_ability.enabled and not home.controller.air_focus_ability.enabled, "Home cannot fire or slow time")
	var start := home.player.position.x
	home.controller.router.set_move_axis(1.0)
	await frames(15)
	check(home.player.position.x > start + 40.0, "Home movement driven by actual Motor physics")
	check(home.nearest_candidate(Vector2(600, HomeScene.FLOOR_Y - 18)) == &"upgrade", "Nearest upgrade candidate")
	check(home.nearest_candidate(Vector2(1160, HomeScene.FLOOR_Y - 18)) == &"departure", "Departure candidate")
	check(home.nearest_candidate(Vector2(40, 40)).is_empty(), "No remote NPC interaction")
	home.nearest_id = &"upgrade"
	check(home.nearest_candidate(Vector2(708, HomeScene.FLOOR_Y - 18)) == &"upgrade", "Current candidate hysteresis")
	var requests: Array[StringName] = []
	home.requested_interaction.connect(func(id: StringName) -> void: requests.append(id))
	home.nearest_id = &"upgrade"
	home.interact()
	check(requests == [&"upgrade"], "Interaction emits local typed request")
	home.controller.router.request_action(&"jump")
	home.set_input_blocked(true)
	home.interact()
	check(requests.size() == 1, "Blocked panel cannot repeat interaction")
	check(home.controller.router.sample_axes() == 0.0 and home.controller.router.consume_actions(999).is_empty(), "Opening panel cancels axes and queued actions")
	var blocked_position := home.player.position
	await frames(10)
	check(home.player.position == blocked_position, "Panel cannot move real Home body")
	home.set_input_blocked(false)
	check(home.controller.active and home.controller.router.axis == 0.0, "Closing panel requires fresh input")
	var menu := DemoMenu.new()
	root.add_child(menu)
	menu.show_title()
	check(menu.visible_panel == &"title", "Real title menu")
	menu.show_home_navigation()
	check(menu.visible_panel == &"home", "All development entries available via Home navigation")
	var text := ""
	for button: Node in menu._content.find_children("*", "Button", true, false):
		text += (button as Button).text + "\n"
	check(text.contains("MODULE LAB") and text.contains("RANDOM STAGE") and text.contains("3 rooms") and text.contains("10 rooms"), "Development routes preserved")
	menu.set_meta_state({"notes": 0, "upgrade_quote": {"level": 0, "max_level": 3, "price": 5, "available": true}})
	menu.show_home_panel(&"upgrade")
	var buttons := menu._content.find_children("*", "Button", true, false)
	check((buttons[0] as Button).disabled, "Insufficient actual notes disables upgrade request")
	menu.set_meta_state({"notes": 7, "upgrade_quote": {"level": 0, "max_level": 3, "price": 5, "available": true}})
	menu.show_home_panel(&"upgrade")
	buttons = menu._content.find_children("*", "Button", true, false)
	check(not (buttons[0] as Button).disabled, "Existing affordable Meta quote offered")
	var purchases := [0]
	menu.requested_upgrade.connect(func() -> void: purchases[0] += 1)
	(buttons[0] as Button).pressed.emit()
	(buttons[0] as Button).pressed.emit()
	check(purchases[0] == 1, "Same confirmation cannot submit permanent purchase twice")
	menu.show_home_panel(&"character")
	check(menu._content.find_children("*", "Button", true, false).size() == 1, "No fake character purchase/select action")
	menu.show_home_panel(&"achievements")
	check(menu._content.find_children("*", "Button", true, false).size() == 1, "No fake achievement reward claim")
	menu.show_pause("fixture build")
	check(menu.visible_panel == &"pause", "Pause route retained")
	menu._confirm_home()
	check(menu.visible_panel == &"confirm_home", "Destructive Run return still requires confirmation")
	check(DemoMenu.atlas_region(Rect2(914, 278, 412, 363)).region == Rect2(914, 278, 412, 363), "PR33 atlas region preserves source geometry")
	home.queue_free()
	menu.queue_free()
	await frames(2)
	if "--failure-probe" in OS.get_cmdline_user_args():
		check(false, "Intentional Home UI failure probe")
	print("HOME UI TESTS: %s assertions, %s failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
