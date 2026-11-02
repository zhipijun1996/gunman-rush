class_name DamageReturnEcho
extends Node2D
## Cosmetic abandoned hit silhouette. No collision, HP, movement or callbacks.
var source: Texture2D
var source_rect := Rect2()
var destination := Rect2()
var facing := 1.0
var duration := 0.0
var age := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if duration <= 0:
		queue_free()
		return
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 5

func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	if source == null: return
	var progress := clampf(age/duration,0,1)
	draw_set_transform(Vector2(0,-progress*5),0,Vector2(facing,1))
	draw_texture_rect_region(source,destination,source_rect,Color(1,.60,.42,(1-progress)*.72))
	draw_set_transform(Vector2.ZERO)
	for i: int in 8:
		var axis := Vector2.from_angle(i*TAU/8+.2)
		var point := axis*(5+progress*23)
		draw_line(point,point+axis*4,Color("ead8a3",1-progress),2,false)
