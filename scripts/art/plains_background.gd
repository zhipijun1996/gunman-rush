class_name PlainsBackground
extends CanvasLayer
## One continuous viewport backdrop. Never participates in gameplay or RNG.
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/painterly_v2/background/sky.png"),
	preload("res://assets/painterly_v2/background/hills.png"),
	preload("res://assets/painterly_v2/background/meadow.png"),
]
const SCROLL: Array[float] = [0.02, 0.08, 0.16]
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
	# Latest paintings are finite panels, not seam-approved periodic textures.
	# Overscan plus bounded camera drift preserves layered depth without repeating
	# their edges or revealing blank regions during arbitrarily tall routes.
	var factor := maxf(size.x / 1672.0, size.y / 941.0) * 1.12
	var width := 1672.0 * factor
	var height := 941.0 * factor
	var world_center := get_viewport().get_canvas_transform().affine_inverse() * (size / 2.0)
	for index: int in TEXTURES.size():
		var drift := sin(world_center.x / 1800.0) * (width - size.x) * 0.5 * SCROLL[index]
		surface.draw_texture_rect(TEXTURES[index], Rect2((size.x - width) * 0.5 - drift, size.y - height, width, height), false)
