class_name DemoMenu
extends CanvasLayer
## Presentation-only menus. The app owns pausing, routing and session input updates.

signal requested_enter_home
signal home_panel_closed
signal requested_start(seed: String, formal_ten: bool)
signal requested_plains(seed: String)
signal requested_upgrade
signal requested_lab
signal requested_random(seed: String)
signal requested_resume
signal requested_home
signal settings_changed(values: Dictionary)
signal menu_opened

const INK := Color("231e21")
const CARD := Color("efe1c6")
const TEAL := Color("2b7067")
const GOLD := Color("967035")
const TEXT := Color("3a2d28")
const MUTED := Color("695247")

var visible_panel: StringName = &""
var _root: Control
var _content: VBoxContainer
var _in_run := false
var _home_overlay := false
var _summary := ""
var _meta_state: Dictionary = {}
var _build := ""
var _seed := "rush-demo"
var _values: Dictionary = {}
var _defaults: Dictionary = {}
var _sliders: Dictionary = {}
var _settings_error: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	var profile := InputProfile.load_default()
	if profile != null:
		_defaults = profile.values.duplicate(true)
		_values = _defaults.duplicate(true)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = _make_theme()
	add_child(_root)
	_root.hide()

func set_input_values(values: Dictionary) -> void:
	_values = values.duplicate(true)

func set_meta_state(snapshot: Dictionary) -> void:
	_meta_state = snapshot.duplicate(true)

func show_title() -> void:
	_home_overlay = false
	_begin(&"title", false)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/title_home/title_logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(400, 170)
	_content.add_child(logo)
	_title("GUNMAN RUSH", "A painted world. A shot that carries you forward.")
	_button(_content, "ENTER HOME", func() -> void:
		_hide()
		requested_enter_home.emit())
	_button(_content, "DEVELOPMENT DEMOS / ALL ENTRIES", func() -> void: show_home(_summary))
	_button(_content, "SETTINGS", func() -> void: show_settings(false))
	_button(_content, "HOW TO PLAY", func() -> void: show_help(false))
	_focus_first()

func show_home_navigation(summary: String = "") -> void:
	_home_overlay = true
	show_home(summary)

func show_home_panel(function_id: StringName) -> void:
	_home_overlay = true
	_begin(&"home_function", false)
	match function_id:
		&"upgrade":
			_title("Clockwork artisan", "Spend permanent NOTES. Run coins stay inside the adventure.")
			_upgrade_controls(_content)
		&"departure":
			_title("The plains await", "A fresh run with your permanent upgrades. Ten independently generated rooms.")
			_button(_content, "BEGIN / WINDCHIME PLAINS", func() -> void:
				_hide()
				requested_plains.emit(_seed.strip_edges() if not _seed.strip_edges().is_empty() else "plains-run"))
		&"character":
			_title("Wardrobe keeper", "Character selection is in development.")
			_label(_content, "Current playable character: Courier. Additional characters and their unlock conditions are not implemented.", 20, TEXT)
		&"achievements":
			_title("Records keeper", "Achievement service is in development.")
			_label(_content, "No achievement rewards are granted by opening this panel. Future progress and unlock rules remain undecided.", 20, TEXT)
		_:
			_title("Home", "This service is not available.")
	_button(_content, "BACK TO HOME", _close_home_overlay)
	_focus_first()

func _upgrade_controls(parent: Node) -> void:
	var quote: Dictionary = _meta_state.get("upgrade_quote", {"level": 0, "max_level": 3, "price": 5, "available": true})
	_label(parent, "NOTES %s / Permanent vitality %s of %s" % [_meta_state.get("notes", 0), quote.level, quote.max_level], 20, TEXT)
	_label(parent, "DEMO BALANCE / +1 max HP each level / price 5, 10, 15 notes", 15, MUTED)
	var submitted := [false]
	var upgrade := _button(parent, "PERMANENT VITALITY / Spend notes %s / +1 HP" % quote.price if quote.available else "PERMANENT VITALITY / MAX LEVEL", func() -> void:
		if not submitted[0]:
			submitted[0] = true
			requested_upgrade.emit())
	upgrade.disabled = not quote.available or int(_meta_state.get("notes", 0)) < int(quote.price)

func _close_home_overlay() -> void:
	_hide()
	_home_overlay = false
	home_panel_closed.emit()

