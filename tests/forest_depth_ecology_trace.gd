extends "res://tests/forest_depth_region_trace.gd"
## Actual DemoApp/shared Manifest route, with an authored crown encounter choice.
## No room copy, transforms, resources, ability grants or enemy phase writes.
var ecology_enabled := true
var ecology_state := "start"
var ecology_primary: EnemyActor
var ecology_lantern: EnemyActor
var ecology_contact := false
var ecology_R := false
var ecology_jump := false
var ecology_preview := false
var ecology_damage_start := 0.0
var ecology_trigger_x := 0.0
var ecology_shot_tick := -1000
var ecology_target_id := ""
var ecology_bank_x := 0.0
var ecology_jump_clear_x := 0.0
var ecology_seed_zones_seen: Dictionary = {}
var ecology_rejected_goal := Vector2(INF,INF)
func request(kind: StringName, aim:=Vector2.ZERO) -> void:
	# Base owns request timing, pre-Motor state and movie stamps. Augment only
	# its actual new row with the Router's canonical single queued direction.
	var previous_sequence: int=controller.router.sequence
	var previous_count: int=controller.router._queue.size()
	var previous_rows: int=requests.size()
	super.request(kind,aim)
	if requests.size()!=previous_rows+1:
		fail("actual_base_request_not_single_append");return
	var row: Dictionary=requests.back()
	row.raw_aim=pair(aim)
	if bool(row.queued):
		if controller.router._queue.size()!=previous_count+1 or controller.router.sequence!=previous_sequence+1:
			fail("actual_router_submission_not_single_append");return
		var actual: Dictionary=controller.router._queue.back()
		if actual.sequence!=controller.router.sequence or actual.type!=kind or actual.epoch!=controller.router.epoch:
			fail("actual_router_submission_identity_mismatch");return
		row.merge({"aim":pair(actual.direction),"router_sequence":actual.sequence,"router_epoch":actual.epoch,"observation":"actual_router_queued_direction"},true)
func _hook_event(state: StringName) -> void:
	super._hook_event(state)
	if ecology_started<0: return
	if state==&"hook_miss":
		var collisions: Array=[]
		for index: int in player.get_slide_collision_count():
			var collision := player.get_slide_collision(index)
			var collider := collision.get_collider() as Node
			collisions.append({"path":str(collider.get_path()) if is_instance_valid(collider) else "","normal":pair(collision.get_normal()),"position":pair(collision.get_position())})
		event("ecology_actual_hook_miss_collisions",{"collisions":collisions,"snapshot":snapshot()})
	var target := controller.traversal.hook_target
	if state==&"hook_contact_kick":
		if ecology_strategy=="live_H" and is_instance_valid(ecology_lantern) and target==ecology_lantern.motor:
			ecology_contact=true
			event("ecology_actual_live_arrival",{"enemy_id":"hollow_route__canopy_lantern","target_position":pair(target.global_position)})
func observe() -> void:
	if not initialized:return
	super.observe()
	if ecology_strategy.begins_with("crossbranch_") and not frames.is_empty() and is_instance_valid(crossbranch_actor):
		var camera: Camera2D=app._run_camera
		var inverse:=get_viewport().get_canvas_transform().affine_inverse()
		var top: Vector2=inverse*Vector2.ZERO
		var bottom: Vector2=inverse*get_viewport().get_visible_rect().size
		var view:=Rect2(top,bottom-top)
		var sample: Dictionary={"tick":tick,"view":[view.position.x,view.position.y,view.size.x,view.size.y],"zoom":pair(camera.zoom),"npc_visible":view.has_point(crossbranch_actor.motor.global_position),"near_reward_edge_visible":view.has_point(Vector2(-320,268)),"NPC":crossbranch_actor.attack_behavior.call("depth_snapshot"),"wallet":app.wallet.balance,"claims":stage.region_state.claimed.keys(),"items":app.build.inventory.item_ids(),"combat_hit_packets":controller.combat_energy._packets.duplicate(true)}
		frames[-1].crossbranch=sample
		frames[-1].crossbranch.physics_frame=Engine.get_physics_frames()
		crossbranch_camera.append(sample)
	if ecology_started<0 or not is_instance_valid(ecology_primary): return
	var behavior := ecology_primary.attack_behavior
	if not behavior is ForestSeedSentryBehavior: return
	var seeds: Array=[]
	for projectile: EnemyAttackProjectile in behavior._projectiles:
		if not is_instance_valid(projectile) or not projectile is ForestSeedProjectile: continue
		var seed := projectile as ForestSeedProjectile
		seeds.append({"event_id":String(seed.event_id),"position":pair(seed.global_position),"goal":pair(seed.goal),"landed":seed.landed,"spent":seed.spent,"age":seed.age})
		if seed.landed and not seed.spent and not ecology_seed_zones_seen.has(seed.event_id):
			ecology_seed_zones_seen[seed.event_id]=true
			event("ecology_actual_seed_zone",{"event_id":String(seed.event_id),"goal":pair(seed.goal),"source":ecology_target_id})
	if not frames.is_empty() and int(frames[-1].tick)==tick: frames[-1].ecology_projectiles=seeds
