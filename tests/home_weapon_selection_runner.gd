extends SceneTree
## Native pointer + real Home navigation; app startup APIs cover loadout propagation.
var checks := 0
var failures := 0
var app: DemoApp
var selections: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ", message)

func frames(count: int) -> void:
	for unused: int in count: await physics_frame

func click(button: Button, touch := false) -> void:
	check(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, "Real selectable native button exists")
	if not is_instance_valid(button) or button.disabled: return
	var point := button.get_global_rect().get_center()
	if touch:
		var down := InputEventScreenTouch.new()
		down.index = 2
		down.position = point
		down.pressed = true
		Input.parse_input_event(down)
		await frames(1)
		var up := InputEventScreenTouch.new()
		up.index = 2
		up.position = point
		up.pressed = false
		Input.parse_input_event(up)
	else:
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		Input.parse_input_event(motion)
		await frames(1)
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.position = point
		down.global_position = point
		down.pressed = true
		Input.parse_input_event(down)
		await frames(1)
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.position = point
		up.global_position = point
		up.pressed = false
		Input.parse_input_event(up)
	await frames(3)

func weapon_button(id: StringName) -> Button:
	return app.menu._content.find_child("EquipHomeWeapon_" + str(id), true, false) as Button

func run() -> void:
	root.size = Vector2i(1280, 720)
	app = preload("res://scenes/demo/demo.tscn").instantiate() as DemoApp
	app.meta_persistence_enabled = false
	root.add_child(app)
	await frames(4)
	var title_button := app.menu._content.find_child("TitleBeginAdventure", true, false) as Button
	if title_button == null:
		for child: Node in app.menu._content.find_children("*", "Button", true, false):
			if child is Button and str(child.get_meta("focus_key", "")) == "title_start": title_button = child
	check(title_button != null, "Title exposes the existing primary start button")
	await click(title_button)
	check(is_instance_valid(app.home_scene) and app.player == null and not app.lifetime.active, "Real title start opens walkable Home without creating a run")
	var home := app.home_scene
	if not is_instance_valid(home):
		finish()
		return
	check(home.world.weapon_workshop_enabled, "Formal Home activates its authored arms service")
	var route := preload("res://tests/underworld_plains/home_terrace_driver.gd").new(home)
	check(await route.reach(&"arms"), "Real Motor input reaches the original elevated weapon workshop")
	check(home.nearest_id == &"arms" and home.reserved_id.is_empty(), "Arms is an active local service rather than a reserved facade")
	route.key(KEY_W, true)
	await route.frames(2)
	route.key(KEY_W, false)
	await frames(3)
	check(home.input_blocked and app.menu.home_function_id == &"arms", "Real interaction opens the armorer and cancels movement")
	check(app.menu._weapon_options.size() == 3, "Armorer exposes exactly three real Lv1 options")
	var notes: int = app.meta.snapshot().notes
	var hp := home.controller.actor_resources.health.current
	var prior := home.player.position
	for id: StringName in [&"shadow_shuriken", &"recoil_bomb", &"pulse_gun"]:
		await click(weapon_button(id), id == &"recoil_bomb")
		check(app.home_weapons.selected_id == id and home.controller.shoot_ability.weapon.id == id and home.controller.shoot_ability.weapon.tier == 1, "Native selection equips the actual Lv1 Definition: " + str(id))
		check(weapon_button(id).disabled and weapon_button(id).text.contains("当前装备"), "Current equipment is visible and cannot resubmit itself")
		check(home.input_blocked and home.player.position == prior and home.controller.router.axis == 0, "Switching keeps the same safe Home and clears action input")
		check(app.meta.snapshot().notes == notes and home.controller.actor_resources.health.current == hp, "Equipment switching never spends notes or changes health")
		selections.append({"id": str(id), "actual": str(home.controller.shoot_ability.weapon.id), "tier": home.controller.shoot_ability.weapon.tier})
	var epoch := home.controller.shoot_ability.weapon_epoch
	app.menu.requested_home_weapon.emit(&"triple_machine_gun")
	app.menu.requested_home_weapon.emit(&"unknown_weapon")
	await frames(1)
	check(home.controller.shoot_ability.weapon_epoch == epoch and app.home_weapons.selected_id == &"pulse_gun", "Unknown and Lv2 IDs are rejected without an equipment transaction")
	# Remaining propagation is a formal App startup consumer, not a natural route claim.
	for id: StringName in [&"shadow_shuriken", &"recoil_bomb", &"pulse_gun"]:
		if app.menu.home_function_id != &"arms": app._open_home_function(&"arms")
		app.menu.requested_home_weapon.emit(id)
		await frames(1)
		app.menu.close_panel()
		await frames(2)
		check(not app.home_scene.input_blocked, "Closing the armorer restores Home input")
		check(app.start_plains("home-weapon-" + str(id)), "Selected loadout can start a real formal Plains run")
		await frames(6)
		check(is_instance_valid(app.stage) and app.controller.shoot_ability.weapon.id == id and app.controller.shoot_ability.weapon.tier == 1, "Formal Plains actually owns the selected Lv1: " + str(id))
		check(app.director.manifest.snapshot().initial_character.weapon == str(id), "Run Manifest records its actual equipped weapon")
		check(not app.controller.traversal.hook_enabled and not app.controller.router.weapon_skill_available, "Selecting Lv1 grants neither grapple nor Lv3 skill")
		if id == &"recoil_bomb": await formal_bomb_boss()
		var run_epoch := app.controller.shoot_ability.weapon_epoch
		app.menu.requested_home_weapon.emit(&"recoil_bomb" if id != &"recoil_bomb" else &"pulse_gun")
		check(app.controller.shoot_ability.weapon_epoch == run_epoch and app.controller.shoot_ability.weapon.id == id, "Home selection signal cannot switch an active run")
		app.abandon_run()
		await frames(4)
		check(is_instance_valid(app.home_scene) and app.home_scene.controller.shoot_ability.weapon.id == id and app.home_weapons.selected_id == id, "Returning Home retains the session loadout")
		app.menu.close_panel()
		await frames(1)
	app._open_home_function(&"arms")
	app.menu.requested_home_weapon.emit(&"recoil_bomb")
	app.menu.close_panel()
	check(app.start_debug_region(&"thorn_forest", 1, "home-weapon-forest"), "Existing Forest development entry accepts the selected base loadout")
	await frames(6)
	check(app.stage is ThornForestRegionStage and app.controller.shoot_ability.weapon.id == &"recoil_bomb", "Real Forest consumer preserves the Home-selected weapon")
	check(app.director.manifest.snapshot().initial_character.weapon == "recoil_bomb", "Forest Manifest identifies its actual selected loadout")
	app.abandon_run()
	await frames(3)
	check(app.home_scene.controller.shoot_ability.weapon.id == &"recoil_bomb", "Forest return also retains the session selection")
	route = null
	check(await load("res://tests/audio_teardown.gd").drain_world(app), "Actual App audio releases before teardown")
	app.queue_free()
	await frames(2)
	finish()

