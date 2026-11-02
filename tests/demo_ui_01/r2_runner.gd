extends SceneTree
## R2 real native consumer. Saved/session records below are presentation fixtures only.
## Window.push_input reaches native GUI; no Button.pressed.emit or real save writes.
const FONT_PATH := "res://assets/ui/demo_ui_01/r2/fonts/fusion-pixel-12px-proportional-zh_hans.otf"
const PRIMARY := {
	"BeginAdventure": "开始游戏",
	"ContinueAdventure": "继续游戏（选择存档）",
	"TitleSettings": "设定",
	"TitleTutorial": "新手教程",
}
var app: DemoApp
var checks := 0
var failures := 0
var observations: Array[Dictionary] = []
var media: Array[Dictionary] = []
var layouts: Array[Dictionary] = []
var pointer_events := 0
var wheel_events := 0
var pointer_trace: Array[Dictionary] = []
var capture := "--capture" in OS.get_cmdline_user_args()
var out := "res://build/verification/demo-ui-r2/r2"

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): out = argument.trim_prefix("--output=")
	run.call_deferred()

func check(ok: bool, assertion: String, detail: Dictionary = {}) -> void:
	checks += 1
	observations.append({"passed": ok, "assertion": assertion, "detail": detail})
	if not ok:
		failures += 1
		printerr("FAIL: " + assertion + " " + JSON.stringify(detail))

func frames(count: int = 5) -> void:
	for index: int in count: await process_frame

func named(name: String) -> Button:
	return app.menu._content.find_child(name, true, false) as Button

func prefix(value: String) -> Button:
	for node: Node in app.menu._content.find_children("*", "Button", true, false):
		if (node as Button).text.begins_with(value): return node as Button
	return null

func copy_rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]

func rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func page_text() -> String:
	var result := ""
	for node: Node in app.menu._content.find_children("*", "Label", true, false): result += (node as Label).text + "\n"
	return result

func motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)
	pointer_events += 1

func scroll_to(target: Control) -> bool:
	var scroller := app.menu._scroll
	for attempt: int in 36:
		var clip := rect(scroller).intersection(root.get_visible_rect())
		var bounds := rect(target)
		if clip.grow(0.5).encloses(bounds): return true
		motion(clip.get_center())
		await frames(1)
		var wheel := InputEventMouseButton.new()
		wheel.position = clip.get_center()
		wheel.global_position = wheel.position
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP if bounds.position.y < clip.position.y else MOUSE_BUTTON_WHEEL_DOWN
		# Balance wheel button edges in this Window.push_input sequence. The
		# rejected unbalanced sequence retained GUI capture under the wheel,
		# even while later motion visibly hovered another target.
		for pressed: bool in [true, false]:
			wheel.pressed = pressed
			root.push_input(wheel, true)
			wheel_events += 1
		await frames(2)
	return false

func trace_pointer(phase: String, target: Variant, point: Vector2) -> void:
	var hovered := root.gui_get_hovered_control()
	pointer_trace.append({"phase": phase, "point": [point.x, point.y], "target": target.text if is_instance_valid(target) else "disposed", "rect": copy_rect(rect(target)) if is_instance_valid(target) else [], "scroll": app.menu._scroll.scroll_vertical if is_instance_valid(app.menu._scroll) else -1, "hovered": str(hovered.get_path()) if is_instance_valid(hovered) else "", "pressed": target.is_pressed() if is_instance_valid(target) else false, "mode": target.get_draw_mode() if is_instance_valid(target) else -1})

func click(target: Button, enabled: bool = true) -> bool:
	check(target != null, "requested native pointer button exists")
	if target == null: return false
	check(target.is_visible_in_tree(), "pointer target belongs to the visible page")
	var revealed := await scroll_to(target) if app.menu._content.is_ancestor_of(target) else root.get_visible_rect().encloses(rect(target))
	check(revealed, "native wheel makes complete button reachable", {"name": str(target.name), "rect": copy_rect(rect(target))})
	if not revealed: return false
	var presses: Array[int] = []
	var enters: Array[int] = []
	target.pressed.connect(func() -> void: presses.append(1), CONNECT_ONE_SHOT)
	target.mouse_entered.connect(func() -> void: enters.append(1), CONNECT_ONE_SHOT)
	motion(Vector2(1, 1))
	await frames(1)
	var point := rect(target).get_center()
	motion(point)
	await frames(2)
	check(target.is_hovered() and not enters.is_empty(), "native mouse motion reaches actual button hover", {"name": str(target.name)})
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		trace_pointer("before-press" if pressed else "before-release", target, point)
		root.push_input(event, true)
		pointer_events += 1
		await frames(2)
		trace_pointer("after-press" if pressed else "after-release", target, point)
	check(presses.size() == (1 if enabled else 0), "native pointer activation count matches enabled state", {"count": presses.size(), "enabled": enabled})
	return presses.size() == (1 if enabled else 0)