var formal_crown_jump := false
var formal_crown_jump_released := false
func drive_walk(destination: Vector2) -> void:
	if crossbranch_formal and leg_index<itinerary.size() and str(itinerary[leg_index].get("edge_id",""))=="cavity_prep":
		var thread: EnemyActor
		for i: int in stage.enemy_manifest.size():
			if stage.enemy_manifest[i].id=="hollow_route__inner_thread":thread=stage.enemies[i].get_node("Actor") as EnemyActor
		if not formal_crown_jump and is_instance_valid(thread) and not thread.health.terminal and player.is_on_floor():
			var ahead: float=thread.motor.global_position.x-player.global_position.x
			if ahead>0 and ahead<=100:
				formal_crown_jump=true
				event("formal_actual_C_thread_jump",{"enemy_id":"hollow_route__inner_thread","enemy_position":pair(thread.motor.global_position),"enemy_body":pair(thread.definition.collision_size),"depth_state":thread.attack_behavior.call("depth_snapshot"),"snapshot":snapshot(),"readable_ground_approach_distance":ahead})
				jump(true)
		if formal_crown_jump and not formal_crown_jump_released and not player.is_on_floor() and player.normal_velocity.y>=0:
			formal_crown_jump_released=true
			event("formal_actual_C_thread_apex_release",{"snapshot":snapshot(),"normal_velocity":pair(player.normal_velocity)})
			jump(false)
		super.drive_walk(destination)
		return
	if not ecology_enabled or leg_index>=itinerary.size() or str(itinerary[leg_index].get("edge_id",""))!="crown_prep" or ecology_finished>=0:
		super.drive_walk(destination)
		return
	if ecology_started<0:
		ecology_started=tick
		ecology_entry=snapshot()
		ecology_damage_start=controller.actor_resources.health.current
		for i: int in stage.enemy_manifest.size():
			var row: Dictionary=stage.enemy_manifest[i]
			var actor: EnemyActor=stage.enemies[i].get_node("Actor")
			if row.id in ["hollow_route__canopy_lantern","hollow_route__outer_lift_lantern"]: ecology_lantern=actor
			if row.id in ["hollow_route__outer_watch","hollow_route__crown_thread"]:
				ecology_primary=actor
				ecology_target_id=str(row.id)
		if not is_instance_valid(ecology_primary) or not is_instance_valid(ecology_lantern): fail("actual_crown_pair_missing");return
		event("ecology_choice_started",{"strategy":ecology_strategy,"recipe":manifest.encounter_plan_contract.duplicate(true),"primary":ecology_target_id,"snapshot":ecology_entry.duplicate(true)})
		var crown: Dictionary=platform("hollow__outer_crown")
		var recoil: float=player.weapon_motion.base_distance(player.tuning,true)
		# The actual E stand is only 50px from the crown lip. Choose a
		# supported gun bank from the real rectangle and configured recoil,
		# rather than firing while the full recoil footprint leaves the ledge.
		ecology_bank_x=maxf(player.global_position.x,float(crown.rect[0])+12.0+recoil+7.0)
		event("ecology_gun_bank_geometry",{"x":ecology_bank_x,"recoil":recoil,"support":crown.duplicate(true)})
		set_phase("ecology_start")
	var E := point(manifest.areas.filter(func(a: Dictionary) -> bool:return a.id=="E")[0].position)
	if ecology_state=="start":
		controller.router.set_move_axis(0)
		if ecology_strategy=="live_H":
			var target := ecology_lantern.motor.global_position
			event("ecology_live_H_request",{"enemy_id":"hollow_route__canopy_lantern","target_position":pair(target),"snapshot":snapshot()})
			request(&"grapple",(target-player.global_position-Vector2(0,-6)).normalized())
			ecology_state="hook"
		elif ecology_strategy=="fixed_route_continue":
			# The common real route has ALREADY reached E through this fixed
			# ring. Continue that legitimate route; do not handicap it with a
			# second reverse hook toward the old window solely for a control.
			event("ecology_existing_fixed_route",{"anchor_id":"hollow__upper_window_ring"})
			ecology_state="advance"
		elif ecology_strategy=="shoot_clear": ecology_state="shoot"
		else:
			# Leave the real E45 protected stand to provoke a normal supported
			# target lock; retreat to E-20 after observing the actual preview.
			ecology_state="provoke"
		return
	if ecology_state=="hook":
		controller.router.set_move_axis(1)
		if ecology_contact and controller.traversal.state==&"free" and not player.is_on_floor() and not ecology_R:
			event("ecology_first_free_R",{"snapshot":snapshot(),"shot_cost":controller.shot_energy.shot_energy_cost,"hook_state":String(controller.traversal.state),"grounded":player.is_on_floor(),"target_position":pair(ecology_lantern.motor.global_position)})
			request(&"shoot_release",Vector2.LEFT)
			ecology_R=true
			ecology_state="advance"
		elif age>240: fail("actual_crown_H_did_not_arrive_and_free")
		return
	if ecology_state=="shoot":
		var target: EnemyActor=ecology_primary if not ecology_primary.health.terminal else ecology_lantern
		if target.health.terminal:
			event("ecology_actual_bullets_cleared_pair")
			ecology_state="advance"
			return
		controller.router.set_move_axis(clampf((ecology_bank_x-player.global_position.x)/12,-1,1))
		if player.is_on_floor() and full_support("hollow__outer_crown") and absf(player.global_position.x-ecology_bank_x)<7 and tick-ecology_shot_tick>=int(ceil(player.tuning.shot_cooldown*Engine.physics_ticks_per_second)):
			request(&"shoot_release",(target.motor.global_position-player.global_position).normalized())
			ecology_shot_tick=tick
		return
	if ecology_state=="provoke":
		var provoke_x := E.x+48
		if ecology_primary.attack_behavior is ForestSeedSentryBehavior:
			# The real landed zone cancels if its expanded rectangle contains
			# a protected point. Merely leaving the E45 center disk is not
			# enough: use the actual pulse width and Player body for a bank
			# beyond that cancellation halo, without changing either contract.
			provoke_x=E.x+ecology_primary.definition.protected_radius+ecology_primary.definition.pulse_size.x*.5+12
		controller.router.set_move_axis(clampf((provoke_x-player.global_position.x)/12,-1,1))
		var behavior := ecology_primary.attack_behavior
		if behavior.state==&"telegraph":
			if behavior is ForestSeedSentryBehavior:
				var bounds := Rect2(behavior.attack_goal-Vector2(ecology_primary.definition.pulse_size.x*.5,ecology_primary.definition.pulse_size.y),ecology_primary.definition.pulse_size)
				for protected_point: Vector2 in behavior.protected_points:
					if bounds.grow(ecology_primary.definition.protected_radius).has_point(protected_point):
						if ecology_rejected_goal!=behavior.attack_goal:
							ecology_rejected_goal=behavior.attack_goal
							event("ecology_preview_will_be_safely_cancelled",{"goal":pair(behavior.attack_goal),"protected_point":pair(protected_point)})
						return
			ecology_preview=true
			ecology_trigger_x=behavior.attack_goal.x
			if behavior is ForestThreadSpiderBehavior:
				var spider := behavior as ForestThreadSpiderBehavior
				ecology_trigger_x=(spider.line_start.x+spider.line_end.x)*.5
			event("ecology_actual_preview",{"source":ecology_target_id,"state":String(behavior.state),"target_x":ecology_trigger_x})
			ecology_state="stand" if ecology_strategy=="stand_danger" else "retreat"
		return
	if ecology_state=="stand":
		controller.router.set_move_axis(clampf((ecology_trigger_x-player.global_position.x)/12,-1,1))
		if controller.actor_resources.health.current<ecology_damage_start:
			event("ecology_actual_damage_observed",{"health":controller.actor_resources.health.current,"source_expected":ecology_target_id})
			ecology_state="retreat"
		return
	if ecology_state=="retreat":
		controller.router.set_move_axis(clampf((E.x-20-player.global_position.x)/12,-1,1))
		if player.is_on_floor() and absf(player.global_position.x-(E.x-20))<7:
			ecology_state="wait"
			event("ecology_actual_safe_bank",{"snapshot":snapshot()})
		return
	if ecology_state=="wait":
		controller.router.set_move_axis(0)
		var attack := ecology_primary.attack_behavior
		var safe := attack.state in [&"retract",&"recovery",&"idle"]
		if attack is ForestSeedSentryBehavior:
			for projectile: EnemyAttackProjectile in (attack as ForestSeedSentryBehavior)._projectiles:
				if is_instance_valid(projectile) and not projectile.spent: safe=false
		if safe and ecology_preview:
			event("ecology_actual_danger_finished",{"state":String(attack.state),"snapshot":snapshot()})
			ecology_state="advance"
		return
	if ecology_state=="advance":
		controller.router.set_move_axis(clampf((destination.x-player.global_position.x)/12,-1,1))
		if not ecology_jump and player.is_on_floor():
			for motor: EnemyMotor in stage.enemies:
				var actor: EnemyActor=motor.get_node("Actor")
				var delta := motor.global_position-player.global_position
				var approach := 12.0+actor.definition.collision_size.x*.5+player.tuning.ground_speed*player.tuning.jump_hold_duration
				if not actor.health.terminal and delta.x>0 and delta.x<approach and absf(delta.y)<18+actor.definition.collision_size.y*.5:
					jump(true);ecology_jump=true;ecology_jump_clear_x=motor.global_position.x+actor.definition.collision_size.x*.5+12.0;set_phase("ecology_body_jump");break
		if ecology_jump and player.global_position.x>ecology_jump_clear_x: jump(false)
		stable=stable+1 if at_destination(destination) else 0
		if stable>=12:
			ecology_finished=tick
			ecology_exit=snapshot()
			event("ecology_choice_finished",{"strategy":ecology_strategy,"snapshot":ecology_exit.duplicate(true),"actual_live_arrival":ecology_contact,"R_requested":ecology_R})
			complete_leg()


