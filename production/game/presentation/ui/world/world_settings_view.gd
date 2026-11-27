class_name WorldSettingsView
extends Control
## Keeps the settings draft while the physical-position calibration page is open.
const MODES := ["two_step", "digital", "analog"]
static var _captions: Dictionary = {}
var preferences: WorldSettings
var close_page: Callable
var modal: DemoUiModalShell
var calibration_modal: DemoUiModalShell
var wizard: WorldGamepadCalibration
var volume: HSlider
var reduced: CheckButton
var movement: OptionButton
var revision := 0

static func caption(id: String) -> String:
	if _captions.is_empty():
		_captions = JSON.parse_string(FileAccess.get_file_as_string("res://config/world_settings_text.json"))
	return _captions[id]

static func mount(parent: Control, close: Callable, store: WorldSettings = null) -> Control:
	var view := WorldSettingsView.new()
	view.preferences = store if store != null else WorldSettings.current()
	view.close_page = close
	parent.add_child(view)
	return view

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	modal = DemoUiModalShell.new()
	add_child(modal)
	modal.cancel_requested.connect(close_page)
	revision = preferences.revision
	modal.heading(caption("world_settings_view.00"), caption("world_settings_view.01"))
	modal.text(caption("world_settings_view.02"))
	volume = HSlider.new()
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = preferences.value.volume
	volume.custom_minimum_size = Vector2(200, 44)
	modal.rows.add_child(volume)
	reduced = CheckButton.new()
	reduced.text = caption("world_settings_view.03")
	reduced.button_pressed = preferences.value.reduced
	modal.rows.add_child(reduced)
	modal.text(caption("world_settings_view.movement"))
	movement = OptionButton.new()
	for label_id: String in ["04", "05", "06"]:
		movement.add_item(caption("world_settings_view." + label_id))
	movement.select(MODES.find(preferences.value.input.touch_move_mode))
	modal.rows.add_child(movement)
	movement.get_popup().about_to_popup.connect(func() -> void: modal.cancel_touch(&"popup_open"))
	var popup_touch := PopupTouchAdapter.new()
	popup_touch.popup = movement.get_popup()
	movement.get_popup().add_child(popup_touch)
	modal.button(caption("gamepad_calibration.title"), open_calibration)
	modal.button(caption("world_settings_view.07"), save_draft)
	modal.button(caption("world_settings_view.09"), close_page)
	modal.focus_first()

func save_draft() -> void:
	if preferences.revision != revision:
		return
	var candidate := preferences.value.duplicate(true)
	candidate.volume = volume.value
	candidate.reduced = reduced.button_pressed
	candidate.input.touch_move_mode = MODES[movement.selected]
	if preferences.save(candidate):
		close_page.call()
	else:
		modal.text(caption("world_settings_view.08") + preferences.error)

func open_calibration() -> void:
	if is_instance_valid(calibration_modal):
		return
	modal.cancel_touch(&"calibration")
	modal.hide()
	calibration_modal = DemoUiModalShell.new()
	add_child(calibration_modal)
	calibration_modal.cancel_requested.connect(close_calibration)
	wizard = WorldGamepadCalibration.install(calibration_modal, preferences, close_calibration)

func close_calibration() -> void:
	calibration_modal.cancel_touch(&"calibration_closed")
	remove_child(calibration_modal)
	calibration_modal.queue_free()
	calibration_modal = null
	wizard = null
	revision = preferences.revision
	modal.show()
	modal.focus_first()

func request_back() -> void:
	if is_instance_valid(calibration_modal):
		close_calibration()
	elif movement.get_popup().visible:
		movement.get_popup().hide()
	else:
		close_page.call()
