class_name BossArenaSeal
extends Node2D
## Two real walls, armed only after the full player body enters. No player motion writes.
var arena:Rect2
var containment:Rect2
var controller:PlayerController
var encounter:BossEncounter
var lifetime:DemoLifetime
var walls:Array[StaticBody2D]=[]
var armed:=false
var closed:=false
var clock:=0.0
var close_count:=0
func setup(bounds:Rect2,world_bounds:Rect2,player:PlayerController,boss:BossEncounter,scope:DemoLifetime)->void:
	arena=bounds;controller=player;encounter=boss;lifetime=scope
	containment=Rect2(bounds.position.x,world_bounds.position.y-200,bounds.size.x,world_bounds.size.y+400)
	for x:float in [bounds.position.x-12,bounds.end.x+12]:
		var wall:=StaticBody2D.new();wall.collision_layer=0;wall.position=Vector2(x,world_bounds.get_center().y)
		var shape:=CollisionShape2D.new();var rectangle:=RectangleShape2D.new();rectangle.size=Vector2(24,world_bounds.size.y+400);shape.shape=rectangle;wall.add_child(shape);add_child(wall);walls.append(wall)
func arm()->bool:
	if armed or closed or not lifetime.active or encounter.health.terminal:return false
	var body:=Rect2(controller.motor.global_position-Vector2(12,18),Vector2(24,36))
	if not Rect2(arena.position+Vector2(24,0),arena.size-Vector2(48,0)).encloses(body):return false
	armed=true;clock=0
	var camera:=get_viewport().get_camera_2d()
	if camera is StageCameraRig:camera.add_impulse(6,.65)
	GameAudio.cue(self,&"warning");queue_redraw();return true
func restore_closed(value:bool)->void:
	closed=value and not encounter.health.terminal;armed=closed;clock=.8 if closed else 0
	for wall:StaticBody2D in walls:wall.collision_layer=1 if closed else 0
	queue_redraw()
func release()->void:
	closed=false;armed=false
	for wall:StaticBody2D in walls:wall.collision_layer=0
	queue_redraw()
func _physics_process(delta:float)->void:
	if not lifetime.active or encounter.health.terminal:
		if closed or armed:release()
		return
	if not armed or closed:return
	clock+=delta
	var body:=Rect2(controller.motor.global_position-Vector2(12,18),Vector2(24,36))
	if not containment.encloses(body):armed=false;queue_redraw();return
	if clock>=.65:
		closed=true;close_count+=1
		for wall:StaticBody2D in walls:wall.collision_layer=1
		GameAudio.cue(self,&"boss_impact")
	queue_redraw()
func _draw()->void:
	if not armed and not closed:return
	var alpha:=1.0 if closed else .4+.3*sin(clock*20)
	for x:float in [arena.position.x,arena.end.x]:
		var target:=Rect2(x-12,arena.position.y,24,arena.size.y)
		if UnderworldActors.enabled(self): UnderworldTerrain.draw_mechanism_beam(self,target,alpha)
		elif PixelFormalActors.pixel_context(self): PixelFormalActors.gate(self,target,alpha)
		else: draw_texture_rect_region(ShotLatch.GATE_ART,target,Rect2(366,47,105,320),Color(.75,.9,.75,alpha))
		draw_line(Vector2(x,arena.position.y),Vector2(x,arena.end.y),Color(.63,.57,.34,alpha*.5),1)
	var text:="BOSS ARENA SEALED" if closed else "WIND GATES CLOSING"
	var font:=ThemeDB.fallback_font;var size:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,18)
	var at:=Vector2(arena.get_center().x-size.x/2,arena.position.y+24)
	draw_rect(Rect2(at-Vector2(6,20),size+Vector2(12,10)),Color(.06,.12,.10,.9))
	draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("f5dfa0"))