func drive_jump(leg: Dictionary) -> void:
	if ecology_strategy in ["west_clear","west_wait","west_jump"] and str(leg.get("edge_id",""))=="west_to_belly" and ecology_finished<0:
		_drive_west_jump(leg);return
	if ecology_strategy not in ["entry_clear","entry_wait","entry_hold"] or str(leg.get("edge_id",""))!="belly_borer_access" or str(leg.get("support_id",""))!="borer_access_low" or ecology_finished>=0:
		super.drive_jump(leg);return
	if ecology_started<0:
		if not full_support(str(leg.from_support_id)): fail("entry_thread_actual_M_support_missing");return
		for index: int in stage.enemy_manifest.size():
			if stage.enemy_manifest[index].id=="hollow_route__borer_entry_thread":
				ecology_primary=stage.enemies[index].get_node("Actor")
				ecology_target_id="hollow_route__borer_entry_thread"
		if not is_instance_valid(ecology_primary): fail("entry_thread_actual_enemy_missing");return
		ecology_started=tick;ecology_entry=snapshot();ecology_state="entry_shoot" if ecology_strategy=="entry_clear" else "entry_align"
		event("ecology_choice_started",{"strategy":ecology_strategy,"primary":ecology_target_id,"snapshot":ecology_entry.duplicate(true),"support":str(leg.from_support_id)})
	if ecology_state=="entry_shoot":
		if ecology_primary.health.terminal: ecology_state="entry_pass";return
		var floor_row: Dictionary=platform(str(leg.from_support_id))
		var recoil: float=player.weapon_motion.base_distance(player.tuning,true)
		var bank: float=minf(float(ecology_entry.position[0]),float(floor_row.rect[0])+float(floor_row.rect[2])-12-recoil-7)
		controller.router.set_move_axis(clampf((bank-player.global_position.x)/12,-1,1))
		if full_support(str(leg.from_support_id)) and absf(player.global_position.x-bank)<7 and controller.shoot_ability.cooldown_remaining<=0:
			if player.global_position.x+recoil+12>float(floor_row.rect[0])+float(floor_row.rect[2]):return
			request(&"shoot_release",(ecology_primary.motor.global_position-player.global_position).normalized())
		return
	if ecology_state=="entry_align":
		var takeoff:=point(leg.takeoff)
		controller.router.set_move_axis(clampf((takeoff.x-player.global_position.x)/12,-1,1))
		if not at_destination(takeoff,str(leg.from_support_id)):return
		if ecology_primary.attack_behavior.state==&"hold":
			ecology_preview=true
			event("entry_thread_actual_hold_observed",{"snapshot":snapshot(),"depth":(ecology_primary.attack_behavior as ForestThreadSpiderBehavior).depth_snapshot()})
			if ecology_strategy=="entry_hold": ecology_state="entry_pass"
			else: ecology_state="entry_wait_retraction"
		return
	if ecology_state=="entry_wait_retraction":
		controller.router.set_move_axis(0)
		if ecology_preview and ecology_primary.attack_behavior.state in [&"retract",&"recovery"]:
			ecology_state="entry_pass"
			event("entry_thread_actual_retraction_observed",{"snapshot":snapshot()})
		return
	if ecology_state=="entry_pass":super.drive_jump(leg)

