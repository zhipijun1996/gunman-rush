extends SceneTree
## Regression: actual ScreenTouch events with global mouse emulation still off.
var failures := 0
var assertions := 0
var app: DemoApp
var lab: FoundryLab
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures += 1; push_error("FOUNDRY TOUCH: " + label)
func ticks(n: int) -> void:
	for unused: int in n: await physics_frame
	# Attempt initialization also awaits an idle frame; physics catch-up alone
	# must not be mistaken for completed UI/world initialization.
	await process_frame
func tap(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await ticks(7)
func run() -> void:
	root.size = Vector2i(1280, 720)
	check(not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"), "global touch policy remains unchanged")
	app = DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	app._open_foundry()
	await ticks(7)
	lab = app._foundry
	check(lab.ready_for_play, "initial attempt loads")
	await tap(lab._profile_buttons[1])
	check(lab.ready_for_play and lab.selected.capability_profile == "double_jump" and lab.player.tuning.max_jumps == 2, "touch selects double jump and loads actual player")
	await tap(lab._profile_buttons[2])
	check(lab.ready_for_play and lab.selected.capability_profile == "air_chain" and lab.player.tuning.max_air_shots == 4, "touch selects four-shot capacity")
	await tap(lab._profile_buttons[0])
	check(lab.ready_for_play and lab.entries.size() == 24 and lab.player.tuning.max_jumps == 1, "touch restores base profile")
	var previous: Dictionary = lab.selected.duplicate(true)
	await tap(lab._level_buttons[1])
	check(lab.ready_for_play and lab.selected.id != previous.id and lab.selected.id == lab.entries[1].manifest.id, "touch selects another level")
	lab.toggle_pause()
	await tap(lab._level_buttons[2])
	check(not paused and lab.ready_for_play and lab.selected.id == lab.entries[2].manifest.id, "touch can select a fresh level while paused")
	for index: int in [1, 2, 0]:
		for pressed: bool in [true, false]:
			var event := InputEventScreenTouch.new()
			event.index = 0
			event.position = lab._profile_buttons[index].get_global_rect().get_center()
			event.pressed = pressed
			Input.parse_input_event(event)
	await ticks(9)
	check(lab.ready_for_play and lab.selected.capability_profile == "base" and lab.player.tuning.max_jumps == 1, "rapid touch profile changes leave latest attempt playable")
	for unused: int in 7: await tap(lab._page_next)
	check(lab._page == 7 and lab._page_next.disabled and lab._level_buttons[23].is_visible_in_tree(), "touch paging reaches last base variant")
	await tap(lab._level_buttons[23])
	check(lab.ready_for_play and lab.selected.id == lab.entries[23].manifest.id, "last-page level actually loads")
	await tap(lab._page_previous)
	check(lab._page == 6 and lab._level_buttons[18].is_visible_in_tree(), "touch pages back")
	var sources_button: Button
	for button: Button in lab.find_children("*", "Button", true, false):
		if button.text == "参考来源": sources_button = button
	check(lab._page_label.size.y <= 36, "page count stays on one line")
	check(sources_button.get_global_rect().end.y <= lab._overlay.jump_center.y - lab._overlay.jump_hit_radius, "side controls do not overlap jump hit area")
	await tap(sources_button)
	check(lab._show_sources and lab._source_buttons[0].is_visible_in_tree(), "sources open without modal")
	for unused: int in 10:
		if lab._page_next.disabled: break
		await tap(lab._page_next)
	check(lab._page_next.disabled and lab._source_buttons.back().is_visible_in_tree(), "last reference is reachable through real touch paging")
	await tap(sources_button)
	check(not lab._show_sources and lab._level_buttons[0].is_visible_in_tree(), "closing references restores usable levels")
	check(lab._profile_buttons[3].disabled, "unimplemented hook stays disabled")
	for button: Button in lab._profile_buttons + lab._level_buttons:
		for character: String in button.text:
			check(FoundryLab.FONT.has_char(character.unicode_at(0)), "Chinese font contains " + character)
	lab.leave()
	await ticks(3)
	check(not paused and not is_instance_valid(app._foundry), "leave releases practice and pause")
	if not "--prove-skip-drain" in OS.get_cmdline_user_args():
		var audio := get_first_node_in_group(&"game_audio") as GameAudio
		check(audio != null and await audio.shutdown(), "audio playback actually releases before host exit")
	app.free()
	await process_frame
	print("FOUNDRY TOUCH: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)
