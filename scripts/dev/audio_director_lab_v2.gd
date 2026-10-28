class_name AudioDirectorLabV2
extends DemoApp
## Explicit development fixtures on the real Home/Player/Enemy/services.
## Replays recreate the fixture; profile changes alone never reset the world.
class StationaryAuditionBehavior extends EnemyAttackBehavior:
	# Explicit training control only. The inherited locked-aim projectile and
	# accepted FrameDamagePolicy are unchanged; no unattended repeated damage.
	func advance(delta: float) -> bool:
		state_time += delta
		if state == &"attack" and state_time >= actor.definition.attack_duration: _begin_recovery()
		return false

const PROFILES := {"original": "原版", "A": "A · 实体轻触", "B": "B · 轻响拾取", "C": "C · 短机械"}
const CONTEXTS := {"ui": "界面与交易", "pickup": "拾取小径", "combat": "实弹与受伤"}
const EVENT_IDS: Array[StringName] = [&"click", &"confirm", &"denied", &"coin", &"heal", &"reward", &"enemy_hit", &"enemy_hurt", &"hurt"]
var lab_audio: PlayerWeaponFeelAudioV2
var lab_profile := "original"
var lab_context := "ui"
var lab_focus: StringName = &"confirm"
var lab_ready := false
var lab_events: Array[Dictionary] = []
var demo_running := false
var _context_busy := false
var _serial := 0
var _demo_serial := 0
var _attack_serial := 0
var _fixture_serial := 0
var _fixture_setup := false
var _fixture_scope: DemoLifetime
var _fixture_policy: FrameDamagePolicy
var _fixture_wallet: RunWallet
var _fixture_build: BuildState
var _fixture_shop: ShopService
var _fixture_enemy: EnemyMotor
var _fixture_container: Node2D
var _fixture_pickups: Array[AudioDirectorLabPickup] = []
var _lab_status: Label
var _result: Label
var _scene_box: VBoxContainer
var _toolbar: PanelContainer
var _profile_buttons: Dictionary = {}
var _ui_buttons: Dictionary = {}
var _fixture_title: Label
var _web_window: Variant
var _web_parent: Variant
var _web_json: Variant
var _web_callback: Variant
var _track := "home"
var _audio_paused := false
var _session_volume := 0.7

func _ready() -> void:
	meta_persistence_enabled = false
	set_meta("cloud_preview_host", true)
	var host := get_parent()
	if host != null and host.has_method("open_test_scene"):
		var offered := host.get("custom_audio") as GameAudio
		if is_instance_valid(offered):
			host.remove_child(offered)
			offered.free()
			host.set("custom_audio", null)
		var banner := host.get("banner") as Control
		if is_instance_valid(banner): banner.hide()
	super._ready()
	lab_audio = get_tree().get_first_node_in_group(&"game_audio") as PlayerWeaponFeelAudioV2
	if lab_audio == null or not lab_audio.configure_candidate_bank("res://assets/audio/director_v2/manifest.json", "res://config/audio_director/v2/runtime.json"):
		push_error("AUDIO_LAB_V2 candidate bank unavailable")
		return
	_make_controls()
	if OS.has_feature("web"):
		_install_bridge()
		var context_query: Variant = JavaScriptBridge.eval("new URLSearchParams(location.search).get('lab_context') || 'ui'")
		var profile_query: Variant = JavaScriptBridge.eval("new URLSearchParams(location.search).get('audio_profile') || 'original'")
		if CONTEXTS.has(str(context_query)): lab_context = str(context_query)
		if PROFILES.has(str(profile_query)): lab_profile = str(profile_query)
	set_lab_profile(lab_profile)
	_boot.call_deferred()

func _boot() -> void:
	await open_context(lab_context)
	lab_ready = true
	_emit_status("ready")

