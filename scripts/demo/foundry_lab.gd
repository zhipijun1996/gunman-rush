class_name FoundryLab
extends Node2D
## Development consumer: verified batches, shared controller/damage, input replay,
## local feedback and reproducible itineraries. Never settles Run/Meta rewards.
signal home_requested
const PLAYER := preload("res://scenes/player/player.tscn")
const FONT := preload("res://assets/fonts/foundry_ui.otf")
var input_values: Dictionary = InputProfile.load_default().values.duplicate(true)
var stage: FoundryWorld
var player: PlayerMotor
var controller: PlayerController
var policy: FrameDamagePolicy
var segment: SegmentRespawn
var lifetime := DemoLifetime.new()
var camera: StageCameraRig
var route_player: FoundryRoutePlayer
var ready_for_play := false
var finished := false
var elapsed := 0.0
var batch: Dictionary
var selected: Dictionary
var entries: Array = []
var feedback: Array = []
var pending: Dictionary = {}
var autoplay := false
var _title: Label
var _detail: Label
var _status: Label
var _level_scroll: ScrollContainer
var _levels: VBoxContainer
var _level_buttons: Array[Button] = []
var _profile_buttons: Array[Button] = []
var _page := 0
var _page_label: Label
var _page_previous: Button
var _page_next: Button
var _show_sources := false
var _source_buttons: Array[Button] = []
var _profile_index := 0
var _profile_name: Label
var _seed: LineEdit
var _hud: ActorResourcesHud
var _panel: PanelContainer
var enemies_enabled := false
var encounter: FoundryEncounter
var _feedback_blocker: Control
var _feedback_panel: PanelContainer
var _feedback_note: TextEdit
var _feedback_was_paused := false
var _feedback_context: Dictionary = {}
var _closed := false
var _active_anchor := -1
var _overlay: TouchOverlay

func configure(values: Dictionary) -> bool:
	var profile := InputProfile.load_default()
	if not profile.configure(values): return false
	input_values = profile.values.duplicate(true)
	return true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 1100
	batch = FoundryCatalog.batch()
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://foundry_feedback.json")) if FileAccess.file_exists("user://foundry_feedback.json") else []
	feedback = clean_feedback(saved)
	_make_ui()
	_refresh_entries()
	if not entries.is_empty(): choose(0)

func _refresh_entries() -> void:
	entries.clear()
	for button: Button in _level_buttons:
		_levels.remove_child(button)
		button.queue_free()
	_level_buttons.clear()
	var profile_id := str(FoundryCatalog.profiles()[_profile_index].id)
	for entry: Dictionary in batch.get("accepted", []):
		if entry.manifest.capability_profile != profile_id: continue
		entries.append(entry)
		var t := FoundryCatalog.template(entry.manifest.template_id)
		var index := entries.size() - 1
		var button := _button(_levels, "%s · V%d / P%d" % [t.name, entry.manifest.variant + 1, entry.manifest.phase_index], func() -> void: choose(index))
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.add_theme_font_size_override("font_size", 16)
		_level_buttons.append(button)
	show_page(0)
	_status.text = "%d 段已通过真实轨迹与输入回放；趣味性待试玩。" % entries.size() if not entries.is_empty() else "没有该能力配置的有效批次。运行 python3 tools/foundry.py build --promote。"

func choose(index: int, replay: bool = false) -> void:
	if _closed or index < 0 or index >= entries.size() or (_feedback_panel != null and _feedback_panel.visible): return
	if not _show_sources: show_page(index / 3)
	selected = entries[index].manifest.duplicate(true)
	for i: int in _level_buttons.size():
		_level_buttons[i].set_pressed_no_signal(i == index)
	request(selected, replay)

