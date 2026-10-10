class_name PlainsBackground
extends CanvasLayer
## One continuous viewport backdrop. Never participates in gameplay or RNG.
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/backgrounds/plains/plains_sky.svg"),
	preload("res://assets/backgrounds/plains/plains_far_hills.svg"),
	preload("res://assets/backgrounds/plains/plains_meadow.svg"),
	preload("res://assets/backgrounds/plains/plains_distant_ruins.svg"),
]
const SCROLL: Array[float] = [0.04, 0.12, 0.22, 0.28]
var surface: Node2D
var _last_transform := Transform2D()
var _last_size := Vector2.ZERO

func _ready() -> void:
	layer = -100
	process_mode = Node.PROCESS_MODE_ALWAYS
	surface = Node2D.new()
	surface.draw.connect(_draw_background)
	add_child(surface)

func _process(_delta: float) -> void:
	var current := get_viewport().get_canvas_transform()
	var size := get_viewport().get_visible_rect().size
	if current != _last_transform or size != _last_size:
		_last_transform = current
		_last_size = size
		surface.queue_redraw()

func _draw_background() -> void:
	var size := get_viewport().get_visible_rect().size
	if size.x <= 0 or size.y <= 0:
		return
	var factor := maxf(size.x / 1920.0, size.y / 1080.0)
	var width := 1920.0 * factor
	var height := 1080.0 * factor
	var world_center := get_viewport().get_canvas_transform().affine_inverse() * (size / 2.0)
	for index: int in TEXTURES.size():
		# Only horizontal repetition: climbing never exposes a blank backdrop or
		# repeats the skyline vertically. Overview does not scale the background.
		var offset := fposmod(world_center.x * SCROLL[index] * factor, width)
		var x := -offset
		while x < size.x:
			surface.draw_texture_rect(TEXTURES[index], Rect2(x, size.y - height, width, height), false)
			x += width
