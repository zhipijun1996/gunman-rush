extends SceneTree
## Actual bootstrap -> formal Home -> original Router/Motor action smoke.
## Headless evidence does not certify audible quality, GUI or physical devices.
var checks := 0
var failures: Array[String] = []
var accepted: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, reason: String) -> void:
	checks += 1
	if not condition:
		failures.append(reason)
		push_error(reason)

func ticks(count: int) -> void:
	for unused: int in count: await physics_frame

func run() -> void:
	root.size = Vector2i(1280, 720)
	var host := CloudPreviewBootstrap.new()
	host.entry = "scene"
	host.entry_scene = "res://scenes/dev/audio_director_lab.tscn"
	root.add_child(host)
	for unused: int in 120:
		await physics_frame
		if host.custom_scene is AudioDirectorLab and is_instance_valid((host.custom_scene as AudioDirectorLab).home_scene): break
	var lab := host.custom_scene as AudioDirectorLab
	check(lab != null, "Existing custom-scene bootstrap instantiates actual Sound Lab")
	if lab == null:
		quit(1)
		return
	await ticks(12)
	check(not lab.meta_persistence_enabled, "Lab disables normal save persistence before formal DemoApp ready")
	check(host.custom_audio == null, "Lab removes bootstrap generic audio before formal assembly")
	check(get_nodes_in_group(&"game_audio").size() == 1 and get_first_node_in_group(&"game_audio") == lab.lab_audio, "Exactly one formal V2 service owns the existing twelve-voice pool")
	check(lab.lab_audio._voices.size() == GameAudio.MAX_VOICES, "Lab does not create a parallel SFX voice pool")
	check(is_instance_valid(lab.home_scene), "Actual Home consumer becomes ready")
	var actor := lab.home_scene.player
	var control := lab.home_scene.controller
	check(actor.is_on_floor(), "Unmodified formal Home spawn reaches its actual ground")
	var body := PlayerPresentationRuntime.current_body(actor)
	check(body is PlayerMotionCandidateVisual and actor.get_node_or_null("MotionFeel") != null and actor.get_node_or_null("WeaponFeel") != null, "Current formal character and real motion/weapon audio consumers remain attached")
	control.jump_ability.jumped.connect(func() -> void: accepted.append({"event": "jump", "tick": Engine.get_physics_frames()}))
	control.shoot_ability.shot_fired.connect(func(axis: Vector2, serial: int) -> void: accepted.append({"event": "shot", "axis": [axis.x, axis.y], "serial": serial, "tick": Engine.get_physics_frames()}))
	var original_health := control.actor_resources.health.current
	var weapon := control.shoot_ability.weapon
	for profile: String in ["original", "A", "B"]:
		var before := actor.position
		lab.set_lab_profile(profile)
		check(lab.lab_profile == profile and lab.lab_audio.audio_profile == profile and actor.position == before and control.actor_resources.health.current == original_health and control.shoot_ability.weapon == weapon, "Profile %s changes presentation without moving, damaging or equipping the player" % profile)
		control.router.request_action(&"shoot_release", Vector2.RIGHT)
		await ticks(24)
	check(accepted.filter(func(row: Dictionary) -> bool: return row.event == "shot").size() == 3, "Original/A/B each allow a genuine accepted Router shot on the same formal Home actor")
	control.router.request_action(&"jump")
	await ticks(3)
	check(not actor.is_on_floor() and actor.velocity.y < 0 and accepted.any(func(row: Dictionary) -> bool: return row.event == "jump"), "Actual Router jump moves the unmodified PlayerMotor")
	await ticks(90)
	check(actor.is_on_floor(), "Actual jump returns to Home ground")
	check(lab._lab_panel.get_global_rect().end.x <= root.size.x and lab._lab_panel.position.x >= 0, "Development toolbar fits the configured project viewport")
	check(lab.lab_transitions.size() == 1 and lab.lab_transitions[0].route == "home", "Profile comparison does not restart the scene or manufacture region completion")
	for route: String in ["plains", "forest"]:
		await lab.open_lab_route(route)
		for unused: int in 360:
			await physics_frame
			if not lab._stage_pending and is_instance_valid(lab.stage): break
		check(not lab._stage_pending and is_instance_valid(lab.stage) and lab.stage.is_inside_tree() and lab.director.state == DemoRunDirector.State.IN_STAGE, "Lab %s button opens a real assembled formal region" % route)
		check(lab.active_region_id == (&"thorn_forest" if route == "forest" else &"plains") and get_first_node_in_group(&"game_audio") == lab.lab_audio and lab.lab_audio.audio_profile == "B", "Lab %s route retains selected profile and the same formal audio service" % route)
		if route == "forest":
			check(lab.controller.traversal.hook_enabled and lab.campaign.debug_entry and lab.lab_transitions.back().natural_progression == false, "Forest hook audition uses the existing explicit debug capability entry and labels its scope")
	await lab.open_lab_route("home")
	check(is_instance_valid(lab.home_scene) and not lab.lifetime.active and not lab.home_scene.input_blocked, "Actual region abandon/cleanup returns to an operable formal Home")
	check(await lab._music.shutdown(), "Actual BGM players release before test teardown")
	check(await lab.lab_audio.shutdown(), "Actual SFX playbacks release before test teardown")
	var weak_lab: WeakRef = weakref(lab)
	root.remove_child(host)
	host.queue_free()
	await ticks(4)
	check(weak_lab.get_ref() == null and get_nodes_in_group(&"game_audio").is_empty(), "Scene teardown releases Lab and its only SFX service")
	var output := {"checks": checks, "failures": failures, "accepted_actions": accepted, "viewport": [1280, 720], "scope": "Actual bootstrap, formal Home, current character, Router accepted shots/jump, profile isolation, actual Plains/Forest region assembly, debug hook capability, Home return and playback teardown; listening, GUI, combat/hook action and real devices unverified"}
	DirAccess.make_dir_recursive_absolute("res://build/audio_director/lab-runtime")
	var file := FileAccess.open("res://build/audio_director/lab-runtime/receipt.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	file.close()
	print("AUDIO_DIRECTOR_LAB checks=%s failures=%s" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
