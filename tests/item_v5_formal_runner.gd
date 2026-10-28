extends SceneTree
## ITEM-V5-01 formal DemoApp integration. All relocation, known rewards, income,
## high-HP training targets/platform and director completion are SETUP FIXTURES.
## This is neither a natural route clear nor physical keyboard/device evidence.
## Gameplay hits always enter the real Router/Controller/projectile/policy chain;
## this runner never calls ItemRuntime.on_hit or a successful-hit callback.
var app: Variant
var assertions := 0
var failures := 0
var committed: Array[Dictionary] = []
var policy_commits: Array[Dictionary] = []
var shot_count := 0
var training_point := Vector2.ZERO
var target_a: Damageable
var target_b: Damageable
var target_bodies: Array[Area2D] = []
var _fixture_serial := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func frames(count := 3) -> void:
	for unused: int in count: await process_frame

func ticks(count := 3) -> void:
	for unused: int in count:
		await physics_frame
		await process_frame

func wait_stage() -> bool:
	for unused: int in 240:
		if is_instance_valid(app.stage) and not app._stage_pending: return true
		await frames(1)
	return false

func ids(items: Array[ItemDefinition]) -> Array[StringName]:
	var result: Array[StringName] = []
	for item: ItemDefinition in items: result.append(item.stable_id)
	return result

func _shot(_direction: Vector2, _shot_id: int) -> void:
	shot_count += 1

func _committed(packet: int, shot: int, receiver: Damageable, session: int, weapon_epoch: int) -> void:
	committed.append({"packet":packet,"shot":shot,"target":receiver.actor_id,"session":session,"weapon_epoch":weapon_epoch})

func _batch(results: Array[DamageResult]) -> void:
	for result: DamageResult in results:
		policy_commits.append({"target":result.request.target_id,"amount":result.hp_lost,"derived":result.request.item_effect_damage,"event":result.request.event_id})

func attach_observers() -> void:
	if not app.controller.shoot_ability.shot_fired.is_connected(_shot): app.controller.shoot_ability.shot_fired.connect(_shot)
	if not app.controller.weapon_damage_committed.is_connected(_committed): app.controller.weapon_damage_committed.connect(_committed)
	app.policy.batch_resolved.connect(_batch)

func reward_fixture(id: StringName, tag: String) -> EconomyReceipt:
	# Explicit known-item reward fixture, through the original RewardService.
	var offer_id := StringName("formal_fixture/reward/" + tag)
	var definitions: Array[ItemDefinition] = [ItemCatalogV5.get_item(id)]
	var offer: RewardOffer = app.rewards.create_cache_offer(offer_id, definitions, StringName(str(offer_id) + "/source"))
	check(offer != null, "SETUP reward fixture is admitted by original RewardService: " + tag)
	if offer == null: return EconomyReceipt.rejected(EconomyReceipt.Status.INVALID)
	var request := RewardClaimRequest.new()
	request.token = app.lifetime.token()
	request.offer_id = offer_id
	request.option_id = id
	request.claim_id = StringName(str(offer_id) + "/claim")
	var receipt: EconomyReceipt = app.rewards.claim(request)
	check(receipt.accepted(), "SETUP known reward commits through original claim transaction: " + tag)
	var before_count: int = app.build.inventory.instances().size()
	var before_level: int = app.build.inventory.instance_for_definition(id).level if receipt.accepted() else -1
	var replay: EconomyReceipt = app.rewards.claim(request)
	check(replay.status == EconomyReceipt.Status.REPLAY and replay.instance_id == receipt.instance_id, "same reward claim ID returns the original instance receipt: " + tag)
	check(app.build.inventory.instances().size() == before_count and (app.build.inventory.instance_for_definition(id).level if receipt.accepted() else -1) == before_level, "same reward claim cannot duplicate or upgrade ownership: " + tag)
	return receipt

func ensure_owned(id: StringName) -> void:
	if app.build.inventory.instance_for_definition(id) == null: reward_fixture(id, String(id))

