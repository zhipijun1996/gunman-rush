extends "res://tests/forest_depth_ecology_trace.gd"
## One real R->E candidate in the generated DemoApp, never a copied room.
var lift_strategy := "alive_lift"
var lift_started := -1
var lift_finished := -1
var lift_state := "entry"
var lift_actor: EnemyActor
var lift_entry: Dictionary = {}
var lift_exit: Dictionary = {}
var lift_prefix: Array = []
var lift_original_itinerary: Array = []
var lift_contact := false
var lift_shots := 0
var lift_setup_shots := 0
var lift_contact_tick := -1
var lift_first_free_tick := -1
var lift_goal := Vector2.ZERO
var lift_bank_x := 0.0
var lift_h_snapshot: Dictionary = {}
var lift_motion_started := -1
var lift_empty_tick := -1
var lift_floor_recovery_tick := -1
var expedition_enabled := false
var expedition_prefix_count := -1
var expedition_camp_tick := -1
var expedition_reward_R_tick := -1
var expedition_reward_R: Dictionary = {}
var expedition_camp: Dictionary = {}
var expedition_prefix: Array = []
var expedition_started_leg := -1
var expedition_fallback := false
var expedition_opposite_phase_seen := false
var crown_return_strategy := "direct_one_R"
var crown_return_started := -1
var crown_return_finished := -1
var crown_return_state := "jump"
var crown_return_entry: Dictionary = {}
var crown_return_exit: Dictionary = {}
var crown_return_contract: Dictionary = {}
var crown_return_R := 0
var crown_return_jump_released := false
var crown_return_burst_seen := false

func _ready() -> void:
	ecology_enabled=false
	super._ready()

func begin() -> void:
	await super.begin()
	if not initialized or not is_instance_valid(controller): return
	if expedition_enabled:
		if map_index==2:
			if route_name!="ecology_expedition" or int(manifest.choices.skeleton)!=0 or int(manifest.choices.cache_route)!=0 or int(manifest.choices.cavity_direction)!=0:
				fail("expedition_map2_natural_lower_cache_identity_missing");return
			for index: int in itinerary.size():
				if str(itinerary[index].get("edge_id",""))=="outer_lift_return":
					expedition_prefix_count=index;break
		else:
			if route_name!="ecology_expedition" or map_index!=1 or int(manifest.choices.skeleton)!=1:
				fail("expedition_actual_graph_identity_missing");return
			for index: int in itinerary.size():
				if str(itinerary[index].get("edge_id",""))=="camp_outer_back":
					expedition_prefix_count=index;break
		if expedition_prefix_count<=0 or not manifest.routes.has("ecology_expedition"):
			fail("expedition_reward_return_prefix_missing");return
	controller.energy_recovered.connect(func(amount: float, airborne: bool) -> void:
		event("actual_shot_energy_recovered",{"amount":amount,"airborne":airborne,"snapshot":snapshot()}))

func _hook_event(state: StringName) -> void:
	super._hook_event(state)
	if lift_started<0: return
	if state==&"hook_contact_kick" and is_instance_valid(lift_actor) and controller.traversal.hook_target==lift_actor.motor:
		lift_contact=true;lift_contact_tick=tick
		event("lift_actual_contact",{"enemy_id":"hollow_route__outer_lift_lantern","snapshot":snapshot(),"enemy_health":lift_actor.health.current})

