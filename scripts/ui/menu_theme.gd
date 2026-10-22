extends RefCounted
## Shared menu styling without loading menu navigation or gameplay consumers.
static func create_theme() -> Theme:
	var theme := preload("res://scripts/ui/demo_ui_01/clockwork_theme.gd").create_theme()
	# Keep the original independent font variation/fallback contract. Chinese
	# remains covered by the licensed repository subset.
	var menu_font := FontVariation.new()
	menu_font.base_font = ThemeDB.fallback_font
	menu_font.fallbacks = [preload("res://assets/fonts/foundry_notes.otf")]
	theme.default_font = menu_font
	return theme