func equip(definitions: Array[StringName]) -> void:
	var desired: Array[StringName] = []
	for id: StringName in definitions:
		var owned: RunItemInstance = app.build.inventory.instance_for_definition(id)
		check(owned != null, "pause command fixture owns " + String(id))
		if owned != null: desired.append(owned.instance_id)
	app.toggle_pause()
	check(paused and app.menu.visible_panel == &"build" and app._equipment_session > 0, "formal pause menu creates the real equipment editing session")
	var revision: int = int(app.build.equipment.snapshot().revision)
	var session: int = app._equipment_session
	app._submit_equipment(desired, revision, session)
	check(app.build.equipment.equipped_ids() == desired, "DemoApp equipment command commits the selected actual instance IDs")
	# BuildState intentionally emits its changed signal deferred. Observe the
	# actual delivery while paused, without calling the runtime sync helper.
	await frames(2)
	var expected_effects: Array[StringName] = definitions.duplicate()
	expected_effects.sort_custom(func(left: StringName,right: StringName) -> bool: return String(left) < String(right))
	var actual_effects: Array[StringName] = ids_equipped_effects()
	if actual_effects != expected_effects:
		print("ITEM V5 FORMAL CACHE DIAGNOSTIC ",JSON.stringify({"command_definitions":definitions,"expected_set":expected_effects,"actual_set":actual_effects,"runtime_keys":app._item_runtime._effects.keys(),"equipment":app.build.equipment.snapshot()}))
	check(actual_effects == expected_effects, "formal ItemRuntime cache synchronizes with the equipment command")
	app.menu.close_panel()
	check(not paused and app._equipment_session < 0, "closing the real menu ends editing and resumes gameplay")
	await ticks(2)

func ids_equipped_effects() -> Array[StringName]:
	var result: Array[StringName] = []
	for owned: RunItemInstance in app.build.inventory.instances():
		if app._item_runtime.has(owned.definition_id): result.append(owned.definition_id)
	# Equipment and inventory can have different order; compare canonical sets.
	result.sort_custom(func(left: StringName,right: StringName) -> bool: return String(left) < String(right))
	return result

func catalog_node(prefix: String, id: StringName) -> Node:
	# Formal offer IDs contain '/'. The real modal uses validate_node_name()
	# when assigning its Control names, so resolve the same actual node name.
	return app.shop_modal.find_child(prefix+String(id).validate_node_name(),true,false)

func make_target(label: String, point: Vector2) -> Damageable:
	var body := Area2D.new()
	body.name = label
	body.collision_layer = 2 # Actual enemy hurtbox layer; no fake overlap callback.
	body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 28)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	var receiver := Damageable.new()
	receiver.name = "Damageable"
	receiver.faction = &"enemy"
	receiver.actor_id = body.get_instance_id()
	body.add_child(receiver)
	app.stage.add_child(body)
	body.global_position = point
	var definition := HealthDefinition.new()
	definition.resource_id = StringName("formal_fixture/" + label)
	definition.max_health = 1000.0
	definition.initial_current = 1000.0
	var health := HealthState.new()
	check(health.configure(definition), "SETUP high-HP training HealthState is valid: " + label)
	receiver.bind_health(health)
	check(app.policy.bind_damageable(StringName("formal_fixture/" + label), receiver, health), "training Damageable binds the actual formal FrameDamagePolicy: " + label)
	target_bodies.append(body)
	return receiver

func training_fixture() -> void:
	# Explicit isolated position/platform fixture above the real stage. Normal
	# Motor, tuning, collision sweeps, projectile resources and damage policy run.
	training_point = app.stage.spawn + Vector2(0,-420)
	var floor_body := StaticBody2D.new()
	floor_body.name = "FormalFixtureTrainingPlatform"
	floor_body.collision_layer = 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1000,20)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	floor_body.add_child(collision)
	app.stage.add_child(floor_body)
	var player_collision: CollisionShape2D = app.player.get_node("CollisionShape2D") as CollisionShape2D
	var feet_offset: float = player_collision.position.y + (player_collision.shape as RectangleShape2D).size.y * 0.5
	floor_body.global_position = training_point + Vector2(0,feet_offset+10.05)
	target_a = make_target("TargetA", training_point+Vector2(60,0))
	target_b = make_target("TargetB", training_point+Vector2(105,-38))
	await position_training()
	check(app.player.is_on_floor(), "SETUP platform supports the actual Motor without changing gravity or tuning")
	check(app._item_runtime.targets(training_point,130).size() == 2, "runtime shape query discovers both actual training hurtboxes")

