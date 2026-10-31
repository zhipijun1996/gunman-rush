extends SceneTree
## Explicit settlement/equipment/transition fixture. No direct result call is traversal or natural-menu proof.
const GEAR := preload("res://tests/gear_inventory_support.gd")
# Independent v2 playtest-default expectation; no commercial admission claim.
const EXPECTED_PUBLIC_FOREST := "thorn-forest-region-v2"
const EXPECTED_FOREST_BOSSES := {
	"thorn-forest-region-v1": {
		1: {"definition":"res://resources/bosses/thorn_guardian.tres","scene":"res://scenes/bosses/thorn_guardian.tscn"},
		2: {"definition":"res://resources/bosses/thorn_queen.tres","scene":"res://scenes/bosses/thorn_queen.tscn"}},
	"thorn-forest-region-v2": {
		1: {"definition":"res://resources/bosses/rootbell_guardian_v2.tres","scene":"res://scenes/bosses/rootbell_guardian_v2.tscn"},
		2: {"definition":"res://resources/bosses/thorn_queen_canopy.tres","scene":"res://scenes/bosses/thorn_queen_canopy.tscn"}}
}
var assertions := 0
var failures := 0
var pointer_events: Array[Dictionary] = []
var callback_counts := {"reward":0,"ability":0,"region":0}
var selected_reward_ids: Array[StringName] = []
var app: DemoApp
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+message)
func frames(count: int) -> void:
	for i: int in count: await physics_frame
func defeat_fixture() -> bool:
	var region := app.stage as PlainsRegionStage
	app.player.reset_at(region.boss_arena.get_center())
	await frames(3)
	if not app._boss_started: return false
	var boss := region.boss.get_node("Encounter") as BossEncounter
	var request := DamageRequest.new()
	request.token=app.lifetime.token()
	request.actor_epoch=app.lifetime.actor_epoch
	request.health_epoch=boss.health.epoch
	request.target_id=&"boss"
	request.source_id=&"explicit_settlement_fixture"
	request.event_id=app._next_id("fixture_defeat")
	request.amount=boss.health.current
	if not app.policy.submit(request): return false
	await frames(65)
	return app.director.stage_complete
func gate_fixture() -> bool:
	app.player.reset_at(app.stage.reward_position)
	await frames(2)
	if app.exit_modal.opened: return app._confirm_generated_exit()
	return app._enter_generated_exit(&"boss_home")
func pointer_click(owner: Node, prefix: String) -> bool:
	for i: int in 4: await process_frame
	for button: Button in owner.find_children("*","Button",true,false):
		if not button.visible or button.disabled or not button.text.begins_with(prefix): continue
		var point := button.get_global_rect().get_center()
		for pressed: bool in [true,false]:
			var event := InputEventMouseButton.new()
			event.position=point
			event.global_position=point
			event.button_index=MOUSE_BUTTON_LEFT
			event.pressed=pressed
			pointer_events.append({"button":button.text,"pressed":pressed,"point":[point.x,point.y],"rect":[button.global_position.x,button.global_position.y,button.size.x,button.size.y]})
			root.push_input(event,true)
			await process_frame
		return true
	return false
func check_default_forest_identity(map_index: int) -> void:
	check_region_presentation(&"thorn_forest")
	check(app.stage is ThornForestRegionStage and is_instance_valid(app.stage.boss),"default forest actual stage and Boss exist")
	if not app.stage is ThornForestRegionStage or not is_instance_valid(app.stage.boss): return
	var expected: Dictionary=EXPECTED_FOREST_BOSSES[EXPECTED_PUBLIC_FOREST][map_index]
	var encounter := app.stage.boss.get_node("Encounter") as BossEncounter
	check(app.forest_content_version==EXPECTED_PUBLIC_FOREST and app.stage.generated.manifest.version==EXPECTED_PUBLIC_FOREST and app.stage.generated.manifest.map_index==map_index,"natural region selection retains independently expected public forest version map%s"%map_index)
	check(encounter!=null and encounter.definition!=null and encounter.definition.resource_path==expected.definition,"natural default forest actual Boss Definition matches selected version map%s"%map_index)
	check(app.stage.boss.scene_file_path==expected.scene,"natural default forest actual Boss scene matches selected version map%s"%map_index)
	check(app.stage.generated.manifest.layout_version=="forest-bible-world-v15","fresh default uses independently expected Bible layout; historical replay is separately mandatory")
