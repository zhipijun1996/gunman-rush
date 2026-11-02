extends RefCounted
## Shared menu styling without loading menu navigation or gameplay consumers.
static func create_theme() -> Theme:
	var theme := preload("res://game/presentation/ui/demo_ui_01/clockwork_theme.gd").create_theme()
	# Retain the shared FontVariation API; GameTypography aliases both resources
	# to the same licensed Fusion Pixel family for CanvasItem and Control text.
	var menu_font := FontVariation.new()
	menu_font.base_font = ThemeDB.fallback_font
	menu_font.fallbacks = [preload("res://assets/fonts/foundry_notes.otf")]
	theme.default_font = menu_font
	return theme