func formal_bomb_boss() -> void:
	# Explicit arena initialization, not proof of traversing the map to its Boss.
	var encounter := app.stage.boss.get_node("Encounter") as WindkeeperEncounter
	app.player.global_position = app.stage.boss.global_position + Vector2(-105, -10)
	app.controller.motor.reset_motion()
	check(app._in_boss_core(), "Initialized bomb stance is inside the real formal arena")
	if not app._boss_started: app._start_generated_boss()
	check(app._boss_started and encounter.active, "Formal App installs and activates its original Boss guard")
	encounter._enter(&"observe", 4.0)
	encounter.set_physics_process(false)
	await frames(2)
	var feel := app.player.get_node_or_null("WeaponFeel") as PlayerWeaponFeel
	check(feel != null and feel is PlayerWeaponFeelV2, "Formal consumer retains its real V2 weapon audio observer")
	var audio_mark := feel.audio.weapon_events.size() if feel != null else 0
	var sound := get_first_node_in_group(&"game_audio") as GameAudio
	var generic_shots := int(sound.played.get(&"shot", 0))
	var before := encounter.health.current
	app.controller.router.request_action(&"shoot_release", Vector2.RIGHT)
	await frames(4)
	check(encounter.health.current < before, "Real accepted bomb blast passes the original formal Boss eligible-shot and damage-policy sinks")
	var key := "%s:%s" % [app.controller.session_id, app.controller.shoot_ability.packet_id]
	check(app._boss_eligible_shots.has(key), "Boss eligibility owns the same unique accepted bomb packet")
	if feel != null:
		var heard: Array = feel.audio.weapon_events.slice(audio_mark)
		check(heard.filter(func(event: Dictionary) -> bool: return event.id == &"blast").size() == 1, "One real base-bomb blast audio event is retained")
		check(heard.filter(func(event: Dictionary) -> bool: return event.id == &"pulse").is_empty(), "Accepted bomb identity never adds a pulse-gun sound")
	check(int(sound.played.get(&"shot", 0)) == generic_shots, "Classic shot audio is also absent for the accepted bomb registration")

func finish() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/home_weapon_selection")
	var output := FileAccess.open("res://build/home_weapon_selection/report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks": checks, "failures": failures, "selections": selections, "scope": "Native pointer/touch event dispatch and actual Home/Plains/Forest startup, not browser or physical-device acceptance"}, "\t"))
	print("HOME WEAPONS: %s assertions, %s failures" % [checks, failures])
	quit(1 if failures else 0)
