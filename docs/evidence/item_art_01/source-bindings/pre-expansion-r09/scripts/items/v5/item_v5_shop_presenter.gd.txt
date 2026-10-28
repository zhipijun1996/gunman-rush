class_name ItemV5ShopPresenter
extends RefCounted
## The formal merchant adapter owns only a paused UI session. ShopService owns
## immutable offers, inventory/coins and transaction receipts; the app keeps the
## run, damage-first interaction queue and Manifest.
const CONFIG_PATH := "res://config/item_v5_economy.json"
const MODAL_OWNER_META: StringName = &"item_v5_shop_presenter_owner"
var _app_ref: WeakRef
var _modal_ref: WeakRef
var _stage_ref: WeakRef
var _session_owner_ref: WeakRef
var _pool: ItemV5Pool
var _configuration: Dictionary = {}
var _map: StringName
var _shop_id: StringName
var _token: DemoToken
var _session := 0
var _router_epoch := -1
var _equipment_revision := -1
var _opened := false
var _submitting := false
var _owns_pause := false
var _generation := 0
var _view_quotes: Dictionary = {}
var _reroll_view: Dictionary = {}
var _repair_views: Dictionary = {}
var _recorded_generations: Dictionary = {}
var _message := ""

func configure(app: Node, pool: ItemV5Pool) -> void:
	_end_session(false)
	_detach_modal()
	_app_ref = weakref(app)
	_pool = pool
	_map = &""
	_shop_id = &""
	_recorded_generations.clear()
	_configuration = _read_configuration()
	_connect_modal()

func _app() -> Node:
	return _app_ref.get_ref() as Node if _app_ref != null else null

func _modal() -> ItemShopModal:
	return _modal_ref.get_ref() as ItemShopModal if _modal_ref != null else null

func _build() -> BuildState:
	var app := _app()
	return app.get("build") as BuildState if is_instance_valid(app) else null

func _actor() -> PlayerController:
	var app := _app()
	return app.get("controller") as PlayerController if is_instance_valid(app) else null

func _shop() -> ShopService:
	var app := _app()
	return app.get("shop") as ShopService if is_instance_valid(app) else null

func _scope() -> DemoLifetime:
	var app := _app()
	return app.get("lifetime") as DemoLifetime if is_instance_valid(app) else null

func _director() -> DemoRunDirector:
	var app := _app()
	return app.get("director") as DemoRunDirector if is_instance_valid(app) else null

func _stage() -> Node2D:
	var app := _app()
	return app.get("stage") as Node2D if is_instance_valid(app) else null

func _runtime() -> RefCounted:
	var actor := _actor()
	return actor.item_runtime if is_instance_valid(actor) else null

func _read_configuration() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not parsed is Dictionary or int(parsed.get("version", -1)) != 1 or not parsed.get("rarity_weights") is Dictionary: return {}
	if ShopService.adjusted_rarity_weights(parsed.rarity_weights).is_empty(): return {}
	for name: String in ["reroll_price", "shop_slots"]:
		var value: Variant = parsed.get(name, -1)
		if not (value is int or value is float) or not is_finite(float(value)) or value != int(value): return {}
	if int(parsed.reroll_price) < 0 or int(parsed.shop_slots) < 1 or int(parsed.shop_slots) > 8: return {}
	return parsed.duplicate(true)

func _connect_modal() -> void:
	var app := _app()
	if not is_instance_valid(app): return
	var modal := app.get("shop_modal") as ItemShopModal
	if not is_instance_valid(modal): return
	var previous: Variant = modal.get_meta(MODAL_OWNER_META) if modal.has_meta(MODAL_OWNER_META) else null
	if previous is WeakRef:
		var previous_owner: Object = previous.get_ref()
		if is_instance_valid(previous_owner) and previous_owner != self and previous_owner.has_method("_detach_modal"):
			previous_owner.call("_detach_modal")
	_modal_ref = weakref(modal)
	modal.set_meta(MODAL_OWNER_META, weakref(self))
	if not modal.catalog_purchase_requested.is_connected(_catalog_purchase): modal.catalog_purchase_requested.connect(_catalog_purchase)
	if not modal.catalog_reroll_requested.is_connected(_catalog_reroll): modal.catalog_reroll_requested.connect(_catalog_reroll)
	if not modal.repair_requested.is_connected(_repair): modal.repair_requested.connect(_repair)

