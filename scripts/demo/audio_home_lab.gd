class_name AudioHomeLab
extends DemoApp
## Developer audition of the unchanged formal Home, with memory-only Meta.
const HOME_MODES := {"original":"原版", "bed":"平静底声", "life":"底声＋稀疏生活音"}
var home_lab_mode := "life"
var home_lab_ready := false
var home_lab_capture := false
var home_lab_audio: GameAudio
var home_audition: Node
var _home_audio_title: Label
var _home_audio_phase: Label

func _ready() -> void:
	meta_persistence_enabled = false
	set_meta("cloud_preview_host", true)
	super._ready()
	home_lab_audio = GameAudio.for_origin(self) as GameAudio
	# Invoke the original title action, which creates the real HomeScene with
	# its original player, input, resources, camera, service slots and music.
	menu._start_title_adventure()
	if not is_instance_valid(home_scene) or home_lab_audio == null:
		push_error("AUDIO_HOME_LAB original Home did not start")
		return
	var adapter_script := load("res://scripts/audio/home_ambience_audition.gd") as Script
	if adapter_script == null:
		push_error("AUDIO_HOME_LAB missing explicit Home audition adapter")
		return
	home_audition = adapter_script.new()
	add_child(home_audition)
	if not bool(home_audition.call("configure", home_scene, home_lab_audio, home_lab_mode)):
		push_error("AUDIO_HOME_LAB rejected Home candidate configuration")
		return
	_make_home_audio_controls()
	home_lab_ready = true

func _make_home_audio_controls() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 118
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_home_audio_title = _home_audio_label(Vector2(28, 94), 18, layer)
	_home_audio_phase = _home_audio_label(Vector2(28, 122), 15, layer)
	_home_audio_phase.text = "真实家园地面行走 · 静态NPC所在地拟音，非敲打动画同步"
	if not home_lab_capture:
		var row := HBoxContainer.new()
		row.position = Vector2(400, 158)
		layer.add_child(row)
		for mode: String in HOME_MODES:
			var button := Button.new()
			button.text = HOME_MODES[mode]
			button.custom_minimum_size = Vector2(100, 40)
			button.focus_mode = Control.FOCUS_NONE
			button.set_meta("audio_skip_click", true)
			button.pressed.connect(func() -> void: set_home_audio_mode(mode))
			row.add_child(button)
	_update_home_audio_title()

func _home_audio_label(at: Vector2, font_size: int, parent: Node) -> Label:
	var label := Label.new()
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UnderworldUI.FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_constant_override("outline_size", 3)
	parent.add_child(label)
	return label

func set_home_audio_mode(mode: String) -> bool:
	if not HOME_MODES.has(mode) or not is_instance_valid(home_audition): return false
	if not bool(home_audition.call("set_mode", mode)): return false
	home_lab_mode = mode
	if is_instance_valid(home_scene): home_scene.controller.router.clear("home_audio_mode")
	_update_home_audio_title()
	return true

func set_home_audio_phase(text: String) -> void:
	if is_instance_valid(_home_audio_phase): _home_audio_phase.text = text

func _update_home_audio_title() -> void:
	if is_instance_valid(_home_audio_title):
		_home_audio_title.text = "家园声音 · %s · 原BGM保持 / 音色待试听" % HOME_MODES[home_lab_mode]

func home_audio_snapshot() -> Dictionary:
	var voices: Array[Dictionary] = []
	for voice: AudioStreamPlayer in _music._voices:
		voices.append({"playing":voice.playing,"paused":voice.stream_paused,"path":voice.stream.resource_path if voice.stream != null else "","volume_db":voice.volume_db,"playback_position":voice.get_playback_position()})
	return {"mode":home_lab_mode,"audition":home_audition.call("snapshot"),"music_track":String(_music.requested_track),"music_voices":voices,"music_gain":GameMusic.MUSIC_GAIN,"session_volume":home_lab_audio.volume,"home_input_blocked":home_scene.input_blocked if is_instance_valid(home_scene) else true,"meta_persistence_enabled":meta_persistence_enabled}

func _exit_tree() -> void:
	if is_instance_valid(home_audition): home_audition.call("stop")
