extends SceneTree
var checks:=0
var failures:Array[String]=[]
func _init()->void:_run.call_deferred()
func check(ok:bool,msg:String)->void:
	checks+=1
	if not ok:failures.append(msg);printerr("FAIL: "+msg)
func _run()->void:
	root.size=Vector2i(1280,720)
	var app:=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
	check(app.start_plains("level-design-v2-baseline/08"),"normal actual formal start")
	for i:int in 20:await physics_frame
	var driver=load("res://tests/level_formal_trace.gd").new()
	check(driver.attach(app,"fast",0,"kill_from_bank_v1"),"existing real route driver attaches to actual formal consumer")
	driver.frame_budget=6000
	var parallax:=app.get_node("PixelPlainsParallax") as PixelPlainsParallax
	var initial:=parallax.measured_nodes()
	var initial_camera:=app.get_viewport().get_camera_2d().get_screen_center_position()
	var epoch:=app.lifetime.actor_epoch
	var route_ok:bool=await driver.tutorial()
	check(route_ok,"real Motor completes actual tutorial approach")
	check(driver._recovery_serial==0 and app.lifetime.actor_epoch==epoch,"route has no resets or recovery teleport")
	check(driver.events.any(func(e:Dictionary):return e.kind=="jump_accepted"),"route has actual accepted jump events")
	check(driver.events.any(func(e:Dictionary):return e.kind=="shot_accepted"),"route has actual accepted shot events")
	# CameraRig and CanvasLayer update in different process order. Observe a
	# naturally settled camera rather than comparing two adjacent-frame clocks.
	for i:int in 180:await physics_frame
	var after:=parallax.measured_nodes()
	var camera_after:=app.get_viewport().get_camera_2d().get_screen_center_position()
	check(absf(camera_after.x-initial_camera.x)>200,"real route moves actual camera horizontally")
	var hashes:Array=[]
	var displacements:Array=[]
	for index:int in 3:
		check(parallax.panels[index*3].is_visible_in_tree(),"actual visible parallax layer "+str(index))
		hashes.append(after[index].texture_sha256)
		var dx:float=after[index].unwrapped_offset[0]-initial[index].unwrapped_offset[0]
		displacements.append(absf(dx))
		check(absf(dx+(camera_after.x-initial_camera.x)*PixelPlainsParallax.RATES[index].x)<.01,"actual distinct camera-dependent rate "+str(index))
	check(hashes[0]!=hashes[1] and hashes[1]!=hashes[2] and hashes[0]!=hashes[2],"three independent original source image bytes")
	check(displacements[0]<displacements[1] and displacements[1]<displacements[2],"far/middle/near observed travel grows with depth")
	var file:=FileAccess.open("res://build/pixel-review/formal_route.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"normal actual formal tutorial only; not whole campaign or Boss victory","source":"300d65c+dirty","checks":checks,"failures":failures,"frames":driver.observed_frames,"events":driver.events,"diagnostics":driver.diagnostics,"before":initial,"after":after,"camera_before":str(initial_camera),"camera_after":str(camera_after)},"  "))
	driver.terminated=true
	check(await load("res://tests/audio_teardown.gd").drain_world(app),"owned actual audio drains")
	app.free();driver=null
	for i:int in 10:await process_frame
	print("PIXEL_FORMAL_ROUTE checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
