class_name BellstriderPresentation
extends Node2D
@export var encounter: BellstriderEncounter
const BODY:=preload("res://assets/plains_v4/spatial/actors.png")
const CHASSIS:=preload("res://assets/plains_v4/spatial/chassis.png")
const CORE_FONT:=preload("res://assets/fonts/windkeeper_ui.ttf")
const PARTS:=preload("res://assets/plains_v4/windkeeper/parts.png")
var clock:=0.0
var wheel_angle:=0.0
var lean:=0.0
var spring:=0.0
var _last:=Vector2.ZERO
var _mode: StringName
var flash:=0.0
var death_age:=0.0
var _body_scale := Vector2.ONE
func _ready() -> void:
	var arrival := BossArrivalPresentation.new()
	arrival.configure(encounter,self,true)
	get_parent().add_child.call_deferred(arrival)
	_last=global_position
	encounter.health.changed.connect(func(r: ActorResourceResult) -> void:
		if r.operation==&"damage" and r.status==ActorResourceResult.Status.APPLIED:
			flash=.16;GameAudio.cue(self,&"core"))
	encounter.armour_hit.connect(func(_p: Vector2) -> void: GameAudio.cue(self,&"armour"))
func _process(delta: float) -> void:
	clock+=delta
	if encounter.health.terminal:death_age+=delta;modulate.a=maxf(0,1-death_age/.45)
	wheel_angle+=(global_position.x-_last.x)/25
	_last=global_position
	lean=lerpf(lean,encounter.direction*.13 if encounter.mode==&"roll" else -.10*encounter.direction if encounter.mode==&"roll_warning" else 0.0,1-exp(-delta*12))
	spring=lerpf(spring,5.0 if encounter.mode in [&"ring_warning",&"lob_warning"] else -3.0 if encounter.mode==&"rings" else 0.0,1-exp(-delta*10))
	if _mode!=encounter.mode:
		_mode=encounter.mode
		if _mode in [&"roll_warning",&"ring_warning",&"lob_warning"]: GameAudio.cue(self,&"warning")
		elif _mode in [&"roll",&"rings",&"lob"]: GameAudio.cue(self,&"boss_impact")
	_body_scale = _body_scale.lerp(Vector2(1.08,.75) if encounter.health.terminal else Vector2.ONE,1-exp(-delta/.12))
	flash=maxf(0,flash-delta)
	queue_redraw()
func _draw() -> void:
	if encounter==null: return
	# Wheel rotation follows real movement; chassis suspension is visual only.
	# AI painted timber braces connect chassis to wheel axles, behind both.
	for side: int in [-1,1]:
		draw_texture_rect_region(PARTS,Rect2(side*40-7,0,14,45),Rect2(292,650,88,450))
	for side: int in [-1,1]:
		var center:=Vector2(side*40,40)
		draw_set_transform(center,wheel_angle)
		draw_texture_rect_region(BODY,Rect2(-25,-25,50,50),Rect2(945,30,565,530))
	draw_set_transform(Vector2.ZERO)
	draw_set_transform(Vector2(0,spring+sin(clock*3)*1.2+14.9*(1-_body_scale.y)),lean,_body_scale)
	draw_texture_rect(CHASSIS,Rect2(Vector2(-78,-87.5),Vector2(153.6,102.4)),false,Color(1.4,1.25,.9) if flash>0 else Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	if encounter.core_open:
		var p:=encounter.core_offset()
		draw_string(CORE_FONT,p+Vector2(-20,-34),"铃芯",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("ffe9a8"))
		draw_texture_rect_region(PARTS,Rect2(p-Vector2(11,14),Vector2(22,29)),Rect2(735,20,435,575))
		draw_circle(p,25,Color(1,.85,.4,.3))
		draw_arc(p,18,0,TAU,32,Color("ffe59b"),2)
		var remaining:=clampf(encounter.clock/(encounter.definition as WindkeeperDefinition).exposed_seconds,0,1)
		draw_arc(p,29,-PI/2,-PI/2+TAU*remaining,40,Color("95dab0"),2)
		draw_string(CORE_FONT,p+Vector2(25,-20),"OPEN %.1fs" % maxf(0,encounter.clock),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("d6f3d1"))
	if encounter.mode==&"roll_warning":
		var distance:=encounter.roll_warning_distance()
		var end:=Vector2(encounter.direction*distance,48)
		draw_line(Vector2(0,48),end,Color(1,.67,.25,.7),4)
		for i: int in 4:
			var p:=Vector2(encounter.direction*distance*(i+1)/5.0,44)
			draw_line(p-Vector2(encounter.direction*8,6),p,Color("f1d58d"),2)
	if encounter.mode in [&"lob_warning",&"lob"]:
		var p:=encounter.locked_point-global_position
		draw_arc(p,25,0,TAU,32,Color(1,.64,.3,.8),3)
		draw_line(p-Vector2(33,0),p+Vector2(33,0),Color("f6d294"),2)
		if encounter.stage_phase==2: draw_arc(p+Vector2(110*encounter.direction,-20),25,0,TAU,32,Color(1,.64,.3,.45),2)
	if encounter.mode==&"ring_warning": draw_arc(Vector2(0,48),40+sin(clock*12)*5,PI,TAU,32,Color("f2d698"),3)
