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
var _list: ItemList
var _profile: OptionButton
var _seed: LineEdit
var _hud: ActorResourcesHud
var _panel: PanelContainer
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
	_list.clear()
	var profile_id := _profile.get_item_metadata(_profile.selected) as String
	for entry: Dictionary in batch.get("accepted", []):
		if entry.manifest.capability_profile != profile_id: continue
		entries.append(entry)
		var t := FoundryCatalog.template(entry.manifest.template_id)
		_list.add_item("%s · V%d / P%d" % [t.name, entry.manifest.variant + 1, entry.manifest.phase_index])
	_status.text = "%d 段已通过真实轨迹与输入回放；趣味性待试玩。" % entries.size() if not entries.is_empty() else "没有该能力配置的有效批次。运行 python3 tools/foundry.py build --promote。"

func choose(index: int, replay: bool = false) -> void:
	if _closed or index < 0 or index >= entries.size(): return
	selected = entries[index].manifest.duplicate(true)
	_list.select(index)
	request(selected, replay)

func request(manifest: Dictionary, replay: bool = false) -> bool:
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
	var profile_id := _profile.get_item_metadata(_profile.selected) as String
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
		JavaScriptBridge.download_buffer(JSON.stringify(feedback, "  ").to_utf8_buffer(), "foundry-feedback.json", "application/json")
	else:
		_status.text = "评价文件：" + ProjectSettings.globalize_path("user://foundry_feedback.json")

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

func rate(rating: String) -> bool:
	if selected.is_empty() or not rating in ["keep", "boring", "hard", "unclear", "control"]: return false
	feedback.append({"id": selected.id, "template_id": selected.get("template_id", "itinerary"), "rating": rating, "basis": selected.basis, "profile": selected.capability_profile, "completed": finished, "seconds": elapsed, "timestamp": Time.get_unix_time_from_system()})
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
		if not vote is Dictionary or vote.get("rating") not in ["keep", "boring", "hard", "unclear", "control"]: continue
		var valid := true
		for key: String in ["id", "template_id", "basis", "profile"]:
			if not vote.get(key) is String or vote[key].length() > 150: valid = false
		if valid: result.append(vote)
	return result

func toggle_pause() -> void:
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
	var side := VBoxContainer.new()
	side.position = Vector2(1010, 194)
	side.size = Vector2(254, 330)
	layer.add_child(side)
	_profile = OptionButton.new()
	_profile.add_theme_font_override("font", FONT)
	for profile: Dictionary in FoundryCatalog.profiles():
		_profile.add_item(profile.name)
		_profile.set_item_metadata(_profile.item_count - 1, profile.id)
		_profile.set_item_disabled(_profile.item_count - 1, not profile.implemented)
	side.add_child(_profile)
	_profile.item_selected.connect(func(_i: int) -> void:
		_refresh_entries()
		if not entries.is_empty(): choose(0)
	)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(254, 200)
	_list.add_theme_font_override("font", FONT)
	_list.add_theme_font_size_override("font_size", 14)
	_list.item_selected.connect(choose)
	side.add_child(_list)
	_seed = LineEdit.new()
	_seed.text = "foundry-first-run"
	_seed.max_length = 80
	side.add_child(_seed)
	_button(side, "三段随机路线", random_itinerary)
	var reference := MenuButton.new()
	reference.text = "参考来源 / 在线视频"
	reference.add_theme_font_override("font", FONT)
	side.add_child(reference)
	var sources: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/foundry_sources.json"))
	for source: Dictionary in sources.sources: reference.get_popup().add_item(source.title)
	reference.get_popup().id_pressed.connect(func(index: int) -> void: OS.shell_open(sources.sources[index].url))
	_hud = ActorResourcesHud.new()
	_hud.position = Vector2(12, 170)
	layer.add_child(_hud)

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
	button.add_theme_font_size_override("font_size", 15)
	button.custom_minimum_size.y = 34
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
