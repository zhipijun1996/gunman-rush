class_name WindkeeperPressurePresentation
extends Node2D
## Articulated old-brass guardian. Drawing never owns combat or actor motion.
## The retained source torso/head are cut from the actual existing species page;
## every new limb and the active blade use the encounter's physical pose.
@export var encounter: WindkeeperEncounter
const BRASS := Color("8e783e")
const LIT_BRASS := Color("c1a361")
const DARK_BRASS := Color("554a30")
const OUTLINE := Color("222b23")
const MOSS := Color("687345")
const CLOTH := Color("a59b73")
const CLOTH_DARK := Color("666d52")
const CORE := Color("e4be68")
const SOURCE := preload("res://assets/underworld_plains/actors/windkeeper.png")
var hit_template: EnemyHitTemplate
var _hurt_remaining := 0.0
var _armour_remaining := 0.0
var _armour_point := Vector2.ZERO


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if encounter == null:
		encounter = get_parent().get_node_or_null("Encounter") as WindkeeperEncounter
	if encounter == null:
		return
	hit_template = EnemyHitTemplate.install_boss(encounter,self)
	encounter.health.changed.connect(_health_changed)
	encounter.armour_hit.connect(_armour_hit)


func _health_changed(result: ActorResourceResult) -> void:
	if result.operation == &"damage" and result.status == ActorResourceResult.Status.APPLIED:
		_hurt_remaining = .12 if not encounter.health.terminal else 0.0


func _armour_hit(point: Vector2) -> void:
	_armour_point = encounter.motor.to_local(point)
	_armour_remaining = .10


func _process(delta: float) -> void:
	if not is_instance_valid(encounter) or get_tree().paused:
		return
	_hurt_remaining = maxf(0,_hurt_remaining-delta)
	_armour_remaining = maxf(0,_armour_remaining-delta)
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(encounter) or not encounter.has_method("rig_pose"):
		return
	var pose: Dictionary = encounter.call("rig_pose")
	if pose.is_empty(): return
	var tint := hit_template.tint() if is_instance_valid(hit_template) else Color.WHITE
	var dead: bool = pose.dead
	if dead: tint = tint.lerp(Color("858778"),clampf(float(pose.death_age)/1.8,0,1))
	_draw_sails(pose,tint)
	for index: int in [3,1]: _draw_leg(pose,index,tint.darkened(.18))
	_draw_body(pose,tint)
	_draw_folded_leaves(pose,tint)
	for index: int in [2,0]: _draw_leg(pose,index,tint)
	_draw_head(pose,tint)
	_draw_core(pose,tint)
	_draw_bells(pose,tint)
	if pose.mode in [&"sweep_warning", &"sweep"] and not dead:
		_draw_attack_leaf(pose,tint)
	_draw_impacts(pose)
	if pose.mode == &"gust" and not dead:
		_draw_wind(pose)
	if _armour_remaining > 0:
		for index: int in 4:
			var axis := Vector2.from_angle(float(index)*PI*.5+.4)
			var p := (_armour_point+axis*(7+(1-_armour_remaining/.1)*8)).round()
			draw_rect(Rect2(p,Vector2(2,2)),Color("ded8ad"))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_sails(pose: Dictionary, tint: Color) -> void:
	var body: Transform2D = pose.body_transform
	var opening: float = pose.sail_open
	var tension: float = pose.sail_tension
	var swing: float = pose.bell_swing
	var base := Vector2(-24,-29)
	var mast := body*Vector2(-25,-77)
	_segment(body*base,mast,6,OUTLINE*tint)
	_segment(body*base,mast,3,BRASS*tint)
	var sag := 13*(1-tension)+sin(float(pose.fight_age)*3.4-.8)*2*(1-tension)
	if pose.dead: sag += smoothstep(.3,1.6,float(pose.death_age))*36
	for side: int in [-1,1]:
		var tip := Vector2(-25+side*(20+opening*49),-72+sag*.45)
		var lower := Vector2(-25+side*(10+opening*38),-22+sag)
		var seam := Vector2(-25+side*(13+opening*29),-37+sag*.8)
		# Walk the cloth's outer boundary in order. The old seam point is an
		# interior fold, not a boundary vertex; inserting it in this contour made
		# the lower hem cross itself after the independent cloth sag was applied.
		var points := [Vector2(-25,-75),tip,lower,base]
		_poly(points,body,CLOTH*tint if side>0 else CLOTH_DARK*tint)
		_poly([base,lower,seam],body,CLOTH_DARK*tint)
		_cloth_detail(body,Vector2(-25,-75),tip,lower,base,side,tint)
		_segment(mast,body*tip,2,LIT_BRASS*tint)
		_segment(body*seam,body*tip,1,Color("d0bf8c")*tint)
		var patch := body*(tip.lerp(lower,.38)+Vector2(-side*5,0))
		draw_rect(Rect2(patch.round(),Vector2(3,5)),Color("7a7858")*tint)
		# The cloth follows the same wind-facing rig rather than a screen effect.
		var tie := body*(lower+Vector2(side*3,sin(swing)*4))
		_segment(body*lower,tie,1,DARK_BRASS*tint)


