class_name RewardService
extends RefCounted

signal claimed(receipt: EconomyReceipt)
var lifetime: DemoLifetime
var build: BuildState
var _offers: Dictionary = {}
var _sources: Dictionary = {}
var _receipts: Dictionary = {}

func configure(scope: DemoLifetime, state: BuildState) -> void:
	lifetime = scope
	build = state

func create_offer(id: StringName, items: Array[ItemDefinition], source_id: StringName) -> RewardOffer:
	return _create(id, items, source_id, false)

func create_gold_offer(id: StringName, item: ItemDefinition, defeat_id: StringName) -> RewardOffer:
	var items: Array[ItemDefinition] = [item]
	return _create(id, items, defeat_id, true)

func _create(id: StringName, items: Array[ItemDefinition], source_id: StringName, gold: bool) -> RewardOffer:
	if lifetime == null or not lifetime.active or id.is_empty() or source_id.is_empty():
		return null
	if _offers.has(id):
		var existing: RewardOffer = _offers[id]
		if existing.source_id != source_id or existing.gold != gold or existing.candidates.size() != items.size():
			return null
		for index: int in items.size():
			if items[index] == null or items[index].fingerprint() != existing.candidates[index].fingerprint():
				return null
		return existing.copy()
	if _sources.has(source_id) or items.size() != (1 if gold else 2):
		return null
	var seen: Array[StringName] = []
	for item: ItemDefinition in items:
		if not build.can_add(item) or item.stable_id in seen or (gold and item.rarity != ItemDefinition.Rarity.GOLD):
			return null
		seen.append(item.stable_id)
	var offer := RewardOffer.new()
	offer.offer_id = id
	offer.source_id = source_id
	offer.run_epoch = lifetime.epoch
	offer.stage_epoch = lifetime.stage_epoch
	offer.gold = gold
	for item: ItemDefinition in items:
		offer.candidates.append(item.duplicate(true))
	_offers[id] = offer
	_sources[source_id] = id
	return offer.copy()

func get_offer(id: StringName) -> RewardOffer:
	return _offers[id].copy() if _offers.has(id) else null

func claim(request: RewardClaimRequest) -> EconomyReceipt:
	if request == null or request.claim_id.is_empty() or request.token == null:
		return EconomyReceipt.rejected(EconomyReceipt.Status.INVALID)
	var payload := [request.offer_id, request.option_id, request.token.run_epoch, request.token.stage_epoch, request.token.actor_epoch]
	if _receipts.has(request.claim_id):
		if _receipts[request.claim_id].payload != payload:
			return EconomyReceipt.rejected(EconomyReceipt.Status.CONFLICT)
		var replay: EconomyReceipt = _receipts[request.claim_id].receipt.copy()
		replay.status = EconomyReceipt.Status.REPLAY
		return replay
	if not lifetime.accepts(request.token):
		return EconomyReceipt.rejected(EconomyReceipt.Status.STALE)
	var offer: RewardOffer = _offers.get(request.offer_id)
	if offer == null or offer.claimed or offer.run_epoch != lifetime.epoch or offer.stage_epoch != lifetime.stage_epoch:
		return EconomyReceipt.rejected(EconomyReceipt.Status.UNAVAILABLE)
	var selected: ItemDefinition
	for item: ItemDefinition in offer.candidates:
		if item.stable_id == request.option_id:
			selected = item
	if selected == null or not build.can_add(selected):
		return EconomyReceipt.rejected(EconomyReceipt.Status.UNAVAILABLE)
	offer.claimed = true
	if not build.add_item(StringName("reward:%s" % offer.source_id), selected):
		offer.claimed = false
		return EconomyReceipt.rejected(EconomyReceipt.Status.UNAVAILABLE)
	offer.claimed = true
	var receipt := EconomyReceipt.new()
	receipt.status = EconomyReceipt.Status.COMMITTED
	receipt.event_id = request.claim_id
	receipt.item_id = selected.stable_id
	_receipts[request.claim_id] = {"payload": payload, "receipt": receipt.copy()}
	claimed.emit(receipt.copy())
	return receipt
