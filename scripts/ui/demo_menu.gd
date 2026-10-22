@static_unload
class_name DemoMenu
extends CanvasLayer
## Presentation-only menus. The app owns pausing, routing and session input updates.

signal requested_enter_home
signal home_panel_closed
signal requested_start(seed: String)
signal requested_plains(seed: String)
signal requested_debug_region(region: StringName, map_index: int, seed: String)
signal requested_forest_exploration(map_index: int, seed: String)
signal requested_forest_varied(map_index: int, seed: String)
signal requested_forest_places(map_index: int, seed: String)
signal requested_upgrade
signal requested_lab
signal requested_actions
signal requested_foundation
signal requested_windchime
signal requested_pixel_plains
signal requested_style_lab
signal requested_foundry
signal requested_random(seed: String)
signal requested_resume
signal requested_home
signal settings_changed(values: Dictionary)
signal menu_opened
signal presentation_changed(reduced_effects: bool, muted: bool)

const INK := UnderworldUI.INK
const CARD := UnderworldUI.PANEL
const TEAL := UnderworldUI.MOSS
const GOLD := UnderworldUI.BRASS
const TEXT := UnderworldUI.TEXT
const MUTED := UnderworldUI.MUTED
const SCROLL_TOUCH_ADAPTER := preload("res://scripts/ui/menu_scroll_touch_adapter.gd")

var visible_panel: StringName = &""
var _root: Control
var _content: VBoxContainer
var _scroll_touch: Node
var _in_run := false
var _home_overlay := false
var _summary := ""
var _meta_state: Dictionary = {}
var _build := ""
var _build_items: Array[ItemDefinition]=[]
var _seed := ""
var _values: Dictionary = {}
var _defaults: Dictionary = {}
var _sliders: Dictionary = {}
var _settings_error: Label
var _reduced_effects := false
var _muted := false
var _audio_volume := 0.7
var _movement_mode: OptionButton
const TOUCH_MOVE_MODES := ["two_step", "digital", "analog"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	# Resolve the resource at use time. A hard script reference here keeps its
	# shared player dependency graph alive after standalone menus are freed.
	var profile: Variant = load("res://scripts/input/input_profile.gd").load_default()
	if profile != null:
		_defaults = profile.values.duplicate(true)
		_values = _defaults.duplicate(true)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = _make_theme()
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_root)
	_root.hide()

func set_input_values(values: Dictionary) -> void:
	_values = values.duplicate(true)

func set_meta_state(snapshot: Dictionary) -> void:
	_meta_state = snapshot.duplicate(true)

