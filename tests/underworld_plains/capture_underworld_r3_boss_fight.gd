extends SceneTree
## One complete actual formal encounter. Only the initial room placement is a
## fixture; no HP/phase/resource injection, mid-fight teleport or stopped AI.
## Optional Godot --write-movie captures this same normal-clock driver.
var app:DemoApp
var map_index:=1
var trace:Array[Dictionary]=[]
var failure:Array[String]=[]
var shots:=0
var accepted_shots:=0
var damage_events:Array[Dictionary]=[]
var crossed:=0
var cross_axis:=0
var jump_active:=false
var previous_mode:StringName
var visited:Dictionary={}
var start_meta:Dictionary
# Current Pressure is a separate input adapter. Classic R3 navigation and all
# original settlement assertions below remain verbatim. This native consumer
# may fire legal attack-phase shots; it is not the cautious two-shot review film.
var pressure_pilot:RefCounted
var pressure_extra_inputs:Array[Dictionary]=[]
# Actual RefCounted health owners survive an arena teardown for failure evidence.
# Holding these observers does not reset or alter any resource or Actor state.
var pressure_boss_health:HealthState
var pressure_player_health:HealthState
var pressure_last_live:Dictionary={}
func _initialize()->void:run.call_deferred()
func frames(n:int)->void:
	for i:int in n:await physics_frame
