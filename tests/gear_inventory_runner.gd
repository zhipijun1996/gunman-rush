extends SceneTree
## Actual Player/Build/Reward/Shop consumers. GUI input has a separate formal App case.
const SUPPORT := preload("res://tests/gear_inventory_support.gd")
var assertions := 0
var failures := 0
var fixture: Variant
var build: BuildState
var lifetime: DemoLifetime
var actor: PlayerController

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func fresh() -> void:
	paused = false
	if build != null:
		build.clear()
	if fixture != null and is_instance_valid(fixture.world):
		fixture.world.free()
	fixture = preload("res://tests/combat_tests.gd").new()
	fixture.tree = self
	await fixture.fixture(Vector2(80, 20))
	actor = fixture.controller
	lifetime = DemoLifetime.new()
	build = BuildState.new()
	build.configure(actor, lifetime)

func item(id: StringName, cost: int, rarity := ItemDefinition.Rarity.BLUE, stat: StringName = &"projectile_damage", amount := 1.0) -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.stable_id = id
	definition.display_name = String(id)
	definition.gear_cost = cost
	definition.rarity = rarity
	var modifier := BuildModifier.new()
	modifier.stat_id = stat
	modifier.operation = BuildModifier.Operation.ADD
	modifier.value = amount
	definition.modifiers = [modifier]
	return definition

