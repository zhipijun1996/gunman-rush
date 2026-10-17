extends Node2D
## Read-only cues. Attack physics, aim locks and damage remain on Encounter/Motor.
@export var encounter: ThornForestEncounter
var _counter_flash := 0.0
var _counter_amount := 0.0
var _counter_position := Vector2.ZERO

func _ready() -> void:
	if encounter is RootbellGuardianV2:
		(encounter as RootbellGuardianV2).duel_event.connect(_duel_event)

func _duel_event(event: Dictionary) -> void:
	# Only the existing real Policy result starts the impact cue, never H input.
	if event.get("event") != "bell_counter_committed": return
	_counter_flash = .55
	_counter_amount = float(event.get("amount",0))
	_counter_position = encounter.motor.global_position

func _process(delta: float) -> void:
	_counter_flash = maxf(0,_counter_flash-delta)
	queue_redraw()

func _draw() -> void:
	if encounter == null: return
	var color := Color("d5d273") if encounter.core_open else Color("365347")
	var size := encounter.definition.collision_size
	draw_rect(Rect2(-size*.5,size),Color("3b4838"))
	draw_circle(Vector2(0,-8),19,color)
	draw_line(Vector2(-28,-35),Vector2(-62,-60),Color("7c6d43"),9)
	draw_line(Vector2(28,-35),Vector2(62,-60),Color("7c6d43"),9)
	if not encounter is RootbellGuardianV2: return
	var duel := encounter as RootbellGuardianV2
	var config := duel.definition as BossDuelDefinition
	if duel.active and not duel.health.terminal:
		if duel.stage_phase == 2:
			# A distinct double rim persists while the actual phase is parallel.
			draw_rect(Rect2(-size*.5-Vector2(5,5),size+Vector2(10,10)),Color("91d9df"),false,2)
			_draw_visible_label(Vector2(-67,-size.y*.5-16),"II  BELL + BODY",13,Color("b5eff2"))
		if duel.has_ground_mark and duel.mode == &"pursuit_warning":
			_draw_body_warning(duel,config,size)
		if duel.mode == &"bell_warning" and is_instance_valid(duel._bell):
			var start := duel._bell.global_position
			var duration := config.bell_outbound_seconds
			var initial := (duel.attack_goal-start)/duration-Vector2(0,config.bell_gravity*duration*.5)
			draw_arc(to_local(start),config.bell_radius+8,0,TAU,32,Color("ffc276"),3)
			for index: int in 12:
				var time := duration*float(index)/12.0
				var point := start+initial*time+Vector2(0,.5*config.bell_gravity*time*time)
				draw_circle(to_local(point),3,Color("ffc276"))
	if _counter_flash > 0:
		var progress := 1.0-_counter_flash/.55
		var impact := to_local(_counter_position)
		var flash := Color(1,.77,.3,1-progress)
		draw_arc(impact,30+progress*70,0,TAU,40,flash,4)
		for index: int in 8:
			var direction := Vector2.from_angle(TAU*index/8.0)
			draw_line(impact+direction*(25+progress*30),impact+direction*(45+progress*65),flash,3)
		_draw_visible_label(impact+Vector2(-66,-68-progress*18),"BELL COUNTER  -%s" % int(_counter_amount),16,flash)

func _draw_body_warning(duel: RootbellGuardianV2, config: BossDuelDefinition, size: Vector2) -> void:
	var start := duel.motor.global_position
	var target := duel.attack_goal-Vector2(0,size.y*.5)
	var duration := config.pursuit_flight_seconds
	var velocity := (target-start)/duration-Vector2(0,config.pursuit_gravity*duration*.5)
	# Draw the full Body footprint along its intended ballistic sweep, not a
	# point T. The real collision sweep can stop early on ordinary terrain.
	var position := start
	var step := 1.0/60.0
	var ticks := ceili(duration/step)
	var previous := to_local(position)
	for index: int in range(ticks+1):
		var center := to_local(position)
		if index % 4 == 0 or index == ticks:
			draw_rect(Rect2(center-size*.5,size),Color(1,.58,.3,.10))
			draw_rect(Rect2(center-size*.5,size),Color(1,.65,.35,.38),false,1)
			draw_line(previous,center,Color(1,.67,.4,.55),2)
			previous = center
		velocity.y += config.pursuit_gravity*step
		position += velocity*step
	var mark := to_local(duel.attack_goal)
	draw_rect(Rect2(mark-Vector2(size.x*.5,size.y),size),Color("ffbf6b"),false,3)
	draw_line(mark-Vector2(size.x*.5,0),mark+Vector2(size.x*.5,0),Color("ffbf6b"),5)
	_draw_visible_label(mark+Vector2(-size.x*.5,-size.y-10),"LOCKED LANDING",13,Color("ffd3a0"))

func _draw_visible_label(at: Vector2, text: String, font_size: int, color: Color) -> void:
	# A moving Boss may reach the screen edge. Clamp only the cue's drawing;
	# the locked landing, body footprint and attack trajectory stay untouched.
	var canvas := get_global_transform_with_canvas()
	var screen := canvas*at
	var width := ThemeDB.fallback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*canvas.x.length()
	var viewport := get_viewport_rect()
	screen.x=clampf(screen.x,viewport.position.x+12,maxf(viewport.position.x+12,viewport.end.x-12-width))
	screen.y=clampf(screen.y,viewport.position.y+font_size*canvas.y.length()+8,viewport.end.y-12)
	draw_string(ThemeDB.fallback_font,canvas.affine_inverse()*screen,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
