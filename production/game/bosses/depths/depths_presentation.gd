extends Node2D
## Native stone cap and drilling carriage; projectile positions belong to the behavior.
@export var actor: EnemyActor
const INK := Color("#282434")
const ROCK := Color("#756a74")
const LIME := Color("#8ed5ba")
const GOLD := Color("#edb873")
const METAL := Color("#747e80")

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	EnemyPresentationBinding.bind_existing(actor,self,&"scene")

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if actor==null or actor.definition==null: return
	var definition := actor.definition as ArenaBossDefinition
	var behavior := actor.attack_behavior as ArenaBossBehavior
	var tex := definition.body_art
	var cave := actor.definition.behavior_id==&"stone_curtain_lord"
	if actor.health.terminal:
		draw_texture_rect(tex,Rect2(Vector2(-tex.get_width()/2,definition.floor_offset-20),Vector2(tex.get_width(),20)),false,Color("#7d7779"))
		return
	var facing := actor.brain.direction
	var open := behavior!=null and behavior.state==&"recovery"
	var at := -tex.get_size()/2
	if cave:
		var lift := 5.0+sin(behavior.state_time*3)*2 if open else 0.0
		draw_texture(tex,at-Vector2(0,lift))
		for x: int in [-20,-8,6,18]:
			draw_line(Vector2(x,16-lift),Vector2(x+1,22),LIME.darkened(0.5),3)
		draw_circle(Vector2(0,18-lift),7 if open else 3,LIME if open else ROCK)
	else:
		draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
		draw_texture(tex,at)
		draw_circle(Vector2(-48,2),9 if open else 5,LIME if open else METAL)
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	if behavior==null or behavior.move_id.is_empty(): return
	if behavior.state==&"telegraph" or behavior.state==&"attack":
		var t:=behavior.state_time/definition.attack_duration if behavior.state==&"attack" else 0.0
		if behavior.state==&"telegraph":
			for step: int in range(1,10):
				for rect: Rect2 in behavior.hit_rects(float(step)/10):
					draw_circle(to_local(rect.get_center()).round(),2,LIME if cave else GOLD)
			if not cave:
				var count:=clampi(ceili(4-4*behavior.state_time/definition.telegraph_duration),0,4)
				for i: int in 4:
					draw_rect(Rect2(-24+i*12,-22,6,3),GOLD if i<count else INK)
		for rect: Rect2 in behavior.hit_rects(t):
			_draw_head(behavior,rect)
	elif not cave and open and behavior.move_id!=&"shale":
		_draw_head(behavior,behavior.active_rect(1-clampf(behavior.state_time/(definition.recovery_duration*0.5),0,1)))

func _draw_head(behavior: ArenaBossBehavior, r: Rect2) -> void:
	var center := to_local(r.get_center()).round()
	var extent := r.size/2
	match behavior.move_id:
		&"bore", &"short_bore":
			var side:=behavior.locked_direction.x
			var nose:=center+Vector2(side*extent.x,0)
			var root_x:=center.x-side*extent.x
			draw_line(Vector2(side*52,center.y),Vector2(root_x,center.y),INK,15)
			draw_line(Vector2(side*52,center.y-2),Vector2(root_x,center.y-2),METAL,7)
			draw_colored_polygon(PackedVector2Array([Vector2(root_x,center.y-extent.y),nose,Vector2(root_x,center.y+extent.y)]),METAL)
			for i:int in 5:
				var u:=float(i)/5
				var x:=lerpf(root_x,nose.x,u)
				draw_line(Vector2(x,center.y-extent.y*(1-u)),Vector2(x+side*5,center.y+extent.y*(1-u)),INK,3)
		&"stonefall", &"shale":
			draw_colored_polygon(PackedVector2Array([center+Vector2(-extent.x,0),center+Vector2(-extent.x/2,-extent.y),center+Vector2(extent.x,-extent.y/2),center+Vector2(extent.x/2,extent.y),center+Vector2(-extent.x,extent.y/2)]),ROCK)
			draw_line(center+Vector2(-extent.x/2,-extent.y),center+Vector2(extent.x,-extent.y/2),METAL,2)
		_:
			draw_circle(center,extent.x,INK)
			draw_circle(center,extent.x-2,Color("#569280"))
			draw_circle(center-Vector2(2,2),3,LIME)