func key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await frames(3)

func shot(label: String) -> void:
	if not capture: return
	check(DisplayServer.get_name() != "headless", "capture requires actual rendered native window")
	if DisplayServer.get_name() == "headless": return
	await frames(5)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := out + "/" + label + ".png"
	var error := image.save_png(path)
	check(error == OK, "actual native Godot screenshot written", {"file": path, "error": error})
	if error == OK: media.append({"path": path, "width": image.get_width(), "height": image.get_height(), "sha256": FileAccess.get_sha256(path)})

func hash_bytes(value: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value)
	return context.finish().hex_encode()

func font_checks() -> void:
	var font := load(FONT_PATH) as FontFile
	check(font != null and DemoClockworkTheme.FONT.resource_path == FONT_PATH, "shared Theme consumes the task pixel font")
	if font == null: return
	var family := font.get_font_name()
	var digest := hash_bytes(font.data)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/demo_ui_01/r2/fonts/source.json"))
	check(digest == str(source.get("font_sha256", "")), "runtime canonical font bytes match recorded licensed source", {"name": family, "sha256": digest})
	check(ThemeDB.fallback_font == font and ThemeDB.get_default_theme().default_font == font, "autoload installs same pixel family for default and CanvasItem fallback")
	check(not font.allow_system_fallback and font.antialiasing == TextServer.FONT_ANTIALIASING_NONE, "pixel font uses deterministic embedded glyphs without system substitution")
	for path: String in ["res://assets/fonts/foundry_notes.otf", "res://assets/fonts/foundry_ui.otf", "res://assets/fonts/windkeeper_ui.ttf"]:
		var legacy := load(path) as FontFile
		check(legacy != null and legacy.get_font_name() == family and hash_bytes(legacy.data) == digest, "direct legacy FontFile aliases canonical runtime name and bytes", {"path": path, "runtime_name": legacy.get_font_name() if legacy != null else ""})
	var menu_font := app.menu._root.theme.default_font
	check(menu_font.get_font_name() == family and named("BeginAdventure").get_theme_font("font").get_font_name() == family and UnderworldUI.FONT.get_font_name() == family, "real title and legacy UI resolve one pixel family")
	var characters: Dictionary = {}
	for path: String in source_files("res://scripts/ui") + source_files("res://resources/items") + source_files("res://resources/bosses") + ["res://game/progression/home/home_scene.gd"]:
		collect_quoted_cjk(FileAccess.get_file_as_string(path), characters)
	var missing := PackedStringArray()
	for character: String in characters:
		if not font.has_char(character.unicode_at(0)): missing.append(character)
	check(missing.is_empty(), "embedded pixel font covers quoted CJK in actual UI, items, Boss names and Home", {"unique_cjk": characters.size(), "missing": "".join(missing)})

func source_files(directory: String) -> Array[String]:
	var result: Array[String] = []
	var access := DirAccess.open(directory)
	if access == null:
		check(false, "actual UI source directory is available", {"path": directory})
		return result
	for file: String in access.get_files():
		if file.ends_with(".gd") or file.ends_with(".tres"): result.append(directory + "/" + file)
	for folder: String in access.get_directories(): result.append_array(source_files(directory + "/" + folder))
	return result

func collect_quoted_cjk(source: String, into: Dictionary) -> void:
	var quote := 0
	var escaped := false
	var comment := false
	for index: int in source.length():
		var code := source.unicode_at(index)
		if comment:
			if code == 10: comment = false
			continue
		if quote == 0:
			if code == 35: comment = true
			elif code in [34, 39]: quote = code
			continue
		if escaped:
			escaped = false
			continue
		if code == 92:
			escaped = true
			continue
		if code == quote:
			quote = 0
			continue
		if (code >= 0x3400 and code <= 0x9fff) or (code >= 0x20000 and code <= 0x3134f): into[String.chr(code)] = true

func title_art_checks() -> void:
	var art := app.menu._root.get_node_or_null("TitleBackdrop") as Control
	check(art != null, "real title owns a separate illustration Control")
	if art == null: return
	check(rect(art).grow(0.5).encloses(root.get_visible_rect()) and not app.menu._content.is_ancestor_of(art), "title illustration fills viewport independently of button containers")
	var background: TextureRect
	var logo: TextureRect
	for node: Node in art.get_children():
		if node is TextureRect and node.texture != null:
			if node.texture.resource_path.ends_with("title_impression.png"): background = node
			if node.texture.resource_path.ends_with("title_logo.png"): logo = node
	check(background != null and logo != null, "title consumes distinct generated environment and clock-logo assets")
	if background != null:
		check(background.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED and rect(background).grow(0.5).encloses(root.get_visible_rect()), "environment is a full-bleed native TextureRect")
	if logo != null:
		check(logo.mouse_filter == Control.MOUSE_FILTER_IGNORE and rect(logo).position.x >= root.get_visible_rect().size.x * 0.35, "clock logo occupies right composition without intercepting clicks")
	check(art.find_children("*", "BaseButton", true, false).is_empty(), "illustration contains no baked or hidden replacement buttons")

