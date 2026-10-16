extends SceneTree
## Formal entry -> continuous H route -> actual bullets/policy -> reward approach.
## Each map is an independent, explicitly recorded debug entry; no HP/phase/resource/position writes.
const TRACE := preload("res://tests/forest_region_trace.gd")
var assertions := 0
var failures := 0
var cases: Array[Dictionary] = []
var output_dir := "res://build/forest_playable/progression/combat"
var selected_map := 0
var seed_value := "forest-playable-00"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output_dir=arg.trim_prefix("--output-dir=")
		if arg.begins_with("--map="): selected_map=int(arg.trim_prefix("--map="))
		if arg.begins_with("--seed="): seed_value=arg.trim_prefix("--seed=")
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures+=1;printerr("FAIL: "+message)
func frames(count: int) -> void:
	for i: int in count: await physics_frame
func run() -> void:
	for map_index: int in [1,2]:
		if selected_map!=0 and map_index!=selected_map: continue
		await combat(map_index)
	DirAccess.make_dir_recursive_absolute(output_dir)
	FileAccess.open(output_dir+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"formal_debug_entries_each_map_actual_route_and_bullet_combat","initial_position_assignment":"only normal start_debug_region spawn","midroute_position_or_resource_injection":false,"manual_motor_step":false,"gui_claim":"gate owner confirmation API; actual Godot Viewport mouse buttons for final gold/core; no OS/Web native pointer claim","assertions":assertions,"failures":failures,"cases":cases}))
	print("FOREST CAMPAIGN COMBAT: %s assertions / %s failures" % [assertions,failures])
	quit(1 if failures else 0)
