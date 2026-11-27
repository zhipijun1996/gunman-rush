extends Node2D
@export var actor: EnemyActor
const INK := Color("#252833")
const COPPER := Color("#a57551")
const GOLD := Color("#f9c177")
const AQUA := Color("#87d9cb")
const MAGMA := Color("#eb8050")

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	EnemyPresentationBinding.bind_existing(actor,self,&"scene")

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if actor==null or actor.definition==null: return
	var data:=actor.definition as ArenaBossDefinition
	var behavior:=actor.attack_behavior as ArenaBossBehavior
	var tex:=data.body_art
	var pump:=data.behavior_id==&"tide_pump_bell"
	if pump and behavior!=null: _nozzles(behavior)
	if actor.health.terminal:
		draw_texture_rect(tex,Rect2(Vector2(-tex.get_width()/2,data.floor_offset-26),Vector2(tex.get_width(),26)),false,Color("#898080"))
		return
	var facing:=1 if pump else actor.brain.direction
	draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
	draw_texture(tex,-tex.get_size()/2)
	var open:=behavior!=null and behavior.state==&"recovery"
	var core:=Vector2(0,12) if pump else Vector2(5,17)
	draw_circle(core,9 if open else 4,INK)
	draw_circle(core,7 if open else 2,(AQUA if pump else GOLD) if open else COPPER)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	if behavior==null or behavior.state not in [&"telegraph",&"attack"]: return
	var warn:=behavior.state==&"telegraph"
	var t:=0.0 if warn else behavior.state_time/data.attack_duration
	var head:=behavior.active_rect(t)
	head.position=to_local(head.position).round()
	if pump:
		var foot:=to_local(behavior.attack_origin)
		if warn:
			for h: int in range(7,151,17):
				draw_line(foot+Vector2(-39,-h),foot+Vector2(-32,-h-3),AQUA,2)
				draw_line(foot+Vector2(39,-h),foot+Vector2(32,-h-3),AQUA,2)
		else:
			draw_rect(head,Color("#5599a282"))
			for i: int in 7:
				var x:=head.position.x+6+i*11
				var chop:=fmod(behavior.state_time*97+i*13,23)
				draw_line(Vector2(x,head.end.y),Vector2(x+2,head.position.y+chop),AQUA if i%2==0 else Color("#64b3b2"),3)
	else:
		match behavior.move_id:
			&"roll":
				var length:=clampf(behavior.state_time/behavior.warning_seconds(),0,1) if warn else 1.0
				for i: int in range(ceili(5*length)):
					var at:=Vector2((i*18-41)*facing,-17-absf(sin(i*0.65))*11)
					draw_line(at,at+Vector2(7*facing,-3),GOLD if i==4 else MAGMA,3)
				if warn:
					for i: int in range(1,10):
						var at:=to_local(behavior.attack_origin.lerp(behavior.attack_goal,float(i)/10))+Vector2(0,data.floor_offset-4)
						draw_line(at,at+Vector2(facing*7,-2),MAGMA,2)
			&"shed":
				var target:=to_local(behavior.attack_goal)
				draw_line(target+Vector2(-37,15),target+Vector2(37,15),GOLD,2)
				var center:=head.get_center()
				var poly:=PackedVector2Array()
				for p: Vector2 in EmberSpentShell.OUTLINE: poly.append(center+p+Vector2(0,15))
				draw_colored_polygon(poly,Color("#52404c"))
				draw_polyline(poly,COPPER,3)
			&"vent":
				if warn:
					draw_line(to_local(behavior.attack_origin),to_local(behavior.attack_goal),GOLD,2)
				else:
					for i: int in 7:
						var at:=head.position+Vector2(9+i*10,14+sin(behavior.state_time*11+i)*5)
						draw_circle(at,6+i*0.6,MAGMA if i<3 else Color("#aaa196"))

func _nozzles(b: ArenaBossBehavior) -> void:
	for label: StringName in [&"port",&"keel",&"starboard"]:
		var offset: float=preload("res://game/bosses/tide_and_ember/pump_keeper.gd").NOZZLES[label]
		var foot:=to_local(Vector2(b.home.x+offset,b.floor_y))
		draw_rect(Rect2(foot-Vector2(46,10),Vector2(92,10)),INK)
		draw_rect(Rect2(foot-Vector2(42,8),Vector2(84,5)),COPPER)
		for i: int in range(-34,40,11):
			draw_line(foot+Vector2(i,-7),foot+Vector2(i+3,-2),INK,3)
		var lit:=b.move_id==label and b.state in [&"telegraph",&"attack"]
		draw_rect(Rect2(foot-Vector2(6,14),Vector2(12,7)),GOLD if lit else Color("#486863"))
