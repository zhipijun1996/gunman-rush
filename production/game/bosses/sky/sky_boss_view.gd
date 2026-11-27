extends Node2D
@export var actor: EnemyActor
var flash := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	actor.damageable.damaged.connect(func(_hit: Dictionary) -> void: flash=.11)
	EnemyPresentationBinding.bind_existing(actor,self,&"scene")

func _process(delta: float) -> void:
	flash = maxf(0,flash-delta)
	queue_redraw()

func synchronize_presentation() -> void: queue_redraw()

func _draw() -> void:
	if not is_instance_valid(actor) or actor.definition == null: return
	var def := actor.definition as ArenaBossDefinition
	var body := def.body_art
	var rect := Rect2(-body.get_size()/2,body.get_size())
	if actor.health.terminal:
		rect.position.y += rect.size.y*.62
		rect.size.y *= .38
		draw_texture_rect(body,rect,false,Color("#8e8885"))
		return
	var ai := actor.attack_behavior as ArenaBossBehavior
	if ai and ai.state in [&"telegraph",&"attack"]:
		var bird := def.stable_id==&"island_windbird"
		var color := Color("#ffdb94") if bird or ai.move_id!=&"phase_scan" else Color("#8ff5ee")
		var fraction := clampf(ai.state_time/def.attack_duration,0,1)
		var frames := ai.hit_rects(0 if ai.state==&"telegraph" else fraction)
		if ai.state==&"telegraph" and (not bird or ai.move_id==&"dive"):
			for tick in 22:
				var place := ai.active_rect(tick/21.0).get_center()
				draw_circle(to_local(place),2,color)
		for area: Rect2 in frames:
			var center := to_local(area.get_center())
			if bird and ai.move_id!=&"dive":
				draw_colored_polygon(PackedVector2Array([center+Vector2(-4,-10),center+Vector2(5,-5),center+Vector2(2,7),center+Vector2(-5,12)]),color)
			elif not bird:
				if ai.move_id==&"phase_scan":
					draw_line(center+Vector2(0,-129),center+Vector2(0,129),Color(color,.55),8)
				else:
					draw_circle(center,14,Color("#3a384c"))
					draw_arc(center,16,0,TAU,16,color,4)
	if ai and ai.state==&"recovery": rect.position.y+=3
	draw_texture_rect(body,rect,false,Color(1.55,1.48,1.42) if flash>0 else Color.WHITE)
	if ai and ai.state==&"recovery":
		draw_circle(Vector2(1,6),6,Color("#f3fff4"))
		draw_arc(Vector2(1,6),10,0,TAU,12,Color("#86e5dc"),2)
