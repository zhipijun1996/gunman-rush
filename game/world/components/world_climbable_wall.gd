class_name WorldClimbableWall
extends StaticBody2D
## Legacy authored wall rectangles; all solid terrain sides share climbing rules.
var bounds:=Rect2(0,0,32,320)
func _ready() -> void:
	collision_layer=1;collision_mask=0
	var collision:=CollisionShape2D.new()
	collision.name="CollisionShape2D"
	collision.position=bounds.get_center()
	var shape:=RectangleShape2D.new();shape.size=bounds.size;collision.shape=shape
	add_child(collision)
	var solids: Array[Rect2]=[bounds]
	add_child(UnderworldTerrain.build(solids))
