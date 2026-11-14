extends "res://tests/world/plains35_fixture.gd"
## Real formal intro, pause/cancel/skip and owner cleanup; no fight-clock injection.
func arrival_of() -> BossArrivalPresentation:
	for child:Node in app.room.boss.get_node("Presentation").get_children():
		if child is BossArrivalPresentation:return child
	return null

func start_intro() -> BossArrivalPresentation:
	await app.review.begin("P-R14","","base")
	if app.story.active:app.story.finish()
	await fixture(app.room.battle_entry_anchor+Vector2(240,0))
	return arrival_of()

func run() -> void:
	root.size=Vector2i(1280,720)
	app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
	var arrival:BossArrivalPresentation=await start_intro()
	check(arrival!=null and arrival.roar_screen!=null,"formal guardian owns full-viewport roar")
	if arrival==null:quit(1);return
	for i:int in 240:
		await ticks(1)
		if arrival.progress>.40:break
	var audio:=GameAudio.for_origin(app) as GameAudio
	check(int(audio.played.get(&"boss_arrival_roar",0))==1 and int(audio.played.get(&"boss_arrival_land",0))==0,"one sustained roar, no landing substitute")
	check(arrival.subject.position.is_equal_approx(Vector2.ZERO),"guardian never hops during roar")
	check(arrival.roar_screen.overlay.visible and arrival.roar_screen.overlay.size==Vector2(1280,720),"pressure covers whole actual viewport")
	check(arrival.roar_screen.layer<app.ui.layer,"HUD is drawn above world-only pressure")
	for progress:float in [.08,.36,.7,.95]:
		var pose:=WindkeeperPressureRig.sample({"mode":&"intro","direction":1,"state_age":progress*3.2,"state_duration":3.2})
		for i:int in 4:check(pose.feet[i].is_equal_approx(WindkeeperPressureRig.FOOT_ANCHORS[i]),"roar feet remain planted")
	app.preferences.value.reduced=true;app._apply_preferences();await ticks(2)
	check(is_equal_approx(float(arrival.roar_screen.surface.get_shader_parameter("strength")),.27),"reduced preference lowers full-screen distortion")
	root.size=Vector2i(960,540);await ticks(2)
	check(arrival.roar_screen.overlay.size==root.get_visible_rect().size,"full-screen pass covers actual logical viewport after window resize")
	var progress:=arrival.progress
	paused=true;await ticks(5)
	check(is_equal_approx(arrival.progress,progress),"pause freezes accepted roar progress")
	app.room.encounter.cancel();await ticks(3)
	check(not arrival.roar_screen.overlay.visible,"cancel while paused removes pressure immediately")
	check((app.camera as WorldCamera)._takeover.is_empty(),"cancel while paused hands back camera")
	check(not audio._voices.any(func(voice:AudioStreamPlayer)->bool:return voice.stream!=null and voice.get_meta("cue_id",&"")==&"boss_arrival_roar"),"cancel clears paused roar voice")
	paused=false
	var previous:=int(audio.played.get(&"boss_arrival_roar",0))
	arrival=await start_intro()
	app.room.encounter.skip_intro();await ticks(3)
	check(not arrival.roar_screen.overlay.visible and int(audio.played.get(&"boss_arrival_roar",0))==previous,"skip before roar leaves no screen or false roar")
	arrival=await start_intro()
	for i:int in 240:
		await ticks(1)
		if arrival.progress>.40:break
	var reference:WeakRef=weakref(arrival.roar_screen)
	await app.review.begin("P-R01","","base");await ticks(4)
	check(reference.get_ref()==null,"room unload releases full-screen owner")
	check(not audio._voices.any(func(voice:AudioStreamPlayer)->bool:return voice.stream!=null and voice.get_meta("cue_id",&"")==&"boss_arrival_roar"),"room unload releases long roar")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(3)
	print("BOSS ROAR: ",failures," failures")
	quit(failures)
