class_name ItemShopModal
extends CanvasLayer
signal purchase_requested
signal closed
signal catalog_purchase_requested(offer_id: StringName)
signal catalog_reroll_requested
signal repair_requested(instance_id: StringName, quote_version: int)
var opened := false
var _root: Control
var _shell: DemoUiModalShell
var _submitted := false
var _generation := 0

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
	var generation := _generation
	var buy := _shell.button("BUY / %s COINS" % offer.price, func() -> void:
		if not _accept_action(generation): return
		_submitted = true
		purchase_requested.emit())
	buy.disabled = not eligible or coins < offer.price or offer.stock < 1
	if buy.disabled:
		var reason := "已售罄 / SOLD OUT" if offer.stock < 1 else "金币不足 / NOT ENOUGH COINS" if coins < offer.price else "背包持有数量已达上限 / OWNERSHIP LIMIT"
		_shell.text(reason, 15, DemoClockworkTheme.BRASS)
	var back := _shell.button("KEEP EXPLORING / 继续探索", func() -> void:
		if opened and generation == _generation: closed.emit())
	_shell.cancel_requested.connect(func() -> void:
		if opened and generation == _generation: closed.emit())
	(back if buy.disabled else buy).grab_focus()

# Current catalog service supplies fixed offer IDs and versioned repair quotes.
# Keeping this separate preserves the historical single-offer fixture contract.
func show_catalog(snapshot: Dictionary, coins: int) -> void:
	close()
	opened = true
	_submitted = false
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shell = DemoUiModalShell.new()
	_shell.preferred_width = 720
	_shell.preferred_height = 600
	_root = _shell
	add_child(_root)
	var generation := _generation
	_shell.heading("营地商店","购买后进入本局背包；同名成长道具提升等级，不增加负荷。","金币 %s" % coins)
	var first_buy: Button
	for row: Dictionary in snapshot.get("offers",[]):
		var definition := row.get("item",row.get("definition")) as ItemDefinition
		if definition == null: continue
		var id := StringName(row.get("offer_id",&""))
		var price := int(row.get("price",0))
		var stock := int(row.get("stock",0))
		var card := ItemCard.new()
		card.name = "CatalogCard_"+String(id).validate_node_name()
		card.item = definition
		card.level = int(row.get("level",1))
		card.compact = true
		_shell.rows.add_child(card)
		var buy := _shell.button("购买 · %s 金币%s" % [price," · 获得后Lv%s" % int(row.next_level) if row.has("next_level") else ""],func() -> void:
			if not _accept_action(generation): return
			_submitted = true
			catalog_purchase_requested.emit(id))
		buy.name = "CatalogBuy_"+String(id).validate_node_name()
		buy.set_meta(&"offer_id",id)
		buy.disabled = not bool(row.get("eligible",false)) or stock <= 0 or coins < price
		if buy.disabled:
			var reason := "已售罄" if stock <= 0 else "金币不足" if coins < price else ItemPresentation.reason(row.get("reason",""),"已达持有或成长上限，暂不可购买。")
			_shell.text(reason,15,DemoClockworkTheme.MUTED)
		elif first_buy == null: first_buy = buy
		_shell.rows.add_child(HSeparator.new())
	var reroll: Dictionary = snapshot.get("reroll",{})
	if not reroll.is_empty():
		var price := int(reroll.get("price",0))
		var reroll_button := _shell.button("免费刷新本店" if price == 0 else "刷新本店 · %s 金币" % price,func() -> void:
			if not _accept_action(generation): return
			_submitted = true
			catalog_reroll_requested.emit())
		reroll_button.name = "CatalogReroll"
		reroll_button.disabled = not bool(reroll.get("available",false)) or coins < price
		if reroll_button.disabled: _shell.text("金币不足。" if coins < price else ItemPresentation.reason(reroll.get("reason",""),"当前无法刷新。"),15,DemoClockworkTheme.MUTED)
	var repairs: Array = snapshot.get("repairs",[])
	if not repairs.is_empty(): _shell.text("修理台 · 修复不会恢复生命",20,DemoClockworkTheme.BRASS)
	for row: Dictionary in repairs:
		var definition := row.get("item",row.get("definition")) as ItemDefinition
		if definition == null: continue
		var id := StringName(row.get("instance_id",&""))
		var price := int(row.get("price",0))
		var quote_version := int(row.get("quote_version",0))
		var repair := _shell.button("修复 %s · %s 金币" % [definition.display_name,price],func() -> void:
			if not _accept_action(generation): return
			_submitted = true
			repair_requested.emit(id,quote_version))
		repair.name = "CatalogRepair_"+String(id).validate_node_name()
		repair.set_meta(&"instance_id",id)
		repair.disabled = not bool(row.get("available",false)) or coins < price
		if repair.disabled: _shell.text("金币不足。" if coins < price else ItemPresentation.reason(row.get("reason",""),"当前无法修复。"),15,DemoClockworkTheme.MUTED)
	var message := str(snapshot.get("message",""))
	if not message.is_empty(): _shell.text(message,16,DemoClockworkTheme.BRASS)
	var back := _shell.button("继续探索",func() -> void:
		if opened and generation == _generation: closed.emit())
	back.name = "CatalogShopClose"
	_shell.cancel_requested.connect(func() -> void:
		if opened and generation == _generation: closed.emit())
	_shell.focus_first()
	(first_buy if first_buy != null else back).grab_focus()

func _accept_action(generation: int) -> bool:
	return opened and not _submitted and generation == _generation

func close() -> void:
	_generation += 1
	opened = false
	if is_instance_valid(_root):
		if is_instance_valid(_shell): _shell.restore_focus()
		remove_child(_root)
		_root.queue_free()
	_root = null
	_shell = null
