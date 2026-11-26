class_name ExplosiveContainer
extends Node2D
@export var element_id := ""
@export var section_id := "main"
@export var state_scope := "attempt"
@export var body_size := Vector2(32,48)
@export var blast_radius := 96.0
@export var fuse_s := 0.45
@export var chain_enabled := true
var stage := "intact"
var elapsed := 0.0
var body: StaticBody2D
var generation := 0
var burst_age := 1.0
var host: Dictionary

func _ready() -> void:
	body = ProjectileImpact.box(self,Rect2(-body_size/2,body_size),8)

func element_bind(context: Dictionary) -> void: host = context
func cancel_pending() -> void:
	generation += 1
	burst_age = 1
func element_state() -> Dictionary: return {"stage":stage,"elapsed":elapsed}
func element_can_receive(input: String, value: Variant) -> bool: return input=="ignite" and value==null and stage=="intact"
func element_propose(_input: String, _value: Variant) -> Dictionary: return {"stage":"warning","elapsed":0.0}
func element_restore(data: Dictionary) -> void:
	stage = data.stage
	elapsed = data.elapsed
	body.collision_layer = 8 if stage!="spent" else 0
	queue_redraw()
func mechanism_shot(packet: Dictionary) -> bool:
	if stage!="intact" or host.is_empty() or packet.get("controller")!=host.controller: return false
	element_restore(element_propose("ignite",null))
	return true
func receive_blast(point: Vector2, radius: float, _packet: Dictionary) -> void:
	if stage!="intact" or not chain_enabled: return
	var local := to_local(point)
	if local.distance_to(local.clamp(-body_size/2,body_size/2))<=radius: element_restore(element_propose("ignite",null))
func _physics_process(delta: float) -> void:
	if stage=="spent" and burst_age<.36:
		burst_age += delta
		queue_redraw()
	if stage!="warning" or host.is_empty() or not host.lifetime.active or not host.controller.active: return
	elapsed += delta
	queue_redraw()
	if elapsed<fuse_s: return
	element_restore({"stage":"spent","elapsed":fuse_s})
	burst_age = 0
	var receipt := "%s/%s/%s/%s" % [host.room.room_id,element_id,host.lifetime.actor_epoch,get_instance_id()] + "/"+str(generation)
	var bodies := ProjectileImpact.bodies(host)
	for id: String in bodies:
		var rect := ProjectileImpact.bounds_of(bodies[id])
		var at := global_position.clamp(rect.position,rect.end)
		if at.distance_squared_to(global_position)<=blast_radius*blast_radius:
			ProjectileImpact.submit_hit(host,id,element_id,receipt,global_position.direction_to(at),ProjectileImpact.profile("blast"),false)
	ProjectileImpact.blast_mechanisms(self,global_position,blast_radius,{"packet_id":receipt,"attack_kind":"explosion"})
	GameAudio.cue(self,&"armour")
func _draw() -> void:
	var foot := Vector2(0,body_size.y*.43)
	var foot_size := Vector2(body_size.x*1.10,maxf(7,body_size.y*.19))
	MechanismRegionArt.panel(self,Rect2(foot-foot_size/2,foot_size),Color("a8a1a1"))
	if stage=="spent":
		ProjectileMechanismArt.paint(self,Rect2(-body_size.x/2,foot.y-9,body_size.x,9),ProjectileMechanismArt.COALS,Color("88828d"))
		if burst_age<.36:
			PixelVfx.clip(self,&"boss-land",foot,burst_age/.36,0.,Color("ff9d58"),Vector2.ONE*clampf(blast_radius/64,.4,2))
			PixelVfx.clip(self,&"ember",Vector2.ZERO,burst_age/.36,0.,Color.WHITE,Vector2.ONE*.9)
		return
	ProjectileMechanismArt.paint(self,Rect2(-body_size/2,body_size),ProjectileMechanismArt.VESSEL)
	var collar_size := Vector2(body_size.x*.94,maxf(3.,body_size.y*.12))
	MechanismRegionArt.panel(self,Rect2(Vector2(-collar_size.x/2,body_size.y*.16),collar_size))
	for side: float in [-1,1]:
		MechanismRegionArt.stamp(self,"mount",foot+Vector2(side*body_size.x*.39,-2),Vector2(body_size.x*.28,body_size.y*.3))
	if stage=="warning":
		var fuse := clampf(elapsed/fuse_s,0,1)
		var point := Vector2(body_size.x*.27,-body_size.y*.46)
		PixelVfx.clip(self,&"spark",point,fmod(elapsed*6,.88),0,Color("ffd09a"),Vector2.ONE*.36)
		for i: int in 16:
			var angle := i*TAU/16.
			PixelVfx.arc(self,Vector2.ZERO,blast_radius,angle,angle+.17,Color(1,.62,.27,.25+fuse*.6))
