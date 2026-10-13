class_name WeaponActionRuntime
extends Node2D
## Stateful behaviors for the single equipped weapon. Visual methods only read accepted state.
signal phase_changed(phase: StringName)
signal entity_transition(entity: WeaponEntity, action: StringName)
var ability: ShootAbility
var phase: StringName = &"idle"
var age := 0.0
var direction := Vector2.RIGHT
var entities: Array[WeaponEntity] = []
var _session := 0
var _packet := 0
var _skill := false
var _packet_damage := 0.0
var _timer := 0.0
var _rounds := 0
var _entity_serial := 0
var _beam_point := Vector2.ZERO
var _beam_start := Vector2.ZERO
var _center := Vector2.ZERO
var _fx: Array[Dictionary] = []
var _art: Dictionary = {}
var _beam_require_release := false
var skill_cooldown := 0.0
var pose_remaining := 0.0
var pose: StringName = &"idle"
func actor() -> PlayerController:return ability.controller
func definition() -> WeaponDefinition:return ability.weapon
func art_catalog() -> Dictionary:
	if _art.is_empty() and FileAccess.file_exists("res://assets/actor_actions/weapon_catalog.json"):
		_art=JSON.parse_string(FileAccess.get_file_as_string("res://assets/actor_actions/weapon_catalog.json"))
	return _art
func valid_session(value: int) -> bool:return is_instance_valid(ability) and is_instance_valid(actor()) and actor().active and actor().session_id==value
func occupied() -> bool:
	return phase!=&"idle" or not current_entities().is_empty()
func locks_movement() -> bool:return phase==&"singularity"
func visual_state() -> StringName:
	if phase==&"singularity":return &"singularity_hold"
	if phase==&"charge":return &"weapon_charge"
	if phase==&"throw_windup":return &"blade_throw"
	if phase==&"beam":return &"laser_fire"
	return pose if pose_remaining>0 else &"idle"
func current_entities() -> Array[WeaponEntity]:
	var alive: Array[WeaponEntity]=[]
	for item: WeaponEntity in entities:
		if is_instance_valid(item) and not item.spent:alive.append(item)
	entities=alive;return alive
func _phase(value: StringName) -> void:
	phase=value;age=0;phase_changed.emit(value);queue_redraw()
func _pose(value: StringName, seconds: float = .18) -> void:
	pose=value;pose_remaining=seconds
func cancel(reason: StringName) -> void:
	# World entities survive a pause/aim interruption; equip/death/respawn remove them.
	if reason in [&"equipment",&"reset",&"death",&"respawn",&"segment_return",&"scene_changed"]:
		for item: WeaponEntity in current_entities():item.dispose()
		entities.clear();_fx.clear()
	if phase in [&"beam",&"charge",&"storm",&"fan_wait",&"throw_windup",&"singularity"]:
		_phase(&"idle");actor().motor.cancel_ability_motion()
	pose_remaining=0
func begin(direction_value: Vector2, grounded: bool, skill: bool = false) -> bool:
	var def := definition()
	if def.mode==WeaponDefinition.Mode.LASER and not skill and _beam_require_release:return false
	if occupied() or (skill and (def.tier!=3 or skill_cooldown>0)):
		ability.shot_rejected.emit(&"weapon_busy");return false
	if not direction_value.is_finite() or direction_value.is_zero_approx():return false
	if skill and not actor().combat_energy.can_consume(def.skill_cost):ability.shot_rejected.emit(&"combat_energy");return false
	if def.mode==WeaponDefinition.Mode.LASER and not skill:_beam_require_release=true
	if not ability.reserve_packet(direction_value,grounded):return false
	_session=actor().session_id;_packet=ability.packet_id;_skill=skill;direction=direction_value.normalized()
	_packet_damage=(def.skill_damage if skill else def.damage)*actor().motor.tuning.projectile_damage
	if skill:
		if not actor().combat_energy.consume("%s/skill/%s" % [_session,_packet],def.skill_cost):return false
		skill_cooldown=def.skill_cooldown
		if def.mode in [WeaponDefinition.Mode.MACHINE,WeaponDefinition.Mode.LASER]:
			_phase(&"charge");_pose(&"weapon_charge",def.skill_charge);return true
	_start(grounded)
	return true
