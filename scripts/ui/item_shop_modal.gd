class_name ItemShopModal
extends CanvasLayer
signal purchase_requested
signal closed
var opened := false
var _root: Control
var _shell: DemoUiModalShell
var _submitted := false

func show_offer(offer: ShopOffer, coins: int, eligible: bool) -> void:
	close()
	opened = true
	_submitted = false
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shell = DemoUiModalShell.new()
	_shell.preferred_width = 420
	_shell.preferred_height = 540
	_root = _shell
	add_child(_root)
	_shell.heading("CAMP SHOP / 营地商店", "购买后进入本局背包，在暂停构筑中装备。满负荷仍可购买。", "COINS %s  /  STOCK %s" % [coins, offer.stock])
	var card := ItemCard.new()
	card.item = offer.item
	_shell.rows.add_child(card)
	var buy := _shell.button("BUY / %s COINS" % offer.price, func() -> void:
		if _submitted: return
		_submitted = true
		purchase_requested.emit())
	buy.disabled = not eligible or coins < offer.price or offer.stock < 1
	if buy.disabled:
		var reason := "已售罄 / SOLD OUT" if offer.stock < 1 else "金币不足 / NOT ENOUGH COINS" if coins < offer.price else "背包持有数量已达上限 / OWNERSHIP LIMIT"
		_shell.text(reason, 15, DemoClockworkTheme.BRASS)
	var back := _shell.button("KEEP EXPLORING / 继续探索", func() -> void: closed.emit())
	_shell.cancel_requested.connect(func() -> void: closed.emit())
	(back if buy.disabled else buy).grab_focus()

func close() -> void:
	opened = false
	if is_instance_valid(_root):
		if is_instance_valid(_shell): _shell.restore_focus()
		remove_child(_root)
		_root.queue_free()
	_root = null
	_shell = null