func complete_leg() -> void:
	if ecology_strategy in ["west_clear","west_wait","west_jump"] and ecology_started>=0 and ecology_finished<0 and leg_index<itinerary.size():
		var current: Dictionary=itinerary[leg_index]
		if str(current.get("edge_id",""))=="west_to_belly" and (leg_index+1==itinerary.size() or str(itinerary[leg_index+1].get("edge_id",""))!="west_to_belly"):
			ecology_finished=tick;ecology_exit=snapshot()
			event("west_seed_actual_M_arrival",{"snapshot":ecology_exit.duplicate(true),"supports":supports()})
	if ecology_strategy in ["entry_clear","entry_wait","entry_hold"] and ecology_started>=0 and ecology_finished<0 and leg_index<itinerary.size():
		var leg: Dictionary=itinerary[leg_index]
		if str(leg.get("edge_id",""))=="belly_borer_access" and str(leg.get("support_id",""))=="hollow__cavity_observe":
			ecology_finished=tick;ecology_exit=snapshot()
			event("entry_thread_actual_S_arrival",{"snapshot":ecology_exit.duplicate(true),"supports":supports()})
	super.complete_leg()

func _drive_west_jump(leg: Dictionary) -> void:
	var W := Vector2.ZERO
	for area: Dictionary in manifest.areas:
		if area.id=="W":W=point(area.position)
	if ecology_started<0:
		if not at_destination(W,"west_court"):fail("west_seed_actual_W_entry_missing");return
		for index: int in stage.enemy_manifest.size():
			if stage.enemy_manifest[index].id=="hollow_route__west_seed_watch":
				ecology_primary=stage.enemies[index].get_node("Actor");ecology_target_id="hollow_route__west_seed_watch"
		if not is_instance_valid(ecology_primary):fail("west_seed_actual_enemy_missing");return
		ecology_started=tick;ecology_entry=snapshot()
		ecology_state="west_shoot" if ecology_strategy=="west_clear" else "west_provoke" if ecology_strategy=="west_wait" else "west_pass"
		event("ecology_choice_started",{"strategy":ecology_strategy,"primary":ecology_target_id,"snapshot":ecology_entry.duplicate(true),"support":"west_court","protected_radius":ecology_primary.definition.protected_radius,"actual_spawn":manifest.spawn.duplicate()})
	if ecology_state=="west_shoot":
		if ecology_primary.health.terminal:ecology_state="west_pass";return
		var bank: float=W.x-ecology_primary.definition.protected_radius-ecology_primary.definition.pulse_size.x*.5-12
		controller.router.set_move_axis(clampf((bank-player.global_position.x)/12,-1,1))
		if full_support("west_court") and absf(player.global_position.x-bank)<7 and controller.shoot_ability.cooldown_remaining<=0:
			var floor_row: Dictionary=platform("west_court")
			var recoil: float=player.weapon_motion.base_distance(player.tuning,true)
			if player.global_position.x+recoil+12>float(floor_row.rect[0])+float(floor_row.rect[2]):return
			if ecology_shot_tick<0:event("west_seed_actual_outside_spawn_gun_bank",{"snapshot":snapshot(),"supports":supports(),"bank_x":bank,"recoil":recoil,"support_rect":floor_row.rect.duplicate()})
			request(&"shoot_release",(ecology_primary.motor.global_position-player.global_position).normalized());ecology_shot_tick=tick
		return
	if ecology_state=="west_provoke":
		var target_x: float=W.x+ecology_primary.definition.protected_radius+ecology_primary.definition.pulse_size.x*.5+12
		controller.router.set_move_axis(clampf((target_x-player.global_position.x)/12,-1,1))
		var attack := ecology_primary.attack_behavior as ForestSeedSentryBehavior
		if attack.state==&"telegraph":
			var zone := Rect2(attack.attack_goal-Vector2(ecology_primary.definition.pulse_size.x*.5,ecology_primary.definition.pulse_size.y),ecology_primary.definition.pulse_size)
			for safe: Vector2 in attack.protected_points:
				if zone.grow(ecology_primary.definition.protected_radius).has_point(safe):return
			ecology_preview=true;ecology_state="west_retreat"
			event("ecology_actual_preview",{"source":ecology_target_id,"goal":pair(attack.attack_goal)})
		return
	if ecology_state=="west_retreat":
		controller.router.set_move_axis(clampf((W.x-player.global_position.x)/12,-1,1))
		if at_destination(W,"west_court"):ecology_state="west_wait_zone"
		return
	if ecology_state=="west_wait_zone":
		controller.router.set_move_axis(0)
		var attack := ecology_primary.attack_behavior as ForestSeedSentryBehavior
		for projectile: EnemyAttackProjectile in attack._projectiles:
			if is_instance_valid(projectile) and not projectile.spent:return
		if ecology_seed_zones_seen.is_empty():return
		ecology_state="west_pass"
		event("west_seed_actual_zone_finished",{"snapshot":snapshot()})
		return
	if ecology_state=="west_pass":super.drive_jump(leg)

