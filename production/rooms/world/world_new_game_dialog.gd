class_name WorldNewGameDialog
extends CanvasLayer
## Reset is a separate, explicit operation even when the current slot cannot open.
signal progress_replaced
var host: Node
var window := ConfirmationDialog.new()
var was_paused := false

static func mount(owner_node: Node) -> WorldNewGameDialog:
	var menu := WorldNewGameDialog.new()
	menu.host = owner_node
	owner_node.add_child(menu)
	return menu

func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(window)
	window.title = "重新开局"
	window.transient = true
	window.exclusive = true
	window.dialog_hide_on_ok = false
	window.ok_button_text = "开始新游戏"
	window.cancel_button_text = "保留进度"
	window.get_ok_button().custom_minimum_size = Vector2(152,54)
	window.get_cancel_button().custom_minimum_size = Vector2(152,54)
	var theme := Theme.new()
	theme.default_font = EquipmentMenu.UI_FONT
	theme.default_font_size = 20
	window.theme = theme
	window.confirmed.connect(confirm)
	window.canceled.connect(cancel)

func open() -> void:
	if window.visible or not host.get("storage") is PlayableWorldSave: return
	was_paused = get_tree().paused
	get_tree().paused = true
	window.dialog_text = "开始新游戏会替换当前世界进度。"
	window.popup_centered(Vector2i(510,190))
	window.get_cancel_button().grab_focus()

func cancel() -> void:
	window.hide()
	get_tree().paused = was_paused

func confirm() -> void:
	if not window.visible: return
	var slot := host.get("storage") as PlayableWorldSave
	if not slot.reset_world():
		window.dialog_text = "无法写入新进度。请检查存储空间后重试。"
		return
	window.hide()
	get_tree().paused = false
	progress_replaced.emit()
