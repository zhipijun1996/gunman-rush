class_name PixelPlainsEnemy
extends WindchimeEnemyVisual
## Formal behavior-specific poses/telegraphs, all keyed to accepted AI state.
var _death := 0.0
var _previous_state: StringName = &"idle"
var _burst_tail := false
func _presentation_profile() -> StringName:
	return &"pixel"

func _presentation_initialized() -> void:
	super._presentation_initialized()
	_death = .65 if actor.health.terminal else 0.0
	_previous_state = &"idle"
	_burst_tail = false
	visible = not actor.health.terminal
	modulate.a = 0.0 if actor.health.terminal else 1.0

func _advance_presentation(delta: float) -> void:
	var state: StringName = lifecycle.snapshot.get("state",&"idle")
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
	if not lifecycle.is_bound(): return
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
	elif EnemyPresentationBinding.view(self).get("scene_body") == &"aerial":
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

func _telegraph(state: StringName, behavior: StringName) -> void:
	if actor.attack_behavior==null: return
	# Attack intent is carried by the creature's pose. Only the actual ground
	# pulse and its short recovery tail are painted outside its body.
	if behavior!=&"root_bell": return
	var center := to_local(actor.attack_behavior.attack_goal)
	if state==&"attack":
		RootBellPulseArt.draw(self,actor.definition,center,"strike" if actor.attack_behavior.state_time<actor.definition.attack_duration*.5 else "bend",1.0)
	elif state==&"recovery" and _burst_tail and actor.attack_behavior.state_time<.1:
		RootBellPulseArt.draw(self,actor.definition,center,"fold" if actor.attack_behavior.state_time<.05 else "settled",1.0-actor.attack_behavior.state_time/.1)
