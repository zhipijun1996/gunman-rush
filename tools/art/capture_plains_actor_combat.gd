extends "res://tools/art/capture_plains_enemy_context.gd"
## Actual encounters, normal Router inputs and clocks. Spawn/phase and wider review camera are disclosed fixtures.
const ACTIONS := {"intro":"入场","observe":"观察","approach":"接近","turn":"转向","ring_warning":"铃波前摇","rings":"敲铃攻击","neck":"收招","lob_aim":"瞄准前摇","lob_lock":"锁定落点","lob":"抛铃","roll_warning":"冲锋前摇","roll":"冲锋","combo_brake":"刹停","combo_turn":"回身","combo_warning":"回冲前摇","phase_transition":"阶段转换","stomp_warning":"踏击前摇","stomp":"踏击","lunge_warning":"扑击前摇","lunge":"扑击","sweep_warning":"横扫前摇","sweep":"横扫","seeds_warning":"种子前摇","seeds":"发射种子","gust_warning":"风压前摇","gust":"风压","platform_warning":"踏台前摇","platform":"踏台","recover":"收招","link":"连招间歇","traverse_warning":"跨台前摇","traverse":"跨台","dead":"死亡"}
const OUT := "res://build/plains_actors_142/combat/"
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for old: String in DirAccess.get_files_at(OUT):
		if old.ends_with(".png") or old=="timeline.json":DirAccess.remove_absolute(OUT+old)
	root.size=Vector2i(1280,720)
	var layer:=CanvasLayer.new();layer.layer=200;root.add_child(layer)
	note=Label.new();note.position=Vector2(320,14);note.add_theme_font_size_override("font_size",16)
	note.add_theme_color_override("font_outline_color",Color("142b2b"));note.add_theme_constant_override("outline_size",5);layer.add_child(note)
	var timeline: Array[Dictionary]=[]
	for test: Dictionary in [{"id":"bell","room":"P-R11","phase":1},{"id":"bell_wave","room":"P-R11","phase":1},{"id":"keeper","room":"P-R14","phase":1},{"id":"windmill","room":"P-R14","phase":2}]:
		if not OS.get_cmdline_user_args().is_empty() and test.id not in OS.get_cmdline_user_args()[0].split(","):continue
		app=preload("res://game/application/world/fixed_world.tscn").instantiate()
		app.save_path="user://plains_actor_combat_"+test.id+".json"
		app.settings_path="user://plains_actor_combat_review_settings.json"
		root.add_child(app);app.start_new();await settle()
		app.load_room(test.room,"");await settle()
		var encounter: Node=app.room.encounter
		var boss: Node2D=app.room.boss
		if boss==null:
			printerr("Missing review Boss: ",test.id);quit(1);return
		var start:=Vector2(boss.position.x-(250 if test.id=="bell_wave" else 360 if test.id=="bell" else 420),boss.position.y+47)
		app.player.reset_at(start)
		# Review-only framing shows both actors, their feet and real terrain.
		# No production camera, Actor, movement or damage settings are changed.
		app.camera.set_physics_process(false)
		app.camera.zoom=Vector2.ONE*1.5
		var floor_y: float=boss.global_position.y+65
		app.camera.global_position=Vector2((boss.global_position.x+start.x)*.5,floor_y-160)
		app.camera.force_update_scroll()
		note.text="实机动作复核 · 自动玩家输入 · 1×\n开场位置夹具"+(" / 二阶段生命阈值夹具" if test.phase==2 else "")
		if test.phase==2:
			encounter.health.apply_damage(ActorResourceRequest.new(&"review_phase_fixture",encounter.health.epoch,encounter.health.capacity*.45,encounter.health.get_instance_id()))
		var seen: Dictionary={}
		var jump_until:=-1
		var start_frame:=Engine.get_process_frames()
		var limit:=int(OS.get_cmdline_user_args()[1])*60 if OS.get_cmdline_user_args().size()>1 else (1080 if test.id=="bell_wave" else 1440)
		for frame: int in limit:
			if app.busy or app.room.room_id!=test.room or app.controller.actor_resources.health.terminal:break
			var dx: float=boss.global_position.x-app.player.global_position.x
			var router: Node=app.controller.router
			router.activate_device(&"keyboard_mouse")
			var far:=180.0 if test.id=="bell_wave" else 350.0 if test.id=="bell" else 300.0
			var near:=135.0 if test.id=="bell_wave" else 280.0 if test.id=="bell" else 235.0
			var axis:=signf(dx) if absf(dx)>far else -signf(dx) if absf(dx)<near else 0.0
			router.set_source_axis(&"keyboard_mouse",axis)
			var danger:bool=(encounter.mode==&"roll" and absf(dx)<250) or encounter.mode in [&"rings",&"stomp",&"sweep",&"seeds",&"gust"]
			if danger and app.player.is_on_floor():jump_until=frame+22
			router.set_jump_held(&"keyboard_mouse",frame<jump_until)
			if frame>850 and frame%100==0:
				var aim: Vector2=boss.to_global(encounter.core_offset())-app.player.global_position
				router.request_action(&"shoot_release",aim.normalized())
			await physics_frame
			_frame_combat(boss,encounter,floor_y)
			var state:=str(encounter.mode)
			note.text=("鸣铃巡游机" if test.id.begins_with("bell") else "牧风者 · 阶段%d" % encounter.stage_phase)+" · "+str(ACTIONS.get(state,state))+"\n正式关卡实战 · 宽镜头 · 自动操作 1×"+(" · 生命阈值设置" if test.phase==2 else "")
			if not seen.has(state):
				seen[state]=frame
				if not OS.get_cmdline_user_args().has("trace"):
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(OUT+test.id+"-"+state+".png")
		print("LIVE_ACTOR_REVIEW ",test.id," states=",seen," player_HP=",app.controller.actor_resources.health.current)
		timeline.append({"scene":test.id,"start_frame":start_frame,"end_frame":Engine.get_process_frames(),"states":seen})
		await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5)
	var file:=FileAccess.open(OUT+"timeline.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(timeline,"\t"));file.close()
	quit()

func _frame_combat(boss: Node2D, encounter: Node, floor_y: float) -> void:
	# Include real recoil jumps without cutting off either actor or the floor.
	var height:=320.0 if encounter.stage_phase>=2 else 240.0
	var left:=minf(app.player.global_position.x-70,boss.global_position.x-235)
	var right:=maxf(app.player.global_position.x+70,boss.global_position.x+235)
	var top:=minf(app.player.global_position.y-70,boss.global_position.y-height)
	var bottom:=maxf(floor_y+80,maxf(app.player.global_position.y+50,boss.global_position.y+90))
	var magnification:=minf(1.5,minf((root.size.x-120)/(right-left),(root.size.y-100)/(bottom-top)))
	app.camera.zoom=Vector2.ONE*magnification
	app.camera.global_position=Vector2((left+right)*.5,(top+bottom)*.5)
	app.camera.force_update_scroll()
