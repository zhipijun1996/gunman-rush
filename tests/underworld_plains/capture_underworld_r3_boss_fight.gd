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
func _initialize()->void:run.call_deferred()
func frames(n:int)->void:
	for i:int in n:await physics_frame
func run()->void:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):map_index=int(arg.trim_prefix("--map="))
	app=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
	app.start_plains("underworld-r3-continuous-boss")
	await frames(8)
	if map_index==2:
		app.director.stage_index=2;app._load_stage();await frames(8)
	var stage:=app.stage as PlainsRegionStage
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
	var hp:=encounter.health.current
	var actor_hp:=app.controller.actor_resources.health.current if is_instance_valid(app.controller) else 0.0
	if not encounter.health.terminal:failure.append("actual continuous full fight did not defeat Boss")
	if actor_hp<=0 or not app.lifetime.active:failure.append("player failed actual continuous battle")
	await frames(60)
	if not app.director.stage_complete:failure.append("actual defeat did not settle stage complete")
	if map_index==2 and (app.current_reward==null or not app.current_reward.gold):failure.append("actual main defeat did not create guaranteed GOLD offer")
	var settlement:Dictionary={"stage_complete":app.director.stage_complete,"reward_available":stage.reward_available,"reward_offer":String(app.current_reward.offer_id) if app.current_reward!=null else "","gold":app.current_reward.gold if app.current_reward!=null else false,"mini_recorded":app.director.manifest.snapshot().stages[0].outputs.has("mini_boss_reward")}
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
		if not settlement.first_claim or not settlement.repeat_claim_rejected or settlement.completed_biomes!=1 or not settlement.returned_home:failure.append("actual main Gold does not settle once and return home")
	DirAccess.make_dir_recursive_absolute("res://build/underworld_r3/boss")
	var file:=FileAccess.open("res://build/underworld_r3/boss/full_fight_map%d.json"%map_index,FileAccess.WRITE)
	file.store_string(JSON.stringify({"map":map_index,"failures":failure,"initial_room_placement_fixture":true,"no_midfight_injection":true,"requested_shots":shots,"accepted_shots":accepted_shots,"damage_events":damage_events,"roll_crossings":crossed,"visited":visited.keys(),"boss_hp":hp,"player_hp":actor_hp,"settlement":settlement,"trace":trace},"\t"));file.close()
	app.abandon_run();await load("res://tests/audio_teardown.gd").drain_world(app);app.free();await frames(5)
	print("UNDERWORLD R3 FULL BOSS MAP%d: %d frames, %d failures"%[map_index,trace.size(),failure.size()]);quit(1 if not failure.is_empty() else 0)