func _make_controls() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 118
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_toolbar = PanelContainer.new()
	_toolbar.theme = DemoMenu.create_theme()
	_toolbar.position = Vector2(335, 72)
	_toolbar.size.x = 650
	layer.add_child(_toolbar)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	_toolbar.add_child(box)
	_lab_status = Label.new()
	_lab_status.add_theme_font_size_override("font_size", 17)
	_lab_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lab_status.custom_minimum_size.x = 630
	box.add_child(_lab_status)
	var profiles := HFlowContainer.new()
	profiles.add_theme_constant_override("h_separation", 5)
	box.add_child(profiles)
	for id: String in PROFILES:
		var button := _lab_button(PROFILES[id], profiles)
		button.toggle_mode = true
		button.pressed.connect(func() -> void: set_lab_profile(id))
		_profile_buttons[id] = button
	var contexts := HFlowContainer.new()
	contexts.add_theme_constant_override("h_separation", 5)
	box.add_child(contexts)
	for id: String in CONTEXTS:
		var button := _lab_button(CONTEXTS[id], contexts)
		button.pressed.connect(func() -> void: open_context(id))
	var replay := _lab_button("一键示范 / 重演", contexts)
	replay.pressed.connect(func() -> void: run_demo())
	var stop := _lab_button("停止示范", contexts)
	stop.pressed.connect(stop_demo)
	var unlock := _lab_button("点一下开启场景声音", contexts)
	unlock.pressed.connect(func() -> void: _emit_status("audio_unlocked"))
	var full := _lab_button("完整游戏", contexts)
	full.pressed.connect(return_full_game)
	var scene_panel := PanelContainer.new()
	scene_panel.theme = DemoMenu.create_theme()
	scene_panel.position = Vector2(365, 515)
	scene_panel.size.x = 570
	layer.add_child(scene_panel)
	_scene_box = VBoxContainer.new()
	_scene_box.add_theme_constant_override("separation", 6)
	scene_panel.add_child(_scene_box)
	_fixture_title = Label.new()
	_fixture_title.add_theme_font_size_override("font_size", 18)
	_fixture_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fixture_title.custom_minimum_size.x = 550
	_scene_box.add_child(_fixture_title)
	_result = Label.new()
	_result.add_theme_font_size_override("font_size", 16)
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.custom_minimum_size.x = 550
	_scene_box.add_child(_result)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _lab_button(text: String, parent: Node, ordinary_click := false) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(100, 42)
	button.add_theme_font_size_override("font_size", 16)
	button.set_meta("audio_skip_click", not ordinary_click)
	button.button_down.connect(_clear_input)
	parent.add_child(button)
	return button

func _layout() -> void:
	if not is_instance_valid(_toolbar): return
	var viewport_size := get_viewport_rect().size
	_toolbar.position.x = maxf(8, (viewport_size.x - minf(650, viewport_size.x - 16)) / 2)
	_toolbar.size.x = minf(650, viewport_size.x - 16)

func _clear_input() -> void:
	if is_instance_valid(home_scene): home_scene.controller.router.clear("audio_lab_v2_ui")

func set_lab_profile(profile: String) -> bool:
	if not PROFILES.has(profile) or not is_instance_valid(lab_audio) or not lab_audio.set_audio_profile(profile): return false
	lab_profile = profile
	for id: String in _profile_buttons: (_profile_buttons[id] as Button).set_pressed_no_signal(id == profile)
	_update_lab_status()
	_emit_status("profile")
	return true

func _update_lab_status() -> void:
	if is_instance_valid(_lab_status): _lab_status.text = "SOUND LAB 02 · %s · %s · 原跳落/枪声保留" % [PROFILES[lab_profile], CONTEXTS[lab_context]]

