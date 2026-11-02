class_name MetaProgression
extends RefCounted

const UPGRADE_CONFIG := "res://config/meta_upgrades.json"
var _settled: Dictionary = {}
var _completed_runs := 0
var _failed_runs := 0
var _completed_biomes := 0
var _last_summary: Dictionary = {}
var _notes := 0
var _upgrades: Dictionary = {}
var _discovered_items: Dictionary = {}
var _unlocked_home_items: Dictionary = {}
var _selected_home_item := ""
var _receipts: Dictionary = {}
var _revision := 0
var _save: MetaSaveService
var _definitions: Dictionary = {}
var _ready := true
var _home_items: HomeItemCatalog
var _profile_epoch := 0

func _init(home_policy_path: String = HomeItemCatalog.CONFIG_PATH) -> void:
	_home_items = HomeItemCatalog.new(home_policy_path)
	var content: Variant = JSON.parse_string(FileAccess.get_file_as_string(UPGRADE_CONFIG))
	if content is Dictionary:
		_definitions = content.get("upgrades", {}).duplicate(true)

func configure_persistence(path: String = "user://plains_meta.json", use_web: bool = OS.has_feature("web"), profile_id: String = "local") -> Dictionary:
	# Switching a profile on an existing owner must not leak the previous slot.
	_profile_epoch += 1
	_ready = false
	_restore(_empty_payload())
	_revision = 0
	_save = MetaSaveService.new()
	_save.configure(path, use_web, profile_id)
	var result := _save.load_profile()
	_ready = result.get("accepted", false)
	if _ready and not result.payload.is_empty():
		_ready = _valid_payload(result.payload)
		if _ready:
			var payload: Dictionary = result.payload
			if int(result.get("source_schema_version",MetaSaveService.SCHEMA_VERSION)) < 3:
				payload = _migrate_known_discoveries(payload)
			_restore(payload)
			_revision = result.revision
		else:
			_save.blocked = true
			_save.status = "invalid_profile"
	return {"accepted": _ready, "reason": _save.status}

func profile_context_id() -> String:
	# Distinguish even two reloads of the same slot/revision. Presentation and
	# pending ownership records cannot silently migrate to a different profile.
	return "%s/%s" % [get_instance_id(), _profile_epoch]

func new_run_receipt_prefix() -> String:
	return "run_" + Crypto.new().generate_random_bytes(16).hex_encode()

func grant_notes(amount: int, receipt_id: StringName) -> Dictionary:
	return _transaction(receipt_id, {"kind": "notes", "amount": amount})

func purchase_upgrade(upgrade_id: StringName, transaction_id: StringName) -> Dictionary:
	return _transaction(transaction_id, {"kind": "upgrade", "upgrade_id": str(upgrade_id)})

# Call only after an actual COMMITTED ownership transaction. Presentation,
# inventory loads, repairs and quote/view operations must never call this API.
func discover_item(item_id: StringName, receipt_id: StringName) -> Dictionary:
	return _transaction(receipt_id,{"kind":"item_discovery","item_id":String(item_id)})

func unlock_home_item(item_id: StringName, transaction_id: StringName, expected_revision: int = -1, quote_fingerprint: String = "") -> Dictionary:
	return _transaction(transaction_id,{"kind":"home_unlock","item_id":String(item_id),"expected_revision":expected_revision,"quote_fingerprint":quote_fingerprint})

func select_home_item(item_id: StringName, transaction_id: StringName, expected_revision: int = -1) -> Dictionary:
	return _transaction(transaction_id,{"kind":"home_select","item_id":String(item_id),"expected_revision":expected_revision})

func home_item_quote(item_id: StringName) -> Dictionary:
	return _home_quote(_home_items.entry(item_id))

func home_item_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _home_items.entries(): result.append(_home_quote(entry))
	return result

func home_items_snapshot() -> Dictionary:
	return {"rows":home_item_rows(),"notes":_notes,"profile_revision":_revision,"selected_home_item":_selected_home_item,"available":_ready and _home_items.ready(),"reason":"" if _ready and _home_items.ready() else "home_policy_unavailable" if _ready else "profile_unavailable"}

