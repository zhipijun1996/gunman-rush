extends SceneTree
## Labeled initialization fixtures, then actual owned state, wallet, equipment
## sessions and ShopService transactions. This is not a natural route capture.
const SUPPORT := preload("res://tests/gear_inventory_support.gd")
var assertions := 0
var failures := 0
var fixture: Variant
var actor: PlayerController
var build: BuildState
var lifetime: DemoLifetime
var wallet: RunWallet
var host: EconomyHost
var effects: ItemEconomyEffects

class RejectingBuild extends BuildState:
	var reject_refresh := false
	func refresh_equipped() -> bool:
		return false if reject_refresh else super.refresh_equipped()

# Inherit the real owned-progress/coin command; the fixture only supplies its
# actor, clock and view data instead of reimplementing production transactions.
class EconomyHost extends ItemRuntime:
	var player: PlayerController
	var construction: BuildState
	var coins: RunWallet
	var clock := 0.0
	var map: StringName = &"economy/map_1"
	var live := true
	var cues: Array[Dictionary] = []
	func actor() -> PlayerController: return player
	func build() -> BuildState: return construction
	func wallet() -> RunWallet: return coins
	func now() -> float: return clock
	func map_key() -> StringName: return map
	func is_live() -> bool: return live and player.active and not player.actor_resources.health.terminal
	func instance(id: StringName) -> RunItemInstance: return construction.inventory.instance_for_definition(id)
	func state(id: StringName) -> Dictionary:
		var owned := instance(id)
		return owned.effect_state if owned != null else {}
	func patch_state(id: StringName, patch: Dictionary, receipt: StringName = &"") -> bool:
		var owned := instance(id)
		return owned != null and construction.inventory.patch_effect_state(owned.instance_id, patch, receipt)
	func effect(id: StringName) -> Dictionary:
		var owned := instance(id)
		return owned.item.parameters_for_level(owned.level) if owned != null and owned.instance_id in construction.equipment.equipped_ids() and not bool(owned.effect_state.get("broken", false)) else {}
	func grant_energy(amount: float, receipt: StringName) -> float:
		return float(player.combat_energy.call("grant", String(receipt), amount))
	func clear_line(a: Vector2, b: Vector2) -> bool:
		var ray := PhysicsRayQueryParameters2D.create(a, b, 1, [player.motor.get_rid()])
		return player.motor.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
	func cue(kind: StringName, point: Vector2, detail: Dictionary = {}) -> void:
		cues.append({"kind": kind, "point": point, "detail": detail.duplicate(true)})

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func fresh() -> void:
	paused = false
	if fixture != null and is_instance_valid(fixture.world): fixture.world.free()
	fixture = preload("res://tests/combat_tests.gd").new()
	fixture.tree = self
	await fixture.fixture(Vector2(80, 150))
	actor = fixture.controller
	lifetime = DemoLifetime.new()
	build = RejectingBuild.new()
	build.configure(actor, lifetime, &"item_v5_economy_fixture")
	wallet = RunWallet.new()
	host = EconomyHost.new()
	host.player = actor
	host.construction = build
	host.coins = wallet
	effects = ItemEconomyEffects.new()
	effects.configure(host)
	effects.map_entered(host.map)

func own(id: StringName) -> bool:
	return build.add_item(StringName("own/%s" % id), ItemCatalogV5.get_item(id))

func equip(ids: Array[StringName]) -> bool:
	var loadout: Array[StringName] = []
	for id: StringName in ids:
		var owned := build.inventory.instance_for_definition(id)
		if owned == null: return false
		loadout.append(owned.instance_id)
	var accepted := SUPPORT.equip_ids(build, loadout)
	effects.sync()
	return accepted

func event(enemy: StringName, boss := false) -> Dictionary:
	return {"enemy_id": enemy, "receipt": StringName("death/%s/%s" % [host.map, enemy]), "map": host.map, "boss": boss, "point": Vector2(100, 150)}

func advance(seconds: float) -> void:
	host.clock += seconds
	effects.advance(seconds, seconds)

