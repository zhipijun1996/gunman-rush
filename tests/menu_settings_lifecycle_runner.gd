extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var app := preload("res://scenes/demo/demo.tscn").instantiate() as DemoApp
	app.meta_persistence_enabled = false
	root.add_child(app)
	var audio := app.get_tree().get_first_node_in_group(&"game_audio") as GameAudio
	var menu := app.menu
	var defaults: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/input_profile.json"))
	check(JSON.parse_string(JSON.stringify(menu._values)) == defaults and JSON.parse_string(JSON.stringify(menu._defaults)) == defaults, "Menu loads the actual default input resource")
	menu.show_settings()
	var applied: Array[Dictionary] = []
	menu.settings_changed.connect(func(values: Dictionary) -> void:applied.append(values))
	var before := menu._values.duplicate(true)
	(menu._sliders.right_exit_deadzone as HSlider).value = .6
	(menu._sliders.right_enter_deadzone as HSlider).value = .2
	menu._apply_settings()
	check(applied.is_empty() and menu._values == before and menu._settings_error.text.contains("lower"), "Actual InputProfile rejects invalid settings atomically")
	(menu._sliders.right_exit_deadzone as HSlider).value = .1
	(menu._sliders.right_enter_deadzone as HSlider).value = .4
	menu._apply_settings()
	check(applied.size() == 1 and is_equal_approx(menu._values.right_exit_deadzone, .1) and is_equal_approx(menu._values.right_enter_deadzone, .4), "Actual InputProfile accepts and emits the legal settings patch")
	var volume_slider: HSlider
	for slider: Node in menu._content.find_children("*", "HSlider", true, false):
		if is_equal_approx((slider as HSlider).max_value, 1.0):volume_slider = slider
	check(volume_slider != null, "Actual settings panel exposes the volume slider")
	check(audio.play(&"bell"), "Real audio service starts an owned voice")
	volume_slider.value = .25
	check(is_equal_approx(audio.volume, .25) and is_equal_approx(menu._audio_volume, .25), "Actual slider updates the real audio volume setter")
	check(is_equal_approx(audio._voices[0].volume_db, linear_to_db(.25) - 7.0), "Existing playing voice receives the updated attenuation")
	audio.volume = 2.0
	check(audio.volume == 1.0, "Real audio setter keeps its upper clamp")
	audio.volume = -1.0
	check(audio.volume == 0.0, "Real audio setter keeps its lower clamp")
	var theme := preload("res://scripts/ui/menu_theme.gd").create_theme()
	var original := DemoMenu.create_theme()
	check(theme.default_font is FontVariation and original.default_font is FontVariation, "Leaf and public menu themes retain font variations")
	var font := theme.default_font as FontVariation
	check(font.base_font == ThemeDB.fallback_font and font.fallbacks == [preload("res://assets/fonts/foundry_notes.otf")], "Leaf keeps the exact original base font and fallback")
	check(theme.default_font_size == original.default_font_size and theme.get_color("font_color", "Label") == original.get_color("font_color", "Label"), "Leaf and public menu themes preserve font size and styling")
	check(await audio.shutdown(), "Real audio playback releases before teardown")
	if not await load("res://tests/audio_teardown.gd").drain_world(app):
		failures += 1;push_error("TEST AUDIO TEARDOWN: playback did not release within 1000ms");quit(1);return
	var app_ref: WeakRef = weakref(app)
	var menu_ref: WeakRef = weakref(menu)
	var audio_ref: WeakRef = weakref(audio)
	app.queue_free()
	for attempt: int in 8:
		if menu_ref.get_ref() == null and audio_ref.get_ref() == null:break
		await process_frame
	check(app_ref.get_ref() == null and menu_ref.get_ref() == null and audio_ref.get_ref() == null, "Actual App releases its Menu and audio owners")
	print("MENU SETTINGS LIFECYCLE: %s assertions, %s failures" % [checks, failures])
	quit.call_deferred(0 if failures == 0 else 1)
