extends Node2D
## Metalwork, moving head and warning are driven by one physical attack path.
@export var actor: EnemyActor
const INK := Color("#26232c")
const STEEL := Color("#637174")
const BRASS := Color("#a67950")
const GOLD := Color("#f7c67d")
const RED := Color("#e16c45")
const GLASS := Color("#9ae3d5")
var flash := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	actor.damageable.damaged.connect(func(_context: Dictionary) -> void: flash=0.13)
	EnemyPresentationBinding.bind_existing(actor,self,&"scene")

func _process(delta: float) -> void:
	flash = maxf(0,flash-delta)
	queue_redraw()

func synchronize_presentation() -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(actor) or actor.definition==null: return
	var machine := actor.definition as ArenaBossDefinition
	var behavior := actor.attack_behavior as MachineBossBehavior
	var tex := machine.body_art
	var origin := -tex.get_size()/2
	if actor.health.terminal:
		var fallen := Rect2(Vector2(origin.x, machine.floor_offset-tex.get_height()*0.38),Vector2(tex.get_width(),tex.get_height()*0.38))
		draw_texture_rect(tex,fallen,false,Color("#777a77"))
		return
	if machine.aerial:
		for x: float in [-46,46]:
			draw_line(Vector2(x,-176),Vector2(x,-18),INK,6)
			draw_line(Vector2(x-1,-176),Vector2(x-1,-18),STEEL,2)
	if is_instance_valid(behavior) and behavior.state in [&"telegraph",&"attack"]:
		_draw_action(behavior)
	draw_texture(tex,origin,Color(1.9,1.7,1.4) if flash>0 else Color.WHITE)
	var core := Vector2(36,-5) if machine.behavior_id==&"gear_overseer" else Vector2(0,31) if machine.aerial else Vector2(0,26)
	var open := is_instance_valid(behavior) and behavior.state==&"recovery"
	var lens := GLASS if open else RED if is_instance_valid(behavior) and behavior.phases.phase==2 else GOLD
	var radius := 10 if open else 4
	draw_circle(core,radius+2,INK)
	draw_circle(core,radius,lens.darkened(0.5))
	draw_circle(core,radius-2,lens)
	draw_rect(Rect2(core+Vector2(-2,-radius+2),Vector2(4,2)),Color.WHITE)
	if open:
		for side: float in [-1,1]:
			draw_line(core+Vector2(side*9,-11),core+Vector2(side*14,-7),BRASS,4)
			draw_line(core+Vector2(side*14,-7),core+Vector2(side*14,9),GOLD,2)

func _draw_action(behavior: MachineBossBehavior) -> void:
	var start := to_local(behavior.attack_origin)
	var end := to_local(behavior.attack_goal)
	var light := behavior.move_id==&"curtain"
	var color := GLASS if light else GOLD
	var warning := behavior.state==&"telegraph"
	if warning:
		# Metal ticks mark the threatened lane; a light curtain additionally shows its vertical extent.
		var delta := end-start
		var count := maxi(1,ceili(delta.length()/22))
		var blink := 0.55+0.45*absf(cos(behavior.state_time*9))
		for i: int in range(count+1):
			var p := (start+delta*(float(i)/count)).round()
			draw_line(p,p+delta.normalized()*6,Color(color,blink),2)
		if light:
			draw_line(start-Vector2(0,110),start+Vector2(0,110),Color(color,blink),2)
		if behavior.move_id in [&"stamp",&"left_weight",&"right_weight"]:
			var landing := end+Vector2(0,behavior.footprint.y/2-2)
			draw_line(landing-Vector2(behavior.footprint.x/2,0),landing+Vector2(behavior.footprint.x/2,0),RED,3)
	if behavior.move_id==&"rail": return
	var rect := behavior.active_rect(0.0 if warning else behavior.state_time/behavior.machine.attack_duration)
	rect.position = to_local(rect.position).round()
	var head := rect.get_center()
	if light:
		var bright := 0.5 if warning else 0.95
		draw_rect(rect,Color(GLASS,0.16))
		for offset: float in [-5,0,6]:
			draw_line(head+Vector2(offset,-rect.size.y/2),head+Vector2(offset,rect.size.y/2),Color(GLASS,bright),2)
		return
	if behavior.move_id in [&"sweep",&"backswing",&"gantry"]:
		var pivot := Vector2(0,10) if behavior.move_id!=&"gantry" else Vector2(head.x, -90)
		draw_line(pivot,head,INK,12)
		draw_line(pivot,head,STEEL,7)
		draw_line(pivot-Vector2(0,2),head-Vector2(0,2),BRASS,2)
	else:
		draw_line(Vector2(head.x,-150),head,INK,6)
		draw_line(Vector2(head.x-1,-150),head-Vector2(1,0),STEEL,2)
	draw_rect(rect,INK)
	draw_rect(rect.grow(-2),BRASS)
	draw_rect(rect.grow(-5),STEEL)
	for x: int in range(int(rect.position.x)+9,int(rect.end.x)-7,12):
		draw_line(Vector2(x,rect.position.y+7),Vector2(x-4,rect.end.y-7),INK,4)
	draw_line(rect.position+Vector2(3,3),Vector2(rect.end.x-3,rect.position.y+3),color,2)
