extends RefCounted

const BLUE := preload("res://resources/items/jump_blue.tres")
const PURPLE := preload("res://resources/items/shot_purple.tres")
const GOLD := preload("res://resources/items/power_gold.tres")

func claim(scope: DemoLifetime, offer: StringName, option: StringName, id: StringName) -> RewardClaimRequest:
	var request := RewardClaimRequest.new()
	request.token = scope.token()
	request.offer_id = offer
	request.option_id = option
	request.claim_id = id
	return request

func purchase(scope: DemoLifetime, id: StringName, transaction: StringName) -> ShopPurchaseRequest:
	var request := ShopPurchaseRequest.new()
	request.token = scope.token()
	request.offer_id = id
	request.transaction_id = transaction
	return request

func run(tree: SceneTree, check: Callable) -> void:
	var fixture := preload("res://tests/combat_tests.gd").new()
	fixture.tree = tree
	await fixture.fixture()
	var player := fixture.controller
	var build := BuildState.new()
	build.configure(player)
	var base_jumps := player.motor.tuning.max_jumps
	var base_shots := player.motor.tuning.max_air_shots
	var base_damage := player.motor.tuning.projectile_damage
	player.jump_ability.advance(0.01, false)
	player.action_resources.advance(false)
	var charges := player.action_resources.shot_charges
	check.call(BLUE.is_valid() and PURPLE.is_valid() and GOLD.is_valid(), "demo item resources load with valid typed modifiers")
	check.call(build.add_item(&"blue", BLUE), "add real jump modifier")
	check.call(player.motor.tuning.max_jumps == base_jumps + 1, "jump modifier reaches shared ability tuning")
	check.call(build.add_item(&"blue", BLUE) and player.motor.tuning.max_jumps == base_jumps + 1, "same source retry is idempotent")
	check.call(not build.add_item(&"blue", PURPLE), "same source changed definition is rejected")
	check.call(not build.can_add(BLUE), "duplicate reject policy prevents a second item")
	check.call(build.add_item(&"purple", PURPLE), "add shot capacity modifier")
	check.call(player.motor.tuning.max_air_shots == base_shots + 1 and player.action_resources.shot_charges == charges, "capacity increase does not grant airborne charges")
	check.call(build.remove_source(&"blue") and player.motor.tuning.max_jumps == base_jumps, "source removal recomputes jump base")
	check.call(build.remove_source(&"purple") and player.motor.tuning.max_air_shots == base_shots, "source removal recomputes shot base")
	var invalid: ItemDefinition = BLUE.duplicate(true)
	invalid.modifiers[0].value = NAN
	check.call(not build.add_item(&"bad", invalid) and build.item_ids().is_empty(), "invalid modifier cannot partially mutate build")
	var stack: ItemDefinition = BLUE.duplicate(true)
	stack.duplicate_policy = ItemDefinition.DuplicatePolicy.STACK
	stack.stack_limit = 2
	check.call(build.add_item(&"stack1", stack) and build.add_item(&"stack2", stack), "configured stacking permits two sources")
	check.call(not build.add_item(&"stack3", stack) and player.motor.tuning.max_jumps == base_jumps + 2, "stack cap cannot be exceeded")
	check.call(build.clear() and player.motor.tuning.max_jumps == base_jumps, "clear all modifiers restores base")
	var exclusive: ItemDefinition = BLUE.duplicate(true)
	exclusive.tags = [&"movement"]
	var conflicts: ItemDefinition = PURPLE.duplicate(true)
	conflicts.exclusive_tags = [&"movement"]
	build.add_item(&"exclusive", exclusive)
	check.call(not build.can_add(conflicts), "mutual exclusion is definition-driven")
	build.clear()
	var override_a: ItemDefinition = BLUE.duplicate(true)
	override_a.stable_id = &"override_a"
	override_a.modifiers[0].operation = BuildModifier.Operation.OVERRIDE
	override_a.modifiers[0].value = 4.0
	var override_z: ItemDefinition = override_a.duplicate(true)
	override_z.stable_id = &"override_z"
	override_z.modifiers[0].value = 3.0
	check.call(build.add_item(&"z", override_z) and build.add_item(&"a", override_a) and player.motor.tuning.max_jumps == 3, "equal priority override uses stable source order instead of insertion order")
	check.call(build.remove_source(&"z") and player.motor.tuning.max_jumps == 4, "removing winning override exposes previous source")
	build.clear()
	var high: ItemDefinition = BLUE.duplicate(true)
	high.stable_id = &"max_health_fixture"
	high.modifiers[0].stat_id = &"max_health"
	high.modifiers[0].value = 2.0
	var health := player.actor_resources.health
	health.apply_damage(ActorResourceRequest.new(&"hurt", health.epoch, 2.0, health.get_instance_id()))
	check.call(build.add_item(&"health", high) and health.capacity == 7.0 and health.current == 3.0, "maximum health item changes cap without healing")
	check.call(build.remove_source(&"health") and health.capacity == 5.0 and health.current == 3.0, "maximum health source is reversible")
	var maximum := MaxHealthEffect.new()
	check.call(maximum.apply(health, 2.0, &"max_effect").accepted(), "standalone maximum effect applies")
	check.call(maximum.apply(health, 2.0, &"max_effect").status == ActorResourceResult.Status.REPLAY and health.capacity == 7.0, "maximum effect retry does not increase twice")
	check.call(SupplyHealEffect.apply(health, 1.0, &"heal").accepted() and health.current == 4.0, "current health effect is independently applied")
	check.call(SupplyHealEffect.apply(health, 1.0, &"heal").status == ActorResourceResult.Status.REPLAY and health.current == 4.0, "supply repeat cannot heal twice")
	var scope := DemoLifetime.new()
	var rewards := RewardService.new()
	rewards.configure(scope, build)
	var events: Array = []
	rewards.claimed.connect(func(receipt: EconomyReceipt) -> void: events.append(receipt))
	var candidates: Array[ItemDefinition] = [BLUE, PURPLE]
	var offer := rewards.create_offer(&"choice", candidates, &"stage_reward")
	check.call(offer != null and offer.candidates.size() == 2, "reward offer retains two different typed candidates")
	offer.candidates.clear()
	check.call(rewards.get_offer(&"choice").candidates.size() == 2, "external offer copy cannot corrupt candidates")
	var choose := claim(scope, &"choice", &"jump_blue", &"choose_blue")
	var receipt := rewards.claim(choose)
	check.call(receipt.accepted() and build.count_item(&"jump_blue") == 1, "choice atomically applies selected item")
	receipt.item_id = &"tampered"
	check.call(rewards.claim(choose).status == EconomyReceipt.Status.REPLAY and events.size() == 1, "exact claim retry returns protected receipt without second event")
	check.call(not rewards.claim(claim(scope, &"choice", &"shot_purple", &"choose_other")).accepted(), "unselected item cannot also be claimed")
	choose.option_id = &"shot_purple"
	check.call(rewards.claim(choose).status == EconomyReceipt.Status.CONFLICT, "claim id with changed payload is rejected")
	check.call(rewards.create_gold_offer(&"badgold", BLUE, &"defeat_bad") == null, "guaranteed gold policy rejects non-gold item")
	var gold_offer := rewards.create_gold_offer(&"gold", GOLD, &"boss_defeat")
	check.call(gold_offer != null and gold_offer.gold and gold_offer.candidates.size() == 1, "boss offer contains exactly one gold item")
	var gold_request := claim(scope, &"gold", &"power_gold", &"gold_claim")
	check.call(rewards.claim(gold_request).accepted(), "valid boss gold grants item")
	check.call(rewards.claim(gold_request).status == EconomyReceipt.Status.REPLAY and build.count_item(&"power_gold") == 1, "boss gold is granted once")
	check.call(rewards.create_gold_offer(&"gold_duplicate", GOLD, &"boss_defeat") == null, "defeat source cannot create another reward group")
	var wallet := RunWallet.new()
	check.call(wallet.grant(10, &"coins") and wallet.grant(10, &"coins") and wallet.balance == 10, "run coin grant is deduplicated")
	check.call(not wallet.grant(11, &"coins") and wallet.balance == 10, "changed coin grant payload is rejected")
	var shop := ShopService.new()
	shop.configure(scope, build, wallet)
	check.call(shop.add_offer(&"ammo", PURPLE, 4, 1), "shop accepts typed valid run-coin inventory")
	check.call(not shop.add_offer(&"negative", PURPLE, -1, 1), "negative price cannot enter inventory")
	var quote := shop.quote(&"ammo")
	quote.stock = 100
	check.call(shop.quote(&"ammo").stock == 1, "quote is detached from real inventory")
	var buy := purchase(scope, &"ammo", &"buy")
	buy.quote_version = 2
	check.call(not shop.purchase(buy).accepted() and wallet.balance == 10 and shop.quote(&"ammo").stock == 1, "stale quote makes no partial changes")
	buy.quote_version = 1
	var old_token := scope.token()
	scope.invalidate_actor()
	buy.token = old_token
	check.call(shop.purchase(buy).status == EconomyReceipt.Status.STALE and wallet.balance == 10, "respawn invalidates pending transaction")
	buy.token = scope.token()
	check.call(shop.purchase(buy).accepted() and wallet.balance == 6 and shop.quote(&"ammo").stock == 0 and build.count_item(&"shot_purple") == 1, "purchase atomically debits coins and stock and applies build")
	check.call(shop.purchase(buy).status == EconomyReceipt.Status.REPLAY and wallet.balance == 6, "purchase replay cannot debit twice")
	check.call(not shop.purchase(purchase(scope, &"ammo", &"buy_again")).accepted() and wallet.balance == 6, "last stock cannot be purchased twice")
	buy.quantity = 2
	check.call(shop.purchase(buy).status == EconomyReceipt.Status.CONFLICT, "changed transaction payload is rejected")
	var costly: ItemDefinition = BLUE.duplicate(true)
	costly.stable_id = &"costly"
	shop.add_offer(&"costly", costly, 99, 1)
	check.call(shop.purchase(purchase(scope, &"costly", &"poor")).status == EconomyReceipt.Status.INSUFFICIENT and wallet.balance == 6 and shop.quote(&"costly").stock == 1 and build.count_item(&"costly") == 0, "insufficient funds leaves wallet stock and build unchanged")
	var future_request := purchase(scope, &"costly", &"old_stage")
	scope.stage_epoch += 1
	future_request.token = scope.token()
	check.call(not shop.purchase(future_request).accepted() and shop.quote(&"costly").stock == 1, "current token cannot purchase inventory from a previous stage")
	scope.end()
	buy.quantity = 1
	check.call(shop.purchase(buy).status == EconomyReceipt.Status.REPLAY, "committed transaction remains readable after run end")
	check.call(not shop.purchase(purchase(scope, &"ammo", &"after_death")).accepted(), "run end cancels uncommitted purchase")
	check.call(build.item_ids().size() == 3 and wallet.balance == 6, "segment lifetime changes preserve claimed items and run wallet")
	check.call(build.add_item(&"fatal_health_modifier", high) and health.capacity == 7.0, "terminal clear regression starts with an actual max health source")
	var terminal_capacity := health.capacity
	health.apply_damage(ActorResourceRequest.new(&"fatal", health.epoch, 99.0, health.get_instance_id()))
	check.call(not SupplyHealEffect.apply(health, 1.0, &"revive").accepted(), "healing cannot resurrect terminal actor")
	check.call(not maximum.apply(health, 1.0, &"revive_max").accepted(), "maximum health effect cannot resurrect terminal actor")
	check.call(build.clear() and build.item_ids().is_empty() and health.terminal and health.current == 0.0 and health.capacity == terminal_capacity, "run end removes max health build source without mutating or reviving terminal health")
	check.call(player.motor.tuning.max_jumps == base_jumps and player.motor.tuning.max_air_shots == base_shots and player.motor.tuning.projectile_damage == base_damage, "terminal clear restores base jump shot and damage tuning")
	fixture.world.free()
