class_name RoomSignReader
extends CanvasLayer

var message := Label.new()
var panel := PanelContainer.new()
var hint := Label.new()
var session: OrdinaryRoomSession
var reading := false

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -190
	hint.offset_right = 190
	hint.offset_top = -84
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", EquipmentMenu.UI_FONT)
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_constant_override("outline_size", 5)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.hide()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -290
	panel.offset_right = 290
	panel.offset_top = -180
	panel.offset_bottom = -44
	panel.add_theme_font_override("font",EquipmentMenu.UI_FONT)
	var layout := VBoxContainer.new()
	panel.add_child(layout)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_override("font", EquipmentMenu.UI_FONT)
	message.add_theme_font_size_override("font_size",20)
	layout.add_child(message)
	var close_button := Button.new()
	close_button.add_theme_font_override("font", EquipmentMenu.UI_FONT)
	close_button.text = "收起"
	close_button.pressed.connect(close)
	layout.add_child(close_button)
	panel.hide()

func _physics_process(_delta: float) -> void:
	hint.text = session.controller.router.interact_prompt("阅读告示")
	hint.visible = (not get_tree().paused and session.is_visible_in_tree() and session.controller.active
		and session.lifetime.active and not session.controller.has_pending_damage() and not session.readable_sign().is_empty())

func open(content: String) -> void:
	if get_tree().paused: return
	message.text = content
	reading = true
	hint.hide()
	panel.show()
	session.controller.router.clear("reading")
	get_tree().paused = true

func close() -> void:
	if not reading: return
	reading = false
	panel.hide()
	get_tree().paused = false
	session.controller.router.clear("reading")

func _input(event: InputEvent) -> void:
	if reading and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		close()

func _exit_tree() -> void:
	if reading: get_tree().paused = false
