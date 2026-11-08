class_name WorldGearObstacle
extends Node2D
## Authored shaft/rail hazard. Shared contact policy owns damage and recovery.
const TEXTURE: Texture2D=preload("res://assets/plains_v07/native/mill_gear.png")
const RADIUS:=34.0
var definition: Dictionary
var controller: PlayerController
var policy: FrameDamagePolicy
var wheel: Sprite2D
var clock:=0.0
var origin:=Vector2.ZERO
var travel:=Vector2.ZERO
var period:=4.8
var phase:=0.0
var tooth_tick:=0
var spark_remaining:=0.0
var drive: WorldMovingPlatform

func _ready() -> void:
	process_physics_priority=100
	origin=FixedWorldProvider.point(definition.point)
	travel=FixedWorldProvider.point(definition.get("travel",[0,0]))
	period=float(definition.get("period",4.8));phase=float(definition.get("phase",0.0))
	if definition.has("drive"):drive=get_parent().get_node(str(definition.drive)) as WorldMovingPlatform
	tooth_tick=floori(phase*2+.5)
	wheel=Sprite2D.new();wheel.texture=TEXTURE;wheel.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	wheel.position=origin+travel*sin(phase*TAU);add_child(wheel)
	var contact:=DemoContactEmitter.new()
	contact.policy=policy;contact.controller=controller;contact.kind=DamageRequest.Kind.ENVIRONMENT
	contact.source_id=StringName(str(get_parent().room_id)+":"+str(definition.id))
	contact.half_size=Vector2.ONE*RADIUS
	contact.contact_test_provider=func(center: Vector2,previous: Vector2,actor: Vector2,half_size: Vector2) -> bool:
		return SawHazard.swept_contact(previous,actor-center,half_size,RADIUS)
	wheel.add_child(contact)
	queue_redraw()

func _physics_process(delta: float) -> void:
	clock=drive.motion_clock if drive!=null else clock+delta
	spark_remaining=maxf(0,spark_remaining-delta)
	wheel.position=(origin+travel*sin(TAU*(clock/period+phase))).round()
	wheel.rotation=TAU*clock/2.4
	var next_tick:=floori((clock/period+phase)*2+.5)
	if next_tick!=tooth_tick:
		tooth_tick=next_tick;spark_remaining=.14
		if controller.active and controller.motor.global_position.distance_to(wheel.global_position)<420:
			GameAudio.cue(self,&"armour")
	queue_redraw()

func _draw() -> void:
	# The fixed axle guide exposes the complete swept corridor before entry.
	var a:=origin-travel;var b:=origin+travel
	if not travel.is_zero_approx():
		draw_line(a,b,Color("17232a"),10)
		draw_line(a,b,Color("697076"),3)
		for at: Vector2 in [a,b]:
			draw_rect(Rect2(at-Vector2(7,7),Vector2(14,14)),Color("26323c"))
			draw_rect(Rect2(at-Vector2(2,2),Vector2(4,4)),Color("bfa070"))
	if spark_remaining>0 and wheel!=null:
		var at:=wheel.position+Vector2(0,RADIUS)
		var spread:=4+(1-spark_remaining/.14)*12
		for direction: Vector2 in [Vector2(-1,.5),Vector2(1,.3),Vector2(.3,1)]:
			draw_rect(Rect2((at+direction*spread).round(),Vector2(2,1)),Color("e9c284"))
