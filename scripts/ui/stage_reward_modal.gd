class_name StageRewardModal
extends CanvasLayer
## Presentation only: gameplay owner validates the token and grants the chosen item.
signal item_selected(item_id: StringName)
var opened := false
var _root: Control
var _footer: Label
var _shell: DemoUiModalShell
var _options: GridContainer
var _submitted := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30

func show_offer(offer: RewardOffer, next_label: String) -> void:
	close()
	opened = true
	_submitted = false
	_shell = DemoUiModalShell.new()
	_shell.preferred_width = 680
	_shell.preferred_height = 550
	_shell.cancelable = false
	_root = _shell
	add_child(_root)
	_shell.heading("GOLD REWARD / BIOME COMPLETE" if offer.gold else "CHOOSE ONE REWARD / 选择一件奖励", "一次选择，带入本局后续旅程。 / One choice only.", "余音  /  A MOMENT TO CHOOSE")
	_options = GridContainer.new()
	_options.add_theme_constant_override("h_separation", 18)
	_options.add_theme_constant_override("v_separation", 16)
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shell.rows.add_child(_options)
	for item: ItemDefinition in offer.candidates:
		var card := ItemCard.new()
		card.item = item
		card.selectable = true
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.selected.connect(_select)
		_options.add_child(card)
		for button: Node in card.find_children("*", "Button", true, false):
			(button as Button).custom_minimum_size.y = 54
			(button as Button).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer = _shell.text("Continue to / 随后前往：" + next_label, 16, DemoClockworkTheme.MUTED)
	_root.resized.connect(_fit_options)
	_shell.layout_changed.connect(_fit_options)
	_fit_options()
	_shell.focus_first()

func _fit_options() -> void:
	if not is_instance_valid(_options): return
	var physical_width := get_viewport().get_visible_rect().size.x * DemoUiModalMetrics.pixel_scale(get_viewport())
	_options.columns = 2 if physical_width >= 720 else 1

func _select(id: StringName) -> void:
	if _submitted: return
	_submitted = true
	item_selected.emit(id)

func show_error(message: String) -> void:
	if opened and is_instance_valid(_footer):
		_submitted = false
		_footer.text = message + " / RETRY SAME OPTION"
		_footer.add_theme_color_override("font_color", DemoClockworkTheme.CORAL)

func close() -> void:
	opened = false
	if is_instance_valid(_root):
		if is_instance_valid(_shell): _shell.restore_focus()
		remove_child(_root)
		_root.queue_free()
	_root = null
	_shell = null
	_footer = null
	_options = null