func request(manifest: Dictionary, replay: bool = false) -> bool:
	if _feedback_panel != null and _feedback_panel.visible: return false
	if replay and enemies_enabled:
		_status.text = "敌人模式仅手动测试；关闭敌人后可回放平台路线。"
		return false
	if not FoundryCatalog.valid(manifest): return false
	if is_instance_valid(route_player): route_player.stop()
	if is_instance_valid(controller):
		controller.router.clear("foundry_new_attempt")
		controller.air_focus_ability.stop()
		controller.active = false
	lifetime.end()
	ready_for_play = false
	pending = manifest.duplicate(true)
	autoplay = replay
	get_tree().paused = false
	return true

func random_itinerary() -> void:
	if _feedback_panel.visible: return
	var profile_id := str(FoundryCatalog.profiles()[_profile_index].id)
	var routes: Array = batch.get("itineraries", []).filter(func(m: Dictionary) -> bool: return m.capability_profile == profile_id)
	if routes.is_empty():
		_status.text = "没有该能力配置的已验证整段路线。请重新构建批次。"
		return
	var seed_value := _seed.text.strip_edges()
	if seed_value.is_empty():
		seed_value = "foundry-%d" % Time.get_ticks_msec()
		_seed.text = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value.hash()
	# Choose only complete validated itineraries. A fresh arrangement must go
	# through build-time continuous physics verification before joining this list.
	selected = routes[rng.randi_range(0, routes.size() - 1)].duplicate(true)
	request(selected)

func export_feedback() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(JSON.stringify(feedback_bundle(), "  ").to_utf8_buffer(), "foundry-feedback.json", "application/json")
	else:
		var file := FileAccess.open("user://foundry-feedback-export.json", FileAccess.WRITE)
		if file == null:
			_status.text = "反馈导出失败，请重试。"
			return
		file.store_string(JSON.stringify(feedback_bundle(), "  "))
		file.close()
		_status.text = "评价文件：" + ProjectSettings.globalize_path("user://foundry-feedback-export.json")

func _physics_process(delta: float) -> void:
	if not pending.is_empty():
		var next := pending.duplicate(true)
		pending.clear()
		# Physics-body creation during the current physics traversal can give
		# AnimatableBody an extra initial velocity step. Start attempts in idle.
		_load.call_deferred(next)
		return
	if not ready_for_play or _closed: return
	elapsed += delta
	if not stage.bounds.grow(24).has_point(player.global_position):
		var damage := DamageRequest.new()
		damage.token = lifetime.token()
		damage.actor_epoch = lifetime.actor_epoch
		damage.health_epoch = controller.actor_resources.health.epoch
		damage.target_id = &"player"
		damage.source_id = &"foundry_bounds"
		damage.event_id = StringName("bounds_%d" % lifetime.actor_epoch)
		damage.kind = DamageRequest.Kind.ENVIRONMENT
		damage.amount = 1
		policy.submit(damage)
	if player.is_on_floor():
		var points := stage.anchors()
		for index: int in points.size():
			if index != _active_anchor and player.global_position.distance_to(points[index]) < 30 and segment.activate_anchor(StringName("anchor_%d" % index)): _active_anchor = index
	if not finished and stage.modules.back().port_accepts(stage.modules.back().definition.exit_port, player):
		finished = true
		_status.text = "挑战完成 · %.1f 秒。可以评价这一段，或选择下一段。" % elapsed

