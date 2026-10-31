class_name AudioDirectorLab
extends DemoApp
## Audio-only comparison on the current formal Home/Plains/Forest consumers.
## This scene never manufactures accepted hits, movement, rewards or hook phases.
const REVIEW_SEED := "audio-director-v1/listen-01"
const PROFILE_NAMES := {"original": "原版", "A": "A · 木芯钟簧", "B": "B · 轻盈魔法"}
var lab_audio: PlayerWeaponFeelAudioV2
var lab_profile := "A"
var lab_route := "home"
var lab_transitions: Array[Dictionary] = []
var _lab_panel: PanelContainer
var _lab_status: Label
var _lab_hint: Label
var _lab_routes: HFlowContainer
var _lab_buttons: Dictionary = {}
var _lab_route_pending := false
var _lab_compact := false

func _ready() -> void:
	meta_persistence_enabled = false
	set_meta("cloud_preview_host", true)
	# A custom preview bootstrap offers an empty generic service. This formal
	# DemoApp owns its richer inherited service; remove the empty one before
	# PlayerPresentationRuntime resolves the first game_audio group member.
	var host := get_parent()
	if host != null and host.has_method("open_test_scene") and host.has_method("return_to_menu"):
		var offered := host.get("custom_audio") as GameAudio
		if is_instance_valid(offered):
			host.remove_child(offered)
			offered.free()
			host.set("custom_audio", null)
	super._ready()
	for child: Node in get_children():
		if child is PlayerWeaponFeelAudioV2:
			lab_audio = child as PlayerWeaponFeelAudioV2
			break
	if lab_audio == null:
		push_error("Audio Director Lab requires the current formal audio service")
		return
	if OS.has_feature("web"):
		var requested: Variant = JavaScriptBridge.eval("new URLSearchParams(location.search).get('audio_profile') || 'A'")
		if str(requested) in PROFILE_NAMES: lab_profile = str(requested)
	_make_lab_ui()
	set_lab_profile(lab_profile)
	open_lab_route.call_deferred("home")

func _make_lab_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 118
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_lab_panel = PanelContainer.new()
	_lab_panel.name = "AudioDirectorControls"
	_lab_panel.theme = DemoMenu.create_theme()
	layer.add_child(_lab_panel)
	var margin := MarginContainer.new()
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 8)
	_lab_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	_lab_status = Label.new()
	_lab_status.add_theme_font_size_override("font_size", 16)
	_lab_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lab_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_lab_status)
	var profiles := HFlowContainer.new()
	profiles.add_theme_constant_override("separation", 6)
	box.add_child(profiles)
	for profile: String in ["original", "A", "B"]:
		var button := _lab_button(PROFILE_NAMES[profile], profiles)
		button.toggle_mode = true
		button.pressed.connect(func() -> void: set_lab_profile(profile))
		_lab_buttons[profile] = button
	var compact := _lab_button("收起", profiles)
	compact.pressed.connect(func() -> void:
		_lab_compact = not _lab_compact
		compact.text = "展开" if _lab_compact else "收起"
		_lab_routes.visible = not _lab_compact
		_lab_hint.visible = not _lab_compact
		_lab_panel.reset_size())
	_lab_routes = HFlowContainer.new()
	_lab_routes.add_theme_constant_override("h_separation", 6)
	box.add_child(_lab_routes)
	for route: String in ["home", "plains", "forest"]:
		var label := {"home": "家园动作", "plains": "平原战斗", "forest": "森林钩索"}[route] as String
		var button := _lab_button(label, _lab_routes)
		button.pressed.connect(func() -> void: open_lab_route(route))
	var full_game := _lab_button("完整游戏 / 菜单", _lab_routes)
	full_game.pressed.connect(return_lab_full_game)
	_lab_hint = Label.new()
	_lab_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lab_hint.add_theme_font_size_override("font_size", 14)
	_lab_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_lab_hint)
	get_viewport().size_changed.connect(_layout_lab_ui)
	_layout_lab_ui()

