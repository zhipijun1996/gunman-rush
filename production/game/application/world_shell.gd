class_name WorldShell
extends Node
## The title owns the playable save slot. Each trip from title to world owns
## one WorldGameHost, whose ordinary room transitions remain independent.
signal page_changed(value: StringName)
signal world_started(host: WorldGameHost)
signal world_closed

const WORLD := preload("res://rooms/world/world.tscn")
const BACKDROP := preload("res://game/presentation/ui/demo_ui_01/title_backdrop.gd")
const SCROLL_TOUCH := preload("res://game/presentation/ui/menu_scroll_touch_adapter.gd")
const CLOCK := preload("res://game/presentation/ui/demo_ui_01/clockwork_theme.gd")
var world: WorldGameHost
var storage: PlayableWorldSave
var page: StringName
var page_host := Control.new()
var menu: VBoxContainer
var notice: Label
var subpage: Control
var _return_page: StringName
var _map_from_pause := false
var _focus_history := {}
var _buttons: Array[Button] = []
var _starting_world := false

# Prepare a real fresh room before replacing a real save. Nothing in this
# temporary slot can reach disk. A rejected write leaves the old slot usable.
class FreshSlot extends PlayableWorldSave:
	func load_profile() -> Dictionary:
		return {"accepted":true,"payload":{},"revision":0}
	func commit(_value: Dictionary, _revision: int) -> bool:
		return true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if storage == null:
		storage = PlayableWorldSave.new()
		storage.configure_world()
	var layer := CanvasLayer.new()
	layer.layer = 105
	add_child(layer)
	page_host.name = "Pages"
	layer.add_child(page_host)
	page_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_host.theme = CLOCK.create_theme()
	WorldSettings.current()
	PlayableWorldAudio.mount(self)
	preload("res://game/platform/input/world_shell_input.gd").mount(self)
	show_title()

func _clear(next: StringName) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus is Button and page_host.is_ancestor_of(focus):
		_focus_history[page] = str(focus.name)
	for child: Node in page_host.get_children():
		page_host.remove_child(child)
		child.queue_free()
	_buttons.clear()
	subpage = null
	notice = null
	page = next
	page_host.visible = next not in [&"play",&"map"]
	if world != null:
		var hud: Node = world.get("game_hud")
		if hud != null: hud.set_overlay_hidden(page != &"play")
	page_changed.emit(page)

func _backdrop() -> void:
	if world == null:
		var art := BACKDROP.new()
		art.name = "TitleBackdrop"
		art.reduced_effects = WorldSettings.current().value.reduced
		page_host.add_child(art)
	else:
		var shade := ColorRect.new()
		shade.color = Color(.025,.045,.046,.84)
		page_host.add_child(shade)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _frame(heading: String, description := "", title := false) -> void:
	_backdrop()
	var margin := MarginContainer.new()
	page_host.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout: Container = VBoxContainer.new() if title else CenterContainer.new()
	margin.add_child(layout)
	var panel := PanelContainer.new()
	layout.add_child(panel)
	if title:
		panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	var max_width := 360.0 if title else (770.0 if page == &"help" else 520.0)
	var fit := _layout_frame.bind(margin,scroll,max_width)
	margin.resized.connect(fit)
	fit.call()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	var scroll_touch := SCROLL_TOUCH.new()
	scroll_touch.scroll = scroll
	scroll.add_child(scroll_touch)
	menu = VBoxContainer.new()
	scroll.add_child(menu)
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.add_theme_constant_override("separation",10)
	menu.add_child(CLOCK.label(heading,36 if title else 28))
	if not description.is_empty(): menu.add_child(CLOCK.label(description,18,CLOCK.MUTED))