func _start(grounded: bool) -> void:
	var def := definition()
	actor().traversal.on_weapon_fired();actor().jump_ability.cancel_ascent()
	GameAudio.cue(actor().motor,&"focus_start" if _skill or def.mode in [WeaponDefinition.Mode.LASER,WeaponDefinition.Mode.SINGULARITY] else &"jump" if def.mode in [WeaponDefinition.Mode.SHURIKEN,WeaponDefinition.Mode.FAN,WeaponDefinition.Mode.BOOMERANG] else &"confirm")
	if def.mode in [WeaponDefinition.Mode.SHURIKEN,WeaponDefinition.Mode.FAN,WeaponDefinition.Mode.BOOMERANG]:
		_phase(&"throw_windup");return
	_release(grounded)
func _release(_grounded: bool) -> void:
	var def := definition()
	match def.mode:
		WeaponDefinition.Mode.LASER:
			_phase(&"beam");_timer=0;_pose(&"laser_fire",def.beam_duration)
		WeaponDefinition.Mode.SHURIKEN,WeaponDefinition.Mode.FAN:
			var count := 9 if _skill else 3 if def.mode==WeaponDefinition.Mode.FAN else 1
			var spread := PI*1.25 if _skill else .55
			for i: int in count:
				var angle := spread*(float(i)/maxi(1,count-1)-.5) if count>1 else 0.0
				ability.emit_special_projectile(direction.rotated(angle),_skill,&"blade")
			flash(-direction,def.flash_speed*(def.skill_multiplier if _skill else 1),def.flash_duration)
			_pose(&"blade_throw")
			if def.mode==WeaponDefinition.Mode.FAN and not _skill:_phase(&"fan_wait")
			else:_phase(&"idle")
		WeaponDefinition.Mode.BOOMERANG:
			spawn(&"boomerang",actor().motor.global_position+direction*25)
			flash(-direction,def.flash_speed,def.flash_duration);_pose(&"blade_throw");_phase(&"idle")
		WeaponDefinition.Mode.BOMB:
			spawn(&"bomb",actor().motor.global_position+direction*18);_pose(&"bomb_place");_phase(&"idle")
		WeaponDefinition.Mode.MINE:
			spawn(&"mine",actor().motor.global_position+direction*15);_pose(&"bomb_place");_phase(&"idle")
		WeaponDefinition.Mode.SINGULARITY:
			_center=actor().motor.global_position;actor().motor.reset_motion();actor().motor.request_ability_velocity(Vector2.ZERO);actor().jump_ability.cancel_requests();_phase(&"singularity")
		WeaponDefinition.Mode.MACHINE:
			_phase(&"storm");_rounds=def.skill_rounds;_timer=0
func spawn(kind: StringName, point: Vector2) -> WeaponEntity:
	_entity_serial+=1
	var item := WeaponEntity.new()
	item.runtime=self;item.kind=kind;item.direction=direction;item.packet=_packet;item.session=_session;item.skill=_skill;item.serial=_entity_serial
	item.start_point=actor().motor.global_position
	actor().motor.get_parent().add_child(item);item.global_position=item.start_point;entities.append(item)
	item._sweep(point-item.start_point)
	return item
func flash(unit: Vector2, speed: float, duration: float) -> void:
	if actor().traversal.busy():actor().traversal.cancel()
	actor().motor.reset_motion();actor().jump_ability.cancel_ascent()
	actor().motor.start_weapon_burst(unit,speed,duration)