func position_training() -> void:
	# Relocation is setup only; it does not count as traversal evidence.
	app.player.global_position = training_point
	app.controller.motor.reset_motion()
	await ticks(4)

func primary(label: String, multiplier: float) -> void:
	await position_training()
	for unused: int in 100:
		if app.controller.shoot_ability.cooldown_remaining <= 0 and app.controller.shoot_ability.rounds_remaining == 0 and app.controller.shot_energy.can_fire(): break
		await ticks(1)
	var health_before: float = target_a.health
	var energy_before: float = app.controller.combat_energy.current
	var shots_before: int = shot_count
	var commits_before: int = committed.size()
	var policy_before: int = policy_commits.size()
	var damage: float = app._item_runtime.base_damage()
	check(app.controller.router.request_action(&"shoot_release",Vector2.RIGHT), label + ": real InputRouter accepts the primary release")
	for unused: int in 45:
		await ticks(1)
		if target_a.health < health_before: break
	check(shot_count == shots_before+1, label + ": PlayerController/ShootAbility emit exactly one actual primary")
	check(is_equal_approx(health_before-target_a.health,damage*multiplier), label + ": swept projectile commits the expected actual HP damage")
	check(committed.size() == commits_before+1 and committed.back().target == target_a.actor_id, label + ": successful policy commit produces the actual controller receipt")
	check(policy_commits.size() > policy_before and policy_commits[policy_before].target == &"formal_fixture/TargetA" and not policy_commits[policy_before].derived, label + ": original FrameDamagePolicy commits the primary channel")
	var gained: float = app.controller.combat_energy.current-energy_before
	check(gained > 0 and gained <= 12, label + ": real successful packet grants resonance within the 12 cap")

func clear_training_bindings() -> void:
	# Release policy bridge Callables before freeing the stage, including their
	# captured receiver/HealthState. Keep no object references in observations.
	for body: Area2D in target_bodies:
		if is_instance_valid(body):
			var receiver := body.get_node("Damageable") as Damageable
			receiver.damage_sink = Callable()
			receiver.bind_health(null)
	target_bodies.clear()
	target_a = null
	target_b = null

func two_target_packet() -> void:
	ensure_owned(&"P08")
	await equip([&"P08"])
	# Explicit hurtbox-position fixture aligns two actual colliders in one sweep.
	(target_b.get_parent() as Node2D).global_position = training_point+Vector2(110,0)
	await position_training()
	for unused: int in 100:
		if app.controller.shoot_ability.cooldown_remaining <= 0 and app.controller.shoot_ability.rounds_remaining == 0: break
		await ticks(1)
	var first_hp: float = target_a.health
	var second_hp: float = target_b.health
	var energy: float = app.controller.combat_energy.current
	var shots: int = shot_count
	var receipts: int = committed.size()
	check(app.controller.router.request_action(&"shoot_release",Vector2.RIGHT), "two-target packet enters the real primary input route")
	for unused: int in 45:
		await ticks(1)
		if target_b.health < second_hp: break
	check(shot_count == shots+1 and committed.size() == receipts+2, "one real piercing projectile produces two successful target receipts")
	check(committed.size() >= receipts+2 and committed[receipts].packet == committed[receipts+1].packet, "both physical target hits retain the same actual primary packet identity")
	check(is_equal_approx(first_hp-target_a.health,app._item_runtime.base_damage()) and is_equal_approx(second_hp-target_b.health,app._item_runtime.base_damage()*.65), "real extra-pierce collision keeps the first damage and applies Lv1's .65D second hit")
	check(is_equal_approx(app.controller.combat_energy.current-energy,12), "two actual primary targets cap shared-packet resonance at 12 rather than granting 14")
	(target_b.get_parent() as Node2D).global_position = training_point+Vector2(105,-38)
	await ticks(2)