# Explicit optional candidate injection, never current generator admission.

func begin() -> void:
	await super.begin()
	if not ecology_strategy.begins_with("crossbranch_") or not failures.is_empty():return
	if manifest.has("crossbranch_contract"):
		ecology_enabled=false
		if not _bind_recorded_crossbranch():fail("formal_crossbranch_binding_failed")
		return
	ecology_enabled=false
	crossbranch_candidate={"scope":"candidate_data_overlay_after_actual_DemoApp_generation_not_formal_generator_admission","base_manifest":manifest.duplicate(true),"actor_id":"candidate__crossbranch","player_reset":false,"resource_injection":false,"enemy_phase_reset":false,"support_rows":[
		{"id":"candidate_reward_branch","rect":[-610.0,268.0,290.0,24.0],"one_way":true},
		{"id":"candidate_lower_return","rect":[-220.0,618.0,140.0,24.0],"one_way":true},
		{"id":"candidate_root_catch","rect":[-1050.0,820.0,1130.0,30.0],"one_way":true},
		{"id":"candidate_return_step0","rect":[-160.0,718.0,100.0,20.0],"one_way":true},
		{"id":"candidate_return_step1","rect":[-60.0,618.0,100.0,20.0],"one_way":true}],"reward_position":[-525.0,250.0],"observation_rect":[96.0,420.0,64.0,60.0],"observation_focus":[-350.0,252.0]}
	for row: Dictionary in crossbranch_candidate.support_rows:
		_candidate_support(row)
	var scene: PackedScene=load("res://game/enemies/species/scenes/forest_crossbranch.tscn")
	var npc:=scene.instantiate() as EnemyMotor
	npc.position=Vector2(76,452);stage.add_child(npc)
	crossbranch_actor=npc.get_node("Actor") as EnemyActor
	var id:=StringName(crossbranch_candidate.actor_id)
	app.policy.bind_damageable(id,crossbranch_actor.damageable,crossbranch_actor.health)
	var safe: Array[Vector2]=stage.anchors.duplicate();safe.append(stage.spawn);safe.append_array(stage.exit_positions)
	crossbranch_actor.bind_encounter(controller,app.policy,app.lifetime,id,safe)
	crossbranch_actor.attack_behavior.max_concurrent_attacks=1 if map_index==1 else 2
	var contact: DemoContactEmitter=app._contact(npc,StringName(str(id)+"_contact"),DamageRequest.Kind.MONSTER,crossbranch_actor.definition.collision_size/2.0+Vector2.ONE)
	app._enemy_contacts.append(contact)
	crossbranch_candidate.actual_contact={"source_id":String(contact.source_id),"half_size":pair(contact.half_size),"interval":contact.interval,"amount":contact.amount,"kind":int(contact.kind),"registered_in_App":app._enemy_contacts.has(contact)}
	var shores: Array[Dictionary]=[
		{"id":"north_court","rect":Rect2(60,468,220,24),"position":Vector2(76,452)},
		{"id":"candidate_reward_branch","rect":Rect2(-610,268,290,24),"position":Vector2(-350,252)}]
	var migrant:=crossbranch_actor.attack_behavior as ForestCrossbranchBehavior
	if not migrant.configure_shores(shores):fail("candidate_actual_shores_rejected");return
	stage.enemies.append(npc);stage.enemy_manifest.append({"id":str(id),"behavior_id":"forest_crossbranch","position":[76,452],"patrol_radius":0.0})
	# Existing NPCs retain every phase/health/position; only this new candidate is authored.
	for i: int in manifest.rewards.size():manifest.rewards[i].position=[-525.0,250.0]
	for i: int in stage.chests.size():stage.chests[i].position=Vector2(-525,250)
	for area: Dictionary in manifest.areas:
		if area.id=="cache":area.position=[-525.0,250.0]
	var candidate_edge: Dictionary={"id":"candidate_crossbranch_physics","edge_id":"candidate_crossbranch_physics","kind":"ecology_return","role":"candidate_crossbranch_physics","a":"N","b":"N","path":[[200.0,450.0],[112.0,450.0]],"landing":[112.0,450.0]}
	manifest.connections.append(candidate_edge.duplicate(true))
	manifest.routes.growth=["arrival_reading","west_north","candidate_crossbranch_physics"]
	# Preserve the exact real flattened W-to-N prefix; only its successor is candidate data.
	if ecology_strategy in ["crossbranch_physics","crossbranch_contact_recovery"]:
		itinerary.resize(2);itinerary.append(candidate_edge)
	else:
		_crossbranch_purpose_route()
	stage.generated.manifest=manifest.duplicate(true)
	stage.assembler.manifest=manifest.duplicate(true)
	stage.bounds=stage.bounds.merge(Rect2(-1100,0,1300,950))
	manifest.world_bounds=[stage.bounds.position.x,stage.bounds.position.y,stage.bounds.size.x,stage.bounds.size.y]
	crossbranch_candidate.actual_bounds=manifest.world_bounds.duplicate()
	app._run_camera.terrain_bounds=stage.bounds
	app._run_camera.world_bounds=stage.bounds.grow_individual(0,180,0,180)
	crossbranch_candidate.actual_definition={"body":pair(crossbranch_actor.definition.collision_size),"health":crossbranch_actor.health.current,"definition_sha":FileAccess.get_sha256("res://resources/enemies/forest_crossbranch.tres"),"recovery_budget_seconds":(crossbranch_actor.definition as ForestEnemyDefinition).crossbranch_max_flight_seconds,"return_speed":crossbranch_actor.definition.return_speed}
	manifest.candidate_overlay=crossbranch_candidate.duplicate(true)
	manifest.enemy_drops[str(id)]={"kind":"none","amount":0}
	manifest.enemies.append(stage.enemy_manifest[-1].duplicate(true))
	stage.generated.manifest=manifest.duplicate(true)
	stage.assembler.manifest=manifest.duplicate(true)
	stage.assembler.queue_redraw()
	stage.queue_redraw()

