extends SceneTree
## Continuous actual App encounter. The automated player is explicitly disclosed.
## The sole position setup happens outside combat; thereafter only legal input.
var trace_path := ""
var seed_label := "bellstrider-rework-01"
var pilot_mode := "cautious2"
var max_battle_seconds := 180.0
var app: Node2D
var encounter: Node
var pilot: RefCounted
var heading: Label
var detail: Label
var frames: Array[Dictionary] = []
var events: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var failures: Array[String] = []
var source_before: Dictionary = {}
var git_before: Dictionary = {}
var setup: Dictionary = {}
var final_metrics: Dictionary = {}
var final_units: Array[Dictionary] = []
var final_audio: Array = []
var wallet_start := 0
var final_wallet_delta := 0
var postdraw_rows := 0
var ready := false
var finished := false
var finish_pending := false
var death_frame := -1
var claimed_frame := -1
var combat_frame := -1
var teardown_released := false
var teardown_epochs: Dictionary = {}
var original_manifest := ""
var manifest_unchanged := false
var last_state := ""
var previous_wallet := -1
var diagnostic_headless := false
var fatal_latched := false
var capture_health: RefCounted
var capture_lifetime: RefCounted
var review_armour := false


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--trace="):
			trace_path = argument.trim_prefix("--trace=")
		elif argument.begins_with("--seed="):
			seed_label = argument.trim_prefix("--seed=")
		elif argument.begins_with("--pilot="):
			pilot_mode = argument.trim_prefix("--pilot=")
		elif argument.begins_with("--max-battle-seconds="):
			max_battle_seconds = float(argument.trim_prefix("--max-battle-seconds="))
		elif argument == "--diagnostic-headless":
			diagnostic_headless = true
		elif argument == "--review-armour":
			review_armour = true
	if trace_path.is_empty() or pilot_mode not in ["cautious2", "greed3", "greed3_late"] or max_battle_seconds <= 0:
		printerr("Required --trace=PATH; --pilot=cautious2|greed3|greed3_late; positive battle timeout")
		quit(1)
		return
	start.call_deferred()