func advance(delta: float) -> void:
	pose_remaining=maxf(0,pose_remaining-delta);skill_cooldown=maxf(0,skill_cooldown-delta)
	if not actor().router.aim_engaged:_beam_require_release=false
	for i: int in range(_fx.size()-1,-1,-1):
		_fx[i].age+=delta
		if _fx[i].age>.3:_fx.remove_at(i)
	if not valid_session(_session):
		if phase!=&"idle" or not current_entities().is_empty():cancel(&"reset")
		queue_redraw();return
	age+=delta
	var aim := actor().router.aim_direction
	if not actor().router.aim_engaged:_beam_require_release=false
	if not aim.is_zero_approx() and actor().router.aim_mode in [&"attack",&"singularity_launch"]:direction=aim
	if actor().router.aim_mode!=&"grapple":
		actor().router.aim_mode=&"singularity_launch" if phase==&"singularity" else &"steer_blade" if not current_entities().is_empty() and current_entities()[0].kind==&"boomerang" else &"attack"
	var def := definition()
	match phase:
		&"throw_windup":
			if age>=def.throw_windup:_release(actor().motor.is_on_floor())
		&"charge":
			if age>=def.skill_charge:
				if def.mode==WeaponDefinition.Mode.LASER:
					(actor().motor.get_node("CourierVisual") as CourierVisual).set_state(&"laser_fire")
					beam_damage(direction,_packet_damage,true,true)
					flash(-direction,def.flash_speed*def.skill_multiplier,.14);_pose(&"weapon_skill",.25);_phase(&"idle")
				else:_start(actor().motor.is_on_floor())
		&"storm":
			_timer-=delta
			if _timer<=0:
				for angle: float in [-.16,0,.16]:ability.emit_special_projectile(direction.rotated(angle),true,&"bullet")
				actor().motor.start_shot_burst(-direction,def.recoil_scale);actor().motor.recoil_burst_remaining=def.burst_duration
				_pose(&"weapon_skill");_rounds-=1;_timer+=def.skill_interval
				if _rounds<=0:_phase(&"idle")
		&"fan_wait":
			if age>=def.second_flash_delay:
				flash(-direction,def.flash_speed*.72,def.second_flash_duration);_pose(&"blade_throw",.13);_phase(&"idle")
		&"beam":
			if not actor().router.aim_engaged or age>=def.beam_duration:
				_beam_require_release=actor().router.aim_engaged;_phase(&"idle")
			else:
				var cost := (def.beam_drain+age*def.beam_growth)*delta
				var stamina := actor().actor_resources.stamina
				if stamina.current+1e-9<cost:_phase(&"idle")
				else:
					stamina.consume_continuous(cost,stamina.epoch)
					actor().traversal.on_weapon_fired()
					actor().motor.normal_velocity.y-=direction.y*actor().motor.tuning.gravity*def.beam_lift_ratio*delta
					actor().motor.apply_impulse(-direction*def.beam_push*delta)
					_timer-=delta
					beam_damage(direction,_packet_damage,false,false,_timer<=0)
					if _timer<=0:
						GameAudio.cue(actor().motor,&"focus_start");_timer+=def.beam_tick
		&"singularity":
			actor().motor.request_ability_velocity(Vector2.ZERO)
			actor().jump_ability.cancel_requests()
			attract(delta)
			if age>=def.hold_seconds:
				damage_burst(_center,def.blast_radius*(def.skill_multiplier if _skill else 1),_skill)
				actor().motor.cancel_ability_motion()
				flash(direction,def.blast_speed*(def.skill_multiplier if _skill else 1),.15);_pose(&"weapon_skill");_phase(&"idle")
	queue_redraw()
func context() -> bool:
	for item: WeaponEntity in current_entities():
		if item.kind==&"boomerang":return item.recall()
		if item.kind==&"mine" and item.phase==&"attached":explode(item);return true
	return false
func steer_direction(item: WeaponEntity, fallback: Vector2) -> Vector2:
	if actor().traversal.busy():return fallback
	if actor().router.current_device==&"keyboard_mouse":
		var world_mouse := item.get_canvas_transform().affine_inverse()*get_viewport().get_mouse_position()
		var value := world_mouse-item.global_position
		return value.normalized() if value.length()>12 else Vector2.ZERO
	var aim := actor().router.aim_direction
	return aim if not aim.is_zero_approx() else Vector2.ZERO