func _draw_body(pose: Dictionary, tint: Color) -> void:
	var body: Transform2D = pose.body_transform
	_poly(WindkeeperPressureRig.BODY_OUTLINE,body,OUTLINE*tint)
	var inset := [Vector2(-66,-21),Vector2(-50,-33),Vector2(41,-32),Vector2(65,-18),Vector2(66,16),Vector2(47,30),Vector2(-47,29),Vector2(-67,12)]
	_poly(inset,body,BRASS*tint)
	_poly([Vector2(-62,8),Vector2(-44,24),Vector2(45,25),Vector2(61,12),Vector2(58,27),Vector2(46,32),Vector2(-49,30)],body,DARK_BRASS*tint)
	draw_set_transform_matrix(body)
	# Keep existing moss, patina and plated identity; no full-picture wobble or
	# old source legs are retained inside this measured torso-only crop.
	draw_texture_rect_region(SOURCE,Rect2(-57,-30,114,64),Rect2(37,36,64,38),tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_segment(body*Vector2(-47,-29),body*Vector2(40,-28),2,LIT_BRASS*tint)
	for index: int in 5:
		var x := -43+float(index)*19
		var rivet := (body*Vector2(x,24)).round()
		draw_rect(Rect2(rivet-Vector2(2,2),Vector2(4,4)),DARK_BRASS*tint)
		draw_rect(Rect2(rivet-Vector2(1,1),Vector2(2,2)),LIT_BRASS*tint)
	for index: int in 8:
		var at := body*Vector2(-52+float(index)*13,-29-absf(sin(float(index)*2.7))*5)
		_poly([Vector2(-4,0),Vector2(-2,-5),Vector2(1,-2),Vector2(4,-6),Vector2(5,2)],Transform2D(0,at),MOSS*tint)


func _draw_head(pose: Dictionary, tint: Color) -> void:
	var head: Transform2D = pose.head_transform
	_poly(WindkeeperPressureRig.HEAD_OUTLINE,head,OUTLINE*tint)
	_poly([Vector2(-23,-15),Vector2(-10,-24),Vector2(15,-20),Vector2(26,-6),Vector2(23,16),Vector2(5,22),Vector2(-20,14)],head,BRASS*tint)
	var mirror := Transform2D(Vector2(-1,0),Vector2(0,1),Vector2.ZERO)
	draw_set_transform_matrix(head*mirror)
	draw_texture_rect_region(SOURCE,Rect2(-25,-22,53,47),Rect2(6,53,38,34),tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_segment(head*Vector2(-15,-18),head*Vector2(-24,-35),7,DARK_BRASS*tint)
	_segment(head*Vector2(-24,-35),head*Vector2(-8,-44),5,LIT_BRASS*tint)
	_segment(head*Vector2(-8,-44),head*Vector2(0,-36),3,LIT_BRASS*tint)
	var eye := head*Vector2(14,-7)
	draw_rect(Rect2(eye.round()-Vector2(4,4),Vector2(8,8)),OUTLINE*tint)
	var energy: float = pose.core_energy
	draw_rect(Rect2(eye.round()-Vector2(2,2),Vector2(4,4)),Color("f2cf83").lerp(Color("514d36"),1-energy)*tint)
	_segment(head*Vector2(13,14),head*Vector2(26,9),2,DARK_BRASS*tint)
	for mark: Vector2 in [Vector2(-18,8),Vector2(-12,-18),Vector2(19,13)]:
		_segment(head*mark,head*(mark+Vector2(2,1)),1,Color("65704b")*tint)


func _brass_detail(start: Vector2, finish: Vector2, salt: int, tint: Color) -> void:
	var axis := (finish-start).normalized()
	var normal := axis.orthogonal()
	# Fixed grouped wear follows this plate, never TIME or gameplay RNG.
	for index: int in 4:
		var along: float = [.18,.34,.58,.79][index]
		var at := start.lerp(finish,along)+normal*float((index*3+salt)%5-2)*.45
		_segment(at-axis*.5,at+axis*1.5,1,Color("566044")*tint)
		if index%2==0:
			_segment(at+normal,at+normal+axis,1,Color("b8a064")*tint)
	var seam := start.lerp(finish,.44)
	_segment(seam-normal*2,seam+normal*2,1,Color("4a5038")*tint)


func _socket_detail(at: Vector2, tint: Color) -> void:
	_segment(at+Vector2(-4,1),at+Vector2(3,3),2,Color("394332")*tint)
	_segment(at+Vector2(-3,-3),at+Vector2(1,-4),1,LIT_BRASS*tint)
	draw_rect(Rect2(at.round()-Vector2(1,1),Vector2.ONE),Color("b39d62")*tint)


func _cloth_detail(body: Transform2D, top: Vector2, tip: Vector2, lower: Vector2, base: Vector2, side: int, tint: Color) -> void:
	# Tension folds and repair cloth stay inside the existing ordered sail.
	_poly([top.lerp(tip,.32),top.lerp(tip,.44),base.lerp(lower,.54),base.lerp(lower,.42)],body,Color("858363")*tint)
	for row: float in [.26,.71]:
		var a := top.lerp(base,row)
		var b := tip.lerp(lower,row)
		var axis := (b-a).normalized()
		for fraction: float in [.27,.55,.80]:
			var at := a.lerp(b,fraction)
			_segment(body*at,body*(at+axis*2),1,Color("92916c")*tint)
	if side>0:
		var a := top.lerp(base,.43).lerp(tip.lerp(lower,.43),.57)
		var b := top.lerp(base,.43).lerp(tip.lerp(lower,.43),.75)
		var c := top.lerp(base,.65).lerp(tip.lerp(lower,.65),.75)
		var d := top.lerp(base,.65).lerp(tip.lerp(lower,.65),.57)
		_poly([a,b,c,d],body,Color("8a8966")*tint)
		_segment(body*a,body*b,1,CLOTH_DARK*tint)
		_segment(body*c,body*d,1,Color("b5aa7c")*tint)
	for fraction: float in [.20,.78]:
		var hem := tip.lerp(lower,fraction)
		_segment(body*hem,body*(hem+Vector2(-side*2,1)),1,Color("b7aa7d")*tint)


func _draw_leg(pose: Dictionary, index: int, tint: Color) -> void:
	var hip: Vector2 = pose.hips[index]
	var knee: Vector2 = pose.knees[index]
	var foot: Vector2 = pose.feet[index]
	_segment(hip,knee,15,OUTLINE*tint)
	_segment(hip,knee,10,DARK_BRASS*tint)
	_segment(hip+Vector2(1,0),knee+Vector2(1,0),6,BRASS*tint)
	_segment(hip+Vector2(-1,-1),knee+Vector2(-1,-1),2,LIT_BRASS*tint)
	_brass_detail(hip,knee,index*7,tint)
	_segment(knee,foot,13,OUTLINE*tint)
	_segment(knee,foot,8,BRASS*tint)
	_segment(knee+Vector2(1,0),foot+Vector2(1,0),1,LIT_BRASS*tint)
	_brass_detail(knee,foot,index*7+3,tint)
	_disc(hip,9,OUTLINE*tint)
	_disc(hip,6,DARK_BRASS*tint)
	_disc(knee,8,OUTLINE*tint)
	_disc(knee,5,BRASS*tint)
	_socket_detail(hip,tint)
	_socket_detail(knee,tint)
	draw_rect(Rect2(knee.round()-Vector2(1,2),Vector2(2,4)),LIT_BRASS*tint)
	# The drawn hoof has the same12wu radius used by actual contact admission.
	_poly([Vector2(-12,-6),Vector2(-8,-12),Vector2(8,-11),Vector2(12,-4),Vector2(12,3),Vector2(-11,3)],Transform2D(0,foot),OUTLINE*tint)
	_poly([Vector2(-9,-5),Vector2(-6,-9),Vector2(7,-8),Vector2(10,-3),Vector2(9,0),Vector2(-8,0)],Transform2D(0,foot),DARK_BRASS*tint)
	_segment(foot+Vector2(-8,-5),foot+Vector2(7,-5),2,LIT_BRASS*tint)


func _draw_core(pose: Dictionary, tint: Color) -> void:
	var core: Transform2D = pose.core_transform
	var at := core.origin
	var energy: float = pose.core_energy
	_disc(at,18,OUTLINE*tint)
	_disc(at,15,DARK_BRASS*tint)
	_disc(at,12,LIT_BRASS*tint)
	_disc(at,9,Color("685b35").lerp(CORE,energy)*tint)
	var angle := float(pose.fight_age)*2.4
	if pose.dead:
		angle += minf(float(pose.death_age),.45)*1.4
	for spoke: int in 4:
		var axis := Vector2.from_angle(angle+float(spoke)*PI*.5)
		_segment(at+axis*3,at+axis*9,2,DARK_BRASS*tint)
	if _hurt_remaining>0 and not pose.dead:
		_poly([Vector2(-9,-5),Vector2(4,-1),Vector2(10,2),Vector2(-3,7)],Transform2D(0,at),Color("fff2ca"))


func _draw_bells(pose: Dictionary, tint: Color) -> void:
	var body: Transform2D = pose.body_transform
	var swing: float = pose.bell_swing
	for index: int in 3:
		var mount := Vector2(-47+float(index)*34,-41-float(index%2)*19)
		var length := 16.0+float(index%2)*9
		var death_silence := smoothstep(.5+float(index)*.25,.8+float(index)*.25,float(pose.death_age)) if pose.dead else 0.0
		var angle := swing*(1+float(index)*.23)*(1-death_silence)
		var bell := body*Transform2D(angle,mount)*Transform2D(0,Vector2(0,length))
		_segment(body*mount,bell.origin,2,DARK_BRASS*tint)
		_poly([Vector2(-5,-6),Vector2(4,-6),Vector2(7,5),Vector2(-7,5)],bell,BRASS*tint)
		_segment(bell*Vector2(-7,5),bell*Vector2(7,5),2,LIT_BRASS*tint)
		draw_rect(Rect2((bell*Vector2(-1,7)).round(),Vector2(2,3)),DARK_BRASS*tint)


func _draw_folded_leaves(pose: Dictionary, tint: Color) -> void:
	var body: Transform2D = pose.body_transform
	var opening: float = pose.sail_open
	for index: int in 3:
		var angle := -.75+float(index)*.68+float(pose.shoulder_twist)*.7
		var mount := body*Vector2(-3,-29)
		var axis := body.basis_xform(Vector2.from_angle(angle))
		var offset := Vector2.ZERO
		var falling := 0.0
		if pose.dead:
			falling = clampf((float(pose.death_age)-.6-float(index)*.16)/.7,0,1)
			offset = Vector2((float(index)-1)*22,47)*falling
			axis = axis.rotated(falling*(.9+float(index)*.3))
		var reach := 24+opening*(23+float(index%2)*9)
		_leaf(mount+axis*12+offset,mount+axis*reach+offset,8,DARK_BRASS*tint,LIT_BRASS*tint)


func _draw_attack_leaf(pose: Dictionary, tint: Color) -> void:
	var start: Vector2 = pose.blade_start
	var finish: Vector2 = pose.blade_end
	var active: bool = pose.mode == &"sweep"
	if not active:
		# Preparing shows a real leaf raised/lowered at the upcoming sweep
		# height, not a helper line over the future damaging route.
		finish = start.lerp(finish,.56+.18*float(pose.progress))
	var edge := Color("e2ce8b") if active else LIT_BRASS
	_leaf(start,finish,float(pose.blade_width),BRASS*tint,edge*tint)
	_disc(pose.blade_hub,9,OUTLINE*tint)
	_disc(pose.blade_hub,5,BRASS*tint)


func _draw_impacts(pose: Dictionary) -> void:
	if pose.mode not in [&"stomp", &"platform"] or pose.dead: return
	var progress: float = pose.progress
	var burst := clampf((progress-.55)/.40,0,1)
	if burst<=0 or burst>=1: return
	var index: int = 0 if pose.mode == &"platform" else int(pose.foot_index)
	var origin: Vector2 = pose.feet[index]
	for chip: int in 8:
		var side := -1.0 if chip%2==0 else 1.0
		var at := origin+Vector2(side*(6+burst*(17+float(chip)*3)),-sin(burst*PI)*(5+float(chip%3)*5))
		draw_rect(Rect2(at.round(),Vector2(3,2)),Color(Color("9e9972"),.7*(1-burst)))


func _draw_wind(pose: Dictionary) -> void:
	var origin: Vector2 = pose.seed_origin
	var direction: Vector2 = pose.gust_direction
	var clock: float = pose.fight_age
	for index: int in 10:
		var travel := fposmod(clock*220+float(index)*39,275)
		var at := origin+direction*travel+Vector2(0,float(index%5-2)*23)
		var alpha := sin(travel/275*PI)*.34
		# Current force is sparse physical wind, never a windup aim/path guide.
		_segment(at,at+direction*10,1,Color(Color("c7d0b0"),alpha))
		if index%3==0:
			_poly([Vector2(-3,0),Vector2(0,-2),Vector2(4,0),Vector2(0,2)],Transform2D(clock*3,at),Color(MOSS,alpha))


func _leaf(start: Vector2, finish: Vector2, width: float, fill: Color, edge: Color) -> void:
	var axis := (finish-start).normalized()
	var normal := axis.orthogonal()
	var middle := start.lerp(finish,.52)
	var half := width*.5
	_poly([start-axis*half,start-normal*half,middle-normal*half,finish+axis*half,middle+normal*half,start+normal*half],Transform2D.IDENTITY,OUTLINE)
	_poly([start-axis*(half-2),start-normal*(half-2),middle-normal*(half-2),finish+axis*(half-2),middle+normal*(half-2),start+normal*(half-2)],Transform2D.IDENTITY,fill)
	_segment(start,finish,2,edge)


func _poly(points: Array, transform: Transform2D, color: Color) -> void:
	var transformed := PackedVector2Array()
	for point: Vector2 in points:
		var rounded := (transform*point).round()
		if transformed.is_empty() or rounded != transformed[-1]:
			transformed.append(rounded)
	if transformed.size()>1 and transformed[0]==transformed[-1]:
		transformed.remove_at(transformed.size()-1)
	if transformed.size()<3: return
	var twice_area := 0.0
	for index: int in transformed.size():
		twice_area += transformed[index].cross(transformed[(index+1)%transformed.size()])
	# Integer snapping can legitimately collapse tiny cloth creases or chips to
	# a point/line. They have no filled area; the actual ordered cloth survives.
	if absf(twice_area)<1.0: return
	draw_colored_polygon(transformed,color)


func _segment(start: Vector2, finish: Vector2, width: float, color: Color) -> void:
	if not start.is_finite() or not finish.is_finite() or not is_finite(width) or width<=0:
		return
	if start.distance_squared_to(finish)<.01:
		draw_rect(Rect2(start.round()-Vector2.ONE*maxf(1,width)*.5,Vector2.ONE*maxf(1,width)),color)
		return
	if width<=1.0:
		# Keep a genuine one-pixel diagonal instead of forming a zero-area quad
		# when both rounded sides of a thin segment fall on the same pixel row.
		draw_line(start.round(),finish.round(),color,1.0,false)
		return
	var normal := (finish-start).normalized().orthogonal()*width*.5
	_poly([start-normal,finish-normal,finish+normal,start+normal],Transform2D.IDENTITY,color)


func _disc(at: Vector2, radius: float, color: Color) -> void:
	var points: Array[Vector2] = []
	for index: int in 12:
		points.append(at+Vector2.from_angle(float(index)*TAU/12)*radius)
	_poly(points,Transform2D.IDENTITY,color)


func synchronize_presentation() -> void:
	_hurt_remaining = 0
	_armour_remaining = 0
	queue_redraw()


func _exit_tree() -> void:
	if is_instance_valid(hit_template): hit_template.dispose()
