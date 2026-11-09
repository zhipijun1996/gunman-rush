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
var _dark: ShaderMaterial
var _lit:=false
var water_time:=0.0
var splash_age:=9.0
var splash_point:=Vector2.ZERO
func _process(delta: float) -> void:
	if mode!="water":return
	water_time+=delta;splash_age+=delta;queue_redraw()
func _water_accepted() -> void:
	splash_age=0;splash_point=Vector2(controller.motor.position.x,bounds.position.y)
	GameAudio.cue(self,&"plains_water_splash")
func _ready() -> void:
	if mode!="dark": return
	var shade:=ColorRect.new();shade.position=bounds.position;shade.size=bounds.size
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_dark=ShaderMaterial.new();_dark.shader=preload("res://game/world/components/world_darkness.gdshader")
	shade.material=_dark;add_child(shade)
func _physics_process(delta: float) -> void:
	if mode=="dark":
		var lit:=services.active("lamp")
		if lit!=_lit:
			_lit=lit;_dark.set_shader_parameter("darkness",.06 if lit else .38)
		return
	if mode not in ["gas","phase_light","thorns","water"] or not bounds.intersects(Rect2(controller.motor.position-Vector2(12,18),Vector2(24,36))): return
	if mode=="gas" and services.active("filter"): return
	# A light curtain is solid danger whenever actual recoil protection is absent.
	# A rejected protected request must not leave a half-second pass for the next
	# unprotected overlap, including an ended recoil still inside the curtain.
	if mode!="phase_light":
		clock-=delta
		if clock>0: return
		clock=.5
	serial+=1
	var request:=DamageRequest.new()
	request.target_id=&"player";request.source_id=StringName(name)
	request.event_id=StringName(str(name)+":"+str(serial))
	request.token=lifetime.token();request.actor_epoch=lifetime.actor_epoch
	request.health_epoch=controller.actor_resources.health.epoch
	request.kind=DamageRequest.Kind.ENVIRONMENT;request.amount=1
	request.hazard_category=&"phase_light" if mode=="phase_light" else &"solid"
	if mode=="water":request.on_damage_applied=_water_accepted
	policy.submit(request)
func _draw() -> void:
	if services==null: return
	if mode=="water":
		draw_rect(bounds,Color("244c54"))
		for row: int in 5:
			for x: int in range(int(bounds.position.x)+8,int(bounds.end.x)-24,32):
				var y:=bounds.position.y+row*9+roundf(sin(water_time*2+x*.04+row)*2)
				draw_rect(Rect2(Vector2(x,y),Vector2(18,2)),Color(.48,.72,.66,.8-row*.1))
		if splash_age<.65:
			for i: int in 9:
				var v:=Vector2((i-4)*26,-100-absf(i-4)*8)
				var at:=splash_point+v*splash_age+Vector2(0,180*splash_age*splash_age)
				draw_rect(Rect2(at.round(),Vector2(3,3)),Color(.68,.88,.86,1-splash_age/.65))
	elif mode=="thorns":
		WorldProps.draw_thorns(self,bounds)
	elif mode=="gas":
		draw_rect(bounds,Color(.38,.58,.24,.35))
		for x: int in range(int(bounds.position.x),int(bounds.end.x),12):
			draw_line(Vector2(x,bounds.position.y),Vector2(x+6,bounds.end.y),Color(.55,.7,.3,.3),2)
	elif mode=="phase_light":
		draw_rect(bounds,Color(.95,.78,.35,.35))
		for y: int in range(int(bounds.position.y),int(bounds.end.y),8): draw_line(Vector2(bounds.position.x,y),Vector2(bounds.end.x,y),Color("f3d98c"),1)
