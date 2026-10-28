class_name ShopService
extends RefCounted

signal purchased(receipt: EconomyReceipt)
var lifetime: DemoLifetime
var build: BuildState
var wallet: RunWallet
var _offers: Dictionary = {}
var _receipts: Dictionary = {}
var _committing := false
var _catalog_shops: Dictionary = {}
var _map_rerolls: Dictionary = {}
const CATALOG_SHOP_VERSION := "item-v5-shop-v2"
const LEGACY_CATALOG_SHOP_VERSION := "item-v5-shop-v1"

func configure(scope: DemoLifetime, state: BuildState, coins: RunWallet) -> void:
	lifetime = scope
	build = state
	wallet = coins
	build.equipment.bind_lifetime(scope)

func add_offer(id: StringName, item: ItemDefinition, price: int, stock: int) -> bool:
	if lifetime == null or not lifetime.active or id.is_empty() or item == null or not item.is_valid() or price < 0 or stock < 0 or _offers.has(id):
		return false
	var offer := ShopOffer.new()
	offer.offer_id = id
	offer.item = item.duplicate(true)
	offer.price = price
	offer.stock = stock
	offer.run_epoch = lifetime.epoch
	offer.stage_epoch = lifetime.stage_epoch
	_offers[id] = offer
	return true

func quote(id: StringName) -> ShopOffer:
	return _offers[id].copy() if _offers.has(id) else null

func get_receipt(id: StringName) -> EconomyReceipt:
	return _receipts[id].receipt.copy() if _receipts.has(id) else null

func purchase(request: ShopPurchaseRequest) -> EconomyReceipt:
	if request == null or request.transaction_id.is_empty() or request.token == null:
		return EconomyReceipt.rejected(EconomyReceipt.Status.INVALID)
	var payload := [&"item", request.shop_id, request.offer_id, request.quantity, request.quote_version, request.token.run_epoch, request.token.stage_epoch, request.token.actor_epoch]
	if _receipts.has(request.transaction_id):
		if _receipts[request.transaction_id].payload != payload:
			return EconomyReceipt.rejected(EconomyReceipt.Status.CONFLICT)
		var replay: EconomyReceipt = _receipts[request.transaction_id].receipt.copy()
		replay.status = EconomyReceipt.Status.REPLAY
		return replay
	if _committing or not lifetime.accepts(request.token):
		return EconomyReceipt.rejected(EconomyReceipt.Status.STALE)
	var offer: ShopOffer = _offers.get(request.offer_id)
	if offer == null or offer.run_epoch != lifetime.epoch or offer.stage_epoch != lifetime.stage_epoch or offer.shop_id != request.shop_id or request.quantity != 1 or offer.currency_type != &"RunCoin" or offer.quote_version != request.quote_version or offer.stock < 1 or not build.can_add(offer.item):
		return EconomyReceipt.rejected(EconomyReceipt.Status.UNAVAILABLE)
	if wallet.balance < offer.price:
		return EconomyReceipt.rejected(EconomyReceipt.Status.INSUFFICIENT)
	_committing = true
	wallet.balance -= offer.price
	offer.stock -= 1
	if not build.add_item(StringName("shop:%s" % request.transaction_id), offer.item, &"shop"):
		wallet.balance += offer.price
		offer.stock += 1
		_committing = false
		return EconomyReceipt.rejected(EconomyReceipt.Status.UNAVAILABLE)
	var receipt := EconomyReceipt.new()
	receipt.status = EconomyReceipt.Status.COMMITTED
	receipt.event_id = request.transaction_id
	receipt.item_id = offer.item.stable_id
	receipt.instance_id = build.inventory.instance_for_source(StringName("shop:%s" % request.transaction_id)).instance_id
	receipt.coins = -offer.price
	_receipts[request.transaction_id] = {"payload": payload, "receipt": receipt.copy()}
	_committing = false
	purchased.emit(receipt.copy())
	return receipt

