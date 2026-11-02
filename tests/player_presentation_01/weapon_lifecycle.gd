extends "res://tests/player_presentation_01/weapon_trace.gd"

func run() -> void:
	root.size=Vector2i(1280,720)
	if output.is_empty() or FileAccess.file_exists(output): quit(1);return
	app=preload("res://experiments/motion/entries/weapon_feel.tscn").instantiate()
	root.add_child(app)
	for unused: int in 150:
		await physics_frame
		if is_instance_valid(app.weapon_feel): break
	actor=app.home_scene.player
	controller=app.home_scene.controller
	controller.router.activate_device(&"gamepad")
	await frames(5)
	var profile := PlayerWeaponFeelProfile.new()
	var unbound := PlayerWeaponFeel.new()
	unbound.set_candidate_enabled(true)
	check(not unbound.enabled_candidate,"unbound consumer cannot be enabled")
	unbound.free()
	for property: String in ["trail_opacity","accent_opacity","contact_seconds","shot_attenuation","sustained_attenuation"]:
		var original: float=profile.get(property)
		for bad: float in [NAN,INF,-1.0]:
			profile.set(property,bad)
			check(not profile.valid(),"invalid cosmetic parameter "+property)
		profile.set(property,original)
	app.select_weapon(5)
	await frames(3)
	controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await frames(8)
	check(app.weapon_audio.played.get(&"weapon_blade",0)==1,"three simultaneous fan blades share one release cue")
	var leaf: PlayerWeaponFeelProjectile=app.weapon_feel.leaves.back()
	var parent := leaf.projectile
	check(parent.presentation==leaf and leaf.active,"actual swept projectile uses candidate leaf")
	paused=true
	var position := parent.position
	var age := parent._age
	for unused: int in 8: await process_frame
	check(parent.position==position and parent._age==age,"pause freezes real projectile")
	paused=false
	app.set_weapon_enabled(false)
	check(parent.presentation==null and not leaf.visible,"OFF restores original Home parent renderer")
	app.set_weapon_enabled(true)
	check(parent.presentation==leaf and leaf.visible,"ON resumes existing real projectile without spawning another")
	var count := app.weapon_audio.weapon_events.size()
	check(count==1,"toggle never replays accepted release audio")
	controller.router.request_action(&"weapon_skill",Vector2.RIGHT)
	await frames(2)
	var extra_release := false
	for event: Dictionary in app.weapon_audio.weapon_events.slice(count):
		if event.id!=&"contact": extra_release=true
	check(not extra_release,"rejected unearned skill emits no release/phase sound;existing real contacts remain audible")
	var legacy := actor.get_node("PlayerFeedback") as PlayerFeedback
	var old: WeakRef=weakref(app.weapon_feel)
	app.return_full_game()
	check(old.get_ref()==null and actor.get_node_or_null("WeaponFeel")==null,"Home return releases weapon consumer")
	check(controller.shoot_ability.shot_fired.is_connected(legacy._shot) and controller.shoot_ability.projectile_impacted.is_connected(legacy._impact),"Home restores original shot/contact handlers")
	check(app.training_targets.is_empty(),"Home return removes explicit practice targets")
	for unused: int in 2:
		app.open_home_sample()
		for attempt: int in 150:
			await physics_frame
			if is_instance_valid(app.weapon_feel): break
		actor=app.home_scene.player
		controller=app.home_scene.controller
		check(actor.get_node_or_null("WeaponFeel")==app.weapon_feel and app.training_targets.size()==2,"reentry has one consumer and two practice targets")
	await earn_skill(10)
	# Earn again;cancel the real accepted charge before release,without refunding.
	app.select_weapon(0)
	var cannon := WeaponCatalog.get_loadout(10)
	for unused: int in 40:
		if controller.combat_energy.current>=cannon.skill_cost: break
		await walk_to(240)
		controller.router.request_action(&"shoot_release",Vector2.RIGHT)
		await frames(24)
	app.select_weapon(10)
	await frames(3)
	var pulse_before := int(app.weapon_audio.played.get(&"weapon_pulse",0))
	controller.router.request_action(&"weapon_skill",Vector2.RIGHT)
	await frames(5)
	check(controller.shoot_ability.runtime.phase==&"charge","real earned cannon charge accepted")
	controller.router.clear("cancel_charge_test")
	await frames(3)
	check(controller.shoot_ability.runtime.phase==&"idle" and int(app.weapon_audio.played.get(&"weapon_pulse",0))==pulse_before,"cancelled charge emits no fake cannon release")
	# Real DemoApp Plains,where its original shot subscriber installs PixelPlains.
	app.restart_sample()
	for unused: int in 180:
		await physics_frame
		if is_instance_valid(app.weapon_feel) and app.weapon_feel.controller==app.controller: break
	check(is_instance_valid(app.weapon_feel) and app.stage is PlainsRegionStage,"actual formal Plains consumer ready")
	if is_instance_valid(app.weapon_feel):
		var observed := false
		app.controller.shoot_ability.shot_fired.connect(func(_axis:Vector2,_id:int)->void:
			var actual: PlayerWeaponFeelProjectile = app.weapon_feel.leaves.back()
			check(actual.previous is PixelPlainsProjectile,"original DemoApp pixel subscriber actually ran")
			app.set_weapon_enabled(false)
			check(actual.projectile.presentation==actual.previous and actual.previous.visible,"OFF restores actual original Plains leaf")
			app.set_weapon_enabled(true)
			check(actual.projectile.presentation==actual and not actual.previous.visible,"ON restores candidate without new gameplay projectile"))
		app.controller.router.activate_device(&"gamepad")
		app.controller.router.request_action(&"shoot_release",Vector2.UP)
		for unused: int in 4: await physics_frame
		for effect: PlayerWeaponFeelProjectile in app.weapon_feel.leaves:
			if is_instance_valid(effect): observed=true
		check(observed,"actual Plains accepted projectile observed")
	await finish()
