extends SceneTree
## Ordinary title/Home GUI → fixed delivery map integration. Explicit economy,
## loadout and Boss-placement fixtures are reported separately from natural input.
const APP_SCENE := "res://scenes/demo/demo.tscn"
const TEARDOWN := preload("res://tests/audio_teardown.gd")
var app: DemoApp
var rows: Array[Dictionary] = []
var trace: Array[Dictionary] = []
var checks := 0
var failures := 0
var output := "user://mapgen-main-runtime.json"
var departures := 0
var starts: Array[Dictionary] = []
var ends: Array[Dictionary] = []
var prebind: Dictionary = {}
var inject_prebind := true
var shots := 0
var observed_phases: Dictionary = {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func _record(id: String, passed: bool, kind: String, evidence: Dictionary = {}) -> void:
	checks += 1
	if not passed: failures += 1
	var row := {"id":id,"status":"passed" if passed else "failed","kind":kind,"evidence":evidence}
	rows.append(row)
	print("MAPGEN MAIN CASE ",JSON.stringify(row))

func _process_frames(count: int = 3) -> void:
	for frame: int in count: await process_frame

func _frames(count: int = 1, capture: bool = false) -> void:
	for frame: int in count:
		await physics_frame
		await process_frame
		if capture and is_instance_valid(app.player):
			trace.append({"frame":Engine.get_physics_frames(),"position":[app.player.global_position.x,app.player.global_position.y],"hp":app.controller.actor_resources.health.current,"coins":app.wallet.balance,"shots":shots,"grounded":app.player.is_on_floor(),"actor_epoch":app.lifetime.actor_epoch})

func _button(node_name: String = "", prefix: String = "") -> Button:
	for node: Node in app.menu.find_children("*","Button",true,false):
		var button := node as Button
		if (node_name.is_empty() or button.name==node_name) and (prefix.is_empty() or button.text.begins_with(prefix)) and button.is_visible_in_tree(): return button
	return null

func _click(button: Button, id: String) -> bool:
	var available := button != null and button.is_visible_in_tree() and not button.disabled
	_record("pointer/"+id,available,"native_gui_pointer",{"button":str(button.get_path()) if button != null else "","text":button.text if button != null else "","dispatch":"Input.parse_input_event; no pressed signal emission"})
	if not available: return false
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await _process_frames(2)
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await _process_frames(2)
	return true

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _run() -> void:
	root.size = Vector2i(1280,720)
	app = (load(APP_SCENE) as PackedScene).instantiate() as DemoApp
	app.meta_persistence_enabled = false
	# Memory-only notes are an explicit business-flow fixture, not map loot.
	var notes_fixture := app.meta.grant_notes(9,&"mapgen_main_notes_fixture")
	root.add_child(app)
	await _frames(6)
	app.menu.requested_plains.connect(func(seed_value: String) -> void: departures += 1; starts.append({"event":"ordinary_departure_signal","seed_from_menu":seed_value}))
	app.director.stage_entered.connect(_before_map_bind)
	app.director.run_ended.connect(_run_ended)
	_record("ordinary/title",app.menu.visible_panel==&"title" and app.home_scene==null and app.player==null and notes_fixture.accepted,"ordinary_main_app",{"scene":app.scene_file_path,"notes_fixture":9,"memory_only":true})
	if not await _click(_button("BeginAdventure"),"title_begin"):
		await _finish(); return
	await _frames(8)
	_record("ordinary/home",is_instance_valid(app.home_scene) and app.player==null and app.director.state==DemoRunDirector.State.HOME,"ordinary_main_app",{"title_clicked":true,"home_created":is_instance_valid(app.home_scene),"run_created":app.player!=null})
	if not is_instance_valid(app.home_scene): await _finish(); return
	# Opening a Home service panel is the declared initial-condition fixture.
	# Every actual purchase/equip/departure below uses the native GUI or service.
	app._open_home_function(&"upgrade")
	await _process_frames(3)
	var bought := app.meta.purchase_upgrade(&"vitality",&"mapgen_main_native_upgrade")
	app._refresh_home_meta()
	_record("ordinary/permanent_upgrade",bought.accepted and int(app.meta.snapshot().upgrades.get("vitality",0))==1 and app.meta.snapshot().notes==4,"native_meta_transaction_fixture",{"notes_fixture":9,"native_purchase":bought,"remaining_notes":app.meta.snapshot().notes,"panel_initial_condition":"explicit Home upgrade panel"})
	app._open_home_function(&"arms")
	await _process_frames(3)
	await _click(_button("EquipHomeWeapon_shadow_shuriken"),"home_shadow_weapon")
	_record("ordinary/selected_weapon",app.home_weapons.selected_id==&"shadow_shuriken" and app.home_scene.controller.shoot_ability.weapon.id==&"shadow_shuriken","native_home_weapon",{"selected":String(app.home_weapons.selected_id),"panel_initial_condition":"explicit Home arms panel"})
	app._open_home_function(&"departure")
	await _process_frames(3)
	if not await _click(_button("","BEGIN /"),"home_departure_begin"):
		await _finish(); return
	if not await _wait_map("first"):
		await _finish(); return
	_record("ordinary/fixed_map_profile",departures==1 and app.director.profile.profile_id==&"fixed_delivery_930001" and app.stage.registry.map_data.seed==930001,"ordinary_main_app",{"departures":departures,"profile":String(app.director.profile.profile_id),"map_seed":app.stage.registry.map_data.seed,"director_seed":app.director.seed,"hosted":app.stage.hosted})
	_inventory("first")
	_binding_preserved()
	_manifest_guards()
	_director_guards()
	_bind_guards()
	var first_actor := app.player.get_instance_id()
	var first_token := app.lifetime.token()
	await _natural_start()
	await _controls()
	await _hosted_chest()
	# Hosted maps own no hidden Return/F5 shortcut. Leave through the actual
	# main-game pause page, its Return Home action, and the confirmation modal.
	_key(KEY_ESCAPE,true); _key(KEY_ESCAPE,false)
	await _process_frames(3)
	await _click(_button("PausePage"),"pause_journey_page")
	await _click(_button("LeaveAdventure"),"pause_return_home")
	await _click(_button("","LEAVE RUN"),"confirm_leave_run")
	await _wait_home("abandon")
	_record("lifecycle/return_home",app.director.state==DemoRunDirector.State.HOME and is_instance_valid(app.home_scene) and app.player==null and not app.lifetime.active and ends.size()==1 and ends[0].reason=="failure","ordinary_main_app",{"ended":ends.duplicate(true),"meta":app.meta.snapshot(),"same_app":app.scene_file_path==APP_SCENE})
	if not await _click(_button("","ENTER HOME"),"abandon_enter_home"):
		await _finish(); return
	await _frames(3)
	app._open_home_function(&"arms")
	await _process_frames(3)
	await _click(_button("EquipHomeWeapon_pulse_gun"),"home_pulse_weapon")
	app._open_home_function(&"departure")
	await _process_frames(3)
	inject_prebind = false
	await _click(_button("","BEGIN /"),"second_departure_begin")
	if not await _wait_map("second"):
		await _finish(); return
	_record("lifecycle/fresh_run",app.player.get_instance_id()!=first_actor and not app.lifetime.accepts(first_token) and app.wallet.balance==0 and app.controller.actor_resources.health.capacity==6 and app.controller.actor_resources.health.current==6 and app.controller.shoot_ability.weapon.id==&"pulse_gun" and app.build.item_ids().is_empty(),"ordinary_main_app",{"actor_id":app.player.get_instance_id(),"previous_actor_id":first_actor,"health":app.controller.actor_resources.health.current,"capacity":app.controller.actor_resources.health.capacity,"coins":app.wallet.balance,"weapon":String(app.controller.shoot_ability.weapon.id),"notes":app.meta.snapshot().notes,"old_token_accepted":app.lifetime.accepts(first_token)})
	_inventory("second")
	await _native_boss()
	await _wait_home("boss")
	var victory_end: Dictionary = ends.back() if not ends.is_empty() else {}
	_record("lifecycle/native_boss_settled",ends.size()==2 and victory_end.get("reason")=="delivery_complete" and victory_end.get("boss_health",-1)==0 and victory_end.get("player_health",0)>0 and victory_end.get("boss_completed",false) and victory_end.get("exit_sealed",false) and victory_end.get("gold_claimed",true)==false and app.meta.snapshot().completed_runs==1 and app.director.state==DemoRunDirector.State.HOME and is_instance_valid(app.home_scene),"native_player_combat_and_main_lifecycle",{"end":victory_end,"meta":app.meta.snapshot(),"natural_whole_map_arrival":false})
	# Actual post-run retry button takes the same ordinary fixed-map route.
	var previous_epoch := app.lifetime.epoch
	await _click(_button("","再次出发"),"summary_depart_again")
	if not await _wait_map("retry"):
		await _finish(); return
	_record("lifecycle/retry_fixed_map",app.stage.registry.map_data.seed==930001 and app.director.profile.profile_id==&"fixed_delivery_930001" and app.lifetime.active and app.lifetime.epoch>previous_epoch and app.wallet.balance==0 and app.controller.shoot_ability.weapon.id==&"pulse_gun","ordinary_main_app",{"profile":String(app.director.profile.profile_id),"seed":app.stage.registry.map_data.seed,"run_epoch":app.lifetime.epoch,"previous_epoch":previous_epoch,"notes":app.meta.snapshot().notes,"coins":app.wallet.balance})
	_inventory("retry")
	await _death_fixture(first_token)
	await _wait_home("death")
	var death_end: Dictionary = ends.back() if not ends.is_empty() else {}
	_record("lifecycle/fatal_returns_home",ends.size()==3 and death_end.get("reason")=="failure" and death_end.get("player_health",1)==0 and app.player==null and app.policy==null and app.stage==null and not app.lifetime.active and is_instance_valid(app.home_scene) and app.meta.snapshot().failed_runs==2 and app.meta.snapshot().notes==4,"native_damage_transaction_fixture",{"end":death_end,"meta":app.meta.snapshot(),"fixture":"fatal DamageRequest; not claimed as natural enemy combat"})
	await _finish()

func _wait_map(label: String) -> bool:
	for frame: int in 180:
		if is_instance_valid(app.stage) and app.stage.get("loaded")==true and not app._stage_pending:
			await _frames(3)
			_record("ordinary/loaded/"+label,true,"ordinary_main_app",{"stage_script":app.stage.get_script().resource_path,"seed":app.stage.registry.map_data.seed})
			return true
		if is_instance_valid(app.stage) and app.stage.get("load_error")!=null and not str(app.stage.get("load_error")).is_empty(): break
		await _frames(1)
	_record("ordinary/loaded/"+label,false,"ordinary_main_app",{"stage_pending":app._stage_pending,"stage":str(app.stage),"load_error":str(app.stage.get("load_error")) if is_instance_valid(app.stage) else "stage_missing"})
	return false

func _wait_home(label: String) -> void:
	for frame: int in 120:
		if app.director.state==DemoRunDirector.State.HOME and is_instance_valid(app.home_scene) and app.player==null: return
		await _frames(1)
	_record("lifecycle/home_timeout/"+label,false,"ordinary_main_app",{"state":app.director.state,"player":str(app.player),"home":str(app.home_scene)})

func _before_map_bind(_result: DemoRunResult) -> void:
	if not inject_prebind: return
	# Explicit integration fixture between normal App actor creation and its
	# queued stage binding. All changes use existing native resource services.
	var actor := app.controller
	var pause_before := paused
	paused = true
	var item: ItemDefinition = load("res://resources/items/health_blue.tres")
	var acquired := app.build.add_item(&"mapgen_main_equipped_health",item,&"test_fixture")
	var owned := app.build.inventory.instance_for_source(&"mapgen_main_equipped_health")
	var session := app.build.equipment.open_session(app.lifetime.token())
	var proposal: Array[StringName] = []
	if owned != null: proposal.append(owned.instance_id)
	var equipped := app.build.equipment.submit(proposal,app.lifetime.token(),session,int(app.build.equipment.snapshot().revision))
	app.build.equipment.close_session()
	paused = pause_before
	actor.traversal.grant(&"wall_climb")
	var health := actor.actor_resources.health
	var damage := health.apply_damage(ActorResourceRequest.new(&"mapgen_main_prebind_damage",health.epoch,1.0,health.get_instance_id()))
	var granted := app.wallet.grant(7,&"mapgen_main_prebind_wallet")
	prebind = {"actor_id":app.player.get_instance_id(),"controller_id":actor.get_instance_id(),"health_id":health.get_instance_id(),"health_epoch":health.epoch,"health":health.current,"capacity":health.capacity,"wallet_id":app.wallet.get_instance_id(),"coins":app.wallet.balance,"lifetime_id":app.lifetime.get_instance_id(),"build_id":app.build.get_instance_id(),"meta_id":app.meta.get_instance_id(),"weapon":String(actor.shoot_ability.weapon.id),"wall_climb":actor.traversal.wall_enabled,"equipped_ids":app.build.equipment.equipped_ids(),"acquired":acquired,"owned":owned!=null,"equipped":equipped,"damage_accepted":damage.accepted(),"wallet_granted":granted}

func _binding_preserved() -> void:
	var actor := app.controller
	var health := actor.actor_resources.health
	var ids_equal: bool = app.player.get_instance_id()==int(prebind.actor_id) and actor.get_instance_id()==int(prebind.controller_id) and health.get_instance_id()==int(prebind.health_id) and app.wallet.get_instance_id()==int(prebind.wallet_id) and app.lifetime.get_instance_id()==int(prebind.lifetime_id) and app.build.get_instance_id()==int(prebind.build_id) and app.meta.get_instance_id()==int(prebind.meta_id)
	_record("binding/resource_identity",ids_equal and app.stage.player==actor and app.stage.motor==app.player and app.stage.wallet==app.wallet and app.stage.policy==app.policy and app.stage.lifetime==app.lifetime and app.stage.segment==app.segment,"ordinary_main_app",{"before":prebind,"stage_player_same":app.stage.player==actor,"stage_wallet_same":app.stage.wallet==app.wallet,"stage_policy_same":app.stage.policy==app.policy,"stage_lifetime_same":app.stage.lifetime==app.lifetime})
	_record("binding/no_reset",prebind.acquired and prebind.owned and prebind.equipped.accepted and prebind.damage_accepted and prebind.wallet_granted and health.epoch==int(prebind.health_epoch) and health.current==float(prebind.health) and health.capacity==float(prebind.capacity) and app.wallet.balance==int(prebind.coins) and actor.shoot_ability.weapon.id==&"shadow_shuriken" and actor.traversal.wall_enabled and actor.traversal.hook_enabled and app.build.equipment.equipped_ids()==prebind.equipped_ids,"native_resource_and_loadout_fixture",{"before":prebind,"health_after":health.current,"health_epoch_after":health.epoch,"capacity_after":health.capacity,"coins_after":app.wallet.balance,"weapon_after":String(actor.shoot_ability.weapon.id),"wall_after":actor.traversal.wall_enabled,"grapple_after":actor.traversal.hook_enabled,"equipped_after":app.build.equipment.equipped_ids(),"fixture":"native prebind health transaction/wallet grant/equipment/wall ability; no PlayerTuning edit"})

func _manifest_guards() -> void:
	var actual := app.director.manifest.snapshot()
	var reconstructed := RunManifest.from_snapshot(actual)
	var map_path := "res://third_party/mapgen/0.1.0/maps/seed-930001.json"
	var receipt: Dictionary = actual.stages[0].outputs.delivery_map
	_record("manifest/actual_ready_roundtrip",RunManifest.compatible(actual) and reconstructed!=null and reconstructed.canonical_json()==app.director.manifest.canonical_json() and receipt.map_sha256==FileAccess.get_sha256(map_path),"actual_ready_manifest",{"profile":actual.run_profile,"delivery":receipt,"physics_hash":actual.config_hashes.get("physics"),"equipped_sources":actual.stages[0].outputs.get("capability_snapshot",{}).get("item_sources",[])})
	var variants: Array[String] = ["root_seed","receipt_seed","map_sha","manifest_sha","profile_version","profile_count","profile_boss","profile_development","stages_missing","second_stage","stage_type","stage_biome","stage_offers","stage_outputs_array","delivery_output_array","tuning_gravity","tuning_type","capability_type","item_fingerprint","physics_hash"]
	for variant: String in variants:
		var changed := actual.duplicate(true)
		match variant:
			"root_seed": changed.root_seed = "930002"
			"receipt_seed": changed.stages[0].outputs.delivery_map.seed = 930002
			"map_sha": changed.stages[0].outputs.delivery_map.map_sha256 = "0".repeat(64)
			"manifest_sha": changed.stages[0].outputs.delivery_map.manifest_sha256 = "0".repeat(64)
			"profile_version": changed.run_profile.version = 2
			"profile_count": changed.run_profile.stages_per_biome = 2
			"profile_boss": changed.run_profile.boss_stage = 2
			"profile_development": changed.run_profile.development_only = true
			"stages_missing": changed.stages = []
			"second_stage": changed.stages.append(changed.stages[0].duplicate(true)); changed.stages[1].stage_index = 2
			"stage_type": changed.stages[0].type_id = "combat"
			"stage_biome": changed.stages[0].biome_id = "thorn_forest"
			"stage_offers": changed.stages[0].offers = [{"exit_id":"fake_second_map"}]
			"stage_outputs_array": changed.stages[0].outputs = []
			"delivery_output_array": changed.stages[0].outputs.delivery_map = []
			"tuning_gravity": changed.stages[0].outputs.stage_tuning.gravity += 1
			"tuning_type": changed.stages[0].outputs.stage_tuning = []
			"capability_type": changed.stages[0].outputs.capability_snapshot = []
			"item_fingerprint":
				var capability: Dictionary = changed.stages[0].outputs.capability_snapshot
				if capability.get("item_sources",[]).is_empty(): capability.item_sources = [{"fingerprint":"forged"}]
				else: capability.item_sources[0].fingerprint = "forged"
			"physics_hash": changed.config_hashes.physics = "0".repeat(64)
		var compatible := RunManifest.compatible(changed)
		var restored := RunManifest.from_snapshot(changed)
		_record("manifest/refuse/"+variant,not compatible and restored==null,"manifest_mutation_fixture",{"mutation":variant,"compatible":compatible,"from_snapshot_nonnull":restored!=null,"source":"deep copy of actual ready main-game Manifest"})

func _director_guards() -> void:
	var life := DemoLifetime.new()
	var director := DemoRunDirector.new(life)
	director.biome_id = &"plains"
	var emitted := {"count":0}
	director.run_ended.connect(func(_result: DemoRunResult) -> void: emitted.count += 1)
	var start := director.start("930001",RunProfile.fixed_delivery())
	var before := director.manifest.canonical_json()
	var token := life.token()
	var early := director.finish_delivery(token,&"fixture_early_delivery")
	_record("director/not_complete",start.accepted() and early.status==DemoRunResult.Status.NOT_READY and life.active and emitted.count==0 and director.manifest.canonical_json()==before,"director_transaction_fixture",{"status":early.status,"active":life.active,"run_ends":emitted.count,"native_boss_combat":false})
	director.complete_stage(token)
	var fake_gold := director.finish_biome(token,&"fixture_fake_gold",true)
	var fake_success := director.finish_success(token,&"fixture_fake_success",true)
	var advance := director.advance_region_map(token,&"fixture_second_map")
	var continuation := director.continue_region(token,&"thorn_forest",&"fixture_fake_region",[&"grapple"])
	var exit := director.select_exit(token,&"fake_exit",&"fixture_fake_exit")
	_record("director/no_fake_gold_or_second_map",not fake_gold.accepted() and not fake_success.accepted() and not advance.accepted() and not continuation.accepted() and not exit.accepted() and life.active and director.stage_index==1 and director.manifest.snapshot().stages.size()==1 and director.offers.is_empty() and director.manifest.snapshot().decisions.is_empty() and emitted.count==0,"director_transaction_fixture",{"fake_gold":fake_gold.status,"fake_success":fake_success.status,"second_map":advance.status,"next_region":continuation.status,"exit":exit.status,"stage_index":director.stage_index,"native_boss_combat":false})
	life.invalidate_actor()
	var stale := director.finish_delivery(token,&"fixture_stale_completion")
	_record("director/stale_completion",stale.status==DemoRunResult.Status.STALE and life.active and emitted.count==0,"director_transaction_fixture",{"status":stale.status,"native_boss_combat":false})
	var completion := director.finish_delivery(life.token(),&"fixture_delivery_complete")
	var replay := director.finish_delivery(token,&"fixture_delivery_complete")
	var duplicate := director.finish_delivery(token,&"fixture_different_end")
	_record("director/completion_idempotence",completion.accepted() and completion.reason==&"delivery_complete" and replay.status==DemoRunResult.Status.REPLAY and duplicate.status==DemoRunResult.Status.TERMINAL and emitted.count==1 and not life.active,"director_transaction_fixture",{"completion":completion.status,"reason":String(completion.reason),"replay":replay.status,"different_end":duplicate.status,"run_ends":emitted.count,"native_boss_combat":false})
	var old_life := DemoLifetime.new()
	var formal := DemoRunDirector.new(old_life)
	formal.start("original-formal-fixture",RunProfile.formal())
	formal.complete_stage(old_life.token())
	var refused := formal.finish_delivery(old_life.token(),&"fixture_formal_not_delivery")
	_record("director/formal_not_delivery",refused.status==DemoRunResult.Status.INVALID and old_life.active and formal.state==DemoRunDirector.State.IN_STAGE,"director_transaction_fixture",{"profile":String(formal.profile.profile_id),"refusal":refused.status,"native_boss_combat":false})
	old_life.end()

func _bind_identity(candidate: Node2D) -> Dictionary:
	return {"hosted":candidate.get("hosted"),"run_id":candidate.get("run_id"),"player":candidate.player.get_instance_id() if is_instance_valid(candidate.player) else 0,"motor":candidate.motor.get_instance_id() if is_instance_valid(candidate.motor) else 0,"policy":candidate.policy.get_instance_id() if is_instance_valid(candidate.policy) else 0,"wallet":candidate.wallet.get_instance_id(),"lifetime":candidate.lifetime.get_instance_id(),"segment":candidate.segment.get_instance_id(),"meta":candidate.meta.get_instance_id(),"region_state":candidate.region_state.get_instance_id()}

func _binding_services() -> Dictionary:
	return {"policy":app.policy,"lifetime":app.lifetime,"wallet":app.wallet,"segment":app.segment,"meta":app.meta,"region_state":app.region_state}

func _bind_guards() -> void:
	var scene := load("res://scenes/mapgen/seed_930001.tscn") as PackedScene
	var names: Array[String] = ["empty_services","empty_identity","null_player","wrong_policy","null_lifetime","wrong_wallet","wrong_segment","wrong_meta","wrong_region","foreign_lifetime"]
	for name: String in names:
		var candidate: Node2D = scene.instantiate()
		var before := _bind_identity(candidate)
		var services := _binding_services()
		var controller := app.controller
		var identity := "bind-fixture/"+name
		var wrong_node: Node
		match name:
			"empty_services": services = {}
			"empty_identity": identity = ""
			"null_player": controller = null
			"wrong_policy": wrong_node = Node.new(); services.policy = wrong_node
			"null_lifetime": services.lifetime = null
			"wrong_wallet": services.wallet = RefCounted.new()
			"wrong_segment": services.segment = RefCounted.new()
			"wrong_meta": services.meta = RefCounted.new()
			"wrong_region": services.region_state = RefCounted.new()
			"foreign_lifetime": services.lifetime = DemoLifetime.new()
		var accepted: bool = candidate.bind_existing(controller,services,identity)
		_record("bind_api/refuse/"+name,not accepted and _bind_identity(candidate)==before,"unparented_binding_fixture",{"case":name,"accepted":accepted,"no_partial_assignment":_bind_identity(candidate)==before,"added_to_tree":false})
		candidate.free()
		if wrong_node != null: wrong_node.free()
	var configured: Node2D = scene.instantiate()
	var first: bool = configured.bind_existing(app.controller,_binding_services(),"bind-fixture/valid")
	var preserved := _bind_identity(configured)
	var rebound: bool = configured.bind_existing(app.controller,_binding_services(),"bind-fixture/rebound")
	_record("bind_api/no_rebind",first and not rebound and _bind_identity(configured)==preserved,"unparented_binding_fixture",{"first":first,"rebind":rebound,"no_partial_assignment":_bind_identity(configured)==preserved,"added_to_tree":false})
	configured.free()
	var live_before := _bind_identity(app.stage)
	var live_rebind: bool = app.stage.bind_existing(app.controller,_binding_services(),"bind-fixture/in-tree")
	_record("bind_api/in_tree_refused",not live_rebind and _bind_identity(app.stage)==live_before,"actual_hosted_stage",{"refused":not live_rebind,"unchanged":_bind_identity(app.stage)==live_before})

func _hosted_chest() -> void:
	var module: Node2D = app.stage.registry.instances.M29
	var consumer: Node = module.original_region_chests
	app.lifetime.invalidate_actor()
	app.controller.router.clear("mapgen_main_chest_fixture")
	app.player.global_position = module.to_global(Vector2(270,20))
	app.player.reset_motion()
	await _frames(16)
	var before_coins := app.wallet.balance
	var before_notes := int(app.meta.snapshot().notes)
	var grounded := app.player.is_on_floor()
	_key(KEY_W,true); _key(KEY_W,false)
	for frame: int in 12:
		await _process_frames(1)
		if consumer.app.reward_modal.opened: break
	var opened: bool = consumer.app.reward_modal.opened
	_record("ordinary/M29_native_W",grounded and opened and paused,"scoped_native_player_interaction",{"instance":"M29","initial_local":[270,20],"fixture_placement":true,"natural_reachability":false,"grounded":grounded,"actual_key":"W","modal_open":opened,"paused":paused})
	for attempt: int in 2:
		_key(KEY_M,true); _key(KEY_M,false)
		_key(KEY_ESCAPE,true); _key(KEY_ESCAPE,false)
		await _process_frames(2)
	_record("ordinary/M29_pause_owner",opened and consumer.app.reward_modal.opened and paused and app.menu.visible_panel.is_empty() and not bool(app.stage.get("_map_view")),"native_input_dispatch",{"keys":["M","Escape","M","Escape"],"nested_modal":consumer.app.reward_modal.opened,"main_menu_panel":String(app.menu.visible_panel),"paused":paused,"map_view":app.stage.get("_map_view")})
	var selected: Button
	if opened:
		for card: Node in consumer.app.reward_modal._options.get_children():
			var item := card.get("item") as ResourceRewardChoice
			if item != null and item.resource_kind=="coin":
				var buttons := card.find_children("*","Button",true,false)
				if not buttons.is_empty(): selected = buttons[0] as Button
	await _click(selected,"M29_coin_choice")
	await _frames(3)
	var snapshot: Dictionary = consumer.snapshot()
	_record("ordinary/M29_mouse_OR_commit",opened and snapshot.chests[0].claimed and app.wallet.balance==before_coins+4 and app.meta.snapshot().notes==before_notes and not consumer.app.reward_modal.opened and not paused,"native_gui_pointer_and_region_transaction",{"instance":"M29","selected":"coin","wallet_before":before_coins,"wallet_after":app.wallet.balance,"notes_before":before_notes,"notes_after":app.meta.snapshot().notes,"claimed":snapshot.chests[0].claimed,"modal_open":consumer.app.reward_modal.opened,"paused":paused})

func _count(node: Node, kind: String) -> int:
	var total := 0
	if kind=="player" and node is PlayerMotor: total += 1
	elif kind=="router" and node is InputRouter: total += 1
	elif kind=="keyboard" and node is KeyboardMouseAdapter: total += 1
	elif kind=="policy" and node is FrameDamagePolicy: total += 1
	elif kind=="audio" and node is GameAudio: total += 1
	elif kind=="music" and node is GameMusic: total += 1
	elif kind=="touch" and node is TouchOverlay: total += 1
	for child: Node in node.get_children(): total += _count(child,kind)
	return total

func _inventory(label: String) -> void:
	var map := app.stage
	var seals := 0
	var terrain_unique := true
	for spec: Dictionary in map.registry.map_data.instances:
		var instance: Node2D = map.registry.instances[spec.id]
		seals += spec.seals.size()
		terrain_unique = terrain_unique and instance.module.definition.platforms.size()==instance.content.platforms.size()
	_record("binding/inventory/"+label,map.hosted and map.registry.instances.size()==46 and map.registry.map_data.connections.size()==55 and seals==40 and terrain_unique,"static_main_runtime_inventory",{"hosted":map.hosted,"instances":map.registry.instances.size(),"connections":map.registry.map_data.connections.size(),"seals":seals,"terrain_unique":terrain_unique})
	var counts := {"players":_count(app,"player"),"routers":_count(app,"router"),"keyboards":_count(app,"keyboard"),"policies":_count(app,"policy"),"audio":_count(app,"audio"),"music":_count(app,"music"),"touch":_count(app,"touch")}
	_record("binding/single_host_services/"+label,counts.players==1 and counts.routers==1 and counts.keyboards==1 and counts.policies==1 and counts.audio==1 and counts.music==1 and counts.touch==1,"static_main_runtime_inventory",counts)

func _natural_start() -> void:
	var map := app.stage
	var motor := app.player
	var actor := app.controller
	var initial_hp := actor.actor_resources.health.current
	var initial_wallet := app.wallet.balance
	var native_actor := motor.get_instance_id()
	var module: Node2D = map.registry.instances.M01
	var latch: ShotLatch = module.cells.latches[0]
	var target := module.to_global(latch.bell_position)
	var direction := (target-motor.global_position).normalized()
	var visual := motor.get_node_or_null("CourierVisual") as CourierVisual
	if visual != null:
		for iteration: int in 8: direction = (target-visual.muzzle_position(direction)).normalized()
	actor.shoot_ability.shot_fired.connect(func(_direction: Vector2,_id: int) -> void: shots += 1)
	var before_shots := shots
	actor.router.request_action(&"shoot_release",direction)
	await _frames(90,true)
	_record("natural/native_bell",shots>before_shots and latch.is_open and latch.open_count==1,"continuous_native_player",{"weapon":String(actor.shoot_ability.weapon.id),"accepted_shots":shots-before_shots,"open_count":latch.open_count,"gate_disabled":latch.gate_shape.disabled,"position_fixture":false})
	actor.router.set_move_axis(1.0)
	for frame: int in 180:
		await _frames(1,true)
		if motor.global_position.x>=540 or not actor.active: break
	actor.router.set_move_axis(0)
	await _frames(3,true)
	_record("natural/M01_to_M02",motor.global_position.x>=540 and motor.get_instance_id()==native_actor and actor.actor_resources.health.current==initial_hp and app.wallet.balance==initial_wallet,"continuous_native_player",{"connection":"C001","from":"M01.exit","to":"M02.R","position":[motor.global_position.x,motor.global_position.y],"same_actor":motor.get_instance_id()==native_actor,"health_before":initial_hp,"health_after":actor.actor_resources.health.current,"wallet_before":initial_wallet,"wallet_after":app.wallet.balance,"position_fixture":false,"extra_fixture_ability_used":false})

func _controls() -> void:
	var epoch := app.controller.router.epoch
	_key(KEY_M,true); _key(KEY_M,false)
	await _process_frames(3)
	_record("ordinary/map_open",paused and bool(app.stage.get("_map_view")) and app.controller.router.epoch>epoch,"native_input_dispatch",{"key":"M","paused":paused,"overview":app.stage.get("_map_view")})
	_key(KEY_M,true); _key(KEY_M,false)
	await _process_frames(3)
	_record("ordinary/map_close",not paused and not bool(app.stage.get("_map_view")),"native_input_dispatch",{"key":"M","paused":paused,"overview":app.stage.get("_map_view")})
	_key(KEY_ESCAPE,true); _key(KEY_ESCAPE,false)
	await _process_frames(3)
	var steps := app.player.motion_steps
	await _process_frames(3)
	_record("ordinary/pause_open",paused and app.player.motion_steps==steps,"native_input_dispatch",{"key":"Escape","paused":paused,"menu_panel":String(app.menu.visible_panel),"motion_steps_stable":app.player.motion_steps==steps})
	var pause_panel := app.menu.visible_panel
	for attempt: int in 2:
		_key(KEY_M,true); _key(KEY_M,false)
		await _process_frames(2)
	_record("ordinary/pause_M_guard",paused and app.menu.visible_panel==pause_panel and not bool(app.stage.get("_map_view")) and app.player.motion_steps==steps,"native_input_dispatch",{"keys":["M","M"],"pause_panel_before":String(pause_panel),"pause_panel_after":String(app.menu.visible_panel),"paused":paused,"map_view":app.stage.get("_map_view"),"motor_still":app.player.motion_steps==steps})
	_key(KEY_ESCAPE,true); _key(KEY_ESCAPE,false)
	await _process_frames(3)
	_record("ordinary/pause_close",not paused,"native_input_dispatch",{"key":"Escape","paused":paused,"menu_panel":String(app.menu.visible_panel)})
	paused = false
	var actor_before := app.player.get_instance_id()
	var epoch_before := app.lifetime.epoch
	_key(KEY_ENTER,true); _key(KEY_ENTER,false)
	_key(KEY_F5,true); _key(KEY_F5,false)
	await _frames(3)
	_record("ordinary/no_hidden_exit_keys",is_instance_valid(app.stage) and app.player.get_instance_id()==actor_before and app.lifetime.active and app.lifetime.epoch==epoch_before and ends.is_empty(),"native_input_dispatch",{"keys":["Enter","F5"],"same_actor":app.player.get_instance_id()==actor_before,"run_epoch_before":epoch_before,"run_epoch_after":app.lifetime.epoch,"run_ends":ends.size()})

func _native_boss() -> void:
	var map := app.stage
	var binding: Node2D = map.boss_binding
	var arena: Node2D = map.registry.instances.M40
	var actor := app.controller
	var motor := app.player
	app.lifetime.invalidate_actor()
	actor.router.clear("mapgen_main_boss_fixture")
	motor.global_position = arena.to_global(Vector2(1096,462))
	motor.reset_motion()
	await _frames(8)
	_record("boss/hosted_arrival",binding.started,"scoped_native_player",{"instance":"M40","fixture_placement":true,"natural_whole_map_arrival":false,"position":[motor.global_position.x,motor.global_position.y],"player_id":motor.get_instance_id()})
	await _v5_boss_authority(binding)
	actor.shoot_ability.shot_fired.connect(func(_direction: Vector2,_id: int) -> void: shots += 1)
	observed_phases.clear()
	var shots_before := shots
	for frame: int in 3000:
		if not is_instance_valid(app.stage) or not actor.active: break
		observed_phases[binding.encounter.stage_phase] = true
		var local := arena.to_local(motor.global_position)
		actor.router.set_move_axis(clampf((1000.0-local.x)/45.0,-1,1))
		# The V5 native authorization probe already waited through the real intro.
		if frame%60==0:
			var target: Vector2 = binding.boss.global_position+binding.encounter.definition.collision_offset
			var direction := (target-motor.global_position).normalized()
			var visual := motor.get_node_or_null("CourierVisual") as CourierVisual
			if visual != null:
				for iteration: int in 8: direction = (target-visual.muzzle_position(direction)).normalized()
			actor.router.request_action(&"shoot_release",direction)
		await _frames(1,frame%6==0)
	if is_instance_valid(actor): actor.router.clear("mapgen_main_boss_pilot_end")
	var result: Dictionary = ends.back() if ends.size()>=2 else {}
	_record("boss/hosted_native_victory",result.get("reason")=="delivery_complete" and result.get("boss_health",-1)==0 and result.get("player_health",0)>0 and result.get("boss_completed",false) and observed_phases.has(1) and observed_phases.has(2) and observed_phases.has(3),"scoped_native_player_combat",{"end":result,"accepted_shots":shots-shots_before,"phases_observed":observed_phases.keys(),"pilot":"actual Router hold x1000; 1 shot/60ticks; no healing/ammo grant, no reposition after arrival","natural_whole_map_arrival":false})

func _v5_boss_authority(binding: Node2D) -> void:
	var actor := app.controller
	var motor := app.player
	# Native Windkeeper rejects all combat in its real intro. Wait on that
	# state using ordinary movement input; never edit its timers or health.
	for frame: int in 240:
		var arena: Node2D = app.stage.registry.instances.M40
		actor.router.set_move_axis(clampf((1000.0-arena.to_local(motor.global_position).x)/45.0,-1,1))
		if binding.encounter.mode!=&"intro": break
		await _frames(1)
	actor.router.set_move_axis(0)
	var runtime := app._item_runtime
	var item := ItemCatalogV5.get_item(&"G01")
	var was_paused := paused
	paused = true
	var acquired := app.build.add_item(&"mapgen_main_G01",item,&"test_fixture")
	var owned := app.build.inventory.instance_for_source(&"mapgen_main_G01")
	var proposal: Array[StringName] = []
	if owned != null: proposal.append(owned.instance_id)
	var session := app.build.equipment.open_session(app.lifetime.token())
	var equip := app.build.equipment.submit(proposal,app.lifetime.token(),session,int(app.build.equipment.snapshot().revision))
	app.build.equipment.close_session()
	paused = was_paused
	await _process_frames(3)
	_record("boss/v5_equipped_native",acquired and owned!=null and equip.accepted and runtime!=null and actor.item_runtime==runtime and runtime.has(&"G01"),"native_equipment_fixture",{"item":"G01","acquired":acquired,"equip":equip,"same_runtime":actor.item_runtime==runtime,"fixture":"native BuildState ownership and EquipmentService session; no manual authorization ledger"})
	if runtime==null or not runtime.has(&"G01"): return
	var receiver := binding.boss.get_node("Damageable") as Damageable
	var original_sink := receiver.damage_sink
	var captured: Array[Dictionary] = []
	receiver.damage_sink = func(context: Dictionary) -> bool:
		captured.append(context.duplicate())
		# These independent copies run BEFORE the first genuine event reaches
		# the policy, so rejection cannot be explained by event de-duplication.
		# No original context, authorization ledger, target HP or epoch is edited.
		for kind: String in ["unregistered_flag","source_actor","session","amount"]:
			var forged := context.duplicate()
			match kind:
				"unregistered_flag": forged.event_id = StringName(str(context.event_id)+"/unregistered"); forged.item_effect_damage = true
				"source_actor": forged.source_actor_id = int(context.source_actor_id)+1
				"session": forged.session_id = int(context.session_id)+1
				"amount": forged.amount = float(context.amount)+1.0
			var authority: bool = runtime.authorizes_effect(forged,receiver)
			var forwarded: bool = original_sink.call(forged)
			var refused: bool = not forwarded and (not authority if kind in ["unregistered_flag","amount"] else true)
			_record("boss/v5_refuse/"+kind,refused,"native_item_authority_negative_fixture",{"mutation":kind,"runtime_authorizes":authority,"sink_accepted":forwarded,"policy_event_not_yet_forwarded":true,"event_id_changed":kind=="unregistered_flag","scope":"runtime proof for amount/registration; hosted source guard for incoming actor/session"})
			forged.clear()
		# Forward the real native Runtime.deal context byte-for-byte unchanged.
		return original_sink.call(context)
	var before: float = binding.encounter.health.current
	var accepted := runtime.deal(receiver,1.0,&"mapgen_main_native_G01",&"G01")
	await _frames(2)
	var after: float = binding.encounter.health.current
	var proof: Dictionary = captured[0].duplicate() if not captured.is_empty() else {}
	var real_authority := not proof.is_empty() and runtime.authorizes_effect(proof,receiver)
	_record("boss/v5_native_policy_damage",accepted and captured.size()==1 and real_authority and is_equal_approx(before-after,1.0),"native_item_effect_and_damage_policy",{"accepted":accepted,"captured_contexts":captured.size(),"runtime_authorizes_real_context":real_authority,"boss_health_before":before,"boss_health_after":after,"native_amount":1,"item":"G01","fixture":"real Runtime.deal with equipped original catalog item; damage applied by FrameDamagePolicy"})
	receiver.damage_sink = original_sink
	paused = true
	var unequip_session := app.build.equipment.open_session(app.lifetime.token())
	var empty: Array[StringName] = []
	var unequip := app.build.equipment.submit(empty,app.lifetime.token(),unequip_session,int(app.build.equipment.snapshot().revision))
	app.build.equipment.close_session()
	paused = was_paused
	# Inspect immediate authoritative revision rejection before any deferred
	# runtime cache notification can hide a stale loadout authorization.
	var stale_authority := not proof.is_empty() and runtime.authorizes_effect(proof,receiver)
	var stale_forwarded: bool = original_sink.call(proof) if not proof.is_empty() else false
	var removed_deal := runtime.deal(receiver,1.0,&"mapgen_main_removed_G01",&"G01")
	_record("boss/v5_unequip_revokes",unequip.accepted and app.build.equipment.equipped_ids().is_empty() and not stale_authority and not stale_forwarded and not removed_deal,"native_item_authority_negative_fixture",{"unequip":unequip,"old_proof_authorized":stale_authority,"old_sink_accepted":stale_forwarded,"new_Runtime_deal_accepted":removed_deal,"empty_equipment":app.build.equipment.equipped_ids().is_empty(),"immediate_revision_check":true})
	captured.clear()
	proof.clear()
	await _frames(2)
	_record("boss/v5_no_hidden_regrant",is_equal_approx(binding.encounter.health.current,after) and app.controller.shoot_ability.weapon.id==&"pulse_gun","native_item_authority_negative_fixture",{"boss_health_after_accepted_damage":after,"boss_health_after_refusals":binding.encounter.health.current,"weapon":String(app.controller.shoot_ability.weapon.id),"health_manually_restored":false})

func _death_fixture(old_token: DemoToken) -> void:
	var policy := app.policy
	var health := app.controller.actor_resources.health
	var stale := DamageRequest.new()
	stale.token = old_token
	stale.event_id = &"mapgen_main_stale_run"
	stale.source_id = &"mapgen_main_fixture"
	stale.target_id = &"player"
	stale.actor_epoch = old_token.actor_epoch
	stale.health_epoch = health.epoch
	stale.amount = 1
	_record("lifecycle/stale_epoch_refused",not policy.submit(stale) and not app.lifetime.accepts(old_token),"native_damage_transaction_fixture",{"old_token":old_token.key(),"current_token":app.lifetime.token().key(),"player_health":health.current})
	for frame: int in 60:
		if policy.player_clock()>=policy._protected_until: break
		await _frames(1)
	var fatal := DamageRequest.new()
	fatal.token = app.lifetime.token()
	fatal.event_id = &"mapgen_main_fatal"
	fatal.source_id = &"mapgen_main_fixture"
	fatal.target_id = &"player"
	fatal.actor_epoch = app.lifetime.actor_epoch
	fatal.health_epoch = health.epoch
	fatal.amount = health.current
	var accepted := policy.submit(fatal)
	_record("lifecycle/native_fatal_submitted",accepted,"native_damage_transaction_fixture",{"accepted":accepted,"damage":fatal.amount,"health_epoch":health.epoch,"actor_epoch":fatal.actor_epoch,"direct_request":true,"natural_enemy_combat":false})
	await _frames(4)

func _run_ended(result: DemoRunResult) -> void:
	var receipt := {"reason":String(result.reason),"event_id":String(result.event_id),"run_epoch":result.run_epoch,"stage_epoch":result.stage_epoch,"player_health":app.controller.actor_resources.health.current if is_instance_valid(app.controller) else -1,"gold_claimed":app._gold_claimed,"status":app._status,"meta":app.meta.snapshot()}
	if is_instance_valid(app.stage) and app.stage.get("boss_binding")!=null:
		var map := app.stage
		var binding: Node2D = map.boss_binding
		receipt.boss_health = binding.encounter.health.current
		receipt.boss_completed = binding.completed
		receipt.boss_snapshot = binding.snapshot()
		var arena: Node2D = map.registry.instances.M40
		var transform := app.player.global_transform
		transform.origin = arena.to_global(Vector2(76,448))
		var hit := KinematicCollision2D.new()
		var blocked := app.player.test_move(transform,Vector2(-120,0),hit,.001,true)
		var collider := hit.get_collider() as Node
		receipt.exit_sealed = blocked and collider != null and str(collider.get_path())==str(arena.get_path())+"/Seal_exit"
	ends.append(receipt)

func _finish() -> void:
	paused = false
	if is_instance_valid(app):
		var drained := await TEARDOWN.drain_world(app)
		_record("main/audio_teardown",drained,"lifecycle")
		app.queue_free()
		await process_frame
		await process_frame
		app = null
	var report := {"schema":"gunman/mapgen-main-tests/v1","seed":930001,"checks":checks,"failures":failures,"cases":rows,"trace":trace,"starts":starts,"ends":ends,"whole_map_continuous_traversal":"NOT_RUN","human_playtest":false,"device_playtest":false,"scope":"Actual Title/Home/BEGIN/retry GUI into fixed map; natural M01→M02; separate native loadout/economy, Boss-arrival and fatal-request fixtures.","viewport":[root.size.x,root.size.y],"display_server":DisplayServer.get_name()}
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null: push_error("mapgen_main_report_write_failed"); quit(2); return
	file.store_string(JSON.stringify(report,"  ")+"\n")
	file.close()
	print("MAPGEN MAIN: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