func gear_quote() -> Dictionary:
	return build.equipment.upgrade_quote() if build != null else {"available":false}

func purchase_gear_upgrade(request: ShopPurchaseRequest) -> EconomyReceipt:
	if request == null or request.transaction_id.is_empty() or request.token == null:
		return EconomyReceipt.rejected(EconomyReceipt.Status.INVALID)
	var payload := [&"gear",request.shop_id,request.offer_id,request.quantity,request.quote_version,request.token.run_epoch,request.token.stage_epoch,request.token.actor_epoch,request.equipment_session,request.equipment_revision]
	if _receipts.has(request.transaction_id):
		if _receipts[request.transaction_id].payload != payload: return EconomyReceipt.rejected(EconomyReceipt.Status.CONFLICT)
		var replay: EconomyReceipt = _receipts[request.transaction_id].receipt.copy()
		replay.status = EconomyReceipt.Status.REPLAY
		return replay
	if _committing or not lifetime.accepts(request.token): return EconomyReceipt.rejected(EconomyReceipt.Status.STALE)
	if not build.equipment.validate_session(request.token,request.equipment_session,request.equipment_revision).is_empty(): return EconomyReceipt.rejected(EconomyReceipt.Status.STALE)
	var quote := gear_quote()
	if request.shop_id != &"demo_shop" or request.offer_id != &"gear_capacity" or request.quantity != 1 or not quote.available or request.quote_version != quote.quote_version:
		return EconomyReceipt.rejected(EconomyReceipt.Status.UNAVAILABLE)
	if wallet.balance < int(quote.price): return EconomyReceipt.rejected(EconomyReceipt.Status.INSUFFICIENT)
	_committing = true
	wallet.balance -= int(quote.price)
	if not build.equipment._commit_capacity_upgrade(int(quote.level)):
		wallet.balance += int(quote.price)
		_committing = false
		return EconomyReceipt.rejected(EconomyReceipt.Status.UNAVAILABLE)
	var receipt := EconomyReceipt.new()
	receipt.status = EconomyReceipt.Status.COMMITTED
	receipt.event_id = request.transaction_id
	receipt.item_id = &"gear_capacity"
	receipt.coins = -int(quote.price)
	receipt.gear_capacity = int(quote.next_capacity)
	receipt.gear_level = int(quote.level)+1
	_receipts[request.transaction_id] = {"payload":payload,"receipt":receipt.copy()}
	_committing = false
	purchased.emit(receipt.copy())
	return receipt

func repair_quote(instance_id: StringName) -> Dictionary:
	var unavailable := {"available": false, "instance_id": instance_id, "price": 0, "quote_version": 0}
	if build == null or build.inventory == null: return unavailable
	var instance := build.inventory.get_instance(instance_id)
	if instance == null or instance.item.catalog_version != 5 or not bool(instance.effect_state.get("broken", false)): return unavailable
	var parameters := instance.item.parameters_for_level(instance.level)
	var price: Variant = parameters.get("repair_price", 0)
	if not (price is int or price is float) or not is_finite(float(price)) or price != int(price) or price <= 0 or int(parameters.get("break_on_hits", 0)) <= 0: return unavailable
	return {"available": true, "instance_id": instance_id, "item_id": instance.definition_id, "price": int(price), "quote_version": build.inventory.revision + 1}

