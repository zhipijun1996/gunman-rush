class_name WorldEnvironmentZone
extends Node2D
## Authored environmental challenge; queries equipped effects, never grants progress.
var bounds:=Rect2()
var mode:="gas"
var services: WorldServices
var controller: PlayerController
var policy: FrameDamagePolicy
var lifetime: DemoLifetime
var wind_pattern := "directional"
var wind_direction := Vector2.UP
var wind_acceleration := 900.0
var wind_speed_cap := 240.0
var vortex_direction := "clockwise"
var serial:=0
var clock:=0.0
var light_image: Image
var light_texture: ImageTexture
var had_lights := false
var _dark: ShaderMaterial
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
	if mode == "wind": process_physics_priority = -150
	if mode!="dark": return
	var shade:=ColorRect.new();shade.position=bounds.position;shade.size=bounds.size
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_dark=ShaderMaterial.new();_dark.shader=preload("res://game/world/components/world_darkness.gdshader")
	shade.material=_dark;add_child(shade)
	process_physics_priority = 1200
	light_image = Image.create_empty(clampi(ceili(bounds.size.x/12),1,128),clampi(ceili(bounds.size.y/12),1,96),false,Image.FORMAT_R8)
	light_texture = ImageTexture.create_from_image(light_image)
	_dark.set_shader_parameter("illumination",light_texture)
func wind_at(at: Vector2) -> Vector2:
	if not bounds.has_point(at): return Vector2.ZERO
	if wind_pattern == "directional": return wind_direction.normalized()*wind_acceleration
	var radial := at-bounds.get_center()
	if radial.length() > bounds.size.x*.5 or radial.is_zero_approx(): return Vector2.ZERO
	var tangent := Vector2(-radial.y,radial.x).normalized()
	return tangent*wind_acceleration*(1.0 if vortex_direction == "clockwise" else -1.0)

func _physics_process(delta: float) -> void:
	if mode == "wind":
		if controller.active and controller.traversal.state in [&"free",&"wall_kick",&"hook_kick",&"object_pull"]:
			var force := wind_at(to_local(controller.motor.global_position))
			if not force.is_zero_approx():
				controller.motor.wind_acceleration += force
				controller.motor.wind_cap = maxf(controller.motor.wind_cap,wind_speed_cap)
		return
	if mode=="dark":
		had_lights = preload("res://game/world/elements/perception/dark_zone_light.gd").update(self,bounds,light_image,light_texture,had_lights)
		return
	if mode not in ["gas","phase_light","thorns","water"] or not bounds.intersects(Rect2(controller.motor.position-Vector2(12,18),Vector2(24,36))): return
	if mode=="gas" and services.active("EQ_FILTER"): return
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
	if mode == "wind":
		var tint := Color(.63,.84,.78,.65)
		if wind_pattern == "vortex": draw_arc(bounds.get_center(),bounds.size.x*.5,0,TAU,48,tint,1)
		for y: int in range(12,int(bounds.size.y),32):
			for x: int in range(12,int(bounds.size.x),32):
				var start := bounds.position+Vector2(x,y)
				var dir := wind_at(start).normalized()
				if dir.is_zero_approx(): continue
				var tip := start+dir*10
				draw_line(start,tip,tint,1)
				draw_line(tip,tip-dir.rotated(.6)*4,tint,1)
		return
	if mode=="water":
		draw_rect(bounds,Color("244c54"))
		for row: int in 5:
			for x: int in range(int(bounds.position.x)+8,int(bounds.end.x)-24,32):
				var y:=clampf(bounds.position.y+row*9+roundf(sin(water_time*2+x*.04+row)*2),bounds.position.y,bounds.end.y)
				if y+2 > bounds.end.y: continue
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
