class_name ProjectileGrate
extends ProjectileField
@export var bounds := Rect2(0,0,32,128)
var body: StaticBody2D

func _ready() -> void:
	body = StaticBody2D.new()
	body.position = bounds.get_center()
	var shape := RectangleShape2D.new()
	shape.size = bounds.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _draw() -> void:
	draw_rect(bounds,Color("273639"),false,3)
	for x in range(3,int(bounds.size.x),8):
		draw_line(bounds.position+Vector2(x,0),bounds.position+Vector2(x,bounds.size.y),Color("827d70"),3)
	for y in range(4,int(bounds.size.y),32):
		draw_line(bounds.position+Vector2(0,y),bounds.position+Vector2(bounds.size.x,y),Color("a29475"),3)
