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
var roar_screen:BossRoarScreen

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	if not rolling:
		roar_screen=BossRoarScreen.new();add_child(roar_screen)

func configure(owner_encounter: WindkeeperEncounter, visual: Node2D, wheels: bool) -> void:
	encounter=owner_encounter
	subject=visual
	rolling=wheels
	z_index=1

func _process(delta: float) -> void:
	if not is_instance_valid(encounter) or not is_instance_valid(subject):
		if is_instance_valid(roar_screen):roar_screen.clear()
		_release_camera();GameAudio.stop_origin(self,false);visible=false;return
	var observed := encounter.presentation_intro()
	var intro: bool = observed.active and not encounter.health.terminal
	var audio:=GameAudio.for_origin(self) as GameAudio
	if audio!=null:audio.pause_origin(self,get_tree().paused)
	if get_tree().paused and intro:return
	if intro and not _was_intro:
		duration = observed.duration
		_impact_played=(1-float(observed.raw_clock)/duration)>=(.64 if rolling else BossRoarTimeline.RELEASE)
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
		if progress>=(.64 if rolling else BossRoarTimeline.RELEASE) and not _impact_played:
			_impact_played=true
			GameAudio.stop_origin(self,false)
			GameAudio.cue(self,&"boss_arrival_land" if rolling else &"boss_arrival_roar")
		if is_instance_valid(roar_screen):
			var size:=get_viewport().get_visible_rect().size
			var point:=get_global_transform_with_canvas()*_mouth()
			roar_screen.present(progress,point/size,PixelVfx.reduced(self))
	else:
		if _was_intro:GameAudio.stop_origin(self,false)
		if is_instance_valid(roar_screen):roar_screen.clear()
		_release_camera()
		subject.position=subject.position.move_toward(Vector2.ZERO,delta*600)
		progress=1
	_was_intro=intro
	visible=intro
	queue_redraw()

func _draw() -> void:
	if not visible:return
	if not rolling:
		var power:=BossRoarTimeline.strength(progress)
		var mouth:=_mouth()
		for i:int in 3:
			var phase:=fposmod((progress-BossRoarTimeline.RELEASE)*4+i*.33,1)
			if power>0:
				PixelVfx.arc(self,mouth,7+phase*32,PI*.62,PI*1.38,Color(.85,.94,.76,power*(1-phase)*.6),1)
		return
	var floor_point:=Vector2(0,62)
	if progress<.64:
		var fall:=clampf((progress-.22)/.42,0,1)
		for side:float in [-1,1]:
			for i:int in 3:
				var at:=floor_point+Vector2(side*(27+i*12)*(1-fall*.4),-30-55*(1-fall))
				PixelVfx.streak(self,at,Vector2(-side*.28,1),8+fall*18,1,Color(.74,.88,.8,sin(fall*PI)*.55))
	else:
		PixelVfx.clip(self,&"boss-land",floor_point,clampf((progress-.64)/.36,0,1))

func _mouth() -> Vector2:
	if encounter is WindkeeperPressureEncounter:
		var pose:Dictionary=(encounter as WindkeeperPressureEncounter).rig_pose()
		var head:Transform2D=pose.head_transform
		return head*Vector2(24,4)
	return Vector2(52*encounter.direction,-45)

func _release_camera() -> void:
	if _camera_token>=0 and is_instance_valid(_camera):_camera.end_takeover(_camera_token)
	_camera_token=-1

func _exit_tree() -> void:
	_release_camera()
	GameAudio.stop_origin(self,false)

static func pose_offset(t:float,wheels:bool,direction:int)->Vector2:
	# Windkeeper plants all four feet and roars. Rolling machinery retains its wake.
	if not wheels:return Vector2.ZERO
	var arrive:=clampf(t/.64,0,1)
	var settle:=sin(clampf((t-.64)/.36,0,1)*TAU)*exp(-maxf(0,t-.64)*14)
	return Vector2(sin(arrive*PI)*18*direction,settle*4)
