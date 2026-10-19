extends RefCounted
## Ground-route combat pilot only; every action goes through the real Router.
## It neither edits a route nor drives NPCs, health, resources or Player motion.
const GROUND_BEHAVIORS := [&"forest_bark_beetle",&"forest_seed_sentry",&"forest_thread_spider",&"charger"]
var target: EnemyActor
var target_id := ""
var origin := Vector2.ZERO
var origin_support := ""
var saved_leg := -1
var saved_phase := ""
var started := -1
var state := ""
var last_shot := -1000
var shots := 0
var intent_requests := 0
var flight_started := -1
var air_shots := 0
var return_stable := 0
var last_drop := -1000
var saved_actor_epoch := -1
var firing_bank := Vector2.ZERO
var firing_support := ""
var flank_side := 0.0
var flank_crossed := false

func drive(trace: Node,leg: Dictionary) -> bool:
	if trace.manifest.get("layout_version","") not in ["forest-expedition-airborne-v11","forest-woven-trunk-v12","forest-interwoven-canopy-v13"]:return false
	if state.is_empty():
		if not _ordinary_ground(trace,leg):return false
		var destination: Vector2=_destination(trace,leg)
		var direction: float=signf(destination.x-trace.player.global_position.x)
		if direction==0:return false
		for index: int in trace.stage.enemy_manifest.size():
			var row: Dictionary=trace.stage.enemy_manifest[index]
			var actor: EnemyActor=trace.stage.enemies[index].get_node("Actor")
			if actor.health.terminal or actor.definition.aerial or actor.definition.behavior_id not in GROUND_BEHAVIORS:continue
			var delta: Vector2=actor.motor.global_position-trace.player.global_position
			if absf(delta.y)>45 or delta.x*direction<=0 or absf(delta.x)>150:continue
			if (actor.motor.global_position.x-destination.x)*direction>25:continue
			if not _clear(trace,actor):continue
			for id: String in trace.supports():
				if trace.full_support(id):origin_support=id;break
			if origin_support.is_empty():return false
			target=actor;target_id=str(row.id);origin=trace.player.global_position
			saved_leg=int(trace.leg_index);saved_phase=str(trace.phase);started=int(trace.tick)
			saved_actor_epoch=int(trace.app.lifetime.actor_epoch)
			shots=0;intent_requests=0;air_shots=0;flight_started=-1;return_stable=0;state="fight"
			trace.controller.router.set_move_axis(0)
			trace.event("forest_encounter_start",_data(trace))
			break
		if state.is_empty():return false
	if trace.controller.actor_resources.health.terminal:
		trace.fail("forest_encounter_player_death/"+target_id);return true
	if int(trace.app.lifetime.actor_epoch)!=saved_actor_epoch:
		trace.fail("forest_encounter_actor_respawn/"+target_id);return true
	if int(trace.leg_index)!=saved_leg or str(trace.phase)!=saved_phase:
		trace.fail("forest_encounter_route_changed/"+target_id);return true
	if int(trace.tick)-started>600:
		trace.fail("forest_encounter_bounded_return/"+target_id);return true
	if not is_instance_valid(target):
		trace.fail("forest_encounter_target_unloaded/"+target_id);return true
	if state!="return" and target.health.terminal:
		state="return";trace.jump(false)
		trace.event("forest_encounter_terminal",_data(trace))
	if state=="return":
		_return(trace)
		return true
	var position: Vector2=trace.player.global_position
	if _recover_origin_layer(trace):return true
	var offset: Vector2=target.motor.global_position-position
	var bark: bool=target.definition.behavior_id==&"forest_bark_beetle"
	var front: bool=bark and offset.normalized().dot(Vector2(target.brain.direction,0)) < -cos(deg_to_rad((target.definition as ForestEnemyDefinition).bark_shield_half_angle_degrees))
	var side: float=signf(target.motor.global_position.x-origin.x)
	if side==0:side=1
	var bank: float=target.motor.global_position.x-side*94.0 if bark else origin.x
	if state.begins_with("flank_"):
		_drive_flank(trace)
		return true
	if bark and front and trace.player.is_on_floor() and _unsafe_top_shot(trace,Vector2(bank,position.y)):
		flank_side=side;flank_crossed=false;state="flank_approach"
		trace.event("forest_encounter_flank_choice",_data(trace))
		_drive_flank(trace)
		return true
	if not front and trace.player.is_on_floor() and not _ground_bank_safe(trace,origin,target.motor.global_position):
		flank_side=side;state="flank_set_bank"
		trace.event("forest_encounter_safe_ground_bank_choice",_data(trace))
		_drive_flank(trace)
		return true
	if trace.player.is_on_floor():
		air_shots=0;flight_started=-1
		if bark and front:
			trace.controller.router.set_move_axis(clampf((bank-position.x)/12.0,-1,1))
			if absf(offset.x)<=98 and trace.player.recoil_burst_remaining<=0:
				trace.controller.router.set_move_axis(0)
				trace.jump(true)
				flight_started=int(trace.tick);state="jump"
				trace.event("forest_encounter_jump",_data(trace))
			return true
		trace.controller.router.set_move_axis(clampf((origin.x-position.x)/12.0,-1,1))
		if absf(origin.x-position.x)<=6 and trace.at_destination(origin,origin_support) and _ground_bank_safe(trace,origin,target.motor.global_position) and _ready_shot(trace) and _clear(trace,target):_ground_shot(trace,offset.normalized())
	else:
		# A ground shot can lift the body slightly. It is not an airborne
		# combat-jump program: return to the real ground bank before firing again.
		var air_bank_x: float=bank if flight_started>=0 else origin.x
		trace.controller.router.set_move_axis(clampf((air_bank_x-position.x)/16.0,-1,1))
		if flight_started>=0 and trace.player.normal_velocity.y>=0:
			trace.jump(false)
		# The actual incoming direction, not a nominal "above" tag, must clear
		# the shield. At most two requests in this airborne period, even on hit.
		if flight_started>=0 and not front and air_shots<2 and _ready_shot(trace) and _clear(trace,target):
			_shoot(trace,offset.normalized());air_shots+=1
	return true


