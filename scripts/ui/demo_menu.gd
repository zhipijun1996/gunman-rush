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
signal requested_avatar(id: String)
signal requested_home_weapon(id: StringName)
signal requested_lab
signal requested_actions
signal requested_player_presentation
signal requested_foundation
signal requested_windchime
signal requested_pixel_plains
signal requested_style_lab
signal requested_foundry
signal requested_random(seed: String)
signal requested_resume
signal requested_retry
signal requested_home
signal settings_changed(values: Dictionary)
signal menu_opened
signal presentation_changed(reduced_effects: bool, muted: bool)
signal build_opened
signal build_closed
signal equipment_requested(instance_ids: Array[StringName], revision: int, session: int)
signal gear_upgrade_requested(revision: int, session: int)

const INK := DemoClockworkTheme.INK
const CARD := DemoClockworkTheme.PANEL
const TEAL := DemoClockworkTheme.TEAL
const GOLD := DemoClockworkTheme.BRASS
const TEXT := DemoClockworkTheme.PAPER
const MUTED := DemoClockworkTheme.MUTED
const SCROLL_TOUCH_ADAPTER := preload("res://scripts/ui/menu_scroll_touch_adapter.gd")
const GEAR_LOAD_CELL := preload("res://scripts/ui/gear_load_cell.gd")

var visible_panel: StringName = &""
var _root: Control
var _content: VBoxContainer
var _scroll_touch: Node
var _in_run := false
var _home_overlay := false
var _summary := ""
var _meta_state: Dictionary = {}
var _avatar_options: Array[Dictionary] = []
var _avatar_selected := "courier"
var _weapon_options: Array[Dictionary] = []
var _weapon_selected: StringName = &"pulse_gun"
var _weapon_buttons: Dictionary = {}
var home_function_id: StringName = &""
var _build := ""
var _build_items: Array[ItemDefinition]=[]
var _equipment_view: Dictionary = {}
var _equipment_body: VBoxContainer
var _equipment_generation := 0
var _equipment_detail_generation := 0
var _replacement_id: StringName = &""
var _equipment_focus_id: StringName = &""
var _selected_instance_id: StringName = &""
var _equipment_left: VBoxContainer
var _equipment_detail: VBoxContainer
var _equipment_grid: GridContainer
var _equipped_grid: GridContainer
var _backpack_scroll: ScrollContainer
var _equipped_scroll: ScrollContainer
var _detail_scroll: ScrollContainer
var _inventory_tiles: Array[Button] = []
const PAUSE_PAGES: Array[StringName] = [&"build", &"pause", &"settings", &"help"]
var _seed := ""
var _values: Dictionary = {}
var _defaults: Dictionary = {}
var _sliders: Dictionary = {}
var _settings_error: Label
var _reduced_effects := false
var _muted := false
var _audio_volume := 0.7
var _movement_mode: OptionButton
var _frame: PanelContainer
var _scroll: ScrollContainer
var _margin: MarginContainer
var _padding: MarginContainer
var _clock: Control
var _title_label: Label
var _title_secondary: GridContainer
var _home_shell: GridContainer
var _footer: Label
var _focus_history: Dictionary = {}
var _page_generation := 0
var _return_panel: StringName = &"title"
var _last_viewport := Vector2.ZERO
var _last_screen_transform := Transform2D.IDENTITY
var _last_window_size := Vector2i.ZERO
var _last_layout_device: StringName = &""
var _menu_device: StringName = &"keyboard_mouse"
var _focus_restore_queued := false
var _focus_restore_generation := -1
var _focus_scroll_callback: Callable
const TOUCH_MOVE_MODES := ["two_step", "digital", "analog"]

func _ready() -> void:
	preload("res://scripts/ui/demo_ui_01/menu_input.gd").ensure_actions()
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

func set_avatar_options(options: Array[Dictionary], selected: String) -> void:
	_avatar_options = options.duplicate(true)
	_avatar_selected = selected

func set_weapon_options(options: Array[Dictionary], selected: StringName) -> void:
	_weapon_options = options.duplicate(true)
	_weapon_selected = selected
	for option: Dictionary in _weapon_options:
		var id := StringName(option.id)
		var button := _weapon_buttons.get(id) as Button
		if is_instance_valid(button):
			button.text = _weapon_button_text(option)
			button.disabled = id == _weapon_selected

func show_title() -> void:
	_home_overlay = false
	_begin(&"title", false)
	_title_label = _label(_content, "失序之钟", 36, TEXT)
	_label(_content, "风铃未息，旅途再启。", 18, MUTED)
	_space(_content, 8)
	var primary := _button(_content, "开始游戏", _start_title_adventure)
	primary.name = "BeginAdventure"
	primary.set_meta(&"ui_legacy_prefix", "风铃平原")
	primary.set_meta(&"focus_key", "title_start")
	primary.theme_type_variation = &"PrimaryButton"
	primary.custom_minimum_size.y = 62
	primary.add_theme_font_size_override("font_size", 24)
	var continue_button := _button(_content, "继续游戏（选择存档）", show_continue)
	continue_button.name = "ContinueAdventure"
	continue_button.set_meta(&"focus_key", "title_continue")
	continue_button.custom_minimum_size.y = 62
	var settings_button := _button(_content, "设定", func() -> void: show_settings(false))
	settings_button.name = "TitleSettings"
	settings_button.set_meta(&"ui_legacy_prefix", "SETTINGS")
	settings_button.set_meta(&"focus_key", "title_settings")
	settings_button.custom_minimum_size.y = 62
	var tutorial_button := _button(_content, "新手教程", func() -> void: show_help(false))
	tutorial_button.name = "TitleTutorial"
	tutorial_button.set_meta(&"ui_legacy_prefix", "HOW TO PLAY")
	tutorial_button.set_meta(&"focus_key", "title_tutorial")
	tutorial_button.custom_minimum_size.y = 62
	_space(_content, 6)
	var workshop := _button(_content, "开发入口", func() -> void: show_home(_summary))
	workshop.name = "DevelopmentEntries"
	workshop.set_meta(&"ui_legacy_prefix", "DEVELOPMENT DEMOS")
	workshop.add_theme_font_size_override("font_size", 18)
	workshop.custom_minimum_size.y = 48
	_focus_first()

func _start_title_adventure() -> void:
	_hide()
	requested_enter_home.emit()

