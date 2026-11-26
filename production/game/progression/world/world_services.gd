class_name WorldServices
extends RefCounted
## Permanent service domain. Candidates use the same durable world revision as HP/facts.
var state: FixedWorldState
var definitions: Dictionary
var content_catalog: WorldContentCatalog
var error := ""
var can_access: Callable
var stage_resources: Callable

static func empty_ledger() -> Dictionary:
	return {"version":2,"gold":0,"drops":{},"owned":{},"equipped":[],"selected":"","claimed":{},"effects":{}}

static func normalize(old: Dictionary) -> Dictionary:
	if old.get("version") != 1: return old
	if not old.get("owned",{}) is Dictionary or not old.get("equipped",[]) is Array or not old.get("drops",{}) is Dictionary: return {}
	var result := empty_ledger()
	result.gold = old.get("gold", 0)
	result.drops = old.get("drops", {}).duplicate(true)
	for id: Variant in old.get("owned", {}):
		if not id is String or not old.owned[id] is Dictionary or not WorldRoomValidation.number(old.owned[id].get("level")): return {}
		var definition := EquipmentCatalog.item(id)
		if definition.is_empty(): continue
		result.owned[id] = clampi(int(old.owned[id].level), 1, int(definition.max_level))
	for id: Variant in old.get("equipped", []):
		if not id is String: return {}
		if EquipmentCatalog.legal_loadout(result.owned, result.equipped + [id], int(EquipmentCatalog.DATA.data.initial_capacity)):
			result.equipped.append(id)
	return result

static func valid_ledger(value: Dictionary) -> bool:
	if value.get("version") != 2: return false
	for key: String in ["owned", "effects", "claimed", "drops"]:
		if not value.get(key) is Dictionary: return false
	if not value.get("equipped") is Array or not value.get("selected") is String: return false
	if not WorldRoomValidation.number(value.get("gold")) or value.gold < 0 or floorf(value.gold) != value.gold: return false
	for id: Variant in value.owned:
		if not id is String or EquipmentCatalog.item(id).is_empty(): return false
		var level: Variant = value.owned[id]
		if not WorldRoomValidation.number(level) or floorf(level) != level or level < 1 or level > EquipmentCatalog.item(id).max_level: return false
	for source: Variant in value.claimed:
		if value.claimed[source] != true or not EquipmentCatalog.REWARDS.data.has(source) or not value.owned.has(EquipmentCatalog.REWARDS.data[source]): return false
	if value.selected != "" and (value.selected not in value.equipped or not EquipmentCatalog.item(value.selected).get("active", false)): return false
	for id: Variant in value.get("drops",{}):
		var drop: Variant=value.drops[id]
		if not id is String or not drop is Dictionary or drop.get("id")!=id or drop.get("kind")!="coin" or not drop.get("room") is String: return false
		if not (drop.get("amount") is int or drop.get("amount") is float) or not is_finite(drop.amount) or drop.amount<=0 or floorf(drop.amount)!=drop.amount: return false
		for field: String in ["position","velocity","safe"]:
			if not drop.get(field) is Array or drop[field].size()!=2: return false
			for value_at: Variant in drop[field]:
				if not (value_at is int or value_at is float) or not is_finite(value_at): return false
		if not drop.get("source") is String: return false
		for field: String in ["age","bounces","rotation"]:
			if not (drop.get(field) is int or drop.get(field) is float) or not is_finite(drop[field]): return false
		if drop.age<0 or drop.bounces<0 or floorf(drop.bounces)!=drop.bounces: return false
		for field: String in ["claimed","settled","returning"]:
			if not drop.get(field) is bool: return false
		if drop.claimed: return false
	return EquipmentCatalog.valid_effects(value.effects) and EquipmentCatalog.legal_loadout(value.owned, value.equipped, int(EquipmentCatalog.DATA.data.maximum_capacity))

func ledger() -> Dictionary:
	return state.value.services

func level(id: String) -> int:
	return int(ledger().owned[id]) if id in ledger().equipped else 0

func active(id: String) -> bool:
	return level(id) > 0

func capacity() -> int:
	return EquipmentCatalog.capacity(state.value.inventory)