func start() -> void:
	source_before = _source_hashes()
	git_before = _git_source()
	app = load("res://scripts/demo/demo_app.gd").new() as Node2D
	app.meta_persistence_enabled = false
	root.add_child(app)
	if not app.start_plains(seed_label):
		_fail("Actual DemoApp refused start_plains")
		return
	for _i: int in 3600:
		await physics_frame
		if _stage_ready():
			break
	if not _stage_ready():
		_fail("Actual plains map1 not ready within startup budget")
		return
	# App's deferred viewport setup must finish before requesting native pixels.
	for _i: int in 4:
		await process_frame
	root.size = Vector2i(1280, 720)
	await process_frame
	encounter = app.stage.boss.get_node("Encounter")
	if encounter.get_script().resource_path != "res://scripts/bosses/bellstrider_encounter.gd":
		_fail("Formal map1 did not instantiate actual BellstriderEncounter")
		return
	if app._boss_started or bool(encounter.active):
		_fail("Encounter active before disclosed initial preparation")
		return
	var arena: Rect2 = app.stage.boss_arena
	var original: Vector2 = app.player.global_position
	var preparation := Vector2(arena.position.x - 38.0, app.stage.boss.global_position.y + 65.0 - 18.0)
	var query := PhysicsRayQueryParameters2D.create(preparation - Vector2(0, 32), preparation + Vector2(0, 85), 1, [app.player.get_rid()])
	query.collide_with_areas = false
	var support: Dictionary = app.player.get_world_2d().direct_space_state.intersect_ray(query)
	if support.is_empty() or (support.normal as Vector2).dot(Vector2.UP) < .7:
		_fail("Initial outside-arena preparation lacks real unchanged floor")
		return
	preparation.y = float(support.position.y) - 18.0
	# This single disclosed precombat Motor positioning does not reset resources.
	app.player.global_position = preparation
	app.controller.router.clear("disclosed_initial_precombat_preparation")
	app.controller.router.activate_device(&"keyboard_mouse")
	wallet_start = int(app.wallet.balance)
	capture_health = app.controller.actor_resources.health
	capture_lifetime = app.lifetime
	original_manifest = JSON.stringify(app.stage.generated.manifest)
	setup = {"entry": "actual DemoApp.start_plains / connected map1", "original_spawn": _vec(original), "initial_precombat_position": _vec(preparation), "floor_support_path": str(support.collider.get_path()), "floor_support_point": _vec(support.position), "arena": [arena.position.x, arena.position.y, arena.size.x, arena.size.y], "boss_scene": app.stage.boss.scene_file_path, "boss_renderer": _renderer_paths(), "boss_definition": encounter.definition.resource_path, "boss_health": encounter.health.current, "player_health": app.controller.actor_resources.health.current, "weapon": app.controller.shoot_ability.weapon.resource_path, "weapon_damage": app.controller.shoot_ability.weapon.damage, "weapon_interval": app.controller.shoot_ability.weapon.interval, "initial_wallet": wallet_start, "camera_zoom": _vec(app._run_camera.zoom), "window": [root.size.x, root.size.y], "epoch": _epochs(), "differences": ["automatic read-only observer submits normal Router actions and MouseMotion aim events", "one disclosed initial player position outside arena before combat", "profile persistence disabled for isolated capture"], "forbidden_combat_mutations": "none: no HP/resources/RNG/clocks/positions/invulnerability/terrain/AI/camera injection after preparation"}
	pilot = load("res://tools/bellstrider_01/legal_input_pilot.gd").new()
	pilot.mode = pilot_mode
	pilot.review_armour = review_armour
	setup["review_armour"] = review_armour
	encounter.presentation_event.connect(_encounter_event)
	app.controller.shoot_ability.shot_fired.connect(_shot_fired)
	app.controller.shoot_ability.shot_rejected.connect(_shot_rejected)
	app.controller.shoot_ability.projectile_impacted.connect(_projectile_impacted)
	app.controller.actor_resources.health.changed.connect(_player_health_changed)
	app.controller.died.connect(_player_died)
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	heading = _label("BELLSTRIDER / ACTUAL APP / CONTINUOUS NORMAL SPEED", Vector2(14, 632), 18)
	detail = _label("AUTOMATED LEGAL-INPUT PLAYER / " + pilot_mode, Vector2(14, 659), 15)
	layer.add_child(heading)
	layer.add_child(detail)
	layer.add_child(_label("Scripted player, autonomous encounter. One disclosed initial prep position. Not human play acceptance.", Vector2(14, 693), 13))
	ready = true
	process_frame.connect(drive)
	RenderingServer.frame_post_draw.connect(_post_draw)