func show_continue() -> void:
	_home_overlay = false
	_begin(&"continue", false)
	_title("选择存档", "选择已有成长记录，回到家园开始新的冒险。")
	var status := str(_meta_state.get("save_status", ""))
	var revision := int(_meta_state.get("profile_revision", 0))
	var memory_only := status == "memory_only"
	var saved := revision > 0 and status in ["loaded", "recovered_backup", "saved"]
	var current_session := memory_only and revision > 0
	if memory_only:
		_label(_content, "当前试玩仅保留本次会话的成长，关闭或刷新网页后不会保存。", 17, GOLD)
	if saved or current_session:
		_label(_content, "当前试玩会话" if memory_only else "本地成长记录", 23, TEXT)
		_label(_content, "音符 %s  ·  %s %s" % [_meta_state.get("notes", 0), "会话记录" if memory_only else "记录版本", revision], 18, GOLD)
		_label(_content, "冒险完成 %s 次  ·  地区通关 %s 次\n未完成的冒险 %s 次" % [_meta_state.get("completed_runs", 0), _meta_state.get("completed_biomes", 0), _meta_state.get("failed_runs", 0)], 17, TEXT)
		var upgrades: Dictionary = _meta_state.get("upgrades", {})
		var growth := PackedStringArray()
		var upgrade_ids := upgrades.keys()
		upgrade_ids.sort()
		for upgrade_id: Variant in upgrade_ids:
			var level := int(upgrades[upgrade_id])
			if level <= 0: continue
			growth.append("%s %s 级" % ["永久生命" if str(upgrade_id) == "vitality" else str(upgrade_id), level])
		_label(_content, "永久成长：" + ("、".join(growth) if not growth.is_empty() else "尚未获得"), 17, TEXT)
		_label(_content, "此记录只保存永久成长，不保存冒险中的位置、金币或物品。选择后返回家园，不会接续上一局。", 17, MUTED)
		var choose := _button(_content, "选择此进度 · 返回家园", func() -> void:
			_hide()
			requested_enter_home.emit())
		choose.name = "ChooseExistingProfile"
		choose.set_meta(&"focus_key", "continue_local")
		choose.theme_type_variation = &"PrimaryButton"
	else:
		var empty := status in ["", "new_profile", "memory_only"] and revision == 0
		_label(_content, "尚无可继续的成长记录" if empty else "本地成长记录暂不可用", 23, TEXT)
		_label(_content, "完成一次冒险或获得音符后，可在这里查看成长记录。" if empty else "现有记录未能读取。请返回标题页，稍后再试。", 17, MUTED)
		if empty:
			var begin := _button(_content, "开始新的冒险", _start_title_adventure)
			begin.theme_type_variation = &"PrimaryButton"
	_button(_content, "返回标题", show_title)
	_focus_first()

func show_region_select() -> void:
	_begin(&"regions", false)
	_title("选择旅途", "REGIONS / 已有试玩地区")
	_label(_content, "01  风铃平原", 25, TEXT)
	_label(_content, "两张相连地图。探索支路、寻找补给，挑战牧风者。", 17, MUTED)
	_button(_content, "BEGIN / 风铃平原", func() -> void:
		_hide()
		requested_plains.emit(_plains_seed()))
	_space(_content, 10)
	_label(_content, "02  荆棘森林 · 开发试玩", 25, TEXT)
	_label(_content, "独立开发入口，临时授予钩索；不记录自然流程通关。", 17, MUTED)
	for map_index: int in [1, 2]:
		var selected_map := map_index
		_button(_content, "THORN FOREST / MAP %s · 开发试玩" % map_index, func() -> void:
			_hide()
			requested_debug_region.emit(&"thorn_forest", selected_map, _plains_seed()))
	_button(_content, "BACK / 返回", func() -> void: show_home(_summary))
	_focus_first()

func show_run_end(report: Dictionary) -> void:
	_home_overlay = true
	_begin(&"run_end", false)
	var success := bool(report.get("success", false))
	_label(_content, "JOURNEY RECORDED / 旅途记录", 13, GOLD)
	_title("钟声仍在回响" if success else "旅途暂歇", "冒险已结束。已存入的音符与永久成长保留。")
	var details := str(report.get("summary", ""))
	if not details.is_empty(): _label(_content, details, 19, TEXT)
	_label(_content, "本局金币与临时物品不带入下一次冒险。", 16, MUTED)
	if bool(report.get("can_retry", true)):
		var retry := _button(_content, "再次出发 / DEPART AGAIN", func() -> void:
			_hide()
			_home_overlay = false
			requested_retry.emit())
		retry.theme_type_variation = &"PrimaryButton"
	_button(_content, "ENTER HOME / 返回家园", _close_home_overlay)
	_focus_first()

func show_home_navigation(summary: String = "") -> void:
	_home_overlay = true
	show_home(summary)

func show_home_panel(function_id: StringName) -> void:
	_home_overlay = true
	_begin(&"home_function", false)
	home_function_id = function_id
	match function_id:
		&"arms":
			_title("武器工坊 / ARMORER", "选择下一次冒险使用的基础武器。")
			_label(_content, "三种武器均为 Lv.1，免费更换；同一时刻只装备一种。", 18, TEXT)
			for option: Dictionary in _weapon_options:
				var id := StringName(option.id)
				var button := _button(_content, _weapon_button_text(option), func() -> void: requested_home_weapon.emit(id))
				button.name = "EquipHomeWeapon_" + str(id)
				button.set_meta(&"focus_key", "home_weapon_" + str(id))
				button.disabled = id == _weapon_selected
				_weapon_buttons[id] = button
			_label(_content, "当前家园与下一次出发都会使用所选武器。\n本次会话内保留选择，刷新网页后恢复脉冲枪。", 17, MUTED)
		&"upgrade":
			_title("Clockwork artisan", "Spend permanent NOTES. Run coins stay inside the adventure.")
			_upgrade_controls(_content)
		&"departure":
			_title("The plains await", "A fresh run with your permanent upgrades. One connected region. Explore loops, open shortcuts, or challenge the Boss early.")
			_button(_content, "BEGIN / WINDCHIME PLAINS", func() -> void:
				_hide()
				requested_plains.emit(_plains_seed()))
		&"character":
			_title("织时匠 / Timeweaver", "为下一段旅途换上喜欢的外观。")
			var picker := OptionButton.new()
			picker.name = "TimeweaverAppearance"
			picker.custom_minimum_size = Vector2(360, 48)
			picker.focus_mode = Control.FOCUS_ALL
			for option: Dictionary in _avatar_options:
				picker.add_item(str(option.display_name))
				if str(option.id) == _avatar_selected: picker.select(picker.item_count - 1)
			picker.item_selected.connect(func(index: int) -> void:
				if index >= 0 and index < _avatar_options.size(): requested_avatar.emit(str(_avatar_options[index].id)))
			_content.add_child(picker)
			var touch := PopupTouchAdapter.new()
			touch.popup = picker.get_popup()
			picker.get_popup().add_child(touch)
			_label(_content, "本次游戏中会记住你的选择。", 18, MUTED)
		&"achievements":
			_title("Records keeper", "Achievement service is in development.")
			_label(_content, "No achievement rewards are granted by opening this panel. Future progress and unlock rules remain undecided.", 20, TEXT)
		_:
			_title("Home", "This service is not available.")
	_button(_content, "BACK TO HOME", _close_home_overlay)
	_focus_first()

func _weapon_button_text(option: Dictionary) -> String:
	return ("当前装备 · " if StringName(option.id) == _weapon_selected else "装备 · ") + "Lv.%s %s" % [option.tier, option.display_name]

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
	var shell := GridContainer.new()
	_home_shell = shell
	shell.columns = 2 if get_viewport().get_visible_rect().size.x >= 900 else 1
	shell.add_theme_constant_override("h_separation", 30)
	shell.add_theme_constant_override("v_separation", 24)
	_content.add_child(shell)
	var rail := VBoxContainer.new()
	rail.custom_minimum_size.x = 160
	rail.add_theme_constant_override("separation", 12)
	shell.add_child(rail)
	_label(rail, "失序\n之钟", 30, TEXT)
	_label(rail, "AIM · RELEASE · RISE", 12, TEAL)
	var action_button := _button(rail,"动作练习 / ACTIONS",func() -> void:
		_hide()
		requested_actions.emit())
	# Let the bilingual entry determine the rail width instead of clipping its label.
	action_button.clip_text = false
	for style: String in ["normal","hover","pressed","focus"]:
		action_button.add_theme_stylebox_override(style,_box(CARD,TEAL,4))
	_button(rail, "主角音画样板", func() -> void:
		_hide()
		requested_player_presentation.emit())
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
	_button(rail, "风格实验室", func() -> void:
		_hide()
		requested_style_lab.emit()).set_meta(&"ui_legacy_prefix", "WINDCHIME PLAINS / FIVE STYLE LAB")
	_button(rail, "像素材质研究", func() -> void:
		_hide()
		requested_pixel_plains.emit()).set_meta(&"ui_legacy_prefix", "PIXEL MATERIAL / SMALL STUDY")
	_button(rail, "旧47格实验室", func() -> void:
		_hide()
		requested_foundation.emit()).set_meta(&"ui_legacy_prefix", "47 TILE / LEGACY TECH LAB")
	_button(rail, "风铃美术实验室", func() -> void:
		_hide()
		requested_windchime.emit())
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
	_button(body, "地区试玩", show_region_select).set_meta(&"ui_legacy_prefix", "地区选择")
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
	# The formal pause entry is the inventory, with no intermediate action menu.
	_build_items = items
	show_build(build_description)

