class_name PlayerWeaponVfxV2
extends Node2D
## Read-only presentation of accepted weapon state and original world-space FX.
## No raycasts, gameplay RNG, damage, timers, actor movement or per-frame nodes.

class HorizonLayer extends Node2D:
	var presenter: Node2D
	func _draw() -> void:
		if is_instance_valid(presenter): presenter.draw_horizon_on(self)

var runtime: WeaponActionRuntime
var controller: PlayerController
var catch_visual: UnderworldPlayer
@export_range(0.0,1.0) var opacity := .85
var _blade: AtlasTexture
var _horizon: HorizonLayer

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/actor_actions/weapon_catalog.json"))
	if catalog.has("texture") and catalog.has("regions") and catalog.regions.size()>2:
		var region: Array=catalog.regions[2]
		_blade=AtlasTexture.new()
		_blade.atlas=load(String(catalog.texture)) as Texture2D
		_blade.region=Rect2(float(region[0]),float(region[1]),float(region[2]),float(region[3]))
	_horizon=HorizonLayer.new()
	_horizon.name="EventHorizonBehindHero"
	_horizon.presenter=self
	_horizon.z_as_relative=false
	_horizon.z_index=controller.motor.z_index-1
	add_child(_horizon)

func _process(_delta: float) -> void:
	if not visible: return
	queue_redraw()
	if is_instance_valid(_horizon): _horizon.queue_redraw()

func _valid() -> bool:
	return is_instance_valid(runtime) and is_instance_valid(controller) and controller.active and is_finite(opacity) and opacity>0 and opacity<=1

func _draw() -> void:
	if not _valid(): return
	var beam := runtime.beam_visual_segment()
	if beam.size()==2:
		_draw_ion_beam(to_local(beam[0]),to_local(beam[1]),runtime.age,1.0,false)
	for fx: Dictionary in runtime._fx:
		match StringName(fx.kind):
			&"return_blade": _draw_return(fx)
			&"beam":
				if bool(fx.skill): _draw_ion_beam(to_local(fx.start),to_local(fx.end),float(fx.age),maxf(0,1-float(fx.age)/.3),true)
			&"blast":
				if controller.shoot_ability.weapon.mode==WeaponDefinition.Mode.SINGULARITY: _draw_collapse(fx)
				else: _draw_explosion(fx)
	if runtime.phase==&"singularity": _draw_accretion()

func _draw_ion_beam(start: Vector2, finish: Vector2, age: float, fade: float, cannon: bool) -> void:
	var length := start.distance_to(finish)
	if length<.5 or fade<=0: return
	var axis := (finish-start)/length
	var normal := axis.orthogonal()
	var strength := opacity*fade
	var item_width := runtime.beam_item_width_scale() if is_instance_valid(runtime) else 1.0
	var width := (15.0 if cannon else 9.0) * item_width
	# A compact dark boundary and bright inner channel survive both bright sky
	# and dark terrain. The stream follows the accepted beam's exact endpoints.
	draw_line(start,finish,Color(.035,.075,.10,.8*strength),width+3*item_width,false)
	draw_line(start,finish,Color(.12,.72,.91,.26*strength),width,false)
	draw_line(start,finish,Color(.25,.87,.98,.75*strength),(4 if cannon else 3)*item_width,false)
	draw_line(start,finish,Color(.91,.99,1,strength),2*item_width,false)
	for i: int in 9:
		var travel := fposmod(age*3.6+float(i)/9,1.0)
		var point := start+axis*length*travel
		var side := sin(age*22+float(i)*2.4)*3
		var span := minf(9.0,minf(travel,1-travel)*length)
		if span<1: continue
		var diamond := PackedVector2Array([point-axis*span,point+normal*(side+2),point+axis*span,point+normal*(side-2)])
		draw_colored_polygon(diamond,Color(.64,.97,1,.55*strength))
		draw_rect(Rect2((point+normal*(side+4)).snapped(Vector2(2,2)),Vector2(2,2)),Color(.35,.84,.95,.7*strength))
	# Endpoint flares indicate an actual obstruction, never a range-only miss.
	var blocked := length<controller.shoot_ability.weapon.range_limit-.5 if cannon else runtime._beam_start.distance_to(runtime._beam_point)<controller.shoot_ability.weapon.range_limit-.5
	if blocked:
		var flicker := .8+.2*sin(age*31)
		draw_circle(finish,4*flicker,Color(.78,.98,1,.8*strength))
		for i: int in 6:
			var direction := (-axis).rotated((float(i)-2.5)*.44+sin(age*24+float(i))*.1)
			var distance := 5+fposmod(age*67+float(i)*4,12)
			draw_line(finish+direction*distance,finish+direction*(distance+3),Color(.51,.94,1,.75*strength),2,false)
	# Short barrel corona does not replace the real muzzle/weapon anchor.
	draw_line(start-normal*4,start+normal*4,Color(.68,.98,1,.55*strength),2,false)

