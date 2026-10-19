class_name StageRewardModal
extends CanvasLayer
## Presentation only: gameplay owner validates the token and grants the chosen item.
signal item_selected(item_id: StringName)
var opened := false
var _root: Control
var _footer: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30

func show_offer(offer: RewardOffer, next_label: String) -> void:
	close()
	opened = true
	_root = Control.new()
	_root.theme=UnderworldUI.create_theme()
	_root.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
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
	title.text = "GOLD REWARD / BIOME COMPLETE" if offer.gold else "CHOOSE ONE REWARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color",UnderworldUI.TEXT)
	rows.add_child(title)
	var options := HBoxContainer.new()
	options.alignment = BoxContainer.ALIGNMENT_CENTER
	options.add_theme_constant_override("separation", 18)
	rows.add_child(options)
	for item: ItemDefinition in offer.candidates:
		var card:=ItemCard.new()
		card.item=item
		card.selectable=true
		card.selected.connect(func(id: StringName): item_selected.emit(id))
		options.add_child(card)
	var footer := Label.new();_footer=footer
	footer.text = "One choice only. Continue to " + next_label
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_color",UnderworldUI.TEXT)
	rows.add_child(footer)

func show_error(message: String) -> void:
	if opened and is_instance_valid(_footer):
		_footer.text=message+" / RETRY SAME OPTION"
		_footer.add_theme_color_override("font_color",UnderworldUI.HURT)

func close() -> void:
	opened = false
	if is_instance_valid(_root):
		remove_child(_root)
		_root.queue_free()
	_root = null
	_footer=null
