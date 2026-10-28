class_name AudioDirectorReels
extends AudioDirectorLabV2
## Normal-speed, fixed-input recording fixtures. No run progression is claimed.
const REELS := ["coin", "heal", "chest_open", "item_get", "ui", "enemy_hit", "enemy_hurt", "hurt", "weapons", "mix"]
const TITLES := {"coin":"金币 · 接触拾取", "heal":"液体回血 · 生命 4→5", "chest_open":"开启宝箱 · 靠近后交互", "item_get":"获得道具 · 真实构筑受付", "ui":"界面 · 选择 / 确认 / 拒绝", "enemy_hit":"命中反馈 · 真实子弹与HP", "enemy_hurt":"敌人受伤 · 单独身体反馈层", "hurt":"主角受伤 · 真实敌弹", "weapons":"三种武器 · 枪 / 手里剑 / 反冲炸弹", "mix":"真实BGM混音 · 拾取 → 实弹 → 受伤"}
var movie_frame_clock: Callable
var reel_event := "coin"
var reel_seed := 387601
var segments: Array[Dictionary] = []
var reel_trace: Array[Dictionary] = []
var _caption: Label
var _detail_caption: Label
var _proof: Label
var _reel_layer: CanvasLayer
var _reward_service: RewardService
var _reward_offer: RewardOffer
var _chest: Sprite2D
var _chest_open := false
var _reel_clock := 0
var _recording := false
var _active_weapon := ""
var selected_receipt: Dictionary = {}

func configure_selected(path: String = "res://config/audio_director/selected/selected.json") -> bool:
	if not FileAccess.file_exists(path): return false
	var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not receipt is Dictionary or receipt.get("candidate_version") != "audio-director-v3": return false
	if not receipt.get("event_profiles") is Dictionary: return false
	if not lab_audio.configure_selected_profiles(receipt.event_profiles): return false
	selected_receipt = receipt
	return true

func set_lab_profile(profile: String) -> bool:
	if profile != "selected": return super.set_lab_profile(profile)
	if selected_receipt.is_empty() or not lab_audio.set_audio_profile(profile): return false
	lab_profile = profile
	_update_lab_status()
	return true

func _update_lab_status() -> void:
	if lab_profile != "selected":
		super._update_lab_status()
	elif is_instance_valid(_lab_status):
		_lab_status.text = "用户所选组合 · 2026-10-28 · 原跳落保留"

func capture_selected_reel(folder: String) -> bool:
	if not configure_selected(): return false
	var all_segments: Array[Dictionary] = []
	var all_trace: Array[Dictionary] = []
	for id: String in REELS:
		if not await capture_reel(id, folder.path_join(id), ["original", "selected"]): return false
		for segment: Dictionary in segments:
			segment["reel"] = id
			all_segments.append(segment.duplicate(true))
		for row: Dictionary in reel_trace:
			row["reel"] = id
			all_trace.append(row.duplicate(true))
	var receipt := {"version": "audio-director-selected-20261028", "fps": 60, "seed": reel_seed, "segments": all_segments, "trace": all_trace, "selection": selected_receipt, "scope": "Ten explicit Home development fixtures; original/selected pairs, native continuous MovieMaker audio. Contexts rebuild between chapters, not a continuous campaign. Original BGM only in final mix chapter."}
	FileAccess.open(folder.path_join("trace.json"), FileAccess.WRITE).store_string(JSON.stringify(receipt))
	return true

func _ready() -> void:
	super._ready()
	if not lab_audio.configure_candidate_bank("res://assets/audio/director_v3/manifest.json", "res://config/audio_director/v3/runtime.json"):
		push_error("AUDIO_REELS missing V3 bank")
		return
	_track = ""
	set_lab_music("")

