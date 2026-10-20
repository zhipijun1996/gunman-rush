extends RefCounted
## Shared menu styling without loading menu navigation or gameplay consumers.
static func create_theme() -> Theme:
	var theme := UnderworldUI.create_theme()
	var menu_font := FontVariation.new()
	menu_font.base_font = ThemeDB.fallback_font
	menu_font.fallbacks = [preload("res://assets/fonts/foundry_notes.otf")]
	theme.default_font = menu_font
	return theme