func open_context(context: String, force_reset := false) -> bool:
	if not CONTEXTS.has(context) or _context_busy: return false
	if context == lab_context and is_instance_valid(_fixture_container) and not force_reset:
		_emit_status("context")
		return true
	_context_busy = true
	stop_demo()
	_fixture_serial += 1
	if _fixture_scope != null: _fixture_scope.end()
	if is_instance_valid(_fixture_enemy):
		var old_actor := _fixture_enemy.get_node_or_null("Actor") as EnemyActor
		if old_actor != null and old_actor.attack_behavior != null: old_actor.attack_behavior.cancel()
	if is_instance_valid(_fixture_build): _fixture_build.clear()
	if is_instance_valid(_fixture_policy):
		_fixture_policy.queue_free()
		_fixture_policy = null
	_remove_home_scene()
	_fixture_container = null
	_fixture_enemy = null
	_fixture_pickups.clear()
	for key: Variant in _ui_buttons:
		var old := _ui_buttons[key] as Control
		if is_instance_valid(old): old.queue_free()
	_ui_buttons.clear()
	await get_tree().process_frame
	_show_home()
	if not is_instance_valid(home_scene):
		_context_busy = false
		_emit_status("error", {"message": "正式家园未能加载"})
		return false
	# The normal Home consumer and all character motion stay intact. Its lower
	# interaction prompt is hidden only because this fixture supplies its own task.
	home_scene._hud.hide()
	home_scene._controls.hide()
	_fixture_container = Node2D.new()
	_fixture_container.name = "AudioContextFixture"
	home_scene.add_child(_fixture_container)
	_fixture_scope = DemoLifetime.new()
	_fixture_wallet = RunWallet.new()
	_fixture_build = BuildState.new()
	_fixture_build.configure(home_scene.controller)
	_fixture_policy = FrameDamagePolicy.new()
	_fixture_policy.lifetime = _fixture_scope
	_fixture_policy.register_player_controller(home_scene.controller)
	_fixture_policy.register_target(&"player", home_scene.controller.actor_resources.health, true)
	add_child(_fixture_policy)
	_fixture_policy.batch_resolved.connect(_damage_results)
	home_scene.controller.actor_resources.health.changed.connect(_player_health_changed)
	home_scene.controller.weapon_damage_committed.connect(_weapon_committed)
	lab_context = context
	lab_focus = &"confirm" if context == "ui" else &"coin" if context == "pickup" else &"enemy_hit"
	lab_audio.set_audition_focus(lab_focus)
	_result.text = "这是开发试听样板；物件与受击均走实际消费者。"
	if context == "ui": _make_shop()
	elif context == "pickup": _make_pickups()
	else: _make_combat()
	_update_lab_status()
	_context_busy = false
	_emit_status("context")
	return true

func _make_shop() -> void:
	_fixture_title.text = "真实交易界面：选择 → 购买成功 / 余额不足"
	_fixture_wallet.grant(3, &"fixture_ui_initial")
	_fixture_shop = ShopService.new()
	_fixture_shop.configure(_fixture_scope, _fixture_build, _fixture_wallet)
	_fixture_shop.add_offer(&"affordable", DAMAGE_ITEM, 1, 8)
	_fixture_shop.add_offer(&"expensive", DAMAGE_ITEM, 99, 8)
	var row := HFlowContainer.new()
	_scene_box.add_child(row)
	_ui_buttons["row"] = row
	var click := _lab_button("选择轻铜枪管", row, true)
	click.pressed.connect(func() -> void:
		click.modulate = Color("dceeb8") if click.modulate == Color.WHITE else Color.WHITE
		_accepted(&"click", {"selection": "damage_blue"}))
	_ui_buttons["click"] = click
	var confirm := _lab_button("购买 · 1 金币", row)
	confirm.pressed.connect(func() -> void: _purchase(&"affordable"))
	_ui_buttons["confirm"] = confirm
	var denied := _lab_button("尝试购买 · 99 金币", row)
	denied.pressed.connect(func() -> void: _purchase(&"expensive"))
	_ui_buttons["denied"] = denied
	_result.text = "试玩钱包：3 金币。按钮执行原 ShopService 交易规则。"

func _purchase(offer: StringName) -> void:
	if _fixture_shop == null: return
	_serial += 1
	var request := ShopPurchaseRequest.new()
	request.token = _fixture_scope.token()
	request.offer_id = offer
	request.transaction_id = StringName("audio_fixture_trade_%s_%s" % [_fixture_serial, _serial])
	var receipt := _fixture_shop.purchase(request)
	var event: StringName = &"confirm" if receipt.status == EconomyReceipt.Status.COMMITTED else &"denied"
	GameAudio.cue(self, event)
	_result.text = "购买成功：轻铜枪管；余额 %s" % _fixture_wallet.balance if event == &"confirm" else "交易拒绝：余额不足或库存耗尽；余额 %s" % _fixture_wallet.balance
	_accepted(event, {"receipt_lab_status": receipt.status, "wallet": _fixture_wallet.balance})