func show_journey() -> void:
	_begin(&"pause", true)
	_pause_navigation(&"pause")
	_title("片刻停驻", "钟摆停下，旅途仍在。")
	if not _build.is_empty(): _label(_content, _build, 17, TEXT)
	var resume := _button(_content, "继续旅途", close_panel)
	resume.name = "ResumeAdventure"
	resume.set_meta(&"ui_legacy_prefix", "RESUME")
	resume.theme_type_variation = &"PrimaryButton"
	var leave := _button(_content, "结束本局 · 返回家园", _confirm_home)
	leave.name = "LeaveAdventure"
	leave.set_meta(&"ui_legacy_prefix", "RETURN TO HOME")
	_focus_first()

func show_settings(in_run: bool = false) -> void:
	if visible_panel not in [&"settings", &"help"]: _return_panel = visible_panel
	_begin(&"settings", in_run)
	if in_run: _pause_navigation(&"settings")
	_title("设定", "输入参数选择应用后生效；仅保存于当前会话。")
	_sliders.clear()
	_label(_content, "Touch movement", 16, TEXT)
	_movement_mode = OptionButton.new()
	_movement_mode.set_meta(&"focus_key", "touch_move_mode")
	_movement_mode.custom_minimum_size.y = 48
	_movement_mode.clip_text = true
	for title: String in ["Walk / Run", "Fixed run speed", "Analog speed"]:
		_movement_mode.add_item(title)
	_movement_mode.select(TOUCH_MOVE_MODES.find(str(_values.get("touch_move_mode", _defaults.touch_move_mode))))
	_content.add_child(_movement_mode)
	var popup_touch := preload("res://scripts/ui/popup_touch_adapter.gd").new()
	popup_touch.popup = _movement_mode.get_popup()
	_movement_mode.get_popup().add_child(popup_touch)
	_movement_mode.get_popup().about_to_popup.connect(func() -> void: _scroll_touch.cancel(&"popup_open"))
	_slider("left_sensitivity", "Movement sensitivity", 0.25, 2.0, 0.05)
	_slider("right_sensitivity", "Aim sensitivity", 0.25, 2.0, 0.05)
	_slider("touch_deadzone", "Touch deadzone", 0.0, 0.45, 0.01)
	_slider("right_enter_deadzone", "Gamepad aim threshold", 0.05, 0.8, 0.01)
	_slider("right_exit_deadzone", "Gamepad center threshold", 0.0, 0.75, 0.01)
	var reduced := CheckButton.new()
	reduced.text = "Reduced decorative effects / 减少装饰特效"
	reduced.custom_minimum_size.y = 48
	reduced.clip_text = true
	reduced.button_pressed = _reduced_effects
	reduced.toggled.connect(func(value: bool) -> void:
		_reduced_effects = value
		presentation_changed.emit(_reduced_effects,_muted))
	_content.add_child(reduced)
	var muted := CheckButton.new()
	muted.text = "Mute audio / 静音"
	muted.custom_minimum_size.y = 48
	muted.clip_text = true
	muted.button_pressed = _muted
	muted.toggled.connect(func(value: bool) -> void:
		_muted = value
		presentation_changed.emit(_reduced_effects,_muted))
	_content.add_child(muted)
	_label(_content, "Sound volume / 音量（当前会话）", 14, GOLD)
	var volume_slider := HSlider.new()
	volume_slider.set_meta(&"focus_key", "audio_volume")
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = _audio_volume
	volume_slider.custom_minimum_size = Vector2(0, 48)
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
	if visible_panel not in [&"settings", &"help"]: _return_panel = visible_panel
	_begin(&"help", in_run)
	if in_run: _pause_navigation(&"help")
	_title("新手教程", "瞄准危险，反冲会带你去相反的方向。")
	if not in_run:
		_label(_content, "先了解操作，再从风铃平原入口练习。练习将开始一局新的冒险。", 17, MUTED)
		var practice := _button(_content, "开始平原练习（新冒险）", _start_title_adventure)
		practice.name = "BeginBasicTutorial"
		practice.theme_type_variation = &"PrimaryButton"
	_label(_content, "键鼠 / KEYBOARD + MOUSE", 19, GOLD)
	_label(_content, "A / D 移动，Space 跳跃。按住鼠标左键瞄准，松手射击。W 交互，S 下穿单向平台；方向键上 / 下观察。已获得钩索时，右键或 E 按住瞄准，松开发钩。", 17, TEXT)
	_label(_content, "触屏 / TOUCH", 19, GOLD)
	_label(_content, "左侧拖动移动：小幅慢走、大幅跑动。右侧拖动瞄准，松手射击；回中心再松手可取消。JUMP 轻点小跳，按住跳高。HOOK 控件仅在获得钩索后显示。", 17, TEXT)
	_label(_content, "手柄 / GAMEPAD", 19, GOLD)
	_label(_content, "左摇杆移动，A 跳跃。右摇杆瞄准，回中心射击。左杆向上交互。已获得钩索时，LB 按住瞄准，松开发钩。菜单内用方向键或左杆选择、A 确认、B 返回。", 17, TEXT)
	_label(_content, "生命与续航 / RESOURCES", 19, GOLD)
	_label(_content, "开枪不消耗时间能量。空中瞄准枪械或钩索触发慢时，只有慢时消耗时间能量，接地逐渐恢复。基础空中弹药一发，对敌人造成真实伤害或落地可补充。二段跳与钩索解锁后，图标表示剩余可用资格。爱心归零结束本局，回到家园。", 17, TEXT)
	_label(_content, "地图与暂停 / MAP & PAUSE", 19, GOLD)
	_label(_content, "点击地图或按 M 查看已探索区域，拖动平移、滚轮或双指缩放。MENU / Esc 暂停；打开界面会取消旧瞄准。平原小 Boss 开启地图二，主 Boss 完成地区。开发练习保留各自规则。", 17, MUTED)
	_button(_content, "BACK / 返回", _back)
	_focus_first()

func show_build(text: String) -> void:
	_build = text
	_begin(&"build", true)
	_equipment_view.clear()
	_replacement_id = &""
	_equipment_focus_id = &""
	_pause_navigation(&"build")
	_equipment_body = VBoxContainer.new()
	_equipment_body.name = "EquipmentBody"
	_equipment_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_equipment_body.add_theme_constant_override("separation", 0)
	_content.add_child(_equipment_body)
	_label(_equipment_body, "正在读取本局背包……", 18, MUTED)
	# The application creates the editing session after _begin cancels old input.
	build_opened.emit()
	if _equipment_view.is_empty(): _show_build_preview()
	_focus_first()