func _layout_frame(margin: MarginContainer, scroll: ScrollContainer, width: float) -> void:
	var view := get_viewport().get_visible_rect().size
	var safe := Rect2(Vector2.ZERO,view)
	if OS.has_feature("android") or OS.has_feature("ios"):
		var area := DisplayServer.get_display_safe_area()
		if area.has_area():
			var to_canvas := get_viewport().get_screen_transform().affine_inverse()
			var origin := Vector2(DisplayServer.window_get_position())
			var start := to_canvas*(Vector2(area.position)-origin)
			var end := to_canvas*(Vector2(area.end)-origin)
			safe = Rect2(start,end-start).intersection(safe)
	var side := 52 if safe.size.x >= 1000 else 22
	var top := 42 if safe.size.y >= 650 else 18
	margin.add_theme_constant_override("margin_left",side+roundi(safe.position.x))
	margin.add_theme_constant_override("margin_top",top+roundi(safe.position.y))
	margin.add_theme_constant_override("margin_right",side+roundi(view.x-safe.end.x))
	margin.add_theme_constant_override("margin_bottom",top+roundi(view.y-safe.end.y))
	scroll.custom_minimum_size = Vector2(clampf(safe.size.x-2*side-48,100,width),clampf(safe.size.y-2*top-54,100,620))

