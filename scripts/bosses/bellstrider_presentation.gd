class_name BellstriderPresentation
extends Node2D
var pixel_style := false
@export var encounter: BellstriderEncounter
const BODY:=preload("res://assets/plains_v4/spatial/actors.png")
const CHASSIS:=preload("res://assets/plains_v4/spatial/chassis.png")
const CORE_FONT:=preload("res://assets/fonts/foundry_notes.otf")
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
var hit_template: EnemyHitTemplate
var motion := BossMotionPresentation.new()
func _ready() -> void:
	hit_template = EnemyHitTemplate.install_boss(encounter, self)
	motion.bind(encounter)
	var arrival := BossArrivalPresentation.new()
	arrival.configure(encounter,self,true)
	get_parent().add_child.call_deferred(arrival)
	_last=global_position
	encounter.health.changed.connect(func(r: ActorResourceResult) -> void:
		if r.operation==&"damage" and r.status==ActorResourceResult.Status.APPLIED:
			GameAudio.cue(self,&"core"))
	encounter.armour_hit.connect(func(_p: Vector2) -> void: GameAudio.cue(self,&"armour"))
func _process(delta: float) -> void:
	if get_tree().paused: return
	var observed := encounter.presentation_state()
	motion.sample(encounter,delta)
	clock+=delta
	if observed.terminal:death_age+=delta;modulate.a=maxf(0,1-death_age/.45)
	wheel_angle+=(global_position.x-_last.x)/25
	_last=global_position
	lean=lerpf(lean,observed.direction*.13 if observed.raw_mode==&"roll" else -.10*observed.direction if observed.raw_mode==&"roll_warning" else 0.0,1-exp(-delta*12))
	spring=lerpf(spring,5.0 if observed.raw_mode in [&"ring_warning",&"lob_warning"] else -3.0 if observed.raw_mode==&"rings" else 0.0,1-exp(-delta*10))
	if _mode!=observed.raw_mode:
		_mode=observed.raw_mode
		if _mode in [&"roll_warning",&"ring_warning",&"lob_warning"]: GameAudio.cue(self,&"warning")
		elif _mode in [&"roll",&"rings",&"lob"]: GameAudio.cue(self,&"boss_impact")
	_body_scale = _body_scale.lerp(Vector2(1.08,.75) if observed.terminal else Vector2.ONE,1-exp(-delta/.12))
	flash=maxf(0,flash-delta)
	queue_redraw()
func _draw() -> void:
	if encounter==null: return
	var observed := encounter.presentation_state()
	if UnderworldActors.enabled(self):
		motion.draw_body(self,UnderworldActors.BELLSTRIDER,Rect2(-80,-91,160,157),&"bellstrider",hit_template.tint(),float(observed.direction))
		# Existing axle coordinates and accepted travel drive independent spokes.
		for side: int in [-1,1]:
			var hub := Vector2(side*40,40)
			for spoke: int in 3:
				var axis := Vector2.from_angle(wheel_angle+spoke*TAU/3)
				PixelFormalActors.pixel_line(self,hub+axis*5,hub+axis*14,Color("7b6d3c"),2)
	elif pixel_style:
		PixelFormalActors.draw_bellstrider(self,encounter,clock,spring,wheel_angle,flash>0)
	else:
		# Wheel rotation follows real movement; chassis suspension is visual only.
		# AI painted timber braces connect chassis to wheel axles, behind both.
		for side: int in [-1,1]:
			draw_texture_rect_region(PARTS,Rect2(side*40-7,0,14,45),Rect2(292,650,88,450))
		for side: int in [-1,1]:
			var center:=Vector2(side*40,40)
			draw_set_transform(center,wheel_angle)
			draw_texture_rect_region(BODY,Rect2(-25,-25,50,50),Rect2(945,30,565,530))
		draw_set_transform(Vector2.ZERO)
		draw_set_transform(Vector2(0,spring+sin(clock*3)*1.2+14.9*(1-_body_scale.y)),lean-motion.hurt*.07*observed.direction,_body_scale)
		draw_texture_rect(CHASSIS,Rect2(Vector2(-78,-87.5),Vector2(153.6,102.4)),false,hit_template.tint())
		draw_set_transform(Vector2.ZERO)
	var core_view := encounter.presentation_core()
	if core_view.visible:
		var p: Vector2 = core_view.offset
		draw_string(CORE_FONT,p+Vector2(-20,-34),"铃芯",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("ffe9a8"))
		if UnderworldActors.enabled(self):
			var bell := UnderworldActors.icon_texture(&"bell")
			var size := bell.get_size() * (32.0 / bell.get_height())
			draw_texture_rect(bell,Rect2(p-size*.5,size),false,Color(1.5,1.3,1.0) if flash>0 else Color.WHITE)
		elif pixel_style: PixelFormalActors.bell(self,p,true,flash>0)
		else: draw_texture_rect_region(PARTS,Rect2(p-Vector2(11,14),Vector2(22,29)),Rect2(735,20,435,575))
		draw_circle(p,25,Color(1,.85,.4,.3))
		draw_arc(p,18,0,TAU,32,Color("ffe59b"),2)

func _exit_tree() -> void:
	motion.dispose(encounter)

func synchronize_presentation() -> void:
	motion.synchronize(encounter)
