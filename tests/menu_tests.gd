extends RefCounted

func run(tree: SceneTree, check: Callable) -> void:
	var menu := DemoMenu.new()
	tree.root.add_child(menu)
	var starts: Array[Dictionary] = []
	var resumes: Array[int] = []
	var homes: Array[int] = []
	var patches: Array[Dictionary] = []
	menu.requested_start.connect(func(seed: String, formal_ten: bool) -> void: starts.append({"seed": seed, "formal": formal_ten}))
	menu.requested_resume.connect(func() -> void: resumes.append(1))
	menu.requested_home.connect(func() -> void: homes.append(1))
	menu.settings_changed.connect(func(patch: Dictionary) -> void: patches.append(patch))
	menu.show_home("Last run: Boss defeated")
	check.call(menu.visible_panel == &"home" and menu._root.visible, "home menu blocks gameplay while showing run modes")
	menu._seed = " seeded trial "
	var formal_button := button(menu, "8 rooms   /   The full route")
	check.call(formal_button != null, "menu exposes the current eight-stage formal option")
	if formal_button == null:
		menu.queue_free()
		await tree.process_frame
		return
	formal_button.pressed.emit()
	check.call(starts == [{"seed": "seeded trial", "formal": true}] and menu.visible_panel == &"", "eight-room button sends trimmed seed and selected profile then hides")
	menu.show_home()
	menu._seed = " "
	button(menu, "3 rooms   /   A quick taste").pressed.emit()
	check.call(starts[1] == {"seed": "rush-demo", "formal": false}, "blank seed uses explicit demo fallback without changing mode")
	menu.show_pause("Double Jump")
	button(menu, "RETURN TO HOME").pressed.emit()
	check.call(menu.visible_panel == &"confirm_home" and homes.is_empty(), "return home first opens confirmation without ending the run")
	button(menu, "KEEP PLAYING").pressed.emit()
	check.call(resumes.size() == 1 and homes.is_empty() and menu.visible_panel == &"", "cancel leave resumes the same run without a home request")
	menu.show_pause()
	button(menu, "RETURN TO HOME").pressed.emit()
	button(menu, "LEAVE RUN").pressed.emit()
	check.call(homes.size() == 1 and menu.visible_panel == &"", "confirmed leave emits one home request and hides the blocking menu")
	menu.show_settings(true)
	(menu._sliders.right_enter_deadzone as HSlider).value = 0.2
	(menu._sliders.right_exit_deadzone as HSlider).value = 0.3
	button(menu, "APPLY").pressed.emit()
	check.call(patches.is_empty() and not menu._settings_error.text.is_empty(), "invalid gamepad deadzone order never emits a settings update")
	(menu._sliders.right_exit_deadzone as HSlider).value = 0.1
	(menu._sliders.right_sensitivity as HSlider).value = 1.5
	button(menu, "APPLY").pressed.emit()
	check.call(patches.size() == 1 and patches[0].size() == 5 and patches[0].right_sensitivity == 1.5, "valid settings emit only the five editable input fields")
	patches[0].right_sensitivity = 0.5
	check.call(menu._values.right_sensitivity == 1.5, "settings signal payload cannot mutate the menu profile")
	button(menu, "RESTORE DEFAULTS").pressed.emit()
	check.call(patches.size() == 1 and menu._values.right_sensitivity == 1.5, "restore defaults remains a preview until Apply")
	button(menu, "APPLY").pressed.emit()
	check.call(patches.size() == 2 and menu._values.right_sensitivity == menu._defaults.right_sensitivity, "restored defaults validate and apply from the authoritative input config")
	button(menu, "BACK").pressed.emit()
	check.call(menu.visible_panel == &"pause" and resumes.size() == 1, "back from run settings stays paused instead of leaking resume")
	menu.close_panel()
	check.call(menu.visible_panel == &"" and resumes.size() == 2, "closing pause emits explicit resume request")
	menu.show_help(false)
	menu.close_panel()
	check.call(menu.visible_panel == &"title" and resumes.size() == 2, "closing title help restores title without a gameplay resume")
	menu.hide_home()
	check.call(not menu._root.visible, "hidden menu root cannot intercept play controls")
	menu.queue_free()
	await tree.process_frame

func button(menu: DemoMenu, text: String) -> Button:
	for node: Node in menu._content.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node as Button
	return null
