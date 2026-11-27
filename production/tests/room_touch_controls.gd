extends SceneTree
## Exercise the same viewport dispatch as an Android finger, including modal map input.
class Field extends WorldGameHost:
	func startup_destination() -> Dictionary: return {"ok":true,"room":"P02"}
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL room touch: ",label)

func touch(id: int, at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = at
	event.pressed = down
	root.push_input(event,true)

func drag(id: int, from: Vector2, to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = id
	event.position = to
	event.relative = to-from
	root.push_input(event,true)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var field := Field.new()
	root.add_child(field)
	for tick: int in 150: await physics_frame
	if field.active == null:
		check(false,"field boot")
		quit(1)
		return
	var controls := field.active.touch_controls
	controls.set_enabled(true)
	var router := controls.router
	var from := controls.left_center
	touch(1,from,true)
	drag(1,from,from+Vector2.RIGHT*controls.radius)
	check(router.current_device==&"touch" and router.sample_axes()>.9,"left thumb drives the active player")
	touch(2,controls.map_button.get_center(),true)
	check(paused and field.route_map.visible and is_zero_approx(router.sample_axes()),"map opens by touch and clears held movement")
	touch(2,controls.map_button.get_center(),false)
	var map_view: WorldRouteMap = field.route_map
	var center := map_view.canvas.get_global_rect().get_center()
	var scroll := InputEventMouseButton.new()
	scroll.button_index = MOUSE_BUTTON_WHEEL_UP
	scroll.position = center
	scroll.pressed = true
	root.push_input(scroll,true)
	check(map_view.canvas.zoom>1.1 and map_view.canvas.clip_contents and not map_view.canvas.get_global_rect().intersects(map_view.close_button.get_global_rect()),"wheel zoom stays clipped inside the map and leaves its close control accessible")
	map_view.canvas.reset_view()
	touch(3,center,true)
	drag(3,center,center+Vector2(46,0))
	check(paused and map_view.visible and map_view.canvas.pan.x>40,"a map drag pans without dismissing the map or moving the player")
	touch(4,center-Vector2(40,0),true)
	drag(4,center-Vector2(40,0),center-Vector2(45,0))
	drag(4,center-Vector2(45,0),center-Vector2(112,0))
	check(map_view.canvas.zoom>1.5 and is_zero_approx(router.sample_axes()),"two fingers zoom the clipped map without reaching the joysticks")
	touch(3,center+Vector2(46,0),false)
	touch(4,center-Vector2(112,0),false)
	var close_at := map_view.close_button.get_global_rect().get_center()
	touch(3,close_at,true)
	touch(3,close_at,false)
	check(not paused and not map_view.visible,"the visible close control dismisses the map by native touch")
	drag(1,from+Vector2.RIGHT*controls.radius,from+Vector2.RIGHT*controls.radius*.8)
	touch(1,from,false)
	check(is_zero_approx(router.sample_axes()),"the old contact cannot restart walking after a modal")
	await field.active.audio_service.shutdown()
	field.free()
	print("ROOM TOUCH CONTROLS failures=",failures)
	quit(1 if failures else 0)