func _load(manifest: Dictionary) -> void:
	var requested_autoplay := autoplay
	_clear()
	stage = FoundryWorld.new()
	add_child(stage)
	if not stage.build(manifest): _status.text = "模块记录已过期或无效。"; return
	player = PLAYER.instantiate() as PlayerMotor
	player.position = stage.entry()
	add_child(player)
	controller = player.get_node("Controller") as PlayerController
	if requested_autoplay: controller.set_physics_process(false)
	controller.router.reconfigure(input_values)
	if not FoundryCatalog.apply_profile(controller, manifest.capability_profile): _status.text = "该能力尚未实现。"; return
	_overlay = InputSetup.attach(player, controller.router)
	_overlay.hide_reset_button = true
	_overlay.pause_label = "PAUSE"
	_overlay.pause_requested.connect(toggle_pause)
	var guide := DemoAimGuide.new()
	guide.controller = controller
	player.add_child(guide)
	var vignette := FocusVignette.new()
	vignette.ability = controller.air_focus_ability
	player.add_child(vignette)
	lifetime.active = true
	policy = FrameDamagePolicy.new()
	policy.lifetime = lifetime
	add_child(policy)
	policy.register_target(&"player", controller.actor_resources.health, true)
	policy.environment_return_requested.connect(_return)
	policy.player_fatal.connect(_fatal)
	segment = SegmentRespawn.new()
	segment.configure(controller, lifetime)
	segment.danger_bounds = stage.danger_envelopes()
	var points := stage.anchors()
	for index: int in points.size(): segment.add_anchor(StringName("anchor_%d" % index), points[index])
	for module: PlatformingModule in stage.modules:
		module.setup_damage(controller, policy, lifetime)
	for danger: Rect2 in stage.static_dangers():
		var contact := DemoContactEmitter.new()
		contact.policy = policy
		contact.controller = controller
		contact.kind = DamageRequest.Kind.ENVIRONMENT
		contact.source_id = StringName("foundry_danger_%d" % get_child_count())
		contact.position = danger.get_center()
		contact.half_size = danger.size / 2
		add_child(contact)
	camera = StageCameraRig.new()
	# Expose the 190px receiver below the authoring HUD without changing physics.
	camera.viewing_zoom = 1.0
	add_child(camera)
	camera.configure(player, stage.bounds)
	_hud.bind(controller.actor_resources, controller.air_focus_ability, controller)
	elapsed = 0
	finished = false
	_active_anchor = 0
	var t := FoundryCatalog.template(str(manifest.get("template_id", "")))
	_title.text = t.get("name", "三段随机路线")
	_detail.text = t.get("experience", "三段连续路线已通过整段物理与输入回放；趣味性待试玩。")
	_detail.text += "\n" + " → ".join(t.get("decisions", []))
	_status.text = "一跳 / 射击反冲 · 沿用实际 HP、精力、冷却与段内回退。"
	var token := lifetime.token()
	await get_tree().physics_frame
	await get_tree().process_frame
	if not lifetime.accepts(token) or _closed: return
	if requested_autoplay:
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(FoundryCatalog.replay_path(manifest.id))) if FileAccess.file_exists(FoundryCatalog.replay_path(manifest.id)) else null
		if value is Dictionary:
			route_player = FoundryRoutePlayer.new()
			add_child(route_player)
			route_player.completed.connect(func(ok: bool, reason: String) -> void: _status.text = ("输入回放完成" if ok else "回放停止") + " / " + reason)
			if not route_player.start(controller, value, manifest): _status.text = "回放记录不兼容。"
		else: _status.text = "此组合没有整段输入回放；可以手动试玩。"
	if enemies_enabled:
		encounter = FoundryEncounter.new()
		add_child(encounter)
		encounter.setup(self)
		_status.text = "敌人手动测试：%d 个敌人；无永久奖励，平台回放不包含敌人。" % encounter.actors.size()
	ready_for_play = segment.activate_anchor(&"anchor_0")
	policy.protect_player()

func _return() -> void:
	if is_instance_valid(route_player): route_player.stop()
	if segment.return_to_anchor():
		policy.protect_player()
		_status.text = "回到安全落点；HP、精力、机关相位和本次计时保留。"

func _fatal() -> void:
	if is_instance_valid(route_player): route_player.stop()
	controller.die()
	ready_for_play = false
	_status.text = "练习结束，零血。点击重试开始新尝试。"

