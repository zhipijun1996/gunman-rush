class_name WorldSettingsView
extends RefCounted
var ui: FixedWorldUI
var settings: WorldSettings
var applied: Callable
func show() -> void:
	var modal:=ui.panel("settings",WorldText.text("world_settings_view.00"),WorldText.text("world_settings_view.01"))
	var volume:=HSlider.new();volume.min_value=0;volume.max_value=1;volume.step=.05
	volume.value=settings.value.volume;volume.custom_minimum_size=Vector2(200,44)
	modal.text(WorldText.text("world_settings_view.02"));modal.rows.add_child(volume)
	var reduced:=CheckButton.new();reduced.text=WorldText.text("world_settings_view.03");reduced.button_pressed=settings.value.reduced
	modal.rows.add_child(reduced)
	var movement:=OptionButton.new()
	for label: String in [WorldText.text("world_settings_view.04"),WorldText.text("world_settings_view.05"),WorldText.text("world_settings_view.06")]: movement.add_item(label)
	var modes: Array=["two_step","digital","analog"]
	movement.select(modes.find(settings.value.input.touch_move_mode))
	modal.rows.add_child(movement)
	movement.get_popup().about_to_popup.connect(func() -> void: modal.cancel_touch(&"popup_open"))
	var popup_touch:=PopupTouchAdapter.new()
	popup_touch.popup=movement.get_popup()
	movement.get_popup().add_child(popup_touch)
	var expected_revision:=settings.revision
	modal.button(WorldText.text("world_settings_view.07"),func() -> void:
		if settings.revision!=expected_revision: return
		var candidate:=settings.value.duplicate(true)
		candidate.volume=volume.value;candidate.reduced=reduced.button_pressed
		candidate.input.touch_move_mode=modes[movement.selected]
		if settings.save(candidate):
			applied.call()
		else: modal.text(WorldText.text("world_settings_view.08")+settings.error))
	modal.button(WorldText.text("world_settings_view.09"),func() -> void: ui.command.emit("close",""))
	modal.focus_first()

