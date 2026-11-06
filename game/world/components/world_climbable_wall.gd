class_name WorldClimbableWall
extends StaticBody2D
## Explicit visible climb surface. Ordinary stone boundaries do not receive this tag.
var bounds:=Rect2(0,0,32,320)
func _ready() -> void:
	collision_layer=1;collision_mask=0
	add_to_group(&"wall_climbable")
	var collision:=CollisionShape2D.new()
	collision.name="CollisionShape2D"
	collision.position=bounds.get_center()
	var shape:=RectangleShape2D.new();shape.size=bounds.size;collision.shape=shape
	add_child(collision)
	var solids: Array[Rect2]=[bounds]
	add_child(UnderworldTerrain.build(solids))
func _draw() -> void:
	for side: float in [bounds.position.x+3,bounds.end.x-3]:
		draw_line(Vector2(side,bounds.position.y),Vector2(side,bounds.end.y),Color("70956b"),4)
		for y: int in range(int(bounds.position.y)+8,int(bounds.end.y),16):
			draw_rect(Rect2(side-4,y,8,3),Color("a6b97b"))
