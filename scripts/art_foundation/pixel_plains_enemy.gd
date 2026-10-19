class_name PixelPlainsEnemy
extends WindchimeEnemyVisual
## Formal behavior-specific poses/telegraphs, all keyed to accepted AI state.
var _death := 0.0
var _previous_state: StringName = &"idle"
var _burst_tail := false
func _process(delta: float) -> void:
	var state: StringName = actor.attack_behavior.state if actor.attack_behavior != null else &"idle"
	if state != _previous_state:
		_burst_tail = state==&"attack" or (state==&"recovery" and _previous_state==&"attack")
		_previous_state = state
	_clock += delta
	_hurt = maxf(0,_hurt-delta)
	if actor.health.terminal: _death += delta
	visible = _death < .65
	modulate.a = maxf(0,1-_death/.65)
	queue_redraw()

func _draw() -> void:
	if actor == null: return
	var ink := PixelFormalActors.INK
	var brass := PixelFormalActors.BRASS if _hurt<=0 else PixelFormalActors.CREAM
	var cream := PixelFormalActors.CREAM
	var behavior := actor.definition.behavior_id
	var state: StringName = actor.attack_behavior.state if actor.attack_behavior != null else &"idle"
	var face := float(actor.brain.direction)
	var size := actor.definition.collision_size
	if not actor.health.terminal: _telegraph(state,behavior)
	# Consistent 2-unit pixel grid, sized from actual definition rather than one
	# generic bird stretched over every enemy collision shape.
	var half := maxf(12,roundf(size.x*.5/2)*2)
	var floor_y := roundf(size.y*.5/2)*2
	var top := -roundf(size.y*.5/2)*2
	var stride := 2*roundf(sin(_clock*12)*2) if state==&"idle" else 0.0
	var dip := 4.0 if state==&"telegraph" else 2.0 if state==&"recovery" else 0.0
	if actor.health.terminal: dip = floor_y*.65
	draw_set_transform(Vector2(0,dip),0,Vector2(face,1))
	if behavior==&"root_bell":
		draw_rect(Rect2(-half,top+4,half*2,floor_y-top-8),ink)
		draw_rect(Rect2(-half+4,top+8,half*2-8,floor_y-top-14),PixelFormalActors.MOSS)
		draw_rect(Rect2(-half+2,floor_y-8,half*2-4,6),brass)
		PixelFormalActors.bell(self,Vector2(0,top+16),state==&"telegraph",_hurt>0)
		for side: int in [-1,1]:
			PixelFormalActors.pixel_line(self,Vector2(side*half,floor_y-6),Vector2(side*(half+8),floor_y),ink,4)
	elif actor.definition.aerial:
		var wing_y := -8.0 if int(_clock*8)%2==0 else 0.0
		draw_rect(Rect2(-half,top+8,half*2,floor_y-top-14),ink)
		draw_rect(Rect2(-half+4,top+10,half*2-8,10),brass)
		draw_rect(Rect2(-half-10,wing_y,12,6),brass)
		draw_rect(Rect2(-half-16,wing_y-4,10,4),cream)
		draw_rect(Rect2(half-8,top+2,14,14),ink)
		draw_rect(Rect2(half,top+4,4,4),cream)
		draw_rect(Rect2(half+6,top+10,10,4),brass)
	elif behavior in [&"sentry",&"fan_sentry"]:
		draw_rect(Rect2(-half,top+6,half*2,floor_y-top-10),ink)
		draw_rect(Rect2(-half+4,top+10,half*2-8,floor_y-top-18),brass)
		draw_rect(Rect2(-half-4,top+2,half*2+8,6),cream)
		draw_rect(Rect2(half-6,top+12,12,8),ink)
		draw_rect(Rect2(half-4,top+14,10,4),cream)
		if behavior==&"fan_sentry":
			for y: int in [-6,6]: draw_rect(Rect2(half-6,top+12+y,10,4),ink)
	else:
		draw_rect(Rect2(-half,top+10,half*2,floor_y-top-16),ink)
		draw_rect(Rect2(-half+4,top+12,half*2-8,floor_y-top-22),brass)
		draw_rect(Rect2(-half+4,top+8,half*2-10,6),cream)
		draw_rect(Rect2(half-8,top+4,14,14),ink)
		draw_rect(Rect2(half-2,top+6,4,4),cream)
		draw_rect(Rect2(half+6,top+12,10,4),brass)
		if behavior==&"charger":
			draw_rect(Rect2(half+8,top+6,12,4),cream)
			draw_rect(Rect2(half+16,top+2,4,6),cream)
		elif behavior==&"hopper":
			draw_rect(Rect2(-half-4,floor_y-14,10,8),brass)
			draw_rect(Rect2(-half-8,floor_y-6,14,4),ink)
		else:
			draw_rect(Rect2(-6,top-4,2,12),brass)
			draw_rect(Rect2(-12,top-8,6,6),brass)
			draw_rect(Rect2(-4,top-8,6,6),brass)
	if behavior!=&"root_bell" and not actor.definition.aerial:
		draw_rect(Rect2(-half+4+stride,floor_y-6,6,6),ink)
		draw_rect(Rect2(half-10-stride,floor_y-6,6,6),ink)
	draw_set_transform(Vector2.ZERO)
	if actor.health.terminal:
		for i: int in 4:
			var p := Vector2.from_angle(i*PI*.5)*_death*32
			draw_rect(Rect2(p.snapped(Vector2(2,2)),Vector2(4,4)),cream)
		return
	if actor.health.capacity>8:
		draw_rect(Rect2(-half,top-10,half*2,4),ink)
		draw_rect(Rect2(-half,top-10,roundf(half*2*actor.health.current/actor.health.capacity/2)*2,2),cream)
	else:
		for i: int in ceili(actor.health.current): draw_rect(Rect2(-8+i*6,top-10,4,2),cream)