func _lab_button(label: String, parent: Node) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(100, 42)
	button.add_theme_font_size_override("font_size", 16)
	button.button_down.connect(_clear_lab_input)
	parent.add_child(button)
	return button

func _layout_lab_ui() -> void:
	if not is_instance_valid(_lab_panel): return
	var viewport_size := get_viewport_rect().size
	var width := minf(660.0, maxf(300.0, viewport_size.x - 24.0))
	_lab_panel.position = Vector2(maxf(12.0, (viewport_size.x - width) * 0.5), 76.0)
	_lab_panel.size.x = width
	_lab_hint.custom_minimum_size.x = width - 16.0

func _clear_lab_input() -> void:
	if is_instance_valid(controller): controller.router.clear("audio_lab_control")
	if is_instance_valid(home_scene): home_scene.controller.router.clear("audio_lab_control")

func set_lab_profile(profile: String) -> void:
	if not PROFILE_NAMES.has(profile) or not is_instance_valid(lab_audio): return
	_clear_lab_input()
	if not lab_audio.set_audio_profile(profile):
		push_error("Audio Director Lab cannot load requested profile: " + profile)
		return
	lab_profile = profile
	for key: String in _lab_buttons:
		(_lab_buttons[key] as Button).set_pressed_no_signal(key == profile)
	_update_lab_text()
	print("AUDIO_DIRECTOR_LAB " + JSON.stringify({"event": "profile", "profile": profile, "seed": REVIEW_SEED, "user_acceptance": "unverified"}))

func open_lab_route(route: String) -> void:
	if route not in ["home", "plains", "forest"] or _lab_route_pending: return
	_lab_route_pending = true
	_clear_lab_input()
	if get_tree().paused: get_tree().paused = false
	abandon_run()
	for unused: int in 180:
		if director.state == DemoRunDirector.State.HOME and not _stage_pending: break
		await get_tree().physics_frame
	if director.state != DemoRunDirector.State.HOME or _stage_pending:
		_lab_route_pending = false
		push_error("Audio Director Lab could not return to Home before route change")
		return
	_show_home()
	lab_route = route
	var accepted := true
	if route == "plains": accepted = start_plains(REVIEW_SEED)
	elif route == "forest":
		# Existing explicit development route provides the region's legal
		# capability snapshot. This is not a natural progression completion.
		accepted = start_debug_region(&"thorn_forest", 1, REVIEW_SEED)
	lab_transitions.append({"route": route, "accepted": accepted, "profile": lab_profile, "seed": REVIEW_SEED, "natural_progression": route != "forest"})
	if lab_transitions.size() > 32: lab_transitions.pop_front()
	_lab_route_pending = false
	_update_lab_text()
	print("AUDIO_DIRECTOR_LAB " + JSON.stringify(lab_transitions.back()))

func _update_lab_text() -> void:
	if not is_instance_valid(_lab_status): return
	_lab_status.text = "SOUND LAB · %s · 开发候选 / 听感待你确认" % PROFILE_NAMES[lab_profile]
	var instructions := "正式家园：移动、跳跃、落地、射击反冲。键鼠 / 触屏沿用游戏操作。"
	if lab_route == "plains": instructions = "正式平原：实际战斗、命中、受伤与拾取；切换音色不重置世界。"
	elif lab_route == "forest": instructions = "正式森林开发入口：实际钩索释放、连接与牵引；此入口不是自然解锁证明。"
	_lab_hint.text = instructions + " 五首原 BGM 保留；可在同一动作中切换原版 / A / B。"

func return_lab_full_game() -> void:
	_clear_lab_input()
	if get_tree().paused: get_tree().paused = false
	var host := get_parent()
	if host != null and host.has_method("return_to_menu"):
		host.call_deferred("return_to_menu")
		return
	# Direct native launches also keep the full game within this isolated,
	# persistence-disabled app. Returning does not write the normal game's save.
	set_lab_profile("original")
	_lab_panel.hide()
	await open_lab_route("home")
	menu.show_title()
