extends SceneTree
## GPU evidence producer. Run with tools/godot.sh and an X11/desktop display.
## --clip records a 20s accepted-input fixture, with 60 simulated ticks/second.
const ENTRY = preload("res://game/experiments/paper_theater/paper_lab.tscn")
var lab: Node
var checks := 0
var failures := 0
var jumps := 0
var shots := 0
var mode := "A"
var output := "res://build/paper_theater"

func _initialize() -> void: run.call_deferred()
func ticks(count: int) -> void:
	for i: int in count: await physics_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1;printerr("PAPER FAIL ",label)

func geometry(node: Node) -> Array:
	var rows: Array = []
	if node is CollisionShape2D and node.get_parent() is StaticBody2D:
		rows.append([str(node.get_path()),node.get_parent().global_transform,str(node.shape),node.disabled,node.one_way_collision])
	if node is CollisionPolygon2D and node.get_parent() is StaticBody2D:rows.append([str(node.get_path()),node.polygon,node.global_transform,node.disabled])
	for child: Node in node.get_children():rows.append_array(geometry(child))
	return rows

func run() -> void:
	root.size = Vector2i(1280,720)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--paper="):mode = arg.trim_prefix("--paper=")
	lab = ENTRY.instantiate()
	root.add_child(lab)
	while not lab.ready_for_play:await physics_frame
	lab.set_mode(mode)
	await ticks(20)
	DirAccess.make_dir_recursive_absolute(output+"/captures")
	if "--clip" in OS.get_cmdline_user_args():await clip()
	elif "--measure" in OS.get_cmdline_user_args():await measure()
	else:await capture()
	print("PAPER CHECKS ",checks," failures=",failures)
	await WorldAudioLifecycle.drain_world(lab.app)
	quit(1 if failures else 0)

func capture() -> void:
	lab.app.controller.active = false
	lab.app.set_physics_process(false)
	for actor: EnemyActor in lab.app.room.enemies.values():actor.set_physics_process(false)
	lab.controls.hide()
	lab.app.ui.root.hide()
	var physical_before := geometry(lab.app.room)
	var poses := {"bridge":Vector2(1700,910),"ascent":Vector2(640,686),"underbridge":Vector2(1776,1198)}
	var manifest: Array = []
	for pose: String in poses:
		lab.app.player.reset_at(poses[pose])
		lab.app.camera.reset_view()
		lab.app.camera.set_physics_process(false)
		var camera_before: Vector2 = lab.app.camera.global_position
		for style: String in ["0","A","B"]:
			lab.set_mode(style)
			await ticks(12)
			await RenderingServer.frame_post_draw
			var path := output+"/captures/"+style+"-"+pose+".png"
			root.get_texture().get_image().save_png(path)
			check(geometry(lab.app.room)==physical_before,"collision identity "+style+pose)
			check(lab.app.camera.global_position==camera_before,"same camera "+style+pose)
			if style!="0":
				check(lab.paper.rebuild_count==1,"no per-frame geometry rebuild")
				check(geometry(lab.paper).is_empty(),"presentation has no collision")
			manifest.append({"style":style,"pose":pose,"player":[poses[pose].x,poses[pose].y],"camera":[camera_before.x,camera_before.y],"zoom":lab.app.camera.zoom.x,"file":path,"sha256":FileAccess.get_sha256(path)})
	check(lab.app.review.active and lab.app.state.storage is WorldRoomReview.MemorySave,"memory save isolation")
	# Physical room inputs must remain byte-for-byte identical on disk as well;
	# the delivery report binds their Git hashes alongside this runtime check.
	FileAccess.open(output+"/capture-manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"  "))
	print("PAPER CAPTURES ",manifest.size()," same-camera frames")
	await lab.restart()
	check(lab.ready_for_play and lab.app.room.room_id=="P-R04" and lab.mode=="B","standalone restart preserves P04 and mode")
	check(lab.app.state.storage is WorldRoomReview.MemorySave,"restart remains in memory")

var clip_tick := 0
var clip_trace: Array = []
func record_ticks(count: int) -> void:
	for i: int in count:
		await physics_frame
		clip_tick += 1
		if clip_tick%30==0:
			clip_trace.append({"tick":clip_tick,"player":[lab.app.player.position.x,lab.app.player.position.y],"camera":[lab.app.camera.position.x,lab.app.camera.position.y],"room":lab.app.room.room_id})

func input_walk(x: float, limit := 150) -> void:
	var router: InputRouter = lab.app.controller.router
	for i: int in limit:
		var dx: float = x-lab.app.player.position.x
		router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>5 else 0)
		await record_ticks(1)
		if absf(dx)<6 and lab.app.player.is_on_floor():break
	router.clear(&"paper_walk_end")
	print("CLIP WALK ",clip_tick," ",lab.app.player.position)