func _home_quote(entry: Dictionary) -> Dictionary:
	var id := String(entry.id)
	var discovered := _discovered_items.has(id)
	var unlocked := _unlocked_home_items.has(id)
	var can_select := _ready and bool(entry.home_enabled) and unlocked
	var can_unlock := _ready and bool(entry.home_enabled) and not unlocked and (not bool(entry.requires_discovered) or discovered) and _notes >= int(entry.price)
	var reason := String(entry.reason)
	if not _ready: reason = "profile_unavailable"
	elif not bool(entry.home_enabled): pass
	elif unlocked: reason = ""
	elif bool(entry.requires_discovered) and not discovered: reason = "requires_discovered"
	elif _notes < int(entry.price): reason = "insufficient_notes"
	else: reason = ""
	var definition: ItemDefinition = entry.item as ItemDefinition
	var quote_fingerprint := JSON.stringify([id,definition.fingerprint() if definition != null else "",entry.policy_fingerprint,_revision,_notes,discovered,unlocked,entry.price,entry.requires_discovered,entry.home_enabled],"",true).sha256_text()
	return {"id":id,"item":definition,"discovered":discovered,"unlocked":unlocked,"price":int(entry.price),"price_notes":int(entry.price),"available":can_select if unlocked else can_unlock,"reason":reason,"selected":id == _selected_home_item and not id.is_empty(),"can_unlock":can_unlock,"can_select":can_select,"home_enabled":bool(entry.home_enabled),"profile_revision":_revision,"quote_fingerprint":quote_fingerprint,"policy_version":int(entry.policy_version),"requires_discovered":bool(entry.requires_discovered)}

func upgrade_quote(upgrade_id: StringName = &"vitality") -> Dictionary:
	var definition: Dictionary = _definitions.get(str(upgrade_id), {})
	if definition.is_empty():
		return {"available": false, "reason": "unknown_upgrade"}
	var level := int(_upgrades.get(str(upgrade_id), 0))
	var capped := level >= int(definition.max_level)
	return {"available": not capped, "level": level, "max_level": int(definition.max_level), "price": 0 if capped else int(definition.prices[level]), "stat": definition.stat, "per_level": definition.per_level}

func fresh_health_definition(base: HealthDefinition) -> HealthDefinition:
	if base == null:
		return null
	var result := base.duplicate(true) as HealthDefinition
	var extra := 0.0
	for upgrade_id: String in _upgrades:
		var definition: Dictionary = _definitions.get(upgrade_id, {})
		if definition.get("stat", "") == "max_health":
			extra += float(definition.per_level) * int(_upgrades[upgrade_id])
	result.max_health += extra
	result.initial_current += extra
	return result

func settle(end_id: StringName, success: bool, summary: Dictionary) -> bool:
	return _settlement(end_id, {"success": success, "summary": summary.duplicate(true)}, "completed_runs" if success else "failed_runs")

func settle_biome(end_id: StringName, summary: Dictionary) -> bool:
	return _settlement(end_id, {"reason": "biome_complete", "summary": summary.duplicate(true)}, "completed_biomes")

func snapshot() -> Dictionary:
	return {"completed_runs": _completed_runs, "failed_runs": _failed_runs, "completed_biomes": _completed_biomes, "meta_currency": _notes, "notes": _notes, "upgrades": _upgrades.duplicate(true), "last_summary": _last_summary.duplicate(true), "profile_revision": _revision, "save_status": "memory_only" if _save == null else _save.status,"profile_id":"local" if _save == null else _save.profile_id,"item_progress_version":1,"discovered_items":_sorted_ids(_discovered_items),"unlocked_home_items":_sorted_ids(_unlocked_home_items),"selected_home_item":_selected_home_item}

