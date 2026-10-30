extends SceneTree
## One complete actual formal encounter. Only the initial room placement is a
## fixture; no HP/phase/resource injection, mid-fight teleport or stopped AI.
## Optional Godot --write-movie captures this same normal-clock driver.
const BELL_PILOT := preload("res://tools/bellstrider_01/legal_input_pilot.gd")
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
var bell_pilot: RefCounted
var terminal_trace: Array[Dictionary] = []
var final_bell_metrics: Dictionary = {}
var final_bell_units: Array[Dictionary] = []
func _initialize()->void:run.call_deferred()
func frames(n:int)->void:
	for i:int in n:await physics_frame
func bell_units(stage: PlainsRegionStage) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var source := BellstriderRewards.source_id(stage)
	for pickup: Dictionary in stage.pickups:
		if str(pickup.get("source",""))==source and pickup.get("kind","")=="coin": result.append(pickup.duplicate(true))
	return result
func stop_bell_inputs() -> void:
	app.controller.router.set_source_axis(&"keyboard_mouse",0.0)
	app.controller.router.set_jump_held(&"keyboard_mouse",false)
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
	app.controller.shoot_ability.shot_fired.connect(func(_aim:Vector2,_id:int)->void:accepted_shots+=1)
	app.policy.batch_resolved.connect(func(results:Array[DamageResult])->void:
		for result:DamageResult in results:
			damage_events.append({"tick":Engine.get_physics_frames(),"target":String(result.request.target_id),"event":String(result.request.event_id),"amount":result.request.amount,"health":result.health.current}))
	# Explicit room-entry fixture. All later movement is the actual Router/Motor.
	app.player.reset_at(boss.global_position+Vector2(-250,47))
	await frames(5)
	if not app._boss_started:failure.append("actual core entry failed to activate Boss")
	if encounter.health.current!=encounter.health.capacity:failure.append("fight did not start at full actual Boss HP")
	var wallet_start := app.wallet.balance
	if map_index==1:
		if not encounter is BellstriderEncounter or not encounter.definition is BellstriderDefinition or encounter.health.capacity!=40 or encounter.health.current!=40: failure.append("current Bell full fight must start at actual forty HP and current Definition")
		if not is_equal_approx(app.controller.shoot_ability.weapon.damage,1.0): failure.append("current Bell full fight must use actual base-one weapon damage")
		bell_pilot = BELL_PILOT.new()
		bell_pilot.mode = "cautious2"
	var previous_side := 0
	var start_tick:=Engine.get_physics_frames()
	for tick:int in 7200:
		if not is_instance_valid(app.controller) or app.director.state!=DemoRunDirector.State.IN_STAGE:break
		if encounter.health.terminal:break
		var player:=app.player as PlayerMotor
		var controller:=app.controller
		var dx:=boss.global_position.x-player.global_position.x
		var grounded:=player.is_on_floor()
		visited[str(encounter.stage_phase)]=true
		var axis:=0.0
		if map_index==1:
			bell_pilot.step(app,encounter,(encounter as BellstriderEncounter).combat_metrics(),bell_units(stage))
			axis = controller.router.axis
			shots = bell_pilot.input_rows.filter(func(row: Dictionary) -> bool: return row.get("action","")=="shoot_release" and bool(row.get("submitted",false))).size()
			var side := int(signf(dx))
			if previous_side!=0 and side!=0 and side!=previous_side and encounter.mode==&"roll": crossed+=1
			previous_side = side
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
		if map_index!=1:
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
	var hp:=encounter.health.current
	var actor_hp:=app.controller.actor_resources.health.current if is_instance_valid(app.controller) else 0.0
	if not encounter.health.terminal:failure.append("actual continuous full fight did not defeat Boss")
	if actor_hp<=0 or not app.lifetime.active:failure.append("player failed actual continuous battle")
	if map_index==1 and encounter.health.terminal:
		bell_pilot.step(app,encounter,(encounter as BellstriderEncounter).combat_metrics(),bell_units(stage))
	# Keep the original post-victory observation, then independently verify the
	# new bounded wreck and physical pickup contract using only legal inputs.
	await frames(60)
	if map_index==1 and encounter.health.terminal and actor_hp>0 and app.lifetime.active:
		for tick: int in 300:
			final_bell_metrics = (encounter as BellstriderEncounter).combat_metrics()
			final_bell_units = bell_units(stage)
			terminal_trace.append({"tick":Engine.get_physics_frames(),"death_age":final_bell_metrics.get("death_age",0),"wallet":app.wallet.balance,"player":[app.player.global_position.x,app.player.global_position.y],"units":final_bell_units.duplicate(true)})
			if float(final_bell_metrics.get("death_age",0))>=1.8 and final_bell_units.size()==4 and final_bell_units.all(func(unit: Dictionary) -> bool: return bool(unit.claimed)): break
			bell_pilot.step(app,encounter,final_bell_metrics,final_bell_units)
			await frames(1)
		stop_bell_inputs()
		if int(final_bell_metrics.get("accepted_hits",0))!=40 or not is_equal_approx(float(final_bell_metrics.get("accepted_damage",0)),40.0): failure.append("actual full forty HP did not resolve through forty real base-one HP-changing hits")
		var denominations: Array[int] = []
		for unit: Dictionary in final_bell_units: denominations.append(int(unit.amount))
		denominations.sort()
		if float(final_bell_metrics.get("death_age",0))<1.8 or denominations!=[1,1,5,5] or not final_bell_units.all(func(unit: Dictionary) -> bool: return bool(unit.claimed)) or app.wallet.balance-wallet_start!=12: failure.append("actual full wreck and four physical coin pickups did not settle exactly twelve before portal")
	if not app.director.stage_complete:failure.append("actual defeat did not settle stage complete")
	if map_index==2 and (app.current_reward==null or not app.current_reward.gold):failure.append("actual main defeat did not create guaranteed GOLD offer")
	var settlement:Dictionary={"stage_complete":app.director.stage_complete,"reward_available":stage.reward_available,"reward_offer":String(app.current_reward.offer_id) if app.current_reward!=null else "","gold":app.current_reward.gold if app.current_reward!=null else false,"mini_recorded":app.director.manifest.snapshot().stages[0].outputs.has("mini_boss_reward")}
	# After combat, verify the actual one-time business settlement. UI positioning
	# below is explicitly post-victory, never a mid-fight movement substitute.
	if not encounter.health.terminal:
		settlement["claim_skipped_because_failed_battle"]=true
	elif map_index==1:
		var before_coins:=app.wallet.balance
		var before_health := app.controller.actor_resources.health.current
		var health_capacity := app.controller.actor_resources.health.capacity
		settlement["physical_coin_delta_before_portal"] = before_coins-wallet_start
		settlement["physical_units_claimed_before_UI_fixture"] = final_bell_units.size()==4 and final_bell_units.all(func(unit: Dictionary) -> bool: return bool(unit.claimed))
		app.player.reset_at(stage.reward_position)
		await frames(3)
		settlement["mini_exit_open"]=app.exit_modal.opened
		settlement["first_advance"]=app._confirm_generated_exit()
		settlement["repeat_advance_rejected"]=not app._confirm_generated_exit()
		settlement["coin_delta"]=app.wallet.balance-before_coins
		settlement["heal_delta"] = app.controller.actor_resources.health.current-before_health
		var output: Dictionary = app.director.manifest.snapshot().stages[0].outputs.get("mini_boss_reward",{})
		settlement["mini_reward_receipt"] = output
		settlement["heal_clamped_at_full"] = before_health==health_capacity
		if not settlement.first_advance or not settlement.repeat_advance_rejected or settlement.coin_delta!=0 or settlement.physical_coin_delta_before_portal!=12 or not settlement.physical_units_claimed_before_UI_fixture: failure.append("actual mini physical reward must pay exactly twelve once and portal must add no duplicate coins")
		if output.get("heal",0)!=1 or output.get("coin_delivery","")!="physical_pickups" or not is_equal_approx(float(settlement.heal_delta),minf(1.0,health_capacity-before_health)): failure.append("actual mini portal must retain one-heart heal with the real capacity clamp")
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
	file.store_string(JSON.stringify({"map":map_index,"actual_map_index":actual_map_identity.map_index,"manifest_seed":actual_map_identity.manifest_seed,"manifest_hash":actual_map_identity.manifest_hash,"failures":failure,"initial_room_placement_fixture":true,"no_midfight_injection":true,"requested_shots":shots,"accepted_shots":accepted_shots,"damage_events":damage_events,"roll_crossings":crossed,"visited":visited.keys(),"boss_hp":hp,"player_hp":actor_hp,"settlement":settlement,"trace":trace,"terminal_trace":terminal_trace,"bell_metrics":final_bell_metrics,"bell_units":final_bell_units,"automated_player":"read-only legal_input_pilot cautious2 for current Bell; original map2 pilot unchanged","bell_inputs":bell_pilot.input_rows if bell_pilot!=null else []},"\t"));file.close()
	app.abandon_run();await load("res://tests/audio_teardown.gd").drain_world(app);app.free();await frames(5)
	print("UNDERWORLD R3 FULL BOSS MAP%d: %d frames, %d failures"%[map_index,trace.size(),failure.size()]);quit(1 if not failure.is_empty() else 0)
