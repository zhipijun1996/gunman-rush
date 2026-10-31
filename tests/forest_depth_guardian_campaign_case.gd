extends Node
## Mechanical Guardian consumer extraction; dynamic Node execution boundary only.
const STRATEGY := preload("res://tests/forest_depth_trace_strategy.gd")
const PILOT := preload("res://tests/forest_depth_guardian_pilot.gd")
const AUDIO := preload("res://tests/audio_teardown.gd")
var output := "res://build/forest_depth/campaign/capture.json"
var seed_value := "forest-depth-hollow-00"
var checks: Array[Dictionary] = []
var pointer_events: Array[Dictionary] = []
var data: Dictionary = {}
var failures: Array[String] = []
func check(ok: bool, reason: String) -> void:
	checks.append({"passed":ok,"reason":reason})
	if not ok: failures.append(reason);printerr("FAIL: "+reason)
func frames(count: int) -> void:
	for unused: int in count: await get_tree().physics_frame
func run() -> void:
	data={"scope":"actual_DemoApp_v2_map1_route_Guardian_fullfight_pointer_reward_map2_entry","seed":seed_value,"expected_version":ThornForestRegionGenerator.DEPTH_VERSION,"initial_debug_entry_only":true,"manual_motor_step":false,"position_health_phase_resource_injection":false,"pointer_scope":"real Godot Viewport InputEventMouseButton, not OS or browser pointer","queen_whole_boss_admission":false}
	var trace: Node=STRATEGY.create();trace.seed_value=seed_value;trace.map_index=1;trace.route_name="fast";get_tree().root.add_child(trace)
	while not trace.finished or not trace.setup_done: await get_tree().process_frame
	trace.set_physics_process(false)
	data.route={"manifest":trace.manifest.duplicate(true),"frames":trace.frames.duplicate(true),"events":trace.events.duplicate(true),"requests":trace.requests.duplicate(true),"completed":trace.completed.duplicate(true),"itinerary":trace.itinerary.duplicate(true),"failures":trace.failures.duplicate(),"initial":trace.initial.duplicate(true),"final":trace.snapshot()}
	check(trace.failures.is_empty() and trace.completed.size()==trace.itinerary.size(),"actual fast route naturally reaches gate_ready")
	if not trace.failures.is_empty() or not is_instance_valid(trace.app): await finish(trace);return
	var app: DemoApp=trace.app
	var stage:=app.stage as ThornForestRegionStage
	check(stage.generated.stage_generator_version==ThornForestRegionGenerator.DEPTH_VERSION and stage.map_index==1,"actual map1 uses explicitly pinned v2")
	check(stage.region_state.opened.has("crown_vine") and stage.assembler.vine_shape.disabled,"actual route H opened persistent entry vine")
	check(app.controller.traversal.hook_enabled and not app.controller.traversal.double_enabled and not app.controller.traversal.wall_enabled,"route retains real H-only entry build")
	var before_entry:=identity(app)
	data.map1_before_entry=before_entry
	var pilot:=PILOT.new()
	data.combat=await pilot.run(app)
	if data.combat.has("error"): check(false,data.combat.error);await finish(trace);return
	check(data.combat.initial.boss_hp==32 and data.combat.initial.boss_started==false,"natural gate exit hands untouched32HP Boss to pilot before arena start")
	check(data.combat.seal_seen and data.combat.eligible_seen,"natural arena trigger closes real seal and enables actual shot gate")
	check(data.combat.defeats==1 and data.combat.final.boss_hp==0 and data.combat.final.player_hp>0,"normal full Guardian fight yields unique live-player defeat")
	check(data.combat.earned_counter_phase2 and data.combat.actual_bell_arrival and data.combat.events.any(func(row: Dictionary)->bool:return row.get("event")=="bell_counter_committed"),"real Player reaches moving Bell and owner contact commits counter")
	check(data.combat.events.any(func(row: Dictionary)->bool:return row.get("event")=="policy_result" and row.get("target")=="boss" and str(row.get("source","")).begins_with("player_projectile:")),"ordinary projectiles pass formal shot gate and FrameDamagePolicy")
	check(data.combat.events.any(func(row: Dictionary)->bool:return row.get("event")=="duel_phase_changed" and row.get("phase")==2 and row.get("completed_body_cycles",0)>0),"actual completed Body cycle and normal damage earn phase2")
	check(app.director.stage_complete and stage.reward_available,"actual App damage consumer marks completion and unique reward")
	if data.combat.final.boss_hp!=0 or data.combat.final.player_hp<=0: await finish(trace);return
	data.before_reward=identity(app)
	data.reward_declaration=reward_declaration()
	var reward_approach: Array[Dictionary]=[]
	for tick: int in 900:
		if app.exit_modal.opened: break
		var delta:=stage.reward_position.x-app.player.global_position.x
		app.controller.router.set_move_axis(signf(delta) if absf(delta)>5 else 0)
		await frames(1)
		reward_approach.append({"tick":tick,"position":[app.player.global_position.x,app.player.global_position.y],"reward_position":[stage.reward_position.x,stage.reward_position.y],"health":app.controller.actor_resources.health.current})
	app.controller.router.set_move_axis(0)
	data.reward_approach=reward_approach
	check(app.exit_modal.opened and app._offered_exit==&"boss_home","normal walking reaches combat-earned map2 reward gate")
	data.reward_modal_paused=get_tree().paused
	check(get_tree().paused,"actual reward modal pauses gameplay")
	if not app.exit_modal.opened: await finish(trace);return
	check(await pointer(app.exit_modal,"ENTER / CLAIM REWARD"),"real Viewport mouse press/release confirms reward")
	for unused: int in 120:
		await get_tree().process_frame
		if is_instance_valid(app.stage) and app.director.region_map_index==2 and app.stage!=stage: break
	var actual_map2:=is_instance_valid(app.stage) and app.stage is ThornForestRegionStage and app.stage!=stage and app.director.region_map_index==2
	check(actual_map2,"combat-earned formal transition instantiates second forest map")
	if actual_map2:
		data.map2_after_entry=identity(app)
		data.map2_manifest=app.stage.generated.manifest.duplicate(true)
		check(data.map2_after_entry.version==ThornForestRegionGenerator.DEPTH_VERSION and app.forest_content_version==ThornForestRegionGenerator.DEPTH_VERSION,"map2 retains explicit v2 version pin without legacy fallback")
		check(data.map2_after_entry.stage_index>before_entry.stage_index and data.map2_after_entry.stage_epoch>before_entry.stage_epoch and data.map2_after_entry.actor_epoch>before_entry.actor_epoch,"cross-map entry ordinal and stage/actor epochs advance")
		check(data.map2_after_entry.wallet==data.before_reward.wallet+data.reward_declaration.coins,"actual mini-boss settlement matches App-declared coin amount")
		check(data.map2_after_entry.hp==minf(data.before_reward.capacity,data.before_reward.hp+data.reward_declaration.heal) and data.map2_after_entry.capacity==data.before_reward.capacity,"actual reward matches App-declared capped heal and preserves capacity")
		check(data.map2_after_entry.build==data.before_reward.build and data.map2_after_entry.hook and not data.map2_after_entry.double and not data.map2_after_entry.wall,"cross-map preserves build and real H-only capabilities")
		var settled:=identity(app)
		check(not app._confirm_generated_exit() and not app._advance_region_map(),"already consumed exit/reward rejects duplicate owner submission")
		check(identity(app)==settled,"duplicate reward submission changes no consumer state")
		var coast: Array[Dictionary]=[]
		for unused: int in 30:
			await frames(1)
			coast.append({"position":[app.player.global_position.x,app.player.global_position.y],"hp":app.controller.actor_resources.health.current,"grounded":app.player.is_on_floor(),"map":app.stage.map_index,"session":app.controller.session_id})
		data.map2_normal_frames=coast
		data.run_manifest=app.director.manifest.snapshot()
		data.run_manifest_compatible=RunManifest.compatible(data.run_manifest)
		check(data.run_manifest_compatible,"actual two-map RunManifest preserves schema, resource configuration and transition identity")
		check(app.controller.actor_resources.health.current>0 and app.stage.map_index==2,"second-map natural spawn remains alive in ordinary physics")
	await finish(trace)
