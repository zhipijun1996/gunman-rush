class_name WindchimeScenery
extends Node2D
## Grounded decorative architecture. No collision, RNG or gameplay callbacks.
var sockets: Array[Dictionary] = []
var one_way: Array[Rect2] = []
var _clock := 0.0

func _ready() -> void:
	z_index = -1

func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()

func _draw() -> void:
	for socket: Dictionary in sockets:
		var p: Vector2 = socket.position
		match socket.kind:
			&"entry_chime": _chime(p, false)
			&"hero_landmark": _chime(p, true)
			&"endpoint":
				draw_line(p, p + Vector2(0,-44), Color("bba36a"), 3, true)
				draw_arc(p+Vector2(0,-44),14,0,TAU,40,Color("d4b66f"),4,true)
				draw_circle(p+Vector2(0,-44),3,Color("f7e8bf"))
	for bridge: Rect2 in one_way:
		var left := bridge.position + Vector2(3,0)
		var right := Vector2(bridge.end.x-3,bridge.position.y)
		for p: Vector2 in [left,right]:
			draw_line(p,p+Vector2(0,-31),Color("4e5c55"),4,true)
			draw_circle(p+Vector2(0,-31),3,Color("a89d73"))
		var rope := PackedVector2Array()
		for i: int in 25:
			var t := float(i)/24
			rope.append(left.lerp(right,t)+Vector2(0,-24+sin(t*PI)*12))
		draw_polyline(rope,Color("707662"),2,true)

func _chime(root: Vector2, landmark: bool) -> void:
	var ink := Color("37483e")
	var gold := Color("b79a57")
	var cream := Color("eee2bb")
	var h := 196.0 if landmark else 220.0
	var top := root + Vector2(0,-h)
	var reach := 122.0 if landmark else 110.0
	draw_line(root,top,ink,8,true)
	draw_line(top+Vector2(-12,0),top+Vector2(reach,0),ink,8,true)
	draw_line(top+Vector2(0,41),top+Vector2(43,0),ink,5,true)
	draw_circle(top+Vector2(-12,0),5,ink)
	draw_line(root+Vector2(0,-12),root+Vector2(8,-12),gold,3,true)
	# A cloth banner, suspended from the beam; its edge never forms a platform.
	var wave := sin(_clock*1.5+(1 if landmark else 0))*3
	var x := -51.0
	draw_line(top+Vector2(x-7,5),top+Vector2(0,5),ink,4,true)
	draw_colored_polygon(PackedVector2Array([top+Vector2(x,8),top+Vector2(x+37,8),top+Vector2(x+37+wave,117),top+Vector2(x+wave,94)]),cream)
	draw_colored_polygon(PackedVector2Array([top+Vector2(x,76),top+Vector2(x+37,99),top+Vector2(x+37+wave,108),top+Vector2(x+wave,85)]),gold)
	var emblem := top+Vector2(x+18,40)
	draw_arc(emblem,9,0,TAU,32,gold,2,true)
	draw_line(emblem+Vector2(0,-15),emblem+Vector2(0,32),gold,2,true)
	for i: int in 3:
		var hook := top+Vector2(54+i*22,4)
		var length: float = 57.0 + [10.0,33.0,18.0][i]
		var angle := sin(_clock*1.35+i*.35)*.035
		var offset := Vector2(sin(angle),cos(angle))
		draw_line(hook,hook+offset*26,gold,1,true)
		draw_line(hook+offset*26,hook+offset*length,gold,5,true)
		draw_line(hook+offset*27+Vector2(-1,0),hook+offset*(length-2)+Vector2(-1,0),cream,1,true)
	var center := top+Vector2(77,4)
	draw_line(center,center+Vector2(sin(_clock*1.35)*3,121),gold,1,true)
	draw_arc(center+Vector2(sin(_clock*1.35)*3,126),5,0,TAU,24,gold,2,true)
