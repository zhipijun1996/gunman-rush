extends Node2D
@export var actor:EnemyActor
const BRONZE:=Color("#e8ae64")
const FROST:=Color("#a4ebf6")

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	EnemyPresentationBinding.bind_existing(actor,self,&"scene")

func _process(_delta:float) -> void:
	queue_redraw()

func _draw() -> void:
	if actor==null or actor.definition==null: return
	var d:=actor.definition as ArenaBossDefinition
	var b:=actor.attack_behavior as ArenaBossBehavior
	var tex:=d.body_art
	var tomb:=d.stable_id==&"royal_bell_bearer"
	var doll:=d.stable_id==&"frost_echo_doll"
	var color:=BRONZE if tomb else FROST
	var foot:=Vector2(0,d.floor_offset)
	var side:=actor.brain.direction
	var open:=b!=null and b.state==&"recovery"
	var sinking:=actor.health.terminal
	var h:=float(tex.get_height())
	var w:=float(tex.get_width())
	var bend:=.24 if sinking else (.91 if open else 1.0)
	draw_set_transform(foot,0,Vector2(side,bend))
	draw_texture(tex,Vector2(-w/2,-h),Color("#858995") if sinking else Color.WHITE)
	if open:
		var core:=Vector2(-w*.35,-h*.71) if tomb else Vector2(0,-h*.51)
		draw_circle(core,5,color.darkened(.48))
		draw_circle(core,3,color)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	if b==null or sinking or b.state not in [&"telegraph",&"attack"]: return
	var warning:=b.state==&"telegraph"
	var t:=0.0 if warning else clampf(b.state_time/d.attack_duration,0,1)
	if doll:
		var pivot:=to_local(b.attack_goal).round()
		draw_set_transform(pivot+Vector2(0,50),0,Vector2(side,1))
		draw_texture(tex,Vector2(-w/2,-h),Color(.61,.84,1,.42))
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	if warning:
		for i in range(11):
			for rect:Rect2 in b.hit_rects(float(i)/10):
				if rect.has_area(): draw_circle(to_local(rect.get_center()).round(),2,color.darkened(.25))
	for rect:Rect2 in b.hit_rects(t):
		if not rect.has_area(): continue
		var p:=to_local(rect.get_center()).round()
		var e:=rect.size/2
		if tomb and e.x>=30:
			draw_colored_polygon(PackedVector2Array([p+Vector2(-e.x,e.y-4),p+Vector2(-20,-e.y+8),p+Vector2(-9,-e.y),p+Vector2(10,-e.y),p+Vector2(22,-e.y+8),p+Vector2(e.x,e.y-4)]),BRONZE.darkened(.36))
			draw_line(p+Vector2(-e.x,13),p+Vector2(e.x,13),BRONZE,3)
		else:
			draw_colored_polygon(PackedVector2Array([p-Vector2(0,e.y),p+Vector2(e.x,0),p+Vector2(0,e.y),p-Vector2(e.x,0)]),color.darkened(.33))
			draw_line(p-Vector2(0,e.y-2),p+Vector2(-e.x+2,0),color,2)
