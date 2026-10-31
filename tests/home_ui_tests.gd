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
	var app := preload("res://scenes/demo/demo.tscn").instantiate() as DemoApp
	app.meta_persistence_enabled=false
	root.add_child(app)
	app.menu.requested_enter_home.emit()
	await frames(8)
	var home := app.home_scene
	check(home.player is PlayerMotor and home.controller is PlayerController, "Home uses real motor and controller")
	check(home.player.is_on_floor(), "Home real body grounded on independent collision floor")
	check(home.controller.shoot_ability.enabled and home.controller.air_focus_ability.enabled and home.controller.shot_energy!=null and home.overlay is TouchOverlay, "Home shares level shooting, focus, shot energy and actual touch controls")
	var start := home.player.position.x
	home.controller.router.set_move_axis(1.0)
	await frames(15)
	check(home.player.position.x > start + 40.0, "Home movement driven by actual Motor physics")
	home.controller.router.set_move_axis(0)
	var energy:float=home.controller.actor_resources.stamina.current
	home.controller.router.request_action(&"jump")
	await frames(4)
	check(not home.player.is_on_floor() and home.player.velocity.y<0,"Home actual jump uses common controller")
	var shots:int=home.controller.shoot_ability._shot_serial
	var charges:int=home.controller.action_resources.shot_charges
	energy=home.controller.actor_resources.stamina.current
	home.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await frames(2)
	check(home.controller.shoot_ability._shot_serial==shots+1 and charges>0 and home.controller.action_resources.shot_charges==charges-1 and is_equal_approx(home.controller.actor_resources.stamina.current,energy),"Home actual airborne shot consumes one air charge without spending time energy")
	await frames(90)
	check(home.player.is_on_floor(),"Home same airborne recoil returns to safe real floor")
	var upgrade_foot:=home.slot_world_foot(&"upgrade")
	var departure_foot:=home.slot_world_foot(&"departure")
	check(home.nearest_candidate(upgrade_foot-Vector2(0,18)) == &"upgrade", "Nearest upgrade candidate")
	check(home.nearest_candidate(departure_foot-Vector2(0,18)) == &"departure", "Departure candidate")
	check(home.nearest_candidate(Vector2(40, 40)).is_empty(), "No remote NPC interaction")
	home.nearest_id = &"upgrade"
	check(home.nearest_candidate(upgrade_foot+Vector2(108,-18)) == &"upgrade", "Current candidate hysteresis")
	# Only the obsolete flat-map driving strategy changes. The original 27
	# business assertions remain intact; the new route uses real keyboard input.
	var route_driver:=preload("res://tests/underworld_plains/home_terrace_driver.gd").new(home)
	await route_driver.reach(&"upgrade")
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
	var menu := app.menu
	menu.show_title()
	check(menu.visible_panel == &"title", "Real title menu")
	menu.show_home_navigation()
	check(menu.visible_panel == &"home", "All development entries available via Home navigation")
	var text := ""
	for button: Node in menu._content.find_children("*", "Button", true, false):
		text += (button as Button).text + "\n"
	check(text.contains("MODULE LAB") and text.contains("RANDOM STAGE") and text.contains("3 rooms") and not text.contains("8 rooms"), "Current development routes preserved; retired eight-room option absent")
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
	# The real Timeweaver offers free production appearances through the App callback.
	var avatars := app.get_meta("avatar_presentation") as AvatarPresentation
	var notes_before := int(app.meta.snapshot().notes)
	var original_body := PlayerPresentationRuntime.current_body(home.player)
	var original_body_id := original_body.get_instance_id()
	var selections: Array[String] = []
	menu.requested_avatar.connect(func(id: String) -> void: selections.append(id))
	home.requested_interaction.emit(&"character")
	var picker := menu._content.find_child("TimeweaverAppearance",true,false) as OptionButton
	var options := avatars.selection_options()
	check(picker!=null and picker.item_count==2 and options.size()==2 and str(options[0].id)=="courier" and str(options[1].id)=="courier_classic", "Timeweaver exposes exactly the two real production appearances")
	check(menu.visible_panel==&"home_function" and home.input_blocked and original_body is PlayerMotionCandidateVisual and app.avatar_selection_id=="courier", "Actual Home service opens with the current new body selected")
	if picker!=null:
		check(picker.selected==0 and picker.get_item_text(0)==str(options[0].display_name) and picker.get_item_text(1)==str(options[1].display_name) and not picker.is_item_disabled(0) and not picker.is_item_disabled(1), "Real appearance control labels and enabled options match the actual catalog")
		picker.select(1)
		picker.item_selected.emit(1)
	await frames(2)
	var selected_body := PlayerPresentationRuntime.current_body(home.player)
	check(selections==["courier_classic"] and app.avatar_selection_id=="courier_classic" and avatars.selected_id=="courier_classic", "One real picker callback accepts exactly one appearance selection")
	check(selected_body!=null and selected_body.visible and selected_body is UnderworldPlayer and not selected_body is PlayerMotionCandidateVisual and selected_body.get_instance_id()!=original_body_id, "Accepted classic selection replaces the actual visible Home body")
	check(int(app.meta.snapshot().notes)==notes_before and purchases[0]==1, "Appearance selection spends no notes and submits no fake purchase")
	buttons = menu._content.find_children("*", "Button", true, false).filter(func(node: Node) -> bool: return not node is OptionButton)
	check(buttons.size()==1 and (buttons[0] as Button).text=="BACK TO HOME", "Appearance panel retains only Back besides the real selector; no fake purchase button")
	if buttons.size()==1: (buttons[0] as Button).pressed.emit()
	check(menu.visible_panel.is_empty() and not home.input_blocked and home.controller.active, "Timeweaver Back restores real Home input")
	home.requested_interaction.emit(&"character")
	var cancel := InputEventAction.new()
	cancel.action=&"ui_cancel"; cancel.pressed=true
	menu._unhandled_input(cancel)
	check(menu.visible_panel.is_empty() and not home.input_blocked and home.controller.active and app.avatar_selection_id=="courier_classic" and selections.size()==1 and int(app.meta.snapshot().notes)==notes_before, "Timeweaver cancel restores Home without selecting again or spending notes")
	menu.show_home_panel(&"achievements")
	check(menu._content.find_children("*", "Button", true, false).size() == 1, "No fake achievement reward claim")
	menu.show_pause("fixture build")
	check(menu.visible_panel == &"build", "Pause opens the backpack directly")
	menu._confirm_home()
	check(menu.visible_panel == &"confirm_home", "Destructive Run return still requires confirmation")
	check(DemoMenu.atlas_region(Rect2(914, 278, 412, 363)).region == Rect2(914, 278, 412, 363), "PR33 atlas region preserves source geometry")
	route_driver=null
	if not await load("res://tests/audio_teardown.gd").drain_world(app):check(false,"App audio releases before test exit")
	var app_ref: WeakRef = weakref(app)
	var home_ref: WeakRef = weakref(home)
	var menu_ref: WeakRef = weakref(menu)
	app.queue_free()
	for attempt: int in 8:
		if app_ref.get_ref() == null:break
		await process_frame
	check(app_ref.get_ref() == null and home_ref.get_ref() == null and menu_ref.get_ref() == null, "Actual App releases its Home and Menu owners before test exit")

	if "--failure-probe" in OS.get_cmdline_user_args():
		check(false, "Intentional Home UI failure probe")
	print("HOME UI TESTS: %s assertions, %s failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