func _show_build_preview() -> void:
	# Read-only development consumers may show long legacy summaries/cards.
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	for child: Node in _equipment_body.get_children():
		_equipment_body.remove_child(child)
		child.queue_free()
	_label(_equipment_body, "开发入口 · 构筑预览", 21, GOLD)
	_label(_equipment_body, "此处仅预览道具与属性。正式装备、卸下与齿轮扩容请在冒险中的暂停背包页操作。", 17, MUTED)
	if not _build.is_empty(): _label(_equipment_body, _build, 17, TEXT)
	for item: ItemDefinition in _build_items:
		if item == null: continue
		var card := ItemCard.new()
		card.item = item
		card.compact = true
		_equipment_body.add_child(card)
	if _build_items.is_empty(): _label(_equipment_body, "此开发入口暂无道具。", 17, MUTED)

func set_equipment_view(snapshot: Dictionary) -> void:
	_equipment_view = snapshot.duplicate(true)
	if visible_panel != &"build" or not is_instance_valid(_equipment_body): return
	_build = str(snapshot.get("summary", _build))
	if not _replacement_id in _equipped_ids(): _replacement_id = &""
	_render_equipment()

func _equipped_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry: Dictionary in _equipment_view.get("items", []):
		if bool(entry.get("equipped", false)): ids.append(StringName(entry.get("instance_id", &"")))
	return ids

func _render_equipment() -> void:
	if not is_instance_valid(_equipment_body): return
	var old_scroll := _backpack_scroll.scroll_vertical if is_instance_valid(_backpack_scroll) else 0
	var focused := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and _equipment_body.is_ancestor_of(focused):
		_focus_history[&"build"] = str(focused.get_meta(&"focus_key", focused.name))
	if not _equipment_focus_id.is_empty():
		_selected_instance_id = _equipment_focus_id
		_focus_history[&"build"] = "item:" + str(_equipment_focus_id)
		_equipment_focus_id = &""
	_equipment_generation += 1
	_inventory_tiles.clear()
	for child: Node in _equipment_body.get_children():
		_equipment_body.remove_child(child)
		child.queue_free()
	var items: Array = _equipment_view.get("items", [])
	var has_selected := false
	var equipped_count := 0
	for entry: Dictionary in items:
		if StringName(entry.get("instance_id", &"")) == _selected_instance_id: has_selected = true
		if bool(entry.get("equipped", false)): equipped_count += 1
	if not has_selected:
		_selected_instance_id = StringName(items[0].get("instance_id", &"")) if not items.is_empty() else &""
	var split := HBoxContainer.new()
	split.name = "InventoryColumns"
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 22)
	_equipment_body.add_child(split)
	_equipment_left = VBoxContainer.new()
	_equipment_left.name = "InventoryCollection"
	_equipment_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equipment_left.size_flags_stretch_ratio = 1.65
	_equipment_left.add_theme_constant_override("separation", 8)
	split.add_child(_equipment_left)
	var capacity := int(_equipment_view.get("capacity", 0))
	var used := int(_equipment_view.get("used", 0))
	var remaining := int(_equipment_view.get("remaining", capacity - used))
	var header := HBoxContainer.new()
	_equipment_left.add_child(header)
	var load_label := _label(header, "齿轮  %s / %s    剩余 %s" % [used, capacity, remaining], 21, GOLD, false)
	load_label.name = "GearLoad"
	load_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var coins_label := _label(header, "金币 %s" % int(_equipment_view.get("coins", 0)), 17, MUTED, false)
	coins_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	coins_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	var slots := HBoxContainer.new()
	slots.name = "GearSlots"
	slots.add_theme_constant_override("separation", 7)
	_equipment_left.add_child(slots)
	for index: int in capacity:
		var slot := GEAR_LOAD_CELL.new()
		slot.name = "GearSlot%s" % (index + 1)
		slot.occupied = index < used
		slot.set_meta(&"occupied", index < used)
		slots.add_child(slot)
	_label(_equipment_left, "已装备  ·  %s" % equipped_count, 17, TEAL)
	_equipped_scroll = _inventory_scroll(_equipment_left, "EquippedScroll")
	_equipped_scroll.size_flags_vertical = Control.SIZE_FILL
	_equipped_grid = _inventory_grid(_equipped_scroll, "EquippedItems")
	for entry: Dictionary in items:
		if bool(entry.get("equipped", false)): _equipment_icon(_equipped_grid, entry)
	if equipped_count == 0:
		var empty_equipped := _label(_equipped_grid, "暂无装备", 16, MUTED, false)
		empty_equipped.autowrap_mode = TextServer.AUTOWRAP_OFF
	var divider := HSeparator.new()
	_equipment_left.add_child(divider)
	_label(_equipment_left, "背包  ·  %s    选中查看详情" % (items.size() - equipped_count), 17, GOLD)
	_backpack_scroll = _inventory_scroll(_equipment_left, "BackpackScroll")
	_backpack_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_equipment_grid = _inventory_grid(_backpack_scroll, "BackpackItems")
	for entry: Dictionary in items:
		if not bool(entry.get("equipped", false)): _equipment_icon(_equipment_grid, entry)
	if items.size() == equipped_count:
		var empty := _label(_equipment_grid, "背包暂无未装备道具。
探索宝箱或商店可以获得。", 17, MUTED)
		empty.custom_minimum_size.x = 250
	_label(_equipment_left, "未装备道具不占负荷、不产生效果。", 14, MUTED)
	var rule := VSeparator.new()
	split.add_child(rule)
	_detail_scroll = _inventory_scroll(split, "DetailScroll")
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_stretch_ratio = 1.0
	_equipment_detail = VBoxContainer.new()
	_equipment_detail.name = "EquipmentDetail"
	_equipment_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equipment_detail.add_theme_constant_override("separation", 10)
	_detail_scroll.add_child(_equipment_detail)
	_render_equipment_detail()
	if not _focus_history.has(&"build") and not _selected_instance_id.is_empty(): _focus_history[&"build"] = "item:" + str(_selected_instance_id)
	_layout_menu()
	_backpack_scroll.set_deferred("scroll_vertical", old_scroll)
	_focus_first()

func _inventory_scroll(parent: Node, node_name: String) -> ScrollContainer:
	var result := ScrollContainer.new()
	result.name = node_name
	result.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	result.follow_focus = true
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(result)
	var adapter := SCROLL_TOUCH_ADAPTER.new()
	adapter.name = "BackpackTouchAdapter" if node_name == "BackpackScroll" else node_name + "TouchAdapter"
	adapter.scroll = result
	result.add_child(adapter)
	return result

func _inventory_grid(parent: Node, node_name: String) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = node_name
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	return grid

func _equipment_icon(parent: Node, entry: Dictionary) -> void:
	var definition := entry.get("definition") as ItemDefinition
	if definition == null: return
	var id := StringName(entry.get("instance_id", &""))
	var button := _equipment_button(parent, "", func() -> void: _select_equipment(id))
	button.name = "SelectItem"
	button.set_meta(&"instance_id", id)
	button.set_meta(&"focus_key", "item:" + str(id))
	button.set_meta(&"rarity_color", _rarity_color(definition))
	button.set_meta(&"inventory_tile", true)
	button.icon = ItemPresentation.icon(definition.icon_key)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 52)
	button.tooltip_text = "%s · %s齿轮" % [definition.display_name, definition.gear_cost]
	button.toggle_mode = true
	button.focus_entered.connect(func() -> void: _select_equipment(id))
	var cost := Label.new()
	cost.text = str(definition.gear_cost)
	cost.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	cost.position = Vector2(-22, -24)
	cost.size = Vector2(18, 20)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.add_theme_font_size_override("font_size", 14)
	cost.add_theme_color_override("font_color", TEXT)
	cost.add_theme_color_override("font_outline_color", INK)
	cost.add_theme_constant_override("outline_size", 4)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(cost)
	_inventory_tiles.append(button)
	_style_inventory_tile(button)

