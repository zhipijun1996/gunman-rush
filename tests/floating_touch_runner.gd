extends SceneTree

var assertions := 0
var failures := 0
var _tick := 200000
var router: InputRouter
var overlay: TouchOverlay

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func touch(index: int, point: Vector2, pressed: bool, cancelled := false) -> bool:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = cancelled
	return overlay.handle_touch(event)

func drag(index: int, point: Vector2) -> bool:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	return overlay.handle_touch(event)

func actions() -> Array[Dictionary]:
	_tick += 1
	return router.consume_actions(_tick)

func _run() -> void:
	# Preserve the existing full keyboard/gamepad/focus cancellation regression.
	await load("res://tests/input_tests.gd").new().run(self, check)
	var world := Node2D.new()
	root.add_child(world)
	router = InputRouter.new()
	world.add_child(router)
	overlay = InputSetup.attach(world, router)
	(world.get_node("GamepadAdapter") as GamepadAdapter).set_physics_process(false)
	overlay.set_enabled(true)
	var safe := overlay._safe_rect
	var origin_left := safe.position + safe.size * Vector2(0.20, 0.28)
	var origin_right := safe.position + safe.size * Vector2(0.76, 0.31)
	# Comfortable hit target and stable touch speeds are observed through the
	# actual adapter, not by calling its movement mapping directly.
	overlay._configure_layout(Rect2(0, 0, 1280, 720), root.get_visible_rect().size)
	check(is_equal_approx(overlay.jump_radius, 64.0) and is_equal_approx(overlay.jump_hit_radius, 76.0), "default visible/hit radii are 64/76")
	check(overlay.jump_center.is_equal_approx(Vector2(1140, 606)), "jump shifts 68px left in reference viewport")
	for edge_direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var edge := overlay.jump_center + edge_direction * 75.0
		check(touch(8, edge, true) and overlay._captures.get(8) == &"jump", "near-miss outside visible button still captures jump")
		check(actions()[0].type == &"jump", "padded edge emits real jump edge")
		touch(8, edge + Vector2(100, 100), false)
		check(actions()[0].type == &"jump_release", "jump release remains captured outside enlarged button")
	check(not router.reconfigure({"touch_jump_hit_padding": -1.0}), "negative hit padding rejected")
	check(not router.reconfigure({"touch_jump_left_inset": INF}), "nonfinite jump inset rejected")
	check(not router.reconfigure({"touch_run_exit": 0.8}), "inverted run hysteresis rejected")
	check(not router.reconfigure({"touch_move_mode": "unknown"}), "unknown movement mode rejected")
	touch(0, origin_left, true)
	for sample: Vector2 in [Vector2(0.10, 0), Vector2(0.25, 0.55), Vector2(0.50, 0.55), Vector2(0.65, 0.55), Vector2(0.75, 1), Vector2(0.70, 1), Vector2(0.60, 1), Vector2(0.55, 0.55), Vector2(0.20, 0.55), Vector2(0.15, 0.55), Vector2(0.10, 0), Vector2(0.15, 0), Vector2(-0.25, -0.55), Vector2(-1, -1)]:
		drag(0, origin_left + Vector2(overlay.radius * sample.x, 0))
		check(is_equal_approx(router.axis, sample.y), "stable walk/run and neutral hysteresis at %s" % sample.x)
	touch(0, origin_left, false)
	check(router.axis == 0 and not overlay._move_running, "release clears running gear")
	for mode: String in ["digital", "analog"]:
		check(router.reconfigure({"touch_move_mode": mode}), "alternate movement mode applies")
		touch(0, origin_left, true)
		drag(0, origin_left + Vector2(overlay.radius * 0.4, 0))
		check(is_equal_approx(router.axis, 1.0 if mode == "digital" else 0.4), "alternate mode changes actual routed intent")
		router.clear("movement_mode_test")
		check(router.axis == 0 and overlay._move_direction == 0.0, "cancel clears motion and touch hysteresis")
	check(router.reconfigure({"touch_move_mode": "two_step"}), "restore two-step defaults")
	check(touch(0, origin_left, true) and touch(1, origin_right, true), "arbitrary upper screen positions independently capture both sticks")
	check(overlay.left_center == origin_left and overlay.right_center == origin_right, "both floating centers equal their exact initial screen touches")
	check(router.axis == 0 and router.aim_direction == Vector2.ZERO and not router.aim_engaged and actions().is_empty(), "initial floating touches cannot move, aim, or shoot")
	check(drag(0, origin_left + Vector2(overlay.radius * 2, 0)), "left floating finger can drag beyond its ring")
	check(router.axis > 0.99, "left floating movement uses displacement from its new origin")
	check(drag(1, origin_right + Vector2(overlay.radius, -overlay.radius)), "right floating finger updates diagonal vector")
	check(router.aim_direction.is_equal_approx(Vector2(1, -1).normalized()) and router.aim_engaged, "right vector uses floating origin instead of actor or idle stick center")
	check(touch(2, overlay.jump_center, true), "third independent finger captures jump on right")
	var edges := actions()
	check(edges.size() == 1 and edges[0].type == &"jump" and router.axis > 0.99, "jump request preserves both active sticks")
	touch(2, overlay.jump_center, false)
	edges = actions()
	check(edges.size() == 1 and edges[0].type == &"jump_release" and overlay._captures.size() == 2, "jump release preserves two joystick captures")
	touch(1, origin_right + Vector2(overlay.radius, -overlay.radius), false)
	edges = actions()
	check(edges.size() == 1 and edges[0].type == &"shoot_release" and edges[0].direction.is_equal_approx(Vector2(1, -1).normalized()), "floating diagonal release shoots exactly once with world unit vector")
	check(router.axis > 0.99 and not router.aim_engaged, "aim release leaves movement and disables active aim")
	check(not touch(1, origin_right, false) and actions().is_empty(), "old release cannot fire twice")
	touch(0, origin_left, false)
	check(router.axis == 0 and overlay.left_center == overlay._left_idle and overlay.right_center == overlay._right_idle, "released floating controls restore neutral idle hints")

	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		touch(3, origin_right, true)
		drag(3, origin_right + direction * overlay.radius)
		check(router.aim_direction.is_equal_approx(direction), "all floating cardinal aim directions use exact displacement: %s" % direction)
		touch(3, origin_right + direction * overlay.radius, false)
		edges = actions()
		check(edges.size() == 1 and edges[0].direction.is_equal_approx(direction), "all floating cardinal release directions preserved: %s" % direction)

	var previous_canvas := root.canvas_transform
	root.canvas_transform = Transform2D(PI / 2, Vector2(100, 50))
	touch(3, origin_right, true)
	drag(3, origin_right + Vector2(overlay.radius, 0))
	check(router.aim_direction.is_equal_approx(Vector2.UP), "rotated world camera maps floating screen-right aim to world-up")
	touch(3, origin_right + Vector2(overlay.radius, 0), false)
	edges = actions()
	check(edges.size() == 1 and edges[0].direction.is_equal_approx(Vector2.UP), "world-direction release survives camera transform")
	root.canvas_transform = previous_canvas

	touch(3, origin_right, true)
	touch(3, origin_right, false)
	check(actions().is_empty(), "tap without vector does not shoot")
	touch(3, origin_right, true)
	drag(3, origin_right + Vector2(overlay.radius, 0))
	drag(3, origin_right + Vector2(overlay.radius * 0.1, 0))
	touch(3, origin_right + Vector2(overlay.radius * 0.1, 0), false)
	check(actions().is_empty(), "returning inside floating deadzone before release cancels the shot")

	# The active right ring may overlap Jump, but Jump retains independent priority.
	touch(3, overlay.jump_center - Vector2(overlay.jump_hit_radius + 1, 0), true)
	check(overlay.right_center.distance_to(overlay.jump_center) < overlay.radius + overlay.jump_hit_radius, "priority fixture really overlaps the active aiming ring and Jump")
	check(touch(4, overlay.jump_center, true) and overlay._captures.get(4) == &"jump", "jump hit priority survives an overlapping floating ring")
	touch(4, overlay.jump_center, false)
	actions()
	router.clear("priority_fixture_done")

	for reason: String in ["pause", "death", "segment_return", "input_profile_changed", "application_focus_out"]:
		touch(0, origin_left, true)
		drag(0, origin_left + Vector2(overlay.radius, 0))
		touch(1, origin_right, true)
		drag(1, origin_right + Vector2(0, -overlay.radius))
		router.clear(reason)
		check(overlay._captures.is_empty() and router.axis == 0 and router.aim_direction == Vector2.ZERO, "cancel clears floating gestures: " + reason)
		touch(1, origin_right + Vector2(0, -overlay.radius), false)
		check(actions().is_empty(), "cancelled floating release never shoots: " + reason)

	touch(1, origin_right, true)
	drag(1, origin_right + Vector2(overlay.radius, 0))
	touch(1, origin_right, false, true)
	check(overlay._captures.is_empty() and actions().is_empty(), "OS touch cancellation discards armed floating shot")

	# Safe layout test includes narrow portrait and notched/inset viewport rectangles.
	for layout: Rect2 in [Rect2(0, 0, 1280, 720), Rect2(0, 0, 640, 360), Rect2(0, 0, 360, 640), Rect2(42, 20, 560, 310)]:
		overlay._configure_layout(layout, root.get_visible_rect().size)
		check(overlay.jump_center.x - overlay.jump_hit_radius > overlay._right_idle.x + overlay.radius, "jump sits entirely to right of idle aim ring at %s" % layout)
		check(overlay._left_idle.x + overlay.radius < overlay._right_idle.x - overlay.radius, "idle stick rings remain separate at %s" % layout)
		for center: Vector2 in [overlay._left_idle, overlay._right_idle]:
			check(layout.encloses(Rect2(center - Vector2.ONE * overlay.radius, Vector2.ONE * overlay.radius * 2)), "idle ring respects safe-area bounds at %s" % layout)
		check(layout.encloses(Rect2(overlay.jump_center - Vector2.ONE * overlay.jump_hit_radius, Vector2.ONE * overlay.jump_hit_radius * 2)), "jump hit region respects safe-area bounds at %s" % layout)
		var edge := layout.position + Vector2(layout.size.x - 1, layout.size.y * 0.5)
		check(touch(5, edge, true) and overlay.right_center == edge, "edge touch has exact origin and no clamping offset at %s" % layout)
		check(router.aim_direction == Vector2.ZERO and actions().is_empty(), "edge press cannot fabricate a shoot vector at %s" % layout)
		touch(5, edge, false)
		check(actions().is_empty(), "edge tap does not shoot at %s" % layout)
		check(not touch(6, layout.position - Vector2.ONE, true), "outside safe area does not capture at %s" % layout)
	check(router.reconfigure({"touch_radius": 1000.0, "touch_jump_radius": 500.0}), "oversized configurable profile remains valid")
	overlay._configure_layout(Rect2(0, 0, 360, 640), root.get_visible_rect().size)
	check(overlay._right_idle.x - overlay.radius >= 180.0 and overlay._left_idle.x + overlay.radius <= 180.0, "oversized rings fit their own narrow-screen input halves")
	check(overlay._safe_rect.encloses(Rect2(overlay.jump_center - Vector2.ONE * overlay.jump_hit_radius, Vector2.ONE * overlay.jump_hit_radius * 2)), "oversized jump region fits safe viewport")
	check(router.load_profile("res://config/input_profile.json"), "touch layout fixture restores configured defaults")
	overlay.update_layout()

	# Verify actual GUI dispatch: an ordinary Button consumes ScreenTouch before
	# _unhandled_input, rather than letting a floating joystick steal menu input.
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 50
	world.add_child(ui_layer)
	var blocker := Button.new()
	blocker.position = origin_right - Vector2(30, 30)
	blocker.size = Vector2(60, 60)
	blocker.text = "UI"
	ui_layer.add_child(blocker)
	await process_frame
	var handled_events := [0]
	blocker.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenTouch:
			handled_events[0] += 1
			blocker.accept_event())
	var gui_touch := InputEventScreenTouch.new()
	gui_touch.index = 9
	gui_touch.position = origin_right
	gui_touch.pressed = true
	root.push_input(gui_touch, true)
	check(handled_events[0] == 1 and overlay._captures.is_empty(), "real Button GUI touch is handled before floating overlay")
	gui_touch = InputEventScreenTouch.new()
	gui_touch.index = 9
	gui_touch.position = origin_right
	gui_touch.pressed = false
	root.push_input(gui_touch, true)
	check(handled_events[0] == 2 and actions().is_empty(), "real Button release cannot leak a floating shot")
	world.free()
	await process_frame
	if "--verify-failure-exit" in OS.get_cmdline_user_args():
		check(false, "intentional failure proves nonzero exit")
	print("FLOATING TOUCH: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
