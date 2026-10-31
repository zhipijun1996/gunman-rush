@static_unload
class_name UnderworldUI
extends RefCounted
## Native UI layout/styles, not generated illustration. Input owners stay unchanged.
const FONT := preload("res://assets/fonts/foundry_notes.otf")
const PIXEL_FONT := preload("res://assets/fonts/foundry_notes.otf")
const BELL := preload("res://assets/underworld_plains/actors/bell.png")
const INK := Color("101819")
const PANEL := Color("1b2625")
const RAISED := Color("26342c")
const BORDER := Color("52604b")
const BRASS := Color("b69a60")
const TEXT := Color("e5dec1")
const MUTED := Color("a2af98")
const MOSS := Color("829b77")
const HURT := Color("c38272")
const COOL := Color("85a6a0")

static func box(fill: Color = PANEL, edge: Color = BORDER, padding := 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.anti_aliasing = false
	style.set_content_margin_all(padding)
	return style

static func panel_frame() -> StyleBoxTexture:
	# Source-native Underworld closed stone frame; native 9-patch tiling keeps
	# corners intact. This is declared Tile reuse, not generated illustration.
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/underworld_plains/ui/ui_build.json"))
	var region: Array = spec.panel.region
	var texture := AtlasTexture.new()
	texture.atlas = load("res://"+str(spec.panel.texture))
	texture.region = Rect2(region[0],region[1],region[2],region[3])
	texture.filter_clip = true
	var style := StyleBoxTexture.new()
	style.texture = texture
	for side: int in 4: style.set_texture_margin(side,float(spec.panel.slice_margin))
	style.set_content_margin_all(20)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.modulate_color = Color(0.78,0.78,0.72,0.97)
	return style

static func create_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 17
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_shadow_color", "Label", INK)
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_stylebox("panel", "Panel", box())
	theme.set_stylebox("panel", "PanelContainer", panel_frame())
	for type: String in ["Button", "OptionButton", "MenuButton"]:
		theme.set_stylebox("normal", type, box(INK, BORDER, 12))
		theme.set_stylebox("hover", type, box(RAISED, MOSS, 12))
		theme.set_stylebox("pressed", type, box(Color("0b1213"), BRASS, 12))
		theme.set_stylebox("disabled", type, box(Color("18201e"), Color("303d32"), 12))
		var focus := box(Color.TRANSPARENT, BRASS, 0)
		focus.border_width_left = 3
		theme.set_stylebox("focus", type, focus)
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			theme.set_color(state, type, TEXT)
		theme.set_color("font_disabled_color", type, Color("74806c"))
		theme.set_color("icon_normal_color", type, BRASS)
	theme.set_stylebox("normal", "LineEdit", box(INK, BORDER, 12))
	theme.set_stylebox("focus", "LineEdit", box(INK, BRASS, 12))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("caret_color", "LineEdit", BRASS)
	theme.set_color("selection_color", "LineEdit", Color("3d5845"))
	theme.set_stylebox("slider", "HSlider", box(INK, BORDER, 3))
	theme.set_stylebox("grabber_area", "HSlider", box(MOSS, MOSS, 3))
	theme.set_stylebox("grabber_area_highlight", "HSlider", box(BRASS, BRASS, 3))
	theme.set_stylebox("scroll", "VScrollBar", box(INK, INK, 2))
	theme.set_stylebox("grabber", "VScrollBar", box(BORDER, BORDER, 4))
	theme.set_stylebox("grabber_highlight", "VScrollBar", box(MOSS, MOSS, 4))
	theme.set_stylebox("grabber_pressed", "VScrollBar", box(BRASS, BRASS, 4))
	theme.set_stylebox("panel", "PopupMenu", box())
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", TEXT)
	theme.set_stylebox("hover", "PopupMenu", box(RAISED, BORDER, 6))
	theme.set_stylebox("panel", "TooltipPanel", box(INK, BORDER, 8))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	return theme

static func style_canvas(canvas: CanvasLayer) -> void:
	# Explicit presentation hook from the owner after its controls are created.
	# Never changes hit rectangles, focus, callbacks, mouse filters or positions.
	for child: Node in canvas.get_children():
		if not child is Control: continue
		child.theme = create_theme()
		if child is Panel: child.add_theme_stylebox_override("panel", box(Color(0.045,0.075,0.07,0.88), BORDER, 6))
		if child is Label:
			child.add_theme_color_override("font_color", TEXT)
			child.add_theme_color_override("font_shadow_color", INK)

static func icon(key: StringName) -> Texture2D:
	var specification: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/underworld_plains/ui/icon_regions.json"))
	var region: Array = specification.regions.get(str(key), [])
	if region.size() != 4: return null
	var texture := AtlasTexture.new()
	texture.atlas = load("res://" + str(specification.atlas))
	texture.region = Rect2(region[0],region[1],region[2],region[3])
	texture.filter_clip = true
	return texture
