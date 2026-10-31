extends SceneTree
## Native initialization fixture: calls DemoApp's actual cache/Boss consumers
## and ItemV5ShopPresenter.map_ready, rather than restating their RNG formulas.
## The app intentionally stays outside the tree so its unrelated _ready UI and
## initial run creation do not replace the explicitly controlled seed/build.
var assertions := 0
var failures := 0
var fixture: Variant

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func item_ids(items: Array[ItemDefinition]) -> Array[String]:
	var result: Array[String] = []
	for item: ItemDefinition in items:
		if item != null: result.append(String(item.stable_id))
	return result

func sample(seed: String, receipt_prefix: String, region: StringName, map_index: int) -> Dictionary:
	var app := DemoApp.new()
	app.director.seed = seed
	app.director.state = DemoRunDirector.State.IN_STAGE
	app.director.stage_index = 1
	app.director.region_map_index = map_index
	app.director.manifest = RunManifest.new(seed)
	app.director.manifest.append_stage(1, &"boss", region, [])
	app.active_region_id = region
	app.set("_run_receipt_prefix", receipt_prefix)
	app.controller = fixture.controller
	app.player = fixture.motor
	app.build = BuildState.new()
	app.build.configure(app.controller, app.lifetime, &"rng_identity_fixture")
	app.wallet = RunWallet.new()
	app.shop = ShopService.new()
	app.shop.configure(app.lifetime, app.build, app.wallet)
	var pool := ItemV5Pool.new()
	pool.configure(app.build)
	app.set("_item_v5_pool", pool)
	var result: Dictionary = {"receipt_prefix":receipt_prefix, "seed":seed, "region":region, "map":map_index, "caches":{}}
	for tier: String in ["medium", "high", "gold"]:
		var chest := {"id":"%s/map_%s/cache/%s" % [region, map_index, tier], "tier":tier}
		var selected: Array[ItemDefinition] = app.call("_v5_cache_items", chest)
		result.caches[tier] = item_ids(selected)
		check(selected.size() == 2, "actual %s cache selects two legal items (%s)" % [tier, receipt_prefix])
	var gold := app.call("_v5_boss_gold") as ItemDefinition
	result.boss = String(gold.stable_id) if gold != null else ""
	check(gold != null and gold.rarity == ItemDefinition.Rarity.GOLD, "actual Boss consumer selects legal gold (%s)" % receipt_prefix)
	var presenter := ItemV5ShopPresenter.new()
	presenter.configure(app, pool)
	var map_key := StringName(receipt_prefix + "/" + str(app.call("_region_prefix")))
	var stable_context := StringName(str(app.call("_region_prefix")) + "shop")
	presenter.map_ready(map_key, stable_context)
	var shop_id := StringName(presenter.get("_shop_id"))
	var snapshot := app.shop.catalog_shop_snapshot(shop_id, map_key)
	var shop_items: Array[String] = []
	for row: Dictionary in snapshot.get("offers", []): shop_items.append(String(row.item_id))
	result.shop = shop_items
	result.shop_id = String(shop_id)
	result.map_key = String(map_key)
	check(shop_items.size() == 3, "actual Presenter registers three frozen shop items (%s)" % receipt_prefix)
	check(snapshot.get("rng_context") == String(stable_context) and snapshot.get("content_version") == "item-v5-shop-v2", "formal shop Manifest records independent stable context and v2 derivation")
	var reopened := app.shop.catalog_shop_snapshot(shop_id, map_key)
	check(reopened == snapshot, "same-run stock snapshot remains frozen (%s)" % receipt_prefix)
	var configuration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/item_v5_economy.json"))
	check(app.shop.register_catalog_shop(shop_id, map_key, seed, pool.eligible_items(-1, true), configuration.rarity_weights, int(configuration.reroll_price), int(configuration.shop_slots), {}, &"different/world/role").is_empty() and app.shop.catalog_shop_snapshot(shop_id, map_key) == snapshot, "reopening with a changed RNG context rejects rather than regenerating stock")
	check(app.wallet.grant(100, StringName(receipt_prefix + "/fixture/fund")), "explicit initialization funds original run wallet")
	paused = true
	var token := app.lifetime.token()
	var session := app.build.equipment.open_session(token)
	var quote := app.shop.reroll_quote(shop_id, map_key)
	var request := ShopPurchaseRequest.new()
	request.transaction_id = StringName(receipt_prefix + "/reroll/1")
	request.shop_id = shop_id
	request.offer_id = StringName(quote.get("offer_id", &""))
	request.quantity = 1
	request.quote_version = int(quote.get("quote_version", 0))
	request.token = token
	request.equipment_session = session
	request.equipment_revision = int(app.build.equipment.snapshot().revision)
	var rerolled := app.shop.reroll_catalog_shop(request, map_key, pool.eligible_items(-1, true))
	check(rerolled.accepted() and app.wallet.balance == 100 - int(configuration.reroll_price), "real paid reroll debits original wallet under valid equipment session")
	var after := app.shop.catalog_shop_snapshot(shop_id, map_key)
	var reroll_items: Array[String] = []
	for row: Dictionary in after.get("offers", []): reroll_items.append(String(row.item_id))
	result.reroll = reroll_items
	check(after.get("rng_context") == String(stable_context) and int(after.get("roll", -1)) == 1, "paid reroll retains frozen stable context and advances only roll number")
	check(app.shop.reroll_catalog_shop(request, map_key, pool.eligible_items(-1, true)).accepted() and app.wallet.balance == 100 - int(configuration.reroll_price) and app.shop.catalog_shop_snapshot(shop_id, map_key) == after, "same transaction reroll replay preserves fee and exact stock")
	app.build.equipment.close_session()
	paused = false
	app.free()
	return result

func _run() -> void:
	fixture = preload("res://tests/combat_tests.gd").new()
	fixture.tree = self
	await fixture.fixture(Vector2(80, 150))
	for region: StringName in [&"plains", &"thorn_forest"]:
		for map_index: int in [1, 2]:
			var seed := "item-v5-identity-fixed-seed"
			var baseline := sample(seed, "run/receipt-A-101", region, map_index)
			for suffix: String in ["B-202", "C-303", "D-404"]:
				var next := sample(seed, "run/receipt-" + suffix, region, map_index)
				check(baseline.caches == next.caches, "same seed/build/map/body keeps cache choices independent of run receipt identity: %s/map_%s/%s" % [region, map_index, suffix])
				check(baseline.boss == next.boss, "same seed/build/map keeps Boss choice independent of run receipt identity: %s/map_%s/%s" % [region, map_index, suffix])
				check(baseline.shop == next.shop, "same seed/build/map keeps shop choices independent of run receipt identity: %s/map_%s/%s" % [region, map_index, suffix])
				check(baseline.reroll == next.reroll, "same paid reroll number keeps choices independent of transaction identity: %s/map_%s/%s" % [region, map_index, suffix])
				check(baseline.shop_id != next.shop_id and baseline.map_key != next.map_key, "transaction/map identities remain unique between runs despite deterministic item choices")
				print("ITEM V5 RNG SAMPLE " + JSON.stringify({"baseline":baseline,"comparison":next}))
	fixture.world.free()
	print("ITEM V5 RANDOM CONTEXT: %s checks, %s failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
