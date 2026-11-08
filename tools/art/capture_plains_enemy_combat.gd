extends "res://tools/art/capture_plains_enemy_context.gd"
## Actual Actor, AI, Router, projectile and corpse owners on formal PR142 terrain.
## One review enemy and the opening player position are explicit fixtures.
const OUT := "res://build/plains_actors_142/enemy-combat/"
const LABELS := {"patrol":"巡逻怪","charger":"冲锋怪","hopper":"跳跃怪","sentry":"哨兵","fan_sentry":"扇射哨兵","root_bell":"根铃","diver":"俯冲怪"}
const STATES := {"idle":"待机","patrol":"移动","telegraph":"攻击前摇","attack":"攻击","recovery":"收招","blocked":"收招","dead":"死亡"}
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for old: String in DirAccess.get_files_at(OUT):
		if old.ends_with(".png") or old=="timeline.json":DirAccess.remove_absolute(OUT+old)
	root.size=Vector2i(1280,720)
	var layer:=CanvasLayer.new();layer.layer=200;root.add_child(layer)
	note=Label.new();note.position=Vector2(320,14);note.add_theme_font_size_override("font_size",18)
	note.add_theme_color_override("font_outline_color",Color("142b2b"));note.add_theme_constant_override("outline_size",5);layer.add_child(note)
	var timeline: Array[Dictionary]=[]
	for kind: String in LABELS:
		if not OS.get_cmdline_user_args().is_empty() and kind not in OS.get_cmdline_user_args()[0].split(","):continue
		app=preload("res://game/application/world/fixed_world.tscn").instantiate()
		app.save_path="user://plains_enemy_combat_"+kind+".json"
		app.settings_path="user://plains_enemy_combat_settings.json"
		root.add_child(app);app.start_new();await settle()
		app.load_room("P-R06","");await settle()
		app.player.reset_at(Vector2(1170,878))
		var body:=EnemyFactory.create_for_behavior(StringName(kind))
		var actor:=body.get_node("Actor") as EnemyActor
		actor.set_meta(&"world_persistent_corpse",true)
		body.position=Vector2(1290,760 if kind=="diver" else 896-actor.definition.collision_size.y*.5)
		app.room.add_child(body)
		EnemyPresentationBinding.replace(actor,&"underworld")
		var id:=StringName("animation_review_"+kind)
		app.policy.bind_damageable(id,actor.damageable,actor.health)
		actor.bind_encounter(app.controller,app.policy,app.lifetime,id,[])
		var contact:=DemoContactEmitter.attach(body,app.policy,app.controller,id,DamageRequest.Kind.MONSTER,actor.definition.collision_size/2)
		actor.defeated.connect(func(_actor: EnemyActor)->void:contact.enabled=false;contact.set_physics_process(false))
		var remains:=EnemyPresentationBinding.remains(body.get_node("Presentation"))
		var start_frame:=Engine.get_process_frames()
		var seen: Dictionary={}
		var dead_at:=-1
		var jump_until:=-1
		var fall_start:=Vector2.INF
		for frame: int in 720:
			if app.busy or app.controller.actor_resources.health.terminal:break
			var state: Dictionary=actor.presentation_state()
			var phase:=str(state.get("state","idle"))
			var dx:=body.global_position.x-app.player.global_position.x
			var router:=app.controller.router
			router.activate_device(&"keyboard_mouse")
			var near:=65.0 if kind=="diver" else 110.0
			var far:=95.0 if kind=="diver" else 150.0
			var axis:=signf(dx) if absf(dx)>far else -signf(dx) if absf(dx)<near else 0.0
			if actor.health.terminal:axis=0.0
			router.set_source_axis(&"keyboard_mouse",axis)
			if phase=="attack" and app.player.is_on_floor() and frame%55==0:jump_until=frame+13
			router.set_jump_held(&"keyboard_mouse",frame<jump_until)
			if frame>=250 and frame%50==0 and not actor.health.terminal:
				router.request_action(&"shoot_release",(body.global_position-app.player.global_position).normalized())
			if actor.health.terminal:
				if dead_at<0:dead_at=frame;fall_start=remains.global_position
				phase=str(remains.phase)
				note.text=LABELS[kind]+" · "+("死亡下坠" if phase=="falling" else "落地死亡")+"\n正式地形实战 · 单怪布置 · 自动操作 1×"
			else:
				note.text=LABELS[kind]+" · "+("移动" if phase=="idle" and absf(body.velocity.x)>1 else str(STATES.get(phase,phase)))+"\n正式地形实战 · 单怪布置 · 自动操作 1×"
			await physics_frame
			if not seen.has(phase):
				seen[phase]=frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OUT+kind+"-"+phase+".png")
			if dead_at>=0 and frame>dead_at+150:break
		var row:={"scene":kind,"start_frame":start_frame,"end_frame":Engine.get_process_frames(),"states":seen,"enemy_HP":actor.health.current,"player_HP":app.controller.actor_resources.health.current,"corpse_drop":remains.global_position.y-fall_start.y if fall_start.is_finite() else 0}
		timeline.append(row);print("ENEMY COMBAT ",row)
		await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5)
	var file:=FileAccess.open(OUT+"timeline.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(timeline,"\t"));file.close()
	quit()
