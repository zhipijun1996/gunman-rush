extends SceneTree
## Exercise the existing service transaction owner with the pinned world price.
## Ownership/funds are fixture inputs; this does not import web player progress.

class Storage extends WorldSaveService:
	var payload := {}
	var revision := 0
	var commits := 0
	var writable := true

	func commit(candidate: Dictionary, next_revision: int) -> bool:
		if not writable or next_revision != revision + 1: return false
		payload = candidate.duplicate(true)
		revision = next_revision
		commits += 1
		return true

var failures := 0
var checks := 0
var world_upgrade_total := 0
var independent_upgrade_total := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func fixture(id: String, gold: int, catalog: WorldContentCatalog = null) -> WorldServices:
	var services := WorldServices.new()
	services.state = FixedWorldState.new()
	services.state.content = FixedWorldProvider.new()
	services.state.content.data = {
		"rooms":{"economy_test":{"doors":[]}},"actions":[],
		"start_room":"economy_test","start_point":[0,0],
		"content_version":("content-channel-economy:" + (catalog.bundle_sha256 if catalog != null else "independent")).sha256_text()
	}
	services.state.storage = Storage.new()
	services.state.value = services.state.fresh(3.0)
	services.state.value.services.gold = gold
	if not id.is_empty(): services.state.value.services.owned[id] = 1
	services.content_catalog = catalog
	services.can_access = func(_kind: String, _id: String) -> bool: return true
	return services

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var catalog := WorldContentCatalog.new()
	var loaded := catalog.load_locked()
	check(loaded.ok, "pinned economy loads")
	if not loaded.ok:
		finish()
		return
	var quoted := fixture("", 0, catalog)
	var independent := fixture("", 0)
	var selected := ""
	for item: Dictionary in catalog.table("equipment").rows:
		var native := EquipmentCatalog.item(item.id)
		if native.is_empty() or int(native.max_level) < 2 or int(item.max_level) < 2: continue
		if selected.is_empty(): selected = item.id
		for target: int in range(2, mini(int(native.max_level), int(item.max_level)) + 1):
			var expected := int(item.upgrade_prices[str(target)])
			var offer := quoted.equipment_upgrade_quote(item.id, target)
			check(offer.ok and offer.price == expected and offer.bundle_sha256 == catalog.bundle_sha256,
				"world quote follows pinned target-level price: " + item.id + ":" + str(target))
			var local := independent.equipment_upgrade_quote(item.id, target)
			check(local.ok and local.price == int(native.upgrade_prices[target - 2]),
				"independent room keeps local price: " + item.id + ":" + str(target))
			world_upgrade_total += expected
			independent_upgrade_total += int(native.upgrade_prices[target - 2])
	check(not selected.is_empty(), "at least one implemented upgrade is available")
	if selected.is_empty():
		finish()
		return
	var price := int(catalog.upgrade_quote(selected, 2).price)
	var services := fixture(selected, price + 17, catalog)
	check(services.state.valid(services.state.value), "fixture obeys real ledger validation")
	var revision := services.state.revision
	check(services.transact("upgrade", selected, "paid_once", revision), "world upgrade commits")
	var storage := services.state.storage as Storage
	check(services.ledger().gold == 17 and services.ledger().owned[selected] == 2
		and storage.payload.services.gold == 17 and storage.payload.services.owned[selected] == 2,
		"one transaction commits the imported price and level together")
	check(services.state.revision == revision + 1 and storage.commits == 1, "one durable commit")
	check(services.transact("upgrade", selected, "paid_once", revision), "duplicate receipt is acknowledged")
	check(services.ledger().gold == 17 and services.ledger().owned[selected] == 2
		and services.state.revision == revision + 1 and storage.commits == 1,
		"duplicate receipt never charges or upgrades twice")
	check(not services.transact("upgrade", "unknown_equipment", "paid_once", revision), "receipt cannot change identity")

	var short_funds := fixture(selected, price - 1, catalog)
	var before := short_funds.state.value.duplicate(true)
	check(not short_funds.transact("upgrade", selected, "too_poor", 0), "insufficient imported-price funds refused")
	check(short_funds.state.value == before and short_funds.state.revision == 0,
		"insufficient funds leave price, level and receipts unchanged")
	check(not short_funds.equipment_upgrade_quote("unknown_equipment", 2).ok
		and not short_funds.transact("upgrade", "unknown_equipment", "unknown", 0), "unknown equipment refused")
	check(short_funds.state.value == before, "unknown equipment makes no ledger mutation")
	check(not quoted.equipment_upgrade_quote(selected, 1).ok, "invalid target level refused")

	var unavailable := fixture(selected, price, WorldContentCatalog.new())
	before = unavailable.state.value.duplicate(true)
	check(not unavailable.equipment_upgrade_quote(selected, 2).ok
		and not unavailable.transact("upgrade", selected, "unavailable", 0), "bound catalog failure never uses a local price")
	check(unavailable.error == "content_not_loaded" and unavailable.state.value == before,
		"catalog error is explicit and preserves the ledger")

	var failed_save := fixture(selected, price, catalog)
	(failed_save.state.storage as Storage).writable = false
	before = failed_save.state.value.duplicate(true)
	check(not failed_save.transact("upgrade", selected, "failed_save", 0)
		and failed_save.state.value == before and failed_save.state.revision == 0,
		"failed save rolls back world price and level")

	var local_price := int(EquipmentCatalog.item(selected).upgrade_prices[0])
	var local_service := fixture(selected, local_price)
	check(local_service.transact("upgrade", selected, "local", 0)
		and local_service.ledger().gold == 0 and local_service.ledger().owned[selected] == 2,
		"unbound ordinary room transaction keeps static price")
	var reward_source: String = EquipmentCatalog.REWARDS.data.keys()[0]
	var world_claim := fixture("", 0, catalog)
	before = world_claim.state.value.duplicate(true)
	check(not world_claim.transact("claim", reward_source, "world_legacy_claim", 0)
		and world_claim.error == "channel_reward_binding_unsupported" and world_claim.state.value == before,
		"world-bound legacy claim cannot bypass content rewards or shop prices")
	var local_claim := fixture("", 0)
	check(local_claim.transact("claim", reward_source, "local_claim", 0)
		and local_claim.ledger().owned.has(EquipmentCatalog.REWARDS.data[reward_source]),
		"independent room legacy claim remains available")

	check_menu(fixture(selected, price, catalog), selected, price, false)
	check_menu(short_funds, selected, price, true)
	check_menu(unavailable, selected, -1, true)
	finish()

func check_menu(services: WorldServices, id: String, expected_price: int, disabled: bool) -> void:
	var host := OrdinaryRoomSession.new()
	host.services = services
	host.state = services.state
	var menu := EquipmentMenu.new()
	menu.session = host
	root.add_child(menu)
	menu.mode = "smith"
	menu.selected = id
	menu.show_detail()
	check(menu.apply.disabled == disabled, "menu affordability uses the same quote")
	if expected_price >= 0:
		check(menu.apply.text == "强化至 Lv2 · %d 金币" % expected_price, "menu displays actual transaction price")
	else:
		check(menu.apply.text == "强化不可用", "menu shows unavailable quote without static fallback")
	menu.free()
	host.free()

func finish() -> void:
	print(JSON.stringify({"world_upgrade_total":world_upgrade_total,"independent_upgrade_total":independent_upgrade_total,"checks":checks,"failures":failures}))
	print("CONTENT CHANNEL ECONOMY failures=", failures)
	quit(1 if failures else 0)
