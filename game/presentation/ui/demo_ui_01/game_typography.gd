extends Node
## One licensed pixel family for native Controls and existing CanvasItem text.
## Compatibility FontFile resources share canonical font bytes at runtime only;
## their original files and every actor/environment consumer stay unchanged.
const FONT := preload("res://assets/ui/demo_ui_01/r2/fonts/fusion-pixel-12px-proportional-zh_hans.otf")
const LEGACY_FONT_PATHS := [
	"res://assets/fonts/foundry_notes.otf",
	"res://assets/fonts/foundry_ui.otf",
	"res://assets/fonts/windkeeper_ui.ttf",
]
var _legacy_fonts: Array[FontFile] = []

func _enter_tree() -> void:
	configure_font(FONT)
	ThemeDB.fallback_font = FONT
	ThemeDB.get_default_theme().default_font = FONT
	# Existing draw_string consumers hold these shared resources, rather than a
	# theme. Alias only font data, never gameplay scripts or original asset bytes.
	for path: String in LEGACY_FONT_PATHS:
		var legacy := load(path) as FontFile
		legacy.clear_cache()
		legacy.data = FONT.data
		configure_font(legacy)
		legacy.clear_cache()
		# Keep aliases alive for consumers loaded later (labs, bosses, Home).
		_legacy_fonts.append(legacy)

static func configure_font(font: FontFile) -> void:
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.multichannel_signed_distance_field = false
	# Let Godot rasterize outlines for the real display scale, including HiDPI.
	font.oversampling = 0.0
	font.allow_system_fallback = false
