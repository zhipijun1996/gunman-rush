extends SceneTree
## Terminal waiting is optional; paused/restored carrier clocks stay authoritative.
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: ",label)
func ticks(count: int) -> void:
	for i: int in count: await physics_frame
func run() -> void:
	var cage := WorldMovingPlatform.new()
	cage.position=Vector2(320,480)
	cage.route=[Vector2(0,-128),Vector2(128,-128)]
	cage.period=4; cage.endpoint_dwell=1
	root.add_child(cage)
	await ticks(40)
	check(cage.position.is_equal_approx(Vector2(320,480)),"boarding terminal waits")
	await ticks(170)
	check(cage.position.is_equal_approx(Vector2(448,352)),"arrival terminal waits")
	cage.motion_running=false
	var paused_clock := cage.motion_clock
	await ticks(90)
	check(cage.motion_clock==paused_clock and cage.position.is_equal_approx(Vector2(448,352)),"pause preserves terminal dwell")
	cage.restore_motion(0,false)
	await ticks(10)
	check(cage.position.is_equal_approx(Vector2(320,480)),"restore returns to the saved terminal")
	cage.motion_running=true
	await ticks(90)
	check(cage.position.y<480 and cage.position.y>352,"resume includes boarding dwell then departs")
	var shuttle := WorldMovingPlatform.new()
	shuttle.position=Vector2(100,100);shuttle.endpoint=Vector2(200,0);shuttle.period=4
	root.add_child(shuttle)
	check(shuttle.sample_position(2).is_equal_approx(Vector2(300,100)),"ordinary shuttle keeps its previous period")
	cage.queue_free();shuttle.queue_free();await ticks(3)
	print("PLATFORM DWELL: ",failures," failures");quit(failures)
