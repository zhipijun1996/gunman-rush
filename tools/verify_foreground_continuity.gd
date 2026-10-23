extends "res://tools/capture_depth_frame.gd"
## Actual Home consumer, deterministic camera/reversal, real collision/UI probes.
## Camera and injected guard are diagnostic stimuli, not traversal/combat evidence.
var foreground: Node
var timeline: Array[Dictionary]=[]
var identities: Dictionary={}
var _previous: Dictionary={}
var _previous_center:=Vector2.ZERO
var _samples:=0

func _initialize() -> void:
	output="res://build/foreground_continuity_08/check"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	run_capture.call_deferred()

func find_foreground(node: Node) -> Node:
	if node.get_script()!=null and str(node.get_script().resource_path).ends_with("underworld_foreground.gd"):return node
	for child: Node in node.get_children():
		var found:=find_foreground(child)
		if found!=null:return found
	return null

func snapshot(label: String) -> Dictionary:
	var report: Dictionary=foreground.call("receipt")
	var center: Array=report.get("camera",[0,0])
	var current:=Vector2(float(center[0]),float(center[1]))
	var present: Dictionary={}
	for row: Dictionary in report.get("residents",[]):
		var id:=str(row.id)
		var identity: Array=[row.asset,row.world_anchor,row.display_scale,row.get("wind_phase",0)]
		if identities.has(id):check(identities[id]==identity,"resident identity/size/anchor stable "+id)
		else:identities[id]=identity
		present[id]=row
	for id: String in _previous:
		if present.has(id):continue
		var old: Dictionary=_previous[id]
		var b: Array=old.bounds
		var rect:=Rect2(float(b[0]),float(b[1]),float(b[2]),float(b[3]))
		rect.position-=(current-_previous_center)*Vector2(1.15,1.12)
		check(not rect.grow(3).intersects(Rect2(Vector2.ZERO,Vector2(1280,720))),"resident recycled only fully offscreen "+id)
	_previous=present;_previous_center=current
	_samples+=1
	if _samples%6==0:timeline.append({"label":label,"receipt":report})
	return report

func tick(count: int,label: String) -> void:
	for i: int in count:
		await process_frame
		snapshot(label)

func image_capture(name: String) -> Image:
	for i: int in 3:await process_frame
	await RenderingServer.frame_post_draw
	var pixels:=root.get_texture().get_image()
	check(pixels.save_png(output+"/"+name+".png")==OK,"PNG saved "+name)
	return pixels

func run_capture() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	await new_app("home",1,"")
	app.home_scene.player.position=Vector2(440,414)
	app.home_scene.camera.position=Vector2(640,310)
	app.home_scene.camera.force_update_scroll()
	foreground=find_foreground(app)
	check(foreground!=null,"actual Home foreground exists")
	if foreground==null:quit(1);return
	foreground.set_process(true)
	await tick(70,"settle")
	var start: Dictionary=foreground.call("receipt")
	var counter: int=int(start.get("advance_count",-1))
	for i: int in 20:foreground.call("refresh")
	var refreshed: Dictionary=foreground.call("receipt")
	check(counter==int(refreshed.get("advance_count",-2)),"repeated refresh does not advance transition clock")
	for i: int in 200:
		var x:=640.0+float(i if i<100 else 200-i)*12.0
		app.home_scene.camera.position=Vector2(x,310)
		app.home_scene.camera.force_update_scroll()
		await tick(1,"horizontal_return")
	app.home_scene.camera.position=Vector2(640,310)
	app.home_scene.camera.force_update_scroll()
	await tick(70,"return_settle")
	# Avoid the left world boundary and bottom tutorial panel in the pixel probe.
	app.home_scene.camera.position=Vector2(1140,310)
	app.home_scene.camera.force_update_scroll()
	await tick(80,"pixel_probe_settle")
	foreground.set_process(false)
	var with_foreground:=await image_capture("with_foreground")
	foreground.set("visible",false)
	var without_foreground:=await image_capture("without_foreground")
	var best:=Vector2i.ZERO
	var best_score:=0.0
	var changed:=0
	for y: int in range(4,716,2):
		for x: int in range(4,1276,2):
			var a:=with_foreground.get_pixel(x,y)
			var b:=without_foreground.get_pixel(x,y)
			var score:=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
			if score>.025:changed+=1
			if score>best_score:best_score=score;best=Vector2i(x,y)
	check(changed>50,"visible foreground contributes actual pixels; mask check not vacuous")
	foreground.set("visible",true)
	var guard:=CharacterBody2D.new()
	guard.name="DiagnosticForegroundGuard"
	app.home_scene.world.add_child(guard)
	guard.global_position=root.get_canvas_transform().affine_inverse()*Vector2(best)
	var collision:=CollisionShape2D.new()
	var shape:=RectangleShape2D.new();shape.size=Vector2(12,12)
	collision.shape=shape;guard.add_child(collision)
	foreground.call("refresh")
	await image_capture("with_guard_foreground")
	var guarded: Dictionary=foreground.call("receipt")
	foreground.set("visible",false)
	await image_capture("without_foreground_guard")
	foreground.set("visible",true)
	foreground.set_process(true)
	await tick(24,"guard_fade")
	guard.free();await process_frame
	await tick(10,"recovery_hold")
	var held: Dictionary=foreground.call("receipt")
	for row: Dictionary in held.residents:
		if row.admitted and row.safe_time<.3:check(float(row.alpha)==0.0,"unsafe-to-safe recovery hold stays zero")
	await tick(40,"recovery_rise")
	var recovered: Dictionary=foreground.call("receipt")
	paused=true
	var before_pause: Dictionary=foreground.call("receipt")
	await tick(12,"paused")
	var during_pause: Dictionary=foreground.call("receipt")
	check(before_pause.get("wind_time")==during_pause.get("wind_time"),"pause freezes foreground wind")
	paused=false
	FileAccess.open(output+"/check.json",FileAccess.WRITE).store_string(JSON.stringify({"task":"FOREGROUND-CONTINUITY-08","scope":"actual Home formal consumer, camera reversal and injected real collision guard; not gameplay traversal/combat","failures":failures,"identity_count":identities.size(),"samples":_samples,"actual_foreground_pixel_samples":changed,"guard_pixel":[best.x,best.y],"guarded":guarded,"held":held,"recovered":recovered,"timeline":timeline},"  "))
	app.abandon_run();await load("res://tests/audio_teardown.gd").drain_world(app)
	app.free()
	for i: int in 4:await process_frame
	print("FOREGROUND_CONTINUITY_DONE failures=%d samples=%d identities=%d"%[failures.size(),_samples,identities.size()])
	quit(0 if failures.is_empty() else 1)
