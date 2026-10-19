class_name WeaponActionRuntime
extends Node2D
## Stateful behaviors for the single equipped weapon. Visual methods only read accepted state.
signal blast_fired(point: Vector2)
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
var _fire_grounded := false
var _beam_elapsed := 0.0
var skill_cooldown := 0.0
var pose_remaining := 0.0
var pose: StringName = &"idle"
func _ready() -> void:
	actor().motor.weapon_blinked.connect(_blink_fx)
func steering_focus() -> bool:
	var items := current_entities()
	return not actor().motor.is_on_floor() and not actor().traversal.busy() and not items.is_empty() and items[0].kind==&"boomerang" and items[0].phase in [&"outbound",&"auto_return"]
func fx_duration(fx: Dictionary) -> float:
	return .55 if fx.kind=="blast" else .22 if fx.kind=="blink" else .3
func return_flash(start: Vector2, finish: Vector2) -> void:
	_fx.append({"kind":"beam","start":start,"end":finish,"age":0.0,"skill":false})
func _blink_fx(start: Vector2, finish: Vector2) -> void:
	var visual := actor().motor.get_node("CourierVisual") as CourierVisual
	var transform := visual.body.global_transform
	transform.origin+=start-finish
	_fx.append({"kind":"blink","start":start,"end":finish,"age":0.0,"texture":visual.body.texture,"transform":transform,"skill":false})
	_pose(&"blade_throw",.16)
	GameAudio.cue(actor().motor,&"focus_start")
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
	if actor().motor.weapon_pause_remaining>0:return &"blade_throw"
	if phase==&"fan_wait":return &"blade_throw" if age<.13 else &"weapon_charge"
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
	if phase==&"beam":actor().motor.stop_weapon_drive()
	actor().motor.cancel_weapon_requests()
	# World entities survive a pause/aim interruption; equip/death/respawn remove them.
	if reason in [&"equipment",&"reset",&"death",&"respawn",&"segment_return",&"scene_changed"]:
		for item: WeaponEntity in current_entities():item.dispose()
		entities.clear();_fx.clear()
	if phase in [&"beam",&"charge",&"storm",&"fan_wait",&"throw_windup",&"singularity"]:
		_phase(&"idle");actor().motor.cancel_ability_motion()
	pose_remaining=0
func begin(direction_value: Vector2, grounded: bool, skill: bool = false) -> bool:
	var def := definition()
	# Main aim starts a laser primary; a valid skill trigger can take ownership
	# without refunding the already accepted primary cost. No other busy action is preempted.
	if skill and def.tier==3 and def.mode==WeaponDefinition.Mode.LASER and phase==&"beam" and skill_cooldown<=0 and actor().active and ability.enabled and direction_value.is_finite() and not direction_value.is_zero_approx() and actor().combat_energy.can_consume(def.skill_cost) and (actor().shot_energy==null or actor().shot_energy.can_fire()) and (grounded or actor().action_resources.shot_charges>0):
		_end_beam(false);ability.cooldown_remaining=0
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
		if def.mode==WeaponDefinition.Mode.LASER:_beam_require_release=true
		if not actor().combat_energy.consume("%s/skill/%s" % [_session,_packet],def.skill_cost):return false
		skill_cooldown=def.skill_cooldown
		if def.mode in [WeaponDefinition.Mode.MACHINE,WeaponDefinition.Mode.LASER]:
			_phase(&"charge");_pose(&"weapon_charge",def.skill_charge);return true
	_start(grounded)
	return true
func _start(grounded: bool) -> void:
	_fire_grounded=grounded
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
			actor().motor.reset_motion();actor().motor.request_weapon_drive(Vector2.ZERO,Vector2.ZERO)
			_beam_elapsed=0;_phase(&"beam");_timer=0;_pose(&"laser_fire",def.beam_duration)
			beam_damage(direction,_packet_damage,false,false,false)
		WeaponDefinition.Mode.SHURIKEN,WeaponDefinition.Mode.FAN:
			var count := 9 if _skill else 3 if def.mode==WeaponDefinition.Mode.FAN else 1
			var spread := PI*1.25 if _skill else .55
			for i: int in count:
				var angle := spread*(float(i)/maxi(1,count-1)-.5) if count>1 else 0.0
				ability.emit_special_projectile(direction.rotated(angle),_skill,&"blade")
			blink(-direction,base_displacement()*(def.skill_multiplier if _skill else 1))
			_pose(&"blade_throw")
			if def.mode==WeaponDefinition.Mode.FAN and not _skill:_phase(&"fan_wait")
			else:_phase(&"idle")
		WeaponDefinition.Mode.BOOMERANG:
			spawn(&"boomerang",actor().motor.global_position+direction*25)
			blink(-direction,base_displacement());_pose(&"blade_throw");_phase(&"idle")
		WeaponDefinition.Mode.BOMB:
			var bomb := spawn(&"bomb",actor().motor.global_position+direction*18)
			explode(bomb);_pose(&"bomb_place");_phase(&"idle")
		WeaponDefinition.Mode.MINE:
			if not _fire_grounded and not _skill:
				var bomb := spawn(&"bomb",actor().motor.global_position+direction*18)
				explode(bomb)
			else:spawn(&"mine",actor().motor.global_position+direction*15)
			_pose(&"bomb_place");_phase(&"idle")
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
func base_displacement() -> float:
	return actor().motor.weapon_motion.base_distance(actor().motor.tuning,_fire_grounded)