func cache_flow() -> bool:
	var chosen: Dictionary = {}
	for chest: Dictionary in app.stage.chests:
		if chest.reward_mode == "resources": continue
		var candidates: Array[ItemDefinition] = app._v5_cache_items(chest)
		if not candidates.is_empty() and candidates[0].stable_id != &"B03": chosen = chest; break
	check(not chosen.is_empty(), "formal seed offers a real non-B03 item cache for the independent damage fixture")
	if chosen.is_empty(): return false
	# Transaction-position fixture; production cache, token, UI and service stay.
	app.player.global_position = chosen.position
	app.controller.motor.reset_motion()
	app._region_interact()
	check(paused and app.reward_modal.opened, "formal region interact opens the actual cache reward modal")
	var offered: Array[StringName] = ids(app._region_offer.candidates)
	check(not offered.is_empty() and ItemCatalogV5.get_item(offered[0]) != null, "actual formal cache offers the new V5 stable ID")
	var cache_key := StringName(app._run_receipt_prefix + "/" + str(chosen.id))
	var manifest_before: Dictionary = app._item_v5_pool.manifest_for(cache_key)
	check(not manifest_before.is_empty() and int(manifest_before.catalog_version) == 5, "actual cache draw records the original V5 pool provenance")
	app.reward_modal.close()
	app._region_interact()
	check(ids(app._region_offer.candidates) == offered and app._item_v5_pool.manifest_for(cache_key) == manifest_before, "reopening the actual unclaimed cache neither redraws candidates nor advances RNG")
	var damage_before: float = app.controller.motor.tuning.projectile_damage
	check(app._commit_region_choice(offered[0]), "formal cache choice commits through DemoApp and original RewardService")
	check(app.build.inventory.instances().size() == 1 and app.build.item_ids().is_empty(), "cache item enters ownership without automatic equipment")
	check(app._item_runtime._effects.is_empty() and app.controller.motor.tuning.projectile_damage == damage_before, "un-equipped cache item does not become a live effect")
	check(not app.reward_modal.opened and not paused and bool(chosen.claimed), "cache completion closes the modal, records claim and resumes the world")
	check(not app._commit_region_choice(offered[0]) and app.build.inventory.instances().size() == 1, "late repeated cache selection cannot grant twice")
	return true