func check_region_presentation(region: StringName) -> void:
	# Reuse actual consumers, not a second region transition implementation.
	# Existing Boss/reward reset_at fixtures remain explicit settlement evidence.
	var errors: Array[String] = load("res://tests/parallel_region_presentation_tests.gd").presentation_errors(app,region)
	check(errors.is_empty(),"actual shared presentation: %s" % [errors])
func inventory_identity() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for instance: RunItemInstance in app.build.inventory.instances():
		result.append({"instance_id":str(instance.instance_id),"definition_id":str(instance.definition_id),"definition_version":instance.definition_version,"source_id":str(instance.source_id),"origin":str(instance.origin),"level":instance.level})
	return result
func receipt_identity(receipt: EconomyReceipt) -> Dictionary:
	if receipt == null: return {}
	return {"status":receipt.status,"event_id":str(receipt.event_id),"item_id":str(receipt.item_id),"instance_id":str(receipt.instance_id),"coins":receipt.coins,"gear_capacity":receipt.gear_capacity,"gear_level":receipt.gear_level}
func run() -> void:
	var before:=DisplayServer.window_get_size()
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.size=Vector2i(1280,720)
	print("FOREST_CAMPAIGN_WINDOW ",JSON.stringify({"physical_before":[before.x,before.y],"physical":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"viewport":[root.size.x,root.size.y],"screen_scale":[root.get_screen_transform().get_scale().x,root.get_screen_transform().get_scale().y]}))
	app=DemoApp.new()
	app.meta_persistence_enabled=false
	root.add_child(app)
	app.reward_modal.item_selected.connect(func(id: StringName) -> void:
		callback_counts.reward+=1
		selected_reward_ids.append(id))
	app.progression_modal.ability_selected.connect(func(_id: StringName) -> void: callback_counts.ability+=1)
	app.progression_modal.region_selected.connect(func(_id: StringName) -> void: callback_counts.region+=1)
	check(app.start_plains("campaign-integration"),"formal campaign starts plains map1")
	await frames(12)
	check(app.stage != null and app.stage.assembly_ok and app.director.region_map_index==1,"formal first map assembled")
	check_region_presentation(&"plains")
	if not is_instance_valid(app.stage) or not app.stage.assembly_ok: await finish(); return
	check(RunManifest.from_snapshot(JSON.parse_string(app.director.manifest.canonical_json()))!=null,"schema1 Plains manifest roundtrip")
	check(await defeat_fixture(),"explicit Plains mini settlement fixture")
	check(await gate_fixture(),"formal mini gate accepts")
	await frames(12)
	check(app.director.region_map_index==2 and app.director.stage_index==2,"formal Plains map2 follows map1")
	check_region_presentation(&"plains")
	var actor_id := app.player.get_instance_id()
	var health := app.controller.actor_resources.health
	check(await defeat_fixture(),"explicit policy fixture opens gold reward")
	check(await gate_fixture() and app.reward_modal.opened,"GOLD item remains separate panel")
	var actual_gold_candidates: Dictionary = {}
	for item: ItemDefinition in app.current_reward.candidates:
		actual_gold_candidates[item.stable_id] = item.duplicate(true)
	check(await pointer_click(app.reward_modal,"选择 / PICK") and app.progression_modal.opened,"actual mouse GOLD button settles before core choice")
	var actual_gold_id: StringName = selected_reward_ids[0] if not selected_reward_ids.is_empty() else &""
	var actual_gold: ItemDefinition = actual_gold_candidates.get(actual_gold_id) as ItemDefinition
	var actual_gold_instance := app.build.inventory.instance_for_definition(actual_gold_id)
	check(callback_counts.reward==1 and actual_gold!=null and actual_gold.catalog_version==5 and actual_gold.rarity==ItemDefinition.Rarity.GOLD and actual_gold_instance!=null and app.build.count_item(actual_gold_id)==1,"one actual mouse callback grants exactly the selected current V5 gold candidate")
	if actual_gold == null or actual_gold_instance == null: await finish(); return
	var actual_gold_instance_id: StringName = actual_gold_instance.instance_id
	var owned_after_gold := app.build.inventory.instances().size()
	check(not app._claim_modal_item(actual_gold_id) and app.build.count_item(actual_gold_id)==1 and app.build.inventory.instances().size()==owned_after_gold and app.build.inventory.instance_for_definition(actual_gold_id).instance_id==actual_gold_instance_id,"replayed settled actual gold cannot stack, replace its instance or submit again")
	check(not app.controller.traversal.hook_enabled,"gold item does not itself grant H")
	check(app.build.item_ids().is_empty() and app.build.count_item(actual_gold_id)==1 and not app._item_runtime.has(actual_gold_id),"settled V5 gold first remains in backpack without automatic equipment or runtime effect")
	# Explicit fixture after the real GOLD button: use the same paused session,
	# RunWallet debit and transaction ledger as production. The legacy +2 probe is
	# separately labeled initialization, never reported as the natural V5 reward.
	var legacy_probe_source: StringName = &"fixture/campaign/legacy_damage_plus_two_probe"
	check(app.build.add_item(legacy_probe_source,preload("res://resources/items/power_gold.tres"),&"fixture"),"explicit legacy +2 probe enters ownership under its separate fixture source")
	var legacy_probe := app.build.inventory.instance_for_source(legacy_probe_source)
	check(legacy_probe!=null and legacy_probe.definition_id==&"power_gold" and legacy_probe.instance_id!=actual_gold_instance_id and legacy_probe.origin==&"fixture" and actual_gold_instance.source_id!=legacy_probe_source,"legitimate V5 reward provenance remains distinct from explicit legacy stat probe")
	var damage_before_equipment: float = app.controller.motor.tuning.projectile_damage
	var explicit_loadout: Array[StringName] = [actual_gold_instance_id]
	if legacy_probe != null: explicit_loadout.append(legacy_probe.instance_id)
	check(paused and GEAR.equip_ids(app.build,explicit_loadout) and app.build.equipment.equipped_ids()==explicit_loadout and app.build.equipment.capacity()==8 and app.controller.motor.tuning.projectile_damage==damage_before_equipment+2.0,"original paused gear session equips actual claimed gold plus separately initialized legacy +2 probe")
	app._item_runtime.sync()
	check(app._item_runtime.has(actual_gold_id) and not app._item_runtime.has(&"power_gold"),"real V5 runtime consumes selected actual gold while legacy probe remains a stat-only fixture")
	check(not app.controller.traversal.hook_enabled,"equipped random gold still cannot grant the independent core H")
	var gear_quote: Dictionary = app.shop.gear_quote()
	var gear_configuration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/gear_capacity.json"))
	var configured_first_upgrade: Dictionary = gear_configuration.upgrades[0]
	var quoted_upgrade_price := int(gear_quote.price)
	check(gear_quote.available and quoted_upgrade_price==int(configured_first_upgrade.price) and gear_quote.next_capacity==int(configured_first_upgrade.capacity) and gear_quote.level==0,"cross-region fixture uses actual configured first gear quote and capacity")
	var before_fixture_funding := app.wallet.balance
	check(app.wallet.grant(quoted_upgrade_price,&"fixture/campaign/configured_gear_price_funding") and app.wallet.balance==before_fixture_funding+quoted_upgrade_price,"explicit fixture funds one actual quoted upgrade price through original wallet grant ledger")
	var upgrade_events: Array[EconomyReceipt] = []
	app.shop.purchased.connect(func(receipt: EconomyReceipt) -> void:
		if receipt.item_id==&"gear_capacity": upgrade_events.append(receipt.copy()))
	var gear_request := ShopPurchaseRequest.new()
	gear_request.token=app.lifetime.token()
	gear_request.offer_id=&"gear_capacity"
	gear_request.quote_version=int(gear_quote.quote_version)
	gear_request.transaction_id=&"campaign_cross_region_gear_fixture"
	gear_request.equipment_session=app.build.equipment.open_session(gear_request.token)
	gear_request.equipment_revision=int(app.build.equipment.snapshot().revision)
	var coins_before_upgrade: int = app.wallet.balance
	var committed_upgrade: EconomyReceipt = app.shop.purchase_gear_upgrade(gear_request)
	app.build.equipment.close_session()
	check(committed_upgrade.status==EconomyReceipt.Status.COMMITTED and committed_upgrade.coins==-quoted_upgrade_price and committed_upgrade.gear_capacity==int(configured_first_upgrade.capacity) and committed_upgrade.gear_level==1 and app.wallet.balance==coins_before_upgrade-quoted_upgrade_price and app.build.equipment.capacity()==int(configured_first_upgrade.capacity) and upgrade_events.size()==1,"real paused upgrade commits one receipt and exact quoted run-coin debit before crossing")
	var inventory_before_region: Array[Dictionary] = inventory_identity()
	var equipped_before_region: Array[StringName] = app.build.equipment.equipped_ids()
	var capacity_before_region: int = app.build.equipment.capacity()
	var damage_before_region: float = app.controller.motor.tuning.projectile_damage
	var build_before_region: BuildState = app.build
	var wallet_before_region: RunWallet = app.wallet
	var shop_before_region: ShopService = app.shop
	var coins_before_region: int = app.wallet.balance
	var grants_before_region: Dictionary = app.wallet._grants.duplicate(true)
	var receipt_before_region: Dictionary = receipt_identity(app.shop.get_receipt(gear_request.transaction_id))
	check(receipt_before_region==receipt_identity(committed_upgrade),"committed gear receipt is readable from the authoritative shop ledger")
	var old_token := app.lifetime.token()
	app._select_core_ability(&"wall_climb")
	check(not app.controller.traversal.wall_enabled,"unbuilt Canyon choice is rejected by owner")
	check(await pointer_click(app.progression_modal,"H / GRAPPLE"),"actual mouse selects H button")
	check(app.controller.traversal.hook_enabled and app.campaign.abilities==[&"grapple"],"formal core choice actually grants H")
	check(await pointer_click(app.progression_modal,"ENTER / THORN FOREST"),"actual mouse selects Forest button")
	await frames(12)
	check(callback_counts.ability==1 and callback_counts.region==1,"actual ability and region callbacks fire exactly once")
	check(app.stage is ThornForestRegionStage and app.stage.assembly_ok and app.active_region_id==&"thorn_forest","formal cross-region assembles forest")
	check_default_forest_identity(1)
	# Any automatic pickup at the new spawn must have a real map-local coin source;
	# exact ledger deltas explain the balance rather than allowing an arbitrary increase.
	var grants_after_region: Dictionary = app.wallet._grants.duplicate(true)
	var previous_grants_retained := true
	for grant_id: StringName in grants_before_region:
		if not grants_after_region.has(grant_id) or grants_after_region[grant_id]!=grants_before_region[grant_id]: previous_grants_retained=false
	var actual_claimed_coin_sources: Dictionary = {}
	for pickup: Dictionary in (app.stage as GeneratedDemoStage).pickups:
		if pickup.kind=="coin" and pickup.claimed:
			var source := StringName("%s/stage_%s/%s" % [app._run_receipt_prefix,app.director.stage_index,pickup.id])
			actual_claimed_coin_sources[source]=int(pickup.amount)
	var new_coin_grants: Dictionary = {}
	var legitimate_new_grants := true
	var granted_delta := 0
	for grant_id: StringName in grants_after_region:
		if grants_before_region.has(grant_id): continue
		var amount: int = int(grants_after_region[grant_id])
		new_coin_grants[grant_id]=amount
		granted_delta+=amount
		if not actual_claimed_coin_sources.has(grant_id) or actual_claimed_coin_sources[grant_id]!=amount: legitimate_new_grants=false
	check(app.player.get_instance_id()==actor_id and app.controller.actor_resources.health==health and app.wallet==wallet_before_region and previous_grants_retained and legitimate_new_grants and app.wallet.balance==coins_before_region+granted_delta,"same actor health and exact run-wallet ledger balance persist across region")
	check(app.build.count_item(actual_gold_id)==1 and app.build.inventory.instance_for_definition(actual_gold_id).instance_id==actual_gold_instance_id and app.build.inventory.instance_for_source(legacy_probe_source).instance_id==legacy_probe.instance_id and app.build.count_item(&"power_gold")==1 and app._item_runtime.has(actual_gold_id) and app.controller.traversal.hook_enabled and not app.controller.traversal.wall_enabled and not app.controller.traversal.double_enabled,"actual V5 gold, separate fixture probe and native-selected H persist independently without extra S2 abilities")
	check(app.build==build_before_region and inventory_identity()==inventory_before_region and app.build.equipment.equipped_ids()==equipped_before_region and app.build.equipment.capacity()==capacity_before_region and capacity_before_region==10 and app.controller.motor.tuning.projectile_damage==damage_before_region,"cross-region transition preserves exact owned provenance, selected instances, ten gear and active effects")
	check(app.shop==shop_before_region and receipt_identity(app.shop.get_receipt(gear_request.transaction_id))==receipt_before_region,"same shop retains the exact committed expansion receipt across region epochs")
	var balance_before_replay: int = app.wallet.balance
	var replay_upgrade: EconomyReceipt = app.shop.purchase_gear_upgrade(gear_request)
	var replay_identity: Dictionary = receipt_identity(replay_upgrade)
	replay_identity.status=EconomyReceipt.Status.COMMITTED
	check(replay_upgrade.status==EconomyReceipt.Status.REPLAY and replay_identity==receipt_before_region and app.wallet.balance==balance_before_replay and app.build.equipment.capacity()==10 and app.build.equipment.equipped_ids()==equipped_before_region and upgrade_events.size()==1,"old committed upgrade command replays read-only after crossing without debit, equipment mutation or a second event")
	write_fixture_evidence("res://build/forest_playable/progression/cross_region_equipment.json",JSON.stringify({"scope":"explicit settlement and paused equipment fixture; native H/region buttons; not natural combat or player menu proof","actual_selected_v5_gold":str(actual_gold_id),"actual_gold_instance":str(actual_gold_instance_id),"legacy_stat_probe_source":str(legacy_probe_source),"configured_upgrade_price":quoted_upgrade_price,"fixture_funding_receipt":"fixture/campaign/configured_gear_price_funding","inventory_before":inventory_before_region,"inventory_after":inventory_identity(),"equipped_before":equipped_before_region,"equipped_after":app.build.equipment.equipped_ids(),"capacity_before":capacity_before_region,"capacity_after":app.build.equipment.capacity(),"wallet_object_before":str(wallet_before_region.get_instance_id()),"wallet_object_after":str(app.wallet.get_instance_id()),"coins_before":coins_before_region,"coins_after":app.wallet.balance,"grant_ledger_before":grants_before_region,"grant_ledger_after":grants_after_region,"new_actual_coin_grants":new_coin_grants,"receipt_before":receipt_before_region,"receipt_after":receipt_identity(app.shop.get_receipt(gear_request.transaction_id)),"replay":receipt_identity(replay_upgrade)},"  "))
	check(not app.lifetime.accepts(old_token),"old region token rejected after crossing")
	write_fixture_evidence("res://build/forest_playable/progression/cross_region_manifest.json",app.director.manifest.canonical_json())
	check(RunManifest.from_snapshot(JSON.parse_string(app.director.manifest.canonical_json()))!=null,"cross-region schema2 replay validates")
	check(RunManifest.from_snapshot(app.director.manifest.snapshot())!=null,"native campaign capability ledger roundtrip")
	var stale_snapshot := app.director.manifest.snapshot()
	stale_snapshot.stages.back().outputs.capability_snapshot.abilities=[]
	check(RunManifest.from_snapshot(stale_snapshot)==null,"forest without H provenance rejects")
	var malformed := app.director.manifest.snapshot()
	malformed.stages.back().outputs.capability_snapshot="invalid"
	check(RunManifest.from_snapshot(malformed)==null,"malformed capability rejected without runtime error")
	var fractional := app.director.manifest.snapshot()
	fractional.stages.back().outputs.region_map.map_index=1.5
	check(RunManifest.from_snapshot(fractional)==null,"fractional map identity cannot truncate to valid map")
	var forged_boss := app.director.manifest.snapshot()
	forged_boss.stages.back().outputs.boss_layout.health=1
	check(RunManifest.from_snapshot(forged_boss)==null,"boss definition identity cannot be forged")
	check(await defeat_fixture(),"forest mini policy fixture completes")
	check(await gate_fixture(),"forest mini gate accepts")
	await frames(12)
	check(app.stage is ThornForestRegionStage and app.director.region_map_index==2 and app.director.stage_index==4,"formal four maps preserve distinct global entries")
	check_default_forest_identity(2)
	check(RunManifest.from_snapshot(JSON.parse_string(app.director.manifest.canonical_json()))!=null,"forest second map replay validates")
	check(await defeat_fixture(),"forest final fixture completes")
	check(await gate_fixture() and app.reward_modal.opened,"forest final gate presents independent real gold candidates")
	var forest_gold_candidates: Array[StringName] = []
	for item: ItemDefinition in app.current_reward.candidates: forest_gold_candidates.append(item.stable_id)
	var before_forest_gold := app.build.inventory.instances().size()
	check(await pointer_click(app.reward_modal,"选择 / PICK"),"actual mouse claims independent forest gold reward")
	var forest_gold_id: StringName = selected_reward_ids.back() if not selected_reward_ids.is_empty() else &""
	check(callback_counts.reward==2 and forest_gold_id in forest_gold_candidates and app.build.count_item(forest_gold_id)==1 and app.build.inventory.instances().size()==before_forest_gold+1,"second native gold callback grants one actually offered forest definition alongside the separate legacy probe")
	check(not app._claim_modal_item(forest_gold_id) and app.build.inventory.instances().size()==before_forest_gold+1 and app.build.count_item(forest_gold_id)==1,"settled actual forest gold replay cannot add or upgrade another instance")
	check(await pointer_click(app.progression_modal,"D / DOUBLE JUMP"),"actual mouse selects legal D reward")
	check(app.controller.traversal.double_enabled and app.campaign.phase==RunCampaignProgression.Phase.BOUNDARY,"forest awards legal missing D and explicit S3 boundary")
	check(await pointer_click(app.progression_modal,"END THIS RUN"),"actual mouse confirms explicit end boundary")
	await frames(5)
	check(app.director.state==DemoRunDirector.State.HOME and app.wallet.balance==0 and app.build.item_ids().is_empty() and app.build.inventory.instances().is_empty() and app.campaign.abilities.is_empty(),"boundary ends run and clears coins/build/abilities")
	var presentation_home_errors: Array[String] = load("res://tests/parallel_region_presentation_tests.gd").home_errors(app)
	check(presentation_home_errors.is_empty(),"campaign Home has no stale presentation owner: %s" % [presentation_home_errors])
	await finish()
func finish() -> void:
	write_fixture_evidence("res://build/forest_playable/progression/campaign_pointer_events.json",JSON.stringify({"scope":"Godot real Viewport mouse press/release into actual Button; boss outcomes explicit fixtures; no OS/Web pointer claim","events":pointer_events,"callbacks":callback_counts,"assertions":assertions,"failures":failures}))
	paused=false
	if is_instance_valid(app):
		if not await load("res://tests/audio_teardown.gd").drain_world(app): failures += 1
		app.free()
	print("FOREST CAMPAIGN: %s assertions / %s failures" % [assertions,failures])
	quit(1 if failures else 0)

func write_fixture_evidence(path: String, content: String) -> void:
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	check(directory_error==OK,"fixture evidence output directory is available")
	if directory_error!=OK: return
	var output := FileAccess.open(path,FileAccess.WRITE)
	check(output!=null,"fixture evidence output file opens")
	if output==null: return
	output.store_string(content)
	output.close()