func equipment_upgrade_quote(id: String, target_level: int) -> Dictionary:
	# A pinned world owns its prices. A missing/invalid content quote must never
	# silently switch the transaction back to independent-room fixture prices.
	if content_catalog != null: return content_catalog.upgrade_quote(id, target_level)
	var definition := EquipmentCatalog.item(id)
	if definition.is_empty(): return {"ok":false,"error":"equipment_id_unknown","equipment_id":id}
	var prices: Variant = definition.get("upgrade_prices")
	if target_level < 2 or target_level > int(definition.max_level) or not prices is Array or target_level - 2 >= prices.size():
		return {"ok":false,"error":"upgrade_target_invalid","equipment_id":id,"target_level":target_level}
	var price: Variant = prices[target_level - 2]
	if not WorldRoomValidation.number(price) or price <= 0 or floorf(price) != price:
		return {"ok":false,"error":"equipment_upgrade_price_invalid","equipment_id":id,"target_level":target_level}
	return {"ok":true,"equipment_id":id,"target_level":target_level,"price":int(price),"bundle_sha256":""}

func transact(kind: String, id: String, receipt: String, expected_revision: int) -> bool:
	error = ""
	# Existing local reward sources have no world reward/shop binding yet.
	if content_catalog != null and kind == "claim":
		error = "channel_reward_binding_unsupported"
		return false
	if receipt.is_empty(): return false
	var key := "equipment:" + receipt
	var fingerprint := JSON.stringify([kind,id]).sha256_text()
	if state.value.receipts.has(key): return state.value.receipts[key].source_hash == fingerprint
	if expected_revision != state.revision or not can_access.is_valid() or not can_access.call(kind, id): return false
	var candidate := state.candidate()
	var gear: Dictionary = candidate.services
	var definition := EquipmentCatalog.item(id)
	match kind:
		"claim":
			var reward: String = EquipmentCatalog.REWARDS.data.get(id, "")
			if reward.is_empty() or gear.claimed.has(id): return false
			gear.claimed[id] = true
			if not gear.owned.has(reward): gear.owned[reward] = 1
		"equip":
			if not EquipmentCatalog.legal_loadout(gear.owned, gear.equipped + [id], capacity()): return false
			gear.equipped.append(id)
			if definition.get("active", false) and gear.selected == "": gear.selected = id
		"unequip":
			if id not in gear.equipped: return false
			gear.equipped.erase(id)
			if gear.selected == id: gear.selected = ""
		"select":
			if id not in gear.equipped or not definition.get("active", false): return false
			gear.selected = id
		"upgrade":
			var current := int(gear.owned.get(id, 0))
			if definition.is_empty() or current < 1 or current >= definition.max_level: return false
			var quoted := equipment_upgrade_quote(id, current + 1)
			if not quoted.get("ok", false):
				error = str(quoted.get("error", "equipment_upgrade_quote_failed"))
				return false
			var price := int(quoted.price)
			if gear.gold < price: return false
			gear.gold -= price
			gear.owned[id] = current + 1
		"rest":
			candidate.cycle += 1
		_: return false
	if stage_resources.is_valid(): stage_resources.call(candidate, kind, id)
	candidate.receipts[key] = {"source":key,"source_hash":fingerprint,"revision":state.revision + 1}
	return state.commit(candidate, expected_revision)

func earned_candidate(candidate: Dictionary,id: String,amount: int) -> Dictionary:
	var key:="income:"+id
	if candidate.receipts.has(key): return candidate
	if not candidate.has("services"): candidate.services=ledger().duplicate(true)
	candidate.services.gold+=amount
	candidate.receipts[key]={"source":key,"source_hash":str(amount).sha256_text(),"revision":state.revision+1}
	return candidate
func drop_candidate(candidate: Dictionary,id: String,units: Array[Dictionary]) -> Dictionary:
	var key:="income:"+id
	if candidate.receipts.has(key): return {}
	if not candidate.services.has("drops"): candidate.services.drops={}
	var amount:=0
	for unit: Dictionary in units:
		candidate.services.drops[unit.id]=unit.duplicate(true);amount+=int(unit.amount)
	candidate.receipts[key]={"source":key,"source_hash":str(amount).sha256_text(),"revision":state.revision+1}
	return candidate
func collect_coin_candidate(candidate: Dictionary,id: String) -> Dictionary:
	if not candidate.services.get("drops",{}).has(id): return {}
	var unit: Dictionary=candidate.services.drops[id]
	candidate=earned_candidate(candidate,"pickup:"+id,int(unit.amount))
	candidate.services.drops.erase(id)
	return candidate