func rate(rating: String, note: String = "") -> bool:
	if rating == "note" and note.strip_edges().is_empty(): return false
	if selected.is_empty() or not rating in ["keep", "boring", "hard", "unclear", "control", "note"]: return false
	feedback.append({"id": selected.id, "template_id": selected.get("template_id", "itinerary"), "rating": rating, "basis": selected.basis, "profile": selected.capability_profile, "completed": finished, "seconds": elapsed, "timestamp": Time.get_unix_time_from_system()})
	feedback.back()["note"] = note.left(1000)
	feedback.back()["manifest"] = selected.duplicate(true)
	feedback.back()["enemy_mode"] = enemies_enabled
	feedback.back()["enemy_spawns"] = encounter.spawn_records.duplicate(true) if is_instance_valid(encounter) else []
	feedback.back()["player_position"] = [player.position.x, player.position.y] if is_instance_valid(player) else []
	feedback.back()["engine"] = Engine.get_version_info().string
	feedback = feedback.slice(maxi(0, feedback.size() - 500))
	var file := FileAccess.open("user://foundry_feedback.json.tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(feedback))
	file.close()
	if DirAccess.rename_absolute("user://foundry_feedback.json.tmp", "user://foundry_feedback.json") != OK: return false
	_status.text = "评价已记录；导出后可交给 AI 批量分析并修改模板。"
	return true

static func clean_feedback(value: Variant) -> Array:
	var result: Array = []
	if not value is Array: return result
	for vote: Variant in value.slice(maxi(0, value.size() - 500)):
		if not vote is Dictionary or vote.get("rating") not in ["keep", "boring", "hard", "unclear", "control", "note"]: continue
		var valid := true
		for key: String in ["id", "template_id", "basis", "profile"]:
			if not vote.get(key) is String or vote[key].length() > 150: valid = false
		if valid:
			var copy: Dictionary = vote.duplicate(true)
			copy["note"] = str(copy.get("note", "")).left(1000)
			result.append(copy)
	return result

func toggle_pause() -> void:
	if _feedback_panel != null and _feedback_panel.visible: return
	if is_instance_valid(controller): controller.router.clear("foundry_pause"); controller.air_focus_ability.stop()
	get_tree().paused = not get_tree().paused
	_status.text = "已暂停。再次点击暂停或按 Esc 继续。" if get_tree().paused else "继续挑战。"

func leave() -> void:
	if _closed: return
	_closed = true
	lifetime.end()
	if is_instance_valid(route_player): route_player.stop()
	if is_instance_valid(controller): controller.router.clear("foundry_leave"); controller.air_focus_ability.stop(); controller.active = false
	get_tree().paused = false
	home_requested.emit()

func _clear() -> void:
	_hud.unbind()
	if is_instance_valid(route_player): route_player.stop()
	for child: Node in get_children():
		if child is CanvasLayer: continue
		remove_child(child)
		child.free()
	stage = null
	player = null
	controller = null
	policy = null
	camera = null
	route_player = null
	encounter = null

func _process(_delta: float) -> void:
	if is_instance_valid(controller):
		_title.text = "%s  ·  %.1fs  ·  %d跳 / %d发" % [FoundryCatalog.template(str(selected.get("template_id", ""))).get("name", "三段随机路线"), elapsed, player.tuning.max_jumps, controller.action_resources.shot_charges]

func _make_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var pause_input := FoundryPauseInput.new()
	pause_input.toggle_requested.connect(toggle_pause)
	layer.add_child(pause_input)
	_panel = PanelContainer.new()
	_panel.position = Vector2(16, 12)
	_panel.size = Vector2(1248, 168)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.075, 0.94)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_top = 10
	style.content_margin_right = 16
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)
	layer.add_child(_panel)
	var column := VBoxContainer.new()
	_panel.add_child(column)
	_title = _label(column, "关卡工坊 / DEVELOPMENT", 22)
	_detail = _label(column, "", 14)
	_status = _label(column, "", 14)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	_button(buttons, "重试", func() -> void: request(selected))
	_button(buttons, "输入回放", func() -> void: request(selected, true))
	_button(buttons, "暂停", toggle_pause)
	_button(buttons, "返回", leave)
	_button(buttons, "导出评价", export_feedback)
	for item: Array in [["保留", "keep"], ["无聊", "boring"], ["太难", "hard"], ["看不懂", "unclear"], ["手感问题", "control"]]:
		var rating: String = item[1]
		_button(buttons, item[0], func() -> void: rate(rating))
	_button(buttons, "填写反馈", open_feedback)
	_button(buttons, "敌人测试", toggle_enemies)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 3)
	side.position = Vector2(960, 194)
	side.size = Vector2(304, 330)
	layer.add_child(side)
	# PopupMenu/ItemList mouse selection cannot be relied on when the project's
	# touch-to-mouse emulation is disabled. Real Buttons handle touch directly.
	var profiles := HBoxContainer.new()
	side.add_child(profiles)
	var names := ["基础", "二跳", "四发", "钩子"]
	for index: int in FoundryCatalog.profiles().size():
		var profile: Dictionary = FoundryCatalog.profiles()[index]
		var button := _button(profiles, names[index], func() -> void: select_profile(index))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.disabled = not profile.implemented
		button.set_pressed_no_signal(index == _profile_index)
		_profile_buttons.append(button)
	_profile_name = _label(side, FoundryCatalog.profiles()[_profile_index].name, 14)
	_level_scroll = ScrollContainer.new()
	_level_scroll.custom_minimum_size = Vector2(304, 140)
	_level_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(_level_scroll)
	_levels = VBoxContainer.new()
	_levels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level_scroll.add_child(_levels)
	var pages := HBoxContainer.new()
	side.add_child(pages)
	_page_previous = _button(pages, "上一页", func() -> void: show_page(_page - 1))
	_page_previous.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_previous.custom_minimum_size.y = 36
	_page_label = _label(pages, "1 / 1", 16)
	_page_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_page_label.custom_minimum_size.x = 60
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_next = _button(pages, "下一页", func() -> void: show_page(_page + 1))
	_page_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_next.custom_minimum_size.y = 36
	_seed = LineEdit.new()
	_seed.text = "foundry-first-run"
	_seed.max_length = 80
	side.add_child(_seed)
	var actions := HBoxContainer.new()
	side.add_child(actions)
	_button(actions, "三段随机路线", random_itinerary).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var source_scroll := ScrollContainer.new()
	source_scroll.custom_minimum_size = Vector2(304, 140)
	source_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(source_scroll)
	side.move_child(source_scroll, _level_scroll.get_index() + 1)
	source_scroll.hide()
	var sources_column := VBoxContainer.new()
	sources_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_scroll.add_child(sources_column)
	_button(actions, "参考来源", func() -> void:
		_show_sources = not _show_sources
		source_scroll.visible = _show_sources
		_level_scroll.visible = not _show_sources
		show_page(0)
	)
	# Use an inline list for sources too: no modal Window can trap phone input.
	var sources: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/foundry_sources.json"))
	for source: Dictionary in sources.sources:
		var url: String = source.url
		var button := _button(sources_column, source.title, func() -> void: OS.shell_open(url))
		button.clip_text = true
		button.tooltip_text = source.title
		_source_buttons.append(button)
		button.add_theme_font_size_override("font_size", 14)
	show_page(0)
	_feedback_blocker = Control.new()
	_feedback_blocker.size = Vector2(1280, 720)
	_feedback_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(_feedback_blocker)
	_feedback_blocker.hide()
	_feedback_panel = PanelContainer.new()
	_feedback_panel.position = Vector2(240, 220)
	_feedback_panel.size = Vector2(800, 320)
	_feedback_panel.add_theme_stylebox_override("panel", style.duplicate())
	_feedback_blocker.add_child(_feedback_panel)
	_feedback_panel.hide()
	var feedback_column := VBoxContainer.new()
	_feedback_panel.add_child(feedback_column)
	_label(feedback_column, "玩家反馈：描述卡住的位置、想调整的地方或敌人问题", 20)
	_feedback_note = TextEdit.new()
	_feedback_note.custom_minimum_size = Vector2(760, 160)
	_feedback_note.add_theme_font_override("font", preload("res://assets/fonts/foundry_notes.otf"))
	_feedback_note.add_theme_font_size_override("font_size", 20)
	_feedback_note.gui_input.connect(_feedback_note_touch)
	_feedback_note.text_changed.connect(func() -> void:
		if _feedback_note.text.length() > 1000: _feedback_note.text = _feedback_note.text.left(1000)
	)
	feedback_column.add_child(_feedback_note)
	var feedback_actions := HBoxContainer.new()
	feedback_column.add_child(feedback_actions)
	_button(feedback_actions, "保存反馈", save_feedback)
	_button(feedback_actions, "取消", close_feedback)
	_hud = ActorResourcesHud.new()
	_hud.position = Vector2(12, 170)
	layer.add_child(_hud)
	layer.move_child(_feedback_blocker, layer.get_child_count() - 1)