func drive() -> void:
	if not ready or finished or finish_pending:
		return
	if not _live_world():
		_fail("Actual App removed the encounter before observer sampling; last live snapshot retained")
		return
	var metrics: Dictionary = encounter.combat_metrics()
	var units := _boss_units()
	var state := str(encounter.mode)
	var local_frame := frames.size() + 1
	if app._boss_started and combat_frame < 0:
		combat_frame = local_frame
		_mark("actual_entry_activation", {"epoch": _epochs()})
	if encounter.health.terminal and death_frame < 0:
		death_frame = local_frame
		_mark("accepted_terminal_damage")
	if state != last_state:
		_mark("state", {"state": state, "group": metrics.get("groups_started", 0), "phase": encounter.stage_phase})
		last_state = state
	pilot.step(app, encounter, metrics, units)
	var hp: float = app.controller.actor_resources.health.current
	var wallet := int(app.wallet.balance)
	if previous_wallet >= 0 and wallet != previous_wallet:
		_mark("actual_wallet_change", {"before": previous_wallet, "after": wallet})
	previous_wallet = wallet
	var player: CharacterBody2D = app.player
	var controller: Node = app.controller
	var row := {"frame": local_frame, "movie_process_frame": Engine.get_process_frames(), "movie_seconds": float(Engine.get_process_frames()) / 60.0, "sampling_phase": "SceneTree.process_frame before node processing", "boss_started": app._boss_started, "seal_closed": app.stage.boss_seal.closed, "state": state, "boss_clock": encounter.clock, "fight_seconds": metrics.get("fight_seconds", 0), "group": metrics.get("groups_started", 0), "groups_completed": metrics.get("groups_completed", 0), "group_plan": _json_value(metrics.get("group_plan", {})), "phase": encounter.stage_phase, "boss_position": _vec(app.stage.boss.global_position), "bell_world": _vec(app.stage.boss.to_global(encounter.core_offset())), "boss_HP": encounter.health.current, "accepted_hits": metrics.get("accepted_hits", 0), "accepted_damage": metrics.get("accepted_damage", 0), "player_position": _vec(player.global_position), "player_HP": hp, "grounded": player.is_on_floor(), "normal_velocity": _vec(player.normal_velocity), "recoil_velocity": _vec(player.recoil_velocity), "recoil_remaining": player.recoil_burst_remaining, "damage_motion_remaining": player.damage_remaining, "router_axis": controller.router.axis, "router_aim": _vec(controller.router.aim_direction), "router_epoch": controller.router.epoch, "router_sequence": controller.router.sequence, "rounds": controller.action_resources.shot_charges, "energy": controller.actor_resources.stamina.current, "cooldown": controller.shoot_ability.cooldown_remaining, "shots_fired": shots.size(), "pilot_intent": pilot.intent, "pilot_recovery_shots": pilot.recovery_shots, "wallet": wallet, "wallet_delta": wallet - wallet_start, "units": _json_value(units), "camera_zoom": _vec(app._run_camera.zoom), "time_scale": Engine.time_scale, "epoch": _epochs()}
	frames.append(row)
	row["active_threats"] = _projectile_rows()
	row["tree_paused"] = paused
	row["exit_modal_opened"] = is_instance_valid(app.exit_modal) and app.exit_modal.opened
	row["reward_modal_opened"] = is_instance_valid(app.reward_modal) and app.reward_modal.opened
	row["controller_active"] = controller.active
	row["late_withdraw_remaining"] = pilot.late_withdraw_remaining
	row["late_visible_reaction"] = pilot.late_reaction_snapshot()
	row["slide_collisions"] = _slide_rows(player)
	# Last-live snapshots survive App's deferred world destruction on failure.
	final_metrics = metrics
	final_units = units
	final_wallet_delta = wallet - wallet_start
	if local_frame % 120 == 0:
		print("BELLSTRIDER PILOT HEARTBEAT: " + JSON.stringify({"frame": local_frame, "fight_seconds": metrics.get("fight_seconds", 0), "HP": hp, "hits": metrics.get("accepted_hits", 0), "group": metrics.get("groups_started", 0), "state": state, "player": _vec(player.global_position), "boss": _vec(app.stage.boss.global_position), "wallet_delta": final_wallet_delta, "paused": paused, "exit_modal": row.exit_modal_opened}))
	if diagnostic_headless and local_frame % 600 == 0:
		_write_checkpoint("incomplete_periodic_headless_gameplay_checkpoint_NO_GPU_OR_MEDIA_PROOF")
	detail.text = "AUTO %s  |  %s  HP %.0f / BOSS %.0f  HITS %s  GROUP %s  COINS +%s  %.1fs" % [pilot_mode, state, hp, encounter.health.current, metrics.get("accepted_hits", 0), metrics.get("groups_started", 0), wallet - wallet_start, metrics.get("fight_seconds", 0)]
	if controller.actor_resources.health.terminal:
		_fail("Actual player death; failed attempt retained")
		return
	if not is_equal_approx(Engine.time_scale, 1.0):
		_fail("Normal-speed clock requirement failed")
		return
	var all_claimed := units.size() == 4 and units.all(func(unit: Dictionary) -> bool: return bool(unit.claimed))
	if all_claimed and wallet - wallet_start == 12 and float(metrics.get("death_age", 0)) >= 1.8:
		if claimed_frame < 0:
			claimed_frame = local_frame
			_mark("all_actual_boss_coins_claimed")
		elif local_frame - claimed_frame >= 45:
			finish_pending = true
			finish.call_deferred()
	if local_frame > int(max_battle_seconds * 60.0):
		_fail("Bounded battle timeout; failed uncut attempt retained")


func _boss_units() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _live_world():
		return result
	for pickup: Dictionary in app.stage.pickups:
		var source := str(pickup.get("source", ""))
		if pickup.get("kind", "") == "coin" and ("boss" in source or "bellstrider" in source):
			result.append(pickup.duplicate(true))
	return result


func _shot_fired(direction: Vector2, shot_id: int) -> void:
	if not _live_world() or finished or finish_pending:
		return
	shots.append({"frame": frames.size() + 1, "movie_frame": Engine.get_process_frames(), "id": shot_id, "direction": _vec(direction), "player": _vec(app.player.global_position), "muzzle": _vec(app.controller.shoot_ability.last_muzzle), "grounded": app.player.is_on_floor(), "group": encounter.combat_metrics().get("groups_started", 0), "state": str(encounter.mode), "boss_health": encounter.health.current, "ordinal": pilot.recovery_shots if is_instance_valid(pilot) else 0})
	if is_instance_valid(pilot):
		pilot.observe_actual_shot(shot_id)