func _make_controls() -> void:
	super._make_controls()
	_toolbar.hide()
	(_scene_box.get_parent() as Control).hide()
	_reel_layer = CanvasLayer.new()
	_reel_layer.layer = 125
	add_child(_reel_layer)
	var top := PanelContainer.new()
	top.theme = DemoMenu.create_theme()
	top.position = Vector2(32, 22)
	top.size = Vector2(1216, 120)
	_reel_layer.add_child(top)
	var box := VBoxContainer.new()
	top.add_child(box)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 34)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_caption)
	_detail_caption = Label.new()
	_detail_caption.add_theme_font_size_override("font_size", 21)
	_detail_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_detail_caption)
	var bottom := PanelContainer.new()
	bottom.theme = DemoMenu.create_theme()
	bottom.position = Vector2(90, 610)
	bottom.size = Vector2(1100, 85)
	_reel_layer.add_child(bottom)
	_proof = Label.new()
	_proof.add_theme_font_size_override("font_size", 22)
	_proof.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_proof)

func _boot() -> void:
	await open_context("pickup", true)
	lab_ready = true
	_emit_status("ready")

func open_context(context: String, force_reset := false) -> bool:
	if is_instance_valid(item_toast): item_toast.clear()
	_chest_open = false
	_reward_service = null
	_reward_offer = null
	_chest = null
	var accepted := await super.open_context(context, force_reset)
	if accepted and is_instance_valid(home_scene):
		home_scene.overlay.hide()
		# Home's visual-only _process clamps its own camera to x>=640.
		# Freeze that follow observer for this fixed recording composition only;
		# all original physics/input consumers continue processing.
		home_scene.set_process(false)
		home_scene.camera.position = Vector2(300, 342)
		home_scene.camera.zoom = Vector2(1.6, 1.6)
		home_scene.camera.force_update_scroll()
		# This explicit fixture owns interaction; do not also open a nearby Home NPC.
		if home_scene.controller.interact_requested.is_connected(home_scene.interact):
			home_scene.controller.interact_requested.disconnect(home_scene.interact)
		home_scene.controller.interact_requested.connect(_interact_chest)
		var feedback := home_scene.player.get_node("PlayerFeedback") as PlayerFeedback
		feedback.show()
	return accepted

func _make_pickups() -> void:
	_fixture_setup = true
	var initial := home_scene.controller.actor_resources.health_definition.duplicate(true) as HealthDefinition
	initial.initial_current = initial.max_health - 1 if reel_event in ["heal", "mix"] else initial.max_health
	home_scene.controller.actor_resources.health.configure(initial)
	_fixture_setup = false
	if reel_event in ["chest_open", "item_get"]:
		_reward_service = RewardService.new()
		_reward_service.configure(_fixture_scope, _fixture_build)
		var items: Array[ItemDefinition] = [DAMAGE_ITEM]
		_reward_offer = _reward_service.create_cache_offer(&"audio_reel_cache", items, &"audio_reel_source")
		if reel_event == "chest_open":
			_chest = Sprite2D.new()
			_fixture_container.add_child(_chest)
			UnderworldObjects.place_chest(_chest, Vector2(285, HomeScene.FLOOR_Y), false)
		else:
			_spawn_pickup(&"note", 245)
			_fixture_pickups[0]._sprite.texture = ItemPresentation.icon(DAMAGE_ITEM.icon_key)
			_fixture_pickups[0]._sprite.scale = Vector2(30, 30) / _fixture_pickups[0]._sprite.texture.get_size()
	elif reel_event == "mix":
		_spawn_pickup(&"coin", 235)
		_spawn_pickup(&"heart", 345)
	else:
		_spawn_pickup(&"heart" if reel_event == "heal" else &"coin", 245)

func _claim_pickup(kind: StringName, pickup: Node) -> bool:
	if reel_event != "item_get": return super._claim_pickup(kind, pickup)
	if not _claim_reel_item(): return false
	GameAudio.cue_event(self, &"item_get", &"note")
	_show_reel_item_toast()
	var feedback := home_scene.player.get_node("PlayerFeedback") as PlayerFeedback
	feedback.reward_received(pickup.global_position, true)
	_accepted(&"item_get", {"contact": true, "scope": "fixture_area_original_reward_service", "item_id": String(DAMAGE_ITEM.stable_id), "build_count": _fixture_build.count_item(DAMAGE_ITEM.stable_id)})
	return true