func _detach_modal() -> void:
	_end_session(false)
	var modal := _modal()
	if is_instance_valid(modal):
		if modal.catalog_purchase_requested.is_connected(_catalog_purchase): modal.catalog_purchase_requested.disconnect(_catalog_purchase)
		if modal.catalog_reroll_requested.is_connected(_catalog_reroll): modal.catalog_reroll_requested.disconnect(_catalog_reroll)
		if modal.repair_requested.is_connected(_repair): modal.repair_requested.disconnect(_repair)
		var owner: Variant = modal.get_meta(MODAL_OWNER_META) if modal.has_meta(MODAL_OWNER_META) else null
		if owner is WeakRef and owner.get_ref() == self: modal.remove_meta(MODAL_OWNER_META)
	_modal_ref = null

func map_ready(map_key: StringName, rng_context: StringName = &"") -> void:
	_end_session(false)
	_map = map_key
	_shop_id = StringName("item_v5_shop/%s" % map_key)
	var stage := _stage()
	_stage_ref = weakref(stage) if is_instance_valid(stage) else null
	_connect_modal()
	var app := _app()
	var shop := _shop()
	var director := _director()
	if not is_instance_valid(app) or shop == null or director == null or _pool == null or _configuration.is_empty() or map_key.is_empty(): return
	var snapshot := shop.register_catalog_shop(_shop_id, _map, director.seed, _pool.eligible_items(-1, true), _configuration.rarity_weights, int(_configuration.reroll_price), int(_configuration.shop_slots), _dice(), rng_context)
	if not snapshot.is_empty(): _record_generation(snapshot)

func _dice() -> Dictionary:
	var runtime := _runtime()
	return runtime.call("effect", &"G12") as Dictionary if runtime != null else {}

func _near_merchant() -> bool:
	var stage := _stage()
	var actor := _actor()
	if not stage is PlainsRegionStage or not is_instance_valid(actor): return false
	return actor.motor.global_position.distance_to((stage as PlainsRegionStage).merchant_position) < 90.0

func open() -> bool:
	var app := _app()
	if not is_instance_valid(app) or _opened or _pool == null or _configuration.is_empty() or _map.is_empty() or not bool(app.call("_can_interact")) or not _near_merchant(): return false
	_connect_modal()
	var modal := _modal()
	var actor := _actor()
	var scope := _scope()
	var build := _build()
	if not is_instance_valid(modal) or modal.opened or not is_instance_valid(actor) or not actor.active or actor.has_pending_damage() or not actor.router.has_application_focus or scope == null or not scope.active or build == null: return false
	app.call("_pause_for_menu")
	_owns_pause = true
	_token = scope.token()
	_session_owner_ref = weakref(build)
	_session = build.equipment.open_session(_token)
	_router_epoch = actor.router.epoch
	_equipment_revision = int(build.equipment.snapshot().revision)
	if _session <= 0:
		_end_session(true)
		return false
	_opened = true
	_message = ""
	_generation += 1
	refresh()
	return _opened and modal.opened

func is_open() -> bool:
	return _opened and is_instance_valid(_modal()) and _modal().opened

func _context(require_view_revision := true) -> bool:
	var app := _app()
	var actor := _actor()
	var scope := _scope()
	var director := _director()
	var build := _build()
	var stage := _stage()
	if require_view_revision and (not is_instance_valid(_modal()) or not _modal().opened): return false
	if not _opened or not is_instance_valid(app) or not app.is_inside_tree() or not app.get_tree().paused or not is_instance_valid(actor) or not actor.active or actor.has_pending_damage() or actor.actor_resources.health.terminal or not actor.router.has_application_focus or scope == null or not scope.accepts(_token) or director == null or director.state != DemoRunDirector.State.IN_STAGE or bool(app.get("_stage_pending")) or build == null or not _near_merchant(): return false
	if _stage_ref == null or _stage_ref.get_ref() != stage or actor.router.epoch != _router_epoch or _session_owner_ref == null or _session_owner_ref.get_ref() != build: return false
	var runtime := _runtime()
	if runtime == null or StringName(runtime.call("map_key")) != _map: return false
	var revision := _equipment_revision if require_view_revision else int(build.equipment.snapshot().revision)
	return build.equipment.validate_session(_token, _session, revision).is_empty()