func run()->void:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):map_index=int(arg.trim_prefix("--map="))
	app=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
	app.start_plains("underworld-r3-continuous-boss")
	await frames(8)
	var first_map_hash := str((app.stage as PlainsRegionStage).generated.manifest.manifest_hash)
	if map_index==2:
		app.director.stage_index=2;app.director.region_map_index=2;app._load_stage();await frames(8)
	var stage:=app.stage as PlainsRegionStage
	# Normal post-victory progression may release this map before the receipt.
	var actual_map_identity := {"map_index":stage.map_index,"manifest_seed":stage.generated.manifest.seed,"manifest_hash":stage.generated.manifest.manifest_hash}
	if not (stage.map_index == map_index and app.director.region_map_index == map_index and str(stage.generated.manifest.seed) == PlainsRegionCampaign.seed_for(app.director.seed,map_index) and str(stage.generated.manifest.manifest_hash).length() == 64): failure.append("actual fight map identity differs from requested formal map")
	if map_index==2 and str(stage.generated.manifest.manifest_hash)==first_map_hash: failure.append("actual main fight reused mini map Manifest hash")
	var boss:=stage.boss as BossMotor
	var encounter:=boss.get_node("Encounter") as WindkeeperEncounter
	start_meta=app.meta.snapshot()
	app.controller.shoot_ability.shot_fired.connect(func(_aim:Vector2,_id:int)->void:
		accepted_shots+=1
		if pressure_pilot!=null:pressure_pilot.observe_actual_shot(_id))
	if encounter is WindkeeperPressureEncounter:
		pressure_pilot=load("res://tools/windkeeper_pressure_01/legal_input_pilot.gd").new()
		pressure_pilot.mode="active_assault"
		pressure_boss_health=encounter.health
		pressure_player_health=app.controller.actor_resources.health
	app.policy.batch_resolved.connect(func(results:Array[DamageResult])->void:
		for result:DamageResult in results:
			damage_events.append({"tick":Engine.get_physics_frames(),"target":String(result.request.target_id),"event":String(result.request.event_id),"amount":result.request.amount,"health":result.health.current}))
	# Explicit room-entry fixture. All later movement is the actual Router/Motor.
	app.player.reset_at(boss.global_position+Vector2(-250,47))
	await frames(5)
	if not app._boss_started:failure.append("actual core entry failed to activate Boss")
	if encounter.health.current!=encounter.health.capacity:failure.append("fight did not start at full actual Boss HP")
	var start_tick:=Engine.get_physics_frames()
	for tick:int in 7200:
		if not is_instance_valid(app.controller) or app.director.state!=DemoRunDirector.State.IN_STAGE:break
		if pressure_pilot!=null and (not is_instance_valid(encounter) or not is_instance_valid(stage) or not is_instance_valid(boss)):break
		if encounter.health.terminal:break
		var player:=app.player as PlayerMotor
		var controller:=app.controller
		var dx:=boss.global_position.x-player.global_position.x
		var grounded:=player.is_on_floor()
		visited[str(encounter.stage_phase)]=true
		var axis:=0.0
		if encounter is WindkeeperPressureEncounter:
			var pressure:=encounter as WindkeeperPressureEncounter
			var input_start:int=pressure_pilot.input_rows.size()
			pressure_pilot.step(app,pressure,pressure.combat_metrics(),_pressure_units(stage))
			var requested_this_frame:=false
			for row:Dictionary in pressure_pilot.input_rows.slice(input_start):
				if row.get("action","") in ["shoot_release","escape_recoil_shot","active_extra_shot","proven_escape_recoil_shot","corner_sweep_recoil_shot","support_escape_recoil_shot"] and bool(row.get("submitted",false)):
					shots+=1;requested_this_frame=true
			if pressure_pilot.mode!="active_assault" and not requested_this_frame and _pressure_extra_shot(pressure):shots+=1
			axis=controller.router.axis
			trace.append({"tick":Engine.get_physics_frames(),"movie_seconds":float(Engine.get_physics_frames()-start_tick)/60,"player":[player.global_position.x,player.global_position.y],"boss":[boss.global_position.x,boss.global_position.y],"player_hp":controller.actor_resources.health.current,"boss_hp":encounter.health.current,"stamina":controller.actor_resources.stamina.current,"phase":encounter.stage_phase,"mode":String(encounter.mode),"clock":encounter.clock,"axis":axis,"cross":pressure_pilot.cross_axis,"grounded":grounded,"requested_shots":shots,"pressure_adapter":true,"pilot_intent":pressure_pilot.intent,"group_plan":pressure.combat_metrics().group_plan})
			pressure_last_live=trace.back().duplicate(true)
			await frames(1)
			continue
		if map_index==1:
			if encounter.mode==&"roll" and signf(dx)==-encounter.direction and absf(dx)<195 and grounded and cross_axis==0:
				cross_axis=-encounter.direction;controller.router.set_jump_held(&"r3_fight",true);jump_active=true;crossed+=1
			if cross_axis!=0:
				axis=float(cross_axis)
				if grounded and not jump_active:cross_axis=0
			else:
				var desired:=clampf(boss.global_position.x-signf(dx)*220,stage.boss_arena.position.x+55,stage.boss_arena.end.x-55)
				axis=clampf((desired-player.global_position.x)/45,-1,1)
			if encounter.mode==&"rings" and grounded and encounter.clock<.5:
				controller.router.set_jump_held(&"r3_fight",true);jump_active=true
		else:
			var module:PlatformingModule=null
			for candidate:PlatformingModule in stage.assembler.modules:
				if candidate.definition.module_id==&"plains_boss_arena":module=candidate;break
			var desired:=boss.global_position.x-signf(dx)*240
			if encounter.stage_phase>=2 and module!=null:
				var shelf_centers:Array[float]=[]
				for index:int in [1,2,3]:shelf_centers.append(module.to_global(module.definition.platforms[index].get_center()).x)
				desired=shelf_centers[0] if encounter.stage_phase==2 else shelf_centers[clampi(encounter.chase_segment+1,0,2)]
				if grounded and player.global_position.y>encounter._floor_y-130:
					controller.router.set_jump_held(&"r3_fight",true);jump_active=true
			axis=clampf((desired-player.global_position.x)/45,-1,1)
			if grounded and encounter.mode==&"stomp_warning" and encounter.clock<.3:
				controller.router.set_jump_held(&"r3_fight",true);jump_active=true
		if jump_active and player.normal_velocity.y>=0:
			controller.router.set_jump_held(&"r3_fight",false);jump_active=false
		controller.router.set_move_axis(axis)
		var can_shoot:=encounter.mode!=&"intro" and controller.shoot_ability.cooldown_remaining<=0 and controller.shoot_ability.rounds_remaining==0
		if map_index==1 and cross_axis!=0 and signf(dx)==float(cross_axis):can_shoot=false
		if can_shoot:
			var aim_point:=boss.global_position+Vector2(0,-20 if player.global_position.y>boss.global_position.y else -95)
			if controller.router.request_action(&"shoot_release",(aim_point-player.global_position).normalized()):shots+=1
		trace.append({"tick":Engine.get_physics_frames(),"movie_seconds":float(Engine.get_physics_frames()-start_tick)/60,"player":[player.global_position.x,player.global_position.y],"boss":[boss.global_position.x,boss.global_position.y],"player_hp":controller.actor_resources.health.current,"boss_hp":encounter.health.current,"stamina":controller.actor_resources.stamina.current,"phase":encounter.stage_phase,"mode":String(encounter.mode),"clock":encounter.clock,"axis":axis,"cross":cross_axis,"grounded":grounded,"requested_shots":shots})
		await frames(1)
	if pressure_pilot!=null and (not is_instance_valid(encounter) or not is_instance_valid(stage) or not is_instance_valid(app.controller) or not app.lifetime.active or app.director.state!=DemoRunDirector.State.IN_STAGE):
		await _finish_pressure_released_receipt(actual_map_identity)
		return
	var hp:=encounter.health.current
	var actor_hp:=app.controller.actor_resources.health.current if is_instance_valid(app.controller) else 0.0
	if not encounter.health.terminal:failure.append("actual continuous full fight did not defeat Boss")
	if actor_hp<=0 or not app.lifetime.active:failure.append("player failed actual continuous battle")
	var pressure_settlement:Dictionary={}
	if encounter is WindkeeperPressureEncounter and encounter.health.terminal and actor_hp>0 and app.lifetime.active:
		pressure_settlement=await _collect_pressure_coins(stage,encounter as WindkeeperPressureEncounter)
	if pressure_pilot!=null and (not is_instance_valid(encounter) or not is_instance_valid(stage) or not is_instance_valid(app.controller) or not app.lifetime.active or app.director.state!=DemoRunDirector.State.IN_STAGE):
		await _finish_pressure_released_receipt(actual_map_identity,pressure_settlement)
		return
	await frames(60)
	if pressure_pilot!=null and (not is_instance_valid(encounter) or not is_instance_valid(stage) or not is_instance_valid(app.controller) or not app.lifetime.active or app.director.state!=DemoRunDirector.State.IN_STAGE):
		await _finish_pressure_released_receipt(actual_map_identity,pressure_settlement)
		return
	if not app.director.stage_complete:failure.append("actual defeat did not settle stage complete")
	if map_index==2 and (app.current_reward==null or not app.current_reward.gold):failure.append("actual main defeat did not create guaranteed GOLD offer")
	var settlement:Dictionary={"stage_complete":app.director.stage_complete,"reward_available":stage.reward_available,"reward_offer":String(app.current_reward.offer_id) if app.current_reward!=null else "","gold":app.current_reward.gold if app.current_reward!=null else false,"mini_recorded":app.director.manifest.snapshot().stages[0].outputs.has("mini_boss_reward")}
	if encounter is WindkeeperPressureEncounter:settlement["pressure_physical_coins"]=pressure_settlement
	# After combat, verify the actual one-time business settlement. UI positioning
	# below is explicitly post-victory, never a mid-fight movement substitute.
	if not encounter.health.terminal:
		settlement["claim_skipped_because_failed_battle"]=true
	elif map_index==1:
		var before_coins:=app.wallet.balance
		app.player.reset_at(stage.reward_position)
		await frames(3)
		settlement["mini_exit_open"]=app.exit_modal.opened
		settlement["first_advance"]=app._confirm_generated_exit()
		settlement["repeat_advance_rejected"]=not app._confirm_generated_exit()
		settlement["coin_delta"]=app.wallet.balance-before_coins
		if not settlement.first_advance or not settlement.repeat_advance_rejected or settlement.coin_delta!=12:failure.append("actual mini reward does not settle exactly once")
		await frames(8)
		settlement["next_map"]=app.director.stage_index
		if app.director.stage_index!=2:failure.append("actual mini reward does not advance once to map2")
	elif app.current_reward!=null:
		var offer:=app.current_reward
		app.player.reset_at(stage.reward_position)
		await frames(3)
		settlement["gold_exit_open"]=app.exit_modal.opened
		app._confirm_generated_exit()
		await frames(2)
		settlement["gold_choice_open"]=app.reward_modal.opened
		var selected:StringName=offer.candidates[0].stable_id
		settlement["first_claim"]=app._claim_modal_item(selected)
		settlement["repeat_claim_rejected"]=not app._claim_modal_item(selected)
		await frames(5)
		settlement["completed_biomes"]=app.meta.snapshot().completed_biomes
		settlement["returned_home"]=app.director.state==DemoRunDirector.State.HOME
		settlement["gold_instances"]=app.build.count_item(selected)
		if not settlement.first_claim or not settlement.repeat_claim_rejected or settlement.gold_instances!=1:failure.append("actual main Gold does not settle exactly once")
		# Current two-region play continues through a separate core reward. These
		# are real production modal callbacks after the uninterrupted Boss battle.
		settlement["core_choice_open"]=app.progression_modal.opened and app.campaign.phase==RunCampaignProgression.Phase.ABILITY_CHOICE
		settlement["gold_does_not_grant_hook"]=not app.controller.traversal.hook_enabled
		if not settlement.core_choice_open or not settlement.gold_does_not_grant_hook or settlement.returned_home or settlement.completed_biomes!=0:failure.append("actual Gold must open the separate current core reward without ending the run")
		var previous_region_token := app.lifetime.token()
		var previous_stage_epoch := app.lifetime.stage_epoch
		var continuing_player_id := app.player.get_instance_id()
		app.progression_modal.ability_selected.emit(&"grapple")
		settlement["grapple_granted_once"]=app.controller.traversal.hook_enabled and app.campaign.abilities==[&"grapple"]
		settlement["region_choice_open"]=app.progression_modal.opened and app.campaign.phase==RunCampaignProgression.Phase.REGION_CHOICE
		var selected_core_snapshot := app.director.manifest.canonical_json()
		app.progression_modal.ability_selected.emit(&"grapple")
		settlement["duplicate_core_has_no_effect"]=app.campaign.abilities==[&"grapple"] and app.director.manifest.canonical_json()==selected_core_snapshot
		if not settlement.grapple_granted_once or not settlement.region_choice_open or not settlement.duplicate_core_has_no_effect:failure.append("actual core modal must grant grapple once and open region selection")
		app.progression_modal.region_selected.emit(&"thorn_forest")
		await frames(8)
		settlement["forest_entered"]=app.stage is ThornForestRegionStage and app.stage.assembly_ok and app.stage.map_index==1 and app.active_region_id==&"thorn_forest" and app.campaign.phase==RunCampaignProgression.Phase.PLAYING
		settlement["forest_version"]=str(app.stage.generated.manifest.version) if app.stage is ThornForestRegionStage else ""
		settlement["forest_layout"]=str(app.stage.generated.manifest.layout_version) if app.stage is ThornForestRegionStage else ""
		settlement["same_player_with_grapple"]=app.player.get_instance_id()==continuing_player_id and app.controller.traversal.hook_enabled and app.campaign.abilities==[&"grapple"] and app.build.count_item(selected)==1
		settlement["previous_region_token_rejected"]=not app.lifetime.accepts(previous_region_token) and app.lifetime.stage_epoch>previous_stage_epoch
		if not settlement.forest_entered or settlement.forest_version!="thorn-forest-region-v2" or settlement.forest_layout!="forest-bible-world-v15" or not settlement.same_player_with_grapple or not settlement.previous_region_token_rejected:failure.append("actual post-Boss region selection must assemble the default forest with retained Gold, one grapple and a fresh stage token")
	DirAccess.make_dir_recursive_absolute("res://build/underworld_r3/boss")
	var file:=FileAccess.open("res://build/underworld_r3/boss/full_fight_map%d.json"%map_index,FileAccess.WRITE)
	file.store_string(JSON.stringify({"map":map_index,"actual_map_index":actual_map_identity.map_index,"manifest_seed":actual_map_identity.manifest_seed,"manifest_hash":actual_map_identity.manifest_hash,"failures":failure,"initial_room_placement_fixture":true,"no_midfight_injection":true,"requested_shots":shots,"accepted_shots":accepted_shots,"damage_events":damage_events,"roll_crossings":crossed,"visited":visited.keys(),"boss_hp":hp,"player_hp":actor_hp,"settlement":settlement,"trace":trace,"pressure_input_adapter":pressure_pilot!=null,"pressure_navigation_sha256":FileAccess.get_sha256("res://tools/windkeeper_pressure_01/legal_input_pilot.gd") if pressure_pilot!=null else "","pressure_input_profile":"canonical active_assault legal-input profile; its guarded extras and exact escape requests are counted; external duplicate shots disabled; original7200 combat frames unchanged; not cautious2 safety proof" if pressure_pilot!=null else "classic original R3","pressure_extra_inputs":pressure_extra_inputs,"pressure_pilot_inputs":pressure_pilot.input_rows if pressure_pilot!=null else []},"\t"));file.close()
	app.abandon_run();await load("res://tests/audio_teardown.gd").drain_world(app);app.free();await frames(5)
	print("UNDERWORLD R3 FULL BOSS MAP%d: %d frames, %d failures"%[map_index,trace.size(),failure.size()]);quit(1 if not failure.is_empty() else 0)