func purchase_repair(request: ShopPurchaseRequest) -> EconomyReceipt:
	if request == null or request.transaction_id.is_empty() or request.token == null: return EconomyReceipt.rejected(EconomyReceipt.Status.INVALID)
	var payload := [&"repair", request.shop_id, request.offer_id, request.quantity, request.quote_version, request.token.run_epoch, request.token.stage_epoch, request.token.actor_epoch, request.equipment_session, request.equipment_revision]
	var replay := _transaction_replay(request.transaction_id, payload)
	if replay != null: return replay
	if _committing or lifetime == null or not lifetime.accepts(request.token): return EconomyReceipt.rejected(EconomyReceipt.Status.STALE)
	if build == null or not build.equipment.validate_session(request.token, request.equipment_session, request.equipment_revision).is_empty(): return EconomyReceipt.rejected(EconomyReceipt.Status.STALE)
	var offer := repair_quote(request.offer_id)
	if request.shop_id != &"demo_shop" or request.quantity != 1 or not offer.available or request.quote_version != offer.quote_version: return EconomyReceipt.rejected(EconomyReceipt.Status.UNAVAILABLE)
	if wallet == null or wallet.balance < int(offer.price): return EconomyReceipt.rejected(EconomyReceipt.Status.INSUFFICIENT)
	var savepoint := build.inventory._transaction_snapshot()
	_committing = true
	wallet.balance -= int(offer.price)
	var patch_id := StringName("repair/%s/%s" % [request.transaction_id, request.quote_version])
	if not build.inventory.patch_effect_state(request.offer_id, {"broken": false, "damage_hits": 0}, patch_id):
		wallet.balance += int(offer.price)
		_committing = false
		return EconomyReceipt.rejected(EconomyReceipt.Status.UNAVAILABLE)
	if not build.refresh_equipped():
		# An unsupported effect/context must not charge for a partial repair.
		build.inventory._restore_transaction(savepoint)
		build.refresh_equipped()
		wallet.balance += int(offer.price)
		_committing = false
		return EconomyReceipt.rejected(EconomyReceipt.Status.UNAVAILABLE)
	var receipt := EconomyReceipt.new()
	receipt.status = EconomyReceipt.Status.COMMITTED
	receipt.event_id = request.transaction_id
	receipt.item_id = offer.item_id
	receipt.instance_id = request.offer_id
	receipt.coins = -int(offer.price)
	_receipts[request.transaction_id] = {"payload": payload, "receipt": receipt.copy()}
	_committing = false
	purchased.emit(receipt.copy())
	return receipt

