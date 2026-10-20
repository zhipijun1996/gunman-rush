extends "res://tests/support/forest_queen_gameplay_fixture.gd"
## Independent actual-App scenarios; inherited fixture world construction is never called.
## Guardian default preserves05; Queen branch is prepared, not yet native-verified.
const TRACE := preload("res://tests/forest_depth_region_trace.gd")
var output := "res://build/forest_depth/campaign/capture.json"
var seed_value := "forest-depth-hollow-00"
var checks: Array[Dictionary] = []
var pointer_events: Array[Dictionary] = []
var data: Dictionary = {}
var selected_boss := "guardian"
var _q_driver_phase := "entry"
var _q_combat_deadline := -1
var _q_app: DemoApp
var _q_segment := "before_reload"
var _q_last_steps := 0
var _q_defeats := 0
var _q_shot_source: ShootAbility
var _q_shot_callable: Callable
var _q_observed_actors: Array[WeakRef] = []
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		elif arg.begins_with("--seed="): seed_value=arg.trim_prefix("--seed=")
		elif arg.begins_with("--boss="): selected_boss=arg.trim_prefix("--boss=")
	run.call_deferred()
func check(ok: bool, reason: String) -> void:
	checks.append({"passed":ok,"reason":reason})
	if not ok: failures.append(reason);printerr("FAIL: "+reason)
func frames(count: int) -> void:
	for unused: int in count:
		if selected_boss=="queen" and _q_combat_deadline>=0 and tick>=_q_combat_deadline: return
		if selected_boss!="queen": await physics_frame;continue
		if is_instance_valid(controller):
			for action: Dictionary in controller.router._queue:
				events.append({"case":current,"event":"actual_queued_input","tick":tick+1,"segment":_q_segment,"session":controller.session_id,"action":String(action.type),"direction":_q_pair(action.direction)})
		await physics_frame
		await process_frame
		tick+=1
		if is_instance_valid(player) and is_instance_valid(queen): _queen_frame()
func run() -> void:
	if selected_boss=="canopy":
		var canopy_case: Node=load("res://tests/forest_depth_canopy_campaign_case.gd").new()
		canopy_case.output=output;canopy_case.seed_value=seed_value
		root.add_child(canopy_case);await canopy_case.run()
		var canopy_exit: int=0 if canopy_case.failures.is_empty() else 1
		canopy_case.free();quit(canopy_exit);return
	if selected_boss=="queen": await run_queen();return
	# Dynamically owned real Node, awaited and freed before the outer tree exits.
	var helper: Node=load("res://tests/forest_depth_guardian_campaign_case.gd").new()
	helper.output=output;helper.seed_value=seed_value
	root.add_child(helper)
	await helper.run()
	var exit_code: int=0 if helper.failures.is_empty() else 1
	helper.free()
	quit(exit_code)
