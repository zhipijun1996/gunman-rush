class_name PlainsRegionMapModal
extends CanvasLayer
## The existing fog-map canvas remains the sole exploration/projection consumer.
signal closed
const TOUCH_SCROLL := preload("res://scripts/ui/menu_scroll_touch_adapter.gd")
const METRICS := preload("res://scripts/ui/demo_ui_01/modal_metrics.gd")
var opened := false
var canvas: PlainsRegionMap
var _root: Control
var _controls: GridContainer
var _controls_scroll: ScrollContainer
var _touch_adapter: Node
var _prior_focus: WeakRef
var _pan_axis := Vector2.ZERO
var _closing := false
var _margin: MarginContainer
var _rows: VBoxContainer
var _layout_signature: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40

func show_map(stage: PlainsRegionStage) -> void:
	close()
	opened = true
	_closing = false
	var previous := get_viewport().gui_get_focus_owner()
	if previous != null: _prior_focus = weakref(previous)
	_root = Control.new()
	_root.theme = DemoClockworkTheme.create_theme()
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.055, 0.06, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_margin)
	var rows := VBoxContainer.new()
	_rows = rows
	rows.add_theme_constant_override("separation", 12)
	_margin.add_child(rows)
	var region_name := "THORN FOREST / 荆棘森林" if stage is ThornForestRegionStage else "WINDCHIME PLAINS / 风铃平原"
	var heading := DemoClockworkTheme.label(region_name + "  ·  MAP %s OF 2" % stage.map_index, 24)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(heading)
	if not stage.visited_area.is_empty():
		var location := DemoClockworkTheme.label("当前位置 / " + stage.visited_area, 17, DemoClockworkTheme.BRASS)
		location.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.add_child(location)
	var help := DemoClockworkTheme.label("迷雾：未探索   ·   亮点：你   ·   B 首领 / C 营地 / * 奖励", 14, DemoClockworkTheme.MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(help)
	canvas = PlainsRegionMap.new()
	canvas.name = "ExplorationCanvas"
	canvas.expanded = true
	canvas.stage = stage
	canvas.custom_minimum_size = Vector2(0, 96)
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(canvas)
	# Expanded map pointer gestures remain active; GUI confirmation stays in the toolbar.
	canvas.focus_mode = Control.FOCUS_NONE
	var controls_hint := DemoClockworkTheme.label("拖动 / 滚轮或双指缩放  ·  手柄：右杆平移，LB/RB 缩放，B 返回", 13, DemoClockworkTheme.MUTED)
	controls_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(controls_hint)
	_controls_scroll = ScrollContainer.new()
	_controls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_controls_scroll.follow_focus = true
	rows.add_child(_controls_scroll)
	_controls = GridContainer.new()
	_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controls.add_theme_constant_override("h_separation", 10)
	_controls.add_theme_constant_override("v_separation", 10)
	_controls_scroll.add_child(_controls)
	_touch_adapter = TOUCH_SCROLL.new()
	_touch_adapter.scroll = _controls_scroll
	_controls_scroll.add_child(_touch_adapter)
	for title: String in ["ZOOM -", "ZOOM +", "FIT MAP", "FIND ME", "CLOSE MAP"]:
		var button := Button.new()
		button.text = title
		button.add_theme_font_size_override("font_size", 15)
		button.custom_minimum_size.y = 52
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_controls.add_child(button)
		if title == "ZOOM -": button.pressed.connect(func() -> void: canvas.zoom_at(1.0 / 1.3, canvas.player_anchor()))
		elif title == "ZOOM +": button.pressed.connect(func() -> void: canvas.zoom_at(1.3, canvas.player_anchor()))
		elif title == "FIT MAP": button.pressed.connect(func() -> void: canvas.reset_view())
		elif title == "FIND ME": button.pressed.connect(func() -> void: canvas.focus_player())
		else:
			button.pressed.connect(_request_close)
			button.grab_focus()
	_root.resized.connect(_fit_controls)
	_fit_controls()

func _fit_controls() -> void:
	if not is_instance_valid(_controls): return
	var viewport := get_viewport()
	var viewport_size := viewport.get_visible_rect().size
	var scale := METRICS.ui_scale(viewport)
	var safe := METRICS.safe_rect(viewport)
	var is_compact := METRICS.compact(viewport)
	var edge := 16.0 / scale if is_compact else 24.0
	_margin.add_theme_constant_override("margin_left", ceili(safe.position.x + edge))
	_margin.add_theme_constant_override("margin_right", ceili(viewport_size.x - safe.end.x + edge))
	_margin.add_theme_constant_override("margin_top", ceili(safe.position.y + edge))
	_margin.add_theme_constant_override("margin_bottom", ceili(viewport_size.y - safe.end.y + edge))
	var physical_width := safe.size.x * scale
	_controls.columns = 5 if physical_width >= 800 else 3 if physical_width >= 540 else 2
	var gap := ceili(8.0 / scale) if is_compact else 10
	_rows.add_theme_constant_override("separation", ceili(8.0 / scale) if is_compact else 12)
	_controls.add_theme_constant_override("h_separation", gap)
	_controls.add_theme_constant_override("v_separation", gap)
	METRICS.apply(_root)
	var row_count := ceili(5.0 / _controls.columns)
	var button_height := maxf(52.0, 48.0 / scale)
	for control: Control in METRICS.focus_controls(_controls): button_height = maxf(button_height, control.get_combined_minimum_size().y)
	_controls_scroll.custom_minimum_size.y = row_count * button_height + (row_count - 1) * gap
	METRICS.trap_focus(_controls)
	_layout_signature = METRICS.signature(_root)

func _request_close() -> void:
	if not opened or _closing: return
	_closing = true
	closed.emit()

func _input(event: InputEvent) -> void:
	if not opened: return
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		if event.axis == JOY_AXIS_RIGHT_X: _pan_axis.x = event.axis_value
		else: _pan_axis.y = event.axis_value
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_B, JOY_BUTTON_START]:
			get_viewport().set_input_as_handled()
			_request_close()
		elif event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			canvas.zoom_at(1.0 / 1.3 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1.3, canvas.player_anchor())
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if opened and is_instance_valid(_root) and METRICS.signature(_root) != _layout_signature: _fit_controls()
	if opened and is_instance_valid(canvas) and _pan_axis.length() > 0.22:
		canvas.drag_by(-_pan_axis * delta * 420.0)

func close() -> void:
	opened = false
	canvas = null
	_pan_axis = Vector2.ZERO
	if is_instance_valid(_touch_adapter): _touch_adapter.cancel(&"map_close")
	if is_instance_valid(_root):
		remove_child(_root)
		_root.queue_free()
	_root = null
	_controls = null
	_controls_scroll = null
	_touch_adapter = null
	_margin = null
	_rows = null
	if _prior_focus != null:
		var previous := _prior_focus.get_ref() as Control
		if is_instance_valid(previous) and previous.is_inside_tree() and previous.is_visible_in_tree(): previous.grab_focus()
	_prior_focus = null
