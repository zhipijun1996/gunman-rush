extends SceneTree
## Ignored, stage-bounded real-GL/native-input probe. Snapshot ownership and
## local router pause lifecycle are fixtures, not a natural run or Android test.
var checks := 0
var failures := 0
var events: Array[Dictionary] = []
var submissions: Array[Dictionary] = []
var menu: DemoMenu
var router: InputRouter
var adapter: KeyboardMouseAdapter
var output := "res://build/item_art_01/detail-native-probe"

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("DETAIL NATIVE PROBE FAILURE: "+label)

func frames(count := 4) -> void:
	for unused: int in count: await process_frame

func rect_data(rect: Rect2) -> Array:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

func clip_rect(control: Control) -> Rect2:
	var result := Rect2(Vector2.ZERO,Vector2(root.size))
	var ancestor := control.get_parent_control()
	while ancestor != null:
		if ancestor.clip_contents: result = result.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent_control()
	return result

func geometry(button: Button, scroll: ScrollContainer) -> Dictionary:
	var clip := clip_rect(button)
	return {"scroll":scroll.scroll_vertical,"max":scroll.get_v_scroll_bar().max_value,"page":scroll.get_v_scroll_bar().page,"button_rect":rect_data(button.get_global_rect()),"clip_rect":rect_data(clip),"button_center_visible":clip.has_point(button.get_global_rect().get_center()),"button_visible_rect":rect_data(button.get_global_rect().intersection(clip))}

func screenshot(stem: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image != null and image.get_size() == Vector2i(960,540),"actual post-draw960x540 screenshot "+stem)
	if image != null: check(image.save_png(ProjectSettings.globalize_path(output).path_join(stem+".png")) == OK,"save actualGL screenshot "+stem)

func touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	events.append({"native_type":"InputEventScreenTouch","index":index,"position":[point.x,point.y],"pressed":pressed})
	Input.parse_input_event(event)
	await frames(2)