func finish(trace: Node) -> void:
	paused=false
	if is_instance_valid(trace.app):
		trace.app.process_mode=Node.PROCESS_MODE_DISABLED
		trace.app._cancel_enemy_attacks()
		check(await AUDIO.drain_world(trace.app),"actual owned App audio releases cleanly")
	if selected_boss=="queen":
		if is_instance_valid(_q_shot_source) and _q_shot_callable.is_valid() and _q_shot_source.shot_fired.is_connected(_q_shot_callable):
			_q_shot_source.shot_fired.disconnect(_q_shot_callable)
		_q_shot_callable=Callable()
		_q_shot_source=null
	trace.free()
	await process_frame;await process_frame
	if selected_boss=="queen":
		var alive: Array[int]=[]
		for reference: WeakRef in _q_observed_actors:
			var actor: Object=reference.get_ref()
			if actor!=null: alive.append(actor.get_instance_id())
		data.queen_teardown={"observed_actors_alive":alive,"shot_source_cleared":_q_shot_source==null,"shot_callable_cleared":not _q_shot_callable.is_valid(),"scope":"WeakRefs to each actually bound Queen and ShootAbility after actual trace/App free and original two process frames; not proof of all ObjectDB resources"}
		check(alive.is_empty(),"actually observed Queen/shot-source actors release after App teardown")
	data.checks=checks;data.failures=failures;data.pointer_events=pointer_events
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
	print("FOREST DEPTH CAMPAIGN: %s assertions / %s failures" % [checks.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)


# Queen branch binds the actual App to the shared input helpers. It never calls
# fixture(), slab(), configure_arena(), activate(), grant() or a Factory itself.
func _queen_bind_actual(app: DemoApp) -> bool:
	if not is_instance_valid(app.stage) or not is_instance_valid(app.stage.boss) or not app.stage.boss.get_node("Encounter") is ThornQueenV2: return false
	# App reload keeps the player/controller but advances its session. Replace only
	# this observer binding so accepted shots retain their new real ownership.
	if is_instance_valid(_q_shot_source) and _q_shot_callable.is_valid() and _q_shot_source.shot_fired.is_connected(_q_shot_callable):
		_q_shot_source.shot_fired.disconnect(_q_shot_callable)
	_q_app=app
	player=app.player;controller=app.controller;queen=app.stage.boss.get_node("Encounter") as ThornQueenV2
	policy=app.policy;life=app.lifetime;geometry=queen.geometry
	actual_body_half=(player.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect().size*.5
	_q_last_steps=player.motion_steps
	if not queen.weave_event.is_connected(_queen_weave_event): queen.weave_event.connect(_queen_weave_event)
	if not policy.batch_resolved.is_connected(_queen_damage): policy.batch_resolved.connect(_queen_damage)
	queen.defeated.connect(func(_boss: BossEncounter) -> void: _q_defeats+=1)
	_q_shot_source=controller.shoot_ability
	_q_observed_actors.append(weakref(_q_shot_source));_q_observed_actors.append(weakref(queen))
	_q_shot_callable=_queen_shot.bind(controller.session_id,player.get_instance_id())
	_q_shot_source.shot_fired.connect(_q_shot_callable)
	if not controller.traversal.action_changed.is_connected(_queen_hook_state): controller.traversal.action_changed.connect(_queen_hook_state)
	if not controller.traversal.hook_contact.is_connected(_queen_contact): controller.traversal.hook_contact.connect(_queen_contact)
	return true
func _queen_frame() -> void:
	var sample:={"tick":tick,"physics_frame":Engine.get_physics_frames(),"segment":_q_segment,"player":_q_pair(player.global_position),"velocity":_q_pair(player.velocity),"player_hp":controller.actor_resources.health.current,"energy":controller.actor_resources.stamina.current,"capacity":controller.actor_resources.health.capacity,"session":controller.session_id,"actor_epoch":life.actor_epoch,"stage_epoch":life.stage_epoch,"motor_steps":player.motion_steps-_q_last_steps,"boss_hp":queen.health.current,"boss":_q_pair(queen.motor.global_position),"phase":queen.stage_phase,"route_phase":queen.route_phase,"mode":queen.motion_mode,"fields":queen.combat_snapshot().fields,"hook":String(controller.traversal.state),"seal":_q_app.stage.boss_seal.closed,"eligible":_q_app._boss_eligible_shots.size()}
	sample.driver_phase=_q_driver_phase
	sample.grounded=player.is_on_floor();sample.axis=controller.router.axis
	sample.used_jumps=controller.jump_ability.used_jumps;sample.air_shots=controller.action_resources.shot_charges
	sample.shot_cooldown=controller.shoot_ability.cooldown_remaining
	sample.damage_remaining=player.damage_remaining;sample.recoil_remaining=player.recoil_burst_remaining
	sample.normal_velocity=_q_pair(player.normal_velocity)
	var contacts: Array=[]
	for index: int in player.get_slide_collision_count():
		var hit:=player.get_slide_collision(index)
		contacts.append({"collider":str(hit.get_collider().get_path()),"normal":_q_pair(hit.get_normal())})
	sample.actual_contacts=contacts
	_q_last_steps=player.motion_steps
	frames_data.append(sample)
func _q_pair(value: Vector2) -> Array: return [value.x,value.y]
func _queen_weave_event(row: Dictionary) -> void:
	var event:=row.duplicate(true);event.case=current;event.tick=tick+1;event.segment=_q_segment;events.append(event)
func _queen_shot(aim: Vector2,serial: int,session: int,motor_id: int) -> void:
	events.append({"case":current,"event":"accepted_shot","tick":tick+1,"physics_frame":Engine.get_physics_frames(),"segment":_q_segment,"serial":serial,"session":session,"motor_id":motor_id,"aim":_q_pair(aim)})
func _queen_damage(results: Array[DamageResult]) -> void:
	for result: DamageResult in results:
		events.append({"case":current,"event":"policy_result","tick":tick+1,"physics_frame":Engine.get_physics_frames(),"segment":_q_segment,"target":String(result.request.target_id),"source":String(result.request.source_id),"event_id":String(result.request.event_id),"amount":result.request.amount,"hp":result.health.current if result.health!=null else -1,"lethal":result.lethal})
func _queen_hook_state(value: StringName) -> void:
	events.append({"case":current,"event":"hook_state","state":String(value),"tick":tick+1,"segment":_q_segment,"session":controller.session_id})
func _queen_contact(point: Vector2) -> void:
	var target: Node2D=controller.traversal.hook_target
	events.append({"case":current,"event":"actual_hook_target_contact","tick":tick+1,"segment":_q_segment,"point":_q_pair(point),"target_id":target.get_instance_id() if is_instance_valid(target) else 0,"target_position":_q_pair(target.global_position) if is_instance_valid(target) else []})
func _queen_bank(index: int) -> Rect2:
	for row: Dictionary in geometry.platforms:
		if str(row.id)=="queen_branch_%s"%index: return Rect2(row.rect[0],row.rect[1],row.rect[2],row.rect[3])
	return Rect2()
func _queen_gap() -> float:
	return (_queen_bank(1).end.x+_queen_bank(2).position.x)*.5
# Same real jump/R helpers as the canonical fixture, with targets translated
# from actual App geometry rather than assuming its zero-origin golden world.
func right_gap_approach() -> bool:
	_q_driver_phase="right_gap_approach"
	var middle:=_queen_bank(1)
	if player.global_position.x<middle.get_center().x:
		if not await walk(middle.position.x+middle.size.x*.2): return false
		controller.router.set_move_axis(1);controller.router.set_jump_held(&"queen_network",true)
		await frames(23);controller.router.set_jump_held(&"queen_network",false)
	if not await walk(_queen_gap()): return false
	for unused: int in 80:
		if player.is_on_floor(): return true
		await frames(1)
	return false
# Receiving-bank decisions use the actual collider size and authored bank, never
# just horizontal arrival (walk() alone can succeed after falling off a bank).
func _queen_full_support(bank: Rect2) -> bool:
	return player.is_on_floor() and absf(player.global_position.y+actual_body_half.y-bank.position.y)<=1 and player.global_position.x-actual_body_half.x>=bank.position.x and player.global_position.x+actual_body_half.x<=bank.end.x
func _queen_observed_jump() -> bool:
	if not player.is_on_floor() or player.damage_remaining>0: return false
	var prior_jumps:=controller.jump_ability.used_jumps
	var accepted:=false
	controller.router.set_jump_held(&"queen_network",true)
	for unused: int in 23:
		await frames(1)
		accepted=accepted or controller.jump_ability.used_jumps>prior_jumps
		if controller.actor_resources.health.terminal or player.damage_remaining>0 or (_q_combat_deadline>=0 and tick>=_q_combat_deadline):
			controller.router.set_jump_held(&"queen_network",false)
			return false
	controller.router.set_jump_held(&"queen_network",false)
	return accepted and not player.is_on_floor()
func enter_upper(use_hook: bool) -> bool:
	_q_driver_phase="enter_upper_approach"
	if not await right_gap_approach(): return false
	_q_driver_phase="enter_upper_jump"
	if not await _queen_observed_jump(): return false
	if use_hook and not queen.knot.health.terminal:
		if not await accepted_hook(queen.knot.global_position): return false
	else:
		# A hurt-cancelled jump cannot borrow the planned jump height. Only fire
		# when the actual airborne position plus the current real R budget clears
		# the receiving bank; the accepted action still owns all motion/resources.
		var rise:=player.weapon_motion.base_distance(controller.shoot_ability.tuning,false)
		if player.global_position.y+actual_body_half.y-rise>=_queen_bank(2).position.y: return false
		_q_driver_phase="enter_upper_down_R"
		controller.router.request_action(&"shoot_release",Vector2.DOWN);await frames(15)
	if player.damage_remaining>0 or player.global_position.y+actual_body_half.y>=_queen_bank(2).position.y: return false
	_q_driver_phase="enter_upper_left_R"
	controller.router.request_action(&"shoot_release",Vector2.LEFT);await frames(15)
	_q_driver_phase="enter_upper_receive"
	var bank:=_queen_bank(2)
	var target:=bank.get_center().x
	for unused: int in 100:
		controller.router.set_move_axis(0 if absf(player.global_position.x-target)<7 else signf(target-player.global_position.x))
		if player.is_on_floor(): controller.router.set_move_axis(0);return _queen_full_support(bank)
		await frames(1)
	return false
func move_to_middle() -> bool:
	_q_driver_phase="move_to_middle"
	var right:=_queen_bank(2);var middle:=_queen_bank(1)
	var takeoff:=right.position.x+right.size.x*.3
	if player.global_position.x>takeoff:
		if not await walk(takeoff): return false
	controller.router.set_move_axis(-1 if player.global_position.x>middle.get_center().x else 1)
	if not await _queen_observed_jump(): return false
	if not await walk(middle.get_center().x): return false
	for unused: int in 100:
		if player.is_on_floor(): return _queen_full_support(middle)
		await frames(1)
	return false
func _queen_regain_middle() -> bool:
	_q_driver_phase="regain_wait_floor"
	controller.router.set_move_axis(0)
	for unused: int in 160:
		if (player.is_on_floor() and player.damage_remaining<=0) or controller.actor_resources.health.terminal: break
		await frames(1)
	if controller.actor_resources.health.terminal or not player.is_on_floor() or player.damage_remaining>0: return false
	var middle:=_queen_bank(1)
	if _queen_full_support(middle):
		if not await walk(middle.get_center().x): return false
		return _queen_full_support(middle)
	if not _queen_full_support(_queen_bank(2)) and not await enter_upper(false): return false
	return await move_to_middle()
func continuous_fire() -> void:
	# The shared helper checks recoil containment after it finds a complete bank.
	# Fail closed here when contact exists only at an edge, so that absence of a
	# full bank cannot fall through into an otherwise legal but unreceivable R.
	if player.is_on_floor():
		var supported:=false
		var partial:=Rect2()
		for row: Dictionary in geometry.platforms:
			var bank:=Rect2(row.rect[0],row.rect[1],row.rect[2],row.rect[3])
			if _queen_full_support(bank): supported=true;break
			if absf(player.global_position.y+actual_body_half.y-bank.position.y)<=1 and player.global_position.x+actual_body_half.x>bank.position.x and player.global_position.x-actual_body_half.x<bank.end.x: partial=bank
		if not supported:
			controller.router.set_move_axis(0 if partial.size==Vector2.ZERO else signf(partial.get_center().x-player.global_position.x))
			return
	super.continuous_fire()
func _queen_snapshot() -> Dictionary:
	return {"active":queen.active,"app_boss_started":_q_app._boss_started,"last_restore_accepted":queen.last_restore_accepted,"seal_closed":_q_app.stage.boss_seal.closed,"boss":queen.combat_snapshot().duplicate(true),"boss_hp":queen.health.current,"player_hp":controller.actor_resources.health.current,"energy":controller.actor_resources.stamina.current,"session":controller.session_id,"actor_epoch":life.actor_epoch,"stage_epoch":life.stage_epoch,"boss_instance":queen.get_instance_id(),"player_instance":player.get_instance_id(),"stage_instance":_q_app.stage.get_instance_id(),"manifest_hash":_q_app.stage.generated.manifest.manifest_hash}
func _queen_pause_reload() -> bool:
	var before:=_queen_snapshot();var token:=life.token();var prior_state:=_q_app.region_state
	if not await _queen_send_button(_q_app._pause_button,"pause"): return false
	check(paused,"actual Queen MENU pointer pauses gameplay")
	var frozen:=queen.combat_snapshot().duplicate(true)
	for unused: int in 3: await process_frame
	check(queen.combat_snapshot()==frozen,"actual Queen state and growing fields freeze in menu")
	_q_app.stage.capture_state()
	var saved: Dictionary=_q_app.region_state.boss_state.duplicate(true)
	check(saved.get("weave_schema")==13 and saved.health>0 and saved.health<data.queen_initial.boss_hp,"actual damaged current-schema Queen state is earned before reload")
	var paused_player_hp:=controller.actor_resources.health.current
	await _q_app._load_stage()
	await process_frame
	if not _queen_bind_actual(_q_app): return false
	var bound:=_queen_snapshot()
	check(_q_app.region_state==prior_state and bound.manifest_hash==before.manifest_hash,"actual App reload preserves same hash-bound Queen map")
	check(bound.stage_instance!=before.stage_instance and bound.boss_instance!=before.boss_instance and bound.actor_epoch>before.actor_epoch and not life.accepts(token),"fresh real Stage/Boss actor epoch replaces old Queen and rejects old token")
	check(queen.last_restore_accepted and is_equal_approx(queen.health.current,float(saved.health)) and queen.combat_snapshot().fields==saved.fields,"bound App restore retains actual damaged HP and exact persistent field state")
	_q_segment="after_reload"
	if not await _queen_pointer(_q_app.menu,"RESUME","resume"): return false
	for unused: int in 4: await process_frame
	var activated:=_queen_snapshot()
	check(not paused and _q_app._boss_started and queen.active and _q_app.stage.restored_boss.is_empty(),"actual resume and natural in-arena trigger reactivate restored Queen")
	check(queen.stage_phase==saved.stage_phase and queen.route_phase==saved.route_phase and queen.sampled_shore==saved.sampled_shore,"fresh active Queen preserves earned phase and sampled shore")
	_q_last_steps=player.motion_steps
	data.queen_reload={"before":before,"saved":saved,"after_bound":bound,"after_resume":activated,"paused_player_hp":paused_player_hp,"old_token_rejected":not life.accepts(token),"scope":"real MENU/RESUME pointer and App loadStage; no fixture/state patch"}
	return true
func _queen_pointer(owner: Node,prefix: String,phase: String) -> bool:
	for unused: int in 4: await process_frame
	for button: Button in owner.find_children("*","Button",true,false):
		if button.text.begins_with(prefix) and button.visible and not button.disabled: return await _queen_send_button(button,phase)
	return false
func _queen_send_button(button: Button,phase: String) -> bool:
	if not is_instance_valid(button) or not button.visible or button.disabled: return false
	for pressed: bool in [true,false]:
		var rect:=button.get_global_rect();var point:=rect.get_center()
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		pointer_events.append({"phase":phase,"text":button.text,"pressed":pressed,"point":_q_pair(point),"actual_button_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
		root.push_input(event,true);await process_frame
	return true
func run_queen() -> void:
	current="actual_app_queen";tick=0
	data={"scope":"actual_DemoApp_v2_map2_Queen_route_reload_fullfight_pointer_rewards_boundary","seed":seed_value,"initial_debug_entry_only":true,"expected_version":ThornForestRegionGenerator.DEPTH_VERSION,"manual_motor_step":false,"position_health_phase_resource_injection":false,"queen_whole_boss_admission":false,"pointer_scope":"actual Godot Viewport Button events; no OS/browser claim","input_scope":"shared Queen aim/fire/hook helpers bound to actual App; no fixture world or efficiency comparison","world_constructor_called":false}
	# This schema13 regression owns its recorded v7 content. The current canopy
	# Boss has a separate mandatory actual-App consumer, not a relaxed old test.
	var trace:=TRACE.new();trace.seed_value=seed_value;trace.map_index=2;trace.route_name="fast";trace.recorded_layout_version=ThornForestRegionGenerator.DEPTH_LAYOUT_V7;root.add_child(trace)
	while not trace.finished or not trace.setup_done: await process_frame
	trace.set_physics_process(false)
	data.route={"manifest":trace.manifest.duplicate(true),"frames":trace.frames.duplicate(true),"events":trace.events.duplicate(true),"requests":trace.requests.duplicate(true),"completed":trace.completed.duplicate(true),"itinerary":trace.itinerary.duplicate(true),"failures":trace.failures.duplicate(),"initial":trace.initial.duplicate(true),"final":trace.snapshot()}
	check(trace.manifest.get("layout_version")==ThornForestRegionGenerator.DEPTH_LAYOUT_V7,"legacy Queen App regression explicitly retains its recorded v7 layout")
	check(trace.failures.is_empty() and trace.completed.size()==trace.itinerary.size(),"actual map2 fast route naturally opens Queen gate")
	if not trace.failures.is_empty() or not is_instance_valid(trace.app): await finish(trace);return
	if not _queen_bind_actual(trace.app):
		check(false,"actual map2 Queen consumer binding failed");await finish(trace);return
	check(queen!=null and queen._weave_bound and _q_app.forest_content_version==ThornForestRegionGenerator.DEPTH_VERSION,"actual map2 App binds current experimental Queen")
	data.queen_initial=_queen_snapshot()
	data.definition={"resource":queen.definition.resource_path,"sha256":FileAccess.get_sha256(queen.definition.resource_path),"health":queen.definition.health_definition.initial_current,"schema":queen.combat_snapshot().weave_schema,"geometry":geometry.duplicate(true)}
	check(data.queen_initial.boss_hp==data.definition.health and not _q_app._boss_started,"actual uninjured Definition Queen awaits natural arena entry")
	for unused: int in 300:
		if _q_app._boss_started and _q_app.stage.boss_seal.closed: break
		controller.router.set_move_axis(1);await frames(1)
	controller.router.set_move_axis(0)
	check(_q_app._boss_started and _q_app.stage.boss_seal.closed,"normal walking enters Queen arena and closes production seal")
	var upper:=await enter_upper(false)
	var middle: bool=false
	if upper: middle=await move_to_middle()
	check(upper and middle,"real ordinary jump and R reach authored Queen shooting branches")
	var reloaded:=false;var borrowed:=false;var borrow_attempted:=false
	var combat_start:=tick
	_q_combat_deadline=combat_start+4200
	for unused: int in 4200:
		if tick>=_q_combat_deadline: break
		_q_driver_phase="fight"
		if queen.health.terminal or controller.actor_resources.health.terminal or not life.active: break
		if not reloaded and queen.stage_phase>=2:
			reloaded=await _queen_pause_reload()
			check(reloaded,"actual earned Queen state survives pause and fresh App reload")
			if not reloaded: break
		if not _queen_full_support(_queen_bank(1)):
			if not await _queen_regain_middle():
				if controller.actor_resources.health.terminal: break
				await frames(1)
				continue
		if not borrow_attempted and queen.stage_phase>=2 and is_instance_valid(queen.knots[1]) and not queen.knots[1].health.terminal:
			borrow_attempted=true
			borrowed=await accepted_hook(queen.knots[1].global_position)
			if borrowed and controller.shoot_ability.cooldown_remaining<=0:
				controller.router.request_action(&"shoot_release",(queen.knots[1].global_position-player.global_position).normalized());await frames(15)
			continue
		var target:=_queen_bank(1).get_center().x
		controller.router.set_move_axis(0 if absf(player.global_position.x-target)<6 else signf(target-player.global_position.x))
		continuous_fire();await frames(1)
	controller.router.set_move_axis(0)
	_q_combat_deadline=-1
	check(tick-combat_start<=4200,"actual Queen combat including recovery stays within original 4200 physics frames")
	data.queen_combat={"combat_start_tick":combat_start,"combat_elapsed_frames":tick-combat_start,"combat_budget_frames":4200,"initial":data.queen_initial,"final":_queen_snapshot(),"frames":frames_data.duplicate(true),"events":events.duplicate(true),"defeats":_q_defeats,"reloaded":reloaded,"optional_main_borrowed":borrowed,"whole_boss_design_admission":false}
	check(queen.health.terminal and controller.actor_resources.health.current>0 and _q_defeats==1,"actual normal Queen full fight ends in unique live-player defeat")
	check(reloaded and _q_app.director.stage_complete,"actual Queen reload and App completion both succeeded")
	if not queen.health.terminal or controller.actor_resources.health.terminal: await finish(trace);return
	for unused: int in 900:
		if _q_app.exit_modal.opened: break
		var delta:=_q_app.stage.reward_position.x-player.global_position.x
		controller.router.set_move_axis(signf(delta) if absf(delta)>5 else 0);await frames(1)
	controller.router.set_move_axis(0)
	check(_q_app.exit_modal.opened and _q_app._offered_exit==&"boss_home","normal walk reaches Queen combat-earned reward gate")
	if not _q_app.exit_modal.opened: await finish(trace);return
	check(await _queen_pointer(_q_app.exit_modal,"ENTER / CLAIM REWARD","reward"),"actual pointer confirms Queen reward gate")
	check(_q_app.reward_modal.opened and _q_app.current_reward.gold and _q_app.current_reward.candidates[0].stable_id==&"forest_heart_gold","Queen offers actual independent guaranteed GOLD")
	data.gold_definition={"id":String(_q_app.current_reward.candidates[0].stable_id),"resource":_q_app.current_reward.candidates[0].resource_path,"fingerprint":_q_app.current_reward.candidates[0].fingerprint()}
	data.before_gold={"hp":controller.actor_resources.health.current,"capacity":controller.actor_resources.health.capacity,"count":_q_app.build.count_item(&"forest_heart_gold")}
	check(await _queen_pointer(_q_app.reward_modal,"选择 / PICK","gold"),"actual pointer claims combat-earned forest GOLD once")
	data.after_gold={"hp":controller.actor_resources.health.current,"capacity":controller.actor_resources.health.capacity,"count":_q_app.build.count_item(&"forest_heart_gold")}
	check(data.after_gold.count==1 and not _q_app._claim_modal_item(&"forest_heart_gold") and _q_app.build.count_item(&"forest_heart_gold")==1,"unique Queen GOLD rejects duplicate owner submission")
	check(await _queen_pointer(_q_app.progression_modal,"D / DOUBLE JUMP","ability"),"actual pointer selects legal missing D reward")
	var boundary_text: Array[String]=[]
	for label: Label in _q_app.progression_modal.find_children("*","Label",true,false): boundary_text.append(label.text)
	data.boundary_ui_text=boundary_text
	data.before_boundary={"abilities":Array(_q_app.campaign.abilities),"phase":int(_q_app.campaign.phase),"double":controller.traversal.double_enabled,"map":_q_app.director.region_map_index,"manifest":_q_app.director.manifest.snapshot()}
	check(controller.traversal.double_enabled and _q_app.campaign.phase==RunCampaignProgression.Phase.BOUNDARY,"actual Queen core reward reaches explicit unbuilt-region boundary")
	data.before_boundary.manifest_compatible=RunManifest.compatible(data.before_boundary.manifest)
	check(data.before_boundary.manifest_compatible,"actual Queen completion and ability receipts retain compatible current RunManifest")
	check(await _queen_pointer(_q_app.progression_modal,"END THIS RUN","finish"),"actual pointer confirms truthful end boundary")
	for unused: int in 6: await process_frame
	data.after_boundary={"state":int(_q_app.director.state),"wallet":_q_app.wallet.balance,"items":_q_app.build.item_ids(),"abilities":Array(_q_app.campaign.abilities)}
	check(_q_app.director.state==DemoRunDirector.State.HOME and _q_app.wallet.balance==0 and _q_app.build.item_ids().is_empty() and _q_app.campaign.abilities.is_empty(),"boundary returns home and clears run items coins and abilities")
	await finish(trace)