func _make_pickups() -> void:
	_fixture_title.text = "拾取小径：向右移动实际接触金币、生命、普通奖励"
	# An explicit development initial condition, not a damage event. Configure
	# the real HealthState with 4/5 HP so the heart can demonstrate an actual
	# heal without preceding the pickup comparison with unrelated hurt audio.
	_fixture_setup = true
	var initial := home_scene.controller.actor_resources.health_definition.duplicate(true) as HealthDefinition
	initial.initial_current = maxf(1, initial.max_health - 1)
	if not home_scene.controller.actor_resources.health.configure(initial):
		push_error("Audio pickup fixture has an invalid initial health condition")
	_fixture_setup = false
	_spawn_pickup(&"coin", 235)
	_spawn_pickup(&"heart", 345)
	_spawn_pickup(&"note", 455)
	_spawn_enemy(265)
	var row := HFlowContainer.new()
	_scene_box.add_child(row)
	_ui_buttons["row"] = row
	var injury := _lab_button("额外接受一次敌弹（可选）", row)
	injury.pressed.connect(func() -> void: _fire_enemy_once())
	_result.text = "样板初始生命 4/5；真实接触拾取恢复生命，不先播放受伤声。"

func _spawn_pickup(kind: StringName, x: float) -> void:
	var pickup := AudioDirectorLabPickup.new()
	pickup.kind = kind
	pickup.expected_player = home_scene.player
	pickup.claim = _claim_pickup
	pickup.position = Vector2(x, HomeScene.FLOOR_Y - 27)
	_fixture_container.add_child(pickup)
	_fixture_pickups.append(pickup)

func _claim_pickup(kind: StringName, pickup: Node) -> bool:
	_serial += 1
	var receipt := StringName("audio_fixture_pickup_%s_%s" % [_fixture_serial, pickup.get_instance_id()])
	var event: StringName
	if kind == &"coin":
		if not _fixture_wallet.grant(1, receipt): return false
		event = &"coin"
	elif kind == &"heart":
		var result := SupplyHealEffect.apply(home_scene.controller.actor_resources.health, 1, receipt)
		if result.status != ActorResourceResult.Status.APPLIED or result.amount_applied <= 0: return false
		event = &"heal"
	else:
		var result := meta.grant_notes(1, receipt)
		if not result.get("accepted", false): return false
		event = &"reward"
	GameAudio.cue(self, &"note" if event == &"reward" else event)
	var feedback := home_scene.player.get_node("PlayerFeedback") as PlayerFeedback
	feedback.reward_received(pickup.global_position, kind == &"note")
	_result.text = "已实际拾取：%s；金币 %s，生命 %s/%s" % [event, _fixture_wallet.balance, home_scene.controller.actor_resources.health.current, home_scene.controller.actor_resources.health.capacity]
	_accepted(event, {"contact": true, "wallet": _fixture_wallet.balance, "health": home_scene.controller.actor_resources.health.current})
	return true

func _spawn_enemy(x: float) -> void:
	_fixture_enemy = preload("res://scenes/enemies/patrol_drone.tscn").instantiate() as EnemyMotor
	_fixture_enemy.position = Vector2(x, HomeScene.FLOOR_Y - 18)
	var actor := _fixture_enemy.get_node("Actor") as EnemyActor
	# Explicit stationary fixture: original Sentry definition, original attack,
	# health and accepted-damage implementation, no altered movement/HP rules.
	actor.definition = preload("res://resources/enemies/plains_sentry.tres")
	_fixture_container.add_child(_fixture_enemy)
	actor.brain.enabled = false
	var audition_behavior := StationaryAuditionBehavior.new()
	actor.add_child(audition_behavior)
	audition_behavior.configure(actor, home_scene.controller, _fixture_policy, _fixture_scope, &"audio_lab_sentry", [])
	actor.attack_behavior = audition_behavior
	_fixture_policy.bind_damageable(&"audio_lab_enemy", actor.damageable, actor.health)
	actor.damageable.damaged.connect(func(_context: Dictionary) -> void:
		_accepted(&"enemy_hurt" if lab_focus == &"enemy_hurt" else &"enemy_hit", {"health": actor.health.current, "scope": "actual_enemy_damage_receipt"}))
	actor.defeated.connect(func(_enemy: EnemyActor) -> void: _result.text = "训练敌人已被实际击败；点重演生成新的样板。")

func _make_combat() -> void:
	_fixture_title.text = "真实战斗：瞄准右侧训练敌人射击，或接受一次敌弹"
	_spawn_enemy(265)
	var row := HFlowContainer.new()
	_scene_box.add_child(row)
	_ui_buttons["row"] = row
	var hit := _lab_button("命中反馈示范", row)
	hit.pressed.connect(func() -> void: run_demo("enemy_hit"))
	var body := _lab_button("敌人受伤示范", row)
	body.pressed.connect(func() -> void: run_demo("enemy_hurt"))
	var hurt := _lab_button("主角受伤示范", row)
	hurt.pressed.connect(func() -> void: run_demo("hurt"))
	_result.text = "当前只听命中层；HP真实扣除。切换敌人受伤示范可单独比较身体反馈，避免双响。"