func show_title() -> void:
	_home_overlay = false
	_begin(&"title", false)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 24)
	_content.add_child(heading)
	var seal := TextureRect.new()
	seal.texture = UnderworldUI.icon(&"meta_note")
	seal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	seal.custom_minimum_size = Vector2(72, 100)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(seal)
	var title_rows := VBoxContainer.new()
	title_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title_rows)
	_label(title_rows, "失序之钟", 44, TEXT)
	_label(title_rows, "WINDCHIME PLAINS  /  第一声风铃", 15, GOLD)
	_label(_content, "AIM  ·  RELEASE  ·  RISE", 13, MUTED)
	_space(_content, 8)
	var columns := GridContainer.new()
	columns.columns = 2 if get_viewport().get_visible_rect().size.x >= 900 else 1
	columns.add_theme_constant_override("h_separation", 24)
	columns.add_theme_constant_override("v_separation", 18)
	_content.add_child(columns)
	var journey := VBoxContainer.new()
	journey.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journey.add_theme_constant_override("separation", 10)
	columns.add_child(journey)
	_label(journey, "ADVENTURE / 冒险", 13, GOLD)
	_button(journey, "风铃平原 / WIND CHIME PLAINS", func() -> void:
		_hide()
		requested_plains.emit("level-design-v2-baseline/08"))
	_button(journey, "ENTER HOME", func() -> void:
		_hide()
		requested_enter_home.emit())
	_button(journey, "SETTINGS", func() -> void: show_settings(false))
	_button(journey, "HOW TO PLAY", func() -> void: show_help(false))
	var workshop := VBoxContainer.new()
	workshop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workshop.add_theme_constant_override("separation", 10)
	columns.add_child(workshop)
	_label(workshop, "WORKSHOP / 开发入口", 13, MUTED)
	_button(workshop, "WINDCHIME PLAINS / FIVE STYLE LAB", func() -> void:
		_hide()
		requested_style_lab.emit())
	_button(workshop, "PIXEL MATERIAL / SMALL STUDY", func() -> void:
		_hide()
		requested_pixel_plains.emit())
	_button(workshop, "47 TILE / LEGACY TECH LAB", func() -> void:
		_hide()
		requested_foundation.emit())
	_button(workshop, "DEVELOPMENT DEMOS / ALL ENTRIES", func() -> void: show_home(_summary))
	for button: Node in columns.find_children("*", "Button", true, false):
		button.add_theme_font_size_override("font_size", 15)

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
			_title("The plains await", "A fresh run with your permanent upgrades. One connected region. Explore loops, open shortcuts, or challenge the Boss early.")
			_button(_content, "BEGIN / WINDCHIME PLAINS", func() -> void:
				_hide()
				requested_plains.emit(_plains_seed()))
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
	_label(rail, "失序\n之钟", 30, TEXT)
	_label(rail, "AIM • RELEASE • RISE", 12, TEAL)
	var action_button := _button(rail,"动作练习 / ACTIONS",func() -> void:
		_hide()
		requested_actions.emit())
	# Let the bilingual entry determine the rail width instead of clipping its label.
	action_button.clip_text = false
	for style: String in ["normal","hover","pressed","focus"]:
		action_button.add_theme_stylebox_override(style,_box(CARD,TEAL,4))
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
	_button(rail, "LEVEL FOUNDRY", func() -> void:
		_hide()
		requested_foundry.emit())
	_space(rail, 18)
	_label(rail, "PLAYABLE DEMO", 12, GOLD)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	shell.add_child(body)
	_label(body, "Choose your next run", 30, TEXT)
	_label(body, "Precise jumps. Powerful recoil. Your own route.", 16, MUTED)
	_label(body, "PLAINS / RANDOMIZED RUN", 12, GOLD)
	_button(body, "Explore   /   Windchime Plains", func() -> void:
		_hide()
		requested_plains.emit(_plains_seed()))
	_upgrade_controls(body)
	_button(body, "DEBUG / SELECT REGION + MAP", show_debug_regions)
	_label(body, "QUICK DEMO", 12, TEAL)
	_button(body, "3 rooms   /   A quick taste", _start_quick_demo)
	_label(body, "RUN SEED", 12, MUTED)
	var seed_edit := LineEdit.new()
	seed_edit.text = _seed
	seed_edit.placeholder_text = "Optional seed (blank = fresh plains run)"
	seed_edit.max_length = 80
	seed_edit.custom_minimum_size.y = 46
	seed_edit.text_changed.connect(func(value: String) -> void: _seed = value)
	body.add_child(seed_edit)
	if not _summary.is_empty():
		_label(body, _summary, 15, MUTED)
	_focus_first()

func show_debug_regions() -> void:
	_begin(&"debug_regions", false)
	_title("DEBUG / REGION SELECT", "Test entry only. Forest grants H only. This does not record a natural campaign clear.")
	var seed_edit := LineEdit.new()
	seed_edit.text = _seed
	seed_edit.placeholder_text = "Seed (blank = fresh run)"
	seed_edit.text_changed.connect(func(value: String) -> void: _seed = value)
	_content.add_child(seed_edit)
	for region: StringName in [&"plains", &"thorn_forest"]:
		for map_index: int in [1,2]:
			var chosen_region := region
			var chosen_map := map_index
			_button(_content, "%s / MAP %s" % [String(region).to_upper(),map_index], func() -> void:
				_hide()
				requested_debug_region.emit(chosen_region,chosen_map,_plains_seed()))
	for map_index: int in [1,2]:
		var chosen_map := map_index
		_button(_content,"FOREST PLACES / MAP %s" % map_index,func() -> void:
			_hide()
			requested_forest_places.emit(chosen_map,_plains_seed()))
	for map_index: int in [1,2]:
		var chosen_map := map_index
		_button(_content,"FOREST EXPANDED / MAP %s" % map_index,func() -> void:
			_hide()
			requested_forest_varied.emit(chosen_map,_plains_seed()))
	for map_index: int in [1,2]:
		var chosen_map := map_index
		_button(_content,"FOREST EXPLORATION / MAP %s" % map_index,func() -> void:
			_hide()
			requested_forest_exploration.emit(chosen_map,_plains_seed()))
	_button(_content,"BACK",func() -> void: show_home(_summary))
	_focus_first()

