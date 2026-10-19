extends Node
## Actual current-layout App transaction. No fixture constructor or actor injection.
const TRACE := preload("res://tests/forest_depth_region_trace.gd")
const PILOT := preload("res://tests/forest_depth_canopy_campaign_pilot.gd")
const AUDIO := preload("res://tests/audio_teardown.gd")
var output := "res://build/forest_depth/campaign/canopy.json"
var seed_value := "forest-depth-hollow-00"
var failures: Array[String] = []
var checks: Array[Dictionary] = []
var pointer_events: Array[Dictionary] = []
var data: Dictionary = {}
var pilot: Node
func check(ok: bool,why: String) -> void:
	checks.append({"passed":ok,"reason":why})
	if not ok: failures.append(why);printerr("FAIL: canopy_app/"+why)
func run() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	data={"scope":"actual_current_default_canopy_App_route_pause_freshload_fullfight_pointer_boundary","seed":seed_value,"manual_motor_step":false,"position_health_phase_resource_injection":false,"world_constructor_called":false,"whole_boss_fun_admission":false}
	var trace:=TRACE.new();trace.seed_value=seed_value;trace.map_index=2;trace.route_name="fast";get_tree().root.add_child(trace)
	while not trace.finished or not trace.setup_done: await get_tree().process_frame
	trace.set_physics_process(false)
	data.route={"manifest":trace.manifest.duplicate(true),"frames":trace.frames.duplicate(true),"events":trace.events.duplicate(true),"requests":trace.requests.duplicate(true),"completed":trace.completed.duplicate(true),"itinerary":trace.itinerary.duplicate(true),"failures":trace.failures.duplicate(),"initial":trace.initial.duplicate(true),"final":trace.snapshot()}
	check(trace.failures.is_empty() and trace.completed.size()==trace.itinerary.size(),"actual latest map2 fast reaches gate_ready")
	if not failures.is_empty(): await finish(trace);return
	var app: DemoApp=trace.app
	pilot=PILOT.new();add_child(pilot);pilot.partial_path=output.get_base_dir()+"/canopy-partial.json"
	check(pilot.bind_actual(app),"latest default produces actual canopy Encounter, not legacy Queen")
	if not failures.is_empty(): await finish(trace);return
	data.initial=pilot.snapshot();data.geometry=pilot.geometry.duplicate(true)
	check(not pilot.queen.active and not app._boss_started and pilot.queen.health.current==24,"route hands untouched inactive24HP Queen to actual entry connector")
	check(app.stage.region_state.opened.has("crown_vine") and app.stage.assembler.vine_shape.disabled,"real prior H opened entry gate")
	var spawn: Array=pilot.geometry.player_spawn
	var supported:=0
	for unused: int in 240:
		var dx:=float(spawn[0])-app.player.global_position.x
		app.controller.router.set_move_axis(signf(dx) if absf(dx)>3 else 0)
		await pilot.frames(1)
		if pilot.support_id()=="S" and absf(dx)<=3: supported+=1
		else: supported=0
		if supported>=12 and app.stage.boss_seal.closed: break
	app.controller.router.set_move_axis(0)
	check(supported>=12 and app._boss_started and pilot.queen.active and app.stage.boss_seal.closed,"normal connector walk earns real S support12 and closes Boss seal")
	data.after_entry=pilot.snapshot()
	if not failures.is_empty(): await finish(trace);return
	pilot.reload_callback=_pause_reload
	await pilot.full_fight("purpose")
	for message: String in pilot.failures: check(false,message)
	data.combat={"initial":pilot.combat_initial,"final":pilot.snapshot(),"frames":pilot.frames_data.duplicate(true),"events":pilot.events.duplicate(true),"cases":pilot.cases.duplicate(true),"defeats":pilot.defeats,"reloaded":pilot.reloaded,"fight_start_tick":pilot.fight_start_tick}
	check(pilot.reloaded and pilot.defeats==1 and pilot.queen.health.terminal and app.director.stage_complete,"actual freshrestore then unique24HP defeat completes App")
	if not failures.is_empty(): await finish(trace);return
	await approach_reward(app)
	if not app.exit_modal.opened: check(false,"actual movement reaches reward gate");await finish(trace);return
	check(await pointer(app.exit_modal,"ENTER / CLAIM REWARD","reward"),"real reward gate pointer")
	check(app.reward_modal.opened and app.current_reward.gold,"combat-earned GOLD modal")
	data.gold_definition={"id":String(app.current_reward.candidates[0].stable_id),"resource":app.current_reward.candidates[0].resource_path,"fingerprint":app.current_reward.candidates[0].fingerprint()}
	data.before_gold=reward_identity(app)
	check(await pointer(app.reward_modal,"选择 / PICK","gold"),"real GOLD item pointer")
	data.after_gold=reward_identity(app)
	check(data.after_gold.count==1 and data.after_gold.hp==data.before_gold.hp and data.after_gold.wallet==data.before_gold.wallet and data.after_gold.capacity==data.before_gold.capacity+2,"GOLD maxHP+2 preserves HP/coins per current declaration")
	check(not app._claim_modal_item(&"forest_heart_gold") and reward_identity(app)==data.after_gold,"duplicate GOLD rejected atomically")
	check(await pointer(app.progression_modal,"D / DOUBLE JUMP","ability"),"actual D selection pointer")
	data.boundary_ui_text=[]
	for label: Label in app.progression_modal.find_children("*","Label",true,false): data.boundary_ui_text.append(label.text)
	data.before_boundary={"double":app.controller.traversal.double_enabled,"abilities":Array(app.campaign.abilities),"phase":int(app.campaign.phase),"map":app.director.region_map_index,"manifest":app.director.manifest.snapshot()}
	data.before_boundary.manifest_compatible=RunManifest.compatible(data.before_boundary.manifest)
	check(data.before_boundary.double and data.before_boundary.manifest_compatible and app.campaign.phase==RunCampaignProgression.Phase.BOUNDARY,"actual D receipt reaches compatible development boundary")
	pilot.disconnect_actual()
	check(await pointer(app.progression_modal,"END THIS RUN","finish"),"actual development-boundary home pointer")
	for unused: int in 6: await get_tree().process_frame
	data.after_boundary={"state":int(app.director.state),"wallet":app.wallet.balance,"items":app.build.item_ids(),"abilities":Array(app.campaign.abilities)}
	check(app.director.state==DemoRunDirector.State.HOME and app.wallet.balance==0 and app.build.item_ids().is_empty() and app.campaign.abilities.is_empty(),"real home clears run")
	await finish(trace)
