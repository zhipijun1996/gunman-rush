extends SceneTree
## Real formal consumers/Router and NPC callbacks; explicit lifecycle fixtures.
var app: DemoApp
var checks := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var audio: PlayerWeaponFeelAudioV2

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)
func frames(count: int) -> void:
	for tick: int in count:
		await physics_frame
		await process_frame
func avatars() -> AvatarPresentation:
	return app.get_meta("avatar_presentation") as AvatarPresentation
func active_player() -> PlayerMotor:
	return app.player if is_instance_valid(app.player) else app.home_scene.player
func audit(id: String, location: String) -> void:
	var player := active_player()
	var body := PlayerPresentationRuntime.current_body(player)
	check(body != null and body.visible, location+" actual visible Underworld-derived body")
	check((body is PlayerMotionCandidateVisual) == (id == "courier"), location+" selected new/classic body identity")
	check(not player.get_node("CourierVisual").visible and player.get_node("PlayerVisualAdapter").process_mode == Node.PROCESS_MODE_DISABLED, location+" hidden authoritative Courier and disabled Adapter preserved")
	var bodies := 0
	for child: Node in player.get_children():
		if child is UnderworldPlayer: bodies += 1
	check(bodies == 1, location+" exactly one body")
	var feel := player.get_node("WeaponFeel") as PlayerWeaponFeelV2
	check(feel != null and feel.audio == audio and feel.runtime.presentation == feel.renderer, location+" actual V2 weapon/audio binding")
	check(feel.renderer.catch_visual == body, location+" catch renderer follows selected body")
	var controller := player.get_node("Controller") as PlayerController
	var legacy := player.get_node("PlayerFeedback") as PlayerFeedback
	check(controller.jump_ability.jumped.is_connected(legacy._jump) == (id == "courier_classic"), location+" original jump listener restored only for classic")
	check(controller.landed.is_connected(legacy._land) == (id == "courier_classic"), location+" original land listener restored only for classic")
	check((player.get_node_or_null("MotionFeel") != null) == (id == "courier"), location+" unique motion feedback ownership")
	var shot_connections := controller.shoot_ability.shot_fired.get_connections().size()
	for repeat: int in 3: avatars().bind_player(player)
	check(controller.shoot_ability.shot_fired.get_connections().size() == shot_connections and player.get_node("WeaponFeel") == feel, location+" repeated binding creates no listeners/renderer")
	check(root.get_tree().get_nodes_in_group(&"game_audio").size() == 1 and audio._voices.size() == 12, location+" exactly one original-sized SFX service")
	check(app.avatar_selection_id == id and avatars().selected_id == id, location+" app selection retained")
	observations.append({"avatar":id,"consumer":location,"body_script":body.get_script().resource_path,"weapon_script":feel.get_script().resource_path,"audio_script":audio.get_script().resource_path,"shot_listeners":shot_connections})

func choose_at_npc(id: String) -> void:
	var home := app.home_scene
	var controller := home.controller
	home.player.get_node("KeyboardMouseAdapter").process_mode = Node.PROCESS_MODE_DISABLED
	var remaining := 240
	while absf(home.player.position.x - 300) > 5 and remaining > 0:
		controller.router.set_move_axis(signf(300 - home.player.position.x) * .55)
		await frames(1)
		remaining -= 1
	controller.router.set_move_axis(0)
	await frames(3)
	check(home.nearest_id == &"character", "real Motor reaches unchanged character service")
	controller.router.request_action(&"interact")
	await frames(3)
	check(app.menu.visible_panel == &"home_function", "real interact opens Timeweaver menu")
	var picker := app.menu._content.find_child("TimeweaverAppearance", true, false) as OptionButton
	check(picker != null and picker.item_count == 2, "NPC exposes only new/classic production appearances")
	if picker != null:
		var index := 0 if id == "courier" else 1
		picker.select(index)
		picker.item_selected.emit(index) # Actual control callback, not browser GUI.
	app.menu._close_home_overlay()
	await frames(3)
	audit(id, "Timeweaver Home")

