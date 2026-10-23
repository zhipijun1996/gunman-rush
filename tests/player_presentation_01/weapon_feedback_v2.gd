extends "res://tests/player_presentation_01/weapon_trace_v2.gd"

func voice_count(cue: StringName) -> int:
	return int(app.weapon_audio.played.get(&"weapon_"+cue,0))

func sustained() -> int:
	var total := 0
	for voice: AudioStreamPlayer in app.weapon_audio._voices:
		if voice.playing and bool(voice.get_meta("weapon_sustained",false)) and str(voice.get_meta("cue_id","")).begins_with("weapon_"): total+=1
	return total

func run() -> void:
	root.size=Vector2i(1280,720)
	if output.is_empty() or FileAccess.file_exists(output): quit(1);return
	app=preload("res://scenes/dev/player_presentation_01/weapon_feel_v2.tscn").instantiate()
	root.add_child(app)
	for unused: int in 150:
		await physics_frame
		if is_instance_valid(app.weapon_feel): break
	actor=app.home_scene.player
	controller=app.home_scene.controller
	controller.router.activate_device(&"gamepad")
	var feel := app.weapon_feel as PlayerWeaponFeelV2
	var runtime := controller.shoot_ability.runtime
	check(feel!=null and runtime.presentation==feel.renderer,"real Home uses optional V2 presentation")
	await walk_to(240)
	var hits := voice_count(&"hit")
	var shots := voice_count(&"pulse")
	var hp := app.training_targets[0].health
	controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await frames(28)
	check(app.training_targets[0].health<hp and voice_count(&"hit")==hits+1,"actual enemy damage gets one distinct hit layer")
	check(voice_count(&"pulse")==shots+1,"actual pistol release gets gunshot")
	hits=voice_count(&"hit")
	shots=voice_count(&"pulse")
	controller.router.request_action(&"shoot_release",Vector2.UP)
	await frames(34)
	check(voice_count(&"pulse")==shots+1 and voice_count(&"hit")==hits,"air miss has gunshot but no invented enemy hit")
	await walk_to(240)
	# Explicit fixture variant: first training column becomes a plain wall.
	var target := app.training_targets[0]
	target.name="TrainingReceiverDisabled"
	var walls := voice_count(&"wall")
	controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await frames(28)
	check(voice_count(&"wall")==walls+1 and voice_count(&"hit")==hits,"plain solid impact has material sound and no enemy hit")
	target.name="Damageable"
	# Reject a real receiver transaction; physical overlap is not committed HP.
	target.damage_sink=func(_context:Dictionary)->bool:return false
	var health := HealthState.new()
	var definition := HealthDefinition.new()
	definition.resource_id=&"weapon_v2_rejected_target_fixture"
	definition.max_health=1000
	definition.initial_current=1000
	check(health.configure(definition),"explicit target fixture HP state valid")
	target.bind_health(health)
	controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await frames(28)
	check(voice_count(&"hit")==hits,"rejected damage transaction never plays enemy hit")
	target.damage_sink=Callable()
	target.bind_health(null)
	app.select_weapon(4)
	await walk_to(240)
	controller.router.set_aim(&"gamepad",Vector2.RIGHT,true)
	await frames(8)
	check(runtime.phase==&"beam" and sustained()==1,"accepted laser owns exactly one looping ion voice")
	paused=true
	for unused: int in 8: await process_frame
	check(runtime.phase==&"idle" and sustained()==0,"original pause input cancellation stops accepted beam and loop")
	paused=false
	controller.router.activate_device(&"gamepad")
	controller.router.set_aim(&"gamepad",Vector2.RIGHT,false)
	await frames(20)
	controller.router.set_aim(&"gamepad",Vector2.RIGHT,true)
	await frames(8)
	check(runtime.phase==&"beam" and sustained()==1,"fresh post-pause real aim restarts accepted beam")
	var start_count := voice_count(&"ion_start")
	app.set_weapon_enabled(false)
	check(not feel.renderer.visible and sustained()==0,"OFF stops loop and reveals original runtime visuals")
	check(runtime.audio_override.call(&"focus_start")==false,"OFF delegates original producer audio")
	app.set_weapon_enabled(true)
	check(sustained()==1 and voice_count(&"ion_start")==start_count,"ON resumes accepted sustain without replaying attack")
	controller.router.set_aim(&"gamepad",Vector2.RIGHT,false)
	await frames(3)
	check(runtime.phase==&"idle" and sustained()==0,"release stops looping ion voice")
	app.select_weapon(8)
	await frames(20)
	controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await frames(7)
	check(runtime.phase==&"singularity" and voice_count(&"blackhole_start")==1 and sustained()==1,"black hole uses own accepted start and sustain")
	var old: WeakRef=weakref(feel)
	app.return_full_game()
	check(old.get_ref()==null and runtime.presentation==null and not runtime.audio_override.is_valid(),"Home unload restores runtime leaves and source audio hook")
	check(sustained()==0,"Home unload stops all owned sustain")
	app.open_home_sample()
	for unused: int in 150:
		await physics_frame
		if is_instance_valid(app.weapon_feel): break
	check(app.weapon_feel is PlayerWeaponFeelV2,"reentry creates one fresh V2 consumer")
	app.restart_sample()
	for unused: int in 180:
		await physics_frame
		if is_instance_valid(app.weapon_feel) and app.weapon_feel.controller==app.controller: break
	check(is_instance_valid(app.weapon_feel) and app.stage is PlainsRegionStage,"actual formal Plains V2 consumer assembled")
	if is_instance_valid(app.weapon_feel):
		app.controller.shoot_ability.shot_fired.connect(func(_axis:Vector2,_serial:int)->void:
			var leaf: PlayerWeaponFeelProjectile=app.weapon_feel.leaves.back()
			check(leaf.previous is PixelPlainsProjectile,"formal DemoApp really installed original pixel projectile leaf")
			app.set_weapon_enabled(false)
			check(leaf.projectile.presentation==leaf.previous and leaf.previous.visible,"formal OFF restores original pixel projectile")
			app.set_weapon_enabled(true))
		app.controller.router.activate_device(&"gamepad")
		app.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
		for unused: int in 5: await physics_frame
	await finish()