func bonus_and_remainder() -> void:
	await fresh()
	check(own(&"B16") and own(&"G10") and own(&"P39") and own(&"B20"), "real catalog economy definitions enter ordinary ownership")
	check(not equip([&"B16", &"G10"]), "two purses coexist in backpack but remain mutually exclusive when equipped")
	check(actor.traversal.grant(&"grapple") and equip([&"B16", &"P39", &"B20"]), "owned economy build equips after separate grapple grant")
	for index: int in 12:
		effects.on_kill(event(StringName("enemy_%s" % index)))
	check(wallet.balance == 8, "cracked purse first eight distinct accepted kills grant exactly eight coins")
	check(int(effects.on_kill(event(&"enemy_0")).coins) == 0 and wallet.balance == 8, "duplicate death receipt does not mint another bonus")
	check(equip([&"P39", &"B20"]) and equip([&"B16", &"P39", &"B20"]), "purse can be unequipped and re-equipped")
	effects.on_kill(event(&"after_re_equip"))
	check(wallet.balance == 8, "purse map allowance cannot reset by re-equipping")
	var total := 0
	for index: int in 4:
		total += effects.settle_kill_coins(1, StringName("loot_%s" % index))
	check(total == 5, "kill coin multiplier accumulates integer remainder: four one-coin drops total five")
	var fraction := float(host.state(&"P39").kill_coin_fraction)
	check(effects.settle_kill_coins(1, &"loot_3") == 2 and is_equal_approx(float(host.state(&"P39").kill_coin_fraction), fraction), "same enemy loot replay returns frozen amount without consuming remainder twice")
	var before_damage := wallet.balance
	effects.on_damage({"amount": 1.0, "receipt": &"hurt"})
	check(wallet.balance == before_damage, "thief oath never removes coins on HP damage")
	for index: int in 12:
		effects.on_hook(event(StringName("hook_%s" % index)))
	check(wallet.balance == 18, "hook theft first distinct targets respects ten-coin map cap")
	effects.on_hook(event(&"hook_0"))
	effects.on_hook(event(&"boss", true))
	check(wallet.balance == 18, "repeat hook and boss hook do not mint coins")
	host.map = &"economy/map_2"
	effects.map_entered(host.map)
	check(equip([&"G10", &"P39", &"B20"]), "immortal purse can replace fragile purse atomically")
	for index: int in 10: effects.on_kill(event(StringName("enemy_%s" % index)))
	check(wallet.balance == 30, "immortal purse new map has six two-coin bonuses, not sixteen coins")
	host.live = false
	effects.on_kill(event(&"stale_death"))
	check(wallet.balance == 30, "dead or stale actor cannot gain new item coins")

func bonus_rollback() -> void:
	await fresh()
	check(own(&"B16") and equip([&"B16"]), "coin conflict fixture equips actual purse")
	var owned := build.inventory.instance_for_definition(&"B16")
	var key := StringName("item/B16/%s/%s/kill/conflict_enemy" % [owned.instance_id, host.map])
	check(wallet.grant(9, key), "explicit conflicting wallet receipt fixture")
	var revision := build.inventory.revision
	var before := host.state(&"B16")
	check(int(effects.on_kill(event(&"conflict_enemy")).coins) == 0 and wallet.balance == 9 and host.state(&"B16") == before and build.inventory.revision == revision, "wallet conflict rolls back the owned earning allowance and revision")

func idle_budget() -> void:
	await fresh()
	check(own(&"G07") and equip([&"G07"]), "idle recovery is equipped explicitly")
	advance(5.9)
	check(is_zero_approx(actor.combat_energy.current), "six active idle seconds are required before any recovery")
	advance(0.2)
	check(is_equal_approx(actor.combat_energy.current, 0.2), "boundary frame counts only active time after idle threshold")
	advance(20.0)
	check(is_equal_approx(actor.combat_energy.current, 20.0), "idle recovery has exactly twenty actual energy per-map allowance")
	check(equip([]) and equip([&"G07"]), "idle item re-equips without changing owned allowance")
	advance(10.0)
	check(is_equal_approx(actor.combat_energy.current, 20.0), "re-equipping cannot refresh the twenty-energy map budget")
	host.map = &"economy/map_2"
	effects.map_entered(host.map)
	advance(7.0)
	check(is_equal_approx(actor.combat_energy.current, 22.0), "new map grants a separate budget after its own idle threshold")
	effects.on_energy_spent(1.0, &"accepted_skill")
	advance(5.0)
	check(is_equal_approx(actor.combat_energy.current, 22.0), "accepted skill spending rearms the full idle gate")
	host.live = false
	advance(10.0)
	check(is_equal_approx(actor.combat_energy.current, 22.0), "inactive actor cannot tick passive recovery")

