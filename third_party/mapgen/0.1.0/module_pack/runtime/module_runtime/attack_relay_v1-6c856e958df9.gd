extends ShotLatch
## New state-coupled Cell. Native enemy attack commitment opens the native gate.
## No projectile, damage, enemy motion, resource or player motion is synthesized.
var recorder
var relay_enemy_id: String=""
var relay_actor: EnemyActor
func _register_shot(_direction: Vector2,_shot_id: int)->void:
	pass
func bind_enemy(actor: EnemyActor, id: String, cells)->void:
	relay_actor=actor;relay_enemy_id=id;recorder=cells
	bell_body.collision_layer=0
	actor.attack_behavior.state_changed.connect(_native_attack_state)
func _native_attack_state(state: StringName)->void:
	if state!=&"attack" or relay_actor.health.terminal or not lifetime.active:return
	is_open=true;open_count+=1;_opened_at=_clock
	gate_body.collision_layer=0;gate_shape.set_deferred("disabled",true)
	if recorder!=null:recorder.events.append({"frame":recorder.context.frame,"type":"enemy_attack_relay_open","id":link_id,"enemy_id":relay_enemy_id,"native_state":str(state)})
	opened.emit();queue_redraw()
func _draw()->void:
	_draw_gate(gate_rect,.15 if is_open else 1.0)
	draw_line(bell_position+Vector2(-20,0),bell_position+Vector2(20,0),Color("e8bd65"),3)
	draw_string(ThemeDB.fallback_font,bell_position+Vector2(-48,-15),"ATTACK RELAY",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("e8bd65"))