func base_recoil() -> void:
	ability.recoil.execute(direction,_fire_grounded)
func blink(unit: Vector2, distance: float) -> void:
	if actor().traversal.busy():actor().traversal.cancel()
	actor().jump_ability.cancel_ascent()
	actor().motor.request_weapon_blink(unit.normalized()*distance)
func flash(unit: Vector2, speed: float, duration: float) -> void:
	if actor().traversal.busy():actor().traversal.cancel()
	actor().motor.reset_motion();actor().jump_ability.cancel_ascent()
	actor().motor.start_weapon_burst(unit,speed,duration)
func advance(delta: float) -> void:
	pose_remaining=maxf(0,pose_remaining-delta);skill_cooldown=maxf(0,skill_cooldown-delta)
	if not actor().router.aim_engaged:_beam_require_release=false
	for i: int in range(_fx.size()-1,-1,-1):
		_fx[i].age+=delta
		if _fx[i].age>fx_duration(_fx[i]):_fx.remove_at(i)
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
				blink(-direction,base_displacement()*actor().motor.weapon_motion.secondary_ratio);_pose(&"blade_throw",.13);_phase(&"idle")
		&"beam":
			if not actor().router.aim_engaged:
				_end_beam(false)
			else:
				var step := minf(delta,maxf(0,def.beam_duration-_beam_elapsed))
				var cost := (def.beam_drain+_beam_elapsed*def.beam_growth)*step
				var stamina := actor().actor_resources.stamina
				if stamina.current+1e-9<cost:_end_beam(false)
				else:
					stamina.consume_continuous(cost,stamina.epoch)
					actor().traversal.on_weapon_fired()
					var budget := base_displacement()*actor().motor.weapon_motion.lv2_total_ratio
					var acceleration := 2*budget/(def.beam_duration*def.beam_duration)
					var distance := acceleration*(_beam_elapsed*step+.5*step*step)
					_beam_elapsed+=step
					actor().motor.request_weapon_drive(-direction*distance/delta,-direction*acceleration*_beam_elapsed)
					_timer-=step
					beam_damage(direction,_packet_damage,false,false,_timer<=0)
					if _timer<=0:GameAudio.cue(actor().motor,&"focus_start");_timer+=def.beam_tick
					if _beam_elapsed>=def.beam_duration-1e-9:_end_beam(true)
		&"singularity":
			actor().motor.request_ability_velocity(Vector2.ZERO)
			actor().jump_ability.cancel_requests()
			attract(delta)
			if age>=def.hold_seconds:
				damage_burst(_center,def.blast_radius*(def.skill_multiplier if _skill else 1),_skill)
				actor().motor.cancel_ability_motion()
				flash(direction,base_displacement()*(def.skill_multiplier if _skill else 1)/actor().motor.tuning.shot_burst_duration,actor().motor.tuning.shot_burst_duration);_pose(&"weapon_skill");_phase(&"idle")
	queue_redraw()
func _end_beam(final_step: bool) -> void:
	_beam_require_release=actor().router.aim_engaged
	if final_step:actor().motor.finish_weapon_drive()
	else:actor().motor.stop_weapon_drive()
	pose_remaining=0;_phase(&"idle")
func context() -> bool:
	for item: WeaponEntity in current_entities():
		if item.kind==&"boomerang":return item.recall()
		if item.kind==&"mine" and item.phase==&"attached":explode(item);return true
	return false
func steer_direction(item: WeaponEntity, fallback: Vector2) -> Vector2:
	if actor().traversal.busy() or actor().motor.is_on_floor():return fallback
	if actor().router.current_device==&"keyboard_mouse":
		var world_mouse := item.get_canvas_transform().affine_inverse()*get_viewport().get_mouse_position()
		var value := world_mouse-item.global_position
		return value.normalized() if actor().router.aim_engaged and value.length()>12 else fallback
	var aim := actor().router.aim_direction
	return aim if actor().router.aim_engaged and not aim.is_zero_approx() else fallback