func _show_reel_item_toast() -> void:
	item_toast.show_item(DAMAGE_ITEM)
	item_toast.layer = 126
	item_toast._root.position = Vector2(305, 510)

func _claim_reel_item() -> bool:
	if _reward_offer == null: return false
	var request := RewardClaimRequest.new()
	request.token = _fixture_scope.token()
	request.offer_id = _reward_offer.offer_id
	request.option_id = DAMAGE_ITEM.stable_id
	request.claim_id = &"audio_reel_reward_claim"
	return _reward_service.claim(request).status == EconomyReceipt.Status.COMMITTED

func _interact_chest() -> void:
	if reel_event != "chest_open" or _chest_open or not is_instance_valid(_chest): return
	if home_scene.player.position.distance_to(Vector2(285, HomeScene.FLOOR_Y - 18)) >= 80: return
	if not _claim_reel_item(): return
	_chest_open = true
	UnderworldObjects.place_chest(_chest, Vector2(285, HomeScene.FLOOR_Y), true)
	GameAudio.cue_event(self, &"chest_open", &"confirm")
	_show_reel_item_toast()
	_accepted(&"chest_open", {"scope": "fixture_proximity_router_interact_original_reward_service", "opened": true, "build_count": _fixture_build.count_item(DAMAGE_ITEM.stable_id)})

func _accepted(event_id: StringName, details: Dictionary = {}) -> void:
	super._accepted(event_id, details)
	if lab_profile == "selected":
		var profile := lab_audio.director_profile_for_event(event_id)
		lab_events.back()["candidate_id"] = "original" if profile == "original" else "%s_%s" % [event_id, profile.to_lower()]
		lab_events.back()["event_profile"] = profile
	lab_events.back()["movie_frame"] = _movie_frame()
	lab_events.back()["process_frame"] = Engine.get_process_frames()
	if is_instance_valid(_detail_caption):
		_detail_caption.text = "已发生 %s · %s" % [event_id, _candidate_caption(event_id)]
		if reel_event == "weapons" and not _active_weapon.is_empty():
			var shot := &"shot_pulse" if _active_weapon == "pulse_gun" else &"shot_shuriken" if _active_weapon == "shadow_shuriken" else &"shot_bomb"
			_detail_caption.text = "%s · %s · 当前 %s" % [_active_weapon, _candidate_caption(shot), _candidate_caption(event_id)]

func _make_combat() -> void:
	if reel_event == "weapons":
		_fixture_title.text = "武器动作样板：真实枪弹、手里剑、反冲炸弹；命中另片对照"
		return
	super._make_combat()

func _movie_frame() -> int:
	return int(movie_frame_clock.call()) if movie_frame_clock.is_valid() else Engine.get_process_frames()

func _candidate_caption(event_id: StringName) -> String:
	var profile := lab_audio.director_profile_for_event(event_id)
	if profile != "original": return "%s_%s" % [event_id, profile.to_lower()]
	if event_id == &"chest_open": return "原版通用 confirm（无专用开箱声）"
	if event_id == &"item_get": return "原版通用 note（无专用道具声）"
	if event_id == &"shot_bomb": return "原版无发射声；爆炸沿原声"
	return "原版 " + String(event_id)

