extends SceneTree
## GPU evidence producer. Run with tools/godot.sh and an X11/desktop display.
## --clip records a 20s accepted-input fixture, with 60 simulated ticks/second.
const ENTRY = preload("res://game/experiments/paper_theater/paper_lab.tscn")
var lab: Node
var checks := 0
var failures := 0
var jumps := 0
var shots := 0
const Studies = preload("res://game/experiments/paper_theater/paper_studies.gd")
var mode := "B"
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
		if arg.begins_with("--paper="):mode = "0" if arg.trim_prefix("--paper=")=="0" else "B"
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
	lab.controls.hide()
	var manifest: Array = []
	for id: String in Studies.ROOMS:
		await lab.open_study(id)
		await ticks(20)
		lab.app.controller.active=false
		lab.app.set_physics_process(false)
		for actor: EnemyActor in lab.app.room.enemies.values():actor.set_physics_process(false)
		lab.app.ui.root.hide()
		var physical_before:=geometry(lab.app.room)
		var poses: Dictionary=Studies.ROOMS[id].poses
		for pose: String in poses:
			lab.app.player.reset_at(poses[pose])
			lab.app.camera.reset_view()
			lab.app.camera.set_physics_process(false)
			var camera_before: Vector2=lab.app.camera.global_position
			for style: String in ["0","B"]:
				lab.set_mode(style)
				await ticks(12)
				await RenderingServer.frame_post_draw
				var path:=output+"/captures/"+id+"-"+style+"-"+pose+".png"
				root.get_texture().get_image().save_png(path)
				check(geometry(lab.app.room)==physical_before,"collision identity "+id+style+pose)
				check(lab.app.camera.global_position==camera_before,"same camera "+id+style+pose)
				if style=="B":
					check(lab.paper.rebuild_count==1,"no per-frame rebuild "+id)
					check(geometry(lab.paper).is_empty(),"paper owns no collision "+id)
					for attached: Dictionary in lab.paper.foreground:
						check(attached.node.get_parent().position==Vector2.ZERO,"foreground stays world-fixed "+id)
				manifest.append({"room":id,"region":Studies.ROOMS[id].name,"style":style,"pose":pose,"player":[poses[pose].x,poses[pose].y],"camera":[camera_before.x,camera_before.y],"zoom":lab.app.camera.zoom.x,"file":path,"sha256":FileAccess.get_sha256(path)})
		check(lab.app.state.storage is WorldRoomReview.MemorySave,"memory isolation "+id)
		await lab.restart()
		check(lab.ready_for_play and lab.app.room.room_id==id and lab.mode=="B","selected-region reset "+id)
	check(lab.app.review.active,"review remains active")
	FileAccess.open(output+"/capture-manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"  "))
	print("PAPER CAPTURES ",manifest.size()," matched frames / three B regions")
	await paper_modulation()

func paper_modulation() -> void:
	# Verify real framebuffer blending, not just the Node's modulate property.
	var layer := CanvasLayer.new()
	layer.layer = 90
	root.add_child(layer)
	var parent := Node2D.new()
	parent.position = Vector2(1200,12)
	layer.add_child(parent)
	var material_factory: RefCounted = load("res://game/experiments/paper_theater/paper_shapes.gd").new()
	material_factory.polygon(parent,material_factory.rect_points(Rect2(0,0,16,16)),Color("35565b"))
	var colors: Array[Color] = []
	for alpha: float in [0.0,.5,1.0]:
		parent.modulate = Color(1,1,1,alpha)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		colors.append(root.get_texture().get_image().get_pixel(1208,20))
	check(colors[0]!=colors[1] and colors[1]!=colors[2],"paper shader inherits parent alpha in framebuffer")
	parent.modulate = Color(.4,1,1,1)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var hurt := root.get_texture().get_image().get_pixel(1208,20)
	check(hurt.r<colors[2].r-.02,"paper shader inherits accepted flash tint")
	layer.queue_free()
	FileAccess.open(output+"/modulation.json",FileAccess.WRITE).store_string(JSON.stringify({"transparent":str(colors[0]),"half":str(colors[1]),"opaque":str(colors[2]),"tinted":str(hurt)}))

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
	caption.text = "B · "+lab.selected_room+" · 正常速度 / 隔离无敌审核夹具"
	caption.add_theme_color_override("font_color",Color("244d4c"))
	var layer := CanvasLayer.new()
	layer.layer = 55
	lab.add_child(layer)
	layer.add_child(caption)
	lab.app.controller.jump_ability.jumped.connect(func() -> void:jumps+=1)
	lab.app.controller.shoot_ability.shot_fired.connect(func(_axis:Vector2,_id:int) -> void:shots+=1)
	# Continuous accepted inputs; no body/velocity/camera setters.
	var id: String=lab.selected_room
	if id=="P-R04":
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
	elif id=="F-R01":
		await record_ticks(35)
		await input_hop(Vector2(950,430),Vector2.LEFT)
		await input_walk(975)
		lab.app.controller.router.request_action(&"drop_through")
		await record_ticks(65)
		await input_hop(Vector2(700,558),Vector2.RIGHT)
		await input_walk(140,180)
		await input_hop(Vector2(156,286),Vector2.DOWN)
		await record_ticks(60)
		await input_hop(Vector2(620,558),Vector2.LEFT)
		await record_ticks(80)
	else:
		await record_ticks(35)
		await input_walk(210)
		await input_hop(Vector2(410,430),Vector2.LEFT)
		await input_walk(735)
		await record_ticks(35)
		await input_hop(Vector2(500,430),Vector2.RIGHT)
		await input_walk(210)
		await input_hop(Vector2(450,430),Vector2.DOWN)
		await input_walk(650)
		await input_hop(Vector2(480,430),Vector2.RIGHT)
		await record_ticks(65)
	var length_ticks:=1200 if id=="P-R04" else 900
	if clip_tick<length_ticks:await record_ticks(length_ticks-clip_tick)
	check(jumps>=3,"accepted jumps")
	check(shots>=3,"accepted recoil shots")
	check(lab.app.room.room_id==id,"clip stays in selected region")
	FileAccess.open(output+"/clip-"+id+".json",FileAccess.WRITE).store_string(JSON.stringify({"room":id,"style":mode,"seconds":clip_tick/60.0,"physics_hz":60,"jumps":jumps,"shots":shots,"trace":clip_trace},"  "))
	print("PAPER CLIP room=",id," mode=",mode," accepted_jumps=",jumps," accepted_shots=",shots)

func measure() -> void:
	var rows: Array=[]
	for id: String in Studies.ROOMS:
		await lab.open_study(id)
		lab.app.controller.active=false
		lab.app.set_physics_process(false)
		for style: String in ["0","B"]:
			lab.set_mode(style)
			await ticks(90)
			var times: Array[float]=[]
			var calls:=0.0
			for frame: int in 240:
				await process_frame
				times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
				calls=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			times.sort()
			var total:=0.0
			for t: float in times:total+=t
			rows.append({"room":id,"mode":style,"mean_process_ms":total/times.size(),"p95_process_ms":times[int(times.size()*.95)],"draw_calls_last":calls,"paper_nodes":lab.paper.ply_count if style=="B" else 0,"contours":lab.paper.silhouette_count if style=="B" else 0})
	FileAccess.open(output+"/performance.json",FileAccess.WRITE).store_string(JSON.stringify({"adapter":RenderingServer.get_video_adapter_name(),"renderer":"GL Compatibility","resolution":[1280,720],"measurements":rows,"physical_mobile":"unverified"},"  "))
	print("PAPER PERFORMANCE ",JSON.stringify(rows))