func magnet_policy() -> void:
	await fresh()
	check(own(&"B01") and equip([&"B01"]), "magnet consumer uses real equipped definition")
	var pickup := {"kind": "coin", "position": Vector2(180, 120), "claimed": false, "id": "original_id", "ready_at": 0.5}
	var original := pickup.duplicate(true)
	check(not effects.can_magnet_pickup(pickup, Vector2(80, 120), 0.4), "magnet respects original settling time")
	check(effects.can_magnet_pickup(pickup, Vector2(80, 120), 0.5), "ordinary settled resource inside two hundred is eligible")
	check(pickup == original, "magnet policy does not move or rename pickup, claim it or replace its receipt")
	for kind: String in ["note", "heart", "energy"]:
		pickup.kind = kind
		check(effects.can_magnet_pickup(pickup, Vector2(80, 120), 1.0), "magnet supports ordinary resource %s" % kind)
	for kind: String in ["item", "chest", "shop"]:
		pickup.kind = kind
		check(not effects.can_magnet_pickup(pickup, Vector2(80, 120), 1.0), "magnet cannot claim reward object %s" % kind)
	pickup.kind = "coin"
	check(not effects.can_magnet_pickup(pickup, Vector2(-30, 120), 1.0), "magnet cannot reach beyond configured radius")
	fixture.body(Rect2(125, 60, 20, 120))
	await physics_frame
	check(not effects.can_magnet_pickup(pickup, Vector2(80, 120), 1.0), "actual solid wall blocks magnet line of sight")
	check(equip([]) and not effects.can_magnet_pickup(pickup, Vector2(80, 120), 1.0), "ownership without equipped magnet supplies no expanded pickup authorization")

func request_for(offer_id: StringName, quote_version: int, transaction_id: StringName, shop_id: StringName = &"demo_shop") -> ShopPurchaseRequest:
	paused = true
	var request := ShopPurchaseRequest.new()
	request.token = lifetime.token()
	request.shop_id = shop_id
	request.offer_id = offer_id
	request.quote_version = quote_version
	request.transaction_id = transaction_id
	request.equipment_session = build.equipment.open_session(request.token)
	request.equipment_revision = int(build.equipment.snapshot().revision)
	return request

func repairs() -> void:
	await fresh()
	check(own(&"B30") and equip([&"B30"]), "repair fixture equips actual fragile heart")
	var owned := build.inventory.instance_for_definition(&"B30")
	check(build.inventory.patch_effect_state(owned.instance_id, {"broken": true, "damage_hits": 3}, &"broken_fixture") and build.refresh_equipped(), "broken fixture revokes actual max-health source")
	var health := actor.actor_resources.health
	var old_hp := health.current
	wallet.balance = 30
	var shop := ShopService.new()
	shop.configure(lifetime, build, wallet)
	var quote := shop.repair_quote(owned.instance_id)
	var request := request_for(owned.instance_id, int(quote.quote_version), &"repair_1")
	check(quote.available and int(quote.price) == 18 and shop.purchase_repair(request).accepted(), "fragile heart repairs for exact data-defined eighteen coins")
	check(wallet.balance == 12 and health.capacity == 8 and health.current == old_hp and not bool(host.state(&"B30").broken) and int(host.state(&"B30").damage_hits) == 0, "repair restores maximum only, resets cracks, does not heal")
	check(shop.purchase_repair(request).status == EconomyReceipt.Status.REPLAY and wallet.balance == 12, "same repair transaction replay does not debit twice")
	request.quantity = 2
	check(shop.purchase_repair(request).status == EconomyReceipt.Status.CONFLICT and wallet.balance == 12, "repair transaction payload conflict cannot mutate a committed receipt")
	paused = false
	check(build.inventory.patch_effect_state(owned.instance_id, {"broken": true, "damage_hits": 3}, &"broken_again") and build.refresh_equipped(), "same held instance can break again")
	quote = shop.repair_quote(owned.instance_id)
	request = request_for(owned.instance_id, int(quote.quote_version), &"repair_insufficient")
	var before := build.inventory.effect_state(owned.instance_id)
	var revision := build.inventory.revision
	check(shop.purchase_repair(request).status == EconomyReceipt.Status.INSUFFICIENT and wallet.balance == 12 and build.inventory.effect_state(owned.instance_id) == before and build.inventory.revision == revision, "insufficient repair rolls back nothing and leaves cracks/revision untouched")
	wallet.balance = 30
	request = request_for(owned.instance_id, int(quote.quote_version), &"repair_rejected_effect")
	(build as RejectingBuild).reject_refresh = true
	check(shop.purchase_repair(request).status == EconomyReceipt.Status.UNAVAILABLE and wallet.balance == 30 and build.inventory.effect_state(owned.instance_id) == before and build.inventory.revision == revision, "effect failure restores exact owned transaction snapshot and refunds coins")
	(build as RejectingBuild).reject_refresh = false
	request = request_for(owned.instance_id, int(shop.repair_quote(owned.instance_id).quote_version), &"repair_stale")
	build.equipment.close_session()
	check(shop.purchase_repair(request).status == EconomyReceipt.Status.STALE and wallet.balance == 30, "closed equipment session invalidates a repair callback")
	paused = false