func refresh() -> void:
	if not _context(false):
		_end_session(false)
		return
	var modal := _modal()
	var shop := _shop()
	var build := _build()
	var app := _app()
	if not is_instance_valid(modal) or shop == null or build == null or not is_instance_valid(app): return
	_generation += 1
	_equipment_revision = int(build.equipment.snapshot().revision)
	_view_quotes.clear()
	_repair_views.clear()
	var snapshot := shop.catalog_shop_snapshot(_shop_id, _map)
	var view := snapshot.duplicate(true)
	var rows: Array[Dictionary] = []
	for saved: Dictionary in snapshot.get("offers", []):
		var offer := shop.quote(StringName(saved.offer_id))
		if offer == null: continue
		var reason := ItemV5Eligibility.offer_reason(offer.item, build, true)
		var owned := build.inventory.instance_for_definition(offer.item.stable_id)
		var row := saved.duplicate(true)
		row.item = offer.item
		row.level = owned.level if owned != null else 1
		row.next_level = mini(offer.item.max_level, owned.level + 1) if owned != null else 1
		row.eligible = reason.is_empty()
		row.reason = reason
		rows.append(row)
		_view_quotes[offer.offer_id] = {"quote_version": offer.quote_version, "fingerprint": offer.item.fingerprint(), "price": offer.price}
	view.offers = rows
	_reroll_view = shop.reroll_quote(_shop_id, _map, _dice())
	if _pool.eligible_items(-1, true).size() < int(_configuration.shop_slots):
		_reroll_view.available = false
		_reroll_view.reason = &"insufficient_legal_candidates"
	view.reroll = _reroll_view.duplicate(true)
	var repairs: Array[Dictionary] = []
	for owned: RunItemInstance in build.inventory.instances():
		var quote := shop.repair_quote(owned.instance_id)
		if not bool(quote.get("available", false)): continue
		quote.item = owned.item
		repairs.append(quote)
		_repair_views[owned.instance_id] = {"quote_version": int(quote.quote_version), "price": int(quote.price)}
	view.repairs = repairs
	view.message = _message if not _message.is_empty() else "当前合法商品不足，仍可使用修理台。" if rows.is_empty() else ""
	var coins := app.get("wallet") as RunWallet
	if coins == null: return
	modal.show_catalog(view, coins.balance)

func repair_view_quote(instance_id: StringName) -> Dictionary:
	if not _context(true) or not is_instance_valid(_modal()) or not _modal().opened: return {"available": false}
	return _shop().repair_quote(instance_id) if _shop() != null else {"available": false}

func _request(offer_id: StringName, quote_version: int, kind: String, shop_id: StringName) -> ShopPurchaseRequest:
	var request := ShopPurchaseRequest.new()
	request.token = _token.copy()
	request.shop_id = shop_id
	request.offer_id = offer_id
	request.quote_version = quote_version
	request.transaction_id = StringName(_app().call("_next_id", "item_v5_" + kind))
	request.equipment_session = _session
	request.equipment_revision = _equipment_revision
	return request

func _catalog_purchase(offer_id: StringName) -> void:
	if _submitting or not _context(true) or not _view_quotes.has(offer_id): return
	var shop := _shop()
	var build := _build()
	var offer := shop.quote(offer_id)
	var expected: Dictionary = _view_quotes[offer_id]
	if offer == null or offer.shop_id != _shop_id or offer.quote_version != int(expected.quote_version) or offer.price != int(expected.price) or offer.item.fingerprint() != expected.fingerprint: return
	var reason := ItemV5Eligibility.offer_reason(offer.item, build, true)
	if not reason.is_empty():
		_message = ItemPresentation.reason(reason, "当前无法购买。")
		refresh()
		return
	_submitting = true
	var request := _request(offer_id, offer.quote_version, "purchase", _shop_id)
	var receipt := shop.purchase(request)
	_record_transaction(&"purchase", request, receipt, shop.catalog_shop_snapshot(_shop_id, _map))
	if receipt.accepted():
		build.refresh_equipped()
		if _runtime() != null: _runtime().call("sync")
		var owned := build.inventory.get_instance(receipt.instance_id)
		var level := owned.level if owned != null else 1
		_message = "已升级：%s · Lv%s。" % [offer.item.display_name, level] if level > 1 else "已收入背包：%s。" % offer.item.display_name
		var toast := _app().get("item_toast") as ItemAcquiredToast
		if is_instance_valid(toast): toast.show_item(offer.item, level)
	else: _message = _receipt_message(receipt)
	_finish_action(receipt.accepted())

func _catalog_reroll() -> void:
	if _submitting or not _context(true) or not bool(_reroll_view.get("available", false)): return
	_submitting = true
	var request := _request(StringName(_reroll_view.offer_id), int(_reroll_view.quote_version), "reroll", _shop_id)
	var receipt := _shop().reroll_catalog_shop(request, _map, _pool.eligible_items(-1, true), _dice())
	var snapshot := _shop().catalog_shop_snapshot(_shop_id, _map)
	_record_transaction(&"reroll", request, receipt, snapshot)
	if receipt.accepted():
		_record_generation(snapshot)
		_message = "商店已刷新。" if receipt.coins < 0 else "本地图首次免费刷新已使用。"
	else: _message = _receipt_message(receipt)
	_finish_action(receipt.accepted())

