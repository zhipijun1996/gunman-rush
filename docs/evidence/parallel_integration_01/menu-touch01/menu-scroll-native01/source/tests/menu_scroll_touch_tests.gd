extends SceneTree
## Actual native Viewport GUI routing/lifecycle fixture. Headless DisplayServer
## has no touchscreen: real Web scroll/inertia and DOM touchcancel remain separate.
var checks := 0
var failures := 0
var accepted := 0
var menu: DemoMenu

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("MENU TOUCH FAIL: " + label)

func frame() -> void:
	await process_frame
	await process_frame

func open_menu() -> Vector2:
	menu.show_home("")
	await frame()
	for button: Button in menu._content.find_children("*","Button",true,false):
		if button.text.ends_with("ACTIONS"): return button.get_global_rect().get_center()
	check(false,"actual ACTIONS button exists")
	return Vector2.ZERO

func touch(index: int, point: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event,true)
	await frame()

func run() -> void:
	check(not Input.emulate_mouse_from_touch and not Input.emulate_touch_from_mouse,"global emulation stays disabled")
	var canceled := InputEventMouseButton.new()
	canceled.pressed = false
	canceled.canceled = true
	check(not canceled.is_pressed() and not canceled.is_released(),"actual native canceled mouse is neither press nor release")
	menu = DemoMenu.new()
	root.add_child(menu)
	menu.requested_actions.connect(func() -> void: accepted += 1)
	var point: Vector2 = await open_menu()
	check(is_instance_valid(menu._scroll_touch) and menu._scroll_touch.scroll is ScrollContainer,"actual DemoMenu installs adapter on real ScrollContainer")
	await touch(0,point,true)
	check(menu._scroll_touch._finger == 0,"first actual touch owns GUI pointer")
	await touch(0,point,false)
	check(accepted == 1,"actual native GUI touch tap accepts once")
	point = await open_menu()
	await touch(1,point,true)
	await touch(2,point,true)
	check(menu._scroll_touch._finger == 1 and menu._scroll_touch._suppressed.has(2),"additional finger cannot replace owner")
	await touch(2,point,false)
	check(accepted == 1,"extra finger release cannot click")
	await touch(1,point,false)
	check(accepted == 2,"owner release still clicks exactly once")
	point = await open_menu()
	await touch(0,point,true)
	await touch(0,point,false,true)
	check(accepted == 2 and menu._scroll_touch._finger == -1,"actual canceled ScreenTouch never clicks and releases ownership")
	await touch(0,point,true)
	await touch(0,point,false)
	check(accepted == 3,"tap after cancel rearms normally")
	point = await open_menu()
	await touch(0,point,true)
	menu._scroll_touch.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await touch(0,point,false)
	check(accepted == 3 and menu._scroll_touch._finger == -1,"focus-loss cancellation does not activate button")
	await touch(0,point,true)
	# Callback contract only; root verifies real DOM touchcancel in Web separately.
	menu._scroll_touch._web_touch_cancel([])
	await touch(0,point,false)
	check(accepted == 3 and menu._scroll_touch._finger == -1,"early Web cancellation callback rejects subsequent ordinary release")
	await touch(0,point,true)
	menu.hide_home()
	await touch(0,point,false)
	check(accepted == 3 and menu._scroll_touch._finger == -1,"actual menu hide cancels pending press")
	point = await open_menu()
	await touch(0,point,true)
	var old_adapter: Node = menu._scroll_touch
	menu.show_title()
	await frame()
	await touch(0,point,false)
	check(accepted == 3 and not is_instance_valid(old_adapter),"replacement frees old pointer owner without activating prior button")
	point = await open_menu()
	await touch(0,point,true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = point + Vector2(0,100)
	drag.relative = Vector2(0,100)
	root.push_input(drag,true)
	await frame()
	await touch(0,drag.position,false)
	check(accepted == 3 and menu._scroll_touch._finger == -1,"drag leaving real Button does not accept a tap")
	check(not Input.emulate_mouse_from_touch and not Input.emulate_touch_from_mouse,"all fixtures preserve actual global input settings")
	menu.queue_free()
	await frame()
	print("MENU SCROLL TOUCH: %s checks / %s failures; native GUI lifecycle only, Web scrolling separate" % [checks,failures])
	quit(1 if failures else 0)