func _draw_return(fx: Dictionary) -> void:
	if _blade==null: return
	var age := float(fx.age)
	var duration := .14
	if age<0 or age>=duration: return
	var start := to_local(fx.start)
	var finish := to_local(fx.end)
	# Physics has already accepted the original swept segment/catch. Its short
	# echo follows the currently drawn hand while the real recoil moves the hero.
	if is_instance_valid(catch_visual) and catch_visual.is_visible_in_tree():
		finish=to_local(catch_visual.to_global(Vector2(catch_visual.facing*4,-1)))
	else:
		var courier := controller.motor.get_node_or_null("CourierVisual") as CourierVisual
		if is_instance_valid(courier): finish=to_local(courier.grapple_hand_position())
	var axis := (finish-start).normalized()
	var width := 50.0 if bool(fx.skill) else 36.0
	var size := Vector2(width,width*_blade.region.size.y/_blade.region.size.x)
	# The physical recall is already swept/caught in the same accepted tick.
	# This short visual echo traverses that exact segment; it is not a beam.
	for i: int in range(2,-1,-1):
		var phase := clampf((age-float(i)*.012)/duration,0,1)
		var eased := 1-pow(1-phase,3)
		var point := start.lerp(finish,eased)
		var alpha := (1-float(i)*.27)*(1-clampf(age/duration,0,1)*.25)*opacity
		alpha*=minf(1,(1-age/duration)*4)
		if i==0:
			var tail := minf(32,start.distance_to(point))
			draw_line(point-axis*tail,point,Color(.79,.87,.88,.3*alpha),3,false)
		draw_set_transform(point,age*48+float(i)*.4)
		draw_texture_rect(_blade,Rect2(-size/2,size),false,Color(1,1,1,alpha))
		draw_set_transform(Vector2.ZERO)

func draw_horizon_on(canvas: Node2D) -> void:
	if not _valid() or runtime.phase!=&"singularity": return
	var center := to_local(runtime._center)
	var progress := clampf(runtime.age/controller.shoot_ability.weapon.hold_seconds,0,1)
	var radius := 29+4*sin(progress*PI)
	# This fixed background pass sits one canvas-Z behind the real hero. It
	# never covers the actor with an opaque foreground black circle.
	canvas.draw_circle(center,radius+5,Color(.20,.12,.29,.45*opacity))
	canvas.draw_circle(center,radius,Color(.015,.018,.03,.98*opacity))
	canvas.draw_arc(center,radius+1,0,TAU,32,Color(.69,.56,.80,.75*opacity),2,false)

func _draw_accretion() -> void:
	var center := to_local(runtime._center)
	var age := runtime.age
	var progress := clampf(age/controller.shoot_ability.weapon.hold_seconds,0,1)
	var pulse := 1+.06*sin(age*25)
	# Thin elliptical accretion bands and inward specks carry the vortex
	# motion; the broad attraction radius remains clear and unfilled.
	for band: int in 3:
		var points := PackedVector2Array()
		for i: int in 33:
			var angle := float(i)*TAU/32+age*(4.5+band)
			var point := Vector2(cos(angle)*(31+band*7),sin(angle)*(10+band*4)).rotated(-.20)
			points.append(center+point*pulse)
		draw_polyline(points,Color(.57+.08*band,.42+.10*band,.78,.5*opacity),2,false)
	for i: int in 18:
		var travel := fposmod(age*2.2+float(i)/18,1.0)
		var radius := lerpf(82.0,22.0,travel)
		var angle := float(i)*2.39996+age*3.5+travel*1.4
		var point := center+Vector2.from_angle(angle)*radius*Vector2(1,.76)
		var next := center+Vector2.from_angle(angle+.08)*(radius-5)*Vector2(1,.76)
		var color := Color(.84,.75,.57,(.25+.6*travel)*opacity)
		draw_line(point.snapped(Vector2(2,2)),next.snapped(Vector2(2,2)),color,2,false)
	for i: int in 4:
		var angle := age*5+float(i)*TAU/4
		draw_arc(center,48+i*4,angle,angle+.45,5,Color(.65,.58,.85,.40*opacity),2,false)
	# The existing launch direction remains readable outside the dark center.
	var marker := center+runtime.direction*60
	draw_line(marker-runtime.direction*5,marker+runtime.direction*5,Color(.96,.84,.54,.9*opacity),2,false)
	draw_arc(center,controller.shoot_ability.weapon.attract_radius,0,TAU*progress,48,Color(.56,.49,.72,.15*opacity),1,false)