func _rarity_color(definition: ItemDefinition) -> Color:
	return [Color("83a69e"), Color("a694b0"), GOLD][definition.rarity]

func _style_inventory_tile(button: Button) -> void:
	var selected := StringName(button.get_meta(&"instance_id", &"")) == _selected_instance_id
	button.button_pressed = selected
	var border: Color = button.get_meta(&"rarity_color", GOLD)
	var normal := _box(INK.lightened(0.08) if selected else INK, GOLD if selected else border.darkened(0.35), 2)
	normal.set_content_margin_all(8)
	normal.set_border_width_all(2 if selected else 1)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("pressed", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = GOLD
	hover.bg_color = CARD
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("hover_pressed", hover)

func _select_equipment(id: StringName) -> void:
	if visible_panel != &"build" or not is_instance_valid(_equipment_detail): return
	var same_selection := _selected_instance_id == id
	_selected_instance_id = id
	# Native toggle buttons flip before pressed: a second click must retain
	# the selected highlight and the matching detail, rather than deselect it.
	for tile: Button in _inventory_tiles:
		if is_instance_valid(tile): _style_inventory_tile(tile)
	if same_selection and _equipment_detail.get_child_count() > 0: return
	_render_equipment_detail()

func _render_equipment_detail() -> void:
	if not is_instance_valid(_equipment_detail): return
	_equipment_detail_generation += 1
	for child: Node in _equipment_detail.get_children():
		_equipment_detail.remove_child(child)
		child.queue_free()
	var selected: Dictionary = {}
	for entry: Dictionary in _equipment_view.get("items", []):
		if StringName(entry.get("instance_id", &"")) == _selected_instance_id:
			selected = entry
			break
	var definition := selected.get("definition") as ItemDefinition
	if definition != null:
		var item_title := _label(_equipment_detail, definition.display_name, 26, TEXT)
		item_title.name = "SelectedItemName"
		var badge := _label(_equipment_detail, "%s  ·  %s 齿轮" % [["普通", "稀有", "顶级"][definition.rarity], definition.gear_cost], 17, _rarity_color(definition))
		badge.name = "SelectedItemCost"
		var image := TextureRect.new()
		image.name = "SelectedItemIcon"
		image.texture = ItemPresentation.icon(definition.icon_key)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(0, 90)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_equipment_detail.add_child(image)
		if not definition.description.is_empty(): _label(_equipment_detail, definition.description, 17, TEXT)
		var effects := _label(_equipment_detail, ItemPresentation.effects(definition), 17, TEAL)
		effects.name = "SelectedItemEffects"
		var equipped := bool(selected.get("equipped", false))
		var id := _selected_instance_id
		var action := _detail_equipment_button(_equipment_detail, "卸下" if equipped else ("替换并装备" if not _replacement_id.is_empty() else "装备"), func() -> void: _request_equipment(id, not equipped))
		action.name = "UnequipItem" if equipped else "EquipItem"
		action.set_meta(&"focus_key", ("unequip:" if equipped else "equip:") + str(id))
		action.theme_type_variation = &"PrimaryButton"
		if equipped:
			var replace := _detail_equipment_button(_equipment_detail, "取消替换对象" if _replacement_id == id else "选为替换对象", func() -> void:
				_replacement_id = &"" if _replacement_id == id else id
				_render_equipment_detail()
				_focus_history[&"build"] = "item:" + str(id)
				_focus_first())
			replace.name = "SelectReplacement"
			replace.set_meta(&"focus_key", "replace:" + str(id))
		var reason := str(selected.get("reason", ""))
		if not equipped and not reason.is_empty() and _replacement_id.is_empty():
			var denial := _label(_equipment_detail, reason, 16, GOLD)
			denial.name = "EquipmentReason"
	else:
		_label(_equipment_detail, "行囊尚空", 26, TEXT)
		_label(_equipment_detail, "探索宝箱、击败Boss或到商店购买道具。获得后先进入背包，在这里选择并装备。", 18, MUTED)
	if not _replacement_id.is_empty():
		_label(_equipment_detail, "替换中 · 选择背包中的道具，再确认装备。", 16, TEAL)
		var cancel := _detail_equipment_button(_equipment_detail, "取消替换", func() -> void:
			_replacement_id = &""
			_render_equipment_detail()
			_focus_history[&"build"] = "item:" + str(_selected_instance_id)
			_focus_first())
		cancel.name = "CancelReplacement"
		cancel.set_meta(&"focus_key", "cancel_replace")
	var message := str(_equipment_view.get("message", ""))
	if not message.is_empty():
		var feedback := _label(_equipment_detail, message, 16, GOLD)
		feedback.name = "EquipmentFeedback"
	_equipment_detail.add_child(HSeparator.new())
	var capacity := int(_equipment_view.get("capacity", 0))
	var coins := int(_equipment_view.get("coins", 0))
	var upgrade: Dictionary = _equipment_view.get("upgrade", {})
	if bool(upgrade.get("available", false)):
		var price := int(upgrade.get("price", 0))
		var buy := _detail_equipment_button(_equipment_detail, "扩容 %s→%s · %s 金币" % [capacity, int(upgrade.get("capacity", capacity)), price], func() -> void:
			gear_upgrade_requested.emit(int(_equipment_view.get("revision", 0)), int(_equipment_view.get("session", 0))))
		buy.name = "PurchaseGearUpgrade"
		buy.set_meta(&"focus_key", "gear_upgrade")
		buy.disabled = coins < price
		if buy.disabled: _label(_equipment_detail, str(upgrade.get("reason", "金币不足，暂时无法扩容。")), 14, MUTED)
	else:
		_label(_equipment_detail, str(upgrade.get("reason", "本局齿轮容量已达上限。")), 14, MUTED)
	if not _build.is_empty():
		var attributes := _label(_equipment_detail, _build, 15, MUTED)
		attributes.name = "EquipmentAttributes"
	_wire_equipment_focus.call_deferred()

func _detail_equipment_button(parent: Node, text: String, action: Callable) -> Button:
	var detail_generation := _equipment_detail_generation
	return _equipment_button(parent, text, func() -> void:
		if detail_generation == _equipment_detail_generation: action.call())

func _equipment_button(parent: Node, text: String, action: Callable) -> Button:
	var generation := _equipment_generation
	var revision := int(_equipment_view.get("revision", 0))
	var session := int(_equipment_view.get("session", 0))
	return _button(parent, text, func() -> void:
		if visible_panel == &"build" and generation == _equipment_generation and revision == int(_equipment_view.get("revision", 0)) and session == int(_equipment_view.get("session", 0)):
			action.call())

func _request_equipment(id: StringName, equip: bool) -> void:
	_equipment_focus_id = id
	var proposed := _equipped_ids()
	if equip:
		if not _replacement_id.is_empty(): proposed.erase(_replacement_id)
		if not id in proposed: proposed.append(id)
	else:
		proposed.erase(id)
	equipment_requested.emit(proposed, int(_equipment_view.get("revision", 0)), int(_equipment_view.get("session", 0)))

func _pause_navigation(active_page: StringName) -> void:
	var navigation := HBoxContainer.new()
	navigation.name = "PauseNavigation"
	navigation.add_theme_constant_override("separation", 8)
	_content.add_child(navigation)
	var previous := _button(navigation, "<", func() -> void: _switch_pause_page(-1))
	previous.name = "PagePrevious"
	previous.size_flags_horizontal = Control.SIZE_FILL
	previous.custom_minimum_size.x = 48
	previous.set_meta(&"ui_scale_min_width", true)
	previous.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pages := [{"id": &"build", "text": "背包", "name": "BuildPage"}, {"id": &"pause", "text": "旅途", "name": "PausePage"}, {"id": &"settings", "text": "设置", "name": "SettingsPage"}, {"id": &"help", "text": "帮助", "name": "HelpPage"}]
	for page: Dictionary in pages:
		var id: StringName = page.id
		var tab := _button(navigation, str(page.text), func() -> void: _show_pause_page(id))
		tab.name = str(page.name)
		if id == &"settings": tab.set_meta(&"ui_legacy_prefix", "SETTINGS")
		elif id == &"help": tab.set_meta(&"ui_legacy_prefix", "CONTROLS")
		tab.toggle_mode = true
		tab.button_pressed = active_page == id
		tab.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab.add_theme_font_size_override("font_size", 20)
		if id == &"build": tab.set_meta(&"ui_legacy_prefix", "YOUR BUILD")
	var next := _button(navigation, ">", func() -> void: _switch_pause_page(1))
	next.name = "PageNext"
	next.size_flags_horizontal = Control.SIZE_FILL
	next.custom_minimum_size.x = 48
	next.set_meta(&"ui_scale_min_width", true)
	next.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var resume := _button(navigation, "继续", close_panel)
	resume.name = "ResumeAdventure"
	resume.set_meta(&"ui_legacy_prefix", "RESUME")
	resume.size_flags_horizontal = Control.SIZE_FILL
	resume.custom_minimum_size.x = 112
	resume.set_meta(&"ui_scale_min_width", true)
	resume.alignment = HORIZONTAL_ALIGNMENT_CENTER

func _show_pause_page(page: StringName) -> void:
	match page:
		&"build": show_build(_build)
		&"pause": show_journey()
		&"settings": show_settings(true)
		&"help": show_help(true)

func _switch_pause_page(direction: int) -> void:
	if not _in_run or not visible_panel in PAUSE_PAGES: return
	var index := PAUSE_PAGES.find(visible_panel)
	_show_pause_page(PAUSE_PAGES[posmod(index + direction, PAUSE_PAGES.size())])

func _wire_equipment_focus() -> void:
	if visible_panel != &"build" or not is_instance_valid(_equipment_grid): return
	var action := _equipment_detail.get_node_or_null("EquipItem") as Control
	if action == null: action = _equipment_detail.get_node_or_null("UnequipItem") as Control
	for grid: GridContainer in [_equipped_grid, _equipment_grid]:
		if not is_instance_valid(grid): continue
		var buttons: Array[Control] = []
		for child: Node in grid.get_children():
			if child is Button: buttons.append(child)
		for index: int in buttons.size():
			var tile := buttons[index]
			var columns := grid.columns
			if index >= columns: tile.focus_neighbor_top = tile.get_path_to(buttons[index - columns])
			if index + columns < buttons.size(): tile.focus_neighbor_bottom = tile.get_path_to(buttons[index + columns])
			if index % columns > 0: tile.focus_neighbor_left = tile.get_path_to(buttons[index - 1])
			else: tile.focus_neighbor_left = tile.get_path_to(tile)
			if index % columns < columns - 1 and index + 1 < buttons.size(): tile.focus_neighbor_right = tile.get_path_to(buttons[index + 1])
			elif is_instance_valid(action): tile.focus_neighbor_right = tile.get_path_to(action)
	if is_instance_valid(action) and not _inventory_tiles.is_empty():
		for tile: Button in _inventory_tiles:
			if StringName(tile.get_meta(&"instance_id", &"")) == _selected_instance_id:
				action.focus_neighbor_left = action.get_path_to(tile)
				break

func close_panel() -> void:
	if _in_run:
		_hide()
		requested_resume.emit()
	elif _home_overlay:
		_close_home_overlay()
	else:
		show_title()

func _back() -> void:
	if visible_panel == &"continue":
		show_title()
	elif visible_panel == &"regions":
		show_home(_summary)
	elif visible_panel == &"debug_regions":
		show_home(_summary)
	elif not _in_run and _return_panel == &"home" and not _home_overlay:
		show_home(_summary)
	elif not _in_run and _return_panel == &"regions":
		show_region_select()
	elif _in_run:
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
	_title("要结束这次旅途吗？", "本局物品与金币将失去。已存入的音符与永久成长保留。")
	_button(_content, "KEEP PLAYING", close_panel)
	_button(_content, "LEAVE RUN", func() -> void:
		_hide()
		requested_home.emit())
	_focus_first()

func _hide() -> void:
	if visible_panel == &"build": build_closed.emit()
	_equipment_generation += 1
	home_function_id = &""
	if is_instance_valid(_scroll_touch): _scroll_touch.cancel(&"menu_hide")
	visible_panel = &""
	_page_generation += 1
	_root.hide()

func _begin(panel: StringName, in_run: bool) -> void:
	if visible_panel == &"build": build_closed.emit()
	_equipment_generation += 1
	home_function_id = &""
	_weapon_buttons.clear()
	var focused := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and _root.is_ancestor_of(focused):
		_focus_history[visible_panel] = str(focused.get_meta(&"focus_key", focused.name))
	if is_instance_valid(_scroll_touch): _scroll_touch.cancel(&"menu_replace")
	_page_generation += 1
	_in_run = in_run
	visible_panel = panel
	_equipment_body = null
	_equipment_left = null
	_equipment_detail = null
	_equipment_grid = null
	_equipped_grid = null
	_backpack_scroll = null
	_equipped_scroll = null
	_detail_scroll = null
	_inventory_tiles.clear()
	_title_label = null
	_title_secondary = null
	_home_shell = null
	_clock = null
	_footer = null
	for child: Node in _root.get_children():
		_root.remove_child(child)
		child.queue_free()
	_root.show()
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.025, 0.045, 0.046, 0.88) if in_run else Color("101f20")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(backdrop)
	if not in_run and not _home_overlay and panel != &"title":
		var painted := TextureRect.new()
		painted.texture = load("res://assets/underworld_plains/backgrounds/far.png")
		painted.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		painted.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		painted.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		painted.modulate = Color(0.28, 0.36, 0.32, 1)
		painted.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(painted)
		var veil := TextureRect.new()
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0.035, 0.075, 0.075, 0.94))
		gradient.set_color(1, Color(0.035, 0.075, 0.075, 0.14))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill_from = Vector2.ZERO
		texture.fill_to = Vector2.RIGHT
		veil.texture = texture
		veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(veil)
	if panel == &"title":
		var title_backdrop := preload("res://scripts/ui/demo_ui_01/title_backdrop.gd").new()
		title_backdrop.name = "TitleBackdrop"
		title_backdrop.reduced_effects = _reduced_effects
		_root.add_child(title_backdrop)
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_margin)
	var centered: Container
	if panel == &"title":
		centered = VBoxContainer.new()
	else:
		centered = CenterContainer.new()
	_margin.add_child(centered)
	_frame = PanelContainer.new()
	if panel == &"title":
		_frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if panel == &"title": _frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	centered.add_child(_frame)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = panel != &"build"
	if panel == &"build": _scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_frame.add_child(_scroll)
	_scroll_touch = SCROLL_TOUCH_ADAPTER.new()
	_scroll_touch.scroll = _scroll
	_scroll.add_child(_scroll_touch)
	_padding = MarginContainer.new()
	_padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if panel == &"build": _padding.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_padding)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if panel == &"build": _content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	_padding.add_child(_content)
	if panel not in [&"title", &"build"]:
		var ribbon := HBoxContainer.new()
		ribbon.add_theme_constant_override("separation", 12)
		_content.add_child(ribbon)
		var seal := TextureRect.new()
		seal.texture = UnderworldUI.icon(&"meta_note")
		seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		seal.custom_minimum_size = Vector2(26, 26)
		seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ribbon.add_child(seal)
		var ribbon_title := _label(ribbon, "失序之钟", 14, GOLD)
		ribbon_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer = Label.new()
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.clip_text = true
	_footer.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_footer.add_theme_font_size_override("font_size", 12)
	_footer.add_theme_color_override("font_color", MUTED)
	_footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_footer.offset_left = 48
	_footer.offset_right = -48
	_footer.offset_top = -30
	_footer.offset_bottom = -10
	_root.add_child(_footer)
	_layout_menu()
	if in_run: menu_opened.emit()