func _fire_enemy_once() -> bool:
	if not is_instance_valid(_fixture_enemy) or not is_instance_valid(home_scene): return false
	var actor := _fixture_enemy.get_node("Actor") as EnemyActor
	if actor.health.terminal or actor.attack_behavior == null or home_scene.controller.actor_resources.health.current <= 1:
		_result.text = "请重演场景，避免在试听中反复受伤至死亡。"
		return false
	var behavior := actor.attack_behavior
	_attack_serial += 1
	var attack_token := _attack_serial
	behavior.locked_direction = (home_scene.player.global_position - _fixture_enemy.global_position).normalized()
	behavior._set_state(&"telegraph")
	var fixture := _fixture_serial
	await get_tree().create_timer(actor.definition.telegraph_duration).timeout
	if fixture != _fixture_serial or attack_token != _attack_serial or _audio_paused or not is_instance_valid(behavior) or _fixture_scope == null or not _fixture_scope.active: return false
	behavior._set_state(&"attack")
	behavior._fire()
	return true

func _weapon_committed(_packet: int, _shot: int, _receiver: Damageable, _session: int, _epoch: int) -> void:
	_result.text = "实弹命中已提交；当前比较 %s，未叠加另一个受伤层。" % lab_focus

func _damage_results(results: Array[DamageResult]) -> void:
	for result: DamageResult in results:
		if result.request.target_id == &"player":
			_result.text = "敌弹实际命中；生命 %s/%s" % [home_scene.controller.actor_resources.health.current, home_scene.controller.actor_resources.health.capacity]

func _player_health_changed(result: ActorResourceResult) -> void:
	if _fixture_setup: return
	if result.operation == &"damage" and result.status == ActorResourceResult.Status.APPLIED and result.amount_applied < 0:
		var source := "actual_enemy_projectile_damage" if str(result.event_id).begins_with("audio_lab_sentry:seed:") else "actual_health_state_damage"
		_accepted(&"hurt", {"health": result.snapshot.current, "scope": source})

func run_demo(event_id := "") -> void:
	if _context_busy or demo_running: return
	var requested := StringName(event_id)
	var context := "ui" if requested in [&"click", &"confirm", &"denied"] else "pickup" if requested in [&"coin", &"heal", &"reward"] else "combat" if requested in [&"enemy_hit", &"enemy_hurt", &"hurt"] else lab_context
	if not await open_context(context, true): return
	lab_focus = requested if requested in EVENT_IDS else &"confirm" if context == "ui" else &"coin" if context == "pickup" else &"enemy_hit"
	lab_audio.set_audition_focus(lab_focus)
	demo_running = true
	_demo_serial += 1
	var token := _demo_serial
	_emit_status("demo_started")
	await _ticks(20, token)
	if not _demo_valid(token): return
	if context == "ui":
		var actions: Array[String] = []
		if requested in [&"click", &"confirm", &"denied"]: actions.append(String(lab_focus))
		else: actions.assign(["click", "confirm", "denied"])
		for action: String in actions:
			if not _demo_valid(token): return
			(_ui_buttons[action] as Button).pressed.emit()
			await _ticks(50, token)
	elif context == "pickup":
		var goal := 235.0 if lab_focus == &"coin" and not requested.is_empty() else 345.0 if lab_focus == &"heal" else 455.0
		await _walk_to(goal, token)
		await _ticks(20, token)
	else:
		if lab_focus == &"hurt":
			await _fire_enemy_once()
			await _ticks(85, token)
		else:
			home_scene.controller.router.request_action(&"shoot_release", Vector2.RIGHT)
			await _ticks(65, token)
	if not _demo_valid(token): return
	demo_running = false
	_clear_input()
	_emit_status("demo_finished")

func _walk_to(goal: float, token: int) -> void:
	for unused: int in 220:
		if not _demo_valid(token): return
		var difference := goal - home_scene.player.position.x
		if absf(difference) < 8: break
		home_scene.controller.router.set_move_axis(clampf(difference / 25, -1, 1))
		await get_tree().physics_frame
	if is_instance_valid(home_scene): home_scene.controller.router.set_move_axis(0)

