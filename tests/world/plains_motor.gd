extends SceneTree
## Fixed start fixtures exercise the production Router/Motor, never simulated range arithmetic.
var app: FixedWorldApp
var failures:=0
func _initialize() -> void:run.call_deferred()
func ticks(n: int) -> void:
	for i: int in n:await physics_frame
func settle() -> void:
	for i: int in 240:
		await physics_frame
		if not app.busy:return
func attempt(recoil: bool) -> Vector2:
	app.controller.router.clear("fixture");app.player.reset_at(Vector2(548,717));await ticks(6)
	app.controller.router.set_source_axis(&"keyboard_mouse",1)
	app.controller.router.set_jump_held(&"keyboard_mouse",true)
	var min_y:=app.player.position.y
	for i: int in 100:
		await physics_frame
		if i==8 and recoil:app.controller.router.request_action(&"shoot_release",Vector2.LEFT)
		if i==15:app.controller.router.set_jump_held(&"keyboard_mouse",false)
		min_y=minf(min_y,app.player.position.y)
		if i>12 and app.player.is_on_floor():break
	app.controller.router.set_source_axis(&"keyboard_mouse",0)
	print("MOTOR recoil=",recoil," landed=",app.player.position," apex=",min_y)
	return app.player.position
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_motor_fixture.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);app.start_new();await settle();app.load_room("P-R22","");await settle()
	if app.room.room_id!="P-R22":printerr("LOAD ",app.status);quit(1);return
	var ordinary:=await attempt(false)
	var recoiled:=await attempt(true)
	if ordinary.y<800 or recoiled.y>740 or recoiled.x<800:failures+=1
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5);print("PLAINS MOTOR: ",failures," failures");quit(failures)