func _layout_menu() -> void:
	if not is_instance_valid(_scroll) or visible_panel.is_empty(): return
	var viewport := get_viewport().get_visible_rect().size
	_last_viewport = viewport
	_last_screen_transform = get_viewport().get_screen_transform()
	_last_window_size = get_window().size
	_last_layout_device = _menu_device
	var screen_scale := _last_screen_transform.get_scale().abs()
	var pixel_scale := maxf(0.01, minf(screen_scale.x, screen_scale.y))
	var physical_size := viewport * screen_scale
	var compact := physical_size.x < 1000 or physical_size.y < 600
	var safe := Rect2(Vector2.ZERO, viewport)
	if OS.has_feature("android") or OS.has_feature("ios"):
		var physical := DisplayServer.get_display_safe_area()
		if physical.has_area():
			var screen_transform := get_viewport().get_screen_transform().affine_inverse()
			var origin := Vector2(DisplayServer.window_get_position())
			var start := screen_transform * (Vector2(physical.position) - origin)
			var finish := screen_transform * (Vector2(physical.end) - origin)
			safe = Rect2(start, finish - start).intersection(safe)
	var title_page := visible_panel == &"title"
	var side := 52 if physical_size.x >= 1000 else 22
	var top := 42 if physical_size.y >= 650 else 18
	_margin.add_theme_constant_override("margin_left", side + roundi(safe.position.x))
	_margin.add_theme_constant_override("margin_right", side + roundi(viewport.x - safe.end.x))
	_margin.add_theme_constant_override("margin_top", top + roundi(safe.position.y))
	_margin.add_theme_constant_override("margin_bottom", top + roundi(viewport.y - safe.end.y))
	var frame_inset := _frame.get_theme_stylebox("panel").get_minimum_size()
	var available_width := maxf(120, safe.size.x - side * 2 - frame_inset.x)
	var width := available_width if compact or visible_panel == &"build" else minf(360 if title_page else 790, available_width)
	if title_page: width = minf(available_width, 360.0 / minf(1.0, pixel_scale))
	var footer_reserve := 38.0 / pixel_scale if compact else 18.0
	var height := maxf(100, safe.size.y - top * 2 - footer_reserve - frame_inset.y)
	_scroll.custom_minimum_size = Vector2(width, height if visible_panel == &"build" else minf(640, height))
	_scroll.size = _scroll.custom_minimum_size
	var padding := 0 if title_page else (18 if visible_panel == &"build" else 26 if physical_size.x >= 900 else 16)
	for edge: String in ["left", "right", "top", "bottom"]: _padding.add_theme_constant_override("margin_" + edge, padding)
	if is_instance_valid(_title_label): _title_label.set_meta(&"ui_base_font_size", 36 if title_page else 24)
	if is_instance_valid(_title_secondary): _title_secondary.columns = 2 if physical_size.x >= 500 else 1
	if is_instance_valid(_home_shell): _home_shell.columns = 2 if physical_size.x >= 900 else 1
	_apply_physical_metrics(pixel_scale, compact)
	if visible_panel == &"build": _layout_inventory(pixel_scale, height - 2 * padding)
	if is_instance_valid(_footer):
		var footer_font := _footer.get_theme_font("font")
		var footer_font_size := _footer.get_theme_font_size("font_size")
		var bottom := 10.0 / pixel_scale if compact else 10.0
		_footer.offset_left = safe.position.x + side
		_footer.offset_right = -(viewport.x - safe.end.x + side)
		_footer.offset_bottom = -(viewport.y - safe.end.y + bottom)
		_footer.offset_top = _footer.offset_bottom - footer_font.get_height(footer_font_size) - 4.0 / pixel_scale
	if is_instance_valid(_clock):
		_clock.visible = physical_size.x >= 1000 and physical_size.y >= 600
		_clock.position = Vector2(viewport.x * 0.48, maxf(6, viewport.y * 0.16))
		_clock.size = Vector2(viewport.x * 0.43, viewport.y * 0.78)
		_clock.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# Children are rebuilt synchronously after a transaction. Their temporary
	# minimums can expand an anchored MarginContainer; reclaim the viewport
	# once the final grid columns and no-wrap header have been established.
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_update_device_hint()