func _shot_rejected(reason: StringName) -> void:
	if finished or finish_pending:
		return
	_mark("actual_shot_rejection", {"reason": str(reason)})


func _projectile_impacted(point: Vector2, direction: Vector2) -> void:
	if not _live_world() or finished or finish_pending:
		return
	_mark("actual_player_projectile_impact", {"point": _vec(point), "direction": _vec(direction), "group": encounter.combat_metrics().get("groups_started", 0)})


func _projectile_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _live_world():
		return result
	for projectile: Variant in encounter.get("_projectiles"):
		if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
			result.append({"event_id": str(projectile.event_id), "position": _vec(projectile.global_position), "direction": _vec(projectile.direction), "speed": projectile.speed, "spent": projectile.spent})
	return result


func _slide_rows(player: CharacterBody2D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in player.get_slide_collision_count():
		var collision := player.get_slide_collision(index)
		var collider := collision.get_collider() as Node
		result.append({"path": str(collider.get_path()) if is_instance_valid(collider) else "freed", "normal": _vec(collision.get_normal()), "point": _vec(collision.get_position())})
	return result


func _player_health_changed(result: Object) -> void:
	if str(result.operation) == "damage" and float(result.amount_applied) < 0:
		var live := _live_world()
		_mark("actual_player_injury", {"amount": -float(result.amount_applied), "health": capture_health.current if is_instance_valid(capture_health) else result.snapshot.current, "event_id": str(result.event_id), "state": str(encounter.mode) if live else last_state, "group": encounter.combat_metrics().get("groups_started", 0) if live else final_metrics.get("groups_started", 0), "last_shot_frame": shots.back().frame if not shots.is_empty() else -1})
		if bool(result.snapshot.terminal):
			_latch_player_failure()


func _player_died() -> void:
	_latch_player_failure()


func _latch_player_failure() -> void:
	if fatal_latched or finished:
		return
	fatal_latched = true
	_capture_final_observation()
	_mark("actual_player_terminal_latched_before_App_teardown", {"health": capture_health.current if is_instance_valid(capture_health) else 0, "epoch": _epochs()})
	_fail("Actual player death; failed continuous attempt retained")
	# Synchronous fallback protects the original attempt even if a later App
	# cleanup destroys nodes before the deferred observer finish can run.
	_write_checkpoint("fatal_checkpoint_before_App_teardown")


func _write_checkpoint(kind: String) -> void:
	var file := FileAccess.open(trace_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"task": "BELLSTRIDER-REWORK-01", "kind": kind, "complete": false, "frames": frames, "events": events, "shots": shots, "combat_metrics": _json_value(final_metrics), "final_units": _json_value(final_units), "wallet_delta": final_wallet_delta, "failures": failures, "pilot": pilot_mode, "inputs": pilot.input_rows if is_instance_valid(pilot) else [], "initial_setup": setup, "source_before": source_before, "postdraw_rows": postdraw_rows, "diagnostic_headless": diagnostic_headless}, "\t"))
		file.close()


func _encounter_event(value: Dictionary) -> void:
	if finished or finish_pending:
		return
	_mark(str(value.get("event", "encounter")), {"actual_event": _json_value(value)})


func _mark(id: String, extra: Dictionary = {}) -> void:
	var row := {"event": id, "frame": frames.size() + 1, "movie_frame": Engine.get_process_frames(), "movie_seconds": float(Engine.get_process_frames()) / 60.0}
	row.merge(extra)
	events.append(row)


func _post_draw() -> void:
	if frames.is_empty() or finished or diagnostic_headless:
		return
	var row: Dictionary = frames.back()
	if row.has("rendered_movie_process_frame"):
		return
	row["rendered_movie_process_frame"] = Engine.get_process_frames()
	row["sampling_phase"] = "read-only frame_post_draw confirms preceding process sample"
	postdraw_rows += 1


func _fail(message: String) -> void:
	failures.append(message)
	if not finish_pending:
		finish_pending = true
		finish.call_deferred()