func reward_declaration() -> Dictionary:
	# Read the actual production settlement declaration, never a fixture grant.
	var source:=FileAccess.get_file_as_string("res://game/application/demo_app.gd")
	var section:=source.get_slice("func _advance_region_map() -> bool:",1).get_slice("\nfunc ",0)
	var coins:=RegEx.new();coins.compile("wallet\\.grant\\(([0-9.]+),id\\)")
	var heal:=RegEx.new();heal.compile("SupplyHealEffect\\.apply\\(controller\\.actor_resources\\.health,([0-9.]+),id\\)")
	var coin_match:=coins.search(section);var heal_match:=heal.search(section)
	return {"coins":float(coin_match.get_string(1)) if coin_match!=null else -1.0,"heal":float(heal_match.get_string(1)) if heal_match!=null else -1.0,"app_source_sha256":FileAccess.get_sha256("res://game/application/demo_app.gd")}
func identity(app: DemoApp) -> Dictionary:
	return {"map":app.director.region_map_index,"stage_index":app.director.stage_index,"stage_epoch":app.lifetime.stage_epoch,"actor_epoch":app.lifetime.actor_epoch,"session":app.controller.session_id,"version":app.stage.generated.stage_generator_version,"manifest_hash":app.stage.generated.manifest.manifest_hash,"wallet":app.wallet.balance,"hp":app.controller.actor_resources.health.current,"capacity":app.controller.actor_resources.health.capacity,"energy":app.controller.actor_resources.stamina.current,"build":app.build.inventory.item_ids(),"hook":app.controller.traversal.hook_enabled,"double":app.controller.traversal.double_enabled,"wall":app.controller.traversal.wall_enabled,"weapon":String(app.controller.shoot_ability.weapon.id),"tier":app.controller.shoot_ability.weapon.tier}
func pointer(owner: Node, text: String) -> bool:
	for unused: int in 4: await get_tree().process_frame
	for button: Button in owner.find_children("*","Button",true,false):
		if button.text!=text or button.disabled or not button.visible: continue
		var point:=button.get_global_rect().get_center()
		for pressed: bool in [true,false]:
			var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
			pointer_events.append({"text":text,"pressed":pressed,"point":[point.x,point.y],"actual_button_rect":[button.get_global_rect().position.x,button.get_global_rect().position.y,button.size.x,button.size.y]})
			get_tree().root.push_input(event,true);await get_tree().process_frame
		return true
	return false
func finish(trace: Node) -> void:
	get_tree().paused=false
	if is_instance_valid(trace.app):
		trace.app.process_mode=Node.PROCESS_MODE_DISABLED
		trace.app._cancel_enemy_attacks()
		check(await AUDIO.drain_world(trace.app),"actual owned App audio releases cleanly")
	trace.free()
	await get_tree().process_frame;await get_tree().process_frame
	data.checks=checks;data.failures=failures;data.pointer_events=pointer_events
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
	print("FOREST DEPTH CAMPAIGN: %s assertions / %s failures" % [checks.size(),failures.size()])
