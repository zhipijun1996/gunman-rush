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
var _receipts: Dictionary = {}
var _revision := 0
var _save: MetaSaveService
var _definitions: Dictionary = {}
var _ready := true

func _init() -> void:
	var content: Variant = JSON.parse_string(FileAccess.get_file_as_string(UPGRADE_CONFIG))
	if content is Dictionary:
		_definitions = content.get("upgrades", {}).duplicate(true)

func configure_persistence(path: String = "user://plains_meta.json", use_web: bool = OS.has_feature("web")) -> Dictionary:
	_save = MetaSaveService.new()
	_save.configure(path, use_web)
	var result := _save.load_profile()
	_ready = result.get("accepted", false)
	if _ready and not result.payload.is_empty():
		_ready = _valid_payload(result.payload)
		if _ready:
			_restore(result.payload)
			_revision = result.revision
		else:
			_save.blocked = true
			_save.status = "invalid_profile"
	return {"accepted": _ready, "reason": _save.status}

func new_run_receipt_prefix() -> String:
	return "run_" + Crypto.new().generate_random_bytes(16).hex_encode()

func grant_notes(amount: int, receipt_id: StringName) -> Dictionary:
	return _transaction(receipt_id, {"kind": "notes", "amount": amount})

func purchase_upgrade(upgrade_id: StringName, transaction_id: StringName) -> Dictionary:
	return _transaction(transaction_id, {"kind": "upgrade", "upgrade_id": str(upgrade_id)})

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
	return {"completed_runs": _completed_runs, "failed_runs": _failed_runs, "completed_biomes": _completed_biomes, "meta_currency": _notes, "notes": _notes, "upgrades": _upgrades.duplicate(true), "last_summary": _last_summary.duplicate(true), "profile_revision": _revision, "save_status": "memory_only" if _save == null else _save.status}

func _transaction(receipt_id: StringName, request: Dictionary) -> Dictionary:
	var key := str(receipt_id)
	if key.is_empty() or not _ready:
		return {"accepted": false, "reason": "profile_unavailable"}
	if _receipts.has(key):
		return {"accepted": MetaSaveService.canonical_json(_receipts[key]) == MetaSaveService.canonical_json(request), "replayed": true, "reason": "replay" if MetaSaveService.canonical_json(_receipts[key]) == MetaSaveService.canonical_json(request) else "receipt_conflict"}
	var candidate := _payload()
	if request.kind == "notes":
		if int(request.amount) <= 0 or int(request.amount) > 1000000 or _notes > 1000000000 - int(request.amount):
			return {"accepted": false, "reason": "invalid_amount"}
		candidate.notes += int(request.amount)
	else:
		var quote := upgrade_quote(StringName(request.upgrade_id))
		if not quote.available:
			return {"accepted": false, "reason": "upgrade_unavailable"}
		if _notes < int(quote.price):
			return {"accepted": false, "reason": "insufficient_notes"}
		candidate.notes -= int(quote.price)
		candidate.upgrades[request.upgrade_id] = int(quote.level) + 1
	candidate.receipts[key] = request.duplicate(true)
	if not _commit(candidate):
		return {"accepted": false, "reason": "save_failed"}
	return {"accepted": true, "replayed": false, "reason": "committed", "notes": _notes}

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
	return {"notes": _notes, "upgrades": _upgrades.duplicate(true), "receipts": _receipts.duplicate(true), "settled": _settled.duplicate(true), "completed_runs": _completed_runs, "failed_runs": _failed_runs, "completed_biomes": _completed_biomes, "last_summary": _last_summary.duplicate(true)}

func _commit(candidate: Dictionary) -> bool:
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

func _valid_payload(payload: Dictionary) -> bool:
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
