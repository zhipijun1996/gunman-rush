extends SceneTree
## Real DemoApp consumer, actual native event dispatch. Resource edge cases are explicit fixtures.
var app: DemoApp
var checks := 0
var failures := 0
var observations: Array[Dictionary] = []
var capture := "--capture" in OS.get_cmdline_user_args()
var out := "res://build/verification/demo-ui-contract-05"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): out = arg.trim_prefix("--output=")
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	observations.append({"passed": ok, "assertion": message})
	if not ok: failures += 1; printerr("FAIL: " + message)
func frames(n: int = 4) -> void:
	for i: int in n: await process_frame
func button(owner: Node, prefix: String) -> Button:
	for node: Node in owner.find_children("*", "Button", true, false):
		if node.name == prefix or node.text.begins_with(prefix) or str(node.get_meta(&"ui_legacy_prefix", "")).begins_with(prefix): return node
	return null
func click(target: Control) -> void:
	check(target != null, "requested pointer control exists")
	if target == null: return
	var parent := target.get_parent()
	while parent:
		if parent is ScrollContainer and parent.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED: parent.ensure_control_visible(target)
		parent = parent.get_parent()
	await frames()
	var point := target.get_global_rect().get_center()
	check(root.get_visible_rect().has_point(point), "pointer center inside actual viewport")
	var move := InputEventMouseMotion.new(); move.position = point; move.global_position = point; Input.parse_input_event(move)
	await frames(2)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new(); event.position = point; event.global_position = point; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; Input.parse_input_event(event)
		await frames(2)
func joy(id: int) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new(); event.button_index = id; event.pressed = pressed; Input.parse_input_event(event); await frames(3)
func touch(target: Control) -> void:
	var point := target.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new(); event.index = 82; event.position = point; event.pressed = pressed; root.push_input(event, true); await frames(3)