func reward_identity(app: DemoApp) -> Dictionary:
	return {"hp":app.controller.actor_resources.health.current,"capacity":app.controller.actor_resources.health.capacity,"wallet":app.wallet.balance,"count":app.build.count_item(&"forest_heart_gold")}
func _pause_reload(driver: Node) -> bool:
	var app: DemoApp=driver.app
	var before: Dictionary=driver.snapshot();var token:=app.lifetime.token();var prior:=app.region_state
	if not await send_button(app._pause_button,"pause"): return false
	check(get_tree().paused,"MENU genuinely pauses App")
	var frozen: Dictionary=driver.queen.combat_snapshot().duplicate(true)
	for unused: int in 3: await get_tree().process_frame
	check(driver.queen.combat_snapshot()==frozen,"paused actual motion/field ages freeze")
	app.stage.capture_state()
	var saved: Dictionary=app.region_state.boss_state.duplicate(true)
	check(saved.canopy_schema==1 and saved.health>0 and saved.health<24 and saved.stage_phase>=2 and saved.fields[0].spawned and saved.fields[0].health>0 and saved.fields[0].weave.age>.15,"earned damaged schema1 save contains aged living phase2 field")
	data.schema_negatives=probe_invalid(driver,saved)
	if not failures.is_empty(): return false
	driver.disconnect_actual()
	await app._load_stage();await get_tree().process_frame
	if not driver.bind_actual(app): return false
	var bound: Dictionary=driver.snapshot()
	check(app.region_state==prior and bound.manifest_hash==before.manifest_hash and bound.boss_instance!=before.boss_instance and bound.stage_instance!=before.stage_instance and bound.actor_epoch>before.actor_epoch,"actual fresh load replaces actors, retains same region Manifest")
	check(bound.last_restore_accepted and bound.boss_hp==saved.health and bound.player_hp==before.player_hp and is_equal_approx(bound.energy,before.energy) and bound.capacity==before.capacity,"real bound restore preserves damaged Boss/Player HP, energy and capacity")
	for key: String in ["body_position","mode","motion_clock","stage_phase","section","leg","cycles","last_receiver","locked_receiver","sampled_player","intro_seen","intro_duration","fields"]:
		check(bound.boss[key]==saved[key],"fresh restore preserves actual "+key)
	var request:=DamageRequest.new();request.token=token;request.event_id=&"canopy_app_stale_token";request.source_id=&"player_projectile:stale";request.target_id=&"boss";request.health_epoch=driver.queen.health.epoch;request.actor_epoch=app.lifetime.actor_epoch
	var hp: float=driver.queen.health.current;var queued: int=app.policy._queue.size()
	var stale_rejected:=not app.policy.submit(request)
	check(stale_rejected and not app.lifetime.accepts(token) and driver.queen.health.current==hp and app.policy._queue.size()==queued,"actual Policy rejects old token without damage/queue mutation")
	driver.segment="after_reload"
	if not await pointer(app.menu,"RESUME","resume"): return false
	var resumed: Dictionary=driver.snapshot()
	check(not get_tree().paused,"real RESUME pointer releases pause")
	driver._last_steps=driver.player.motion_steps
	data.reload={"before":before,"frozen":frozen,"saved":saved,"after_bound":bound,"after_resume":resumed,"old_token_rejected":stale_rejected,"player_restore_scope":"production checkpoint S resets motion/H/air actions; HP/stamina/capacity survive, not airborne position or empty guns"}
	return failures.is_empty()