func shop_flow() -> void:
	# Original wallet income fixture, never represented as natural coin drops.
	check(app.wallet.grant(500,&"formal_fixture/shop_income"), "SETUP explicit shop income enters the original RunWallet ledger")
	ensure_owned(&"B30")
	check(app._item_runtime.patch_state(&"B30",{"broken":true},&"formal_fixture/broken"), "SETUP broken-item fixture uses persistent inventory state")
	var broken: StringName = app.build.inventory.instance_for_definition(&"B30").instance_id
	check(not app._v5_shop_presenter.repair_view_quote(broken).available, "closed shop context exposes no remote repair quote")
	app.player.global_position = app.stage.merchant_position
	app.controller.motor.reset_motion()
	app._open_region_shop()
	check(app._v5_shop_presenter.is_open() and app.shop_modal.opened and paused, "formal merchant position opens the real V5 presenter and paused catalog modal")
	var shop_id: StringName = app._v5_shop_presenter._shop_id
	var map_key: StringName = app._item_runtime.map_key()
	var snapshot: Dictionary = app.shop.catalog_shop_snapshot(shop_id,map_key)
	check(snapshot.offers.size() == 3, "actual formal merchant has three frozen catalog offers")
	if snapshot.offers.size() != 3:
		app._close_region_shop()
		return
	var unique: Dictionary = {}
	var prices_match: bool = true
	var cards_exist: bool = true
	for row: Dictionary in snapshot.offers:
		var offer: ShopOffer = app.shop.quote(StringName(row.offer_id))
		unique[offer.item.stable_id] = true
		prices_match = prices_match and offer.price == offer.item.shop_price and offer.stock == 1 and offer.item.catalog_version == 5
		cards_exist = cards_exist and catalog_node("CatalogCard_",StringName(row.offer_id)) is ItemCard
	check(unique.size() == 3 and prices_match, "three merchant goods use distinct V5 IDs, table prices and one fixed stock")
	check(cards_exist, "actual ItemShopModal.show_catalog builds all three formal item cards")
	check(app._v5_shop_presenter.repair_view_quote(broken).available, "broken owned instance obtains repair quote inside the real near-merchant context")
	# Goods were drawn before these explicit reward fixtures. Pick a currently
	# legal row instead of assuming the first draw was not acquired meanwhile.
	var first: Dictionary = {}
	for row: Dictionary in snapshot.offers:
		var candidate: ShopOffer = app.shop.quote(StringName(row.offer_id))
		if ItemV5Eligibility.offer_reason(candidate.item,app.build,true).is_empty():
			first = row
			break
	check(not first.is_empty(), "actual frozen merchant retains an eligible purchasable row after the reward fixtures")
	if first.is_empty():
		app._close_region_shop()
		return
	var offer: ShopOffer = app.shop.quote(StringName(first.offer_id))
	var bought_id: StringName = offer.item.stable_id
	var previous: RunItemInstance = app.build.inventory.instance_for_definition(bought_id)
	var level_before: int = previous.level if previous != null else 0
	var count_before: int = app.build.inventory.instances().size()
	var coins_before: int = app.wallet.balance
	var equipped_before: Array[StringName] = app.build.item_ids()
	var buy: Button = catalog_node("CatalogBuy_",StringName(first.offer_id)) as Button
	check(buy != null and not buy.disabled, "real catalog exposes the affordable purchase action")
	if buy != null: buy.pressed.emit()
	check(app.wallet.balance == coins_before-int(first.price), "real presenter purchase debits exactly the immutable table quote")
	var owned: RunItemInstance = app.build.inventory.instance_for_definition(bought_id)
	check(owned != null and owned.level == level_before+1 and app.build.inventory.instances().size() == count_before+(1 if previous == null else 0), "merchant transaction adds ownership or grows the same owned instance")
	check(app.build.item_ids() == equipped_before, "buying a formal catalog item does not automatically equip it")
	check(app.shop.quote(StringName(first.offer_id)).stock == 0, "original merchant stock is consumed exactly once")
	var after_purchase: int = app.wallet.balance
	if buy != null: buy.pressed.emit()
	check(app.wallet.balance == after_purchase and app.build.inventory.instance_for_definition(bought_id).level == level_before+1, "same-frame stale purchase button cannot buy or level twice")
	buy = null
	var reroll: Button = app.shop_modal.find_child("CatalogReroll",true,false) as Button
	check(reroll != null and int(app._v5_shop_presenter._reroll_view.price) == 8, "real merchant refresh quotes the centralized 8-coin candidate price")
	if reroll != null: reroll.pressed.emit()
	var refreshed: Dictionary = app.shop.catalog_shop_snapshot(shop_id,map_key)
	check(app.wallet.balance == after_purchase-8 and int(refreshed.roll) == int(snapshot.roll)+1, "one actual refresh charges 8 and advances the frozen shop generation")
	check(refreshed.offers.size() == 3, "refresh produces three legal replacement offers")
	var after_reroll: int = app.wallet.balance
	if reroll != null: reroll.pressed.emit()
	check(app.wallet.balance == after_reroll, "stale refresh button cannot charge a second transaction")
	reroll = null
	var closed_buy: Button = catalog_node("CatalogBuy_",StringName(refreshed.offers[0].offer_id)) as Button
	app._close_region_shop()
	if closed_buy != null: closed_buy.pressed.emit()
	check(not paused and not app.shop_modal.opened and app.wallet.balance == after_reroll, "closing the formal shop resumes gameplay and invalidates old purchase controls")
	closed_buy = null
	check(not app._v5_shop_presenter.repair_view_quote(broken).available, "closing the presenter removes its repair authorization")
	app._open_region_shop()
	check(app._v5_shop_presenter.is_open() and app.shop.catalog_shop_snapshot(shop_id,map_key) == refreshed, "reopening the same map merchant preserves draw, prices, stock and generation")
	app.player.global_position = app.stage.merchant_position+Vector2(200,0)
	check(not app._v5_shop_presenter.repair_view_quote(broken).available, "even an open presenter cannot expose repair after leaving merchant proximity")
	app._close_region_shop()
	check(not app._v5_shop_presenter.open(), "formal presenter rejects remote merchant opening")
	await frames(2)