func _candidate_support(row: Dictionary) -> void:
	var rect:=Rect2(row.rect[0],row.rect[1],row.rect[2],row.rect[3])
	var body:=StaticBody2D.new();body.name=row.id;body.position=rect.get_center();body.collision_layer=1
	body.add_to_group(&"one_way_platform");body.set_meta("support_ids",[str(row.id)]);body.set_meta("support_world_rect",rect)
	var collision:=CollisionShape2D.new();collision.name="CollisionShape2D"
	var shape:=RectangleShape2D.new();shape.size=rect.size;collision.shape=shape;collision.one_way_collision=true;collision.one_way_collision_margin=4
	body.add_child(collision);stage.assembler.add_child(body)
	manifest.platforms.append(row.duplicate(true));stage.assembler.forest_platforms.append(row.duplicate(true));stage.assembler.support_bodies[row.id]=body

func drive_ecology(leg: Dictionary) -> void:
	if str(leg.get("role",""))=="candidate_reward_out":
		_crossbranch_outbound();return
	if str(leg.get("role",""))=="candidate_reward_return":
		_crossbranch_return();return
	if str(leg.get("role",""))!="candidate_crossbranch_physics":super.drive_ecology(leg);return
	if ecology_strategy=="crossbranch_contact_recovery":
		_crossbranch_contact_recovery();return
	controller.router.set_move_axis(clampf((112-player.global_position.x)/12,-1,1))
	if crossbranch_started<0:
		crossbranch_started=tick;event("candidate_N_arrival",{"snapshot":snapshot()})
	var behavior:=crossbranch_actor.attack_behavior as ForestCrossbranchBehavior
	var landed: Array=behavior.ledger.filter(func(row: Dictionary) -> bool:return row.event=="land")
	if behavior.state==&"blocked":fail("candidate_NPC_blocked/"+str(behavior.ledger));return
	if landed.size()>=2 and behavior.current_shore==0 and behavior.state==&"rest":
		crossbranch_finished=tick
		stable=stable+1 if at_destination(Vector2(112,450),"north_court") else 0
		if stable>=12:complete_leg()

