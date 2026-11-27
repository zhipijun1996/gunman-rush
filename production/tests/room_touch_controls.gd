extends SceneTree
## Exercise the same viewport dispatch as an Android finger, including modal map input.
const FIELD := preload("res://rooms/world/P02.tscn")
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
	var field: FieldTerracePilot = FIELD.instantiate()
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
	touch(3,root.get_visible_rect().get_center(),true)
	check(not paused and not field.route_map.visible,"another tap closes the map without a keyboard")
	touch(3,root.get_visible_rect().get_center(),false)
	drag(1,from+Vector2.RIGHT*controls.radius,from+Vector2.RIGHT*controls.radius*.8)
	touch(1,from,false)
	check(is_zero_approx(router.sample_axes()),"the old contact cannot restart walking after a modal")
	await field.active.audio_service.shutdown()
	field.free()
	print("ROOM TOUCH CONTROLS failures=",failures)
	quit(1 if failures else 0)