func hide_home() -> void:
	_hide()

func show_pause(build_description: String = "", items: Array[ItemDefinition] = []) -> void:
	_build = build_description
	_build_items=items
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
	_label(_content, "Touch movement", 16, TEXT)
	_movement_mode = OptionButton.new()
	_movement_mode.custom_minimum_size.y = 44
	for title: String in ["Walk / Run", "Fixed run speed", "Analog speed"]:
		_movement_mode.add_item(title)
	_movement_mode.select(TOUCH_MOVE_MODES.find(str(_values.get("touch_move_mode", _defaults.touch_move_mode))))
	_content.add_child(_movement_mode)
	_slider("left_sensitivity", "Movement sensitivity", 0.25, 2.0, 0.05)
	_slider("right_sensitivity", "Aim sensitivity", 0.25, 2.0, 0.05)
	_slider("touch_deadzone", "Touch deadzone", 0.0, 0.45, 0.01)
	_slider("right_enter_deadzone", "Gamepad aim threshold", 0.05, 0.8, 0.01)
	_slider("right_exit_deadzone", "Gamepad center threshold", 0.0, 0.75, 0.01)
	var reduced := CheckButton.new()
	reduced.text = "Reduced decorative effects"
	reduced.button_pressed = _reduced_effects
	reduced.toggled.connect(func(value: bool) -> void:
		_reduced_effects = value
		presentation_changed.emit(_reduced_effects,_muted))
	_content.add_child(reduced)
	var muted := CheckButton.new()
	muted.text = "Mute audio"
	muted.button_pressed = _muted
	muted.toggled.connect(func(value: bool) -> void:
		_muted = value
		presentation_changed.emit(_reduced_effects,_muted))
	_content.add_child(muted)
	_label(_content, "Sound volume / 音量（当前会话）", 14, GOLD)
	var volume_slider := HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = _audio_volume
	volume_slider.custom_minimum_size = Vector2(300, 20)
	volume_slider.value_changed.connect(func(value: float) -> void:
		_audio_volume = value
		var service := get_tree().get_first_node_in_group(&"game_audio")
		if service: service.set("volume", value))
	_content.add_child(volume_slider)
	_settings_error = _label(_content, "", 14, GOLD)
	_button(_content, "APPLY", _apply_settings)
	_button(_content, "RESTORE DEFAULTS", _restore_defaults)
	_button(_content, "BACK", _back)
	_focus_first()

func show_help(in_run: bool = false) -> void:
	_begin(&"help", in_run)
	_title("Make every shot a move", "Aim toward danger. Recoil carries you the other way.")
	_label(_content, "TOUCH\nTouch on the left: small drag to walk, larger drag to run (default). Touch and drag on the right to aim; release to fire. JUMP is beside the aim stick: tap for a small hop, hold for height.", 18, TEXT)
	_label(_content, "KEYBOARD + MOUSE\nA / D or arrows move. Space jumps. Aim with the mouse; release the left mouse button to fire. W / Up interacts.", 18, TEXT)
	_label(_content, "GAMEPAD\nLeft stick moves. A jumps. Aim with the right stick and return it to center to fire. Tilt the left stick up to interact.", 18, TEXT)
	_label(_content, "PLAINS ENERGY\nShots spend energy. Real enemy hits restore energy and one airborne round. Walls and armour do not. Rest on a platform to recover; air aiming keeps its separate brief slow-time budget.", 18, GOLD)
	_label(_content, "Explore two connected random maps. Mini Boss opens map 2; main Boss completes Plains. Click the fog minimap to zoom and drag. Hazards return you to a safe segment; zero HP ends the run. Legacy demos retain their original resource rules.", 16, MUTED)
	_button(_content, "BACK", _back)
	_focus_first()

