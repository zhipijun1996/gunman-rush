extends SceneTree
## Actual bootstrap/Home, accepted UI receipts, contact pickups and projectiles.
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, reason: String) -> void:
	checks += 1
	if not condition:
		failures.append(reason)
		push_error(reason)

func ticks(count: int) -> void:
	for unused: int in count: await physics_frame

func count_event(lab: AudioDirectorLabV2, id: String) -> int:
	return lab.lab_events.filter(func(row: Dictionary) -> bool: return row.event_id == id).size()

func run() -> void:
	root.size = Vector2i(1280, 720)
	var host := CloudPreviewBootstrap.new()
	host.entry = "scene"
	host.entry_scene = "res://scenes/dev/audio_director_lab_v2.tscn"
	root.add_child(host)
	for unused: int in 150:
		await physics_frame
		if host.custom_scene is AudioDirectorLabV2 and (host.custom_scene as AudioDirectorLabV2).lab_ready: break
	var lab := host.custom_scene as AudioDirectorLabV2
	check(lab != null and lab.lab_ready, "Actual CloudPreview bootstrap reaches v2 Home fixture")
	if lab == null or not lab.lab_ready:
		quit(1)
		return
	check(not lab.meta_persistence_enabled and host.custom_audio == null, "Preview persistence disabled and offered generic audio removed")
	check(get_nodes_in_group(&"game_audio").size() == 1 and lab.lab_audio._voices.size() == 12, "Only one formal twelve-voice pool")
	check(lab.lab_profile == "original", "Original is the default audition profile")
	check(not lab.lab_audio.has_director_event(&"jump") and not lab.lab_audio.has_director_event(&"shot"), "V2 bank deliberately preserves original motion and shot families")
	for profile: String in ["original", "A", "B", "C"]:
		check(lab.set_lab_profile(profile), "Explicit profile %s is available in v2 bank" % profile)
		await lab.run_demo("confirm")
		check(count_event(lab, "confirm") > 0 and lab._fixture_wallet.balance == 2 and lab._fixture_build.count_item(&"damage_blue") == 1, "%s confirmation is a real accepted shop transaction" % profile)
		await lab.run_demo("denied")
		check(lab.lab_events.back().event_id == "denied" and lab._fixture_wallet.balance == 3 and lab._fixture_build.item_ids().is_empty(), "%s insufficient-funds rejection keeps original shop rules" % profile)
		await lab.run_demo("click")
		check(lab.lab_events.back().event_id == "click", "%s selection is a real UI button signal" % profile)
		await lab.run_demo("enemy_hit")
		var actor := lab._fixture_enemy.get_node("Actor") as EnemyActor
		check(actor.health.current < actor.health.capacity and count_event(lab, "enemy_hit") > 0, "%s real player projectile commits enemy HP and hit feedback" % profile)
		check(lab.lab_audio.is_director_event_suppressed(&"enemy_hurt") and not lab.lab_audio.is_director_event_suppressed(&"enemy_hit"), "%s hit audition isolates the same layer without doubling body feedback" % profile)
		await lab.run_demo("enemy_hurt")
		actor = lab._fixture_enemy.get_node("Actor") as EnemyActor
		check(actor.health.current < actor.health.capacity and count_event(lab, "enemy_hurt") > 0 and lab.lab_audio.is_director_event_suppressed(&"enemy_hit"), "%s body audition is a different focus on actual accepted damage" % profile)
		await lab.run_demo("hurt")
		check(lab.home_scene.controller.actor_resources.health.current == 4 and lab.lab_events.back().event_id == "hurt", "%s inherited enemy projectile and original policy damage the actual Home player" % profile)
		var hurt_events_before := count_event(lab, "hurt")
		var hurt_audio_before := int(lab.lab_audio.played.get(&"hurt", 0)) + int(lab.lab_audio.played.get(&"director_hurt", 0))
		await lab.run_demo("reward")
		check(lab._fixture_pickups.all(func(pickup: AudioDirectorLabPickup) -> bool: return pickup.claimed), "%s real Router walk contacts and claims all three pickup Areas" % profile)
		check(lab._fixture_wallet.balance == 1 and lab.home_scene.controller.actor_resources.health.current == 5, "%s original wallet and health services commit coin/heal rewards" % profile)
		check(count_event(lab, "coin") > 0 and count_event(lab, "heal") > 0 and count_event(lab, "reward") > 0 and count_event(lab, "hurt") == hurt_events_before and int(lab.lab_audio.played.get(&"hurt", 0)) + int(lab.lab_audio.played.get(&"director_hurt", 0)) == hurt_audio_before, "%s contact sequence has actual coin/heal/reward and no setup damage or hurt audio" % profile)
		var old_director_jump := int(lab.lab_audio.played.get(&"director_jump", 0))
		var old_motion_jump := int(lab.lab_audio.played.get(&"motion_jump", 0))
		lab.home_scene.controller.router.request_action(&"jump")
		await ticks(4)
		check(not lab.home_scene.player.is_on_floor() and int(lab.lab_audio.played.get(&"motion_jump", 0)) == old_motion_jump + 1 and int(lab.lab_audio.played.get(&"director_jump", 0)) == old_director_jump, "%s actual Router jump retains accepted original motion audio" % profile)
		await ticks(100)
	await lab.open_context("combat", true)
	await ticks(15)
	var health_before := lab.home_scene.controller.actor_resources.health.current
	lab._fire_enemy_once()
	await ticks(3)
	lab.stop_demo()
	await ticks(110)
	var canceled_actor := lab._fixture_enemy.get_node("Actor") as EnemyActor
	check(lab.home_scene.controller.actor_resources.health.current == health_before and canceled_actor.attack_behavior._projectiles.is_empty(), "Stop during actual telegraph cancels pending fire and late HP damage")
	lab._fire_enemy_once()
	await ticks(3)
	lab.pause_audition_audio(true)
	await ticks(110)
	check(lab.home_scene.controller.actor_resources.health.current == health_before and canceled_actor.attack_behavior._projectiles.is_empty(), "Pause during actual telegraph cancels manual delayed fire as well")
	lab.pause_audition_audio(false)
	check(lab.lab_audio._voices.size() == 12, "All fixtures and profiles retain twelve voices")
	lab.pause_audition_audio(true)
	check(lab.lab_audio.volume == 0 and not lab.demo_running, "HTML single-sound handshake pauses fixture sound and cancels demo")
	lab.pause_audition_audio(false)
	check(is_equal_approx(lab.lab_audio.volume, 0.7), "Scene playback resumes original session gain")
	check(lab.set_lab_music("forest"), "Scene music accepts an existing original MP3 identifier")
	await ticks(45)
	check(lab._music.requested_track == &"forest", "Selected forest music survives the normal DemoApp state observer across frames")
	lab.set_lab_music("")
	await ticks(45)
	check(lab._music.requested_track.is_empty(), "No-music selection survives the normal Home observer")
	check(not lab.set_lab_music("untrusted-track"), "Unknown music identifiers are rejected")
	var actor_before := lab.home_scene.player
	var point_before := actor_before.position
	lab.set_lab_profile("A")
	check(lab.home_scene.player == actor_before and actor_before.position == point_before, "Profile change alone never resets or teleports the world")
	check(await lab._music.shutdown(), "Existing BGM backend drains")
	check(await lab.lab_audio.shutdown(), "Shared actual SFX playbacks drain")
	var weak_lab: WeakRef = weakref(lab)
	root.remove_child(host)
	host.queue_free()
	await ticks(4)
	check(weak_lab.get_ref() == null and get_nodes_in_group(&"game_audio").is_empty(), "Removing preview releases fixture and its single service")
	var output := {"checks": checks, "failures": failures, "scope": "Actual original Home character and UI/ShopService, original damage policy/projectiles, collision pickup Areas with official reward services; four profiles, preserved jump, isolation and drains. This explicit dev fixture is not natural progression, subjective listening or device acceptance."}
	DirAccess.make_dir_recursive_absolute("res://build/audio_director_v2/scene-runtime")
	var file := FileAccess.open("res://build/audio_director_v2/scene-runtime/receipt.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	file.close()
	print("AUDIO_DIRECTOR_V2_SCENE checks=%s failures=%s" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