func feedback_bundle() -> Dictionary:
	return {"schema": 2, "game": "gunman-rush", "scope": "foundry", "engine": Engine.get_version_info().string, "exported_at": Time.get_unix_time_from_system(), "records": feedback.duplicate(true)}

func toggle_enemies() -> void:
	if _feedback_panel.visible: return
	enemies_enabled = not enemies_enabled
	request(selected)

func open_feedback() -> void:
	if _closed or selected.is_empty() or not is_instance_valid(controller) or not pending.is_empty(): return
	_feedback_was_paused = get_tree().paused
	_feedback_context = {"id": selected.id}
	controller.router.clear("foundry_feedback")
	controller.air_focus_ability.stop()
	get_tree().paused = true
	_feedback_note.text = ""
	_feedback_blocker.show()
	_feedback_panel.show()
	_feedback_note.grab_focus()

func _feedback_note_touch(event: InputEvent) -> void:
	# Project intentionally disables touch-to-mouse emulation. TextEdit's mouse
	# focus path therefore cannot be relied on to summon a phone keyboard.
	if event is InputEventScreenTouch and event.pressed:
		_feedback_note.grab_focus()
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			var rectangle := get_viewport().get_screen_transform() * _feedback_note.get_global_rect()
			DisplayServer.virtual_keyboard_show(_feedback_note.text, rectangle, DisplayServer.KEYBOARD_TYPE_MULTILINE, 1000)
		_feedback_note.accept_event()