func finish() -> void:
	if finished:
		return
	finished = true
	ready = false
	if process_frame.is_connected(drive):
		process_frame.disconnect(drive)
	if RenderingServer.frame_post_draw.is_connected(_post_draw):
		RenderingServer.frame_post_draw.disconnect(_post_draw)
	_capture_final_observation()
	if _live_world():
		app.controller.router.set_source_axis(&"keyboard_mouse", 0.0)
		app.controller.router.set_jump_held(&"keyboard_mouse", false)
	if is_instance_valid(app):
		if _live_world():
			teardown_epochs["before_abandon"] = _epochs()
		app.abandon_run()
		teardown_epochs["after_abandon"] = {"run": capture_lifetime.epoch, "stage": capture_lifetime.stage_epoch, "actor": capture_lifetime.actor_epoch, "lifetime_active": capture_lifetime.active} if is_instance_valid(capture_lifetime) else {}
		teardown_released = await load("res://tests/audio_teardown.gd").drain_world(app)
		app.free()
		await process_frame
		await process_frame
	if not teardown_released:
		failures.append("Actual App audio teardown did not release")
	var source_after := _source_hashes()
	var git_after := _git_source()
	var stable := source_before == source_after and git_before == git_after
	if not stable:
		failures.append("Source changed during continuous capture")
	var denominations: Array[int] = []
	for unit: Dictionary in final_units:
		denominations.append(int(unit.amount))
	denominations.sort()
	var coverage := {"actual_entry_and_intro": combat_frame > 0 and events.any(func(row: Dictionary) -> bool: return row.event == "state" and row.get("state", "") == "intro"), "40_effective_hits": int(final_metrics.get("accepted_hits", 0)) == 40, "40_effective_damage": is_equal_approx(float(final_metrics.get("accepted_damage", 0)), 40.0), "autonomous_groups": int(final_metrics.get("groups_started", 0)) > 0, "full_death": float(final_metrics.get("death_age", 0)) >= 1.799, "exact_coin_units": denominations == [1, 1, 5, 5], "actual_wallet_plus12": final_wallet_delta == 12, "all_units_claimed": final_units.size() == 4 and final_units.all(func(unit: Dictionary) -> bool: return bool(unit.claimed)), "manifest_unchanged": manifest_unchanged, "native_window": root.size == Vector2i(1280, 720), "original_audio_released": teardown_released, "source_stable": stable}
	for key: String in coverage:
		if not bool(coverage[key]):
			failures.append("Coverage gap: " + key)
	var result := {"task": "BELLSTRIDER-REWORK-01", "kind": "actual_App_autonomous_encounter_scripted_legal_input_player", "complete": failures.is_empty(), "pilot": pilot_mode, "seed": seed_label, "resolution": [1280, 720], "fps": 60, "playback_speed": 1, "initial_setup": setup, "frames": frames, "postdraw_rows": postdraw_rows, "inputs": pilot.input_rows if is_instance_valid(pilot) else [], "shots": shots, "events": events, "combat_metrics": _json_value(final_metrics), "final_units": _json_value(final_units), "wallet_delta": final_wallet_delta, "material_audio_events": _json_value(final_audio), "coverage": coverage, "failures": failures, "source_before": source_before, "source_after": source_after, "git_before": git_before, "git_after": git_after, "source_stable": stable, "audio_teardown_released": teardown_released, "teardown_epochs": teardown_epochs, "not_verified": ["human play acceptance", "visual/listening acceptance", "physical device performance", "third-shot injury if no actual injury is recorded"]}
	result["diagnostic_headless"] = diagnostic_headless
	result["fatal_latched_before_teardown"] = fatal_latched
	result["review_armour"] = review_armour
	result["armour_probe_actual_shot_id"] = pilot.armour_probe_actual_shot if is_instance_valid(pilot) else -1
	if diagnostic_headless:
		result["kind"] = "headless_legal_input_gameplay_diagnostic_NO_GPU_OR_MEDIA_PROOF"
		result["not_verified"].append("headless diagnostic has no rendered pixels, original PCM, or movie proof")
	var file := FileAccess.open(trace_path, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write continuous encounter trace")
		quit(1)
		return
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	await process_frame
	print("BELLSTRIDER REWORK REVIEW: complete; frames=%s; hits=%s; groups=%s; failures=%s" % [frames.size(), final_metrics.get("accepted_hits", 0), final_metrics.get("groups_started", 0), failures.size()])
	quit(0 if failures.is_empty() else 1)


func _stage_ready() -> bool:
	return is_instance_valid(app) and not app._stage_pending and is_instance_valid(app.stage) and app.stage.get_script().resource_path == "res://scripts/demo/plains_region_stage.gd" and bool(app.stage.get("assembly_ok")) and is_instance_valid(app.player) and is_instance_valid(app.controller) and is_instance_valid(app.stage.boss) and app._can_interact() and is_instance_valid(app._run_camera)


func _live_world() -> bool:
	if not is_instance_valid(app) or not is_instance_valid(encounter):
		return false
	if not is_instance_valid(app.stage) or not is_instance_valid(app.player) or not is_instance_valid(app.controller):
		return false
	if not is_instance_valid(app.stage.boss) or not is_instance_valid(app.controller.actor_resources):
		return false
	return encounter.get_parent() == app.stage.boss and not encounter.is_queued_for_deletion() and is_instance_valid(app._run_camera)


func _capture_final_observation() -> void:
	if not _live_world():
		return
	final_metrics = encounter.combat_metrics().duplicate(true)
	final_units = _boss_units()
	final_wallet_delta = int(app.wallet.balance) - wallet_start
	manifest_unchanged = original_manifest == JSON.stringify(app.stage.generated.manifest)
	final_audio.clear()
	for audio: Node in get_nodes_in_group(&"game_audio"):
		if is_instance_valid(audio) and app.is_ancestor_of(audio):
			var material: Variant = audio.get("material_events")
			if material is Array:
				final_audio.append_array(material.duplicate(true))


func _renderer_paths() -> Array[String]:
	var result: Array[String] = []
	for node: Node in app.stage.boss.find_children("*", "", true, false):
		if node.get_script() != null and ("underworld" in node.get_script().resource_path or node.name == &"Presentation"):
			result.append(node.get_script().resource_path)
	return result


func _epochs() -> Dictionary:
	var scope: RefCounted = capture_lifetime if is_instance_valid(capture_lifetime) else app.lifetime if is_instance_valid(app) else null
	return {"run": scope.epoch if scope != null else -1, "stage": scope.stage_epoch if scope != null else -1, "actor": scope.actor_epoch if scope != null else -1, "player_session": app.controller.session_id if is_instance_valid(app) and is_instance_valid(app.controller) else -1, "boss_attack": encounter.attack_epoch if is_instance_valid(encounter) else -1}


func _json_value(value: Variant) -> Variant:
	if value is Vector2:
		return _vec(value)
	if value is Rect2:
		return [value.position.x, value.position.y, value.size.x, value.size.y]
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_json_value(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[str(key)] = _json_value(value[key])
		return result
	return value


func _source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in ["tools/bellstrider_rework_01_capture.gd", "tools/bellstrider_01/legal_input_pilot.gd", "scripts/demo/demo_app.gd", "scripts/bosses/bellstrider_encounter.gd", "scripts/bosses/bellstrider_definition.gd", "scripts/bosses/bellstrider_rig_pose.gd", "scripts/bosses/bellstrider_presentation.gd", "scripts/bosses/bellstrider_bell_projectile.gd", "scripts/bosses/bellstrider_ring_projectile.gd", "scenes/bosses/bellstrider.tscn", "scripts/input/input_router.gd", "scripts/input/keyboard_mouse_adapter.gd", "scripts/combat/shoot_ability.gd", "scripts/player/player_controller.gd", "scripts/player/player_motor.gd", "resources/bosses/bellstrider.tres", "resources/bosses/bellstrider_health.tres", "scripts/rewards/plains_loot_motion.gd", "scripts/audio/bellstrider_audio.gd"]:
		result[path] = FileAccess.get_sha256("res://" + path) if FileAccess.file_exists("res://" + path) else "missing"
	return result


func _git_source() -> Dictionary:
	var head: Array = []
	var status: Array = []
	var directory := ProjectSettings.globalize_path("res://")
	var a := OS.execute("git", ["-C", directory, "rev-parse", "HEAD"], head, true)
	var b := OS.execute("git", ["-C", directory, "status", "--porcelain"], status, true)
	return {"head": str(head[0]).strip_edges() if a == 0 and not head.is_empty() else "unavailable", "status": str(status[0]) if b == 0 and not status.is_empty() else "unavailable"}


func _vec(value: Vector2) -> Array:
	return [value.x, value.y]


func _label(value: String, at: Vector2, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color("10201d"))
	label.add_theme_constant_override("outline_size", 4)
	return label
