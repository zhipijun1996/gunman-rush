class_name DemoClockworkTheme
extends RefCounted
## Native, reusable UI materials. All illustration remains independently interactive.
const FONT := preload("res://assets/ui/demo_ui_01/r2/fonts/fusion-pixel-12px-proportional-zh_hans.otf")
const INK := Color("111b20")
const PANEL := Color("253538")
const RAISED := Color("3b4e4c")
const PAPER := Color("f6e8bf")
const BRASS := Color("d8b16b")
const EDGE := Color("8c8467")
const MUTED := Color("bcbba1")
const TEAL := Color("8dbda4")
const CORAL := Color("d97860")

static func plate(fill: Color, border: Color, padding: int = 16) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(1)
	result.set_content_margin_all(padding)
	result.set_corner_radius_all(12)
	result.shadow_color = Color(0.02, 0.035, 0.045, 0.72)
	result.shadow_size = 4
	result.shadow_offset = Vector2(0, 3)
	result.anti_aliasing = false
	return result

static func create_theme() -> Theme:
	var result := Theme.new()
	result.default_font = FONT
	result.default_font_size = 24
	result.set_color("font_color", "Label", PAPER)
	result.set_color("font_shadow_color", "Label", INK)
	result.set_constant("shadow_offset_x", "Label", 1)
	result.set_constant("shadow_offset_y", "Label", 2)
	result.set_stylebox("panel", "PanelContainer", plate(PANEL, EDGE, 24))
	result.set_stylebox("panel", "Panel", plate(PANEL, EDGE))
	for kind: String in ["Button", "OptionButton", "MenuButton", "CheckButton"]:
		var normal := plate(Color("293a3b"), Color("807b60"))
		normal.border_width_top = 2
		normal.border_width_left = 2
		normal.border_width_right = 2
		normal.border_width_bottom = 5
		result.set_stylebox("normal", kind, normal)
		result.set_stylebox("hover", kind, plate(RAISED, BRASS))
		result.set_stylebox("pressed", kind, plate(INK, TEAL, 16))
		result.set_stylebox("disabled", kind, plate(Color("1b292a"), Color("394640")))
		var focus := plate(Color.TRANSPARENT, BRASS, 0)
		focus.draw_center = false
		focus.shadow_size = 0
		focus.set_border_width_all(2)
		focus.expand_margin_left = 3
		focus.expand_margin_top = 3
		focus.expand_margin_right = 3
		focus.expand_margin_bottom = 3
		result.set_stylebox("focus", kind, focus)
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			result.set_color(state, kind, PAPER)
		result.set_color("font_disabled_color", kind, Color("819184"))
		result.set_color("icon_normal_color", kind, BRASS)
		result.set_font_size("font_size", kind, 24)
	result.set_type_variation("PrimaryButton", "Button")
	var primary := plate(Color("c3a366"), Color("ead096"), 16)
	primary.border_width_top = 2
	primary.border_width_bottom = 5
	result.set_stylebox("normal", "PrimaryButton", primary)
	result.set_stylebox("hover", "PrimaryButton", plate(PAPER, BRASS, 16))
	result.set_stylebox("pressed", "PrimaryButton", plate(TEAL, PAPER, 16))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		result.set_color(state, "PrimaryButton", INK)
	result.set_type_variation("CompactButton", "Button")
	result.set_font_size("font_size", "CompactButton", 18)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var compact := result.get_stylebox(state, "Button").duplicate() as StyleBoxFlat
		compact.set_content_margin_all(8)
		compact.set_corner_radius_all(8)
		result.set_stylebox(state, "CompactButton", compact)
	result.set_stylebox("normal", "LineEdit", plate(INK, EDGE, 14))
	result.set_stylebox("focus", "LineEdit", plate(INK, BRASS, 14))
	result.set_color("font_color", "LineEdit", PAPER)
	result.set_color("caret_color", "LineEdit", BRASS)
	result.set_color("font_placeholder_color", "LineEdit", MUTED)
	result.set_color("selection_color", "LineEdit", RAISED)
	result.set_stylebox("slider", "HSlider", plate(INK, EDGE, 4))
	result.set_stylebox("grabber_area", "HSlider", plate(TEAL, TEAL, 4))
	result.set_stylebox("grabber_area_highlight", "HSlider", plate(BRASS, BRASS, 4))
	result.set_constant("grabber_offset", "HSlider", 0)
	result.set_stylebox("scroll", "VScrollBar", plate(INK, INK, 3))
	for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		result.set_stylebox(state, "VScrollBar", plate(EDGE if state == "grabber" else BRASS, INK, 6))
	result.set_stylebox("panel", "PopupMenu", plate(INK, BRASS))
	result.set_stylebox("hover", "PopupMenu", plate(RAISED, BRASS, 12))
	result.set_color("font_color", "PopupMenu", PAPER)
	result.set_color("font_hover_color", "PopupMenu", PAPER)
	result.set_stylebox("panel", "TooltipPanel", plate(INK, EDGE, 10))
	result.set_color("font_color", "TooltipLabel", PAPER)
	return result

static func label(text: String, size: int = 16, color: Color = PAPER) -> Label:
	var result := Label.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_override("font", FONT)
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_outline_color", INK)
	result.add_theme_constant_override("outline_size", 2)
	result.add_theme_color_override("font_shadow_color", Color(INK, 0.9))
	result.add_theme_constant_override("shadow_offset_y", 2)
	return result