func _button(id: String, label: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.name = id
	button.text = label
	button.custom_minimum_size.y = 62 if page == &"title" else 52
	if primary: button.theme_type_variation = &"PrimaryButton"
	button.pressed.connect(callback)
	menu.add_child(button)
	_buttons.append(button)
	return button

func _focus(default_id := "") -> void:
	var enabled := _buttons.filter(func(button: Button) -> bool: return not button.disabled)
	if enabled.is_empty(): return
	var first := enabled[0] as Button
	var id: String = _focus_history.get(page,default_id)
	for i: int in enabled.size():
		var button := enabled[i] as Button
		var above := enabled[posmod(i-1,enabled.size())] as Button
		var below := enabled[(i+1)%enabled.size()] as Button
		button.focus_neighbor_top = button.get_path_to(above)
		button.focus_neighbor_bottom = button.get_path_to(below)
		if button.name == id: first = button
	first.grab_focus()

func _message(text: String) -> void:
	if not is_instance_valid(notice):
		notice = CLOCK.label("",17,CLOCK.MUTED)
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		menu.add_child(notice)
	notice.text = text

func show_title() -> void:
	_clear(&"title")
	_frame("失序之钟","风铃未息，旅途再启。",true)
	_button("BeginAdventure","新游戏",request_new_game,true)
	var saved := storage.startup_room()
	var continue_button := _button("ContinueAdventure","继续游戏",continue_game)
	continue_button.disabled = not saved.ok or not saved.get("has_save",false)
	_button("Settings","设定",open_settings)
	_button("Help","操作说明",open_help)
	if not saved.ok: _message("无法读取当前存档。可重试读取，或确认开始新游戏。")
	if not saved.ok: _button("Retry","重新读取存档",show_title)
	_focus("BeginAdventure")

func request_new_game() -> void:
	var saved := storage.startup_room()
	if saved.ok and not saved.has_save and world == null:
		_start(true)
		return
	_return_page = &"map" if world != null and world.route_map.visible else page
	if _return_page == &"map":
		_map_from_pause = world.route_map.was_paused
		world.route_map.hide()
	get_tree().paused = world != null
	_clear(&"confirm")
	_frame("开始新的旅途？","这会替换当前世界存档，用户设置保留。")
	_button("KeepProgress","保留进度",_cancel_replacement,true)
	_button("ReplaceProgress","确认新游戏",func(): _start(true))
	_focus_history.erase(&"confirm")
	_focus("KeepProgress")

func _cancel_replacement() -> void:
	if world == null:
		show_title()
	elif _return_page == &"map":
		if _map_from_pause: _open_pause_map()
		else:
			resume_world()
			world.route_map.open()
	else:
		_pause_menu()

func continue_game() -> void:
	var saved := storage.startup_room()
	if not saved.ok or not saved.get("has_save",false):
		show_title()
		_message("未能读取可继续的世界存档。")
		return
	_start(false)

func _start(fresh: bool) -> void:
	if _starting_world: return
	_starting_world = true
	var candidate := WORLD.instantiate() as WorldGameHost
	candidate.process_mode = Node.PROCESS_MODE_PAUSABLE
	candidate.request_new_game = request_new_game
	candidate.storage = FreshSlot.new() if fresh else storage
	add_child(candidate)
	var ready_world := candidate.active != null
	if ready_world and fresh: ready_world = _save_new_world(candidate)
	if not ready_world:
		remove_child(candidate)
		candidate.queue_free()
		if world != null: world.follow_camera.make_current()
		_message("无法打开或写入世界进度。请检查存储后重试。")
		_starting_world = false
		return
	if world != null: _release_world()
	world = candidate
	world.room_changed.connect(_settings_for_room)
	world.route_map.closed.connect(_map_closed)
	_settings_for_room(world.active.room.room_id)
	world_started.emit(world)
	resume_world()
	_starting_world = false

func _save_new_world(candidate: WorldGameHost) -> bool:
	if not storage.profile_id.is_valid_identifier(): return false
	var state := candidate.active.state
	var previous_version := storage.content_version
	var previous_validator := storage.payload_validator
	var previous_block := storage.blocked
	storage.content_version = state.content.data.content_version
	storage.payload_validator = state.valid
	storage.blocked = false
	state.storage = storage
	if state.commit(state.candidate(),state.revision):
		candidate.storage = storage
		return true
	storage.content_version = previous_version
	storage.payload_validator = previous_validator
	storage.blocked = previous_block
	return false

func _settings_for_room(_id: String) -> void:
	WorldSettings.current().apply_session(world.active)

func open_pause() -> void:
	if page != &"play" or world == null or get_tree().paused or world.crossing: return
	if not world.active.controller.active or world.active.controller.has_pending_damage(): return
	world.active.controller.router.clear("world_pause")
	get_tree().paused = true
	_pause_menu()

func _pause_menu() -> void:
	_clear(&"pause")
	_frame("片刻停驻","钟摆停下，旅途仍在。")
	_button("Resume","继续探索",resume_world,true)
	_button("Map","世界地图",_open_pause_map)
	_button("Equipment","背包与装配",func(): resume_world(); world.active.equipment_menu.open("select"))
	_button("Settings","设定",open_settings)
	_button("Help","操作说明",open_help)
	_button("SaveAndTitle","保存并返回标题",return_title)
	_focus("Resume")

func _open_pause_map() -> void:
	_clear(&"map")
	world.route_map.open(true)

func _map_closed() -> void:
	if page == &"map": _pause_menu()

func resume_world() -> void:
	if world == null: return
	get_viewport().gui_release_focus()
	world.active.controller.router.clear("world_resume")
	var keyboard := world.active.player.get_node_or_null("KeyboardMouseAdapter") as KeyboardMouseAdapter
	if keyboard != null: keyboard.observe_current_key_neutral()
	get_tree().paused = false
	_clear(&"play")

func return_title() -> void:
	if world == null or page != &"pause": return
	if not world.active.checkpoint():
		_message("保存失败，仍保留当前房间。请检查存储后重试。")
		return
	_release_world()
	get_tree().paused = false
	show_title()

func _release_world() -> void:
	var previous := world
	if storage.payload_validator.get_object() == previous.active.state:
		storage.payload_validator = Callable()
	world = null
	world_closed.emit()
	remove_child(previous)
	previous.queue_free()

func open_settings() -> void:
	_return_page = page
	_clear(&"settings")
	_backdrop()
	subpage = preload("res://game/presentation/ui/world/world_settings_view.gd").mount(page_host,close_subpage)

func open_help() -> void:
	_return_page = page
	_clear(&"help")
	_frame("操作说明")
	menu.add_child(preload("res://game/presentation/ui/controls/control_guide.gd").build(self))
	var back := _button("Back","返回",close_subpage)
	back.grab_focus()

func close_subpage() -> void:
	if world == null: show_title()
	else: _pause_menu()

func handle_back() -> void:
	match page:
		&"play":
			if world.route_map.visible:
				world.route_map.close()
			elif world.active.equipment_menu.panel.visible: world.active.equipment_menu.close()
			elif world.active.sign_reader != null and world.active.sign_reader.reading: world.active.sign_reader.close()
			else: open_pause()
		&"map": world.route_map.close()
		&"pause": resume_world()
		&"settings":
			if subpage != null and subpage.has_method("request_back"): subpage.request_back()
			else: close_subpage()
		&"help": close_subpage()
		&"confirm": _cancel_replacement()