func probe_invalid(driver: Node,saved: Dictionary) -> Array[Dictionary]:
	var variants: Array[Dictionary]=[]
	for id: String in ["unknown_schema","wrong_clock_type","nan_clock","off_path_body","invalid_leg","future_field","unknown_receiver","severed_hp","age_growth"]:
		var row:=saved.duplicate(true)
		match id:
			"unknown_schema": row.canopy_schema=999
			"wrong_clock_type": row.motion_clock="0"
			"nan_clock": row.motion_clock=NAN
			"off_path_body": row.body_position=[-99999,-99999];row.position=row.body_position.duplicate()
			"invalid_leg": row.leg=999
			"future_field": row.stage_phase=1
			"unknown_receiver": row.locked_receiver="unknown_receiver"
			"severed_hp": row.fields[0].weave.severed=true
			"age_growth": row.fields[0].weave.growth=float(row.fields[0].weave.growth)+.25 if float(row.fields[0].weave.growth)<=.75 else float(row.fields[0].weave.growth)-.25
		var before: Dictionary=driver.queen.combat_snapshot().duplicate(true);var hp: float=driver.queen.health.current
		var accepted: bool=driver.queen.valid_duel_snapshot(row)
		driver.queen.restore_combat_state(row)
		var after: Dictionary=driver.queen.combat_snapshot().duplicate(true)
		var atomic: bool=after==before and driver.queen.health.current==hp
		variants.append({"id":id,"valid_accepted":accepted,"restore_accepted":driver.queen.last_restore_accepted,"atomic":atomic,"before":before,"after":after,"hp_before":hp,"hp_after":driver.queen.health.current})
		check(not accepted and not driver.queen.last_restore_accepted and atomic,"invalid real schema rejects atomically: "+id)
		if not failures.is_empty(): break
	return variants
