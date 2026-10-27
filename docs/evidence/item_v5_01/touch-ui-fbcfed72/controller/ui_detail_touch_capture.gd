extends "res://tests/item_v5_ui_input_runner.gd"
## External evidence controller. Runtime/UI source stays at FBC; only this ignored
## fixture adds native touch gestures and observes the existing menu signal.
const FROZEN_SOURCE := "fbcfed72a5c6c266228c3f8f32eaf56a1739fa0d"
var control_events: Array[Dictionary] = []
var control_requests: Array[Dictionary] = []
var control_stem := ""
var control_finger := 900

func control_frames(count: int) -> void:
	for unused: int in count: await process_frame

func record_request(ids: Array[StringName], revision: int, session: int) -> void:
	control_requests.append({"capture":control_stem,"proposed_instance_ids":ids.duplicate(),"revision":revision,"session":session})

func touch_edge(finger: int, location: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = location
	event.pressed = pressed
	Input.parse_input_event(event)
	control_events.append({"capture":control_stem,"type":"ScreenTouch","finger":finger,"position":[location.x,location.y],"pressed":pressed,"frame":Engine.get_process_frames()})

func touch_drag(finger: int, location: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger
	event.position = location
	event.relative = relative
	Input.parse_input_event(event)
	control_events.append({"capture":control_stem,"type":"ScreenDrag","finger":finger,"position":[location.x,location.y],"relative":[relative.x,relative.y],"frame":Engine.get_process_frames()})

func visible_detail(scroll: ScrollContainer) -> Rect2:
	return scroll.get_global_rect().intersection(root.get_visible_rect())

func swipe_detail(scroll: ScrollContainer, upward: bool, distance: float = 150.0) -> void:
	var clip := visible_detail(scroll)
	var travel := minf(distance,maxf(0.0,clip.size.y-36.0))
	var start := Vector2(clip.get_center().x,clip.end.y-18.0 if upward else clip.position.y+18.0)
	var finish := start+Vector2(0,-travel if upward else travel)
	control_finger += 1
	touch_edge(control_finger,start,true)
	await control_frames(2)
	var previous := start
	for step: int in 6:
		var next := start.lerp(finish,float(step+1)/6.0)
		touch_drag(control_finger,next,next-previous)
		previous = next
		await control_frames(2)
	touch_edge(control_finger,finish,false)
	await control_frames(4)

func reach_and_tap(menu: DemoMenu) -> Dictionary:
	var scroll := menu.find_child("DetailScroll",true,false) as ScrollContainer
	var action := menu.find_child("EquipItem",true,false) as Button
	check(scroll != null and action != null and not action.disabled,"960 control evidence owns the real enabled detail-scroll equipment button")
	if scroll == null or action == null: return {}
	var inherited_scroll := scroll.scroll_vertical
	# Each selected item starts from the actual top using reverse touch swipes,
	# including G19 after the preceding P18 case retained its old scroll offset.
	for unused: int in 14:
		if scroll.scroll_vertical <= 0: break
		await swipe_detail(scroll,false)
	check(scroll.scroll_vertical == 0,"real reverse touch gestures establish the detail top before each reachability case")
	var initial_scroll := scroll.scroll_vertical
	var initial_rect := action.get_global_rect()
	var drag_count := 0
	# Reach the native scroll's actual end using only real routed touch input.
	for unused: int in 14:
		var bar := scroll.get_v_scroll_bar()
		if scroll.scroll_vertical >= maxf(0.0,bar.max_value-bar.page)-0.5: break
		await swipe_detail(scroll,true)
		drag_count += 1
	var bottom := scroll.scroll_vertical
	var bar := scroll.get_v_scroll_bar()
	check(bottom >= maxf(0.0,bar.max_value-bar.page)-0.5,"real ScreenTouch/Drag reaches the native detail scroll bottom")
	# If later footer content puts the action above the viewport at the very
	# bottom, bring it back by a real reverse gesture instead of ensure_visible.
	for unused: int in 8:
		var clip := visible_detail(scroll).grow(0.5)
		var rect := action.get_global_rect()
		if clip.encloses(rect): break
		await swipe_detail(scroll,rect.end.y > clip.end.y,48.0)
		drag_count += 1
	var button_rect := action.get_global_rect()
	var fully_visible := action.is_visible_in_tree() and visible_detail(scroll).grow(0.5).encloses(button_rect) and root.get_visible_rect().grow(0.5).encloses(button_rect)
	check(drag_count > 0 and scroll.scroll_vertical > initial_scroll,"960 equipment action is reached by actual touch scrolling, not an assigned offset")
	check(fully_visible,"real 960 equipment button is fully inside both detail clip and viewport before tapping")
	var previous_requests := control_requests.size()
	if fully_visible:
		control_finger += 1
		var center := button_rect.get_center()
		touch_edge(control_finger,center,true)
		await control_frames(3)
		touch_edge(control_finger,center,false)
		await control_frames(5)
	var count := control_requests.size()-previous_requests
	check(count == 1,"one real ScreenTouch tap emits exactly one existing equipment_requested signal")
	if count == 1:
		var request := control_requests[-1]
		check(menu._selected_instance_id in request.proposed_instance_ids and request.revision == 71 and request.session == 19,"native detail tap carries the selected instance and original snapshot revision/session")
	return {"scope":"actual native touch scrolling and one equipment_requested GUI signal only; no BuildState submit, natural ownership or applied effect claim","inherited_detail_scroll":inherited_scroll,"initial_button_rect":str(initial_rect),"initial_detail_scroll":initial_scroll,"reached_scroll_bottom":bottom,"final_detail_scroll":scroll.scroll_vertical,"actual_swipe_count":drag_count,"button_rect":str(action.get_global_rect()),"detail_clip":str(visible_detail(scroll)),"button_fully_visible":fully_visible,"equipment_signal_count":count}

func capture_menu_png(menu: DemoMenu, directory: String, stem: String, dimensions: Vector2i, rows: Array) -> void:
	control_stem = stem
	var interaction: Dictionary = {}
	if dimensions == Vector2i(960,540):
		if not menu.equipment_requested.is_connected(record_request): menu.equipment_requested.connect(record_request)
		interaction = await reach_and_tap(menu)
	# Keep the frozen parent screenshot implementation: same real post-draw
	# image, no compositing, generated imagery or direct Control callback calls.
	await super.capture_menu_png(menu,directory,stem,dimensions,rows)
	if not rows.is_empty(): rows[-1]["external_touch_control"] = interaction
	var file := FileAccess.open(directory.path_join("external-touch-control-trace.json"),FileAccess.WRITE)
	check(file != null,"external native touch evidence trace can be written")
	if file != null:
		file.store_string(JSON.stringify({"frozen_source_commit":FROZEN_SOURCE,"external_fixture":get_script().resource_path,"external_fixture_sha256":FileAccess.get_sha256(get_script().resource_path),"scope":"software GL and mobile layout proxy; real ScreenTouch/Drag GUI requests, not physical Android or equipment business acceptance","input_events":control_events,"equipment_requests":control_requests},"  "))
		file.close()