func _exercise() -> void:
	check(app.start_plains("level-design-v2-baseline/08"), "formal DemoApp starts the real Plains run")
	check(await wait_stage(), "actual formal stage generation and binding complete")
	if not is_instance_valid(app.stage) or app._stage_pending: return
	check(app.connected_region and app.stage is PlainsRegionStage and app.director.region_map_index == 1, "actual consumer is formal Plains map one")
	check(app._item_runtime != null and app.controller.item_runtime == app._item_runtime and app._item_runtime.is_live(), "formal run owns and binds its one live ItemRuntime")
	check(app._item_v5_pool != null and app._v5_shop_presenter != null, "formal run installs the real reward pool and merchant presenter")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ItemCatalogV5.CONFIG_PATH))
	var authoring: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ItemCatalogV5.AUTHORING_PATH))
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/item_v5_authoring_baseline.json"))
	var catalog := ItemCatalogV5.all_items()
	var catalog_ids := ids(catalog)
	var original_present: bool = original.items.size() == 72
	for id: String in original.items:
		original_present = original_present and StringName(id) in catalog_ids
	check(original_present, "formal catalog exposes all 72 active table definitions")
	check(catalog.size() == data.items.size()+authoring.additions.size(), "formal catalog also exposes the declared additional definitions")
	var deleted_missing: bool = data.deleted_ids.size() == 21
	var eligible: Array[ItemDefinition] = app._item_v5_pool.eligible_items()
	var all_new: bool = true
	for item: ItemDefinition in eligible: all_new = all_new and item.catalog_version == 5 and String(item.stable_id) not in data.deleted_ids
	for id: String in data.deleted_ids: deleted_missing = deleted_missing and ItemCatalogV5.get_item(StringName(id)) == null and StringName(id) not in ids(eligible)
	check(deleted_missing and all_new, "all 21 deleted IDs and legacy definitions are excluded from the real new-run pool")
	check(&"B03" in ids(eligible) and &"B33" in ids(eligible), "actual pulse-gun run admits both passive and active starter-compatible goods")
	check(&"B22" not in ids(eligible) and &"B19" not in ids(eligible), "real new-run pool filters incompatible bomb and ungranted grapple prerequisites")
	if not await cache_flow(): return
	ensure_owned(&"B03")
	check(app.build.inventory.instance_for_definition(&"B03").level == 1, "known primary-damage fixture starts at actual owned Lv1")
	check(not app._item_runtime.has(&"B03"), "known RewardService grant remains inactive in the backpack")
	attach_observers()
	await training_fixture()
	await primary("unequipped baseline",1.0)
	var hp_before: float = app.controller.actor_resources.health.current
	var energy_before: float = app.controller.combat_energy.current
	await equip([&"B03"])
	check(app.controller.actor_resources.health.current == hp_before and app.controller.combat_energy.current == energy_before, "equipping through the real pause session grants neither HP nor resonance")
	await primary("B03 Lv1",1.12)
	var instance_before: StringName = app.build.inventory.instance_for_definition(&"B03").instance_id
	var load_before: int = int(app.build.equipment.snapshot().used)
	var count_before: int = app.build.inventory.instances().size()
	reward_fixture(&"B03","B03_growth")
	await frames(2)
	check(app.build.inventory.instance_for_definition(&"B03").instance_id == instance_before and app.build.inventory.instance_for_definition(&"B03").level == 2, "equipped duplicate reward grows Lv2 on the same actual instance")
	check(app.build.inventory.instances().size() == count_before and int(app.build.equipment.snapshot().used) == load_before, "equipped reward growth adds neither an instance nor gear load")
	check(is_equal_approx(float(app._item_runtime.effect(&"B03").primary_damage_multiplier),1.22), "formal changed signal refreshes ItemRuntime's equipped level parameters")
	await primary("B03 Lv2",1.22)
	await equip([])
	check(not app._item_runtime.has(&"B03"), "real unequip removes B03 from the runtime cache")
	await primary("B03 removed",1.0)
	ensure_owned(&"P29")
	await equip([&"P29"])
	var secondary_hp: float = target_b.health
	var resonance_before: float = app.controller.combat_energy.current
	await primary("P29 originating primary",1.0)
	await ticks(4)
	check(is_equal_approx(secondary_hp-target_b.health,app._item_runtime.base_damage()*.3), "actual P29 primary commit chains derived .30D into the second real target")
	check(is_equal_approx(app.controller.combat_energy.current-resonance_before,7), "P29 derived damage does not self-charge or add an extra target refund")
	check(policy_commits.any(func(row: Dictionary) -> bool: return bool(row.derived) and row.target == &"formal_fixture/TargetB"), "P29 derived hit is authenticated and committed by the real frame policy")
	await two_target_packet()
	ensure_owned(&"B33")
	await equip([&"B33"])
	await position_training()
	check(app.controller.combat_energy.current >= 30, "five real primary hit receipts naturally funded the 30-resonance item active")
	var active_hp: float = target_a.health
	var active_energy: float = app.controller.combat_energy.current
	var active_shots: int = shot_count
	var active_commits: int = committed.size()
	check(app._item_runtime.selected_active() == &"B33" and app.controller.router.item_skill_available, "equipped B33 populates the independent actual item-skill input slot")
	# Synthetic keyboard edges reach the installed formal KeyboardMouseAdapter.
	for pressed: bool in [true,false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_R
		event.keycode = KEY_R
		event.pressed = pressed
		root.push_input(event,true)
		await ticks(2)
	check(is_equal_approx(active_energy-app.controller.combat_energy.current,30), "R through the formal adapter/router debits exactly one item-skill cost")
	check(is_equal_approx(active_hp-target_a.health,app._item_runtime.base_damage()*1.1), "independent B33 active commits real 1.10D area HP damage")
	check(shot_count == active_shots and committed.size() == active_commits, "item input creates no accompanying primary projectile or primary receipt")
	check(int(app._item_runtime.state(&"B33").get("cast_sequence",0)) == 1, "accepted item active persists one cast receipt on its owned instance")
	var cooldown_energy: float = app.controller.combat_energy.current
	check(app.controller.router.request_action(&"item_skill",Vector2.RIGHT), "actual router accepts a fresh independent item action for cooldown rejection")
	await ticks(2)
	check(app.controller.combat_energy.current == cooldown_energy and int(app._item_runtime.state(&"B33").cast_sequence) == 1, "cooldown rejection is atomic and does not debit or duplicate the cast")
	await shop_flow()
	ensure_owned(&"B26")
	var capacity_energy: float = app.controller.combat_energy.current
	await equip([&"B03",&"B26",&"B33"])
	var vessel: RunItemInstance = app.build.inventory.instance_for_definition(&"B26")
	var expected_capacity: float = app.controller.combat_energy.definition.capacity + float(vessel.item.parameters_for_level(vessel.level).max_resonance_add)
	check(app.controller.combat_energy.capacity() == expected_capacity and app.controller.combat_energy.current == capacity_energy, "formal equipped B26 raises resonance capacity by its current owned table level without filling energy")
	vessel = null
	var inventory_before: Array[StringName] = app.build.inventory.item_ids()
	var equipped_before: Array[StringName] = app.build.equipment.equipped_ids()
	var gear_before: int = int(app.build.equipment.snapshot().capacity)
	var coins_before: int = app.wallet.balance
	var state_before: Dictionary = app._item_runtime.state(&"B33")
	var map_before: StringName = app._item_runtime.map_key()
	var old_stage: int = app.stage.get_instance_id()
	var token: DemoToken = app.lifetime.token()
	clear_training_bindings()
	# Completion is an explicit director eligibility fixture, NOT a boss kill.
	check(app.director.complete_stage(token), "SETUP completion fixture satisfies the real director's map-transition prerequisite")
	check(app.director.advance_region_map(token,&"formal_fixture/map2").accepted(), "real director transition enters map two in the same run")
	check(await wait_stage(), "actual map two generation, policy and item binding finish")
	check(app.director.region_map_index == 2 and app.stage.get_instance_id() != old_stage, "director transition replaces the actual formal stage instance")
	check(app._item_runtime.map_key() != map_before and app._item_runtime.world_root() == app.stage, "runtime rebinds a distinct map identity to the actual new stage")
	check(not app.lifetime.accepts(token), "old-map token is rejected after the real stage epoch transition")
	token = null
	check(app.build.inventory.item_ids() == inventory_before and app.build.equipment.equipped_ids() == equipped_before, "same-run map transition preserves actual owned and equipped instances")
	check(app.wallet.balance == coins_before and int(app.build.equipment.snapshot().capacity) == gear_before and app.controller.combat_energy.capacity() == expected_capacity, "same-run transition preserves wallet, gear capacity and equipped resonance cap")
	check(app._item_runtime.state(&"B33") == state_before, "same-run map transition preserves paid active cooldown and cast state")
	attach_observers()
	await training_fixture()
	# Queue cancellation uses the actual pause boundary, without a fake hit.
	var menu_shots: int = shot_count
	check(app.controller.router.request_action(&"shoot_release",Vector2.UP), "pre-menu primary intent is initially accepted by the actual router")
	app.toggle_pause()
	app.menu.close_panel()
	await ticks(3)
	check(not paused and shot_count == menu_shots and app.controller.shoot_ability.get_projectiles().is_empty(), "closing the real pause menu cannot misfire a pre-menu primary intent")
	await ticks(45)
	await position_training()
	check(app.controller.router.request_action(&"shoot_release",Vector2.UP), "environment-return fixture begins with a real primary shot")
	await ticks(1)
	check(not app.controller.shoot_ability.get_projectiles().is_empty(), "environment-return fixture has an actual old live projectile to cancel")
	var session_before: int = app.controller.session_id
	var health_before: float = app.controller.actor_resources.health.current
	app._submit_damage(&"formal_fixture/environment",DamageRequest.Kind.ENVIRONMENT,1,&"formal_fixture/environment_hit")
	app.policy.resolve_batch()
	check(app.controller.actor_resources.health.current == health_before-1 and app.controller.session_id > session_before, "real surviving environment policy damage invokes the formal segment return")
	check(app.controller.shoot_ability.get_projectiles().is_empty(), "formal surviving environment return cancels the previous actual projectile")
	check(app.build.inventory.item_ids() == inventory_before and app.build.equipment.equipped_ids() == equipped_before and app.wallet.balance == coins_before, "surviving environment return retains the actual run construction and wallet")
	check(app._item_runtime.state(&"B33") == state_before, "surviving environment return cannot reset owned item cooldown/cast state")
	await position_training()
	await ticks(45)
	clear_training_bindings()
	app._submit_damage(&"formal_fixture/death",DamageRequest.Kind.ENVIRONMENT,999,&"formal_fixture/fatal_hit")
	app.policy.resolve_batch()
	await frames(8)
	check(app.director.state == DemoRunDirector.State.HOME and not app.lifetime.active, "actual fatal policy result ends the run and returns the director Home")
	check(app.controller == null and app.stage == null and is_instance_valid(app.home_scene), "formal death cleanup removes the run world and creates the real Home")
	check(app.build.inventory.instances().is_empty() and app.build.item_ids().is_empty() and app.wallet.balance == 0, "formal death cleanup discards all run item ownership, equipment and coins")
	check(app._item_runtime._effects.is_empty() and app._item_runtime.world_root() == null, "formal death clears equipped effects and world entities from ItemRuntime")

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	if "--verify-failure-exit" in OS.get_cmdline_user_args():
		check(false,"intentional strict-exit counterexample")
		print("ITEM V5 FORMAL: %s assertions, %s failures" % [assertions,failures])
		quit(1)
		return
	app = DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	await frames(5)
	await _exercise()
	paused = false
	clear_training_bindings()
	check(await preload("res://tests/audio_teardown.gd").drain_world(app), "actual formal App audio backends drain before teardown")
	app.free()
	app = null
	await frames(3)
	print("ITEM V5 FORMAL: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)