func save_feedback() -> void:
	if not _feedback_panel.visible or _feedback_context.get("id") != selected.get("id"): return
	if rate("note", _feedback_note.text): close_feedback()

func close_feedback() -> void:
	_feedback_panel.hide()
	_feedback_blocker.hide()
	_feedback_note.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide()
	_feedback_context.clear()
	controller.router.clear("foundry_feedback_close")
	get_tree().paused = _feedback_was_paused

func show_page(index: int) -> void:
	var buttons: Array[Button] = _source_buttons if _show_sources else _level_buttons
	var per_page := 2 if _show_sources else 3
	var count := maxi(1, ceili(float(buttons.size()) / per_page))
	_page = clampi(index, 0, count - 1)
	for i: int in buttons.size(): buttons[i].visible = i / per_page == _page
	_page_label.text = "%d / %d" % [_page + 1, count]
	_page_previous.disabled = _page == 0
	_page_next.disabled = _page == count - 1

func select_profile(index: int) -> void:
	var profiles := FoundryCatalog.profiles()
	if _closed or index < 0 or index >= profiles.size() or not profiles[index].implemented or _feedback_panel.visible: return
	_profile_index = index
	for i: int in _profile_buttons.size():
		_profile_buttons[i].set_pressed_no_signal(i == index)
	_profile_name.text = profiles[index].name
	_refresh_entries()
	if not entries.is_empty(): choose(0)

func _label(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 18)
	button.custom_minimum_size.y = 44
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