func _transaction(receipt_id: StringName, request: Dictionary) -> Dictionary:
	var key := str(receipt_id)
	if key.is_empty() or not _ready:
		return {"accepted": false, "reason": "profile_unavailable"}
	if _receipts.has(key):
		return {"accepted": MetaSaveService.canonical_json(_receipts[key]) == MetaSaveService.canonical_json(request), "replayed": true, "reason": "replay" if MetaSaveService.canonical_json(_receipts[key]) == MetaSaveService.canonical_json(request) else "receipt_conflict"}
	if not request.get("kind") is String or request.kind not in ["notes","upgrade","item_discovery","home_unlock","home_select"]:
		return {"accepted":false,"reason":"unknown_kind"}
	if not _valid_request(request): return {"accepted":false,"reason":"invalid_request"}
	var candidate := _payload()
	if request.kind == "notes":
		if int(request.amount) <= 0 or int(request.amount) > 1000000 or _notes > 1000000000 - int(request.amount):
			return {"accepted": false, "reason": "invalid_amount"}
		candidate.notes += int(request.amount)
	elif request.kind == "upgrade":
		var quote := upgrade_quote(StringName(request.upgrade_id))
		if not quote.available:
			return {"accepted": false, "reason": "upgrade_unavailable"}
		if _notes < int(quote.price):
			return {"accepted": false, "reason": "insufficient_notes"}
		candidate.notes -= int(quote.price)
		candidate.upgrades[request.upgrade_id] = int(quote.level) + 1
	elif request.kind == "item_discovery":
		if HomeItemCatalog.item(StringName(request.item_id)) == null: return {"accepted":false,"reason":"unknown_item"}
		if _discovered_items.has(request.item_id): return _unchanged("already_discovered")
		candidate.discovered_items.append(request.item_id)
		candidate.discovered_items.sort()
	elif request.kind == "home_unlock":
		if int(request.expected_revision) >= 0 and int(request.expected_revision) != _revision: return {"accepted":false,"reason":"stale_revision"}
		var quote := home_item_quote(StringName(request.item_id))
		if not String(request.quote_fingerprint).is_empty() and request.quote_fingerprint != quote.quote_fingerprint: return {"accepted":false,"reason":"stale_quote"}
		if not quote.home_enabled: return {"accepted":false,"reason":quote.reason}
		if quote.unlocked: return _unchanged("already_unlocked")
		if not quote.can_unlock: return {"accepted":false,"reason":quote.reason}
		candidate.notes -= int(quote.price)
		candidate.unlocked_home_items.append(request.item_id)
		candidate.unlocked_home_items.sort()
	elif request.kind == "home_select":
		if int(request.expected_revision) >= 0 and int(request.expected_revision) != _revision: return {"accepted":false,"reason":"stale_revision"}
		if not String(request.item_id).is_empty():
			var quote := home_item_quote(StringName(request.item_id))
			if not quote.can_select: return {"accepted":false,"reason":"not_unlocked" if not quote.unlocked and quote.home_enabled else quote.reason}
		if request.item_id == _selected_home_item: return _unchanged("already_selected")
		candidate.selected_home_item = request.item_id
	candidate.receipts[key] = request.duplicate(true)
	if not _commit(candidate):
		return {"accepted": false, "reason": "save_failed"}
	return {"accepted": true, "replayed": false, "reason": "committed", "notes": _notes}

func _unchanged(reason: String) -> Dictionary:
	return {"accepted":true,"replayed":false,"reason":reason,"notes":_notes,"profile_revision":_revision}

func _valid_request(request: Dictionary) -> bool:
	if request.kind == "notes": return request.size() == 2 and request.get("amount") is int
	if request.kind == "upgrade": return request.size() == 2 and request.get("upgrade_id") is String and not String(request.upgrade_id).is_empty()
	if not request.get("item_id") is String: return false
	if request.kind != "home_select" or not String(request.item_id).is_empty():
		if not HomeItemCatalog.valid_id(request.item_id): return false
	if request.kind == "item_discovery": return request.size() == 2
	if not request.get("expected_revision") is int or int(request.expected_revision) < -1: return false
	if request.kind == "home_select": return request.size() == 3
	return request.size() == 4 and request.get("quote_fingerprint") is String and String(request.quote_fingerprint).length() in [0,64]

func _settlement(end_id: StringName, request: Dictionary, counter: String) -> bool:
	var key := str(end_id)
	if key.is_empty() or not _ready:
		return false
	if _settled.has(key):
		return MetaSaveService.canonical_json(_settled[key]) == MetaSaveService.canonical_json(request)
	var candidate := _payload()
	candidate.settled[key] = request.duplicate(true)
	candidate[counter] += 1
	candidate.last_summary = request.summary.duplicate(true)
	return _commit(candidate)