func _physics_process(_delta: float) -> void:
	super._physics_process(_delta)
	if not _recording or not is_instance_valid(home_scene): return
	_reel_clock += 1
	var actor := _fixture_enemy.get_node_or_null("Actor") as EnemyActor if is_instance_valid(_fixture_enemy) else null
	var row := {"action_frame": _reel_clock, "movie_frame": _movie_frame(), "process_frame": Engine.get_process_frames(), "physics_tick": Engine.get_physics_frames(), "profile": lab_profile, "event": reel_event, "weapon": _active_weapon, "position": [snappedf(home_scene.player.position.x, .001), snappedf(home_scene.player.position.y, .001)], "hp": home_scene.controller.actor_resources.health.current, "enemy_hp": actor.health.current if actor != null else -1, "motion_steps": home_scene.player.motion_steps, "player_screen": [home_scene.player.get_global_transform_with_canvas().origin.x, home_scene.player.get_global_transform_with_canvas().origin.y]}
	reel_trace.append(row)
	if is_instance_valid(_proof):
		_proof.text = "生命 %s/%s　金币 %s　道具 %s\n真实正式角色 / HP / 受付服务 · 开发固定样板 · Seed %s · 60Hz" % [home_scene.controller.actor_resources.health.current, home_scene.controller.actor_resources.health.capacity, _fixture_wallet.balance, _fixture_build.count_item(DAMAGE_ITEM.stable_id), reel_seed]

func _frames(count: int) -> void:
	for unused: int in count: await get_tree().physics_frame

func _walk_reel(goal: float) -> void:
	for unused: int in 150:
		var difference := goal - home_scene.player.position.x
		if absf(difference) < 6: break
		home_scene.controller.router.set_move_axis(clampf(difference / 25, -1, 1))
		await get_tree().physics_frame
	home_scene.controller.router.set_move_axis(0)

