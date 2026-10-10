class_name StageExitModal
extends CanvasLayer
## Confirmation presentation only; the App owns route, epoch and reward settlement.
signal entered
signal stayed
var opened := false
var _root: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 29

func show_exit(next_label: String, reward_summary: String) -> void:
	close()
	opened = true
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.035, 0.04, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.theme = DemoMenu.create_theme()
	panel.custom_minimum_size = Vector2(600, 260)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 20)
	margin.add_child(rows)
	for text: String in ["NEXT / " + next_label, reward_summary, "Enter now, or stay and keep exploring."]:
		var label := Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		rows.add_child(label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	rows.add_child(buttons)
	var enter := Button.new()
	enter.text = "ENTER / CLAIM REWARD"
	enter.custom_minimum_size = Vector2(260, 56)
	enter.pressed.connect(func() -> void: entered.emit())
	buttons.add_child(enter)
	var stay := Button.new()
	stay.text = "STAY"
	stay.custom_minimum_size = Vector2(180, 56)
	stay.pressed.connect(func() -> void: stayed.emit())
	buttons.add_child(stay)
	stay.grab_focus()

func close() -> void:
	opened = false
	if is_instance_valid(_root):
		remove_child(_root)
		_root.queue_free()
	_root = null