func _payload() -> Dictionary:
	return {"notes": _notes, "upgrades": _upgrades.duplicate(true), "receipts": _receipts.duplicate(true), "settled": _settled.duplicate(true), "completed_runs": _completed_runs, "failed_runs": _failed_runs, "completed_biomes": _completed_biomes, "last_summary": _last_summary.duplicate(true),"item_progress_version":1,"discovered_items":_sorted_ids(_discovered_items),"unlocked_home_items":_sorted_ids(_unlocked_home_items),"selected_home_item":_selected_home_item}

static func _empty_payload() -> Dictionary:
	return {"notes":0,"upgrades":{},"receipts":{},"settled":{},"completed_runs":0,"failed_runs":0,"completed_biomes":0,"last_summary":{},"item_progress_version":1,"discovered_items":[],"unlocked_home_items":[],"selected_home_item":""}

static func _sorted_ids(values: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for id: String in values: result.append(id)
	result.sort()
	return result

func _commit(candidate: Dictionary) -> bool:
	if not _valid_payload(candidate): return false
	if _save != null and not _save.commit(candidate, _revision + 1):
		return false
	_restore(candidate)
	_revision += 1
	return true

func _restore(payload: Dictionary) -> void:
	_notes = int(payload.notes)
	_upgrades = payload.upgrades.duplicate(true)
	_receipts = payload.receipts.duplicate(true)
	_settled = payload.settled.duplicate(true)
	_completed_runs = int(payload.completed_runs)
	_failed_runs = int(payload.failed_runs)
	_completed_biomes = int(payload.completed_biomes)
	_last_summary = payload.last_summary.duplicate(true)
	_discovered_items.clear()
	for id: String in payload.discovered_items: _discovered_items[id] = true
	_unlocked_home_items.clear()
	for id: String in payload.unlocked_home_items: _unlocked_home_items[id] = true
	_selected_home_item = String(payload.selected_home_item)

func _migrate_known_discoveries(payload: Dictionary) -> Dictionary:
	var result := payload.duplicate(true)
	var ids: Dictionary = {}
	for id: String in result.discovered_items: ids[id] = true
	var histories: Array[Dictionary] = [result.last_summary]
	var settled: Dictionary = result.settled
	for value: Variant in settled.values():
		if value is Dictionary and value.get("summary") is Dictionary: histories.append(value.summary)
	for history: Dictionary in histories:
		if not history.get("items") is Array: continue
		for id: Variant in history.items:
			if id is String and HomeItemCatalog.item(StringName(id)) != null: ids[id] = true
	result.discovered_items = _sorted_ids(ids)
	return result

func _valid_payload(payload: Dictionary) -> bool:
	if not (payload.get("item_progress_version") is int or payload.get("item_progress_version") is float) or float(payload.item_progress_version) != 1: return false
	for field: String in ["discovered_items","unlocked_home_items"]:
		if not payload.get(field) is Array: return false
		var seen: Array[String] = []
		for id: Variant in payload[field]:
			if not id is String or not HomeItemCatalog.valid_id(id) or id in seen: return false
			seen.append(id)
	if not payload.get("selected_home_item") is String: return false
	if not String(payload.selected_home_item).is_empty() and payload.selected_home_item not in payload.unlocked_home_items: return false
	for counter: String in ["notes", "completed_runs", "failed_runs", "completed_biomes"]:
		if not payload.get(counter) is float and not payload.get(counter) is int:
			return false
		if float(payload[counter]) != int(payload[counter]) or int(payload[counter]) < 0:
			return false
	for map: String in ["upgrades", "receipts", "settled", "last_summary"]:
		if not payload.get(map) is Dictionary:
			return false
	for upgrade_id: String in payload.upgrades:
		if not payload.upgrades[upgrade_id] is int and not payload.upgrades[upgrade_id] is float:
			return false
		var definition: Dictionary = _definitions.get(upgrade_id, {})
		if definition.is_empty() or float(payload.upgrades[upgrade_id]) != int(payload.upgrades[upgrade_id]) or int(payload.upgrades[upgrade_id]) < 0 or int(payload.upgrades[upgrade_id]) > int(definition.max_level):
			return false
	for ledger: String in ["receipts", "settled"]:
		for key: Variant in payload[ledger]:
			if not key is String or key.is_empty() or not payload[ledger][key] is Dictionary:
				return false
	return int(payload.notes) <= 1000000000
