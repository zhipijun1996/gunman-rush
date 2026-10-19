extends SceneTree
## Actual native Viewport GUI routing/lifecycle fixture. Headless DisplayServer
## has no touchscreen: real Web scroll/inertia and DOM touchcancel remain separate.
var checks := 0
var failures := 0
var accepted := 0
var menu: DemoMenu
var spawn_consumer := false
var player: PlayerMotor
var controller: PlayerController
var overlay: TouchOverlay
var shots := 0
var traversal_actions := 0
var slider_changes := 0
var scroll_mouse_buttons := 0
var scroll_mouse_motion := 0

func observe_scroll(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT: scroll_mouse_buttons += 1
	if event is InputEventMouseMotion: scroll_mouse_motion += 1

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
	menu._scroll_touch.scroll.gui_input.connect(observe_scroll)
	for button: Button in menu._content.find_children("*","Button",true,false):
		if button.text.ends_with("ACTIONS"):
			check(button.mouse_filter == Control.MOUSE_FILTER_PASS,"actual menu Button passes pointer events to existing ScrollContainer")
			return button.get_global_rect().get_center()
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

func actions_accepted() -> void:
	accepted += 1
	if not spawn_consumer: return
	player = load("res://scenes/player/player.tscn").instantiate() as PlayerMotor
	root.add_child(player)
	controller = player.get_node("Controller") as PlayerController
	controller.traversal.grant(&"grapple")
	overlay = InputSetup.attach(player,controller.router)
	# Explicit native consumer fixture, not a fake DisplayServer touchscreen.
	# Global mouse/touch emulation remains disabled throughout.
	overlay.set_enabled(true)
	controller.shoot_ability.shot_fired.connect(func(_aim: Vector2,_id: int) -> void: shots += 1)
	controller.traversal.action_changed.connect(func(_action: StringName) -> void: traversal_actions += 1)

func run() -> void:
	var menu_font := DemoMenu.create_theme().default_font
	for text: String in ["DEVELOPMENT DEMOS / ALL ENTRIES", "ACTIONS", "HOME / SETTINGS"]:
		check(menu_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,18) == ThemeDB.fallback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,18),"CJK fallback preserves exact Latin advance: " + text)
	for character: String in "动作练习风铃平原":
		check(menu_font.has_char(character.unicode_at(0)),"actual menu font covers Chinese glyph: " + character)
	check(not Input.emulate_mouse_from_touch and not Input.emulate_touch_from_mouse,"global emulation stays disabled")
	var canceled := InputEventMouseButton.new()
	canceled.pressed = false
	canceled.canceled = true
	check(not canceled.is_pressed() and not canceled.is_released(),"actual native canceled mouse is neither press nor release")
	menu = DemoMenu.new()
	root.add_child(menu)
	menu.requested_actions.connect(actions_accepted)
	var point: Vector2 = await open_menu()
	check(is_instance_valid(menu._scroll_touch) and menu._scroll_touch.scroll is ScrollContainer,"actual DemoMenu installs adapter on real ScrollContainer")
	await touch(0,point,true)
	check(menu._scroll_touch._finger == 0,"first actual touch owns GUI pointer")
	check(scroll_mouse_buttons == 1 and scroll_mouse_motion >= 1,"actual converted left press and hover reach native ScrollContainer through menu Button")
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
	menu.show_settings(false)
	await frame()
	var slider := menu._sliders.left_sensitivity as HSlider
	var scroll := menu._scroll_touch.scroll as ScrollContainer
	scroll.gui_input.connect(observe_scroll)
	var slider_scroll_buttons_before := scroll_mouse_buttons
	var scroll_before := scroll.scroll_vertical
	var slider_before := slider.value
	slider.value_changed.connect(func(_value: float) -> void: slider_changes += 1)
	var slider_rect := slider.get_global_rect()
	var slider_start := slider_rect.position + Vector2(slider_rect.size.x*0.35,slider_rect.size.y*0.5)
	var slider_end := slider_rect.position + Vector2(slider_rect.size.x*0.8,slider_rect.size.y*0.5)
	await touch(0,slider_start,true)
	var slider_drag := InputEventScreenDrag.new()
	slider_drag.index = 0
	slider_drag.position = slider_end
	slider_drag.relative = slider_end-slider_start
	root.push_input(slider_drag,true)
	await frame()
	await touch(0,slider_end,false)
	check(slider.value > slider_before and slider_changes >= 1 and slider_changes <= 2,"nested actual HSlider changes through native GUI with no duplicate value dispatch")
	check(scroll.scroll_vertical == scroll_before and menu._scroll_touch._finger == -1,"horizontal Slider gesture neither scrolls parent nor leaves pointer owned")
	check(slider.mouse_filter == Control.MOUSE_FILTER_STOP and scroll_mouse_buttons == slider_scroll_buttons_before,"actual HSlider keeps STOP and consumes pointer without duplicate parent press")
	# Create the real player/router/overlay from the actual button callback. The
	# suppressed second finger began before this consumer existed, so its later
	# drag/release must not become a new aim, shot, H cast or movement intent.
	point = await open_menu()
	await touch(10,point,true)
	await touch(11,point,true)
	spawn_consumer = true
	await touch(10,point,false)
	check(accepted == 4 and is_instance_valid(controller) and overlay.enabled,"actual owner callback hides menu and creates real touch gameplay consumer")
	var sequence_before := controller.router.sequence
	for target: Vector2 in [overlay.left_center+Vector2(50,0),overlay.right_center+Vector2(40,0),overlay.hook_center+Vector2(40,0)]:
		var tail := InputEventScreenDrag.new()
		tail.index = 11
		tail.position = target
		tail.relative = Vector2(40,0)
		root.push_input(tail,true)
		await frame()
	await touch(11,overlay.hook_center,false)
	check(controller.router.sequence == sequence_before and controller.router._queue.is_empty(),"old extra finger produces zero actual router action intents after menu changes")
	check(controller.router.axis == 0.0 and controller.router.look_axis == 0.0 and not controller.router.aim_engaged and overlay._captures.is_empty(),"old extra finger leaves actual movement/aim/capture state neutral")
	check(shots == 0 and traversal_actions == 0,"real player accepts neither projectile nor H action from trailing menu finger")
	player.queue_free()
	await frame()
	check(not Input.emulate_mouse_from_touch and not Input.emulate_touch_from_mouse,"extended actual consumers preserve global settings")
	menu.queue_free()
	await frame()
	print("MENU SCROLL TOUCH: %s checks / %s failures; native GUI lifecycle only, Web scrolling separate" % [checks,failures])
	quit(1 if failures else 0)