func title_layout(size: Vector2i) -> void:
	root.size = size
	app.menu.show_title()
	await frames(9)
	var scale := root.get_screen_transform().get_scale().abs()
	var controls: Array[Button] = []
	var evidence: Array[Dictionary] = []
	for name: String in PRIMARY:
		var target := named(name)
		check(target != null and target.text == PRIMARY[name], "title primary uses exact requested name and label", {"name": name})
		if target == null: continue
	for node: Node in app.menu._content.find_children("*", "Button", true, false):
		var target := node as Button
		controls.append(target)
		evidence.append({"name": str(target.name), "logical_rect": copy_rect(rect(target)), "physical_height": rect(target).size.y * scale.y})
		check(rect(target).size.y >= 47.95, "every title target retains its 48-unit logical minimum on every screen", evidence.back())
		check(rect(target).position.x >= 0 and rect(target).end.x <= root.get_visible_rect().end.x + 0.5, "title target fits viewport horizontally", {"name": str(target.name)})
	for first: int in controls.size():
		for second: int in range(first + 1, controls.size()):
			check(not rect(controls[first]).intersects(rect(controls[second])), "primary title hit rectangles do not overlap", {"a": str(controls[first].name), "b": str(controls[second].name)})
	title_art_checks()
	await shot("title-%sx%s" % [size.x, size.y])
	for target: Button in controls:
		var reachable := await scroll_to(target)
		check(reachable and root.get_visible_rect().grow(0.5).encloses(rect(target)), "each title action is reachable with native wheel scrolling", {"name": str(target.name), "window": [size.x, size.y]})
	await shot("title-%sx%s-bottom" % [size.x, size.y])
	layouts.append({"window_size": [size.x, size.y], "logical_size": [root.get_visible_rect().size.x, root.get_visible_rect().size.y], "pixel_scale": [scale.x, scale.y], "buttons": evidence})

