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
var host: Dictionary

func _ready() -> void:
	body = ProjectileImpact.box(self,Rect2(-body_size/2,body_size),8)

func element_bind(context: Dictionary) -> void: host = context
func cancel_pending() -> void: generation += 1
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
	if stage!="warning" or host.is_empty() or not host.lifetime.active or not host.controller.active: return
	elapsed += delta
	queue_redraw()
	if elapsed<fuse_s: return
	element_restore({"stage":"spent","elapsed":fuse_s})
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
	if stage=="spent":
		draw_rect(Rect2(-body_size.x/2,body_size.y*.34,body_size.x,body_size.y*.16),Color("534949"))
		return
	var rect := Rect2(-body_size/2,body_size)
	draw_rect(rect,Color("80503e"))
	for y: float in [-0.35,0.28]: draw_rect(Rect2(Vector2(-body_size.x/2,y*body_size.y),Vector2(body_size.x,3)),Color("b3986a"))
	draw_circle(Vector2.ZERO,5,Color("ffc075"))
	if stage=="warning": draw_arc(Vector2.ZERO,blast_radius,0,TAU,48,Color(1,.56,.18,0.4+0.5*elapsed/fuse_s),2)