func show_home(summary: String = "") -> void:
	_summary = summary
	_in_run = false
	_begin(&"home", false)
	var shell := HBoxContainer.new()
	shell.add_theme_constant_override("separation", 30)
	_content.add_child(shell)
	var rail := VBoxContainer.new()
	rail.custom_minimum_size.x = 160
	rail.add_theme_constant_override("separation", 12)
	shell.add_child(rail)
	_label(rail, "GUNMAN\nRUSH", 30, TEXT)
	_label(rail, "AIM • RELEASE • RISE", 12, TEAL)
	_space(rail, 24)
	_button(rail, "HOME", func() -> void:
		if _home_overlay:
			_close_home_overlay()
		else:
			_hide()
			requested_enter_home.emit())
	_button(rail, "SETTINGS", func() -> void: show_settings(false))
	_button(rail, "HOW TO PLAY", func() -> void: show_help(false))
	_button(rail, "MODULE LAB", func() -> void:
		_hide()
		requested_lab.emit())
	_button(rail, "RANDOM STAGE", func() -> void:
		_hide()
		requested_random.emit(_seed.strip_edges() if not _seed.strip_edges().is_empty() else "rush-preview"))
	_space(rail, 18)
	_label(rail, "PLAYABLE DEMO", 12, GOLD)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	shell.add_child(body)
	_label(body, "Choose your next run", 30, TEXT)
	_label(body, "Precise jumps. Powerful recoil. Your own route.", 16, MUTED)
	_label(body, "PLAINS / RANDOMIZED RUN", 12, GOLD)
	_button(body, "8 rooms   /   Windchime Plains", func() -> void:
		_hide()
		requested_plains.emit(_seed.strip_edges() if not _seed.strip_edges().is_empty() else "plains-run"))
	_upgrade_controls(body)
	_label(body, "QUICK DEMO", 12, TEAL)
	_button(body, "3 rooms   /   A quick taste", func() -> void: _start(false))
	_label(body, "BIOME TRIAL", 12, GOLD)
	_button(body, "8 rooms   /   The full route", func() -> void: _start(true))
	_label(body, "RUN SEED", 12, MUTED)
	var seed_edit := LineEdit.new()
	seed_edit.text = _seed
	seed_edit.placeholder_text = "Choose a seed"
	seed_edit.max_length = 80
	seed_edit.custom_minimum_size.y = 46
	seed_edit.text_changed.connect(func(value: String) -> void: _seed = value)
	body.add_child(seed_edit)
	if not _summary.is_empty():
		_label(body, _summary, 15, MUTED)
	_focus_first()

func hide_home() -> void:
	_hide()

func show_pause(build_description: String = "") -> void:
	_build = build_description
	_begin(&"pause", true)
	_title("Run paused", "Take a breath. Your run is waiting.")
	_button(_content, "RESUME", close_panel)
	_button(_content, "SETTINGS", func() -> void: show_settings(true))
	_button(_content, "CONTROLS", func() -> void: show_help(true))
	_button(_content, "YOUR BUILD", func() -> void: show_build(_build))
	_button(_content, "RETURN TO HOME", _confirm_home)
	_focus_first()

func show_settings(in_run: bool = false) -> void:
	_begin(&"settings", in_run)
	_title("Input settings", "Tune your sticks. Changes apply when you choose Apply.")
	_sliders.clear()
	_slider("left_sensitivity", "Movement sensitivity", 0.25, 2.0, 0.05)
	_slider("right_sensitivity", "Aim sensitivity", 0.25, 2.0, 0.05)
	_slider("touch_deadzone", "Touch deadzone", 0.0, 0.45, 0.01)
	_slider("right_enter_deadzone", "Gamepad aim threshold", 0.05, 0.8, 0.01)
	_slider("right_exit_deadzone", "Gamepad center threshold", 0.0, 0.75, 0.01)
	_settings_error = _label(_content, "", 14, GOLD)
	_button(_content, "APPLY", _apply_settings)
	_button(_content, "RESTORE DEFAULTS", _restore_defaults)
	_button(_content, "BACK", _back)
	_focus_first()

func show_help(in_run: bool = false) -> void:
	_begin(&"help", in_run)
	_title("Make every shot a move", "Aim toward danger. Recoil carries you the other way.")
	_label(_content, "TOUCH\nTouch anywhere on the left to move. Touch and drag on the right to aim; release to fire. JUMP is on the far right: tap for a small hop, hold for height.", 18, TEXT)
	_label(_content, "KEYBOARD + MOUSE\nA / D or arrows move. Space jumps. Aim with the mouse; release the left mouse button to fire. W / Up interacts.", 18, TEXT)
	_label(_content, "GAMEPAD\nLeft stick moves. A jumps. Aim with the right stick and return it to center to fire. Tilt the left stick up to interact.", 18, TEXT)
	_label(_content, "AIR FOCUS\nAim in the air to slow time. The focus bar recovers on the ground. Shoot downward for a fast upward burst.", 18, GOLD)
	_label(_content, "Pick an exit to choose the next room. Hazards cost health and return you to a safe segment start. Zero health ends the run.", 16, MUTED)
	_button(_content, "BACK", _back)
	_focus_first()

func show_build(text: String) -> void:
	_build = text
	_begin(&"build", true)
	_title("Your build", "Every pickup shapes this run.")
	_label(_content, text if not text.is_empty() else "No items yet. Explore a reward room to find your first upgrade.", 20, TEXT)
	_button(_content, "BACK", _back)
	_focus_first()

func close_panel() -> void:
	if _in_run:
		_hide()
		requested_resume.emit()
	elif _home_overlay:
		_close_home_overlay()
	else:
		show_title()

func _back() -> void:
	if _in_run:
		show_pause(_build)
	elif _home_overlay:
		show_home_navigation(_summary)
	else:
		show_title()

