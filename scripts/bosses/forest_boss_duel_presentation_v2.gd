extends Node2D
## Read-only cues. Attack physics, aim locks and damage remain on Encounter/Motor.
@export var encounter: BossEncounter
var _counter_flash := 0.0
var _counter_amount := 0.0
var _counter_position := Vector2.ZERO
var hit_template: EnemyHitTemplate
var motion := BossMotionPresentation.new()

func _ready() -> void:
	hit_template = EnemyHitTemplate.install_boss(encounter, self)
	motion.bind(encounter)
	if encounter.presentation_capabilities().has("rootbell_duel"):
		encounter.presentation_event.connect(_duel_event)

func _duel_event(event: Dictionary) -> void:
	# Only the existing real Policy result starts the impact cue, never H input.
	if event.get("event") != "bell_counter_committed": return
	_counter_flash = .55
	_counter_amount = float(event.get("amount",0))
	_counter_position = encounter.presentation_state().position

func _process(delta: float) -> void:
	motion.sample(encounter,delta)
	_counter_flash = maxf(0,_counter_flash-delta)
	queue_redraw()

func _draw() -> void:
	if encounter == null: return
	var observed := encounter.presentation_state()
	var is_duel := encounter.presentation_capabilities().has("rootbell_duel")
	var color := Color("d5d273") if observed.core_hint_visible else Color("365347")
	var size := encounter.definition.collision_size
	if ForestBibleActors.active(self) and is_duel and encounter.definition.stable_id == &"rootbell_guardian_v2" and size == Vector2(72,96):
		motion.draw_body(self,ForestBibleActors.GUARDIAN_BODY,ForestBibleActors.GUARDIAN_BOUNDS,&"guardian",hit_template.tint(Color.WHITE.lerp(Color("858b74"),motion.death)))
		if not observed.core_hint_visible:
			draw_texture_rect_region(ForestBibleActors.GUARDIAN_BODY,Rect2(-6,-10,16,10),Rect2(30,36,16,10),Color(.30,.55,.38))
	else:
		draw_rect(Rect2(-size*.5,size),hit_template.tint(Color("3b4838")))
		draw_circle(Vector2(0,-8),19,color)
		for side: int in [-1,1]:
			var shoulder := Vector2(side*28,-35)
			var elbow := shoulder+Vector2(side*20,-12).rotated(motion.limb_angle(side))
			var tip := elbow+Vector2(side*14,-13).rotated(motion.limb_angle(side)*.5)
			draw_line(shoulder,elbow,Color("7c6d43"),9)
			draw_line(elbow,tip,Color("7c6d43"),7)
	if not is_duel: return
	if observed.active and not observed.terminal:
		if observed.phase == 2:
			# The owner reports its actual combat phase; body and Bell remain
			# independent, and no presenter reads a mutable Bell node.
			draw_rect(Rect2(-size*.5-Vector2(5,5),size+Vector2(10,10)),Color("91d9df"),false,2)
			_draw_visible_label(Vector2(-67,-size.y*.5-16),"II  BELL + BODY",13,Color("b5eff2"),true)
		var pursuit := encounter.presentation_pursuit_warning()
		if not pursuit.is_empty(): _draw_body_warning(pursuit)
		var bell_warning := encounter.presentation_bell_warning()
		if not bell_warning.is_empty():
			draw_arc(to_local(bell_warning.origin),float(bell_warning.radius)+8,0,TAU,32,Color("ffc276"),3)
			for point: Vector2 in bell_warning.points:
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

func _draw_body_warning(warning: Dictionary) -> void:
	var size: Vector2 = warning.body_size
	var previous := to_local(warning.origin)
	# The Encounter publishes the original projected footprint sweep. Drawing
	# cannot choose a gravity, flight clock, lock target or collision extent.
	for point: Vector2 in warning.centers:
		var center := to_local(point)
		draw_rect(Rect2(center-size*.5,size),Color(1,.58,.3,.10))
		draw_rect(Rect2(center-size*.5,size),Color(1,.65,.35,.38),false,1)
		draw_line(previous,center,Color(1,.67,.4,.55),2)
		previous = center
	var mark := to_local(warning.landing)
	draw_rect(Rect2(mark-Vector2(size.x*.5,size.y),size),Color("ffbf6b"),false,3)
	draw_line(mark-Vector2(size.x*.5,0),mark+Vector2(size.x*.5,0),Color("ffbf6b"),5)
	_draw_visible_label(mark+Vector2(-size.x*.5,-size.y-10),"LOCKED LANDING",13,Color("ffd3a0"))

func _draw_visible_label(at: Vector2, text: String, font_size: int, color: Color, avoid_bell := false) -> void:
	# A moving Boss may reach the screen edge. Clamp only the cue's drawing;
	# the locked landing, body footprint and attack trajectory stay untouched.
	var canvas := get_global_transform_with_canvas()
	var screen := canvas*at
	var width := ThemeDB.fallback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*canvas.x.length()
	var viewport := get_viewport_rect()
	var left := viewport.position.x+12
	var right := viewport.end.x-12
	# Keep lettering inside the actual arena as well as the viewport: the
	# sealed boundary is drawn above this Actor and can obscure warning text.
	if encounter.arena.right_x > encounter.arena.left_x:
		var arena_left := canvas*to_local(Vector2(encounter.arena.left_x,encounter.motor.global_position.y))
		var arena_right := canvas*to_local(Vector2(encounter.arena.right_x,encounter.motor.global_position.y))
		left=maxf(left,minf(arena_left.x,arena_right.x)+12)
		right=minf(right,maxf(arena_left.x,arena_right.x)-12)
	screen.x=clampf(screen.x,left,maxf(left,right-width))
	# Only move a phase label when its actual screen rectangle overlaps the
	# nearby Bell cue. A remote flying Bell must not drag this label away.
	var bell := encounter.presentation_bell() if avoid_bell else {}
	if not bell.is_empty():
		var bell_center := canvas*to_local(bell.position)
		var radius := Vector2(canvas.x.length(),canvas.y.length())*(float(bell.radius)+8)
		var height := ThemeDB.fallback_font.get_height(font_size)*canvas.y.length()
		var letters := Rect2(screen-Vector2(0,height),Vector2(width,height+4))
		if letters.intersects(Rect2(bell_center-radius,radius*2)):
			screen.y=minf(screen.y,bell_center.y-radius.y-12)
	screen.y=clampf(screen.y,viewport.position.y+font_size*canvas.y.length()+8,viewport.end.y-12)
	draw_string(ThemeDB.fallback_font,canvas.affine_inverse()*screen,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _exit_tree() -> void:
	if is_instance_valid(encounter) and encounter.presentation_event.is_connected(_duel_event): encounter.presentation_event.disconnect(_duel_event)
	motion.dispose(encounter)

func synchronize_presentation() -> void:
	motion.synchronize(encounter)