func _pressure_units(stage:PlainsRegionStage)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for pickup:Dictionary in stage.pickups:
		if str(pickup.get("source",""))==WindkeeperPressureRewards.SOURCE:
			result.append(pickup.duplicate(true))
	return result


func _pressure_extra_shot(encounter:WindkeeperPressureEncounter)->bool:
	# A native full-consumer strategy may exploit a real opening during an
	# advertised preparation. It never commands Boss state, HP or timestamps.
	var player:=app.player as PlayerMotor
	var controller:=app.controller
	if pressure_pilot.cross_axis!=0 or pressure_pilot.frame<pressure_pilot.jump_until or not player.is_on_floor():return false
	if encounter.mode not in [&"approach",&"stomp_warning",&"seeds_warning",&"gust_warning",&"sweep_warning",&"platform_warning"] or encounter.clock<=.36:return false
	var distance:=absf(player.global_position.x-encounter.motor.global_position.x)
	if distance<240:return false
	if controller.shoot_ability.cooldown_remaining>0 or controller.action_resources.shot_charges<=0 or (controller.shot_energy!=null and not controller.shot_energy.can_fire()):return false
	var at:=player.global_position
	var pose:Dictionary=encounter.rig_pose()
	var aim:Vector2=pressure_pilot._clear_body_aim(app,pose,at,encounter.motor.to_global(encounter.core_offset()))
	if not pressure_pilot._shot_clear(app,at,aim):return false
	var direction:Vector2=player.get_node("KeyboardMouseAdapter").world_direction(player.get_canvas_transform()*aim)
	var recoil_end:=at-direction*95
	var bounds:=Rect2(at-Vector2(12,18),Vector2(24,36)).expand(recoil_end-Vector2(12,18)).expand(recoil_end+Vector2(12,18))
	for shot:BossProjectile in encounter._projectiles:
		if not is_instance_valid(shot) or shot.spent or shot.is_queued_for_deletion():continue
		if shot is WindkeeperPressureStrike:return false
		var travel:Vector2=shot.direction*shot.speed*.9
		if DemoContactEmitter.segment_intersects_bounds(shot.global_position,shot.global_position+travel,bounds.grow(shot.radius+7)):return false
	# Require true support across the predicted horizontal recoil corridor;
	# never assume old fixed Boss ground height or teleport over a broken gap.
	for fraction:float in [0.0,.33,.66,1.0]:
		var foot:=Vector2(lerpf(at.x,recoil_end.x,fraction),at.y+17)
		var query:=PhysicsRayQueryParameters2D.create(foot,foot+Vector2(0,35),1,[player.get_rid()])
		var support:=player.get_world_2d().direct_space_state.intersect_ray(query)
		if support.is_empty() or (support.normal as Vector2).dot(Vector2.UP)<.7:return false
	var submitted:=controller.router.request_action(&"shoot_release",direction)
	if submitted:pressure_extra_inputs.append({"tick":Engine.get_physics_frames(),"mode":String(encounter.mode),"remaining_warning":encounter.clock,"player":[at.x,at.y],"direction":[direction.x,direction.y],"kind":"legal_extra_attack_phase_shot","no_Boss_or_player_state_injection":true})
	return submitted


