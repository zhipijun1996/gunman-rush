extends SceneTree
## Native Escape regression: actual App/Menu and real Input.parse_input_event.
## Known ownership/direct formal entry are disclosed setup; no direct call to
## DemoMenu._input/_unhandled_input or resume action substitutes for Escape.
var app: Variant
var checks := 0
var failures := 0
var trace: Array[Dictionary] = []
var phase := "setup"
const OUTPUT := "res://build/item_v5/pause-escape-development"

class EventProbe extends Node:
	var reporter: Callable
	var label := ""
	func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS
	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.keycode == KEY_ESCAPE:
			reporter.call(label+"/_input", event)
	func _unhandled_key_input(event: InputEvent) -> void:
		if event is InputEventKey and event.keycode == KEY_ESCAPE:
			reporter.call(label+"/_unhandled_key_input", event)
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.keycode == KEY_ESCAPE:
			reporter.call(label+"/_unhandled_input", event)

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+label)

func frames(count: int) -> void:
	for unused: int in count: await process_frame

func control_name(control: Control) -> String:
	return str(control.get_path()) if is_instance_valid(control) else "<none>"

func event_trace(label: String, event: InputEvent) -> void:
	var row := {"phase":phase,"where":label,"event":event.as_text(),"cancel":event.is_action_pressed("ui_cancel"),"pressed":event.is_pressed(),"handled":root.is_input_handled(),"paused":paused,"panel":str(app.menu.visible_panel),"focus":control_name(root.gui_get_focus_owner()),"hover":control_name(root.gui_get_hovered_control())}
	trace.append(row)
	print("ESCAPE EVENT ", JSON.stringify(row))

func gui_trace(event: InputEvent, target: Control) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE: event_trace("GUI "+str(target.get_path()), event)

func popup_trace(target: Window) -> void:
	var row := {"phase":phase,"where":"popup_hide","popup":str(target.get_path()),"paused":paused,"panel":str(app.menu.visible_panel)}
	trace.append(row)
	print("ESCAPE POPUP ", JSON.stringify(row))

func windows_snapshot() -> Array:
	var result: Array = []
	for node: Node in root.find_children("*", "Window", true, false):
		var window := node as Window
		result.append({"path":str(window.get_path()),"visible":window.visible,"class":window.get_class()})
		if window is Popup and not window.popup_hide.is_connected(popup_trace.bind(window)):
			window.popup_hide.connect(popup_trace.bind(window))
	return result

func escape() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = pressed
		if pressed: check(event.is_action_pressed("ui_cancel"), "real Escape key matches the live ui_cancel action before dispatch")
		event_trace("before Input.parse_input_event", event)
		Input.parse_input_event(event)
		event_trace("after Input.parse_input_event", event)
		await frames(3)
	await frames(3)

func pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = Vector2(1, 0)
	Input.parse_input_event(motion)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1280, 720)
	var early := EventProbe.new()
	early.label = "early root probe"
	early.reporter = event_trace
	root.add_child(early)
	app = DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	var late := EventProbe.new()
	late.label = "late root probe"
	late.reporter = event_trace
	root.add_child(late)
	await frames(5)
	check(app.start_plains("level-design-v2-baseline/08"), "explicit native regression fixture starts actual formal Plains")
	for unused: int in 200:
		if is_instance_valid(app.stage) and not app._stage_pending: break
		await frames(1)
	check(is_instance_valid(app.stage) and not app._stage_pending, "actual formal stage finishes loading")
	check(app.build.add_item(&"escape_fixture", ItemCatalogV5.get_item(&"B28")), "explicit fixture grants a known inventory instance through BuildState")
	app.toggle_pause()
	await frames(8)
	check(paused and app.menu.visible_panel == &"build" and app._equipment_session > 0, "real pause opens the live backpack session")
	var tile: Button
	for node: Node in app.menu._root.find_children("*", "Button", true, false):
		var button := node as Button
		button.gui_input.connect(gui_trace.bind(button))
		if button.has_meta(&"instance_id"): tile = button
	check(is_instance_valid(tile) and not tile.tooltip_text.is_empty(), "actual inventory tile owns a real native tooltip")
	if not is_instance_valid(tile): await finish(early, late); return
	tile.grab_focus()
	pointer(tile.get_global_rect().get_center())
	# Same pause-focus and long native hover conditions as the failed GL movie.
	await frames(100)
	phase = "long_hover_tooltip"
	var before := {"phase":phase,"focus":control_name(root.gui_get_focus_owner()),"hover":control_name(root.gui_get_hovered_control()),"windows":windows_snapshot(),"home_scene_exists":is_instance_valid(app.home_scene),"menu_process_mode":app.menu.process_mode,"menu_input":app.menu.is_processing_input(),"menu_unhandled":app.menu.is_processing_unhandled_input()}
	trace.append(before)
	print("ESCAPE SETUP ", JSON.stringify(before))
	await escape()
	check(not paused and app.menu.visible_panel.is_empty(), "one native Escape closes backpack even after a focused tile tooltip is visible")
	# Keep the failure; next case resets only its setup with the same real menu.
	if not paused: app.toggle_pause()
	await frames(5)
	phase = "pointer_away_focused_button"
	pointer(Vector2(2, 2))
	await frames(40)
	for node: Node in app.menu._root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.name == "ResumeAdventure": button.grab_focus(); break
	print("ESCAPE CONTROL ", JSON.stringify({"phase":phase,"windows":windows_snapshot(),"focus":control_name(root.gui_get_focus_owner()),"hover":control_name(root.gui_get_hovered_control())}))
	await escape()
	check(not paused and app.menu.visible_panel.is_empty(), "native Escape with a focused real button closes backpack after pointer leaves tooltip")
	await finish(early, late)

func finish(early: Node, late: Node) -> void:
	paused = false
	check(await load("res://tests/audio_teardown.gd").drain_world(app), "formal regression fixture releases audio")
	app.free()
	app = null
	early.free()
	late.free()
	await frames(3)
	var file := FileAccess.open(OUTPUT+"/trace.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"events":trace}, "  "))
	file.close()
	print("ITEM V5 PAUSE ESCAPE: %s checks, %s failures" % [checks, failures])
	quit(1 if failures else 0)
