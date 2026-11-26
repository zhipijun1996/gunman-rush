class_name ProjectileDrag
extends ProjectileField
@export var bounds := Rect2(0,0,192,128)
@export var speed_scale := 0.35
@export var factions: Array[String] = ["player","enemy"]

func _draw() -> void:
	draw_rect(bounds,Color("8b9ed837"))
	draw_rect(bounds,Color("aebadc8c"),false,1)
	for y in range(8,int(bounds.size.y),14):
		var offset := (y*7)%21
		for x in range(4+offset,int(bounds.size.x)-6,27):
			draw_line(bounds.position+Vector2(x,y),bounds.position+Vector2(x+6,y),Color("a9c8df90"),1)
