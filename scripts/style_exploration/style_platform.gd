class_name StylePlatform
extends StaticBody2D
## Wood bridges own separate one-way physics, never a terrain-mask substitute.
var bounds := Rect2(0, 0, 96, 8)
var style_id := "retro"
const COLORS := {
	"retro": [Color("97b8b4"), Color("343a4c"), Color("dcead3")],
	"basic": [Color("b99167"), Color("59485d"), Color("f1d697")],
	"scribble": [Color("d9ba8e"), Color("353c3d"), Color("fff2c5")],
	"underworld": [Color("29424b"), Color("0a1827"), Color("72d0c5")],
	"cavern": [Color("799b82"), Color("253e4c"), Color("b8ce84")]}

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("one_way_platform")
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = bounds.size
	collision.shape = shape
	collision.position = bounds.get_center()
	collision.one_way_collision = true
	add_child(collision)

func configure(value: String) -> void:
	style_id = value
	queue_redraw()

func _draw() -> void:
	var palette: Array = COLORS[style_id]
	draw_rect(bounds, palette[1])
	for x: int in range(0, int(bounds.size.x), 12):
		draw_rect(Rect2(x + 1, 1, 10, 5), palette[0])
		draw_line(Vector2(x + 2, 1), Vector2(x + 9, 1), palette[2], 1)
	# Slender support ropes are presentation only, and leave the jumping lane clear.
	draw_line(Vector2(0, bounds.size.y + 3), Vector2(bounds.size.x / 2, bounds.size.y + 12), palette[1], 2)
	draw_line(Vector2(bounds.size.x / 2, bounds.size.y + 12), Vector2(bounds.size.x, bounds.size.y + 3), palette[1], 2)