func _unsafe_top_shot(trace: Node,bank: Vector2) -> bool:
	var half: Vector2=(trace.player.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect().size*.5
	var d: ForestEnemyDefinition=target.definition as ForestEnemyDefinition
	var angle: float=deg_to_rad(d.bark_shield_half_angle_degrees)
	var rise: float=absf(target.motor.global_position.x-bank.x)*tan(angle)+maxf(0,bank.y-target.motor.global_position.y)
	var distance: float=trace.player.weapon_motion.base_distance(trace.player.tuning,false)
	# Two actual airborne impulses can move sideways as well as upwards. The
	# expanded swept envelope includes both firing sides and the full body.
	var retreat: float=2*distance*cos(angle)
	var height: float=rise+2*distance+half.y
	var sweep:=Rect2(Vector2(bank.x-retreat-half.x,bank.y-height),Vector2(2*(retreat+half.x),height-half.y))
	for raw: Array in trace.manifest.dangers:
		if Rect2(raw[0],raw[1],raw[2],raw[3]).intersects(sweep):return true
	# A one-way branch is passable upward but can catch the body after recoil;
	# solid branches may also obstruct the elevated incoming projectile angle.
	for row: Dictionary in trace.manifest.platforms:
		var r: Array=row.rect
		if float(r[1])<bank.y-half.y and Rect2(r[0],r[1],r[2],r[3]).intersects(sweep):return true
	return false

func _floor_envelope(trace: Node) -> Rect2:
	var support: Dictionary=trace.platform(origin_support)
	if support.is_empty():return Rect2()
	var root:=Rect2(support.rect[0],support.rect[1],support.rect[2],support.rect[3])
	var body: StaticBody2D=trace.stage.assembler.support_bodies.get(origin_support)
	if is_instance_valid(body):
		var physical: Variant=body.get_meta("support_world_rect",null)
		if physical is Rect2 and origin_support in body.get_meta("support_ids",[]) and absf(physical.position.y-root.position.y)<.001:root=physical
	return root

func _ground_bank_safe(trace: Node,bank: Vector2,enemy: Vector2) -> bool:
	var half: Vector2=(trace.player.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect().size*.5
	var root: Rect2=_floor_envelope(trace)
	var end_x: float=bank.x-(enemy-bank).normalized().x*trace.player.weapon_motion.base_distance(trace.player.tuning,true)
	return root.has_area() and absf(bank.y+half.y-root.position.y)<2 and minf(bank.x,end_x)-half.x>=root.position.x and maxf(bank.x,end_x)+half.x<=root.end.x

func _recover_origin_layer(trace: Node) -> bool:
	var pos: Vector2=trace.player.global_position
	if trace.player.is_on_floor() and pos.y<origin.y-20:
		var one_way:=false
		var full_one_way:=false
		for id: String in trace.supports():
			if bool(trace.platform(id).get("one_way",false)):
				one_way=true
				full_one_way=full_one_way or trace.full_support(id)
		if not one_way:
			trace.fail("forest_encounter_upper_solid_recovery_blocked/"+target_id);return true
		# During a live crossing the receiving bank remains the goal. Returning
		# to route origin here would endlessly restart the same jump.
		var keep_far_bank: bool=state in ["flank_jump","flank_drop_to_bank"]
		state="flank_drop_to_bank" if keep_far_bank else "drop_to_origin"
		trace.jump(false)
		var goal_x: float=origin.x
		if keep_far_bank:
			var half: Vector2=(trace.player.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect().size*.5
			goal_x=target.motor.global_position.x+flank_side*(half.x+target.definition.collision_size.x*.5+24)
		trace.controller.router.set_move_axis(clampf((goal_x-pos.x)/12,-1,1))
		# A partial edge already releases by walking off. Do not inject a
		# downward impulse that unnecessarily cuts the remaining crossing time.
		if keep_far_bank and not full_one_way:return true
		if int(trace.tick)-last_drop>=20:
			_submit(trace,&"drop_through");last_drop=int(trace.tick)
			trace.event("forest_encounter_actual_upper_drop",_data(trace))
		return true
	if state=="drop_to_origin":
		trace.controller.router.set_move_axis(clampf((origin.x-pos.x)/12,-1,1))
		if trace.player.is_on_floor():
			if absf(pos.y-origin.y)>2:trace.fail("forest_encounter_wrong_recovery_level/"+target_id);return true
			state="fight";return false
		return true
	return false

func _drive_flank(trace: Node) -> void:
	var pos: Vector2=trace.player.global_position
	var enemy: Vector2=target.motor.global_position
	var half: Vector2=(trace.player.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect().size*.5
	var body_gap: float=half.x+target.definition.collision_size.x*.5
	var root: Rect2=_floor_envelope(trace)
	if not root.has_area():trace.fail("forest_encounter_flank_support_missing/"+target_id);return
	var incoming: Vector2=(enemy-pos).normalized()
	var guarded: bool=target.definition.behavior_id==&"forest_bark_beetle" and incoming.dot(Vector2(target.brain.direction,0)) < -cos(deg_to_rad((target.definition as ForestEnemyDefinition).bark_shield_half_angle_degrees))
	if state in ["flank_fire","flank_set_bank"] and guarded:
		state="fight";trace.controller.router.set_move_axis(0)
		trace.event("forest_encounter_shield_turn_reselect",_data(trace));return
	if state=="flank_set_bank":
		var bank:=Vector2(enemy.x-signf(enemy.x-pos.x)*(body_gap+24),origin.y)
		if not _ground_bank_safe(trace,bank,enemy):
			# A narrow near shore cannot absorb a ground recoil. Reuse the real
			# no-shot crossing only if its far shore owns a full firing envelope.
			var far_bank:=Vector2(enemy.x+flank_side*(body_gap+24),origin.y)
			if not _ground_bank_safe(trace,far_bank,enemy):trace.fail("forest_encounter_no_safe_ground_bank/"+target_id);return
			state="flank_approach";flank_crossed=false
			trace.event("forest_encounter_far_ground_bank_choice",_data(trace));return
		trace.controller.router.set_move_axis(clampf((bank.x-pos.x)/12,-1,1))
		if absf(bank.x-pos.x)<7:
			firing_support=""
			for id: String in trace.supports():
				if trace.full_support(id):firing_support=id;break
			if not firing_support.is_empty() and _ground_bank_safe(trace,pos,enemy):
				firing_bank=pos;state="flank_fire"
				trace.event("forest_encounter_flank_bank",_data(trace).merged({"firing_bank":trace.pair(firing_bank),"firing_support":firing_support}))
	elif state=="flank_approach":
		var departure_x: float=enemy.x-flank_side*94.0
		var receiver_x: float=enemy.x+flank_side*(body_gap+24)
		var recoil: float=trace.player.weapon_motion.base_distance(trace.player.tuning,true)
		var firing_end: float=receiver_x+flank_side*recoil
		if minf(receiver_x,firing_end)-half.x<root.position.x or maxf(receiver_x,firing_end)+half.x>root.end.x:
			trace.fail("forest_encounter_no_full_flank_bank/"+target_id);return
		trace.controller.router.set_move_axis(clampf((departure_x-pos.x)/12,-1,1))
		if absf(enemy.x-pos.x)<=98 and trace.player.recoil_burst_remaining<=0:
			trace.jump(true);flight_started=int(trace.tick);state="flank_jump"
			trace.event("forest_encounter_flank_jump",_data(trace))
	elif state in ["flank_jump","flank_drop_to_bank"]:
		# Remain held through the real ascent, rather than cutting it at 0.13s.
		# No shot during this jump: a downward recoil would enter the ceiling.
		var receiver_x: float=enemy.x+flank_side*(body_gap+24)
		trace.controller.router.set_move_axis(clampf((receiver_x-pos.x)/12,-1,1))
		if not flank_crossed and (pos.x-enemy.x)*flank_side>body_gap+8 and pos.y+half.y<enemy.y-target.definition.collision_size.y*.5-1:
			flank_crossed=true
			trace.event("forest_encounter_flank_crossed",_data(trace))
		if trace.player.normal_velocity.y>=0:trace.jump(false)
		if trace.player.is_on_floor() and int(trace.tick)>flight_started+1:
			firing_support=""
			for id: String in trace.supports():
				if trace.full_support(id):firing_support=id;break
			if not flank_crossed or firing_support.is_empty() or not _ground_bank_safe(trace,pos,enemy):
				trace.fail("forest_encounter_flank_landing_failed/"+target_id);return
			firing_bank=pos;state="flank_fire"
			trace.event("forest_encounter_flank_bank",_data(trace).merged({"firing_bank":trace.pair(firing_bank),"firing_support":firing_support}))
	elif state=="flank_fire":
		if not _ground_bank_safe(trace,firing_bank,enemy):
			state="fight";trace.controller.router.set_move_axis(0);return
		trace.controller.router.set_move_axis(clampf((firing_bank.x-pos.x)/12,-1,1))
		if trace.at_destination(firing_bank,firing_support) and _ready_shot(trace) and _clear(trace,target):
			_ground_shot(trace,(enemy-pos).normalized())

func _ordinary_ground(trace: Node,leg: Dictionary) -> bool:
	var kind: String=str(leg.get("kind",""))
	if kind not in ["walk","drop","drop_through","jump_gap","jump_rise","jump_rise_through_gap"]:return false
	return trace.player.is_on_floor() and (str(trace.phase)=="align" or kind in ["walk","drop","drop_through"])

func _destination(trace: Node,leg: Dictionary) -> Vector2:
	if str(leg.kind) in ["drop","drop_through"]:
		var path: Array=leg.get("path",[])
		var cursor: int=int(trace.drop_cursor)
		if cursor<path.size():return trace.point(path[cursor])
	if str(leg.kind).begins_with("jump_") and leg.has("takeoff"):return trace.point(leg.takeoff)
	return trace.point(leg.landing)

func _clear(trace: Node,actor: EnemyActor) -> bool:
	var query: PhysicsRayQueryParameters2D=PhysicsRayQueryParameters2D.create(trace.player.global_position,actor.motor.global_position,1,[trace.player.get_rid(),actor.motor.get_rid()])
	return trace.player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _ready_shot(trace: Node) -> bool:
	return trace.controller.shoot_ability.cooldown_remaining<=0 and trace.controller.shoot_ability.rounds_remaining==0 and trace.player.recoil_burst_remaining<=0 and trace.controller.actor_resources.stamina.current>=trace.controller.shot_energy.shot_energy_cost and (trace.player.is_on_floor() or trace.controller.action_resources.shot_charges>0)

func _shot_aim(trace: Node,requested: Vector2) -> Vector2:
	var offset: Vector2=target.motor.global_position-trace.player.global_position
	if trace.player.is_on_floor() and not is_zero_approx(offset.x):
		var cardinal:=Vector2(signf(offset.x),0)
		if _direction_hits_body(trace,cardinal):return cardinal
	# Request a genuine normalization fixed point, since both Router and
	# ShootAbility normalize. Never rewrite their resulting recorded packets.
	var unit: Vector2=requested
	for attempt: int in 12:
		var normalized: Vector2=unit.normalized()
		if normalized==unit:
			return unit if _direction_hits_body(trace,unit) else Vector2.ZERO
		unit=normalized
	return Vector2.ZERO

func _direction_hits_body(trace: Node,unit: Vector2) -> bool:
	if not unit.is_finite() or unit.is_zero_approx():return false
	var position: Vector2=trace.player.global_position
	var distance: float=(target.motor.global_position-position).dot(unit)
	if distance<=0:return false
	var closest: Vector2=position+unit*distance
	var half: Vector2=target.definition.collision_size*.5
	var inner:=Rect2(target.motor.global_position-half,half*2).grow(-trace.player.tuning.projectile_radius)
	if not inner.has_point(closest):return false
	var ray:=PhysicsRayQueryParameters2D.create(position,closest,5,[trace.player.get_rid()])
	var hit: Dictionary=trace.player.get_world_2d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.get("collider")==target.motor

func _ground_shot(trace: Node,requested: Vector2) -> void:
	var final_aim: Vector2=_shot_aim(trace,requested)
	if not final_aim.is_zero_approx() and not _ground_bank_safe(trace,trace.player.global_position,trace.player.global_position+final_aim):
		# Keep the caller's existing bank-return movement. Near-origin position
		# tolerance alone does not prove a complete real recoil fits yet.
		return
	_shoot(trace,final_aim,true)

func _shoot(trace: Node,aim: Vector2,final_aim_already_selected: bool=false) -> void:
	var stable: Vector2=aim if final_aim_already_selected else _shot_aim(trace,aim)
	if stable.is_zero_approx():trace.fail("forest_encounter_no_stable_body_aim/"+target_id);return
	aim=stable
	if trace.player.is_on_floor() and not _ground_bank_safe(trace,trace.player.global_position,trace.player.global_position+aim):
		trace.fail("forest_encounter_actual_shot_bank_unsafe/"+target_id);return
	if target.definition.behavior_id==&"forest_bark_beetle":
		var shield: ForestEnemyDefinition=target.definition as ForestEnemyDefinition
		if aim.dot(Vector2(target.brain.direction,0)) < -cos(deg_to_rad(shield.bark_shield_half_angle_degrees)):return
	if shots>=12:
		trace.fail("forest_encounter_shot_budget/"+target_id);return
	shots+=1;last_shot=int(trace.tick)
	trace.event("forest_encounter_shot",_data(trace).merged({"aim":trace.pair(aim),"request_index":shots,"grounded":trace.player.is_on_floor(),"shots_remaining":trace.controller.action_resources.shot_charges}))
	_submit(trace,&"shoot_release",aim)

func _submit(trace: Node,kind: StringName,aim:=Vector2.ZERO) -> void:
	if intent_requests>=12:
		trace.fail("forest_encounter_action_budget/"+target_id);return
	intent_requests+=1
	trace.request(kind,aim)

func _return(trace: Node) -> void:
	var position: Vector2=trace.player.global_position
	trace.controller.router.set_move_axis(clampf((origin.x-position.x)/12.0,-1,1))
	if trace.player.is_on_floor() and position.y<origin.y-20 and int(trace.tick)-last_drop>=20:
		var one_way: bool=false
		for id: String in trace.supports():
			var row: Dictionary=trace.platform(id)
			if not row.is_empty() and bool(row.get("one_way",false)):one_way=true
		if one_way:_submit(trace,&"drop_through");last_drop=int(trace.tick)
		else:trace.fail("forest_encounter_return_upper_solid/"+target_id);return
	return_stable=return_stable+1 if trace.at_destination(origin,origin_support) and trace.player.recoil_burst_remaining<=0 else 0
	if return_stable>=12:
		trace.controller.router.set_move_axis(0);trace.jump(false)
		trace.event("forest_encounter_return",_data(trace).merged({"support":origin_support,"full_foot_frames":return_stable}))
		state="";target=null;target_id="";origin_support=""

func _data(trace: Node) -> Dictionary:
	return {"enemy_id":target_id,"enemy_hp":target.health.current if is_instance_valid(target) else -1,"enemy_position":trace.pair(target.motor.global_position) if is_instance_valid(target) else [],"snapshot":trace.snapshot(),"origin":trace.pair(origin),"saved_leg":saved_leg,"saved_phase":saved_phase,"pilot_state":state,"action_requests":intent_requests,"shot_requests":shots}
