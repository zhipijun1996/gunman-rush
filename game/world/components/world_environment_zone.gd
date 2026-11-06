class_name WorldEnvironmentZone
extends Node2D
## Authored environmental challenge; queries equipped effects, never grants progress.
var bounds:=Rect2()
var mode:="gas"
var services: WorldServices
var controller: PlayerController
var policy: FrameDamagePolicy
var lifetime: DemoLifetime
var serial:=0
var clock:=0.0
func _physics_process(delta: float) -> void:
	queue_redraw()
	if mode not in ["gas","phase_light","thorns"] or not bounds.intersects(Rect2(controller.motor.position-Vector2(12,18),Vector2(24,36))): return
	if mode=="gas" and services.active("filter"): return
	clock-=delta
	if clock>0: return
	clock=.5;serial+=1
	var request:=DamageRequest.new()
	request.target_id=&"player";request.source_id=StringName(name)
	request.event_id=StringName(str(name)+":"+str(serial))
	request.token=lifetime.token();request.actor_epoch=lifetime.actor_epoch
	request.health_epoch=controller.actor_resources.health.epoch
	request.kind=DamageRequest.Kind.ENVIRONMENT;request.amount=1
	request.hazard_category=&"phase_light" if mode=="phase_light" else &"solid"
	policy.submit(request)
func _draw() -> void:
	if services==null: return
	if mode=="thorns":
		WorldProps.draw_thorns(self,bounds)
	elif mode=="gas":
		draw_rect(bounds,Color(.38,.58,.24,.35))
		for x: int in range(int(bounds.position.x),int(bounds.end.x),12):
			draw_line(Vector2(x,bounds.position.y),Vector2(x+6,bounds.end.y),Color(.55,.7,.3,.3),2)
	elif mode=="phase_light":
		draw_rect(bounds,Color(.95,.78,.35,.35))
		for y: int in range(int(bounds.position.y),int(bounds.end.y),8): draw_line(Vector2(bounds.position.x,y),Vector2(bounds.end.x,y),Color("f3d98c"),1)
	else:
		draw_rect(bounds,Color(0.02,.04,.06,.12 if services.active("lamp") else .7))
