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
signal requested_retry
signal requested_home
signal settings_changed(values: Dictionary)
signal menu_opened
signal presentation_changed(reduced_effects: bool, muted: bool)

const INK := DemoClockworkTheme.INK
const CARD := DemoClockworkTheme.PANEL
const TEAL := DemoClockworkTheme.TEAL
const GOLD := DemoClockworkTheme.BRASS
const TEXT := DemoClockworkTheme.PAPER
const MUTED := DemoClockworkTheme.MUTED
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
	requested_plains.emit("level-design-v2-baseline/08")

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
	_build = build_description
	_build_items=items
	_begin(&"pause", true)
	_title("片刻停驻", "钟摆停下，旅途仍在。")
	_pause_navigation(&"pause")
	var resume := _button(_content, "RESUME / 继续旅途", close_panel)
	resume.theme_type_variation = &"PrimaryButton"
	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 12)
	_content.add_child(actions)
	_button(actions, "SETTINGS", func() -> void: show_settings(true))
	_button(actions, "CONTROLS", func() -> void: show_help(true))
	_button(_content, "RETURN TO HOME", _confirm_home)
	if not _focus_history.has(&"pause"): _focus_history[&"pause"] = "RESUME / 继续旅途"
	_focus_first()

func show_settings(in_run: bool = false) -> void:
	if visible_panel not in [&"settings", &"help"]: _return_panel = visible_panel
	_begin(&"settings", in_run)
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
	_title("旅途行囊", "本局已获得的物品与真实属性。")
	_pause_navigation(&"build")
	_label(_content, text if not text.is_empty() else "No items yet. Look for marked caches on optional routes.", 20, TEXT)
	var unique: Dictionary={}
	for item: ItemDefinition in _build_items:
		if unique.has(item.stable_id): unique[item.stable_id].count+=1
		else: unique[item.stable_id]={"item":item,"count":1}
	if not unique.is_empty():
		var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(0,290);_content.add_child(scroll)
		var cards:=HBoxContainer.new();cards.add_theme_constant_override("separation",12);scroll.add_child(cards)
		for entry: Dictionary in unique.values():
			var card:=ItemCard.new();card.item=entry.item;card.count=entry.count;cards.add_child(card)
	_button(_content, "BACK", _back)
	if not _focus_history.has(&"build"): _focus_history[&"build"] = "行囊"
	_focus_first()

func _pause_navigation(active_page: StringName) -> void:
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 10)
	_content.add_child(navigation)
	var pause_tab := _button(navigation, "暂停", func() -> void: show_pause(_build, _build_items))
	pause_tab.name = "PausePage"
	pause_tab.toggle_mode = true
	pause_tab.button_pressed = active_page == &"pause"
	var build_tab := _button(navigation, "行囊", func() -> void: show_build(_build))
	build_tab.name = "BuildPage"
	build_tab.set_meta(&"ui_legacy_prefix", "YOUR BUILD")
	build_tab.toggle_mode = true
	build_tab.button_pressed = active_page == &"build"
	var equipment := _button(navigation, "装备", Callable())
	equipment.name = "EquipmentNotImplemented"
	equipment.disabled = true
	equipment.tooltip_text = "装备分页尚未开放。"
	_label(_content, "装备分页尚未开放；当前可查看本局行囊。", 14, MUTED)

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
	if is_instance_valid(_scroll_touch): _scroll_touch.cancel(&"menu_hide")
	visible_panel = &""
	_page_generation += 1
	_root.hide()

func _begin(panel: StringName, in_run: bool) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and _root.is_ancestor_of(focused):
		_focus_history[visible_panel] = str(focused.get_meta(&"focus_key", focused.name))
	if is_instance_valid(_scroll_touch): _scroll_touch.cancel(&"menu_replace")
	_page_generation += 1
	_in_run = in_run
	visible_panel = panel
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
	_scroll.follow_focus = true
	_frame.add_child(_scroll)
	_scroll_touch = SCROLL_TOUCH_ADAPTER.new()
	_scroll_touch.scroll = _scroll
	_scroll.add_child(_scroll_touch)
	_padding = MarginContainer.new()
	_padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_padding)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	_padding.add_child(_content)
	if panel != &"title":
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
	var width := available_width if compact else minf(360 if title_page else 640 if visible_panel in [&"pause", &"build"] else 790, available_width)
	if title_page: width = minf(available_width, 360.0 / minf(1.0, pixel_scale))
	var footer_reserve := 38.0 / pixel_scale if compact else 18.0
	var height := maxf(100, safe.size.y - top * 2 - footer_reserve - frame_inset.y)
	_scroll.custom_minimum_size = Vector2(width, minf(640, height))
	_scroll.size = _scroll.custom_minimum_size
	var padding := 0 if title_page else (26 if physical_size.x >= 900 else 16)
	for edge: String in ["left", "right", "top", "bottom"]: _padding.add_theme_constant_override("margin_" + edge, padding)
	if is_instance_valid(_title_label): _title_label.set_meta(&"ui_base_font_size", 36 if title_page else 24)
	if is_instance_valid(_title_secondary): _title_secondary.columns = 2 if physical_size.x >= 500 else 1
	if is_instance_valid(_home_shell): _home_shell.columns = 2 if physical_size.x >= 900 else 1
	_apply_physical_metrics(pixel_scale, compact)
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
	_update_device_hint()

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
	if not visible_panel.is_empty() and (get_viewport().get_visible_rect().size != _last_viewport or get_viewport().get_screen_transform() != _last_screen_transform or get_window().size != _last_window_size or _menu_device != _last_layout_device):
		_layout_menu()

func _update_device_hint() -> void:
	if not is_instance_valid(_footer): return
	match _menu_device:
		&"gamepad": _footer.text = "左摇杆 / 十字键  选择     A  确认     B  返回"
		&"touch": _footer.text = "轻触选择 · 滑动长页面"
		_: _footer.text = "鼠标 / 方向键  选择     Enter  确认     Esc  返回"

func _input(event: InputEvent) -> void:
	if visible_panel.is_empty(): return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and absf(event.axis_value) < 0.35: return
		_menu_device = &"gamepad"
	elif event is InputEventScreenTouch or event is InputEventScreenDrag: _menu_device = &"touch"
	elif event is InputEventKey or (event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION): _menu_device = &"keyboard_mouse"
	_update_device_hint()

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

func _label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_restore_focus.call_deferred(_page_generation)

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
	target.grab_focus()
	# Containers settle after this deferred callback. Scrolling against the
	# pre-layout rectangle can open a long page at its bottom with focus offscreen.
	await get_tree().process_frame
	if generation == _page_generation and is_instance_valid(target) and is_instance_valid(_scroll):
		if wanted.is_empty() or (visible_panel == &"title" and target.name == "BeginAdventure"): _scroll.scroll_vertical = 0
		else: _scroll.ensure_control_visible(target)

func _unhandled_input(event: InputEvent) -> void:
	if visible_panel.is_empty():
		return
	if event.is_action_pressed("ui_cancel"):
		if visible_panel == &"pause" or visible_panel == &"confirm_home":
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
