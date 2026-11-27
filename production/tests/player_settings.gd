extends SceneTree
## Exercise real preferences, physical-position calibration, the gameplay router and presentation.
var checks := 0
var failures := 0
var closed := 0
var path := "user://settings_test_" + str(OS.get_process_id()) + ".json"

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL settings ", label)

func button(index: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = 7
	event.button_index = index
	event.pressed = pressed
	return event

func trigger(axis: JoyAxis, strength: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = 7
	event.axis = axis
	event.axis_value = strength
	return event

func measure_touch(session: OrdinaryRoomSession) -> float:
	var overlay := session.touch_controls
	overlay.set_enabled(true)
	var down := InputEventScreenTouch.new()
	down.index = 2
	down.pressed = true
	down.position = overlay.left_center
	overlay.handle_touch(down)
	var move := InputEventScreenDrag.new()
	move.index = 2
	move.position = overlay.left_center + Vector2(overlay.radius * 0.45, 0)
	move.relative = move.position - down.position
	overlay.handle_touch(move)
	var sampled := session.controller.router.sample_axes()
	down.pressed = false
	down.position = move.position
	overlay.handle_touch(down)
	return sampled

func run() -> void:
	root.size = Vector2i(1280, 720)
	var prefs := WorldSettings.new()
	prefs.open(path, "settings_fixture")
	check(prefs.revision == 0 and is_equal_approx(prefs.value.volume, 0.7), "fresh independent checked slot")
	var session := OrdinaryRoomSession.new()
	root.add_child(session)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://rooms/world/P01.json"))
	var catalog := WorldContentCatalog.new()
	catalog.load_locked()
	catalog.load_bindings("res://config/imported_world/bindings.json")
	var issue := session.open(doc, null, null, catalog)
	check(issue.is_empty(), "production P01 opens " + issue)
	if not issue.is_empty():
		quit(1)
		return
	for tick in 160: await physics_frame
	prefs.apply_session(session)
	check(is_equal_approx(measure_touch(session), prefs.value.input.touch_walk_ratio), "two-step sends walking axis through actual touch and router")
	var page_host := Control.new()
	root.add_child(page_host)
	var view := WorldSettingsView.mount(page_host, func() -> void: closed += 1, prefs) as WorldSettingsView
	view.volume.value = 0
	view.reduced.button_pressed = true
	view.movement.select(1)
	view.open_calibration()
	var wizard := view.wizard
	check(wizard.save_button.disabled and not view.modal.visible, "calibration waits for physical input")
	root.push_input(button(JOY_BUTTON_B, true), true)
	check(wizard.step == 0, "press without release does not calibrate")
	root.push_input(button(JOY_BUTTON_B, false), true)
	var other := button(JOY_BUTTON_A, true)
	other.device = 8
	root.push_input(other, true)
	check(wizard.pending.is_empty() and wizard.device == 7, "other devices cannot modify partial calibration")
	Input.joy_connection_changed.emit(7, false)
	check(wizard.step == 0 and wizard.bindings.is_empty() and not wizard.error.is_empty(), "disconnect discards unfinished calibration")
	root.push_input(button(JOY_BUTTON_B, true), true)
	root.push_input(button(JOY_BUTTON_B, false), true)
	root.push_input(button(JOY_BUTTON_B, true), true)
	check(wizard.step == 1 and not wizard.error.is_empty(), "one physical input cannot occupy two roles")
	root.push_input(button(JOY_BUTTON_A, true), true)
	root.push_input(button(JOY_BUTTON_A, false), true)
	root.push_input(trigger(JOY_AXIS_TRIGGER_LEFT, 0.9), true)
	root.push_input(trigger(JOY_AXIS_TRIGGER_LEFT, 0.45), true)
	check(wizard.step == 2, "trigger holds across hysteresis band")
	root.push_input(trigger(JOY_AXIS_TRIGGER_LEFT, 0.05), true)
	root.push_input(button(JOY_BUTTON_RIGHT_SHOULDER, true), true)
	root.push_input(button(JOY_BUTTON_RIGHT_SHOULDER, false), true)
	root.push_input(button(JOY_BUTTON_BACK, true), true)
	root.push_input(button(JOY_BUTTON_BACK, false), true)
	check(wizard.step == 5 and not wizard.save_button.disabled, "five physical roles complete")
	wizard.save_button.pressed.emit()
	check(prefs.revision == 1 and view.modal.visible and view.reduced.button_pressed and view.volume.value == 0, "calibration persists independently, preserving open settings draft")
	view.save_draft()
	check(closed == 1 and prefs.revision == 2 and AudioServer.is_bus_mute(0), "apply writes and mutes downstream Master")
	check(is_equal_approx(measure_touch(session), 1), "fixed speed reaches actual movement router")
	check(session.focus_heal.reduced and not session.focus_vignette.enabled and PixelVfx.reduced(session.player), "reduced option reaches focused heal and gameplay VFX")
	session.camera.shake(4, 0.2)
	check(session.camera._shake_time == 0, "incoming hit cannot displace reduced camera")
	var feel := session.player.get_node("MotionFeel") as PlayerMotionFeel
	feel._land(300, 760, true, true)
	check(not feel._screen.visible and feel.shake_count == 0, "heavy landing leaves reduced screen stable")
	var mapped := session.controller.router.profile.gamepad_binding(7, "jump")
	check(int(mapped.index) == JOY_BUTTON_B, "saved device remap reaches game router")
	var pad := session.player.get_node("GamepadAdapter") as GamepadAdapter
	pad.connected_device = 7
	pad._unhandled_input(button(JOY_BUTTON_B, true))
	var actions := session.controller.router.consume_actions(10000)
	check(actions.size() == 1 and actions[0].type == &"jump", "calibrated physical south button emits a live jump")
	pad._unhandled_input(button(JOY_BUTTON_B, false))
	var fresh := WorldSettings.new()
	fresh.open(path, "settings_fixture")
	check(fresh.revision == 2 and fresh.value.reduced and fresh.value.input.touch_move_mode == "digital", "reload restores saved UI, touch and revision")
	var restarted_profile := InputProfile.new()
	restarted_profile.configure(fresh.value.input)
	check(restarted_profile.gamepad_binding(7,"map").index == JOY_BUTTON_BACK and restarted_profile.gamepad_binding(7,"item_trigger").kind == "none", "reload preserves physical map and skipped item binding")
	fresh.apply_session(session)
	var candidate := fresh.value.duplicate(true)
	candidate.input.touch_move_mode = "analog"
	candidate.volume = 0.35
	candidate.reduced = false
	check(fresh.save(candidate), "valid nonzero preferences commit")
	check(not AudioServer.is_bus_mute(0) and is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.35)), "restoring volume unmutes Master with its calibrated gain")
	check(is_equal_approx(measure_touch(session), 0.45), "analog sends thumb magnitude to actual gameplay")
	session.camera.shake(4, 0.2)
	check(session.camera._shake_time > 0 and not PixelVfx.reduced(session.player), "restoring effects enables ordinary camera impact and effects")
	feel._land(300, 760, true, true)
	check(feel._screen.visible, "ordinary landing screen shake is restored")
	candidate.volume = 1.5
	check(not fresh.save(candidate) and fresh.revision == 3 and is_equal_approx(fresh.value.volume, 0.35), "invalid edit cannot corrupt or partially apply")
	candidate.volume = 0
	fresh.storage.blocked = true
	check(not fresh.save(candidate) and not AudioServer.is_bus_mute(0) and fresh.revision == 3, "failed persistence leaves current sound and controls intact")
	page_host.queue_free()
	session.queue_free()
	for index in 12: await process_frame
	for suffix: String in ["", ".tmp", ".backup", ".corrupt"]: DirAccess.remove_absolute(path + suffix)
	print("PLAYER SETTINGS checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