func combat(map_index: int) -> void:
	var trace := TRACE.new()
	trace.mode="region"
	trace.seed_value=seed_value
	trace.map_index=map_index
	trace.route_name="fast"
	root.add_child(trace)
	while not trace.finished: await process_frame
	var row := {"map_index":map_index,"debug_entry":true,"natural_previous_map_clear":false,"seed":seed_value,"route_errors":trace.route_errors.duplicate(),"route_completed_legs":trace.completed_legs.duplicate(true),"route_frames":trace.frames.duplicate(true),"route_events":trace.events.duplicate(true),"route_requests":trace.requests.duplicate(true),"combat_frames":[],"shot_requests":[],"accepted_shots":[],"committed_damage":[],"phases":[],"defeats":0,"seal_closed_seen":false,"eligible_shots_seen":false,"pointer_events":[]}
	cases.append(row)
	check(trace.route_errors.is_empty() and trace.completed_legs.size()==trace.itinerary.size(),"map%s actual formal H route reaches arena" % map_index)
	if not is_instance_valid(trace.app) or not is_instance_valid(trace.controller) or not trace.route_errors.is_empty():
		await cleanup(trace)
		return
	var app: DemoApp=trace.app
	var controller: PlayerController=trace.controller
	var player: PlayerMotor=trace.player
	var stage: ThornForestRegionStage=trace.stage
	var boss:=stage.boss.get_node("Encounter") as ThornForestEncounter
	row.initial_health=controller.actor_resources.health.current
	row.manifest_hash=stage.generated.manifest.manifest_hash
	check(stage.region_state.opened.has("crown_vine") and stage.assembler.vine_shape.disabled,"map%s actual H opens persistent forest entrance" % map_index)
	controller.shoot_ability.shot_fired.connect(func(aim: Vector2,id: int) -> void: row.accepted_shots.append({"id":id,"aim":[aim.x,aim.y],"session":controller.session_id}))
	app.policy.batch_resolved.connect(func(results: Array[DamageResult]) -> void:
		for result: DamageResult in results:
			row.committed_damage.append({"target":String(result.request.target_id),"source":String(result.request.source_id),"event_id":String(result.request.event_id),"amount":result.request.amount,"lethal":result.lethal}))
	boss.defeated.connect(func(_encounter: BossEncounter) -> void: row.defeats+=1)
	var next_shot:=0
	var last_mode: StringName=&""
	var center:=stage.boss_arena.get_center().x
	var destination:=center-260
	for tick: int in 10000:
		if boss.health.terminal or controller.actor_resources.health.terminal or not app.lifetime.active: break
		if not row.phases.has(boss.stage_phase): row.phases.append(boss.stage_phase)
		if boss.mode!=last_mode:
			last_mode=boss.mode
			if boss.mode==&"branch_warning": destination=center-260 if player.global_position.x>center else center+260
			elif boss.core_open: destination=center-230 if boss.stage_phase==1 or boss.weak_side<0 else center+230
		var offset:=destination-player.global_position.x
		controller.router.set_move_axis(0 if absf(offset)<12 else signf(offset))
		if boss.core_open and tick>=next_shot and (boss.stage_phase==1 or (player.global_position.x-center)*boss.weak_side>60):
			var aim: Vector2=(boss.motor.global_position-player.global_position).normalized()
			row.shot_requests.append({"tick":tick,"queued":controller.router.request_action(&"shoot_release",aim),"position":[player.global_position.x,player.global_position.y],"aim":[aim.x,aim.y]})
			next_shot=tick+30
		await frames(1)
		row.seal_closed_seen=bool(row.seal_closed_seen) or stage.boss_seal.closed
		row.eligible_shots_seen=bool(row.eligible_shots_seen) or not app._boss_eligible_shots.is_empty()
		row.combat_frames.append({"tick":tick,"position":[player.global_position.x,player.global_position.y],"hp":controller.actor_resources.health.current,"boss_hp":boss.health.current,"mode":String(boss.mode),"phase":boss.stage_phase,"weak_side":boss.weak_side,"core_open":boss.core_open,"active":boss.active,"seal_closed":stage.boss_seal.closed,"eligible_shots":app._boss_eligible_shots.size(),"energy":controller.actor_resources.stamina.current,"actor_epoch":app.lifetime.actor_epoch,"stage_epoch":app.lifetime.stage_epoch,"axis":controller.router.axis})
	controller.router.set_move_axis(0)
	check(boss.health.terminal and int(row.defeats)==1,"map%s actual formal bullets defeat Boss exactly once" % map_index)
	check(row.phases.has(2) and (map_index==1 or row.phases.has(3)),"map%s full real fight reaches each phase" % map_index)
	check(row.seal_closed_seen and row.eligible_shots_seen,"map%s formal seal and eligible-shot gate actually engage" % map_index)
	check(row.committed_damage.any(func(d: Dictionary)->bool:return d.target=="boss" and d.source.begins_with("player_projectile:")),"map%s actual FrameDamagePolicy commits player bullets" % map_index)
	check(app.director.stage_complete and not controller.actor_resources.health.terminal,"map%s formal completion succeeds while player survives" % map_index)
	if boss.health.terminal and not controller.actor_resources.health.terminal:
		await frames(60)
		for tick: int in 500:
			if app.exit_modal.opened: break
			controller.router.set_move_axis(signf(stage.reward_position.x-player.global_position.x) if absf(stage.reward_position.x-player.global_position.x)>5 else 0)
			await frames(1)
		controller.router.set_move_axis(0)
		row.reward_approach_position=[player.global_position.x,player.global_position.y]
		row.reward_stand=[stage.reward_position.x,stage.reward_position.y]
		check(app.exit_modal.opened and app._offered_exit==&"boss_home","map%s actual walk reaches unique reward gate" % map_index)
		if app.exit_modal.opened:
			check(app._confirm_generated_exit(),"map%s reward owner accepts confirmed gate" % map_index)
			if map_index==2:
				check(app.reward_modal.opened and app.current_reward.gold and app.current_reward.candidates[0].stable_id==&"forest_heart_gold","queen death provides independent guaranteed forest GOLD")
				check(await pointer_pick(app.reward_modal,"选择 / PICK",row) and app.build.count_item(&"forest_heart_gold")==1,"actual mouse button claims combat-earned unique gold")
				check(not app._claim_modal_item(&"forest_heart_gold") and app.build.count_item(&"forest_heart_gold")==1,"already claimed combat gold rejects duplicate submission")
				check(await pointer_pick(app.progression_modal,"D / DOUBLE JUMP",row) and controller.traversal.double_enabled,"actual mouse button grants legal combat-earned D")
			else:
				await frames(10)
				check(app.director.region_map_index==2 and app.stage is ThornForestRegionStage,"actual guardian reward opens map2")
	row.final_player_health=controller.actor_resources.health.current
	row.boss_defeated=boss.health.terminal if is_instance_valid(boss) else true
	await cleanup(trace)
func pointer_pick(owner: Node, prefix: String, row: Dictionary) -> bool:
	for i: int in 4: await process_frame
	for button: Button in owner.find_children("*","Button",true,false):
		if not button.visible or button.disabled or not button.text.begins_with(prefix): continue
		var point := button.get_global_rect().get_center()
		for pressed: bool in [true,false]:
			var event:=InputEventMouseButton.new()
			event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
			row.pointer_events.append({"button":button.text,"pressed":pressed,"point":[point.x,point.y]})
			root.push_input(event,true)
			await process_frame
		return true
	return false
func cleanup(trace: Node) -> void:
	paused=false
	if is_instance_valid(trace.app):
		check(await preload("res://tests/audio_teardown.gd").drain_world(trace.app),"actual formal audio teardown releases")
	trace.free()
	await process_frame
	await process_frame