func run() -> void:
	check(DirAccess.make_dir_recursive_absolute(out) == OK, "fresh R2 evidence directory is writable")
	root.size = Vector2i(1280, 720)
	app = preload("res://game/application/demo.tscn").instantiate() as DemoApp
	app.meta_persistence_enabled = false
	root.add_child(app)
	await frames(9)
	check(root.has_node("GameTypography") and not app.meta_persistence_enabled, "real project autoload runs while fixture disables persistence")
	font_checks()
	for size: Vector2i in [Vector2i(844, 390), Vector2i(960, 540), Vector2i(1920, 720)]: await title_layout(size)
	root.size = Vector2i(1280, 720)
	app.menu.show_title()
	await frames(9)
	await click(named("TitleSettings"))
	check(app.menu.visible_panel == &"settings", "actual title settings click opens real settings")
	await shot("settings")
	await click(prefix("BACK"))
	check(app.menu.visible_panel == &"title" and root.gui_get_focus_owner() == named("TitleSettings"), "settings back restores actual title caller focus")
	await click(named("TitleTutorial"))
	check(app.menu.visible_panel == &"help" and named("BeginBasicTutorial") != null and page_text().contains("新的冒险"), "tutorial exposes truthful basic Plains new-adventure entry")
	await shot("tutorial")
	await click(prefix("BACK"))
	var real_meta := app.meta.snapshot().duplicate(true)
	app.menu.set_meta_state({"save_status": "new_profile", "profile_revision": 0})
	await click(named("ContinueAdventure"))
	check(app.menu.visible_panel == &"continue" and named("ChooseExistingProfile") == null and page_text().contains("尚无"), "empty actual profile presentation offers no fake choose/load action")
	await shot("continue-empty")
	app.menu.set_meta_state({"save_status": "saved", "profile_revision": 7, "notes": 12, "upgrades": {"vitality": 1}, "completed_runs": 2, "failed_runs": 3, "completed_biomes": 1})
	app.menu.show_continue()
	await frames()
	check(page_text().contains("本地成长记录") and page_text().contains("不会接续上一局"), "explicit saved-record fixture identifies permanent progress without promising run resume")
	await shot("continue-saved-fixture")
	var entered: Array[int] = []
	app.menu.requested_enter_home.connect(func() -> void: entered.append(1))
	await click(named("ChooseExistingProfile"))
	check(entered.size() == 1 and app.home_scene != null and app.meta.snapshot() == real_meta, "saved fixture choose emits once into actual Home without restoring fake data or mutating real meta")
	app._remove_home_scene()
	app.menu.set_meta_state({"save_status": "memory_only", "profile_revision": 3, "notes": 4, "upgrades": {}})
	app.menu.show_continue()
	await frames()
	check(page_text().contains("当前试玩会话") and page_text().contains("不会保存") and not page_text().contains("本地成长记录"), "memory-only preview wording distinguishes current session from saved profiles")
	await shot("continue-session-fixture")
	app.menu.set_meta_state(real_meta)
	app.menu.show_title()
	await frames()
	await click(named("BeginAdventure"))
	check(is_instance_valid(app.home_scene) and app.director.state == DemoRunDirector.State.HOME, "actual title start enters the current playable Home")
	# The current title enters Home. Retain this UI-only suite's formal pause
	# checks through the real Home navigation button, without claiming traversal.
	app.menu._seed = "level-design-v2-baseline/08"
	app._open_home_navigation()
	await frames(6)
	await click(prefix("Explore"))
	for attempt: int in 90:
		if app.director.state == DemoRunDirector.State.IN_STAGE and is_instance_valid(app.controller) and is_instance_valid(app.stage): break
		await process_frame
	check(app.director.state == DemoRunDirector.State.IN_STAGE and is_instance_valid(app.controller), "actual Home navigation starts the formal game consumer for retained pause checks")
	if is_instance_valid(app.controller): await pause_checks()
	paused = false
	check(await preload("res://tests/audio_teardown.gd").drain_world(app), "actual test world releases owned audio before teardown")
	var reference: WeakRef = weakref(app)
	app.queue_free()
	app = null
	await frames(10)
	check(reference.get_ref() == null, "real DemoApp is released cleanly")
	var result := {"schema": "demo-ui-r2-native-v1", "checks": checks, "failures": failures, "exit_code": 0 if failures == 0 else 1, "native_event_route": "Window.push_input(event, true)", "pointer_events": pointer_events, "wheel_events": wheel_events, "pointer_trace": pointer_trace, "captured": capture, "layouts": layouts, "media": media, "observations": observations, "scope": "Actual native DemoApp and Control GUI. Saved/session snapshots are explicitly presentation fixtures; real persistence disabled. CJK checks actual quoted UI/item/Boss/Home source against embedded font. No physical device or user-art approval."}
	var file := FileAccess.open(out + "/assertions.json", FileAccess.WRITE)
	if file == null:
		printerr("FAIL: unable to write R2 assertions.json")
		quit(1)
		return
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("DEMO UI R2: %s checks, %s failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func pause_checks() -> void:
	var player := app.player
	var shots := app.controller.shoot_ability._shot_serial
	await click(app._pause_button)
	check(paused and app.menu.visible_panel == &"build", "native MENU pauses actual world and opens backpack directly")
	var pause_tab := named("PausePage")
	var build_tab := named("BuildPage")
	var settings_tab := named("SettingsPage")
	var help_tab := named("HelpPage")
	check(pause_tab != null and build_tab != null and settings_tab != null and help_tab != null, "paused backpack exposes four genuine page controls")
	if pause_tab == null or build_tab == null or settings_tab == null or help_tab == null: return
	check(build_tab.button_pressed and not pause_tab.button_pressed, "backpack is the active page on pause entry")
	await shot("pause-build")
	var backpack := app.menu._content.find_child("BackpackItems", true, false) as GridContainer
	check(backpack != null and backpack.find_children("*", "Button", true, false).is_empty() and named("EquipItem") == null and named("EquipmentNotImplemented") == null, "fresh run has an honest empty backpack without disabled fake equipment tabs")
	await click(pause_tab)
	check(paused and app.menu.visible_panel == &"pause" and named("PausePage").button_pressed and not named("BuildPage").button_pressed, "native page click opens journey actions without resuming")
	await shot("pause")
	await click(named("BuildPage"))
	check(app.menu.visible_panel == &"build" and paused and named("BuildPage").button_pressed, "native backpack page click returns to the actual equipment editor")
	named("BuildPage").grab_focus()
	await key(KEY_E)
	check(app.menu.visible_panel == &"pause" and paused, "native next-page key opens journey without moving the actor")
	await key(KEY_Q)
	check(app.menu.visible_panel == &"build" and paused, "native previous-page key returns to backpack")
	await click(named("SettingsPage"))
	check(app.menu.visible_panel == &"settings" and paused, "native settings page is reachable from backpack")
	await click(prefix("BACK"))
	check(app.menu.visible_panel == &"build" and paused, "settings Back remains inside paused backpack")
	await click(named("ResumeAdventure"))
	check(not paused and app.player == player and app.controller.shoot_ability._shot_serial == shots, "direct backpack close preserves real player and releases no stale UI shot")
