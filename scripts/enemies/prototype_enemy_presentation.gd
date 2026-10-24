class_name PrototypeEnemyPresentation
extends EnemyPresentation
const ATLAS:=preload("res://assets/plains_v7/enemies/guard_moth.png")
var moth:=false
var _pose:=0
var _old_pose:=0
var _blend:=1.0
func _process(delta:float)->void:
	super._process(delta)
	var state:StringName=actor.attack_behavior.state if actor.attack_behavior!=null else &"idle"
	var pose:int=5 if actor.health.terminal else 2 if state==&"telegraph" and moth else 1 if state==&"telegraph" else 3 if state==&"attack" and moth else 2 if state==&"attack" else 4 if state==&"recovery" else int(_clock*6)%2 if moth else 0
	if pose!=_pose:_old_pose=_pose;_pose=pose;_blend=0
	_blend=minf(1,_blend+delta/.09)
func _draw()->void:
	if actor==null:return
	var state:StringName=actor.attack_behavior.state if actor.attack_behavior!=null else &"idle"
	var pose:=5 if actor.health.terminal else 2 if state==&"telegraph" and moth else 1 if state==&"telegraph" else 3 if state==&"attack" and moth else 2 if state==&"attack" else 4 if state==&"recovery" else int(_clock*6)%2 if moth else 0
	var tint:=Color(1,.65,.45) if _hurt_time>0 else Color.WHITE
	if hit_template != null: tint = hit_template.tint()
	if actor.health.terminal:tint.a=maxf(0,1-_death_time/.6)
	var facing:=float(actor.brain.direction)
	var size:=Vector2(38,76) if moth else Vector2(36,72)
	var foot:=Vector2(0,actor.definition.collision_size.y/2)
	var offset:=Vector2(sin(_clock*3)*1.5,sin(_clock*4)*2) if moth else Vector2.ZERO
	draw_set_transform_matrix(Transform2D(Vector2(facing*_weight.x,0),Vector2(_lean,_weight.y),offset+Vector2(0,actor.definition.collision_size.y/2*(1-_weight.y))))
	var destination:=Rect2(foot-Vector2(size.x/2,size.y*.94),size)
	if _blend<1:draw_texture_rect_region(ATLAS,destination,Rect2(_old_pose*256,512 if moth else 0,256,512),Color(tint,tint.a*(1-_blend)))
	draw_texture_rect_region(ATLAS,destination,Rect2(_pose*256,512 if moth else 0,256,512),Color(tint,tint.a*_blend))
	draw_set_transform(Vector2.ZERO)
	if state==&"telegraph":
		var aim:=actor.attack_behavior.locked_direction
		if moth:
			for angle:float in [-.35,.35]:draw_line(aim.rotated(angle)*22,aim.rotated(angle)*65,Color(1,.82,.36,.55),1.5)
		else:draw_line(Vector2(facing*20,10),Vector2(facing*90,10),Color(1,.82,.36,.65),2)