func observe() -> void:
	super.observe()
	if frames.is_empty() or int(frames[-1].tick)!=tick: return
	if crown_return_started>=0:
		frames[-1].merge({"crown_return_recoil_remaining":player.recoil_burst_remaining,"crown_return_recoil_velocity":pair(player.recoil_velocity),"crown_return_normal_velocity":pair(player.normal_velocity),"crown_return_actor_epoch":app.lifetime.actor_epoch,"crown_return_hold_elapsed":controller.jump_ability._hold_elapsed})
	if not expedition_enabled and lift_started<0: return
	frames[-1].combat_energy=controller.combat_energy.current
	frames[-1].combat_hit_packets=controller.combat_energy._packets.duplicate(true)
	frames[-1].pending_shot_grants=controller.received_resource_grants.size()
	frames[-1].shot_energy_hit_receipts=controller.shot_energy._hits.duplicate(true)
	frames[-1].lift_health=lift_actor.health.current if is_instance_valid(lift_actor) else -1.0
	frames[-1].lift_position=pair(lift_actor.motor.global_position) if is_instance_valid(lift_actor) else []
	if expedition_enabled:
		frames[-1].wallet_balance=app.wallet.balance
		frames[-1].meta_notes=app.meta.snapshot().get("notes",0)
		frames[-1].item_ids=app.build.item_ids()
		frames[-1].claimed_ids=stage.region_state.claimed.keys()

	if lift_contact and lift_first_free_tick<0 and controller.traversal.state==&"free" and not player.is_on_floor():
		lift_first_free_tick=tick
		event("lift_first_actual_free_frame",{"snapshot":snapshot()})

func _connection(id: String) -> Dictionary:
	for row: Dictionary in manifest.connections:
		if row.id==id:
			var result: Dictionary=row.duplicate(true)
			result.edge_id=id;result.landing=result.get("landing",result.path[-1]).duplicate()
			return result
	return {}

func _fixed_return() -> void:
	# These are the actual existing edges, including both fixed rings and
	# normal recovery jumps. No invented staircase or added topology.
	var revised: Array[Dictionary]=[]
	for index: int in leg_index: revised.append(itinerary[index].duplicate(true))
	for id: String in ["outer_to_inner","inner_recovery","upper_out"]:
		var row := _connection(id)
		if row.is_empty(): fail("lift_missing_actual_fixed_return/"+id);return
		revised.append(row)
		if row.has("post_landing_steps"):
			for step: Dictionary in row.post_landing_steps:
				var copy: Dictionary=step.duplicate(true);copy.edge_id=id;copy.post_landing=true;revised.append(copy)
	itinerary=revised
	lift_state="fixed_return";set_phase("align")
	event("lift_existing_fixed_return_selected",{"edges":["outer_to_inner","inner_recovery","upper_out"]})

func _seal_lift() -> void:
	if lift_finished>=0: return
	lift_finished=tick;lift_exit=snapshot()
	lift_exit.supports=supports();lift_exit.combat_energy=controller.combat_energy.current
	event("lift_actual_E_arrival",{"snapshot":lift_exit.duplicate(true),"strategy":lift_strategy})

func complete_leg() -> void:
	if expedition_enabled and map_index==2 and leg_index==expedition_prefix_count-1:
		if not cache_claimed or not duplicate_checked or str(itinerary[leg_index].edge_id)!="reward_other_exit" or not at_destination(point(itinerary[leg_index].landing),"hollow__outer_root"):
			fail("expedition_map2_R_before_actual_lower_reward_claim");return
		expedition_reward_R_tick=tick
		expedition_reward_R=snapshot();expedition_reward_R.supports=supports()
		expedition_reward_R.wallet_balance=app.wallet.balance
		expedition_reward_R.meta_notes=app.meta.snapshot().get("notes",0)
		expedition_reward_R.item_ids=app.build.item_ids()
		expedition_reward_R.claimed_ids=stage.region_state.claimed.keys()
		expedition_prefix=completed.duplicate(true)
		event("expedition_reward_R_complete",{"snapshot":expedition_reward_R.duplicate(true),"prefix_final_leg":leg_index,"actual_edge":itinerary[leg_index].edge_id})
	if expedition_enabled and map_index==1 and leg_index==expedition_prefix_count-1:
		if not cache_claimed or not duplicate_checked:
			fail("expedition_camp_before_actual_reward_claim");return
		expedition_camp_tick=tick
		expedition_camp=snapshot();expedition_camp.supports=supports()
		expedition_camp.wallet_balance=app.wallet.balance
		expedition_camp.meta_notes=app.meta.snapshot().get("notes",0)
		expedition_camp.item_ids=app.build.item_ids()
		expedition_camp.claimed_ids=stage.region_state.claimed.keys()
		expedition_prefix=completed.duplicate(true)
		event("expedition_reward_return_complete",{"snapshot":expedition_camp.duplicate(true),"prefix_final_leg":leg_index,"actual_edge":itinerary[leg_index].edge_id})
	if lift_started>=0 and lift_state=="fixed_return" and leg_index==itinerary.size()-1:
		_seal_lift()
	super.complete_leg()