func hit(receiver: Damageable, packet: int, serial: int, stage: String, skill: bool, point: Vector2, unit: Vector2, amount: float = -1) -> bool:
	if not receiver.active or receiver.faction!=&"enemy":return false
	var damage := amount if amount>0 else _packet_damage
	var event := "%s:%s:weapon:%s:%s:%s" % [actor().motor.get_instance_id(),_session,packet,serial,stage]
	var target_id := receiver.actor_id if receiver.actor_id!=0 else receiver.get_instance_id()
	return receiver.receive_damage({"session_id":_session,"event_id":event,"source_actor_id":actor().motor.get_instance_id(),"source_faction":&"player","target_actor_id":receiver.actor_id,"target_epoch":receiver.damage_epoch,"amount":damage,"damage_type":&"weapon","hit_point":point,"hit_direction":unit,"on_committed":actor().on_weapon_damage.bind(_session,packet,serial,not actor().motor.is_on_floor(),target_id,skill,receiver,ability.weapon_epoch)})
func beam_damage(unit: Vector2, amount: float, skill: bool, pierce: bool, commit: bool = true) -> void:
	var visual := actor().motor.get_node("CourierVisual") as CourierVisual
	var start := visual.muzzle_position(unit)
	_beam_start=start
	var barrel := PhysicsRayQueryParameters2D.create(actor().motor.global_position,start,1,[actor().motor.get_rid()])
	var obstruction := get_world_2d().direct_space_state.intersect_ray(barrel)
	if not obstruction.is_empty():
		_beam_start=obstruction.position;_beam_point=obstruction.position;return
	var finish := start+unit*definition().range_limit
	var exclude: Array[RID]=[actor().motor.get_rid()]
	_entity_serial+=1
	for i: int in 12:
		var ray := PhysicsRayQueryParameters2D.create(start,finish,0xFFFFFFFF,exclude);ray.collide_with_areas=true
		var contact := get_world_2d().direct_space_state.intersect_ray(ray)
		if contact.is_empty():_beam_point=finish;break
		_beam_point=contact.position
		var collider := contact.collider as Node
		var receiver := collider.get_node_or_null("Damageable") as Damageable if collider!=null else null
		if receiver!=null and receiver.faction==&"enemy":
			if commit:hit(receiver,_packet,_entity_serial,"beam",skill,contact.position,unit,amount)
			if not pierce:break
		elif not collider is Area2D:break
		exclude.append(contact.rid)
	if skill:_fx.append({"kind":"beam","start":start,"end":_beam_point,"age":0.0,"skill":skill})
func receivers(point: Vector2, radius: float) -> Array[Dictionary]:
	var shape := CircleShape2D.new();shape.radius=radius
	var query := PhysicsShapeQueryParameters2D.new();query.shape=shape;query.transform=Transform2D(0,point);query.collide_with_areas=true;query.exclude=[actor().motor.get_rid()]
	var values: Array[Dictionary]=[];var seen: Dictionary={}
	for item: Dictionary in get_world_2d().direct_space_state.intersect_shape(query,64):
		var node := item.collider as Node2D
		var receiver := node.get_node_or_null("Damageable") as Damageable if node!=null else null
		if receiver==null or not receiver.active or receiver.faction!=&"enemy" or seen.has(receiver.get_instance_id()):continue
		seen[receiver.get_instance_id()]=true;values.append({"node":node,"receiver":receiver})
	values.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return point.distance_squared_to(a.node.global_position)<point.distance_squared_to(b.node.global_position))
	return values