func drag(index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = relative
	events.append({"native_type":"InputEventScreenDrag","index":index,"position":[point.x,point.y],"relative":[relative.x,relative.y]})
	Input.parse_input_event(event)
	await frames(2)

func scroll_gesture(scroll: ScrollContainer, amount: float, index: int) -> void:
	var rect := scroll.get_global_rect().intersection(Rect2(Vector2.ZERO,Vector2(root.size))).grow(-20)
	var start := rect.get_center()
	var distance := clampf(amount,-rect.size.y*.4,rect.size.y*.4)
	start.y -= distance*.5
	await touch(index,start,true)
	await drag(index,start+Vector2(0,distance),Vector2(0,distance))
	await touch(index,start+Vector2(0,distance),false)

func click(point: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	events.append({"native_type":"InputEventMouseButton","position":[point.x,point.y],"pressed":pressed})
	Input.parse_input_event(event)
	await frames(2)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): output = argument.trim_prefix("--capture-dir=")
	if DisplayServer.get_name() == "headless":
		check(false,"native GL detail probe refuses dummy/headless screenshots")
		finish({"scope":"realGL required"})
		quit(1)
		return
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output)) == OK,"probe output directory writable")
	root.size = Vector2i(960,540)
	root.content_scale_size = Vector2i(960,540)
	DisplayServer.window_set_size(Vector2i(960,540))
	var origin := Node2D.new()
	root.add_child(origin)
	router = InputRouter.new()
	root.add_child(router)
	adapter = KeyboardMouseAdapter.new()
	adapter.router = router
	adapter.aim_origin = origin
	root.add_child(adapter)
	menu = DemoMenu.new()
	root.add_child(menu)
	menu.equipment_requested.connect(func(ids: Array[StringName], revision: int, session: int) -> void:
		submissions.append({"ids":ids.duplicate(),"revision":revision,"session":session}))
	# This lifecycle is an explicit local adapter fixture; it does not stand in
	# for DemoApp's genuine gameplay open/close integration.
	menu.requested_resume.connect(func() -> void:
		router.clear("probe_menu_close")
		paused = false)
	var ids: Array[StringName] = [&"B01",&"B03",&"B11",&"P24",&"P14",&"G14",&"G16",&"N01"]
	var items: Array[Dictionary] = []
	for id: StringName in ids:
		var definition := ItemCatalogV5.get_item(id)
		check(definition != null and ItemArtLibrary.has_icon(definition.icon_key),"current golden art consumer "+String(id))
		if definition == null: continue
		items.append({"instance_id":StringName("golden/"+String(id)),"definition":definition,"level":definition.max_level,"max_level":definition.max_level,"equipped":id in [&"P24",&"P14"],"active_capable":&"active" in definition.tags})
	var snapshot := {"capacity":8,"used":6,"remaining":2,"revision":71,"session":19,"coins":90,"items":items,"upgrade":{"available":false,"price":0,"capacity":8,"reason":"美术显示样板"}}
	router.clear("probe_menu_open")
	paused = true
	menu.show_build("")
	menu.set_equipment_view(snapshot)
	await frames(6)
	menu.call("_select_equipment",&"golden/G16")
	await frames(6)
	var scroll := menu.find_child("DetailScroll",true,false) as ScrollContainer
	var button := menu.find_child("EquipItem",true,false) as Button
	check(scroll != null and button != null,"actual G16 detail scroll and actual equip Button exist")
	if scroll == null or button == null:
		finish({"scope":"missing real controls"})
		quit(1)
		return
	var touch_adapter := scroll.get_node_or_null("DetailScrollTouchAdapter")
	check(touch_adapter != null,"existing DetailScrollTouchAdapter owns touch gesture")
	if touch_adapter != null:
		touch_adapter.connect("forwarded",func(phase: StringName) -> void: events.append({"adapter_phase":String(phase),"scroll":scroll.scroll_vertical}))
	var before := geometry(button,scroll)
	await screenshot("g16-detail-initial")
	check(scroll.get_v_scroll_bar().max_value>scroll.get_v_scroll_bar().page,"real G16 detail exceeds960x540 scroll viewport")
	var initial_scroll := scroll.scroll_vertical
	await scroll_gesture(scroll,-100,40)
	check(scroll.scroll_vertical>initial_scroll,"native ScreenTouch+ScreenDrag advances real DetailScroll through existing adapter")
	check(submissions.is_empty(),"detail drag does not accidentally submit an equip click")
	for index: int in 10:
		if clip_rect(button).grow(-3).has_point(button.get_global_rect().get_center()): break
		var distance := scroll.get_global_rect().get_center().y-button.get_global_rect().get_center().y
		await scroll_gesture(scroll,distance,41+index)
	var reachable := geometry(button,scroll)
	check(bool(reachable.button_center_visible),"actual equip Button center becomes reachable inside all ancestor clipping viewports")
	check(submissions.is_empty(),"all native scroll gestures preserve zero equip submissions")
	await screenshot("g16-detail-native-scrolled")
	var center := button.get_global_rect().get_center()
	if bool(reachable.button_center_visible):
		await touch(70,center,true)
		await touch(70,center,false)
	check(submissions.size() == 1,"one native ScreenTouch tap submits exactly one equipment request")
	if submissions.size() == 1:
		check(submissions[0].ids == [&"golden/P24",&"golden/P14",&"golden/G16"] and submissions[0].revision == 71 and submissions[0].session == 19,"native touch request contains exact selected instance and frozen revision/session")
	if bool(reachable.button_center_visible):
		await click(center,true)
		await click(center,false)
	check(submissions.size() == 2,"independent native mouse click submits exactly one additional equipment request")
	if submissions.size() == 2:
		check(submissions[1].ids == [&"golden/P24",&"golden/P14",&"golden/G16"] and submissions[1].revision == 71 and submissions[1].session == 19,"native mouse request contains exact selected instance and frozen revision/session")
	# Begin a second native press, close before release, then deliver its late
	# native release after unpause. Also challenge the stale closure directly.
	await click(center,true)
	menu.close_panel()
	await frames(2)
	await click(center,false)
	button.pressed.emit()
	check(submissions.size() == 2,"closed old Button and late native release remain inert")
	check(router.consume_actions(1).is_empty() and not router.aim_engaged,"local real input-router consumer has no ghost shot/action after fixture menu close")
	finish({"scope":"Actual DemoMenu native GL960x540, original8art snapshot fixture; Input.parse_input_event ScreenTouch/ScreenDrag through existing DetailScrollTouchAdapter and native mouse click. Local router pause/close fixture, not natural ownership, actual DemoApp lifecycle, Web DOM, controller or physical Android.","display_server":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"selected_instance":"golden/G16","initial":before,"reachable":reachable,"submissions":submissions,"native_events":events})
	menu.free()
	adapter.free()
	router.free()
	origin.free()
	ItemArtLibrary.clear_cache()
	await process_frame
	quit(1 if failures else 0)

func finish(data: Dictionary) -> void:
	data.checks = checks
	data.failures = failures
	var directory := ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("native-detail-receipt.json"),FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data,"  "))
		file.close()
	print("ITEM ART DETAIL NATIVE: %s checks, %s failures" % [checks,failures])
