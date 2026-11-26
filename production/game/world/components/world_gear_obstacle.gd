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
var clock_source: Node
var source_room_id := ""
var motion_running := true
var path_mode := "linear"
var arc_radius := 128.0
var arc_angles_deg := Vector2(45,135)
var endpoint_dwell := 0.0
var time_scale := 1.0

func _ready() -> void:
	process_physics_priority=100
	origin=FixedWorldProvider.point(definition.point)
	travel=FixedWorldProvider.point(definition.get("travel",[0,0]))
	period=float(definition.get("period",4.8));phase=float(definition.get("phase",0.0))
	if definition.has("drive"):drive=get_parent().get_node(str(definition.drive)) as WorldMovingPlatform
	tooth_tick=floori(phase*2+.5)
	wheel=Sprite2D.new();wheel.texture=TEXTURE;wheel.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(wheel)
	refresh_position()
	var receiver := Area2D.new()
	receiver.collision_layer = 8
	receiver.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	receiver.add_child(shape)
	wheel.add_child(receiver)
	var contact:=DemoContactEmitter.new()
	contact.policy=policy;contact.controller=controller;contact.kind=DamageRequest.Kind.ENVIRONMENT
	contact.source_id=StringName((str(get_parent().room_id) if source_room_id.is_empty() else source_room_id)+":"+str(definition.id))
	contact.half_size=Vector2.ONE*RADIUS
	contact.contact_test_provider=func(center: Vector2,previous: Vector2,actor: Vector2,half_size: Vector2) -> bool:
		return SawHazard.swept_contact(previous,actor-center,half_size,RADIUS)
	wheel.add_child(contact)
	queue_redraw()

func _physics_process(delta: float) -> void:
	clock=float(clock_source.get("motion_clock")) if is_instance_valid(clock_source) else (drive.motion_clock if drive!=null else clock+(delta*time_scale if motion_running else 0.0))
	spark_remaining=maxf(0,spark_remaining-delta)
	refresh_position()
	var next_tick:=floori((clock/period+phase)*2+.5)
	if next_tick!=tooth_tick:
		tooth_tick=next_tick;spark_remaining=.14
		if controller.active and controller.motor.global_position.distance_to(wheel.global_position)<420:
			GameAudio.cue(self,&"armour")
	queue_redraw()

func refresh_position() -> void:
	var cycle := period+2.0*endpoint_dwell
	var elapsed := fposmod(clock+phase*cycle,cycle)
	var moving := elapsed-clampf(elapsed-period*0.25,0,endpoint_dwell)-clampf(elapsed-period*0.75-endpoint_dwell,0,endpoint_dwell)
	var swing := sin(TAU*moving/period)
	if path_mode == "arc":
		var angle := lerpf(arc_angles_deg.x, arc_angles_deg.y, (1.0+swing)*0.5)
		wheel.position = origin+Vector2.from_angle(deg_to_rad(angle))*arc_radius
	else: wheel.position = origin+travel*swing
	wheel.rotation=TAU*clock/2.4

func _draw() -> void:
	if wheel == null: return
	var shaft := wheel.position-origin
	if path_mode == "arc":
		var lo := deg_to_rad(minf(arc_angles_deg.x,arc_angles_deg.y))
		var hi := deg_to_rad(maxf(arc_angles_deg.x,arc_angles_deg.y))
		draw_arc(origin,arc_radius,lo,hi,48,Color("534d46"),2)
		for angle: float in [lo,hi]:
			MechanismRegionArt.stamp(self,"mount",origin+Vector2.from_angle(angle)*arc_radius,Vector2(12,12))
		draw_set_transform(origin,shaft.angle(),Vector2.ONE)
		MechanismRegionArt.panel(self,Rect2(0,-4,shaft.length(),8))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		MechanismRegionArt.stamp(self,"finial",origin,Vector2(23,23))
	elif not travel.is_zero_approx():
		var a := origin-travel
		var b := origin+travel
		draw_set_transform(a,travel.angle(),Vector2.ONE)
		MechanismRegionArt.panel(self,Rect2(0,-4,2*travel.length(),8),Color(.75,.75,.75))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		for at: Vector2 in [a,b]: MechanismRegionArt.stamp(self,"mount",at,Vector2(18,18))
	else: MechanismRegionArt.stamp(self,"mount",origin,Vector2(28,28))
	# An inset boss turns with the original mill wheel, entirely inside its teeth.
	draw_set_transform(wheel.position,wheel.rotation,Vector2.ONE)
	MechanismRegionArt.stamp(self,"hazard",Vector2.ZERO,Vector2(32,32))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if spark_remaining>0:
		PixelVfx.clip(self,&"spark",wheel.position+Vector2(0,RADIUS-2),1-spark_remaining/.14,0,Color("efbe80"),Vector2.ONE*.48)
