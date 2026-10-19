class_name Blob47Platform
extends AnimatableBody2D
## Separate visual grammar: thin wood = one-way; copper chassis = moving solid.
var bounds := Rect2(0, 0, 96, 16)
var travel := Vector2.ZERO
var period := 4.0
var one_way := false
var _origin := Vector2.ZERO
var _clock := 0.0

func _ready() -> void:
	process_physics_priority = -100
	_origin = position
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = bounds.size
	shape.shape = rectangle
	shape.position = bounds.get_center()
	shape.one_way_collision = one_way
	if one_way: add_to_group("one_way_platform")
	add_child(shape)

func _physics_process(delta: float) -> void:
	_clock += delta
	if not travel.is_zero_approx():
		position = _origin + travel * (.5 - .5 * cos(_clock * TAU / period))

func _draw() -> void:
	var rect := bounds
	var ink := Color("49443d")
	draw_style_box(_box(Color("a97550") if one_way else Color("bc935c"), ink), rect)
	draw_line(rect.position + Vector2(2, 2), Vector2(rect.end.x - 2, rect.position.y + 2), Color("f2d595"), 3)
	for x: int in range(int(rect.position.x) + 8, int(rect.end.x), 16):
		draw_line(Vector2(x, rect.position.y + 5), Vector2(x, rect.end.y - 2), ink.lightened(.16), 1)
	if not one_way:
		for x: float in [rect.position.x + 10, rect.end.x - 10]:
			draw_circle(Vector2(x, rect.end.y - 5), 2, ink)
		draw_line(rect.position + Vector2(8, 7), rect.position + Vector2(14, 11), Color("80b5b0"), 2)
		draw_line(rect.position + Vector2(14, 11), rect.position + Vector2(20, 7), Color("80b5b0"), 2)

static func _box(color: Color, outline: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = outline
	style.set_border_width_all(2)
	style.set_corner_radius_all(2)
	return style