func capture_reel(id: String, folder: String, profiles: Array[String] = ["original", "A", "B", "C"]) -> bool:
	if id not in REELS: return false
	reel_event = id
	_active_weapon = ""
	segments.clear()
	reel_trace.clear()
	_reel_clock = 0
	set_lab_music("home" if id == "mix" else "")
	for profile: String in profiles:
		_recording = false
		seed(reel_seed)
		if not set_lab_profile(profile): return false
		var context := "ui" if id == "ui" else "combat" if id in ["enemy_hit", "enemy_hurt", "hurt", "weapons"] else "pickup"
		await open_context(context, true)
		lab_focus = StringName(id)
		lab_audio.set_audition_focus(&"enemy_hit" if id == "weapons" else lab_focus)
		_caption.text = "%s　｜　%s" % [TITLES[id], "原版 ORIGINAL" if profile == "original" else "用户所选组合" if profile == "selected" else "方案 " + profile]
		_detail_caption.text = "同Seed / 同动作 / 原生录音 · 真实事件发生时显示候选ID" if id in ["ui", "weapons", "mix"] else "事件 %s · %s · 同Seed / 同动作 / 原生录音" % [id, _candidate_caption(StringName(id))]
		if id == "ui": (_scene_box.get_parent() as Control).position = Vector2(400, 390)
		if id == "mix":
			for music_voice: AudioStreamPlayer in _music._voices:
				if music_voice.playing: music_voice.seek(0)
		_recording = true
		var start := _reel_clock
		var movie_start := _movie_frame()
		var before := lab_events.size()
		var played_before := lab_audio.played.duplicate()
		var director_before := lab_audio.director_events.size()
		var weapon_before := lab_audio.weapon_events.size()
		await _frames(36)
		if id in ["coin", "heal", "item_get"]:
			await _walk_reel(245)
			await _frames(150 if id == "item_get" else 96)
		elif id == "chest_open":
			await _walk_reel(265)
			home_scene.controller.router.request_action(&"interact")
			await _frames(125)
		elif id == "ui":
			for action: String in ["click", "confirm", "denied"]:
				(_ui_buttons[action] as Button).pressed.emit()
				# Real UI is visible in the captured frame, not hidden behind labels.
				(_scene_box.get_parent() as Control).show()
				await _frames(54)
			(_scene_box.get_parent() as Control).hide()
		elif id == "hurt":
			await _fire_enemy_once()
			await _frames(110)
		elif id == "mix":
			await _walk_reel(345)
			await _frames(35)
			_recording = false
			await open_context("combat", true)
			_recording = true
			await _frames(30)
			home_scene.controller.router.request_action(&"shoot_release", Vector2.RIGHT)
			await _frames(60)
			# The pulse recoil moves the player beyond the original short seed range.
			# Walk back through Router before asking the same original enemy to fire.
			await _walk_reel(210)
			await _fire_enemy_once()
			await _frames(105)
		elif id == "weapons":
			for weapon: String in ["pulse_gun", "shadow_shuriken", "recoil_bomb"]:
				_active_weapon = weapon
				_detail_caption.text = "真实发射 %s · %s" % [weapon, profile]
				home_scene.controller.shoot_ability.equip(load("res://resources/weapons/%s.tres" % weapon) as WeaponDefinition)
				var ability := home_scene.controller.shoot_ability
				ability.shot_fired.connect(_reel_shot.bind(weapon), CONNECT_ONE_SHOT)
				if weapon == "recoil_bomb":
					ability.behavior().blast_fired.connect(_reel_blast, CONNECT_ONE_SHOT)
				home_scene.controller.router.request_action(&"shoot_release", Vector2.RIGHT)
				await _frames(95)
		else:
			home_scene.controller.router.request_action(&"shoot_release", Vector2.RIGHT)
			await _frames(120)
		var delta: Dictionary = {}
		for cue: Variant in lab_audio.played:
			delta[str(cue)] = int(lab_audio.played[cue]) - int(played_before.get(cue, 0))
		var captured_audio := lab_audio.director_events.slice(director_before).duplicate(true)
		var movie_lookup: Dictionary = {}
		for sample: Dictionary in reel_trace: movie_lookup[int(sample.physics_tick)] = int(sample.movie_frame)
		for event: Dictionary in captured_audio: event["movie_frame"] = movie_lookup.get(int(event.tick), -1)
		segments.append({"profile": profile, "start_frame": movie_start, "end_frame": _movie_frame(), "action_start_frame": start, "action_end_frame": _reel_clock, "seed": reel_seed, "events": lab_events.slice(before), "played_delta": delta, "director_events": captured_audio, "weapon_events": lab_audio.weapon_events.slice(weapon_before), "state": {"health": home_scene.controller.actor_resources.health.current, "wallet": _fixture_wallet.balance, "build_count": _fixture_build.count_item(DAMAGE_ITEM.stable_id), "chest_open": _chest_open, "enemy_health": (_fixture_enemy.get_node("Actor") as EnemyActor).health.current if is_instance_valid(_fixture_enemy) else -1}, "music_track": String(_music.requested_track)})
		lab_audio.stop_director_cues()
		await _frames(18)
	_recording = false
	DirAccess.make_dir_recursive_absolute(folder)
	var receipt := {"version": "audio-director-v3-reels-1", "reel": id, "fps": 60, "seed": reel_seed, "segments": segments, "trace": reel_trace, "scope": "Development Home fixture; original Router/physics/projectiles/damage, pickup contact, original wallet/heal/RewardService and visible opened chest. Not natural region progression, subjective approval or device performance."}
	FileAccess.open(folder.path_join("trace.json"), FileAccess.WRITE).store_string(JSON.stringify(receipt))
	return true

func _reel_shot(_axis: Vector2, _serial: int, weapon: String) -> void:
	var event_id := &"shot_pulse" if weapon == "pulse_gun" else &"shot_shuriken" if weapon == "shadow_shuriken" else &"shot_bomb"
	if event_id == &"shot_bomb" and lab_audio.director_profile_for_event(event_id) != "original" and lab_audio.has_director_event(event_id):
		lab_audio.play_director_event(event_id, "", home_scene.player)
	_accepted(event_id, {"scope": "original_shot_fired_signal", "weapon": weapon, "packet": home_scene.controller.shoot_ability.packet_id})

func _reel_blast(point: Vector2) -> void:
	_accepted(&"bomb_explode", {"scope": "original_weapon_runtime_blast_fired", "point": [point.x, point.y]})
