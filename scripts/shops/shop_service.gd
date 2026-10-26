class_name ShopService
extends RefCounted

signal purchased(receipt: EconomyReceipt)
var lifetime: DemoLifetime
var build: BuildState
var wallet: RunWallet
var _offers: Dictionary = {}
var _receipts: Dictionary = {}
var _committing := false

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