func _start(formal_ten: bool) -> void:
	var seed := _seed.strip_edges()
	if seed.is_empty():
		seed = "rush-demo"
	_hide()
	requested_start.emit(seed, formal_ten)

func _confirm_home() -> void:
	_begin(&"confirm_home", true)
	_title("Leave this run?", "Run items and coins are lost. Banked notes and permanent upgrades remain.")
	_button(_content, "KEEP PLAYING", close_panel)
	_button(_content, "LEAVE RUN", func() -> void:
		_hide()
		requested_home.emit())
	_focus_first()

func _hide() -> void:
	visible_panel = &""
	_root.hide()

func _begin(panel: StringName, in_run: bool) -> void:
	_in_run = in_run
	visible_panel = panel
	for child: Node in _root.get_children():
		_root.remove_child(child)
		child.queue_free()
	_root.show()
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.045, 0.065, 0.94) if in_run else INK
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(backdrop)
	if not in_run and not _home_overlay:
		var painted := TextureRect.new()
		painted.texture = load("res://assets/title_home/home_background.png")
		painted.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		painted.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		painted.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		painted.modulate = Color(0.45, 0.4, 0.36, 1)
		painted.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(painted)
	var accent := ColorRect.new()
	accent.color = TEAL
	accent.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	accent.offset_bottom = 4
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(accent)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	_root.add_child(margin)
	var centered := CenterContainer.new()
	margin.add_child(centered)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(0, 0)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centered.add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(minf(820, get_viewport().get_visible_rect().size.x - 56), minf(590, get_viewport().get_visible_rect().size.y - 56))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	var padding := MarginContainer.new()
	padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 24)
	scroll.add_child(padding)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	padding.add_child(_content)
	var ornament := TextureRect.new()
	ornament.texture = atlas_region(Rect2(914, 278, 412, 363))
	ornament.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ornament.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ornament.custom_minimum_size = Vector2(48, 36)
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(ornament)
	if in_run:
		menu_opened.emit()

func _slider(key: String, title: String, minimum: float, maximum: float, step: float) -> void:
	var row := HBoxContainer.new()
	_content.add_child(row)
	var label := _label(row, title, 16, TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var readout := _label(row, "", 16, TEAL)
	readout.custom_minimum_size.x = 56
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = float(_values.get(key, _defaults.get(key, minimum)))
	slider.custom_minimum_size.y = 28
	slider.value_changed.connect(func(value: float) -> void: readout.text = "%.2f" % value)
	readout.text = "%.2f" % slider.value
	_content.add_child(slider)
	_sliders[key] = slider

func _apply_settings() -> void:
	var patch: Dictionary = {}
	for key: String in _sliders:
		patch[key] = (_sliders[key] as HSlider).value
	var candidate := InputProfile.new()
	candidate.values = _values.duplicate(true)
	if not candidate.configure(patch):
		_settings_error.text = "Center threshold must be lower than aim threshold."
		return
	_values = candidate.values.duplicate(true)
	settings_changed.emit(patch.duplicate(true))
	_settings_error.text = "Applied."

func _restore_defaults() -> void:
	for key: String in _sliders:
		(_sliders[key] as HSlider).value = float(_defaults[key])
	_settings_error.text = "Choose Apply to use these values."

func _title(title: String, subtitle: String) -> void:
	_label(_content, title, 30, TEXT)
	_label(_content, subtitle, 16, MUTED)

func _label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 46
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _space(parent: Node, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	parent.add_child(spacer)

func _focus_first() -> void:
	var buttons := _content.find_children("*", "Button", true, false)
	if not buttons.is_empty():
		(buttons[0] as Button).grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if visible_panel.is_empty():
		return
	if event.is_action_pressed("ui_cancel"):
		if visible_panel == &"pause" or visible_panel == &"confirm_home":
			close_panel()
		elif visible_panel == &"home_function" or (visible_panel == &"home" and _home_overlay):
			_close_home_overlay()
		elif visible_panel != &"home" and visible_panel != &"title":
			_back()
		get_viewport().set_input_as_handled()

func _make_theme() -> Theme:
	return create_theme()

static func atlas_region(region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/title_home/ui_atlas.png")
	atlas.region = region
	return atlas

static func create_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_stylebox("panel", "PanelContainer", _box(CARD, Color("355366"), 16))
	theme.set_stylebox("normal", "Button", _box(Color("e7d4ad"), Color("987b49"), 8))
	theme.set_stylebox("hover", "Button", _box(Color("f5e7c5"), Color("b99752"), 8))
	theme.set_stylebox("pressed", "Button", _box(Color("cbb58c"), GOLD, 8))
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), GOLD, 8))
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_focus_color", "Button", TEXT)
	theme.set_color("font_pressed_color", "Button", TEXT)
	theme.set_color("font_hover_pressed_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color("612e32"))
	theme.set_stylebox("normal", "LineEdit", _box(Color("f4ead5"), Color("987b49"), 8))
	theme.set_stylebox("focus", "LineEdit", _box(Color("f4ead5"), GOLD, 8))
	theme.set_color("font_color", "LineEdit", TEXT)
	return theme

static func _box(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 9
	box.content_margin_bottom = 9
	return box