func ids(sources: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for source: StringName in sources:
		var instance: RunItemInstance = build.inventory.instance_for_source(source)
		if instance != null:
			result.append(instance.instance_id)
	return result

func submit(loadout: Array[StringName]) -> Dictionary:
	var was_paused := paused
	paused = true
	var token := lifetime.token()
	var session := build.equipment.open_session(token)
	var result := build.equipment.submit(loadout, token, session, int(build.equipment.snapshot().revision))
	build.equipment.close_session()
	paused = was_paused
	return result

func upgrade_request(shop: ShopService, transaction: StringName) -> ShopPurchaseRequest:
	var request := ShopPurchaseRequest.new()
	request.token = lifetime.token()
	request.offer_id = &"gear_capacity"
	request.transaction_id = transaction
	request.quote_version = int(shop.gear_quote().quote_version)
	request.equipment_session = build.equipment.open_session(request.token)
	request.equipment_revision = int(build.equipment.snapshot().revision)
	return request

func capacity_and_rewards() -> void:
	await fresh()
	var base := actor.motor.tuning.projectile_damage
	var blue := item(&"blue_heavy", 5, ItemDefinition.Rarity.BLUE)
	var purple := item(&"purple_three", 3, ItemDefinition.Rarity.PURPLE)
	var gold := item(&"gold_light", 1, ItemDefinition.Rarity.GOLD)
	check(blue.is_valid() and gold.is_valid(), "blue five-slot and gold one-slot definitions are both legal")
	check(build.add_item(&"blue", blue) and build.add_item(&"purple", purple) and build.add_item(&"gold", gold), "nine load in ownership has no gear capacity limit")
	check(actor.motor.tuning.projectile_damage == base and build.item_ids().is_empty(), "ownership alone supplies neither modifiers nor capability item sources")
	check(submit(ids([&"blue", &"purple"])).accepted and build.equipment.snapshot().used == 8, "exactly eight gear commits")
	var before := build.equipment.snapshot()
	var rejected := submit(ids([&"blue", &"purple", &"gold"]))
	check(not rejected.accepted and not String(rejected.reason).is_empty() and build.equipment.snapshot().equipped_ids == before.equipped_ids and actor.motor.tuning.projectile_damage == base + 2, "nine gear fails atomically with a visible reason")
	var reward := item(&"overloaded_reward", 5, ItemDefinition.Rarity.GOLD)
	var rewards := RewardService.new()
	rewards.configure(lifetime, build)
	check(rewards.create_gold_offer(&"full_gear_reward", reward, &"boss_defeat") != null, "full equipped load still permits a legal guaranteed reward offer")
	var claim := RewardClaimRequest.new()
	claim.token = lifetime.token()
	claim.offer_id = &"full_gear_reward"
	claim.option_id = reward.stable_id
	claim.claim_id = &"claim_full"
	check(rewards.claim(claim).accepted() and build.count_item(reward.stable_id) == 1 and build.equipment.snapshot().used == 8 and actor.motor.tuning.projectile_damage == base + 2, "overloaded backpack reward is received without auto-equipping")
	check(rewards.claim(claim).status == EconomyReceipt.Status.REPLAY and build.inventory.instances().size() == 4, "same reward claim cannot mint another instance")
	for iteration: int in 12:
		check(submit([]).accepted and actor.motor.tuning.projectile_damage == base, "unequip removes every effect iteration %s" % iteration)
		check(submit(ids([&"blue"])).accepted and actor.motor.tuning.projectile_damage == base + 1, "re-equip recomputes from sole base iteration %s" % iteration)
	var owned: RunItemInstance = build.inventory.instance_for_source(&"blue")
	var original_id := owned.instance_id
	owned.item.modifiers[0].value = 999
	owned.source_id = &"tampered"
	blue.gear_cost = 1
	check(build.inventory.instance_for_source(&"blue").instance_id == original_id and build.inventory.instance_for_source(&"blue").item.gear_cost == 5 and actor.motor.tuning.projectile_damage == base + 1, "caller copies cannot mutate owned provenance, cost or live effects")

func component_only_effects() -> void:
	await fresh()
	var base := actor.motor.tuning.projectile_damage
	var definition := ItemDefinition.new()
	definition.stable_id = &"component_only"
	definition.display_name = "Component-only passive"
	definition.gear_cost = 2
	var component := ItemEffectComponent.new()
	component.effect_id = &"barrel_bonus"
	component.channel = ItemEffectComponent.Channel.PASSIVE
	var modifier := BuildModifier.new()
	modifier.stat_id = &"projectile_damage"
	modifier.operation = BuildModifier.Operation.ADD
	modifier.value = 2.5
	component.modifiers = [modifier]
	definition.effect_components = [component]
	check(definition.modifiers.is_empty() and definition.is_valid() and build.add_item(&"component", definition), "a component-only definition enters the ordinary inventory path")
	check(actor.motor.tuning.projectile_damage == base and build.effect_sources().is_empty(), "unequipped component-only ownership supplies no effect or effect source")
	check(submit(ids([&"component"])).accepted and actor.motor.tuning.projectile_damage == base + 2.5, "ordinary equipment commit applies the component-only numerical effect")
	var instance: RunItemInstance = build.inventory.instance_for_source(&"component")
	var sources := build.effect_sources()
	check(sources.size() == 1 and sources[0].source_id == StringName("%s/barrel_bonus" % instance.instance_id) and sources[0].instance_id == instance.instance_id and sources[0].definition_id == definition.stable_id and sources[0].definition_version == definition.definition_version and sources[0].effect_id == component.effect_id and sources[0].channel == ItemEffectComponent.Channel.PASSIVE, "component source preserves unique instance, definition version, effect ID and channel")
	var text := ItemPresentation.effects(instance.item)
	check(text.contains("Damage") and text.contains("+2.5"), "actual card effect formatter displays the component-only stat and numerical bonus")
	check(submit([]).accepted and actor.motor.tuning.projectile_damage == base and build.effect_sources().is_empty(), "unloading a component-only item revokes both its effect and source")

func duplicates_and_requirements() -> void:
	await fresh()
	var stack := item(&"stacked", 2)
	stack.duplicate_policy = ItemDefinition.DuplicatePolicy.STACK
	stack.stack_limit = 3
	stack.equip_limit = 2
	check(build.add_item(&"s1", stack) and build.add_item(&"s2", stack) and build.add_item(&"s3", stack), "same definition permits distinct source instances up to configured ownership limit")
	var loadout := ids([&"s1", &"s2", &"s3"])
	check(loadout.size() == 3 and loadout[0] != loadout[1] and loadout[1] != loadout[2], "duplicate definitions retain unique stable instance IDs")
	check(not build.add_item(&"s4", stack) and build.inventory.instances().size() == 3, "ownership stack cap rejects without adding a partial instance")
	check(not submit([loadout[0], loadout[0]]).accepted and build.item_ids().is_empty(), "same instance cannot occupy two loadout entries")
	check(submit([loadout[0], loadout[1]]).accepted, "two distinct legal stacks equip")
	check(not submit(loadout).accepted and build.equipment.snapshot().equipped_ids.size() == 2, "equipment stack limit is independent from the holding limit")
	build.clear()
	var first := item(&"exclusive_a", 1)
	first.tags = [&"engine"]
	var second := item(&"exclusive_b", 1)
	second.exclusive_tags = [&"engine"]
	check(build.add_item(&"first", first) and build.add_item(&"second", second), "mutually exclusive gear may coexist in the backpack")
	check(submit(ids([&"first"])).accepted and not submit(ids([&"first", &"second"])).accepted, "mutual exclusion is checked against the complete proposed loadout")
	check(submit(ids([&"second"])).accepted and build.item_ids() == [&"exclusive_b"], "atomic replacement removes conflicting prior source and commits the new source")
	var dependent := item(&"requires_engine", 1)
	dependent.required_tags = [&"engine"]
	check(build.add_item(&"dependent", dependent) and not submit(ids([&"dependent"])).accepted, "missing equipped prerequisite rejects the whole proposal")
	check(submit(ids([&"first", &"dependent"])).accepted, "complete proposed loadout satisfies equipped tag prerequisites")
	check(not submit(ids([&"dependent"])).accepted and build.item_ids().size() == 2, "removing a prerequisite cannot leave a partial invalid loadout")
	var weapon := item(&"requires_weapon", 1)
	weapon.required_weapon_id = &"not_the_current_weapon"
	check(build.add_item(&"wrong_weapon", weapon) and not submit(ids([&"wrong_weapon"])).accepted, "weapon prerequisite validates the actual current weapon")
	var grapple := item(&"requires_grapple", 1)
	grapple.required_capabilities = [&"grapple"]
	check(build.add_item(&"grapple", grapple) and not submit(ids([&"grapple"])).accepted, "item cannot grant its own unearned core prerequisite")
	check(actor.traversal.grant(&"grapple") and submit(ids([&"grapple"])).accepted and actor.traversal.hook_enabled, "separate earned core capability satisfies an equipment prerequisite")
	check(submit([]).accepted and actor.traversal.hook_enabled, "removing random equipment preserves the independent region core ability")

func reentrant_commit_snapshot() -> void:
	await fresh()
	var health := actor.actor_resources.health
	var maximum := health.capacity
	var current := health.current
	check(build.add_item(&"atomic_hp", item(&"atomic_hp", 2, ItemDefinition.Rarity.PURPLE, &"max_health", 2)), "atomic observer fixture owns a real maximum-health instance")
	var requested := ids([&"atomic_hp"])
	var expected: Array[StringName] = requested.duplicate()
	var callback_results: Array[bool] = []
	var callback: Callable = func(_result: ActorResourceResult) -> void:
		requested.clear()
		callback_results.append(build.clear())
	health.changed.connect(callback)
	var receipt := submit(requested)
	health.changed.disconnect(callback)
	check(requested.is_empty() and callback_results == [false], "synchronous health observer mutates caller proposal but cannot reenter run cleanup")
	var state := build.equipment.snapshot()
	var sources := build.effect_sources()
	check(receipt.accepted and state.equipped_ids == expected and state.used == 2 and state.remaining == 6 and build.inventory.instances().size() == 1 and build.item_ids() == [&"atomic_hp"] and sources.size() == 1 and sources[0].instance_id == expected[0] and health.capacity == maximum + 2 and health.current == current, "commit uses one private proposal for inventory, loadout, gear and applied effects despite synchronous callbacks")
	check(submit([]).accepted and health.capacity == maximum and health.current == current and build.effect_sources().is_empty() and build.inventory.instances().size() == 1, "observer-safe commit remains reversible without discarding ownership or healing")

func health_and_airborne() -> void:
	await fresh()
	var health := actor.actor_resources.health
	var maximum := health.capacity
	health.apply_damage(ActorResourceRequest.new(&"hurt", health.epoch, 2, health.get_instance_id()))
	var current := health.current
	check(build.add_item(&"hp", item(&"maximum_health", 2, ItemDefinition.Rarity.PURPLE, &"max_health", 3)) and submit(ids([&"hp"])).accepted and health.capacity == maximum + 3 and health.current == current, "equipping maximum health changes only capacity")
	check(SupplyHealEffect.apply(health, 99, &"explicit_supply").accepted() and health.current == maximum + 3, "only an explicit supply fills the larger health capacity")
	check(submit([]).accepted and health.capacity == maximum and health.current == maximum, "unequip clamps current HP to the reduced maximum")
	check(submit(ids([&"hp"])).accepted and health.current == maximum, "re-equipping maximum HP never heals the clamp away")
	build.clear()
	var jump_base := actor.motor.tuning.max_jumps
	var shot_base := actor.motor.tuning.max_air_shots
	check(build.add_item(&"jump", item(&"air_jump", 2, ItemDefinition.Rarity.BLUE, &"max_jumps", 2)) and build.add_item(&"shots", item(&"air_shots", 2, ItemDefinition.Rarity.PURPLE, &"max_air_shots", 2)) and submit(ids([&"jump", &"shots"])).accepted, "airborne test starts with real equipped capacity modifiers")
	# Explicit pre-flight boundary; all subsequent equipment edits happen without a physics tick.
	actor.jump_ability.advance(0.01, true)
	actor.action_resources.advance(true)
	actor.action_resources.reset()
	actor.jump_ability.advance(1.0, false)
	while actor.action_resources.try_consume_shot(false):
		pass
	var used_jumps := actor.jump_ability.used_jumps
	actor.motor.normal_velocity = Vector2(30, -80)
	actor.motor.recoil_velocity = Vector2(-50, 20)
	var normal := actor.motor.normal_velocity
	var recoil := actor.motor.recoil_velocity
	paused = true
	check(submit([]).accepted and submit(ids([&"jump", &"shots"])).accepted, "paused unload/reload completes without a physics-frame workaround")
	check(actor.action_resources.shot_charges == 0 and actor.action_resources._flight_cap == shot_base and actor.jump_ability._air_max == jump_base and actor.jump_ability.used_jumps == used_jumps, "same-flight caps remember the lowest capacity and never restore spent jumps or ammo")
	check(actor.motor.normal_velocity == normal and actor.motor.recoil_velocity == recoil, "equipment edits leave in-flight movement and recoil untouched")
	actor.jump_ability.request_jump()
	check(not actor.jump_ability.try_jump(actor.motor), "paused remove/re-equip cannot create a free extra jump")
	check(actor.action_resources.grant_shot(99) == shot_base and actor.action_resources.shot_charges == shot_base, "later hit refill obeys the reduced flight cap after re-equipping")
	paused = false
	build.clear()
	check(actor.traversal.grant(&"double_jump"), "core double-jump source can be earned independently")
	actor.jump_ability.advance(0.01, true)
	actor.jump_ability.advance(1.0, false)
	check(build.add_item(&"jump", item(&"core_floor_jump", 1, ItemDefinition.Rarity.BLUE, &"max_jumps", 2)) and submit(ids([&"jump"])).accepted and submit([]).accepted and actor.jump_ability._air_max == 2 and actor.jump_ability.capacity_floor == 2, "equipment clamp preserves independently earned core jump floor")

func transactions_and_lifetime() -> void:
	await fresh()
	paused = true
	var wallet := RunWallet.new()
	var shop := ShopService.new()
	shop.configure(lifetime, build, wallet)
	var quote := shop.gear_quote()
	var insufficient := upgrade_request(shop, &"poor")
	check(shop.purchase_gear_upgrade(insufficient).status == EconomyReceipt.Status.INSUFFICIENT and wallet.balance == 0 and build.equipment.snapshot().capacity == 8, "insufficient gear upgrade leaves capacity and wallet unchanged")
	check(wallet.grant(10000, &"debug_economy"), "gear transaction fixture funds only the run wallet")
	var before := wallet.balance
	var buy := upgrade_request(shop, &"upgrade_1")
	check(shop.purchase_gear_upgrade(buy).accepted() and wallet.balance == before - int(quote.price) and build.equipment.snapshot().capacity == 10, "first configured purchase atomically raises eight gear to ten")
	var paid := wallet.balance
	check(shop.purchase_gear_upgrade(buy).status == EconomyReceipt.Status.REPLAY and wallet.balance == paid and build.equipment.snapshot().capacity == 10, "gear transaction replay cannot charge or expand twice")
	buy.quantity = 2
	check(shop.purchase_gear_upgrade(buy).status == EconomyReceipt.Status.CONFLICT and wallet.balance == paid, "gear transaction ID with changed payload is rejected")
	buy.quantity = 1
	var stale := upgrade_request(shop, &"stale_upgrade")
	build.equipment.close_session()
	check(not shop.purchase_gear_upgrade(stale).accepted() and wallet.balance == paid and build.equipment.snapshot().capacity == 10, "expired gear editing session cannot buy capacity")
	for level: int in [2, 3]:
		var request := upgrade_request(shop, StringName("upgrade_%s" % level))
		check(shop.purchase_gear_upgrade(request).accepted() and build.equipment.snapshot().capacity == 8 + level * 2, "configured gear expansion level %s commits" % level)
	check(not shop.gear_quote().available and not shop.purchase_gear_upgrade(upgrade_request(shop, &"over_max")).accepted() and build.equipment.snapshot().capacity == 14, "maximum fourteen capacity cannot be expanded again")
	var limited := item(&"last_owned", 5)
	check(build.add_item(&"already_owned", limited) and shop.add_offer(&"limited", limited, 7, 1), "shop holding-limit rollback fixture has a legal quote")
	var purchase := ShopPurchaseRequest.new()
	purchase.token = lifetime.token()
	purchase.offer_id = &"limited"
	purchase.transaction_id = &"holding_cap_failure"
	purchase.quote_version = shop.quote(&"limited").quote_version
	var coins := wallet.balance
	check(not shop.purchase(purchase).accepted() and wallet.balance == coins and shop.quote(&"limited").stock == 1 and build.count_item(limited.stable_id) == 1, "holding-limit failure rolls back wallet, stock and inventory together")
	check(submit(ids([&"already_owned"])).accepted, "lifetime fixture has an equipped instance")
	var saved := build.equipment.snapshot()
	var saved_instance: RunItemInstance = build.inventory.instances()[0]
	var token := lifetime.token()
	var session := build.equipment.open_session(token)
	lifetime.invalidate_actor()
	check(not build.equipment.submit([], token, session, int(saved.revision)).accepted and build.equipment.snapshot().equipped_ids == saved.equipped_ids and build.inventory.instances()[0].instance_id == saved_instance.instance_id and wallet.balance == coins, "living environment return invalidates pending edit while retaining owned IDs, loadout, capacity and wallet")
	lifetime.stage_epoch += 1
	check(build.equipment.snapshot().capacity == 14 and build.equipment.snapshot().equipped_ids == saved.equipped_ids and build.inventory.instances()[0].instance_id == saved_instance.instance_id, "cross-map stage epoch retains this run inventory, equipment and expansion")
	token = lifetime.token()
	session = build.equipment.open_session(token)
	var revision := int(build.equipment.snapshot().revision)
	var unpaused_upgrade := upgrade_request(shop, &"unpaused_upgrade")
	# Keep exactly the same token/session/revision across the unpause boundary.
	session = unpaused_upgrade.equipment_session
	paused = false
	check(not build.equipment.submit([], token, session, revision).accepted and build.equipment.snapshot().equipped_ids == saved.equipped_ids, "unpaused gameplay rejects an otherwise current editing command")
	paused = true
	# No close_session/open_session intervenes: unpaused validation itself must revoke it.
	check(not build.equipment.submit([], token, session, revision).accepted, "re-pausing never revives the session invalidated while gameplay ran")
	paused = false
	check(shop.purchase_gear_upgrade(unpaused_upgrade).status == EconomyReceipt.Status.STALE and wallet.balance == coins, "unpaused gameplay rejects a pending gear purchase without charging")
	check(build.equipment.open_session(token) == 0, "a new editing session cannot begin during unpaused gameplay")
	paused = true
	session = build.equipment.open_session(token)
	actor.router.clear("application_focus_out")
	actor.router.has_application_focus = false
	check(not build.equipment.submit([], token, session, revision).accepted and build.equipment.snapshot().equipped_ids == saved.equipped_ids, "focus loss invalidates the previously opened equipment session")
	actor.router.has_application_focus = true
	actor.router.clear("application_focus_in")
	check(not build.equipment.submit([], token, session, revision).accepted, "focus restoration does not revive a stale editing command")
	session = build.equipment.open_session(token)
	check(build.equipment.submit([], token, session, revision).accepted, "a newly opened focused session can submit normally")
	session = build.equipment.open_session(token)
	var health := actor.actor_resources.health
	health.apply_damage(ActorResourceRequest.new(&"terminal", health.epoch, 999, health.get_instance_id()))
	check(not build.equipment.submit(ids([&"already_owned"]), token, session, int(build.equipment.snapshot().revision)).accepted and health.current == 0, "terminal health defeats an uncommitted equipment command")
	lifetime.end()
	check(build.clear() and build.inventory.instances().is_empty() and build.item_ids().is_empty() and build.equipment.snapshot().capacity == 8 and health.terminal and health.current == 0, "real run cleanup discards inventory and upgrades without reviving the dead actor")
	check(shop.purchase_gear_upgrade(buy).status == EconomyReceipt.Status.REPLAY, "ended-run upgrade receipt remains readable without applying another mutation")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	if "--verify-failure-exit" in OS.get_cmdline_user_args():
		check(false, "intentional failure propagation")
		quit(1)
		return
	await capacity_and_rewards()
	await component_only_effects()
	await duplicates_and_requirements()
	await reentrant_commit_snapshot()
	await health_and_airborne()
	await transactions_and_lifetime()
	paused = false
	if build != null:
		build.clear()
	build = null
	actor = null
	if fixture != null and is_instance_valid(fixture.world):
		fixture.world.free()
	fixture = null
	await process_frame
	print("GEAR INVENTORY: %s assertions, %s failures" % [assertions, failures])
	quit(1 if failures else 0)
