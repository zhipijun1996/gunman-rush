class_name AudioAmbienceLab
extends DemoApp
## Explicit audition on unchanged formal generated regions. No save writes.
const REVIEW_SEED := "audio-ambience-01/field-listen"
const MANIFEST := "res://assets/audio/ambience_v1/manifest.json"
const PROFILE_NAMES := {"original": "原版", "A": "候选 A", "B": "候选 B"}
var lab_audio: GameAudio
var lab_profile := "original"
var lab_region := "plains"
var lab_ready := false
var environment_only := false
var transport_busy := false
var capture_mode := false
var _ambience_toolbar: PanelContainer
var _ambience_status_label: Label
var _ambience_phase_label: Label
var _ambience_death_controller: WeakRef
var _ambience_death_callback: Callable

func _ready() -> void:
	meta_persistence_enabled = false
	set_meta("cloud_preview_host", true)
	super._ready()
	lab_audio = get_tree().get_first_node_in_group(&"game_audio") as GameAudio
	if lab_audio == null or not lab_audio.configure_ambience(MANIFEST):
		push_error("AUDIO_AMBIENCE_LAB manifest unavailable")
		return
	_make_lab_controls()
	lab_ready = true
	if not capture_mode: open_region.call_deferred("plains")

func _make_lab_controls() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 118
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	if capture_mode:
		# Recording keeps the entire action area visible. Container minimum
		# sizes are not used for these two fixed, short observer captions.
		_ambience_status_label = _capture_label(Vector2(28, 94), 18, layer)
		_ambience_phase_label = _capture_label(Vector2(28, 122), 15, layer)
		_update_status()
		return
	_ambience_toolbar = PanelContainer.new()
	_ambience_toolbar.theme = DemoMenu.create_theme()
	layer.add_child(_ambience_toolbar)
	var box := VBoxContainer.new()
	_ambience_toolbar.add_child(box)
	_ambience_status_label = Label.new()
	_ambience_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_ambience_status_label)
	var controls := HFlowContainer.new()
	box.add_child(controls)
	for profile: String in ["original", "A", "B"]:
		_ambience_button(PROFILE_NAMES[profile], controls).pressed.connect(func() -> void: set_lab_profile(profile))
	_ambience_button("风铃平原", controls).pressed.connect(func() -> void: open_region("plains"))
	_ambience_button("荆棘森林", controls).pressed.connect(func() -> void: open_region("forest"))
	_ambience_button("BGM 开 / 关", controls).pressed.connect(func() -> void:
		environment_only = not environment_only
		_sync_music()
		_update_status())
	_ambience_button("完整游戏", controls).pressed.connect(return_full_game)
	_ambience_phase_label = Label.new()
	_ambience_phase_label.text = "开发试听：正式地图与动作；森林使用开发入口，存档关闭。"
	_ambience_phase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_ambience_phase_label)
	get_viewport().size_changed.connect(_layout_lab)
	_layout_lab()
	_update_status()

func _capture_label(at: Vector2, font_size: int, parent: Node) -> Label:
	var label := Label.new()
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_constant_override("outline_size", 3)
	parent.add_child(label)
	return label

func _ambience_button(text: String, parent: Node) -> Button:
	var result := Button.new()
	result.text = text
	result.focus_mode = Control.FOCUS_NONE
	result.custom_minimum_size = Vector2(94, 40)
	result.set_meta("audio_skip_click", true)
	result.button_down.connect(_clear_lab_input)
	parent.add_child(result)
	return result

func _layout_lab() -> void:
	if not is_instance_valid(_ambience_toolbar): return
	var width := minf(770.0, get_viewport_rect().size.x - 24.0)
	_ambience_toolbar.position = Vector2(maxf(12.0, (get_viewport_rect().size.x - width) * 0.5), 77)
	_ambience_toolbar.size = Vector2(width, 0)
	_ambience_status_label.custom_minimum_size.x = width - 20.0
	_ambience_phase_label.custom_minimum_size.x = width - 20.0
	_settle_lab_toolbar.call_deferred(width)

