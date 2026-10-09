class_name ShopService
extends RefCounted

signal purchased(receipt: EconomyReceipt)
var lifetime: DemoLifetime
var build: BuildState
var wallet: RunWallet
var _offers: Dictionary = {}
var _receipts: Dictionary = {}

func configure(scope: DemoLifetime, state: BuildState, coins: RunWallet) -> void:
	lifetime = scope
	build = state
	wallet = coins

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
	var payload := [request.shop_id, request.offer_id, request.quantity, request.quote_version, request.token.run_epoch, request.token.stage_epoch, request.token.actor_epoch]
	if _receipts.has(request.transaction_id):
		if _receipts[request.transaction_id].payload != payload:
			return EconomyReceipt.rejected(EconomyReceipt.Status.CONFLICT)
		var replay: EconomyReceipt = _receipts[request.transaction_id].receipt.copy()
		replay.status = EconomyReceipt.Status.REPLAY
		return replay
	if not lifetime.accepts(request.token):
		return EconomyReceipt.rejected(EconomyReceipt.Status.STALE)
	var offer: ShopOffer = _offers.get(request.offer_id)
	if offer == null or offer.run_epoch != lifetime.epoch or offer.stage_epoch != lifetime.stage_epoch or offer.shop_id != request.shop_id or request.quantity != 1 or offer.currency_type != &"RunCoin" or offer.quote_version != request.quote_version or offer.stock < 1 or not build.can_add(offer.item):
		return EconomyReceipt.rejected(EconomyReceipt.Status.UNAVAILABLE)
	if wallet.balance < offer.price:
		return EconomyReceipt.rejected(EconomyReceipt.Status.INSUFFICIENT)
	wallet.balance -= offer.price
	offer.stock -= 1
	if not build.add_item(StringName("shop:%s" % request.transaction_id), offer.item):
		wallet.balance += offer.price
		offer.stock += 1
		return EconomyReceipt.rejected(EconomyReceipt.Status.UNAVAILABLE)
	var receipt := EconomyReceipt.new()
	receipt.status = EconomyReceipt.Status.COMMITTED
	receipt.event_id = request.transaction_id
	receipt.item_id = offer.item.stable_id
	receipt.coins = -offer.price
	_receipts[request.transaction_id] = {"payload": payload, "receipt": receipt.copy()}
	purchased.emit(receipt.copy())
	return receipt
