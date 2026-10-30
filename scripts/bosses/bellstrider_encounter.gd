class_name BellstriderEncounter
extends WindkeeperEncounter
## Independent rolling bell machine; inherits only arena/damage/lifecycle plumbing.
var pattern_index := 0
var locked_point := Vector2.ZERO
var volley := 0
var _roll_age := 0.0

func activate() -> bool:
	if not super.activate(): return false
	pattern_index=0
	return true

func core_offset() -> Vector2: return Vector2(0,-34)

func roll_warning_distance() -> float:
	# Cover the maximum whole dash, including the contact front, up to arena edge.
	var config:=definition as WindkeeperDefinition
	return minf(arena.travel_limit(motor.global_position.x,direction),config.charge_speed*1.35)+definition.collision_size.x*.5

func objective() -> String:
	if mode==&"intro": return (definition as WindkeeperDefinition).display_name
	if mode==&"roll_warning": return "离开金色车道 / LEAVE THE MARKED ROLL LANE"
	if mode==&"ring_warning": return "跳过铃波，留意第二声 / JUMP THE RING WAVES"
	if mode==&"lob_warning" or mode==&"lob": return "落点已锁定，换一个平台 / MOVE OFF THE LOCKED LANDING"
	if core_open: return "停机散热，抓紧追击 / RECOVERY — PRESS THE ATTACK" if continuous_combat() else "停机散热！射中央发光铃芯 / SHOOT THE CENTRAL BELL"
	if continuous_combat(): return "随时可攻击，留意冲撞、铃波和落点 / WATCH THE ROLL, RINGS AND LANDING"
	return "滚轮冲刺、铃波、投铃 / ROLL • RINGS • LOB"

func physics_tick(delta: float) -> void:
	_prune_attacks()
	if not active or health.terminal or delta<=0 or not is_finite(delta): return
	stage_phase=2 if health.current<=health.capacity*.5 else 1
	clock-=delta
	var config:=definition as WindkeeperDefinition
	if mode==&"intro":
		if clock<=0: _enter(&"observe",.7)
	elif mode==&"observe" and clock<=0:
		direction=1 if _target.global_position.x>motor.global_position.x else -1
		locked_point=_target.global_position
		volley=0
		_enter([&"roll_warning",&"ring_warning",&"lob_warning"][pattern_index%3],config.warning_seconds)
	elif mode==&"roll_warning" and clock<=0:
		_roll_age=0
		_enter(&"roll",1.35)
	elif mode==&"roll":
		_roll_age+=delta
		motor.speed=config.charge_speed*clampf(_roll_age/.25,.2,1)
		var limit:=arena.travel_limit(motor.global_position.x,direction)
		motor.step(direction,limit,delta)
		if clock<=0 or limit<2: _cool_down()
	elif mode==&"ring_warning" and clock<=0:
		_ring_pair()
		volley=1
		_enter(&"rings",.9)
	elif mode==&"rings":
		if stage_phase==2 and volley==1 and clock<=.45:
			_ring_pair();volley=2
		if clock<=0: _cool_down()
	elif mode==&"lob_warning" and clock<=0:
		_launch(locked_point)
		volley=1
		_enter(&"lob",1.3)
	elif mode==&"lob":
		if stage_phase==2 and volley==1 and clock<=.6:
			# Second shot is telegraphed by the same fixed mark; no retargeting.
			_launch(locked_point+Vector2(110*direction,-20));volley=2
		if clock<=0: _cool_down()
	elif mode==&"neck" and clock<=0:
		pattern_index+=1
		_enter(&"observe",.6 if stage_phase==2 else .85)
	_update_combat_shapes()
	motor.queue_redraw()

func _cool_down() -> void:
	motor.stop()
	_enter(&"neck",(definition as WindkeeperDefinition).exposed_seconds)

func _ring_pair() -> void:
	for side: int in [-1,1]:
		_spawn(&"bellstrider_ring",motor.global_position+Vector2(side*60,48),Vector2(side,0),195,3.4)

func _launch(point: Vector2) -> void:
	var origin:=motor.global_position+Vector2(0,-20)
	_spawn(&"bellstrider_lob",origin,(point-origin).normalized(),210,2.4)

func _spawn(kind: StringName, origin: Vector2, aim: Vector2, speed: float, seconds: float) -> void:
	_attack_serial+=1
	var shot: BossProjectile=BellstriderBellProjectile.new() if kind==&"bellstrider_lob" else BossProjectile.new()
	shot.configure(definition,StringName("%s-%s-%s" % [kind,attack_epoch,_attack_serial]),aim,_target,motor)
	shot.speed=speed;shot.lifetime=seconds
	_projectiles.append(shot)
	projectile_created.emit(shot)
	motor.get_parent().add_child(shot)
	shot.global_position=origin
	if shot is BellstriderBellProjectile: shot.aim_landing(locked_point if volley==0 else locked_point+Vector2(110*direction,-20))

func cancel_pending_attacks() -> void:
	_clear_attacks()
	motor.stop()
	if active and mode!=&"intro": _enter(&"observe",.85)

func combat_snapshot() -> Dictionary:
	var data:=super.combat_snapshot()
	data.merge({"pattern_index":pattern_index,"locked_point":[locked_point.x,locked_point.y],"volley":volley,"roll_age":_roll_age},true)
	return data

func restore_combat_state(data: Dictionary) -> void:
	super.restore_combat_state(data)
	pattern_index=int(data.get("pattern_index",0));volley=int(data.get("volley",0))
	_roll_age=float(data.get("roll_age",0))
	var p: Array=data.get("locked_point",[0,0]);locked_point=Vector2(p[0],p[1])

func presentation_state() -> BossPresentationState:
	var values := _presentation_values()
	values.merge({"phase":stage_phase,"phase_axes":{"combat":stage_phase},"damage_model":&"continuous_body" if continuous_combat() else &"aperture","core_hint_visible":core_open},true)
	return _presentation_countdown(values,mode,clock,(definition as WindkeeperDefinition).warning_seconds,mode in [&"roll_warning",&"ring_warning",&"lob_warning"],mode in [&"rings",&"lob"],mode == &"roll",mode == &"neck")

func presentation_capabilities() -> PackedStringArray:
	return PackedStringArray(["core_anchor","roll_warning","locked_lob","combat_state"])