func _settle_lab_toolbar(width: float) -> void:
	if not is_instance_valid(_ambience_toolbar): return
	# Give HFlow/VBox their real parent width, then discard the old minimum
	# height that was calculated while the newly created container was tiny.
	await get_tree().process_frame
	if not is_instance_valid(_ambience_toolbar): return
	_ambience_toolbar.reset_size()
	_ambience_toolbar.size = Vector2(width, 0)

func _clear_lab_input() -> void:
	if is_instance_valid(controller): controller.router.clear("ambience_lab_control")
	if is_instance_valid(home_scene): home_scene.controller.router.clear("ambience_lab_control")

func set_lab_profile(profile: String) -> bool:
	if profile not in PROFILE_NAMES or not is_instance_valid(lab_audio): return false
	if not is_instance_valid(stage) or not is_instance_valid(player):
		lab_profile = profile
		return true
	if not lab_audio.set_ambience_region(lab_region, profile, stage, player): return false
	_bind_actual_death()
	lab_profile = profile
	_update_status()
	return true

func _bind_actual_death() -> void:
	var prior := _ambience_death_controller.get_ref() as PlayerController if _ambience_death_controller != null else null
	if prior == controller and _ambience_death_callback.is_valid(): return
	_disconnect_actual_death()
	if not is_instance_valid(controller): return
	_ambience_death_controller = weakref(controller)
	var expected := _ambience_death_controller
	_ambience_death_callback = func() -> void:
		# PlayerMotor is the spatial listener; accepted death belongs to its
		# actual Controller. An old route must not clear a new route's bed.
		if is_instance_valid(controller) and expected.get_ref() == controller:
			lab_audio.clear_ambience()
	controller.died.connect(_ambience_death_callback)

func _disconnect_actual_death() -> void:
	var prior := _ambience_death_controller.get_ref() as PlayerController if _ambience_death_controller != null else null
	if is_instance_valid(prior) and _ambience_death_callback.is_valid() and prior.died.is_connected(_ambience_death_callback):
		prior.died.disconnect(_ambience_death_callback)
	_ambience_death_controller = null
	_ambience_death_callback = Callable()

func open_region(region: String) -> bool:
	if region not in ["plains", "forest"] or transport_busy or not lab_ready: return false
	transport_busy = true
	_clear_lab_input()
	get_tree().paused = false
	lab_audio.clear_ambience()
	_disconnect_actual_death()
	if director.state != DemoRunDirector.State.HOME: abandon_run()
	for unused: int in 180:
		if director.state == DemoRunDirector.State.HOME and not _stage_pending: break
		await get_tree().physics_frame
	_show_home()
	lab_region = region
	var accepted := start_plains(REVIEW_SEED) if region == "plains" else start_debug_region(&"thorn_forest", 1, REVIEW_SEED)
	if accepted:
		for unused: int in 360:
			await get_tree().physics_frame
			if is_instance_valid(stage) and not _stage_pending and is_instance_valid(player): break
		accepted = is_instance_valid(stage) and not _stage_pending and is_instance_valid(player)
	if accepted: accepted = set_lab_profile(lab_profile)
	transport_busy = false
	_update_status()
	return accepted

func _sync_music() -> void:
	if environment_only and is_instance_valid(_music):
		_music.request_track(&"")
		_music.set_menu_paused(get_tree().paused)
	else: super._sync_music()

func _update_status() -> void:
	if not is_instance_valid(_ambience_status_label): return
	_ambience_status_label.text = "环境音工坊 · %s · %s · %s" % ["风铃平原" if lab_region == "plains" else "荆棘森林", PROFILE_NAMES[lab_profile], "环境单听（BGM 关闭）" if environment_only else "原 BGM 混音"]
	if is_instance_valid(_ambience_toolbar): _layout_lab()

func set_capture_phase(text: String) -> void:
	_ambience_phase_label.text = text

func return_full_game() -> void:
	_clear_lab_input()
	get_tree().paused = false
	lab_audio.clear_ambience()
	_disconnect_actual_death()
	environment_only = false
	lab_profile = "original"
	abandon_run()
	_ambience_toolbar.hide()
	_show_home()
	menu.show_title()

func _exit_tree() -> void:
	_disconnect_actual_death()