func _ticks(count: int, token: int) -> void:
	for unused: int in count:
		if not _demo_valid(token): return
		await get_tree().physics_frame

func _demo_valid(token: int) -> bool:
	return token == _demo_serial and demo_running and is_instance_valid(home_scene)

func stop_demo() -> void:
	_attack_serial += 1
	if is_instance_valid(_fixture_enemy):
		var actor := _fixture_enemy.get_node_or_null("Actor") as EnemyActor
		if actor != null and actor.attack_behavior != null: actor.attack_behavior.cancel()
	_demo_serial += 1
	demo_running = false
	_clear_input()
	if is_instance_valid(lab_audio): lab_audio.stop_director_cues()

func _accepted(event_id: StringName, details: Dictionary = {}) -> void:
	var row := {"event_id": String(event_id), "candidate_id": "original" if lab_profile == "original" else "%s_%s" % [event_id, lab_profile.to_lower()], "profile": lab_profile, "context": lab_context, "focus": String(lab_focus), "tick": Engine.get_physics_frames(), "fixture": _fixture_serial, "details": details}
	lab_events.append(row)
	if lab_events.size() > 128: lab_events.pop_front()
	_emit_status("accepted_event", row)

func pause_audition_audio(paused: bool) -> void:
	_audio_paused = paused
	if paused:
		stop_demo()
		lab_audio.volume = 0
		for voice: AudioStreamPlayer in lab_audio._voices: voice.stop()
	else: lab_audio.volume = _session_volume
	_emit_status("audio_paused", {"paused": paused})

func _sync_music() -> void:
	# DemoApp's ordinary state observer would otherwise replace the audition
	# selection with Home every frame. This override is specific to the lab.
	if is_instance_valid(_music): _music.request_track(StringName(_track))

func set_lab_music(track: String) -> bool:
	if not track.is_empty() and not GameMusic.TRACKS.has(StringName(track)): return false
	_track = track
	_music.request_track(StringName(track))
	_emit_status("music", {"track": track})
	return true

func _emit_status(event: String, extra: Dictionary = {}) -> void:
	var payload := {"type": "audio-lab-status", "event": event, "context": lab_context, "profile": lab_profile, "focus": String(lab_focus), "track": _track, "paused": _audio_paused, "demo_running": demo_running, "version": "audio-director-v2", "audio_unlocked": _music._unlocked if is_instance_valid(_music) else false}
	payload.merge(extra, true)
	print("AUDIO_LAB_V2 " + JSON.stringify(payload))
	if _web_parent != null:
		_web_parent.postMessage(_web_json.parse(JSON.stringify(payload)), str(_web_window.location.origin))

func _install_bridge() -> void:
	var bridge := Engine.get_singleton("JavaScriptBridge")
	_web_window = bridge.call("get_interface", "window")
	_web_parent = bridge.call("get_interface", "parent")
	_web_json = bridge.call("get_interface", "JSON")
	bridge.call("eval", "window.audioLabAcceptEvent = e => e.source === parent && e.origin === location.origin;")
	_web_callback = bridge.call("create_callback", _receive_web_message)
	_web_window.addEventListener("message", _web_callback)

func _receive_web_message(arguments: Array) -> void:
	if arguments.is_empty() or not _web_window.audioLabAcceptEvent(arguments[0]): return
	var payload: Variant = JSON.parse_string(str(_web_json.stringify(arguments[0].data)))
	if not payload is Dictionary or payload.get("type") != "audio-lab-command": return
	var value := str(payload.get("value", ""))
	match str(payload.get("command", "")):
		"context": open_context(value)
		"profile": set_lab_profile(value)
		"demo": run_demo(value)
		"pause_audio": pause_audition_audio(payload.get("value", false) == true)
		"music": set_lab_music(value)

func return_full_game() -> void:
	stop_demo()
	_fixture_scope.end()
	if _web_parent != null: _emit_status("full_game")
	var host := get_parent()
	if host != null and host.has_method("return_to_menu"): host.call_deferred("return_to_menu")
	else: get_tree().change_scene_to_file("res://scenes/demo/demo.tscn")

func _exit_tree() -> void:
	if _fixture_scope != null: _fixture_scope.end()
	if _web_window != null and _web_callback != null: _web_window.removeEventListener("message", _web_callback)