func approach_reward(app: DemoApp) -> void:
	var start_tick: int=pilot.tick
	var holding:=0
	for unused: int in 900:
		if app.exit_modal.opened: break
		var local: Vector2=app.player.global_position-pilot.origin
		var dx:=app.stage.reward_position.x-app.player.global_position.x
		app.controller.router.set_move_axis(signf(dx) if absf(dx)>4 else 0)
		# Traverse the actual solid right rib via a normal jump and visible B hook.
		if local.x>700 and app.player.is_on_floor() and holding==0:
			app.controller.router.set_jump_held(&"canopy_reward",true);holding=23
		if local.x>700 and not app.player.is_on_floor() and app.controller.traversal.state==&"free" and not app.controller.traversal.hook_used and app.player.global_position.distance_to(pilot.air_anchor("B"))<215:
			await pilot.air_request_hook(pilot.air_anchor("B"),"reward_B")
		if local.x>630 and local.y+18<242 and app.controller.shoot_ability.cooldown_remaining<=0 and app.controller.action_resources.shot_charges>0 and app.player.recoil_burst_remaining<=0:
			app.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
		if holding>0:
			holding-=1
			if holding==0: app.controller.router.set_jump_held(&"canopy_reward",false)
		await pilot.frames(1)
	app.controller.router.set_move_axis(0);app.controller.router.set_jump_held(&"canopy_reward",false)
	data.reward_approach={"final":pilot.snapshot(),"frames":pilot.frames_data.filter(func(row: Dictionary)->bool:return row.tick>start_tick)}
func pointer(owner: Node,prefix: String,phase: String) -> bool:
	for unused: int in 4: await get_tree().process_frame
	for button: Button in owner.find_children("*","Button",true,false):
		if button.text.begins_with(prefix) and button.visible and not button.disabled: return await send_button(button,phase)
	return false
func send_button(button: Button,phase: String) -> bool:
	if not is_instance_valid(button) or not button.visible or button.disabled: return false
	for pressed: bool in [true,false]:
		var rect:=button.get_global_rect();var point:=rect.get_center();var event:=InputEventMouseButton.new()
		event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		pointer_events.append({"phase":phase,"text":button.text,"pressed":pressed,"point":[point.x,point.y],"actual_button_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
		get_tree().root.push_input(event,true);await get_tree().process_frame
	return true
func finish(trace: Node) -> void:
	get_tree().paused=false
	var refs: Array[WeakRef]=[]
	if is_instance_valid(pilot):
		data.observations={"frames":pilot.frames_data.duplicate(true),"events":pilot.events.duplicate(true),"failures":pilot.failures.duplicate()}
		refs=pilot.observed_actors.duplicate();pilot.clear_actual();pilot.free();pilot=null
	if is_instance_valid(trace.app):
		trace.app.process_mode=Node.PROCESS_MODE_DISABLED;trace.app._cancel_enemy_attacks()
		check(await AUDIO.drain_world(trace.app),"actual owned App audio releases")
	trace.free();await get_tree().process_frame;await get_tree().process_frame
	var alive: Array[int]=[]
	for reference: WeakRef in refs:
		if reference.get_ref()!=null: alive.append(reference.get_ref().get_instance_id())
	data.teardown={"observed_actors_alive":alive}
	check(alive.is_empty(),"actual bound Queen/ShootAbility WeakRefs release after owner teardown")
	data.checks=checks;data.failures=failures;data.pointer_events=pointer_events
	DirAccess.make_dir_recursive_absolute(output.get_base_dir());FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(data))
	print("FOREST DEPTH CAMPAIGN: %s assertions / %s failures"%[checks.size(),failures.size()])
