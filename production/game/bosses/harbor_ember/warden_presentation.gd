extends Node2D
@export var actor: EnemyActor
const METAL:=Color("#758e86")
const COPPER:=Color("#caba88")
const HOT:=Color("#f4be6b")
const SLAG:=Color("#7b4643")

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	EnemyPresentationBinding.bind_existing(actor,self,&"scene")

func _process(_delta: float) -> void: queue_redraw()

func _draw() -> void:
	if not is_instance_valid(actor) or actor.definition==null: return
	var d:=actor.definition as ArenaBossDefinition
	var b:=actor.attack_behavior as ArenaBossBehavior
	var body:=d.body_art
	var harbor:=d.behavior_id==&"harbor_warden"
	if actor.health.terminal:
		draw_texture_rect(body,Rect2(-body.get_width()/2,d.floor_offset-24,body.get_width(),24),false,Color("#797574"))
		return
	draw_set_transform(Vector2.ZERO,0,Vector2(actor.brain.direction,1))
	draw_texture(body,-body.get_size()/2)
	if b!=null and b.state==&"recovery":
		var core:=Vector2(-3,3) if harbor else Vector2(0,1)
		draw_circle(core,7,Color("#282833"))
		draw_circle(core,5,Color("#a8e3cb") if harbor else HOT)
		draw_circle(core+Vector2(-1,-1),2,Color.WHITE)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	if b==null or b.state not in [&"attack",&"telegraph"]: return
	var t:=clampf(b.state_time/d.attack_duration,0,1) if b.state==&"attack" else 0.0
	var color:=COPPER if harbor else HOT
	if b.state==&"telegraph":
		for i in range(1,16):
			var mark:=to_local(b.active_rect(float(i)/16).get_center()).round()
			draw_line(mark-Vector2(2,0),mark+Vector2(2,0),Color(color,0.72),2)
		return
	var p:=to_local(b.active_rect(t).get_center()).round()
	if harbor:
		var origin:=to_local(b.attack_origin).round()
		draw_dashed_line(origin,p,METAL,3,5)
		if b.move_id==&"anchor":
			draw_line(p-Vector2(0,17),p+Vector2(0,12),METAL,5)
			draw_polyline(PackedVector2Array([p+Vector2(-23,-7),p+Vector2(-17,9),p+Vector2(0,15),p+Vector2(16,8),p+Vector2(23,-7)]),COPPER,4)
		else:
			var face:=actor.brain.direction
			draw_colored_polygon(PackedVector2Array([p+Vector2(-22*face,-4),p+Vector2(24*face,0),p+Vector2(-9*face,8),p+Vector2(-3*face,2),p+Vector2(-22*face,4)]),METAL)
	else:
		var clinker:=b.move_id==&"clinker"
		var radius:=15 if clinker else 19
		draw_circle(p,radius,SLAG)
		draw_arc(p,radius-2,0.65,4.3,7,HOT,3)
		for i in 4:
			var point:=p+Vector2(sin(i*2.4+t)*9,cos(i*2.4+t)*7)
			draw_line(point,point+Vector2(3,-2),HOT,2)
