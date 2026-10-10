extends RefCounted

const COINS := preload("res://resources/rewards/demo_coins.tres")
const HEAL := preload("res://resources/rewards/demo_heal.tres")

func ids(items: Array[ItemDefinition]) -> Array[StringName]:
	var result: Array[StringName] = []
	for item: ItemDefinition in items:
		result.append(item.stable_id)
	return result

func run(tree: SceneTree, check: Callable) -> void:
	var fixture := preload("res://tests/combat_tests.gd").new()
	fixture.tree = tree
	await fixture.fixture()
	var player := fixture.controller
	var build := BuildState.new()
	build.configure(player)
	var catalog := DemoRewardCatalog.new()
	catalog.configure(build)
	check.call(COINS.is_valid() and HEAL.is_valid(), "coin and current-health resource definitions load")
	var invalid: SimpleRewardDefinition = COINS.duplicate(true)
	invalid.amount = 0.5
	check.call(not invalid.is_valid(), "run coins reject fractional reward amounts")
	invalid.amount = NAN
	check.call(not invalid.is_valid(), "simple reward rejects nonfinite amounts")
	var rarity_found := false
	for property: Dictionary in COINS.get_property_list():
		rarity_found = rarity_found or property.name == "rarity"
	check.call(not rarity_found, "coin reward definition has no item rarity")
	var plains_catalog := DemoRewardCatalog.new()
	plains_catalog.configure(build, &"plains")
	for sample: int in 64:
		var plains_choices := plains_catalog.choose_candidates(str(sample), "plains_stage_2")
		check.call(plains_choices.size() == 2 and not (&"jump_blue" in ids(plains_choices)), "plains rewards cannot regrant locked second jump")
	var initial := catalog.choose_candidates("repro_seed", "stage_2")
	check.call(initial.size() == 2 and initial[0].stable_id != initial[1].stable_id, "catalog produces two distinct legal definitions")
	check.call(ids(initial) == ids(catalog.choose_candidates("repro_seed", "stage_2")), "same seed stage and catalog version reproduce candidate IDs")
	var map_stream := RunRandomStream.new("repro_seed", "map", "stage_2")
	var expected_map := RunRandomStream.new("repro_seed", "map", "stage_2")
	var map_value := map_stream.next_int(1000000)
	for unused: int in 17:
		catalog.choose_candidates("repro_seed", "stage_2")
	check.call(map_value == expected_map.next_int(1000000) and map_stream.next_int(1000000) == expected_map.next_int(1000000), "reward sampling does not consume map stream")
	check.call(ids(initial) == ids(catalog.choose_candidates("repro_seed", "stage_2")), "unrelated map draws do not alter reward candidates")
	var reverse_pool: Array[ItemDefinition] = []
	for item: ItemDefinition in DemoRewardCatalog.DEFAULT_ITEMS:
		reverse_pool.push_front(item)
	check.call(catalog.set_pool(reverse_pool) and ids(initial) == ids(catalog.choose_candidates("repro_seed", "stage_2")), "pool ordering is normalized by stable definition ID")
	initial[0].stable_id = &"tamper"
	check.call(not (&"tamper" in ids(catalog.choose_candidates("repro_seed", "stage_2"))), "returned definitions cannot mutate catalog pool")
	for seed_index: int in 16:
		build.clear()
		catalog.configure(build)
		var health_before := player.actor_resources.health.current
		var chain_valid := true
		for stage: int in 9:
			var choices := catalog.choose_candidates(str(seed_index), "item_stage_%d" % stage)
			chain_valid = chain_valid and choices.size() == 2
			if choices.size() != 2:
				break
			chain_valid = chain_valid and build.add_item(StringName("item_room_%d" % stage), choices[stage % 2])
		check.call(chain_valid and build.item_ids().size() == 9, "nine consecutive item rooms retain two legal choices seed %d" % seed_index)
		check.call(player.actor_resources.health.current == health_before, "max-health pool items never implicitly heal seed %d" % seed_index)
	build.clear()
	var single: Array[ItemDefinition] = [preload("res://resources/items/jump_blue.tres")]
	check.call(catalog.set_pool(single) and catalog.choose_candidates("0", "room").is_empty() and catalog.last_error == &"insufficient_legal_candidates", "insufficient pool reports empty instead of duplicating a candidate")
	catalog.configure(build)
	var duplicate: Array[ItemDefinition] = [DemoRewardCatalog.DEFAULT_ITEMS[0], DemoRewardCatalog.DEFAULT_ITEMS[0]]
	check.call(not catalog.set_pool(duplicate), "duplicate stable IDs cannot enter pool")
	var zero_a: ItemDefinition = DemoRewardCatalog.DEFAULT_ITEMS[0].duplicate(true)
	var zero_b: ItemDefinition = DemoRewardCatalog.DEFAULT_ITEMS[1].duplicate(true)
	zero_a.appearance_weight = 0.0
	zero_b.appearance_weight = 0.0
	var zero_items: Array[ItemDefinition] = [zero_a, zero_b]
	catalog.set_pool(zero_items)
	check.call(catalog.choose_candidates("0", "room").is_empty(), "zero total appearance weight is not silently sampled")
	var lifetime := DemoLifetime.new()
	var wallet := RunWallet.new()
	var health := player.actor_resources.health
	var coins := SimpleRoomReward.new()
	check.call(coins.configure(COINS, lifetime, health, wallet), "coin room binds stage lifetime and separate run wallet")
	check.call(not coins.configure(COINS, lifetime, health, wallet), "reconfiguration cannot erase claim ledger")
	var coin_events: Array = []
	coins.committed.connect(func(result: SimpleRewardResult) -> void: coin_events.append(result))
	var old := lifetime.token()
	lifetime.invalidate_actor()
	check.call(coins.claim(old, &"stale_coin").status == SimpleRewardResult.Status.STALE and wallet.balance == 0, "environment return invalidates pending coin claim")
	var token := lifetime.token()
	var coin_receipt := coins.claim(token, &"coin_claim")
	check.call(coin_receipt.accepted() and coins.claimed and wallet.balance == 10 and coin_events.size() == 1, "new actor token claims preserved room reward once")
	coin_receipt.coins = 999
	check.call(coins.claim(token, &"coin_claim").status == SimpleRewardResult.Status.REPLAY and coins.claim(token, &"coin_claim").coins == 10 and wallet.balance == 10 and coin_events.size() == 1, "coin claim retry returns protected receipt without granting or emitting")
	check.call(not coins.claim(token, &"different_coin_claim").accepted() and wallet.balance == 10, "claimed coin source cannot be collected through a new event ID")
	lifetime.invalidate_actor()
	check.call(coins.claim(lifetime.token(), &"coin_claim").status == SimpleRewardResult.Status.CONFLICT, "same event with changed actor token is rejected")
	check.call(coins.claim(token, &"coin_claim").status == SimpleRewardResult.Status.REPLAY, "committed receipt remains readable after environment return")
	var cloned_room := SimpleRoomReward.new()
	cloned_room.configure(COINS, lifetime, health, wallet)
	check.call(cloned_room.claim(lifetime.token(), &"cloned_coin").status == SimpleRewardResult.Status.REPLAY and wallet.balance == 10, "wallet stable source prevents double grant from reconstructed room service")
	health.apply_damage(ActorResourceRequest.new(&"damage_for_heal", health.epoch, 3.0, health.get_instance_id()))
	var maximum := health.capacity
	var healing := SimpleRoomReward.new()
	healing.configure(HEAL, lifetime, health, wallet)
	var reentry: Array = []
	var on_health: Callable = func(_result: ActorResourceResult) -> void: reentry.append(healing.claim(lifetime.token(), &"reenter_heal").accepted())
	health.changed.connect(on_health)
	var heal_token := lifetime.token()
	var healed := healing.claim(heal_token, &"heal_claim")
	health.changed.disconnect(on_health)
	check.call(healed.accepted() and healed.amount_applied == 2.0 and health.current == maximum - 1.0 and health.capacity == maximum, "health room restores current health while preserving maximum")
	check.call(reentry == [false], "health observer cannot reenter an in-progress room transaction")
	check.call(healing.claim(heal_token, &"heal_claim").status == SimpleRewardResult.Status.REPLAY and health.current == maximum - 1.0, "health reward repeat does not heal twice")
	var previous_stage := SimpleRoomReward.new()
	previous_stage.configure(COINS, lifetime, health, wallet)
	lifetime.stage_epoch += 1
	check.call(previous_stage.claim(lifetime.token(), &"old_room").status == SimpleRewardResult.Status.STALE and wallet.balance == 10, "new stage token cannot claim a previous room offer")
	var next_coins := SimpleRoomReward.new()
	next_coins.configure(COINS, lifetime, health, wallet)
	check.call(next_coins.claim(lifetime.token(), &"next_room").accepted() and wallet.balance == 20, "different stage has its own coin source identity")
	var dead_reward := SimpleRoomReward.new()
	dead_reward.configure(HEAL, lifetime, health, wallet)
	health.apply_damage(ActorResourceRequest.new(&"fatal", health.epoch, 99.0, health.get_instance_id()))
	check.call(dead_reward.claim(lifetime.token(), &"dead_heal").status == SimpleRewardResult.Status.TERMINAL and not dead_reward.claimed and health.current == 0.0, "terminal actor cannot claim a heal or mark its offer committed")
	var dead_coins := SimpleRoomReward.new()
	dead_coins.configure(COINS, lifetime, health, wallet)
	check.call(dead_coins.claim(lifetime.token(), &"dead_coins").status == SimpleRewardResult.Status.TERMINAL and wallet.balance == 20, "terminal actor cannot claim coin rewards either")
	lifetime.end()
	check.call(coins.claim(token, &"coin_claim").status == SimpleRewardResult.Status.REPLAY and wallet.balance == 20, "run end preserves already committed read-only receipt")
	check.call(dead_reward.claim(lifetime.token(), &"after_end").status == SimpleRewardResult.Status.STALE, "ended run cancels new claims")
	fixture.world.free()