func input_hop(target: Vector2, aim: Vector2) -> void:
	var router: InputRouter = lab.app.controller.router
	router.clear(&"paper_jump_begin")
	router.set_source_axis(&"keyboard_mouse",signf(target.x-lab.app.player.position.x))
	router.set_jump_held(&"keyboard_mouse",true)
	for i: int in 110:
		await record_ticks(1)
		if i==16:router.request_action(&"shoot_release",aim)
		if i==32:router.set_jump_held(&"keyboard_mouse",false)
		var dx: float = target.x-lab.app.player.position.x
		router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>7 else 0)
		if i>18 and lab.app.player.is_on_floor():break
	router.clear(&"paper_jump_end")
	print("CLIP HOP ",clip_tick," ",lab.app.player.position," target=",target)

func clip() -> void:
	lab.app.review.set_invincible(true)
	lab.controls.hide()
	lab.app.ui.mini.hide()
	lab.app.ui.review_host.hide()
	var caption := Label.new()
	caption.position = Vector2(24,76)
	caption.text = mode+" · P04 · 正常速度 / 隔离无敌审核夹具"
	caption.add_theme_color_override("font_color",Color("244d4c"))
	var layer := CanvasLayer.new()
	layer.layer = 55
	lab.add_child(layer)
	layer.add_child(caption)
	lab.app.controller.jump_ability.jumped.connect(func() -> void:jumps+=1)
	lab.app.controller.shoot_ability.shot_fired.connect(func(_axis:Vector2,_id:int) -> void:shots+=1)
	# Inputs have positional goals, like a player approaching a ledge. There are
	# no position, velocity or camera setters in this continuous sequence.
	await record_ticks(30)
	await input_walk(1830,25)
	await record_ticks(25)
	await input_walk(1512)
	await input_hop(Vector2(1184,910),Vector2.RIGHT)
	await record_ticks(35)
	await input_walk(1008)
	await input_hop(Vector2(650,910),Vector2.RIGHT)
	await input_walk(608,50)
	await input_hop(Vector2(640,686),Vector2.DOWN)
	await record_ticks(65)
	await input_hop(Vector2(896,558),Vector2.DOWN)
	await input_walk(1072,70)
	await input_hop(Vector2(1168,366),Vector2.DOWN)
	await record_ticks(65)
	await input_hop(Vector2(1344,142),Vector2.DOWN)
	await record_ticks(55)
	await input_hop(Vector2(896,558),Vector2.RIGHT)
	await input_hop(Vector2(640,686),Vector2.RIGHT)
	if clip_tick<1200:await record_ticks(1200-clip_tick)
	check(jumps>=3,"accepted jumps")
	check(shots>=3,"accepted recoil shots")
	check(lab.app.room.room_id=="P-R04","clip stays in P04")
	FileAccess.open(output+"/clip-"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify({"style":mode,"seconds":clip_tick/60.0,"physics_hz":60,"jumps":jumps,"shots":shots,"trace":clip_trace},"  "))
	print("PAPER CLIP mode=",mode," accepted_jumps=",jumps," accepted_shots=",shots)

func measure() -> void:
	lab.app.controller.active = false
	lab.app.set_physics_process(false)
	var rows: Array = []
	for style: String in ["0","A","B"]:
		lab.set_mode(style)
		await ticks(90)
		var times: Array[float] = []
		var draws: Array[float] = []
		for frame: int in 300:
			await process_frame
			times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		times.sort()
		var total := 0.0
		for t: float in times:total+=t
		rows.append({"mode":style,"mean_process_ms":total/times.size(),"p95_process_ms":times[int(times.size()*.95)],"draw_calls_last":draws.back(),"paper_nodes":lab.paper.ply_count if style!="0" else 0,"contours":lab.paper.silhouette_count if style!="0" else 0})
	FileAccess.open(output+"/performance.json",FileAccess.WRITE).store_string(JSON.stringify({"adapter":RenderingServer.get_video_adapter_name(),"renderer":"GL Compatibility","resolution":[1280,720],"measurements":rows,"physical_mobile":"unverified"},"  "))
	print("PAPER PERFORMANCE ",JSON.stringify(rows))
