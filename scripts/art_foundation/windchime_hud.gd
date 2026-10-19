class_name WindchimeHUD
extends Control
## Compact real HP/energy HUD. The map strip reports actual player progress.
const FONT := preload("res://assets/fonts/foundry_notes.otf")
var controller: PlayerController
var lab: WindchimeLab

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if controller == null or lab == null: return
	var ink := Color("33493f")
	var cream := Color("f5e7c2")
	var gold := Color("c7aa6d")
	var coral := Color("d56b58")
	draw_circle(Vector2(49,45),29,Color(.05,.15,.2,.88))
	draw_arc(Vector2(49,45),27,-PI/2,TAU-PI/2,64,gold,1,true)
	var energy := controller.actor_resources.stamina.current / maxf(1,controller.actor_resources.stamina.capacity)
	draw_arc(Vector2(49,45),22,-PI/2,-PI/2+energy*TAU,64,cream,2,true)
	draw_line(Vector2(49,45),Vector2(49,25),cream,2,true)
	draw_circle(Vector2(49,45),3,cream)
	var health := controller.actor_resources.health
	for i: int in ceili(health.capacity):
		var p := Vector2(99+i*21,32)
		var points := PackedVector2Array([p+Vector2(0,-7),p+Vector2(7,0),p+Vector2(0,7),p+Vector2(-7,0),p+Vector2(0,-7)])
		if i < health.current: draw_colored_polygon(points,coral)
		else: draw_polyline(points,cream,1,true)
	draw_string(FONT,Vector2(92,63),"ENERGY  %.0f" % controller.actor_resources.stamina.current,HORIZONTAL_ALIGNMENT_LEFT,-1,12,ink)
	draw_string(FONT,Vector2(1025,36),"风铃平原",HORIZONTAL_ALIGNMENT_LEFT,-1,25,ink)
	draw_string(FONT,Vector2(1025,56),"WIND CHIME PLAINS",HORIZONTAL_ALIGNMENT_LEFT,-1,12,ink)
	draw_line(Vector2(1025,68),Vector2(1247,68),Color(1,.96,.85,.55),1,true)
	var x := 1028.0
	for i: int in 5:
		var rect := Rect2(x+i*40,83,35,14)
		draw_rect(rect,Color(1,.95,.8,.68),false,1)
	var ratio := clampf(lab.player.position.x/lab.layout.bounds.end.x,0,1)
	draw_circle(Vector2(x+ratio*195,90),3,gold)
	var caption := "A/D 移动   SPACE 跳跃   松开鼠标射击"
	if lab._material_mode: caption = "材料验收场 · 实体 / 单向 / 移动平台"
	elif not controller.active: caption = "已倒下 · 点击 Restart 重新开始"
	elif lab.player.position.x > 2350: caption = "已到达风铃庭 · 可以原路返回探索"
	draw_string(FONT,Vector2(24,697),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,13,cream)
