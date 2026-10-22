class_name DemoUiModalMetrics
extends RefCounted
## Rendered-pixel sizing and local focus routing shared by the Demo modal owners.
const BASE_MINIMUM := &"demo_modal_base_minimum"
const BASE_FONT := &"demo_modal_base_font"

static func pixel_scale(viewport: Viewport) -> float:
	var scale := viewport.get_screen_transform().get_scale().abs()
	return maxf(0.01, minf(scale.x, scale.y))

static func compact(viewport: Viewport) -> bool:
	var physical := viewport.get_visible_rect().size * viewport.get_screen_transform().get_scale().abs()
	return physical.x < 1000 or physical.y < 600

static func safe_rect(viewport: Viewport) -> Rect2:
	var safe := Rect2(Vector2.ZERO, viewport.get_visible_rect().size)
	if OS.has_feature("android") or OS.has_feature("ios"):
		var physical := DisplayServer.get_display_safe_area()
		if physical.has_area():
			var inverse := viewport.get_screen_transform().affine_inverse()
			var origin := Vector2(DisplayServer.window_get_position())
			var start := inverse * (Vector2(physical.position) - origin)
			var finish := inverse * (Vector2(physical.end) - origin)
			safe = Rect2(start, finish - start).intersection(safe)
	return safe

static func signature(owner: Control) -> Array:
	var viewport := owner.get_viewport()
	var window := owner.get_window()
	var controls := owner.find_children("*", "Control", true, false)
	var states: Array = []
	for node: Node in controls:
		var control := node as Control
		states.append([control.get_instance_id(), control.is_visible_in_tree(), control.disabled if control is BaseButton else false])
	return [viewport.get_visible_rect().size, viewport.get_screen_transform(), window.size, window.position, safe_rect(viewport), states]

static func apply(owner: Control) -> void:
	var viewport := owner.get_viewport()
	var scale := pixel_scale(viewport)
	var is_compact := compact(viewport)
	var font_factor := clampf(1.0 / scale, 1.0, 1.8) if is_compact else 1.0
	for node: Node in owner.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.has_meta(BASE_MINIMUM): control.set_meta(BASE_MINIMUM, control.custom_minimum_size)
		var authored_minimum: Vector2 = control.get_meta(BASE_MINIMUM)
		if control is BaseButton or control is Range or control is LineEdit:
			control.custom_minimum_size = Vector2(maxf(authored_minimum.x, 48.0 / scale), maxf(authored_minimum.y, 48.0 / scale))
		if control is Label or control is BaseButton or control is LineEdit:
			if not control.has_meta(BASE_FONT): control.set_meta(BASE_FONT, control.get_theme_font_size("font_size"))
			var authored_font: int = control.get_meta(BASE_FONT)
			var font_size := maxi(authored_font, ceili(maxf(authored_font * font_factor, 14.0 / scale))) if is_compact else authored_font
			control.add_theme_font_size_override("font_size", font_size)
			if control is OptionButton:
				var popup := (control as OptionButton).get_popup()
				popup.add_theme_font_size_override("font_size", font_size)
				var font_height := popup.get_theme_font("font").get_height(font_size)
				popup.add_theme_constant_override("v_separation", maxi(8, ceili(48.0 / scale - font_height)))

static func focus_controls(owner: Control) -> Array[Control]:
	var controls: Array[Control] = []
	for node: Node in owner.find_children("*", "Control", true, false):
		var control := node as Control
		if control.focus_mode == Control.FOCUS_ALL and control.is_visible_in_tree() and not (control is BaseButton and control.disabled): controls.append(control)
	return controls

static func trap_focus(owner: Control) -> void:
	var controls := focus_controls(owner)
	for index: int in controls.size():
		var control := controls[index]
		var previous := control.get_path_to(controls[(index + controls.size() - 1) % controls.size()])
		var next := control.get_path_to(controls[(index + 1) % controls.size()])
		control.focus_previous = previous
		control.focus_next = next
		control.focus_neighbor_top = previous
		control.focus_neighbor_bottom = next
		# Ranges retain horizontal editing; OptionButton owns its popup keys.
		control.focus_neighbor_left = control.get_path_to(control) if control is Range or control is OptionButton else previous
		control.focus_neighbor_right = control.get_path_to(control) if control is Range or control is OptionButton else next