func clear_line(start: Vector2, finish: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(start,finish,1,[actor().motor.get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
func damage_burst(point: Vector2, radius: float, skill: bool) -> void:
	_entity_serial+=1
	var def := definition()
	var chain_count := 0;var chain_origin := point
	for value: Dictionary in receivers(point,radius+(def.chain_range*def.chain_limit if skill and def.mode==WeaponDefinition.Mode.MINE else 0)):
		var target: Node2D=value.node
		var within := target.global_position.distance_to(point)<=radius
		if not within:
			if not skill or def.mode!=WeaponDefinition.Mode.MINE or chain_count>=def.chain_limit or target.global_position.distance_to(chain_origin)>def.chain_range or not clear_line(chain_origin,target.global_position):continue
			_fx.append({"kind":"arc","start":chain_origin,"end":target.global_position,"age":0.0,"skill":true});chain_count+=1
		elif not clear_line(point,target.global_position):continue
		hit(value.receiver,_packet,_entity_serial,"blast",skill,target.global_position,(target.global_position-point).normalized())
		chain_origin=target.global_position
	_fx.append({"kind":"blast","start":point,"radius":radius,"age":0.0,"skill":skill})
func explode(item: WeaponEntity) -> void:
	if not item.valid_owner():return
	var def := definition();_packet=item.packet;_skill=item.skill
	var radius: float = def.blast_radius*(def.skill_multiplier if item.skill else 1.0)
	damage_burst(item.global_position,radius,item.skill)
	var offset := actor().motor.global_position-item.global_position
	if offset.length()<=radius and clear_line(item.global_position,actor().motor.global_position):
		flash(offset.normalized() if not offset.is_zero_approx() else Vector2.UP,def.blast_speed*(def.skill_multiplier if item.skill else 1),.14)
	_pose(&"weapon_skill" if item.skill else &"bomb_place")
	item.dispose();_phase(&"idle");GameAudio.cue(actor().motor,&"impact")
func caught(item: WeaponEntity, unit: Vector2) -> void:
	if not item.valid_owner() or item.phase!=&"returning":return
	if not unit.is_zero_approx():flash(unit,definition().catch_speed*(definition().skill_multiplier if item.skill else 1),.13)
	entity_transition.emit(item,&"caught")
	_pose(&"blade_catch");item.dispose();GameAudio.cue(actor().motor,&"confirm")
func entity_failed(item: WeaponEntity) -> void:
	_fx.append({"kind":"fizzle","start":item.global_position,"radius":12.0,"age":0.0,"skill":false})
	GameAudio.cue(actor().motor,&"denied")
func entity_attached(item: WeaponEntity) -> void:
	entity_transition.emit(item,&"attached");GameAudio.cue(actor().motor,&"confirm")
func attract(_delta: float) -> void:
	var def := definition();var count := 0
	for value: Dictionary in receivers(_center,def.attract_radius*(def.skill_multiplier if _skill else 1)):
		var target := value.node as EnemyMotor
		if target==null or value.receiver.impact_style()==&"boss" or count>=def.attract_limit or not clear_line(_center,target.global_position):continue
		if target.get_node("CollisionShape2D").shape.size.length()>70:continue
		target.request_attraction(_center,def.attract_speed,def.attract_stop_ring);count+=1
func _draw() -> void:
	if phase==&"beam":
		draw_line(to_local(_beam_start),to_local(_beam_point),Color(.15,.55,.8,.4),8,true)
		draw_line(to_local(_beam_start),to_local(_beam_point),Color(.65,.95,1),2,true)
	for fx: Dictionary in _fx:
		var alpha := 1-float(fx.age)/.3
		if fx.kind in ["beam","arc"]:
			var color := Color(.35,.86,1,alpha)
			draw_line(to_local(fx.start),to_local(fx.end),Color(.2,.5,.8,alpha*.4),14 if fx.skill else 6,true)
			draw_line(to_local(fx.start),to_local(fx.end),color,5 if fx.skill else 2,true)
		else:
			var progress := float(fx.age)/.3
			draw_arc(to_local(fx.start),float(fx.radius)*(.2+.8*progress),0,TAU,64,Color(.45,.65,.8,alpha) if fx.kind=="fizzle" else Color(1,.65,.25,alpha),4,true)
	if phase==&"singularity":
		var center := to_local(_center);var progress := clampf(age/definition().hold_seconds,0,1)
		draw_circle(center,24,Color(.3,.1,.5,.4))
		for i: int in 4:draw_arc(center,12+i*10,age*7+i,age*7+i+PI*1.3,24,Color(.6,.5,1,.7),2,true)
		draw_arc(center,definition().attract_radius,0,TAU*progress,64,Color(.6,.55,1,.2),1,true)
		draw_line(center,center+direction*60,Color(1,.85,.45),2,true)
		draw_circle(center+direction*60,4,Color(1,.85,.45))
	elif phase==&"charge":
		draw_arc(to_local(actor().motor.global_position),25,0,TAU*minf(1,age/definition().skill_charge),32,Color(.3,.9,1),3,true)