func _layout_inventory(pixel_scale: float, available_height: float) -> void:
	if not is_instance_valid(_equipment_body) or not is_instance_valid(_equipment_grid): return
	var tile_size := 72.0 / minf(1.0, pixel_scale)
	var content_width := maxf(240, _scroll.custom_minimum_size.x - 36)
	var left_width := (content_width - 40) * 1.65 / 2.65
	var columns := maxi(3, floori((left_width + 8) / (tile_size + 8)))
	_equipment_grid.columns = columns
	_equipped_grid.columns = columns
	_equipped_scroll.custom_minimum_size.y = tile_size + 10
	_backpack_scroll.custom_minimum_size.y = tile_size + 10
	for tile: Button in _inventory_tiles:
		if not is_instance_valid(tile): continue
		tile.custom_minimum_size = Vector2(tile_size, tile_size)
		tile.set_meta(&"ui_base_minimum", Vector2(tile_size, tile_size))
	_equipment_body.custom_minimum_size.y = maxf(260, available_height - 64.0 / minf(1.0, pixel_scale))
	_wire_equipment_focus()

func _apply_physical_metrics(pixel_scale: float, compact: bool) -> void:
	# The project keeps a 1280x720 logical canvas on small windows. Preserve
	# authored metrics and derive each layout from them; never multiply a prior
	# resize result. The minimum targets below are actual rendered pixels.
	var font_factor := clampf(1.0 / pixel_scale, 1.0, 1.8) if compact else 1.0
	var targets: Array[Control] = []
	for node: Node in _content.find_children("*", "Control", true, false):
		if node is Control: targets.append(node)
	if is_instance_valid(_footer): targets.append(_footer)
	for control: Control in targets:
		if not control.has_meta(&"ui_base_minimum"):
			control.set_meta(&"ui_base_minimum", control.custom_minimum_size)
		var authored_minimum: Vector2 = control.get_meta(&"ui_base_minimum")
		if control is BaseButton or control is Range or control is LineEdit:
			control.custom_minimum_size = Vector2(authored_minimum.x, maxf(authored_minimum.y, 48.0 / pixel_scale))
		if control is Label or control is BaseButton or control is LineEdit:
			if not control.has_meta(&"ui_base_font_size"):
				control.set_meta(&"ui_base_font_size", control.get_theme_font_size("font_size"))
			var authored_font: int = control.get_meta(&"ui_base_font_size")
			var font_size := maxi(authored_font, ceili(maxf(authored_font * font_factor, 14.0 / pixel_scale))) if compact else authored_font
			control.add_theme_font_size_override("font_size", font_size)
			if control.get_meta(&"ui_scale_min_width", false):
				control.custom_minimum_size.x = authored_minimum.x * font_factor
			if control is OptionButton:
				var popup := (control as OptionButton).get_popup()
				popup.add_theme_font_size_override("font_size", font_size)
				var font_height := popup.get_theme_font("font").get_height(font_size)
				popup.add_theme_constant_override("v_separation", maxi(8, ceili(48.0 / pixel_scale - font_height)))
	_content.add_theme_constant_override("separation", ceili((6.0 if visible_panel == &"title" else 12.0) / pixel_scale) if compact else 12)