func image(name: String) -> void:
	if not capture: return
	await frames(6); await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out + "/" + name + ".png") == OK, "actual Godot rendered " + name)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	app = DemoApp.new(); app.meta_persistence_enabled = false; root.add_child(app)
	await frames(8)
	await image("title")
	var primary := button(app.menu._root, "风铃平原")
	check(primary != null and root.get_visible_rect().encloses(primary.get_global_rect()), "primary title action entirely visible")
	await click(button(app.menu._root,"SETTINGS"))
	check(app.menu.visible_panel == &"settings", "actual pointer opens settings")
	check(app.menu._scroll.scroll_vertical == 0 and root.get_visible_rect().encloses(app.menu._movement_mode.get_global_rect()), "first settings entry shows heading and focused field after layout settles")
	var mode_popup := app.menu._movement_mode.get_popup()
	check(mode_popup.get_child(0) is PopupTouchAdapter and mode_popup.get_child(0).get_viewport() == mode_popup, "popup touch adapter owns embedded popup Viewport, not root menu coordinates")
	await touch(app.menu._movement_mode)
	check(mode_popup.visible, "actual touch opens native movement popup")
	check(app.menu._scroll_touch._finger == -1, "popup opening releases original scroll touch ownership before popup owns release")
	var option_point := Vector2(mode_popup.position) + Vector2(mode_popup.size) * Vector2(0.5, 0.83)
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new(); event.index = 83; event.position = option_point; event.pressed = pressed; root.push_input(event, true); await frames(3)
	check(not mode_popup.visible and app.menu._movement_mode.selected == 2, "actual embedded popup touch submits Analog speed and closes")
	app.menu._sliders.right_enter_deadzone.value = 0.2
	app.menu._sliders.right_exit_deadzone.value = 0.3
	var before := app._session_input.duplicate(true)
	await click(button(app.menu._root, "APPLY"))
	check(app._session_input == before, "invalid settings don't mutate real session profile")
	await click(button(app.menu._root, "RESTORE DEFAULTS"))
	check(app._session_input == before, "restore remains a preview until Apply")
	app.menu._sliders.left_sensitivity.value = 1.25
	await click(button(app.menu._root, "APPLY"))
	check(is_equal_approx(app._session_input.left_sensitivity, 1.25), "Apply changes real InputProfile")
	await click(button(app.menu._root,"BACK"))
	check(app.menu.visible_panel == &"title", "back returns title")
	check(root.gui_get_focus_owner() == button(app.menu._root,"SETTINGS"), "title restores caller settings focus")
	await touch(button(app.menu._root, "HOW TO PLAY"))
	check(app.menu.visible_panel == &"help", "native ScreenTouch opens real menu without global emulation")
	await joy(JOY_BUTTON_B)
	check(app.menu.visible_panel == &"title", "simulated gamepad B returns from help")
	await click(button(app.menu._root,"风铃平原"))
	await frames(12)
	check(is_instance_valid(app.home_scene) and app.director.state == DemoRunDirector.State.HOME, "actual primary enters playable Home")
	# The remaining cases exercise formal HUD, not physical Home-exit traversal.
	# Use the existing Home navigation consumer and its real pointer button.
	app.menu._seed = "level-design-v2-baseline/08"
	app._open_home_navigation()
	await click(button(app.menu._root,"Explore"))
	await frames(12)
	check(app.connected_region and app.stage is PlainsRegionStage, "Home navigation pointer starts formal region for retained HUD cases")
	check(app._demo_hud.actor == app.controller and app._demo_hud.visible and not app._hud_frame.visible, "formal consumer binds new HUD and removes old black board")
	check(app._demo_hud.hearts.capacity == app.controller.actor_resources.health.capacity, "hearts use actual maximum")
	await image("formal-hud")
	var actor := app.controller
	var health := actor.actor_resources.health
	# Let the existing spawn protection expire; do not bypass its eligibility guard.
	for i: int in 90: await physics_frame
	app._submit_damage(&"ui_fixture", DamageRequest.Kind.MONSTER, 1.0)
	await frames(8)
	check(health.current == health.capacity - 1.0 and app._demo_hud.hearts.current == health.current, "official damage policy drives heart loss")
	await image("hurt")
	SupplyHealEffect.apply(health, 1.0, &"ui-heal-fixture")
	await frames(4)
	check(app._demo_hud.hearts.current == health.current and health.current == health.capacity, "official heal effect restores hearts")
	var shots := actor.shoot_ability._shot_serial
	await click(app._pause_button)
	check(paused and app.menu.visible_panel == &"build" and actor.router.axis == 0, "mouse pause cancels input and freezes same run")
	await click(button(app.menu._root,"SETTINGS"))
	await joy(JOY_BUTTON_B)
	check(paused and app.menu.visible_panel == &"build", "gamepad B returns to paused backpack")
	check(root.gui_get_focus_owner() == button(app.menu._root,"SETTINGS"), "pause restores caller focus")
	await click(button(app.menu._root,"PausePage"))
	await click(button(app.menu._root,"RETURN TO HOME"))
	check(paused and app.menu.visible_panel == &"confirm_home", "dangerous leave uses real confirmation")
	await joy(JOY_BUTTON_B)
	check(not paused and app.controller == actor and actor.shoot_ability._shot_serial == shots, "cancel leave resumes same actor without shot leakage")
	await joy(JOY_BUTTON_START)
	check(paused and app.menu.visible_panel == &"build", "gamepad Start opens backpack at the original pause boundary")
	await joy(JOY_BUTTON_B)
	check(not paused, "gamepad B resumes pause")
	await click(app.stage.map_view)
	check(paused and app.map_modal.opened, "real map chip opens fog map")
	var fog := (app.stage as PlainsRegionStage).region_state.explored.duplicate()
	var zoom := app.map_modal.canvas.zoom
	await joy(JOY_BUTTON_RIGHT_SHOULDER)
	check(app.map_modal.canvas.zoom > zoom, "gamepad shoulder zooms real map")
	await image("map")
	check((app.stage as PlainsRegionStage).region_state.explored == fog, "view/zoom does not reveal terrain while the world remains paused")
	await joy(JOY_BUTTON_B)
	check(not app.map_modal.opened and not paused, "gamepad B closes fog map and resumes")
	check(root.gui_get_focus_owner() == null, "map close releases HUD focus before gameplay A/Space")
	await joy(JOY_BUTTON_A)
	check(not app.map_modal.opened and not paused, "first gameplay A after map close does not reopen the map")
	for viewport: Vector2i in [Vector2i(960,540), Vector2i(844,390), Vector2i(720,1280), Vector2i(1920,720)]:
		root.size = viewport; await frames(8)
		print("VIEWPORT requested=",viewport," window=",root.size," logical=",root.get_visible_rect().size," transform=",root.get_screen_transform())
		var touch_enabled := app.overlay.enabled
		app.overlay.set_enabled(true); await frames(4)
		var touch_pixels := app.overlay._pause_rect.size # Shared logical canvas targets; DPR does not change geometry.
		check(touch_pixels.x >= 47.9 and touch_pixels.y >= 47.9, "actual TouchOverlay MENU hit bounds at least48 logical units at " + str(viewport))
		check(app._demo_hud._touch_menu_text.get_theme_font_size("font_size") >= 13.9, "actual MENU label at least14 shared logical units at " + str(viewport))
		if viewport == Vector2i(844,390): await image("touch-hud-844x390")
		await touch(app._demo_hud._touch_menu)
		check(paused and app.menu.visible_panel == &"build" and actor.shoot_ability._shot_serial == shots, "shared-scale touch MENU invokes original pause without shot at " + str(viewport))
		await joy(JOY_BUTTON_B)
		app.overlay.set_enabled(touch_enabled); await frames(4)
		app.menu.show_pause(); await frames(8)
		for node: Node in app.menu._content.find_children("*","Button",true,false):
			check(node.get_global_rect().size.y >= 47.9, "touch target retains authored logical minimum at " + str(viewport))
			check(node.get_global_rect().position.x >= 0 and node.get_global_rect().end.x <= root.get_visible_rect().size.x, "menu horizontal bounds at " + str(viewport))
		await image("pause-%sx%s" % [viewport.x,viewport.y])
		app.menu.close_panel(); await frames()
	root.size = Vector2i(1280,720); await frames()
	# Exact fractional/max-growth display fixtures through the same HealthState, never rounded back.
	health.set_max(ActorResourceRequest.new(&"ui-max",health.epoch,13.5,health.get_instance_id()))
	await frames()
	check(app._demo_hud.hearts.capacity == 13.5 and health.capacity == 13.5, "growing real maximum wraps fourteen heart slots including fractional final capacity")
	health.heal(ActorResourceRequest.new(&"ui-partial",health.epoch,0.25,health.get_instance_id()))
	await frames()
	check(app._demo_hud.hearts.current == health.current, "fractional HP displayed without changing gameplay units")
	await image("max-growth")
	check(app._demo_hud._health_text.get_line_count() == 1, "fractional growing HP count remains readable on one line")
	# Terminal damage uses existing death settlement, cleanup and home lifecycle.
	for i: int in 180:
		if app.policy.clock >= maxf(app.policy._protected_until, app.policy._monster_until): break
		await physics_frame
	app._submit_damage(&"ui-terminal", DamageRequest.Kind.MONSTER, 100.0)
	for i: int in 3: await physics_frame
	await frames(12)
	check(app.director.state == DemoRunDirector.State.HOME and app.controller == null, "death retains real return-home lifecycle")
	check(app.menu.visible_panel == &"run_end" and not app._demo_hud.visible and app.home_scene.input_blocked, "settled result page blocks home input and hides run HUD")
	await image("run-end")
	await click(button(app.menu._root,"再次出发")); await frames(12)
	check(app.director.state == DemoRunDirector.State.IN_STAGE and app._demo_hud.actor == app.controller and app._demo_hud.hearts.current == app.controller.actor_resources.health.current, "retry uses existing new-run path with fresh real HUD")
	# Real developer forest entry, same UI, no campaign grant shortcuts added.
	app.abandon_run(); await frames(12)
	app.menu.show_region_select(); await frames()
	await click(button(app.menu._root, "THORN FOREST / MAP 1")); await frames(12)
	check(app.active_region_id == &"thorn_forest" and app.controller.traversal.hook_enabled, "existing developer forest entry keeps actual H grant")
	check(app._demo_hud.actor == app.controller and app._demo_hud._abilities.text.contains("钩索"), "forest HUD observes actual granted ability")
	app.open_region_map(); await frames()
	var map_text := ""
	for label: Node in app.map_modal._root.find_children("*", "Label", true, false): map_text += label.text
	check(map_text.contains("THORN FOREST") and not map_text.contains("WINDCHIME PLAINS"), "forest map shows real region identity")
	app.close_region_map(); await frames()
	app.free(); await frames(8)
	var preview := preload("res://experiments/platform/entries/cloud_preview.tscn").instantiate() as CloudPreviewBootstrap
	preview.task_id = "DEMO-UI-01"
	preview.entry = "menu"
	root.add_child(preview); await frames(8)
	check(not preview.banner.visible and not preview.app.meta_persistence_enabled, "UI preview keeps clean real title and save isolation")
	preview.app._open_action_studio(); await frames(8)
	check(preview.banner.visible, "developer laboratory retains original full-game return affordance")
	preview.return_to_menu(); await frames(8)
	check(not preview.banner.visible and not preview.app.meta_persistence_enabled, "return to full game restores clean title and save isolation")
	if not await preload("res://tests/audio_teardown.gd").drain_world(preview): check(false, "preview audio teardown")
	preview.free(); await frames(8)
	var file := FileAccess.open(out + "/assertions.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"native actual consumer; simulated gamepad/touch, explicit resource edge fixtures, physical device unverified","observations":observations},"  ")); file.close()
	print("DEMO UI CONTRACT: %s checks, %s failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
