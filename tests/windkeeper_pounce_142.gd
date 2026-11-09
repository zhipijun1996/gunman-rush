extends "res://tools/art/capture_plains_enemy_context.gd"
## Formal P-R14, real PlayerMotor/Router/contact policy. Only initial placement
## and selected one-move group are fixtures; no immunity or collision overrides.
var checks := 0
var failures := 0
var observations: Array[Dictionary] = []
var capture := false
var capture_start := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1;printerr("FAIL POUNCE142: ",label)
func run() -> void:
	capture = OS.get_cmdline_user_args().has("capture")
	if capture:
		root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
		var layer:=CanvasLayer.new();layer.layer=200;root.add_child(layer)
		note=Label.new();note.position=Vector2(320,14);note.add_theme_font_size_override("font_size",16)
		note.add_theme_color_override("font_outline_color",Color("142b2b"));note.add_theme_constant_override("outline_size",5);layer.add_child(note)
	capture_start=Engine.get_process_frames()
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://windkeeper_pounce_142.json";app.settings_path="user://windkeeper_pounce_settings.json"
	root.add_child(app);app.start_new();await settle()
	for direction: int in [-1,1]:
		await crossing(direction,true)
		await crossing(direction,false)
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
	var file:=FileAccess.open("res://build/windkeeper-pounce-142.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":observations},"\t"))
	if capture:
		DirAccess.make_dir_recursive_absolute("res://build/plains_actors_142/pounce")
		var timeline:=FileAccess.open("res://build/plains_actors_142/pounce/timeline.json",FileAccess.WRITE)
		timeline.store_string(JSON.stringify([{"scene":"pounce","start_frame":capture_start,"end_frame":Engine.get_process_frames(),"states":{},"fixture":"selected lunge group and initial placement; real Router/player/contact; ordinary grounded underpass versus stationary landing"}],"	"))
	print("WINDKEEPER POUNCE142: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
func crossing(direction: int, move_under: bool) -> void:
	app.load_room("P-R14","");await settle()
	var boss:=app.room.encounter as WindkeeperPressureEncounter
	boss.set_physics_process(false)
	if capture:
		app.camera.set_physics_process(false);app.camera.zoom=Vector2.ONE
		note.text="牧风者 · 510 HP · "+("迎向 Boss，从身下穿过" if move_under else "对照：停在落点")+"\n指定扑击／初始站位夹具 · 真实移动与伤害 · 1×"
	var start:=boss.motor.global_position
	start.x=(boss.arena.left_x+boss.arena.right_x)*.5
	boss.motor.global_position=start;boss.direction=direction;boss._pose_from.clear()
	if capture:
		app.camera.global_position=start+Vector2(direction*130,-170);app.camera.force_update_scroll()
	app.player.reset_at(start+Vector2(direction*205,47))
	app.room.update_battle(app.player.position)
	check(boss.active and app.room.boss_contact.enabled,"actual arena entry enables the real body-contact emitter")
	var router:=app.controller.router
	router.activate_device(&"keyboard_mouse");router.set_source_axis(&"keyboard_mouse",0);router.set_jump_held(&"keyboard_mouse",false)
	boss._enter(&"observe",10);boss._update_combat_shapes()
	await ticks(100)
	check(app.player.is_on_floor(),"real player stands on the real arena floor")
	check(app.policy.player_clock()>=app.policy._protected_until,"underpass is measured after real spawn protection expires")
	check(boss.health.capacity==510 and boss.health.current==510,"formal Windkeeper starts at requested 510 HP")
	boss._group_plan={"attacks":[&"lunge"],"double_stomp":false,"sweep_high":false};boss._attack_index=0;boss._preparation_index=-1
	boss._begin_attack()
	check(boss.mode==&"lunge_warning" and boss._hop_prepared,"high pounce commits landing before warning")
	var landing:=boss._hop_target
	var hp:=app.controller.actor_resources.health.current
	var low_y:=start.y
	var crossed:=false
	var stayed_grounded:=true
	var contact_live:=true
	var trace: Array[Dictionary]=[]
	for frame: int in 100:
		# A modest reaction delay after takeoff; no jump, recoil or invulnerability.
		var moving:=move_under and boss.mode==&"lunge" and boss._hop_age>=.06
		router.set_source_axis(&"keyboard_mouse",-direction if moving else 0)
		boss.physics_tick(1.0/60);await physics_frame
		low_y=minf(low_y,boss.motor.global_position.y)
		stayed_grounded=stayed_grounded and app.player.is_on_floor()
		contact_live=contact_live and boss.body_contact_enabled()
		if (app.player.global_position.x-boss.motor.global_position.x)*direction<0:crossed=true
		trace.append({"mode":String(boss.mode),"boss":boss.motor.global_position,"player":app.player.global_position,"HP":app.controller.actor_resources.health.current})
		if boss.mode==&"recover":break
	router.set_source_axis(&"keyboard_mouse",0);await ticks(3)
	var end_hp:=app.controller.actor_resources.health.current
	check(boss.mode==&"recover" and boss.motor.global_position.distance_to(landing)<1,"pounce finishes on its committed landing")
	check(start.y-low_y>boss._config().lunge_height*.9,"large arc is actual body displacement")
	check(contact_live,"actual body contact remains enabled throughout high pounce")
	if move_under:
		check(crossed and stayed_grounded and end_hp==hp,"normal grounded movement crosses underneath without damage, both facings")
	else:
		check(end_hp<hp,"standing at the threatened landing takes actual contact damage")
	observations.append({"direction":direction,"move_under":move_under,"initial_HP":hp,"final_HP":end_hp,"rise":start.y-low_y,"landing":landing,"crossed":crossed,"grounded":stayed_grounded,"trace":trace})
	print("POUNCE CASE ",direction," under=",move_under," HP ",hp," -> ",end_hp," crossed=",crossed," rise=",start.y-low_y," landing=",landing-start)