func _repair(instance_id: StringName, quote_version: int) -> void:
	if _submitting or not _context(true) or not _repair_views.has(instance_id) or int(_repair_views[instance_id].quote_version) != quote_version: return
	var quote := repair_view_quote(instance_id)
	if not bool(quote.get("available", false)) or int(quote.quote_version) != quote_version: return
	_submitting = true
	var request := _request(instance_id, quote_version, "repair", &"demo_shop")
	var receipt := _shop().purchase_repair(request)
	_record_transaction(&"repair", request, receipt, _shop().catalog_shop_snapshot(_shop_id, _map))
	if receipt.accepted():
		if _runtime() != null: _runtime().call("sync")
		_message = "道具已修复；当前生命没有恢复。"
	else: _message = _receipt_message(receipt)
	_finish_action(receipt.accepted())

func _finish_action(accepted: bool) -> void:
	_submitting = false
	var app := _app()
	if is_instance_valid(app):
		app.set("_status", _message)
		app.set("_shown_actions", "")
		GameAudio.cue(app, &"confirm" if accepted else &"denied")
	refresh()

func _receipt_message(receipt: EconomyReceipt) -> String:
	if receipt.status == EconomyReceipt.Status.INSUFFICIENT: return "金币不足，未扣款。"
	if receipt.status == EconomyReceipt.Status.STALE: return "操作已过期，请重新打开商店。"
	if receipt.status == EconomyReceipt.Status.CONFLICT: return "交易编号冲突，本次没有变更。"
	return "报价、库存、持有或成长条件已变化；本次没有扣款。"

func _record_generation(snapshot: Dictionary) -> void:
	if snapshot.is_empty(): return
	var category := StringName("item_v5_shop/%s/roll_%s" % [_shop_id, int(snapshot.roll)])
	if _recorded_generations.has(category): return
	var data := snapshot.duplicate(true)
	# Stock is a live transaction value. Generation provenance records only the
	# immutable draw; purchase receipts below carry the actual stock snapshot.
	for row: Dictionary in data.get("offers", []): row.erase("stock")
	if _record(category, data): _recorded_generations[category] = true

func _record_transaction(kind: StringName, request: ShopPurchaseRequest, receipt: EconomyReceipt, snapshot: Dictionary) -> void:
	_record(StringName("item_v5_%s/%s" % [kind, request.transaction_id]), {"version": 1, "map_key": String(_map), "transaction_id": String(request.transaction_id), "kind": String(kind), "shop_id": String(request.shop_id), "offer_id": String(request.offer_id), "quote_version": request.quote_version, "status": receipt.status, "accepted": receipt.accepted(), "coins": receipt.coins, "item_id": String(receipt.item_id), "instance_id": String(receipt.instance_id), "run_epoch": request.token.run_epoch, "stage_epoch": request.token.stage_epoch, "actor_epoch": request.token.actor_epoch, "snapshot": snapshot})

func _record(category: StringName, data: Dictionary) -> bool:
	var director := _director()
	return director != null and director.manifest != null and director.manifest.record_output(director.stage_index, category, data)

func close() -> void:
	_end_session(true)

func _other_overlay_open(app: Node) -> bool:
	for property: String in ["reward_modal", "exit_modal", "map_modal", "progression_modal"]:
		var overlay := app.get(property) as Node
		if is_instance_valid(overlay) and bool(overlay.get("opened")): return true
	var menu := app.get("menu") as DemoMenu
	return is_instance_valid(menu) and not menu.visible_panel.is_empty()

func _end_session(resume: bool) -> void:
	var was_open := _opened
	var owned_pause := _owns_pause
	_opened = false
	_submitting = false
	_owns_pause = false
	_generation += 1
	var owner := _session_owner_ref.get_ref() as BuildState if _session_owner_ref != null else null
	if owner != null and _session > 0 and int(owner.equipment.snapshot().session) == _session: owner.equipment.close_session()
	_session_owner_ref = null
	_session = 0
	_token = null
	_router_epoch = -1
	_equipment_revision = -1
	_view_quotes.clear()
	_reroll_view.clear()
	_repair_views.clear()
	var modal := _modal()
	if is_instance_valid(modal) and (was_open or owned_pause): modal.close()
	var app := _app()
	if not is_instance_valid(app) or not (was_open or owned_pause): return
	var actor := _actor()
	if is_instance_valid(actor): actor.router.clear("item_v5_shop_close")
	if app.is_inside_tree():
		app.get_viewport().gui_release_focus()
		if app.has_method("_resume_exit_input"): app.call("_resume_exit_input")
	var director := _director()
	var scope := _scope()
	if resume and owned_pause and app.is_inside_tree() and director != null and director.state == DemoRunDirector.State.IN_STAGE and scope != null and scope.active and is_instance_valid(actor) and actor.active and actor.router.has_application_focus and not actor.actor_resources.health.terminal and not bool(app.get("_stage_pending")) and not _other_overlay_open(app):
		app.get_tree().paused = false