func _telegraph(state: StringName, behavior: StringName) -> void:
	if actor.attack_behavior==null: return
	var cream := PixelFormalActors.CREAM
	var rose := PixelFormalActors.ROSE
	if behavior==&"root_bell":
		var center := to_local(actor.attack_behavior.attack_goal)
		var size := actor.definition.pulse_size
		if state==&"telegraph":
			PixelFormalActors.pixel_line(self,center-Vector2(size.x*.5,0),center+Vector2(size.x*.5,0),rose,4)
			for side: int in [-1,1]: PixelFormalActors.pixel_line(self,center+Vector2(side*size.x*.5,0),center+Vector2(side*size.x*.5,-12),cream)
			var progress := clampf(actor.attack_behavior.state_time/actor.definition.telegraph_duration,0,1)
			draw_rect(Rect2(center+Vector2(-size.x*.5,-6),Vector2(size.x*progress,2)),cream)
		elif state==&"attack":
			# Full active pulse bounds, exact definition width/height and foot.
			draw_rect(Rect2(center-Vector2(size.x*.5,size.y),size),Color(rose,.4))
			for x: int in range(0,ceili(size.x),6):
				draw_rect(Rect2(center+Vector2(-size.x*.5+x,-size.y),Vector2(minf(4,size.x-x),size.y)),rose)
			draw_rect(Rect2(center-Vector2(size.x*.5,size.y),Vector2(size.x,2)),cream)
		elif state==&"recovery" and _burst_tail and actor.attack_behavior.state_time<.1:
			var height := size.y*(1-actor.attack_behavior.state_time/.1)
			draw_rect(Rect2(center-Vector2(size.x*.5,height),Vector2(size.x,height)),Color(rose,.5))
		return
	if state==&"telegraph":
		draw_rect(Rect2(-2,-actor.definition.collision_size.y*.5-22,4,10),cream)
		if behavior in [&"diver",&"hopper"]:
			var goal := to_local(actor.attack_behavior.attack_goal)
			for i: int in 5:
				PixelFormalActors.pixel_line(self,goal*float(i)/5,goal*(float(i)+.4)/5,Color(rose,.6))
			draw_rect(Rect2(goal-Vector2(16,2),Vector2(32,4)),rose)
			for side: int in [-1,1]: draw_rect(Rect2(goal+Vector2(side*16-2,-8),Vector2(4,12)),cream)
		elif behavior in [&"sentry",&"fan_sentry"]:
			for angle: float in ([-.18,0.0,.18] if behavior==&"fan_sentry" else [0.0]):
				var aim := actor.attack_behavior.locked_direction.rotated(angle)
				PixelFormalActors.pixel_line(self,aim*25,aim*90,Color(rose,.65))
	elif state==&"attack":
		var face := float(actor.brain.direction)
		PixelFormalActors.pixel_line(self,Vector2(-face*32,2),Vector2(-face*15,2),cream)
	elif state in [&"recovery",&"blocked"]:
		draw_rect(Rect2(-4,-actor.definition.collision_size.y*.5-14,8,2),PixelFormalActors.MOSS)