func _draw_explosion(fx: Dictionary) -> void:
	var center := to_local(fx.start)
	var age := float(fx.age)
	var radius := float(fx.radius)
	var fade := maxf(0,1-age/.55)*opacity
	var burst := 1-pow(1-clampf(age/.18,0,1),3)
	# Flame stays inside the real blast radius; its compact initial core is
	# intentionally brief rather than an additional opaque radius-sized fill.
	for i: int in 8:
		var axis := Vector2.from_angle(float(i)*TAU/8+.12*sin(float(i)*5))
		var point := center+axis*radius*(.10+.22*burst)
		var size := radius*(.06+.04*sin(float(i)*4))*(1-age/.7)
		draw_circle(point,size,Color(.94,.24+.07*(i%3),.055,.65*fade))
		if age<.18:
			var flame := PackedVector2Array([point-axis*size,point+axis.orthogonal()*size*.65,point+axis*size*2.1,point-axis.orthogonal()*size*.65])
			draw_colored_polygon(flame,Color(1,.76,.22,.85*fade))
	if age<.09: draw_circle(center,radius*.105,Color(1,.94,.70,(1-age/.09)*opacity))
	for i: int in 16:
		var axis := Vector2.from_angle(float(i)*TAU/16+.13*sin(float(i)*7))
		var travel := radius*(.15+.75*clampf(age/.36,0,1))
		var point := center+axis*travel+Vector2.DOWN*age*age*70
		draw_line(point-axis*6*fade,point,Color(1,.65,.18,fade),2,false)
	var wave := radius*(1-pow(1-clampf(age/.28,0,1),3))
	for i: int in 8:
		draw_arc(center,wave,float(i)*TAU/8,float(i)*TAU/8+.58,5,Color(.98,.75,.43,maxf(0,1-age/.32)*opacity),2,false)
	if age>.08:
		for i: int in 6:
			var point := center+Vector2.from_angle(float(i)*TAU/6)*radius*(.1+age*.25)+Vector2.UP*age*30
			draw_circle(point,radius*(.035+age*.075),Color(.16,.17,.19,.42*fade))

func _draw_collapse(fx: Dictionary) -> void:
	var center := to_local(fx.start)
	var age := float(fx.age)
	var radius := float(fx.radius)
	var fade := maxf(0,1-age/.45)*opacity
	var progress := clampf(age/.28,0,1)
	# The collapse draws inward debris and a thin lens front rather than
	# reusing the orange explosive flame of the bomb family.
	for i: int in 18:
		var angle := float(i)*2.39996+progress*1.6
		var distance := lerpf(radius*.66,8.0,progress)
		var axis := Vector2.from_angle(angle)
		var point := center+axis*distance*Vector2(1,.75)
		draw_line(point-axis*7,point,Color(.77,.67,.91,.8*fade),2,false)
	for i: int in 3:
		var points := PackedVector2Array()
		for j: int in 33:
			var angle := float(j)*TAU/32
			points.append(center+Vector2(cos(angle),sin(angle)*.42).rotated(-.2)*(18+progress*radius*(.65+i*.08)))
		draw_polyline(points,Color(.77,.72,.94,(.65-.16*i)*fade),2,false)
	if age<.10:
		draw_arc(center,24*(1-progress),0,TAU,24,Color(.94,.88,1,(1-age/.10)*opacity),3,false)