func _collect_pressure_coins(stage:PlainsRegionStage,encounter:WindkeeperPressureEncounter)->Dictionary:
	# The old full-consumer already permits post-victory positioning for its UI
	# checks. Keep that separate from the uninterrupted legal-input fight and
	# from the natural review film. Currency still comes ONLY from real units
	# entering the original proximity/ready_at/once-only pickup consumer.
	var before_coins:=app.wallet.balance
	var original_position:=app.player.global_position
	var expected: int=(encounter.definition as WindkeeperPressureDefinition).reward_coin_total
	var result:Dictionary={"post_victory_position_fixture":true,"original_position":[original_position.x,original_position.y],"post_victory_position":[stage.reward_position.x,stage.reward_position.y],"configured_total":expected,"trace":[]}
	app.controller.router.clear("r3_post_victory_coin_ui_position")
	app.player.reset_at(stage.reward_position)
	var collector:RefCounted=load("res://tools/windkeeper_pressure_01/legal_input_pilot.gd").new()
	collector.mode="cautious2"
	var completed:=false
	for tick:int in 360:
		if not is_instance_valid(stage) or app.stage!=stage or not app.lifetime.active or not is_instance_valid(app.controller):break
		var units:=_pressure_units(stage)
		var snapshots:Array[Dictionary]=[]
		for unit:Dictionary in units:snapshots.append(PlainsLootMotion.snapshot(unit))
		result.trace.append({"tick":Engine.get_physics_frames(),"wallet_delta":app.wallet.balance-before_coins,"units":snapshots})
		if not units.is_empty() and units.all(func(unit:Dictionary)->bool:return bool(unit.claimed)):
			completed=true;break
		# Stand at the authored safe landing while coins are airborne; navigate
		# only to units with real completed support, not after a falling item.
		var settled:Array[Dictionary]=[]
		for unit:Dictionary in units:
			if bool(unit.claimed) or bool(unit.get("loot_settled",false)):settled.append(unit)
		collector.step(app,encounter,encounter.combat_metrics(),settled)
		await frames(1)
	if not is_instance_valid(stage) or app.stage!=stage or not is_instance_valid(app.controller) or not app.lifetime.active:
		result["arena_released_before_coin_completion"]=true
		failure.append("actual Pressure physical coin collection lost its live arena before completion")
		return result
	var final_units:=_pressure_units(stage)
	var unique:Dictionary={}
	var amount:=0
	var original_claims:=true
	for unit:Dictionary in final_units:
		unique[str(unit.id)]=true
		amount+=int(unit.amount)
		original_claims=original_claims and bool(unit.claimed) and stage.region_state.claimed.has(unit.id) and float(unit.get("claimed_at",-1))>=float(unit.get("ready_at",0))
	result["all_claimed"]=completed
	result["unique_units"]=unique.size()
	result["actual_units"]=final_units.size()
	result["actual_total"]=amount
	result["wallet_delta"]=app.wallet.balance-before_coins
	result["original_per_unit_claims"]=original_claims
	if not completed or unique.size()!=final_units.size() or amount!=expected or result.wallet_delta!=expected or not original_claims:
		failure.append("actual Pressure physical coin units did not settle and claim exactly once before GOLD")
	return result