var crossbranch_component_state := "touch"
func _crossbranch_contact_recovery() -> void:
	var behavior:=crossbranch_actor.attack_behavior as ForestCrossbranchBehavior
	if crossbranch_started<0:crossbranch_started=tick
	if behavior.recovery_budget_failed:fail("candidate_actual_recovery_budget_failed");return
	if crossbranch_component_state=="touch":
		controller.router.set_move_axis(clampf((76-player.global_position.x)/12,-1,1))
		if behavior.state==&"recovery_fall":
			crossbranch_component_state="clear";event("candidate_actual_collision_recovery_started",{"snapshot":snapshot(),"NPC_position":pair(crossbranch_actor.motor.global_position),"ledger":behavior.ledger.duplicate(true)})
		return
	controller.router.set_move_axis(clampf((112-player.global_position.x)/12,-1,1))
	var landed: Array=behavior.ledger.filter(func(row: Dictionary) -> bool:return row.event=="land")
	stable=stable+1 if landed.size()>=2 and behavior.current_shore==0 and behavior.state==&"rest" and behavior._on_shore(0) and at_destination(Vector2(112,450),"north_court") else 0
	if stable>=12:
		crossbranch_finished=tick
		event("candidate_actual_component_recovery_complete",{"snapshot":snapshot(),"NPC_position":pair(crossbranch_actor.motor.global_position),"actual_roundtrip_lands":landed.duplicate(true)})
		complete_leg()


