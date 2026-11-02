class_name HomeItemCatalog
extends RefCounted
## Read-only Home policy layered over the existing Definition database.
## Profile ownership never lives in this cache; every returned item is detached.
const CONFIG_PATH := "res://config/home_items.json"
const RARITIES := ["BLUE", "PURPLE", "GOLD"]
var policy_path: String
var _signature := ""
var _policy: Dictionary = {}

func _init(path: String = CONFIG_PATH) -> void:
	policy_path = path

static func item(id: StringName) -> ItemDefinition:
	return ItemCatalogV5.get_item(id) if valid_id(id) else null

static func valid_id(value: Variant) -> bool:
	if not (value is String or value is StringName) or String(value).is_empty(): return false
	var text := String(value)
	for index: int in text.length():
		var code := text.unicode_at(index)
		if code == 95 or (code >= 65 and code <= 90) or (code >= 97 and code <= 122): continue
		if index > 0 and code >= 48 and code <= 57: continue
		return false
	return true

func ready() -> bool:
	return not _read_policy().is_empty()

func version() -> int:
	return int(_read_policy().get("version", 0))

func entry(id: StringName) -> Dictionary:
	return _entry(id, item(id), _read_policy())

func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var policy := _read_policy()
	if policy.is_empty(): return result
	# One catalogue enumeration per view; no per-card database reload or live refs.
	for definition: ItemDefinition in ItemCatalogV5.all_items():
		result.append(_entry(definition.stable_id, definition, policy))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.id) < String(b.id))
	return result

func _entry(id: StringName, definition: ItemDefinition, policy: Dictionary) -> Dictionary:
	var result := {"id":String(id), "item":definition, "price":0, "home_enabled":false,
		"reason":"unknown_item", "requires_discovered":true, "policy_version":0, "policy_fingerprint":""}
	if definition == null or not definition.is_valid() or definition.catalog_version != 5: return result
	if policy.is_empty():
		result.reason = "home_policy_unavailable"
		return result
	var override: Dictionary = policy.items.get(String(id), {})
	result.price = int(override.get("unlock_notes", policy.default_note_prices[RARITIES[definition.rarity]]))
	result.requires_discovered = bool(policy.requires_discovered)
	result.policy_version = int(policy.version)
	result.policy_fingerprint = _signature
	if definition.appearance_weight <= 0:
		result.reason = "item_disabled"
	elif String(id) in policy.home_enabled_blacklist or not bool(override.get("home_enabled", true)):
		result.reason = "home_item_disabled"
	else:
		result.home_enabled = true
		result.reason = ""
	return result

func _read_policy() -> Dictionary:
	if policy_path.is_empty() or not FileAccess.file_exists(policy_path): return {}
	var signature := FileAccess.get_sha256(policy_path)
	if signature == _signature: return _policy
	# Invalid authored data is an expected refusal, not an engine diagnostic.
	# Still cache the empty result for these exact bytes: never reuse old policy.
	var parser := JSON.new()
	var parsed: Variant = null
	if parser.parse(FileAccess.get_file_as_string(policy_path)) == OK:
		parsed = parser.data
	var candidate: Dictionary = parsed if parsed is Dictionary else {}
	if not _valid_policy(candidate): candidate = {}
	if signature != FileAccess.get_sha256(policy_path): return {}
	_signature = signature
	_policy = candidate.duplicate(true)
	return _policy

static func _whole(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high and float(value) == floor(float(value))

static func _valid_policy(policy: Dictionary) -> bool:
	if policy.size() != 6 or not _whole(policy.get("schema_version"),1,1) or not _whole(policy.get("version"),1,2147483647): return false
	if not policy.get("requires_discovered") is bool or not policy.get("default_note_prices") is Dictionary or not policy.get("items") is Dictionary or not policy.get("home_enabled_blacklist") is Array: return false
	if policy.default_note_prices.size() != RARITIES.size(): return false
	for rarity: String in RARITIES:
		if not _whole(policy.default_note_prices.get(rarity),1,1000000000): return false
	for key: Variant in policy.items:
		if not valid_id(key) or not policy.items[key] is Dictionary: return false
		var override: Dictionary = policy.items[key]
		if override.is_empty(): return false
		for field: Variant in override:
			if field == "unlock_notes":
				if not _whole(override[field],1,1000000000): return false
			elif field == "home_enabled":
				if not override[field] is bool: return false
			else: return false
	var seen: Array[String] = []
	for key: Variant in policy.home_enabled_blacklist:
		if not valid_id(key) or String(key) in seen: return false
		seen.append(String(key))
	return true