func hit(receiver: Damageable, packet: int, serial: int, stage: String, skill: bool, point: Vector2, unit: Vector2, amount: float = -1) -> bool:
	if not receiver.active or receiver.faction!=&"enemy":return false
	var damage := amount if amount>0 else _packet_damage
	var event := "%s:%s:weapon:%s:%s:%s" % [actor().motor.get_instance_id(),_session,packet,serial,stage]
	var target_id := receiver.actor_id if receiver.actor_id!=0 else receiver.get_instance_id()
	return receiver.receive_damage({"session_id":_session,"event_id":event,"source_actor_id":actor().motor.get_instance_id(),"source_faction":&"player","target_actor_id":receiver.actor_id,"target_epoch":receiver.damage_epoch,"amount":damage,"damage_type":&"weapon","skill_attack":skill,"hit_point":point,"hit_direction":unit,"on_committed":actor().on_weapon_damage.bind(_session,packet,serial,not actor().motor.is_on_floor(),target_id,skill,receiver,ability.weapon_epoch)})
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
	blast_fired.emit(point)
func explode(item: WeaponEntity) -> void:
	if not item.valid_owner():return
	var def := definition();_packet=item.packet;_skill=item.skill
	var radius: float = def.blast_radius*(def.skill_multiplier if item.skill else 1.0)
	damage_burst(item.global_position,radius,item.skill)
	var offset := actor().motor.global_position-item.global_position
	if offset.length()<=radius and clear_line(item.global_position,actor().motor.global_position):
		if item.kind==&"bomb":base_recoil()
		else:flash(offset.normalized() if not offset.is_zero_approx() else Vector2.UP,base_displacement()*(def.skill_multiplier if item.skill else 1)/actor().motor.tuning.shot_burst_duration,actor().motor.tuning.shot_burst_duration)
	_pose(&"weapon_skill" if item.skill else &"bomb_place")
	item.dispose();_phase(&"idle");GameAudio.cue(actor().motor,&"impact")
func caught(item: WeaponEntity, unit: Vector2) -> void:
	if not item.valid_owner() or item.phase not in [&"returning",&"auto_return"]:return
	if item.manual_recall and not unit.is_zero_approx():
		var distance: float = base_displacement()*actor().motor.weapon_motion.secondary_ratio*(definition().skill_multiplier if item.skill else 1)
		flash(unit,distance/actor().motor.tuning.shot_burst_duration,actor().motor.tuning.shot_burst_duration)
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
func beam_visual_segment() -> PackedVector2Array:
	# Damage uses the accepted physics ray. Presentation follows the current
	# visible barrel after Motor movement; it never changes receipts or motion.
	if phase!=&"beam" or not valid_session(_session) or _beam_start.is_equal_approx(_beam_point):return PackedVector2Array()
	var start := (actor().motor.get_node("CourierVisual") as CourierVisual).visible_muzzle_position()
	var offset := _beam_point-start
	if offset.dot(direction)<=0:return PackedVector2Array()
	return PackedVector2Array([start,start+offset.limit_length(definition().range_limit)])