static func adjusted_rarity_weights(base: Dictionary, dice: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	var sum := 0
	for name: String in ["blue", "purple", "gold"]:
		var value: Variant = base.get(name, -1)
		if not (value is int or value is float) or not is_finite(float(value)) or value != int(value) or value < 0 or value > 100: return {}
		result[name] = int(value)
		sum += int(value)
	if sum != 100: return {}
	if dice.is_empty(): return result
	var blue: Variant = dice.get("blue_penalty_pp", -1)
	var purple: Variant = dice.get("purple_bonus_pp", -1)
	var gold: Variant = dice.get("gold_bonus_pp", -1)
	for value: Variant in [blue, purple, gold]:
		if not (value is int or value is float) or not is_finite(float(value)) or value != int(value) or value < 0 or value > 100: return {}
	if int(blue) != int(purple) + int(gold) or int(result.blue) < int(blue): return {}
	result.blue = int(result.blue) - int(blue)
	result.purple = int(result.purple) + int(purple)
	result.gold = int(result.gold) + int(gold)
	return result

func register_catalog_shop(shop_id: StringName, map_key: StringName, seed: String, pool: Array[ItemDefinition], rarity_weights: Dictionary, reroll_price: int, slots: int = 3, dice_parameters: Dictionary = {}, rng_context: StringName = &"") -> Dictionary:
	if lifetime == null or not lifetime.active or build == null or shop_id.is_empty() or map_key.is_empty() or seed.is_empty() or reroll_price < 0 or slots < 1 or slots > 8: return {}
	var key := _catalog_key(shop_id, map_key)
	if _catalog_shops.has(key):
		var previous: Dictionary = _catalog_shops[key]
		# Reopening/reactivating a visited map binds fresh epochs, never new RNG.
		if int(previous.scope_id) != lifetime.get_instance_id() or previous.seed != seed or previous.base_weights != rarity_weights or int(previous.reroll_price) != reroll_price or int(previous.slots) != slots or previous.rng_context != rng_context: return {}
		for id: StringName in previous.offer_ids:
			var old: ShopOffer = _offers.get(id)
			if old != null:
				old.run_epoch = lifetime.epoch
				old.stage_epoch = lifetime.stage_epoch
		previous.stage_epoch = lifetime.stage_epoch
		return catalog_shop_snapshot(shop_id, map_key)
	var active_dice := _active_dice_parameters()
	if not dice_parameters.is_empty() and dice_parameters != active_dice: return {}
	var weights := adjusted_rarity_weights(rarity_weights, active_dice)
	if weights.is_empty(): return {}
	var plan := _plan_catalog_roll(shop_id, map_key, seed, 0, pool, weights, slots, rng_context)
	if plan.is_empty(): return {}
	var row := {"shop_id": shop_id, "map_key": map_key, "seed": seed, "rng_context": rng_context, "content_version": CATALOG_SHOP_VERSION if not rng_context.is_empty() else LEGACY_CATALOG_SHOP_VERSION, "scope_id": lifetime.get_instance_id(), "stage_epoch": lifetime.stage_epoch, "base_weights": rarity_weights.duplicate(true), "weights": weights, "reroll_price": reroll_price, "slots": slots, "roll": 0, "offer_ids": [], "stream_position": int(plan.stream_position), "pool_fingerprints": plan.pool_fingerprints, "draws": plan.draws}
	_commit_catalog_roll(row, plan.items)
	_catalog_shops[key] = row
	return catalog_shop_snapshot(shop_id, map_key)

func catalog_shop_snapshot(shop_id: StringName, map_key: StringName) -> Dictionary:
	var key := _catalog_key(shop_id, map_key)
	if not _catalog_shops.has(key): return {}
	var row: Dictionary = _catalog_shops[key]
	var offers: Array[Dictionary] = []
	for id: StringName in row.offer_ids:
		var offer: ShopOffer = _offers[id]
		offers.append({"offer_id": offer.offer_id, "item_id": offer.item.stable_id, "definition_version": offer.item.definition_version, "fingerprint": offer.item.fingerprint(), "price": offer.price, "stock": offer.stock, "quote_version": offer.quote_version})
	return {"content_version": row.content_version, "rng_context": String(row.rng_context), "shop_id": shop_id, "map_key": map_key, "roll": int(row.roll), "offers": offers, "base_weights": row.base_weights.duplicate(true), "weights": row.weights.duplicate(true), "stream_namespace": "item_v5_shop", "stream_position": int(row.stream_position), "pool_fingerprints": row.pool_fingerprints.duplicate(true), "draws": row.draws.duplicate(true), "rarity_fallback": "renormalize_nonempty_legal_buckets"}

func reroll_quote(shop_id: StringName, map_key: StringName, dice_parameters: Dictionary = {}) -> Dictionary:
	var key := _catalog_key(shop_id, map_key)
	if not _catalog_shops.has(key): return {"available": false}
	var row: Dictionary = _catalog_shops[key]
	var active_dice := _active_dice_parameters()
	if not dice_parameters.is_empty() and dice_parameters != active_dice: return {"available": false}
	if lifetime == null or not lifetime.active or int(row.scope_id) != lifetime.get_instance_id() or int(row.stage_epoch) != lifetime.stage_epoch or adjusted_rarity_weights(row.base_weights, active_dice).is_empty(): return {"available": false}
	var count := int(_map_rerolls.get(String(map_key), 0))
	var free_limit := maxi(0, int(active_dice.get("free_rerolls_per_map", 0)))
	var free := count < free_limit
	return {"available": true, "shop_id": shop_id, "offer_id": StringName("v5_reroll/%s" % map_key), "map_key": map_key, "quote_version": int(row.roll) + 1, "price": 0 if free else int(row.reroll_price), "free": free, "free_remaining": maxi(0, free_limit - count), "map_rerolls": count, "roll": int(row.roll)}

func reroll_catalog_shop(request: ShopPurchaseRequest, map_key: StringName, pool: Array[ItemDefinition], dice_parameters: Dictionary = {}) -> EconomyReceipt:
	if request == null or request.transaction_id.is_empty() or request.token == null or map_key.is_empty(): return EconomyReceipt.rejected(EconomyReceipt.Status.INVALID)
	var payload := [&"reroll", request.shop_id, request.offer_id, map_key, request.quantity, request.quote_version, request.token.run_epoch, request.token.stage_epoch, request.token.actor_epoch, request.equipment_session, request.equipment_revision]
	var replay := _transaction_replay(request.transaction_id, payload)
	if replay != null: return replay
	if _committing or lifetime == null or not lifetime.accepts(request.token): return EconomyReceipt.rejected(EconomyReceipt.Status.STALE)
	if build == null or not build.equipment.validate_session(request.token, request.equipment_session, request.equipment_revision).is_empty(): return EconomyReceipt.rejected(EconomyReceipt.Status.STALE)
	var quote := reroll_quote(request.shop_id, map_key, dice_parameters)
	if not quote.get("available", false) or request.offer_id != quote.offer_id or request.quantity != 1 or request.quote_version != quote.quote_version: return EconomyReceipt.rejected(EconomyReceipt.Status.UNAVAILABLE)
	if wallet == null or wallet.balance < int(quote.price): return EconomyReceipt.rejected(EconomyReceipt.Status.INSUFFICIENT)
	var key := _catalog_key(request.shop_id, map_key)
	var row: Dictionary = _catalog_shops[key]
	var weights := adjusted_rarity_weights(row.base_weights, _active_dice_parameters())
	var plan := _plan_catalog_roll(request.shop_id, map_key, row.seed, int(row.roll) + 1, pool, weights, int(row.slots), row.rng_context)
	if plan.is_empty(): return EconomyReceipt.rejected(EconomyReceipt.Status.UNAVAILABLE)
	_committing = true
	wallet.balance -= int(quote.price)
	# Superseded offers stay as history, but cannot be bought by an old callback.
	for id: StringName in row.offer_ids:
		var previous: ShopOffer = _offers[id]
		previous.stock = 0
		previous.quote_version += 1
	row.roll = int(row.roll) + 1
	row.weights = weights
	row.stream_position = int(plan.stream_position)
	row.pool_fingerprints = plan.pool_fingerprints
	row.draws = plan.draws
	_commit_catalog_roll(row, plan.items)
	_map_rerolls[String(map_key)] = int(_map_rerolls.get(String(map_key), 0)) + 1
	var receipt := EconomyReceipt.new()
	receipt.status = EconomyReceipt.Status.COMMITTED
	receipt.event_id = request.transaction_id
	receipt.item_id = &"shop_reroll"
	receipt.coins = -int(quote.price)
	_receipts[request.transaction_id] = {"payload": payload, "receipt": receipt.copy(), "snapshot": catalog_shop_snapshot(request.shop_id, map_key)}
	_committing = false
	purchased.emit(receipt.copy())
	return receipt

func reroll_receipt_snapshot(transaction_id: StringName) -> Dictionary:
	return _receipts[transaction_id].get("snapshot", {}).duplicate(true) if _receipts.has(transaction_id) else {}

func _transaction_replay(transaction_id: StringName, payload: Array) -> EconomyReceipt:
	if not _receipts.has(transaction_id): return null
	if _receipts[transaction_id].payload != payload: return EconomyReceipt.rejected(EconomyReceipt.Status.CONFLICT)
	var receipt: EconomyReceipt = _receipts[transaction_id].receipt.copy()
	receipt.status = EconomyReceipt.Status.REPLAY
	return receipt

func _catalog_key(shop_id: StringName, map_key: StringName) -> StringName:
	return StringName(JSON.stringify([String(map_key), String(shop_id)]))

func _active_dice_parameters() -> Dictionary:
	if build == null or build.inventory == null or build.equipment == null: return {}
	for id: StringName in build.equipment.equipped_ids():
		var instance := build.inventory.get_instance(id)
		if instance != null and instance.definition_id == &"G12" and not bool(instance.effect_state.get("broken", false)):
			return instance.item.parameters_for_level(instance.level)
	return {}

func _commit_catalog_roll(row: Dictionary, items: Array[ItemDefinition]) -> void:
	var ids: Array[StringName] = []
	for index: int in items.size():
		var id := StringName("item_v5/%s/%s/roll_%s/slot_%s" % [row.map_key, row.shop_id, row.roll, index])
		var offer := ShopOffer.new()
		offer.offer_id = id
		offer.shop_id = row.shop_id
		offer.item = items[index].duplicate(true)
		offer.price = items[index].shop_price
		offer.stock = 1
		offer.run_epoch = lifetime.epoch
		offer.stage_epoch = lifetime.stage_epoch
		_offers[id] = offer
		ids.append(id)
	row.offer_ids = ids

func _plan_catalog_roll(shop_id: StringName, map_key: StringName, seed: String, roll: int, pool: Array[ItemDefinition], weights: Dictionary, slots: int, rng_context: StringName = &"") -> Dictionary:
	var eligible: Array[ItemDefinition] = []
	var fingerprints: Dictionary = {}
	for item: ItemDefinition in pool:
		if item == null or not item.is_valid() or item.catalog_version != 5 or item.shop_price < 0 or fingerprints.has(String(item.stable_id)): return {}
		fingerprints[String(item.stable_id)] = item.fingerprint()
		if item.appearance_weight > 0.0 and build.can_add(item): eligible.append(item)
	if eligible.size() < slots or weights.is_empty(): return {}
	eligible.sort_custom(func(a: ItemDefinition, b: ItemDefinition) -> bool: return String(a.stable_id) < String(b.stable_id))
	# Receipt/stock identities retain their run namespace. Only the explicit
	# stable world-role context controls new formal draws and their paid rerolls.
	var context := "%s/roll_%s" % [rng_context, roll] if not rng_context.is_empty() else "%s/%s/roll_%s" % [map_key, shop_id, roll]
	var version := CATALOG_SHOP_VERSION if not rng_context.is_empty() else LEGACY_CATALOG_SHOP_VERSION
	var stream := RunRandomStream.new(seed, "item_v5_shop", context, version)
	var chosen: Array[ItemDefinition] = []
	var draws: Array[Dictionary] = []
	for unused: int in slots:
		var available: Array[int] = []
		var rarity_total := 0
		for rarity: int in 3:
			if eligible.any(func(item: ItemDefinition) -> bool: return int(item.rarity) == rarity):
				available.append(rarity)
				rarity_total += int(weights[["blue", "purple", "gold"][rarity]])
		if rarity_total <= 0: return {}
		var rarity_roll := stream.next_int(rarity_total)
		var remaining := rarity_roll
		var selected_rarity := -1
		for rarity: int in available:
			remaining -= int(weights[["blue", "purple", "gold"][rarity]])
			if remaining < 0:
				selected_rarity = rarity
				break
		var total := 0.0
		for item: ItemDefinition in eligible:
			if int(item.rarity) == selected_rarity: total += item.appearance_weight
		if not is_finite(total) or total <= 0.0: return {}
		var item_roll := stream.next_int(1000000)
		var threshold := float(item_roll) / 1000000.0 * total
		var selected := -1
		for index: int in eligible.size():
			if int(eligible[index].rarity) != selected_rarity: continue
			selected = index
			threshold -= eligible[index].appearance_weight
			if threshold < 0.0: break
		if selected < 0: return {}
		chosen.append(eligible[selected].duplicate(true))
		draws.append({"rarity_roll": rarity_roll, "rarity_total": rarity_total, "item_roll": item_roll, "rarity": selected_rarity, "item": eligible[selected].stable_id})
		eligible.remove_at(selected)
	return {"items": chosen, "pool_fingerprints": fingerprints, "draws": draws, "stream_position": stream.position()}