func _start_live_lift() -> void:
	lift_motion_started=tick
	controller.router.set_move_axis(0);jump(false)
	event("lift_motion_started",{"snapshot":snapshot(),"enemy_state":String(lift_actor.attack_behavior.state),"enemy_position":pair(lift_actor.motor.global_position),"travel_side":(lift_actor.attack_behavior as ForestLanternBehavior).travel_side,"shot_energy_hit_receipts":controller.shot_energy._hits.duplicate(true)})
	request(&"grapple",(lift_actor.motor.global_position-player.global_position-Vector2(0,-6)).normalized())
	lift_h_snapshot=snapshot();lift_state="hook";set_phase("lift_live_hook")

func _start_strong_jump() -> void:
	lift_motion_started=tick
	controller.router.set_move_axis(clampf((lift_goal.x-player.global_position.x)/12,-1,1))
	jump(true);lift_state="normal_jump";set_phase("lift_full_jump")
	event("lift_motion_started",{"snapshot":snapshot()})

func drive_hollow(leg: Dictionary) -> void:
	if expedition_enabled and str(leg.get("edge_id",""))!="outer_lift_return":
		super.drive_hollow(leg);return
	var target_edge: String="outer_lift_return" if expedition_enabled else "outer_to_inner"
	if lift_started<0 and str(leg.get("edge_id",""))!=target_edge:
		super.drive_hollow(leg);return
	if lift_started<0:
		if expedition_enabled:
			if (expedition_reward_R_tick<0 if map_index==2 else expedition_camp_tick<0) or leg.kind!="hollow_live_return" or leg.a!="R" or leg.b!="E" or not bool(leg.get("optional",false)) or str(leg.get("enemy_id",""))!="hollow_route__outer_lift_lantern":
				fail("expedition_not_actual_optional_graph_leg_after_reward_return");return
			expedition_started_leg=leg_index
		var R := Vector2.ZERO
		for area: Dictionary in manifest.areas:
			if area.id=="R": R=point(area.position)
			if area.id=="E": lift_goal=point(area.position)
		if not at_destination(R,"hollow__outer_root"): fail("lift_not_actual_R_entry");return
		for index: int in stage.enemy_manifest.size():
			if stage.enemy_manifest[index].id=="hollow_route__outer_lift_lantern": lift_actor=stage.enemies[index].get_node("Actor")
		if not is_instance_valid(lift_actor): fail("lift_actual_actor_missing");return
		if not expedition_enabled and lift_actor.health.current!=lift_actor.definition.health_definition.initial_current:
			fail("lift_actual_live_HP2_entry_missing");return
		if expedition_enabled and not lift_actor.health.terminal and lift_actor.health.current!=lift_actor.definition.health_definition.initial_current:
			fail("expedition_living_anchor_not_naturally_HP2");return
		lift_started=tick;lift_entry=snapshot();lift_entry.supports=supports()
		lift_entry.combat_energy=controller.combat_energy.current
		lift_entry.shot_energy_hit_receipts=controller.shot_energy._hits.duplicate(true)
		lift_prefix=completed.duplicate(true);lift_original_itinerary=itinerary.duplicate(true)
		var support: Dictionary=platform("hollow__outer_root")
		lift_bank_x=maxf(player.global_position.x,float(support.rect[0])+12.0+player.weapon_motion.base_distance(player.tuning,true)+7.0)
		event("lift_R_choice_started",{"strategy":lift_strategy,"entry":lift_entry.duplicate(true),"enemy_health":lift_actor.health.current,"enemy_position":pair(lift_actor.motor.global_position),"travel_side":(lift_actor.attack_behavior as ForestLanternBehavior).travel_side,"enemy_state":String(lift_actor.attack_behavior.state),"manifest_row":stage.enemy_manifest[stage.enemies.find(lift_actor.motor)].duplicate(true)})
		if expedition_enabled and lift_actor.health.terminal:
			expedition_fallback=true
			event("expedition_natural_dead_anchor_fallback",{"snapshot":snapshot()})
			_start_strong_jump();return
		if lift_strategy=="fixed_return": _fixed_return();return
		if lift_strategy in ["dead_fixed_return","dead_jump_two_R","lethal_contact_lift"]: lift_state="shoot_dead";return
		if lift_strategy=="jump_two_R": _start_strong_jump();return
		if lift_strategy=="left_phase_lift": lift_state="left_phase_wait";return
		if lift_strategy=="low_air_recover_lift":
			controller.router.set_move_axis(0);jump(true);lift_state="low_full_jump";set_phase("lift_low_full_jump");return
		_start_live_lift();return
	if lift_state=="fixed_return":
		super.drive_hollow(leg);return
	if lift_state=="shoot_dead":
		if lift_strategy=="lethal_contact_lift" and lift_actor.health.current==1:
			event("lift_actual_projectile_prime_HP1",{"setup_shots":lift_setup_shots,"snapshot":snapshot(),"enemy_health":lift_actor.health.current})
			lift_state="dead_realign";set_phase("lift_primed_R_realign");return
		if lift_actor.health.terminal:
			event("lift_actual_projectile_death_before_return",{"setup_shots":lift_setup_shots,"snapshot":snapshot()})
			if lift_strategy=="dead_fixed_return": _fixed_return()
			else: lift_state="dead_realign";set_phase("lift_dead_R_realign")
			return
		controller.router.set_move_axis(clampf((lift_bank_x-player.global_position.x)/12,-1,1))
		if full_support("hollow__outer_root") and absf(player.global_position.x-lift_bank_x)<7 and controller.shoot_ability.cooldown_remaining<=0:
			request(&"shoot_release",(lift_actor.motor.global_position-player.global_position).normalized());lift_setup_shots+=1
		return
	if lift_state=="dead_realign":
		var R: Vector2=point(lift_entry.position)
		controller.router.set_move_axis(clampf((R.x-player.global_position.x)/12,-1,1))
		stable=stable+1 if at_destination(R,"hollow__outer_root") else 0
		if stable>=12:
			if lift_strategy=="lethal_contact_lift": _start_live_lift()
			else: _start_strong_jump()
		return
	if lift_state=="left_phase_wait":
		controller.router.set_move_axis(0)
		var lantern := lift_actor.attack_behavior as ForestLanternBehavior
		if expedition_enabled:
			# The natural expedition entry can already be moving left. Require a
			# real intervening rightward trip before sampling a later left phase.
			if not expedition_opposite_phase_seen and lantern.state==&"travel" and lantern.travel_side>0:
				expedition_opposite_phase_seen=true
				event("expedition_opposite_phase_observed",{"enemy_id":"hollow_route__outer_lift_lantern","enemy_position":pair(lift_actor.motor.global_position),"travel_side":lantern.travel_side})
			if expedition_opposite_phase_seen and lantern.state==&"travel" and lantern.travel_side<0: _start_live_lift()
		elif lantern.state==&"travel" and lantern.travel_side<0: _start_live_lift()
		return
	if lift_state=="low_full_jump":
		controller.router.set_move_axis(0)
		if not player.is_on_floor() and player.velocity.y>=0 and age>1:
			jump(false);request(&"shoot_release",Vector2.LEFT);lift_setup_shots=1;lift_state="low_second_miss"
		return
	if lift_state=="low_second_miss":
		controller.router.set_move_axis(0)
		if not player.is_on_floor() and player.recoil_burst_remaining<=0 and controller.shoot_ability.cooldown_remaining<=0:
			request(&"shoot_release",Vector2.RIGHT);lift_setup_shots=2;lift_state="low_empty_fall";set_phase("lift_low_empty_fall")
		return
	if lift_state=="low_empty_fall":
		if not player.is_on_floor() and controller.action_resources.shot_charges==0 and lift_empty_tick<0:
			lift_empty_tick=tick
			event("lift_actual_empty_air_rounds",{"snapshot":snapshot()})
		var R: Vector2=point(lift_entry.position)
		controller.router.set_move_axis(clampf((R.x-player.global_position.x)/12,-1,1))
		stable=stable+1 if at_destination(R,"hollow__outer_root") else 0
		if stable>=12:
			if lift_empty_tick<0 or controller.action_resources.shot_charges!=player.tuning.max_air_shots:
				fail("lift_low_air_natural_recovery_missing");return
			lift_floor_recovery_tick=tick
			event("lift_actual_ground_round_recovery",{"snapshot":snapshot()})
			_start_live_lift()
		return
	if lift_state=="hook":
		controller.router.set_move_axis(0)
		if lift_contact and controller.traversal.state==&"free" and not player.is_on_floor():
			jump(false)
			event("lift_first_free_down_R_request",{"snapshot":snapshot(),"shot_cost":controller.shot_energy.shot_energy_cost,"enemy_health":lift_actor.health.current})
			request(&"shoot_release",Vector2.DOWN);lift_shots=1;lift_state="land";set_phase("lift_live_upward_recoil")
		elif age>240: fail("lift_actual_H_arrival_or_free_failed")
		return
	if lift_state=="normal_jump":
		controller.router.set_move_axis(clampf((lift_goal.x-player.global_position.x)/12,-1,1))
		# Keep the legitimate full jump until its actual apex; early release
		# would artificially weaken the strongest ordinary two-shot control.
		if not player.is_on_floor() and player.velocity.y>=0 and age>1:
			event("lift_normal_full_jump_apex",{"snapshot":snapshot()})
			jump(false);request(&"shoot_release",Vector2.DOWN);lift_shots=1
			lift_state="second_R";set_phase("lift_normal_first_R")
		return
	if lift_state=="second_R":
		controller.router.set_move_axis(clampf((lift_goal.x-player.global_position.x)/12,-1,1))
		# If the first shot already gains full crown clearance, don't force
		# a second cost. Otherwise spend at most the real second air round.
		var crown: Dictionary=platform("hollow__outer_crown")
		if player.global_position.y+18<float(crown.rect[1]): lift_state="land"
		elif not player.is_on_floor() and player.recoil_burst_remaining<=0 and controller.shoot_ability.cooldown_remaining<=0:
			request(&"shoot_release",Vector2.DOWN);lift_shots+=1;lift_state="land";set_phase("lift_normal_second_R")
		return
	if lift_state=="land":
		controller.router.set_move_axis(clampf((lift_goal.x-player.global_position.x)/12,-1,1))
		stable=stable+1 if at_destination(lift_goal,"hollow__outer_crown") else 0
		if stable>=12:
			_seal_lift();controller.router.set_move_axis(0);jump(false)
			if expedition_enabled: complete_leg()
			else: finish_pending=true