func _finish_pressure_released_receipt(identity:Dictionary,coin_settlement:Dictionary={})->void:
	# This is an observable FAILED attempt, never a success substitute. The App
	# may legitimately free the defeated player's arena before this coroutine
	# resumes. Use only actual cached resource owners and last-live observations.
	var hp:float=pressure_boss_health.current if pressure_boss_health!=null else float(pressure_last_live.get("boss_hp",0))
	var actor_hp:float=pressure_player_health.current if pressure_player_health!=null else float(pressure_last_live.get("player_hp",0))
	if hp>0 and not failure.has("actual continuous full fight did not defeat Boss"):
		failure.append("actual continuous full fight did not defeat Boss")
	if actor_hp<=0 or not app.lifetime.active:
		if not failure.has("player failed actual continuous battle"):failure.append("player failed actual continuous battle")
	failure.append("actual Pressure full battle released its arena before successful settlement")
	var settlement:Dictionary={"claim_skipped_because_failed_battle":true,"arena_released_before_settlement":true,"pressure_physical_coins":coin_settlement}
	DirAccess.make_dir_recursive_absolute("res://build/underworld_r3/boss")
	var file:=FileAccess.open("res://build/underworld_r3/boss/full_fight_map%d.json"%map_index,FileAccess.WRITE)
	file.store_string(JSON.stringify({"map":map_index,"actual_map_index":identity.map_index,"manifest_seed":identity.manifest_seed,"manifest_hash":identity.manifest_hash,"failures":failure,"initial_room_placement_fixture":true,"no_midfight_injection":true,"requested_shots":shots,"accepted_shots":accepted_shots,"damage_events":damage_events,"roll_crossings":crossed,"visited":visited.keys(),"boss_hp":hp,"player_hp":actor_hp,"settlement":settlement,"trace":trace,"pressure_input_adapter":true,"pressure_navigation_sha256":FileAccess.get_sha256("res://tools/windkeeper_pressure_01/legal_input_pilot.gd"),"pressure_input_profile":"canonical active_assault legal-input profile; its guarded extras and exact escape requests are counted; external duplicate shots disabled; original7200 combat frames unchanged; not cautious2 safety proof","pressure_extra_inputs":pressure_extra_inputs,"pressure_pilot_inputs":pressure_pilot.input_rows,"arena_released":true,"last_live_snapshot":pressure_last_live,"combat_frame_limit":7200},"\t"));file.close()
	if is_instance_valid(app):
		app.abandon_run()
		await load("res://tests/audio_teardown.gd").drain_world(app)
		app.free()
	await frames(5)
	print("UNDERWORLD R3 FULL BOSS MAP%d: %d frames, %d failures"%[map_index,trace.size(),failure.size()])
	quit(1)