func catalog_pool() -> Array[ItemDefinition]:
	var items: Array[ItemDefinition] = []
	for id: StringName in [&"B01", &"B03", &"B05", &"B07", &"B08", &"B11", &"P05", &"P09", &"P26", &"G01", &"G02", &"G03"]:
		items.append(ItemCatalogV5.get_item(id))
	return items

func rerolls() -> void:
	await fresh()
	check(own(&"G12") and equip([&"G12"]), "luck die is actually owned and equipped")
	var shop := ShopService.new()
	shop.configure(lifetime, build, wallet)
	wallet.balance = 30
	var weights := {"blue": 70, "purple": 25, "gold": 5}
	var dice := host.effect(&"G12")
	check(ShopService.adjusted_rarity_weights(weights, dice) == {"blue": 56, "purple": 35, "gold": 9}, "luck die transfers fourteen points from blue, preserving one hundred total")
	check(ShopService.adjusted_rarity_weights({"blue": 3, "purple": 90, "gold": 7}, dice).is_empty(), "invalid negative blue probability rejects rather than silently clamps")
	var stock := shop.register_catalog_shop(&"demo_shop", host.map, "v5-shop-seed", catalog_pool(), weights, 5, 3, dice)
	check(not stock.is_empty() and stock.offers.size() == 3 and stock.weights == {"blue": 56, "purple": 35, "gold": 9}, "initial shop freezes three legal offers and adjusted rarity weights")
	check(shop.register_catalog_shop(&"demo_shop", host.map, "v5-shop-seed", catalog_pool(), weights, 5, 3, dice) == stock, "reopening existing shop returns exact manifest rather than advancing random stream")
	var quote := shop.reroll_quote(&"demo_shop", host.map, dice)
	var request := request_for(quote.offer_id, int(quote.quote_version), &"reroll_free")
	check(int(quote.price) == 0 and shop.reroll_catalog_shop(request, host.map, catalog_pool(), dice).accepted() and wallet.balance == 30, "only first actual map reroll with equipped die is free")
	var frozen := shop.reroll_receipt_snapshot(request.transaction_id)
	check(shop.reroll_catalog_shop(request, host.map, [], dice).status == EconomyReceipt.Status.REPLAY and shop.reroll_receipt_snapshot(request.transaction_id) == frozen, "same reroll transaction returns its frozen result even if caller pool later changes")
	var old_quote := shop.quote(stock.offers[0].offer_id)
	check(old_quote.stock == 0 and old_quote.quote_version == 2, "superseded stock invalidates stale old-price buttons")
	quote = shop.reroll_quote(&"demo_shop", host.map, dice)
	check(int(quote.price) == 5 and not bool(quote.free), "second map reroll returns to explicit configured paid price")
	request = request_for(quote.offer_id, int(quote.quote_version), &"reroll_paid")
	check(shop.reroll_catalog_shop(request, host.map, catalog_pool(), dice).accepted() and wallet.balance == 25, "paid reroll debits once after legal generation plan")
	var current := shop.catalog_shop_snapshot(&"demo_shop", host.map)
	quote = shop.reroll_quote(&"demo_shop", host.map, dice)
	request = request_for(quote.offer_id, int(quote.quote_version), &"reroll_invalid_pool")
	check(shop.reroll_catalog_shop(request, host.map, [], dice).status == EconomyReceipt.Status.UNAVAILABLE and wallet.balance == 25 and shop.catalog_shop_snapshot(&"demo_shop", host.map) == current, "generation failure preserves coins, old stock and random generation")
	wallet.balance = 0
	request = request_for(quote.offer_id, int(quote.quote_version), &"reroll_insufficient")
	check(shop.reroll_catalog_shop(request, host.map, catalog_pool(), dice).status == EconomyReceipt.Status.INSUFFICIENT and shop.catalog_shop_snapshot(&"demo_shop", host.map) == current, "insufficient coins cannot advance stock or stream")
	paused = false
	check(equip([]), "luck die can be unloaded")
	check(not shop.reroll_quote(&"demo_shop", host.map, dice).get("available", false), "unloaded die parameters cannot be forged into a free quote")
	check(shop.register_catalog_shop(&"demo_shop", host.map, "v5-shop-seed", catalog_pool(), weights, 5, 3) == current, "reopening without die does not rewrite frozen earlier offers")

func _run() -> void:
	await bonus_and_remainder()
	await bonus_rollback()
	await idle_budget()
	await magnet_policy()
	await repairs()
	await rerolls()
	paused = false
	if fixture != null and is_instance_valid(fixture.world): fixture.world.free()
	print("ITEM V5 ECONOMY: %s checks, %s failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