func show_build(text: String) -> void:
	_build = text
	_begin(&"build", true)
	_title("Your build", "Every pickup shapes this run.")
	_label(_content, text if not text.is_empty() else "No items yet. Look for marked caches on optional routes.", 20, TEXT)
	var unique: Dictionary={}
	for item: ItemDefinition in _build_items:
		if unique.has(item.stable_id): unique[item.stable_id].count+=1
		else: unique[item.stable_id]={"item":item,"count":1}
	if not unique.is_empty():
		var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(800,290);_content.add_child(scroll)
		var cards:=HBoxContainer.new();cards.add_theme_constant_override("separation",12);scroll.add_child(cards)
		for entry: Dictionary in unique.values():
			var card:=ItemCard.new();card.item=entry.item;card.count=entry.count;cards.add_child(card)
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
		show_pause(_build,_build_items)
	elif _home_overlay:
		show_home_navigation(_summary)
	else:
		show_title()

func _plains_seed() -> String:
	var chosen := _seed.strip_edges()
	# Entropy is used only to choose a NEW run seed; all generation uses its
	# existing independent deterministic streams and recorded RunManifest.
	return chosen if not chosen.is_empty() else "plains-" + Crypto.new().generate_random_bytes(16).hex_encode()

func _start_quick_demo() -> void:
	var seed := _seed.strip_edges()
	if seed.is_empty():
		seed = "rush-demo"
	_hide()
	requested_start.emit(seed)

func _confirm_home() -> void:
	_begin(&"confirm_home", true)
	_title("Leave this run?", "Run items and coins are lost. Banked notes and permanent upgrades remain.")
	_button(_content, "KEEP PLAYING", close_panel)
	_button(_content, "LEAVE RUN", func() -> void:
		_hide()
		requested_home.emit())
	_focus_first()

func _hide() -> void:
	if is_instance_valid(_scroll_touch): _scroll_touch.cancel(&"menu_hide")
	visible_panel = &""
	_root.hide()

func _begin(panel: StringName, in_run: bool) -> void:
	if is_instance_valid(_scroll_touch): _scroll_touch.cancel(&"menu_replace")
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
		painted.texture = load("res://assets/underworld_plains/backgrounds/far.png")
		painted.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		painted.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		painted.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		painted.modulate = Color(0.34, 0.4, 0.35, 1)
		painted.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(painted)
	var accent := ColorRect.new()
	accent.color = Color(TEAL, 0.3)
	accent.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	accent.offset_bottom = 2
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
	scroll.custom_minimum_size = Vector2(minf(820, get_viewport().get_visible_rect().size.x - 96), minf(590, get_viewport().get_visible_rect().size.y - 96))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	_scroll_touch = SCROLL_TOUCH_ADAPTER.new()
	_scroll_touch.scroll = scroll
	scroll.add_child(_scroll_touch)
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
	ornament.texture = UnderworldUI.icon(&"meta_note")
	ornament.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ornament.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ornament.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ornament.custom_minimum_size = Vector2(48, 36)
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if panel != &"title": _content.add_child(ornament)
	else: ornament.free()
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
	var patch: Dictionary = {"touch_move_mode": TOUCH_MOVE_MODES[_movement_mode.selected]}
	for key: String in _sliders:
		patch[key] = (_sliders[key] as HSlider).value
	var candidate: Variant = load("res://scripts/input/input_profile.gd").new()
	candidate.values = _values.duplicate(true)
	if not candidate.configure(patch):
		_settings_error.text = "Center threshold must be lower than aim threshold."
		return
	_values = candidate.values.duplicate(true)
	settings_changed.emit(patch.duplicate(true))
	_settings_error.text = "Applied."

func _restore_defaults() -> void:
	_movement_mode.select(TOUCH_MOVE_MODES.find(str(_defaults.touch_move_mode)))
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
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.text = text
	button.clip_text = true
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
	return preload("res://scripts/ui/menu_theme.gd").create_theme()

static func _box(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := UnderworldUI.box(color, border)
	style.set_corner_radius_all(mini(radius, 2))
	return style