func accepted_jump(id: String) -> void:
	var player := active_player()
	var controller := player.get_node("Controller") as PlayerController
	var cue: StringName = &"motion_jump" if id == "courier" else &"jump"
	var land_cue: StringName = &"motion_land" if id == "courier" else &"land"
	var before := int(audio.played.get(cue, 0))
	var land_before := int(audio.played.get(land_cue, 0))
	controller.router.set_jump_held(&"default_integration_fixture", true)
	await frames(8)
	controller.router.set_jump_held(&"default_integration_fixture", false)
	await frames(65)
	check(int(audio.played.get(cue, 0)) == before + 1, id+" accepted Router jump has exactly one selected/original cue")
	check(int(audio.played.get(land_cue, 0)) == land_before + 1, id+" accepted landing has exactly one selected/original cue")

func run() -> void:
	app = preload("res://scenes/demo/demo.tscn").instantiate()
	app.meta_persistence_enabled = false
	root.add_child(app)
	audio = app.get_children().filter(func(node: Node) -> bool: return node is GameAudio)[0] as PlayerWeaponFeelAudioV2
	check(audio != null, "real default main App owns new inherited SFX service")
	check(audio.weapon_clips[&"mine_beep"][0] == PlayerWeaponFeelAudioV2.TIMER_BEEP, "real default binds latest V3 timer sound")
	check(audio._streams.has(&"hurt") and audio._streams.has(&"enemy_defeat") and audio._streams.has(&"confirm"), "original combat/UI cues remain available")
	app.menu.requested_enter_home.emit()
	await frames(12)
	check(app.avatar_selection_id == "courier", "fresh App defaults to new courier")
	check(str(HomeScene.FUNCTION_NAMES["character"]).begins_with("织时匠") and (app.home_scene.world.slot_nodes["character"] as Label).text == "织时匠", "actual service context and world label renamed")
	check(avatars()._definition("p1_traveller").has("calibration") and avatars()._definition("p1_girl").has("calibration"), "legacy explicit avatar definitions retained")
	check(not (avatars().get_node("AvatarSelectorLayer") as CanvasLayer).visible, "selection stays at NPC rather than floating over game")
	audit("courier", "initial Home")
	await choose_at_npc("courier_classic")
	await accepted_jump("courier_classic")
	await choose_at_npc("courier")
	await accepted_jump("courier")
	# Both choices survive actual independent region starts, deaths and retries.
	for id: String in ["courier_classic", "courier"]:
		await choose_at_npc(id)
		for region: StringName in [&"plains", &"thorn_forest"]:
			check(app.start_debug_region(region, 1, "player-default-integration"), "actual requested region starts")
			await frames(14)
			audit(id, String(region))
			app.player.get_node("KeyboardMouseAdapter").process_mode = Node.PROCESS_MODE_DISABLED
			var c := app.controller
			var energy := c.actor_resources.stamina.current
			var seen_shots: Array[int] = []
			c.shoot_ability.shot_fired.connect(func(_axis: Vector2, serial: int) -> void: seen_shots.append(serial))
			c.router.request_action(&"shoot_release", Vector2.UP)
			await frames(3)
			check(seen_shots.size() == 1, "formal default accepted shot enters existing weapon pipeline")
			check(c.actor_resources.stamina.current == energy and not c.shot_energy.definition.shooting_consumes_energy, "current one-shot/time-energy policy preserved")
			app.toggle_pause()
			var before_pause := PlayerPresentationRuntime.current_body(app.player)._state_age
			for tick: int in 8: await process_frame
			check(PlayerPresentationRuntime.current_body(app.player)._state_age == before_pause, "actual pause freezes body")
			app.toggle_pause()
			await frames(45) # Respect real spawn protection before lifecycle fixture.
			var old_token := app.lifetime.token()
			app._submit_damage(&"default_integration_explicit_terminal", DamageRequest.Kind.MONSTER, c.actor_resources.health.current)
			await frames(12)
			check(is_instance_valid(app.home_scene) and not is_instance_valid(app.player), "real accepted terminal damage unloads run and returns Home")
			check(not app.lifetime.accepts(old_token), "old actor/run token invalid after death")
			if app.menu.visible_panel == &"run_end": app.menu._close_home_overlay()
			audit(id, "Home after death")
			check(app.avatar_selection_id == id, "selected appearance survives death and new session")
	# Default remains new across the real retry route.
	app.menu.requested_retry.emit()
	await frames(14)
	audit("courier", "retry new run")
	var c := app.controller
	var feel := app.player.get_node("WeaponFeel") as PlayerWeaponFeelV2
	app.player.get_node("KeyboardMouseAdapter").process_mode = Node.PROCESS_MODE_DISABLED
	c.router.request_action(&"shoot_release", Vector2.UP)
	await frames(2)
	var old_projectile := c.shoot_ability._projectiles.back() as PlayerProjectile
	check(is_instance_valid(old_projectile) and feel.leaves.size() == 1, "accepted shot owns one actual projectile feedback leaf")
	var fake := PlayerProjectile.new() # Negative-only wrong-owner identity probe.
	fake.session_id = c.session_id
	fake.weapon_epoch = c.shoot_ability.weapon_epoch
	fake.owner_id = c.motor.get_instance_id() + 1
	check(not feel.call("_valid_projectile", fake), "other actor token cannot enter local projectile feedback")
	fake.free()
	check(c.shoot_ability.equip(WeaponCatalog.get_loadout(1)), "actual weapon change accepted as labelled lifecycle fixture")
	check(not feel.call("_valid_projectile", old_projectile), "previous weapon epoch cannot enter current feedback")
	await frames(2)
	check(feel.leaves.is_empty(), "weapon change removes old projectile renderer leaves")
	check(c.shoot_ability.equip(WeaponCatalog.get_loadout(4)), "actual laser fixture equipped")
	for tick: int in 60:
		if c.shoot_ability.cooldown_remaining <= 0: break
		await frames(1)
	check(c.shoot_ability.cooldown_remaining <= 0, "laser fixture respects original pending shot cooldown")
	c.router.activate_device(&"gamepad")
	c.router.set_aim(&"gamepad", Vector2.UP, true)
	await frames(8)
	var loops := 0
	for voice: AudioStreamPlayer in audio._voices:
		if voice.playing and bool(voice.get_meta("weapon_sustained", false)): loops += 1
	check(c.shoot_ability.runtime.phase == &"beam" and loops == 1, "accepted real beam owns exactly one continuous audio voice")
	app.toggle_pause()
	for tick: int in 8: await process_frame
	loops = 0
	for voice: AudioStreamPlayer in audio._voices:
		if voice.playing and bool(voice.get_meta("weapon_sustained", false)): loops += 1
	check(loops == 0 and c.shoot_ability.runtime.phase == &"idle", "actual pause cancellation releases beam loop")
	app.toggle_pause()
	c.router.set_aim(&"gamepad", Vector2.UP, false)
	check(c.shoot_ability.equip(WeaponCatalog.get_loadout(0)), "original single shot fixture restored")
	await frames(25)
	c.router.request_action(&"shoot_release", Vector2.UP)
	await frames(2)
	old_projectile = c.shoot_ability._projectiles.back() as PlayerProjectile
	check(c.return_to_segment(app.player.position), "explicit accepted same-position segment return fixture")
	check(not feel.call("_valid_projectile", old_projectile) and feel.leaves.is_empty(), "previous session cannot leave projectile feedback after accepted return")
	await frames(3)
	PlayerPresentationRuntime._remove(app.player, "WeaponFeel")
	var legacy := app.player.get_node("PlayerFeedback") as PlayerFeedback
	check(c.shoot_ability.shot_fired.is_connected(legacy._shot) and c.shoot_ability.runtime.presentation == null and not c.shoot_ability.runtime.audio_override.is_valid(), "production feedback removal restores original shot/audio/runtime")
	await frames(25)
	var original_shots := int(audio.played.get(&"shot", 0))
	c.router.request_action(&"shoot_release", Vector2.UP)
	await frames(3)
	check(int(audio.played.get(&"shot", 0)) == original_shots + 1, "actual accepted shot restores exactly one original SFX after feedback detach")
	PlayerPresentationRuntime.attach(app.player)
	check(app.player.get_node("WeaponFeel") != feel, "reattach creates one fresh owned feedback leaf")
	app.abandon_run()
	await frames(8)
	if app.menu.visible_panel == &"run_end": app.menu._close_home_overlay()
	check(await load("res://tests/audio_teardown.gd").drain_world(app), "all real consumers release original and new audio")
	app.free()
	for tick: int in 6: await process_frame
	DirAccess.make_dir_recursive_absolute("res://build/player-default-integration")
	FileAccess.open("res://build/player-default-integration/result.json", FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations,"scope":"Actual default Home/Timeweaver native callbacks, both regions, accepted Router movement/shots/jump, explicit policy death/retry, audio restoration; browser GUI/aesthetics/device unverified"}, "\t"))
	print("PLAYER DEFAULT INTEGRATION: checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
