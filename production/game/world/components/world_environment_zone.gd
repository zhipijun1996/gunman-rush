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
var field_time:=0.0
var splash_age:=9.0
var splash_point:=Vector2.ZERO
func _process(delta: float) -> void:
	if mode in ["water","wind","gas","phase_light"]:
		field_time += delta
		splash_age += delta
		queue_redraw()
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
	if services == null or not bounds.has_area(): return
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	match mode:
		"wind": draw_wind()
		"water": draw_water()
		"thorns":
			WorldProps.draw_thorns(self,bounds)
			MechanismRegionArt.stamp(self,"hazard",bounds.position+Vector2(7,bounds.size.y-5),Vector2(15,13))
		"gas": draw_gas()
		"phase_light": draw_phase()
		"dark":
			for corner: Vector2 in [bounds.position,bounds.position+Vector2(bounds.size.x,0)]:
				MechanismRegionArt.stamp(self,"mount",corner+Vector2.DOWN*4,Vector2(23,16),Color("9b959b"))

func draw_wind() -> void:
	var center := bounds.get_center()
	if wind_pattern == "vortex":
		var radius := bounds.size.x*.5
		var turn := 1 if vortex_direction=="clockwise" else -1
		var bands := maxi(1,ceili(radius/46))
		for ring: int in bands:
			var r := radius*(ring+.78)/bands
			var count := maxi(4,ceili(TAU*r/65))
			for i: int in count:
				var angle := TAU*(i+.38*ring)/count+field_time*turn*49/maxf(r,1)
				var at := center+Vector2.from_angle(angle)*r
				var span := minf(31,r*.56)
				draw_set_transform(at.round(),angle+turn*PI*.5)
				TraversalMechanismArt.sprite(self,TraversalMechanismArt.WIND,Vector2.ZERO,Vector2(span,span*.26),Color(1,1,1,.64))
		draw_set_transform(Vector2.ZERO,0)
		for i: int in 4:
			var tip := center+Vector2.from_angle(PI*.25+i*PI*.5)*(radius-4)
			MechanismRegionArt.stamp(self,"finial",tip,Vector2(12,11))
	else:
		var axis := wind_direction.normalized()
		var travel := field_time*46
		for y: int in range(0,ceili(bounds.size.y),34):
			for x: int in range(0,ceili(bounds.size.x),52):
				var start := Vector2(x+13+sin(y*.25)*13,y+10+sin(x*.2)*8)
				var at := bounds.position+Vector2(fposmod(start.x+axis.x*travel,bounds.size.x),fposmod(start.y+axis.y*travel,bounds.size.y))
				var span := minf(33,minf(bounds.size.x,bounds.size.y)*.45)
				var fade := clampf(minf(minf(at.x-bounds.position.x,bounds.end.x-at.x),minf(at.y-bounds.position.y,bounds.end.y-at.y))/maxf(span*.5,1),0,1)
				draw_set_transform(at.round(),axis.angle())
				TraversalMechanismArt.sprite(self,TraversalMechanismArt.WIND,Vector2.ZERO,Vector2(span,span*.26),Color(1,1,1,.7*fade))
		draw_set_transform(Vector2.ZERO,0)
		var source := center-axis*minf(bounds.size.x/maxf(absf(axis.x),.001),bounds.size.y/maxf(absf(axis.y),.001))*.5
		MechanismRegionArt.stamp(self,"mount",source,Vector2(26,22))
		MechanismRegionArt.stamp(self,"finial",source+axis*5,Vector2(18,18))

func draw_water() -> void:
	var local_light := MechanismRegionArt.accent(self)
	draw_rect(bounds,Color("253e4b"))
	var top := bounds.position.y
	for y: int in range(0,ceili(bounds.size.y),10):
		var depth := float(y)/maxf(bounds.size.y,1)
		var band := Rect2(bounds.position+Vector2(0,y),Vector2(bounds.size.x,minf(10,bounds.size.y-y)))
		draw_rect(band,Color("3b6c70").lerp(local_light,.17).lerp(Color("262f42"),depth))
	for row: int in range(0,ceili(bounds.size.y),19):
		for x: int in range(0,ceili(bounds.size.x),48):
			var length := minf(bounds.size.x-x,48)
			var pos := Vector2(bounds.position.x+x,top+row)
			var h := minf(bounds.size.y-row,12 if row==0 else 4)
			var alpha := .84 if row==0 else .18+.08*sin(field_time*2+x*.02+row)
			var src := Rect2(0,0,length,16)
			draw_texture_rect_region(TraversalMechanismArt.FOAM,Rect2(pos,Vector2(length,h)),src,Color(Color.WHITE.lerp(local_light,.28),alpha))
			if row==0:
				var glint := pos+Vector2(fposmod(field_time*9+x*.24,maxf(1,length-4)),minf(h-1,2+sin(field_time*2+x*.22)))
				draw_rect(Rect2(glint.round(),Vector2(minf(4,length),1)),Color("aae0cd").lerp(local_light,.24))
	MechanismRegionArt.stamp(self,"mount",Vector2(bounds.position.x+6,top+6),Vector2(18,16),Color("abbfc0"))
	if splash_age<.65:
		for i: int in 9:
			var v:=Vector2((i-4)*26,-100-absf(i-4)*8)
			var at:=splash_point+v*splash_age+Vector2(0,180*splash_age*splash_age)
			draw_rect(Rect2(at.round(),Vector2(3,3)),Color(.68,.88,.86,1-splash_age/.65))

func draw_gas() -> void:
	draw_rect(bounds,Color(.23,.30,.22,.16))
	for row: int in range(0,ceili(bounds.size.y),21):
		for col: int in range(0,ceili(bounds.size.x),48):
			var width := minf(48,bounds.size.x-col)
			var h := minf(19,bounds.size.y-row)
			var sway := sin(field_time*.92+col*.29+row*.14)
			var at := bounds.position+Vector2(col,row)+Vector2(width*.5,h*.5)
			var tint := Color(1,1,1,.58+.22*sway)
			TraversalMechanismArt.sprite(self,TraversalMechanismArt.GAS,at+Vector2(sway*2,0),Vector2(width,h),tint)
	MechanismRegionArt.stamp(self,"mount",bounds.position+Vector2(9,bounds.size.y-7),Vector2(23,19))
	MechanismRegionArt.stamp(self,"hazard",bounds.position+Vector2(9,bounds.size.y-9),Vector2(16,16))

func draw_phase() -> void:
	draw_rect(bounds,Color(.85,.57,.23,.10))
	for y: int in range(4,ceili(bounds.size.y),14):
		for x: int in range(0,ceili(bounds.size.x),60):
			var width := minf(60,bounds.size.x-x)
			var h := minf(9,bounds.size.y-y)
			var tint := Color(1,1,1,.70+.22*sin(field_time*3+y*.4))
			var at := bounds.position+Vector2(x,y)
			draw_texture_rect_region(TraversalMechanismArt.PHASE,Rect2(at,Vector2(width,h)),Rect2(0,0,width,12),tint)
	for edge: float in [bounds.position.x,bounds.end.x]:
		MechanismRegionArt.stamp(self,"finial",Vector2(edge,bounds.get_center().y),Vector2(14,20),Color("ffe2a7"))
