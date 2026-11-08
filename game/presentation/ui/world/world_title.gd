class_name FixedWorldTitle
extends DemoMenu
## Reuses the existing title composition, typography, input/focus and illustration.
signal world_requested(kind: String)
var _notice: Label
func show_title() -> void:
	_begin(&"title",false)
	_title_label = _label(_content,WorldText.text("world_title.00"),36,TEXT)
	_label(_content,WorldText.text("world_title.01"),18,MUTED)
	var start := _button(_content,WorldText.text("world_title.02"),func() -> void: world_requested.emit("new"))
	start.name = "BeginAdventure"
	start.theme_type_variation = &"PrimaryButton"
	start.custom_minimum_size.y = 62
	var proceed := _button(_content,WorldText.text("world_title.03"),func() -> void: world_requested.emit("continue"))
	proceed.name = "ContinueAdventure"
	proceed.custom_minimum_size.y = 62
	_button(_content,WorldText.text("world_title.04"),func() -> void: world_requested.emit("settings"))
	_button(_content,WorldText.text("world_title.05"),func() -> void: world_requested.emit("help"))
	_button(_content,WorldText.text("review.open"),func() -> void: world_requested.emit("review"))
	_notice=_label(_content,"",16,MUTED)
	_notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_focus_first()
func show_notice(message: String) -> void:
	_notice.text=message
