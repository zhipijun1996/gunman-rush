class_name StageRewardModal
extends CanvasLayer
## Presentation only: gameplay owner validates the token and grants the chosen item.
signal item_selected(item_id: StringName)
var opened := false
var _root: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30

func show_offer(offer: RewardOffer, next_label: String) -> void:
	close()
	opened = true
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.035, 0.04, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 260)
	panel.theme = DemoMenu.create_theme()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 22)
	margin.add_child(rows)
	var title := Label.new()
	title.text = "GOLD REWARD / BIOME COMPLETE" if offer.gold else "CHOOSE ONE ITEM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	rows.add_child(title)
	var options := HBoxContainer.new()
	options.alignment = BoxContainer.ALIGNMENT_CENTER
	options.add_theme_constant_override("separation", 18)
	rows.add_child(options)
	for item: ItemDefinition in offer.candidates:
		var button := Button.new()
		var rarity_names := ["BLUE", "PURPLE", "GOLD"]
		var effects: PackedStringArray = []
		for modifier: BuildModifier in item.modifiers:
			effects.append("%s: %s" % [modifier.stat_id, str(modifier.value)])
		button.text = "%s / %s\n%s" % [rarity_names[item.rarity], item.display_name, "\n".join(effects)]
		button.custom_minimum_size = Vector2(260, 100)
		button.add_theme_font_size_override("font_size", 20)
		var selected := item.stable_id
		button.pressed.connect(func() -> void: item_selected.emit(selected))
		options.add_child(button)
	var footer := Label.new()
	footer.text = "One choice only. Continue to " + next_label
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(footer)

func close() -> void:
	opened = false
	if is_instance_valid(_root):
		remove_child(_root)
		_root.queue_free()
	_root = null