func _physics_process(delta: float) -> void:
	if not expedition_enabled or not initialized or finished or leg_index>=itinerary.size() or str(itinerary[leg_index].get("kind",""))!="hollow_live_return":
		super._physics_process(delta);return
	if get_tree().paused: return
	if not is_instance_valid(player) or not is_instance_valid(controller) or not app.lifetime.active:
		fail("actual_run_ended");return
	tick+=1;age+=1;before_steps=player.motion_steps
	if tick>18000: fail("route_tick_budget");return
	if tick-leg_started>1800: fail("edge_tick_budget/"+str(leg_index)+"/"+phase);return
	drive_hollow(itinerary[leg_index])

# The existing actual optional itinerary invokes this role after supported E.
# All strategies share the complete arrival/reward/R/live-lift prefix.
func drive_ecology(leg: Dictionary) -> void:
	if str(leg.get("role",""))!="crown_reverse_return":
		super.drive_ecology(leg);return
	var goal:=point(leg.landing)
	if crown_return_started<0:
		if map_index!=2 or not expedition_enabled or lift_finished<0 or leg.kind!="ecology_return" or leg.a!="E" or leg.b!="C" or not at_destination(point(lift_exit.position),"hollow__outer_crown"):
			fail("crown_return_actual_supported_E_prefix_missing");return
		if crown_return_strategy not in ["direct_one_R","direct_two_R"]:
			fail("crown_return_unknown_strategy");return
		crown_return_started=tick;crown_return_entry=snapshot()
		crown_return_entry.supports=supports()
		var collision:=player.get_node("CollisionShape2D") as CollisionShape2D
		var body_shape:=collision.shape as RectangleShape2D
		if body_shape==null:fail("crown_return_actual_body_shape_missing");return
		crown_return_contract={"edge_id":str(leg.edge_id),"leg":leg_index,"from_support_id":str(leg.from_support_id),"landing_support_id":str(leg.landing_support_id),"body_size":pair(body_shape.size),"actor_epoch":app.lifetime.actor_epoch,"recoil_distance":player.weapon_motion.base_distance(player.tuning,true),"shot_cost":controller.shot_energy.shot_energy_cost}
		event("crown_return_E_choice_started",{"strategy":crown_return_strategy,"snapshot":crown_return_entry.duplicate(true)})
		controller.router.set_move_axis(clampf((goal.x-player.global_position.x)/12,-1,1))
		jump(true);set_phase("crown_return_full_jump")
		return
	if crown_return_state=="jump":
		controller.router.set_move_axis(clampf((goal.x-player.global_position.x)/12,-1,1))
		if not player.is_on_floor() and player.normal_velocity.y>=0 and age>1:
			event("crown_return_ordinary_real_apex",{"snapshot":snapshot()})
			jump(false);crown_return_jump_released=true
			event("crown_return_R_request",{"ordinal":1,"aim":[0,1],"snapshot":snapshot(),"shot_cost":controller.shot_energy.shot_energy_cost})
			request(&"shoot_release",Vector2.DOWN);crown_return_R=1;crown_return_state="land"
		if not crown_return_jump_released and not player.is_on_floor() and player.normal_velocity.y>=0:
			jump(false);crown_return_jump_released=true
		return
	if crown_return_state=="land":
		crown_return_burst_seen=crown_return_burst_seen or player.recoil_burst_remaining>0
		controller.router.set_move_axis(clampf((goal.x-player.global_position.x)/12,-1,1))
		var receiver: Dictionary=platform(str(leg.landing_support_id))
		var body_half:=point(crown_return_contract.body_size)*.5
		if crown_return_strategy=="direct_two_R" and crown_return_R==1 and player.global_position.y+body_half.y>=float(receiver.rect[1]) and not player.is_on_floor() and player.recoil_burst_remaining<=0 and controller.shoot_ability.cooldown_remaining<=0:
			event("crown_return_R_request",{"ordinal":2,"aim":[0,1],"snapshot":snapshot(),"shot_cost":controller.shot_energy.shot_energy_cost})
			request(&"shoot_release",Vector2.DOWN);crown_return_R=2
		stable=stable+1 if at_destination(goal,str(leg.landing_support_id)) else 0
		if stable>=12:
			crown_return_finished=tick;crown_return_exit=snapshot();crown_return_exit.supports=supports()
			event("crown_return_actual_C_arrival",{"snapshot":crown_return_exit.duplicate(true),"supports":supports(),"R_count":crown_return_R})
			complete_leg();return
		if crown_return_burst_seen and player.is_on_floor() and full_support("hollow__outer_crown"):
			fail("crown_return_bounded_return_to_E_without_C/"+crown_return_strategy)