func _draw() -> void:
	var underworld := UnderworldProjectileVisual.enabled(self)
	var beam := beam_visual_segment()
	if beam.size()==2:
		draw_line(to_local(beam[0]),to_local(beam[1]),Color(.67,.52,.29,.4) if underworld else Color(.15,.55,.8,.4),8,not underworld)
		draw_line(to_local(beam[0]),to_local(beam[1]),Color("f3dda0") if underworld else Color(.65,.95,1),2,not underworld)
	for fx: Dictionary in _fx:
		var duration := fx_duration(fx)
		var alpha := 1-float(fx.age)/duration
		if fx.kind=="blink":
			var start := to_local(fx.start);var end := to_local(fx.end)
			draw_line(start,end,Color(.67,.52,.29,alpha*.45) if underworld else Color(.35,.65,1,alpha*.45),3,not underworld)
			for position: Vector2 in [fx.start,fx.end]:
				var transform: Transform2D=fx.transform
				transform.origin+=position-fx.start
				draw_set_transform_matrix(global_transform.affine_inverse()*transform)
				draw_texture(fx.texture,Vector2.ZERO,Color(.82,.76,.52,alpha*.65) if underworld else Color(.65,.8,1,alpha*.65))
				draw_set_transform_matrix(Transform2D.IDENTITY)
			for i: int in 8:
				var angle := float(i)*TAU/8
				var offset := Vector2.from_angle(angle)*(8+float(fx.age)*100)
				draw_line(end+offset,end+offset+Vector2.from_angle(angle)*7,Color(.95,.86,.63,alpha) if underworld else Color(.7,.85,1,alpha),1.5,not underworld)
		elif fx.kind=="blast":
			_draw_blast(fx,alpha)
		elif fx.kind in ["beam","arc"]:
			var color := Color(.95,.86,.63,alpha) if underworld else Color(.35,.86,1,alpha)
			draw_line(to_local(fx.start),to_local(fx.end),Color(.67,.52,.29,alpha*.4) if underworld else Color(.2,.5,.8,alpha*.4),14 if fx.skill else 6,true)
			draw_line(to_local(fx.start),to_local(fx.end),color,5 if fx.skill else 2,true)
		else:
			var progress := float(fx.age)/duration
			draw_arc(to_local(fx.start),float(fx.radius)*(.2+.8*progress),0,TAU,64,(Color(.57,.58,.43,alpha) if underworld else Color(.45,.65,.8,alpha)) if fx.kind=="fizzle" else Color(1,.65,.25,alpha),4,true)
	if phase==&"singularity":
		var center := to_local(_center);var progress := clampf(age/definition().hold_seconds,0,1)
		draw_circle(center,24,Color(.22,.35,.27,.4) if underworld else Color(.3,.1,.5,.4))
		for i: int in 4:draw_arc(center,12+i*10,age*7+i,age*7+i+PI*1.3,24,Color(.62,.71,.49,.7) if underworld else Color(.6,.5,1,.7),2,not underworld)
		draw_arc(center,definition().attract_radius,0,TAU*progress,64,Color(.62,.71,.49,.2) if underworld else Color(.6,.55,1,.2),1,not underworld)
		draw_line(center,center+direction*60,Color(1,.85,.45),2,not underworld)
		draw_circle(center+direction*60,4,Color(1,.85,.45))
	elif phase==&"fan_wait" and age>.13:
		var center := to_local(actor().motor.global_position)
		var progress := clampf((age-.13)/maxf(.01,definition().second_flash_delay-.13),0,1)
		draw_arc(center,23,0,TAU*progress,32,Color(.83,.72,.45,.6) if underworld else Color(.45,.8,1,.6),1.5,not underworld)
		draw_line(center,center-direction*32,Color(.95,.86,.63,.65) if underworld else Color(.6,.85,1,.65),1,not underworld)
	elif phase==&"charge":
		draw_arc(to_local(actor().motor.global_position),25,0,TAU*minf(1,age/definition().skill_charge),32,Color("f3dda0") if underworld else Color(.3,.9,1),3,not underworld)

func _draw_blast(fx: Dictionary, alpha: float) -> void:
	var underworld := UnderworldProjectileVisual.enabled(self)
	var center := to_local(fx.start)
	var age_value: float=fx.age
	var radius: float=fx.radius
	var flare := clampf(age_value/.13,0,1)
	var hot := maxf(0,1-age_value/.16)
	# Readable core -> irregular flame petals -> shock front -> rising smoke.
	for i: int in 9:
		var angle := float(i)*TAU/9
		var unit := Vector2.from_angle(angle)
		var r := radius*(.22+.20*sin(float(i)*5))*(.25+.75*flare)
		var points := PackedVector2Array([center+unit*6,center+unit*r+unit.orthogonal()*r*.22,center+unit*r*1.5,center+unit*r-unit.orthogonal()*r*.22])
		draw_colored_polygon(points,Color(1,.22+.13*float(i%3),.06,alpha*.7))
		draw_circle(center+unit*r*.55,r*.28,Color(1,.68,.16,alpha*.6))
	if hot>0:
		draw_circle(center,radius*.20*(.7+.3*flare),Color(1,.87,.5,hot))
		draw_circle(center,radius*.09,Color(1,.98,.88,hot))
	var wave := radius*(1-pow(1-clampf(age_value/.28,0,1),3))
	draw_arc(center,wave,0,TAU,64,Color(1,.8,.45,maxf(0,1-age_value/.32)),3.5,true)
	for i: int in 18:
		var unit := Vector2.from_angle(float(i)*TAU/18+.17*sin(float(i)))
		var point := center+unit*radius*(.2+age_value*(1.1+.2*sin(float(i)*7)))+Vector2.DOWN*age_value*age_value*90
		draw_line(point-unit*8*alpha,point,Color(1,.8,.3,alpha),1.5,not underworld)
	if age_value>.08:
		for i: int in 7:
			var unit := Vector2.from_angle(float(i)*TAU/7)
			var point := center+unit*radius*(.12+age_value*.3)+Vector2.UP*age_value*36
			draw_circle(point,radius*(.07+age_value*.12),Color(.25,.23,.27,alpha*.35))
