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
var _camera:WorldCamera
var _camera_token:=-1

func configure(owner_encounter: WindkeeperEncounter, visual: Node2D, wheels: bool) -> void:
	encounter=owner_encounter
	subject=visual
	rolling=wheels
	z_index=1

func _process(delta: float) -> void:
	if not is_instance_valid(encounter) or not is_instance_valid(subject):return
	var observed := encounter.presentation_intro()
	var intro: bool = observed.active
	if intro and not _was_intro:
		duration = observed.duration
		_impact_played=(1-float(observed.raw_clock)/duration)>=.64
		if not _impact_played:
			GameAudio.cue(self,&"boss_arrival_air")
			_camera=get_viewport().get_camera_2d() as WorldCamera
			if _camera!=null and _camera.room!=null and _camera.room.encounter==encounter:
				# The fixed zoom cannot contain both distant arena ends. Show the
				# arriving guardian within player visibility through the sole owner.
				_camera_token=_camera.begin_takeover(self,encounter.motor.global_position+Vector2(0,-80),_camera.room.arena_bounds.grow_individual(0,float(_camera.settings.arena_vertical_padding),0,float(_camera.settings.arena_vertical_padding)),.32)
	if intro:
		progress=clampf(1-float(observed.raw_clock)/duration,0,1)
		subject.position=pose_offset(progress,rolling,int(observed.direction))
		if progress>=.64 and not _impact_played:
			_impact_played=true
			GameAudio.cue(self,&"boss_arrival_land")
	else:
		_release_camera()
		subject.position=subject.position.move_toward(Vector2.ZERO,delta*600)
		progress=1
	_was_intro=intro
	visible=intro
	queue_redraw()

func _draw() -> void:
	if not visible:return
	var floor_point:=Vector2(0,62)
	if progress<.64:
		var fall:=clampf((progress-.22)/.42,0,1)
		for side:float in [-1,1]:
			for i:int in 3:
				var at:=floor_point+Vector2(side*(27+i*12)*(1-fall*.4),-30-55*(1-fall))
				PixelVfx.streak(self,at,Vector2(-side*.28,1),8+fall*18,1,Color(.74,.88,.8,sin(fall*PI)*.55))
	else:
		PixelVfx.clip(self,&"boss-land",floor_point,clampf((progress-.64)/.36,0,1))

func _release_camera() -> void:
	if _camera_token>=0 and is_instance_valid(_camera):_camera.end_takeover(_camera_token)
	_camera_token=-1

func _exit_tree() -> void:
	_release_camera()
	GameAudio.stop_origin(self,false)

static func pose_offset(t:float,wheels:bool,direction:int)->Vector2:
	# Starts/ends exactly at the dormant pose. A skip settles within .1s.
	var arrive:=clampf(t/.64,0,1)
	var settle:=sin(clampf((t-.64)/.36,0,1)*TAU)*exp(-maxf(0,t-.64)*14)
	return Vector2(sin(arrive*PI)*18*direction,settle*4) if wheels else Vector2(0,-sin(arrive*PI)*60+settle*6)
