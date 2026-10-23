class_name DemoUiModalShell
extends Control
## Shared presentation and focus owner. Gameplay pause and settlement remain upstream.
signal cancel_requested
signal layout_changed
const TOUCH_SCROLL := preload("res://scripts/ui/menu_scroll_touch_adapter.gd")
const METRICS := preload("res://scripts/ui/demo_ui_01/modal_metrics.gd")
var rows: VBoxContainer
var scroll: ScrollContainer
var cancelable := true
var preferred_width := 680.0
var preferred_height := 520.0
var _prior_focus: WeakRef
var _touch_adapter: Node
var _hint: Label
var _safe_margin: MarginContainer
var _panel: PanelContainer
var _layout_signature: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = DemoClockworkTheme.create_theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var previous := get_viewport().gui_get_focus_owner()
	if previous != null: _prior_focus = weakref(previous)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.055, 0.06, 0.92)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_safe_margin = MarginContainer.new()
	_safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_safe_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_safe_margin)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe_margin.add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_panel.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 16)
	scroll.add_child(rows)
	_touch_adapter = TOUCH_SCROLL.new()
	_touch_adapter.scroll = scroll
	scroll.add_child(_touch_adapter)
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	if scroll == null: return
	var viewport := get_viewport()
	var viewport_size := viewport.get_visible_rect().size
	var safe := METRICS.safe_rect(viewport)
	var scale := METRICS.pixel_scale(viewport)
	var is_compact := METRICS.compact(viewport)
	var edge := 16.0 / scale if is_compact else 24.0
	_safe_margin.add_theme_constant_override("margin_left", ceili(safe.position.x + edge))
	_safe_margin.add_theme_constant_override("margin_right", ceili(viewport_size.x - safe.end.x + edge))
	_safe_margin.add_theme_constant_override("margin_top", ceili(safe.position.y + edge))
	_safe_margin.add_theme_constant_override("margin_bottom", ceili(viewport_size.y - safe.end.y + edge))
	var inset := _panel.get_theme_stylebox("panel").get_minimum_size()
	var available := Vector2(maxf(1, safe.size.x - edge * 2 - inset.x), maxf(1, safe.size.y - edge * 2 - inset.y))
	scroll.custom_minimum_size = available if is_compact else Vector2(minf(preferred_width, available.x), minf(preferred_height, available.y))
	scroll.size = scroll.custom_minimum_size
	rows.add_theme_constant_override("separation", ceili(10.0 / scale) if is_compact else 16)
	METRICS.apply(self)
	METRICS.trap_focus(rows)
	_layout_signature = METRICS.signature(self)
	layout_changed.emit()

func heading(title: String, detail: String, eyebrow: String = "失序之钟  /  THE CLOCK UNBOUND") -> void:
	text(eyebrow, 13, DemoClockworkTheme.BRASS)
	text(title, 28, DemoClockworkTheme.PAPER)
	var line := HSeparator.new()
	rows.add_child(line)
	text(detail, 17, DemoClockworkTheme.MUTED)

func text(value: String, font_size: int = 17, color: Color = DemoClockworkTheme.PAPER) -> Label:
	var label := DemoClockworkTheme.label(value, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(label)
	return label

func button(title: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = title
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size.y = 54
	result.alignment = HORIZONTAL_ALIGNMENT_LEFT
	result.mouse_filter = Control.MOUSE_FILTER_PASS
	result.pressed.connect(action)
	rows.add_child(result)
	return result

func focus_first() -> void:
	_fit()
	var controls := METRICS.focus_controls(rows)
	if not controls.is_empty(): controls[0].grab_focus()

func _process(_delta: float) -> void:
	if is_visible_in_tree() and METRICS.signature(self) != _layout_signature: _fit()

func restore_focus() -> void:
	if is_instance_valid(_touch_adapter): _touch_adapter.cancel(&"modal_close")
	if _prior_focus == null: return
	var previous := _prior_focus.get_ref() as Control
	if is_instance_valid(previous) and previous.is_inside_tree() and previous.is_visible_in_tree(): previous.grab_focus()
	_prior_focus = null

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START):
		get_viewport().set_input_as_handled()
		if cancelable:
			cancel_requested.emit()
		else:
			if _hint == null: _hint = text("请先完成本次选择 / Choose a reward to continue.", 15, DemoClockworkTheme.BRASS)
			focus_first()