func _process(_delta: float) -> void:
	if visible_panel == &"build" and is_instance_valid(_margin):
		# A transaction replaces children while container minimums are dirty.
		# Godot expands an anchored MarginContainer for that transient minimum,
		# but retains the expanded size after it shrinks. Reclaim FullRect only
		# when the final real minimum fits; genuine overflow remains detectable.
		var viewport_size := get_viewport().get_visible_rect().size
		var minimum := _margin.get_combined_minimum_size()
		if _margin.size != viewport_size and minimum.x <= viewport_size.x and minimum.y <= viewport_size.y:
			_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not visible_panel.is_empty() and (get_viewport().get_visible_rect().size != _last_viewport or get_viewport().get_screen_transform() != _last_screen_transform or get_window().size != _last_window_size or _menu_device != _last_layout_device):
		_layout_menu()

func _update_device_hint() -> void:
	if not is_instance_valid(_footer): return
	match _menu_device:
		&"gamepad": _footer.text = "方向键 选择 · A 确认 · B 返回 · LB/RB 切页" if _in_run else "左摇杆 / 十字键  选择     A  确认     B  返回"
		&"touch": _footer.text = "轻触图标查看 · 滑动背包 · 顶部箭头切页" if visible_panel == &"build" else "轻触选择 · 滑动长页面"
		_: _footer.text = "鼠标 / 方向键 选择 · Enter 确认 · Q/E 切页 · Esc 继续" if _in_run else "鼠标 / 方向键  选择     Enter  确认     Esc  返回"

func _input(event: InputEvent) -> void:
	if visible_panel.is_empty(): return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and absf(event.axis_value) < 0.35: return
		_menu_device = &"gamepad"
	elif event is InputEventScreenTouch or event is InputEventScreenDrag: _menu_device = &"touch"
	elif event is InputEventKey or (event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION): _menu_device = &"keyboard_mouse"
	_update_device_hint()
	if _in_run and visible_panel in PAUSE_PAGES:
		var direction := 0
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_Q: direction = -1
			elif event.physical_keycode == KEY_E: direction = 1
		elif event is InputEventJoypadButton and event.pressed:
			if event.button_index == JOY_BUTTON_LEFT_SHOULDER: direction = -1
			elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER: direction = 1
		if direction != 0:
			_switch_pause_page(direction)
			get_viewport().set_input_as_handled()

func _slider(key: String, title: String, minimum: float, maximum: float, step: float) -> void:
	var row := HBoxContainer.new()
	_content.add_child(row)
	var label := _label(row, title, 16, TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var readout := _label(row, "", 16, TEAL)
	readout.custom_minimum_size.x = 56
	readout.set_meta(&"ui_scale_min_width", true)
	var slider := HSlider.new()
	slider.set_meta(&"focus_key", key)
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = float(_values.get(key, _defaults.get(key, minimum)))
	slider.custom_minimum_size.y = 48
	slider.set_meta(&"focus_key", key)
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

func _label(parent: Node, text: String, font_size: int, color: Color, wrap := true) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", font_size)
	label.set_meta(&"ui_base_font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.text = text
	button.clip_text = true
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.set_meta(&"focus_key", text)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var generation := _page_generation
	button.pressed.connect(func() -> void:
		if generation == _page_generation and is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled:
			action.call())
	parent.add_child(button)
	return button

func _space(parent: Node, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	parent.add_child(spacer)

func _focus_first() -> void:
	_layout_menu()
	# Opening the build can synchronously refresh its contents. Coalesce those
	# requests and restore the latest page, rather than enqueueing two restores.
	_focus_restore_generation = _page_generation
	if _focus_restore_queued: return
	_focus_restore_queued = true
	_flush_focus_restore.call_deferred()

func _flush_focus_restore() -> void:
	_focus_restore_queued = false
	_restore_focus(_focus_restore_generation)

func _restore_focus(generation: int) -> void:
	if generation != _page_generation or visible_panel.is_empty(): return
	var controls: Array[Control] = []
	for node: Node in _content.find_children("*", "Control", true, false):
		if node is Control and node.focus_mode == Control.FOCUS_ALL and node.is_visible_in_tree() and not (node is BaseButton and node.disabled):
			controls.append(node)
	if controls.is_empty(): return
	var wanted := str(_focus_history.get(visible_panel, ""))
	var target := controls[0]
	for i: int in controls.size():
		var control := controls[i]
		control.focus_neighbor_top = control.get_path_to(controls[(i + controls.size() - 1) % controls.size()])
		control.focus_neighbor_bottom = control.get_path_to(controls[(i + 1) % controls.size()])
		control.focus_previous = control.focus_neighbor_top
		control.focus_next = control.focus_neighbor_bottom
		control.focus_neighbor_left = control.get_path_to(control) if control is Range or control is OptionButton else control.focus_neighbor_top
		control.focus_neighbor_right = control.get_path_to(control) if control is Range or control is OptionButton else control.focus_neighbor_bottom
		if str(control.get_meta(&"focus_key", control.name)) == wanted: target = control
	if visible_panel == &"build": _wire_equipment_focus()
	target.grab_focus()
	# Containers settle after this deferred callback. Scrolling against the
	# pre-layout rectangle can open a long page at its bottom with focus offscreen.
	# A second refresh can arrive after the deferred restore but before the
	# next process frame. Replace that pending scroll with the newest target.
	if _focus_scroll_callback.is_valid() and get_tree().process_frame.is_connected(_focus_scroll_callback):
		get_tree().process_frame.disconnect(_focus_scroll_callback)
	_focus_scroll_callback = _finish_focus_scroll.bind(generation, weakref(target), wanted)
	get_tree().process_frame.connect(_focus_scroll_callback, CONNECT_ONE_SHOT)

func _finish_focus_scroll(generation: int, target_ref: WeakRef, wanted: String) -> void:
	_focus_scroll_callback = Callable()
	# The bound method is disconnected when this menu is freed. A suspended
	# coroutine would still resume after owner teardown during scene changes.
	var target := target_ref.get_ref() as Control
	if generation == _page_generation and is_instance_valid(target) and is_instance_valid(_scroll):
		if wanted.is_empty() or (visible_panel == &"title" and target.name == "BeginAdventure"):
			_scroll.scroll_vertical = 0
		else:
			# A disabled outer shell is not a scroller. Godot's direct ensure API
			# still changes its offsets, pushing a fixed two-column panel away.
			var ancestor := target.get_parent()
			while ancestor != null and ancestor != _root:
				if ancestor is ScrollContainer and ancestor.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
					ancestor.ensure_control_visible(target)
				ancestor = ancestor.get_parent()

func _unhandled_input(event: InputEvent) -> void:
	if visible_panel.is_empty():
		return
	if event.is_action_pressed("ui_cancel"):
		if visible_panel in [&"build", &"pause", &"confirm_home"]:
			close_panel()
		elif visible_panel in [&"home_function", &"run_end"] or (visible_panel == &"home" and _home_overlay):
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
