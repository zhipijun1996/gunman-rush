class_name BossArrivalPresentation
extends Node2D
## Read-only choreography driven by the actual encounter's intro clock.
## No timers, gameplay RNG, physics movement, damage or unbounded particle nodes.
var encounter: WindkeeperEncounter
var subject: Node2D
var rolling := false
var duration := 0.0
var progress := 1.0
var _was_intro := false
var _impact_played := false

func configure(owner_encounter: WindkeeperEncounter, visual: Node2D, wheels: bool) -> void:
	encounter=owner_encounter
	subject=visual
	rolling=wheels
	z_index=1

func _process(delta: float) -> void:
	if not is_instance_valid(encounter) or not is_instance_valid(subject):return
	var intro:=encounter.active and encounter.mode==&"intro"
	if intro and not _was_intro:
		duration=maxf(encounter.intro_duration if encounter.intro_duration>0 else (encounter.definition as WindkeeperDefinition).intro_seconds,.01)
		_impact_played=(1-encounter.clock/duration)>=.64
	if intro:
		progress=clampf(1-encounter.clock/duration,0,1)
		subject.position=pose_offset(progress,rolling,encounter.direction)
		if progress>=.64 and not _impact_played:
			_impact_played=true
			GameAudio.cue(self,&"boss_impact")
	else:
		subject.position=subject.position.move_toward(Vector2.ZERO,delta*600)
		progress=1
	_was_intro=intro
	visible=intro
	queue_redraw()

func _draw() -> void:
	if not visible:return
	if PixelFormalActors.pixel_context(self):
		var burst := sin(clampf((progress-.58)/.35,0,1)*PI)
		for i: int in 16:
			var side := -1.0 if i%2==0 else 1.0
			var p := Vector2(side*(12+burst*(24+i*4)),62-burst*(8+i*2)).snapped(Vector2(2,2))
			draw_rect(Rect2(p,Vector2(6,2)),Color(PixelFormalActors.MOSS,burst*.7))
		return
	# Painted leaf/dust wake hugs the floor and clears before control resumes.
	var pulse:=clampf((progress-.58)/.35,0,1)
	var opacity:=sin(pulse*PI)*.62
	if opacity>0:
		var source:Rect2=PlainsCohesionArt.MINI_BURST if rolling else PlainsCohesionArt.WIND_BURST
		var width:=lerpf(65,240,pulse)
		draw_texture_rect_region(PlainsCohesionArt.ATLAS,Rect2(-width/2,28,width,52),source,Color(1,1,1,opacity))
	# Fixed sixteen painted motes: deterministic seed-free choreography, no allocations.
	for i:int in 16:
		var t:=clampf((progress-.61-float(i%4)*.014)/.34,0,1)
		if t<=0 or t>=1:continue
		var side:float=-1 if i%2==0 else 1
		var point:=Vector2(side*(12+t*(40+i*4)),62-sin(t*PI)*(12+i*2))
		draw_set_transform(point,t*side*2)
		draw_texture_rect_region(PlainsCohesionArt.ATLAS,Rect2(-4,-3,8,6),Rect2(1215,170,36,30),Color(1,1,1,1-t))
	draw_set_transform(Vector2.ZERO)


static func pose_offset(t:float,wheels:bool,direction:int)->Vector2:
	# Starts/ends exactly at the dormant pose. A skip settles within .1s.
	var arrive:=clampf(t/.64,0,1)
	var settle:=sin(clampf((t-.64)/.36,0,1)*TAU)*exp(-maxf(0,t-.64)*14)
	return Vector2(sin(arrive*PI)*18*direction,settle*4) if wheels else Vector2(0,-sin(arrive*PI)*60+settle*6)