func _crossbranch_purpose_route() -> void:
	var original_ids: Array=crossbranch_candidate.base_manifest.routes.growth.duplicate()
	var original_tail: Array[Dictionary]=[]
	for i: int in range(2,itinerary.size()):
		if str(itinerary[i].edge_id) not in ["borer_cache","cache_borer_back"]:original_tail.append(itinerary[i].duplicate(true))
	var row: Dictionary={"id":"candidate_reward_out","edge_id":"candidate_reward_out","kind":"ecology_return","role":"candidate_reward_out","a":"N","b":"candidate_award_entry","path":[[200.0,450.0],[-400.0,250.0]],"landing":[-400.0,250.0]}
	var claim: Dictionary={"id":"candidate_reward_claim","edge_id":"candidate_reward_claim","kind":"walk","a":"candidate_award_entry","b":"cache","path":[[-400.0,250.0],[-525.0,250.0]],"landing":[-525.0,250.0]}
	var back: Dictionary={"id":"candidate_reward_return","edge_id":"candidate_reward_return","kind":"ecology_return","role":"candidate_reward_return","a":"cache","b":"W","path":[[-525.0,250.0],[-440.0,250.0],[-150.0,600.0],[20.0,600.0],[180.0,600.0]],"landing":[180.0,600.0],"claim_before_edge":true,"claim_id":str(manifest.rewards[0].id),"claim_area":"cache"}
	manifest.areas.append({"id":"candidate_award_entry","position":[-400.0,250.0],"role":"candidate_observation","label":"FAR BOUGH"})
	for edge: Dictionary in [row,claim,back]:manifest.connections.append(edge.duplicate(true))
	var first_north: Dictionary=itinerary[1].duplicate(true)
	itinerary.resize(2);itinerary.append_array([row,claim,back]);itinerary.append(first_north);itinerary.append_array(original_tail)
	var ids: Array=["arrival_reading","west_north","candidate_reward_out","candidate_reward_claim","candidate_reward_return","west_north"]
	for id: String in original_ids.slice(2):
		if id not in ["borer_cache","cache_borer_back"]:ids.append(id)
	manifest.routes.growth=ids
