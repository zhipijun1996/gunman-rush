class_name WorldServices
extends RefCounted
## Permanent service domain. Candidates use the same durable world revision as HP/facts.
var state: FixedWorldState
var definitions: Dictionary
var error := ""
var prepare_candidate: Callable
static func empty_ledger() -> Dictionary:
	return {"version":1,"gold":0,"owned":{},"equipped":[],"locked":[],"met":[],"quests":{},"cycle_uses":{},"collected":[],"delivered":[]}
static func valid_ledger(value: Dictionary) -> bool:
	if value.get("version")!=1: return false
	for key: String in ["gold"]:
		if not (value.get(key) is float or value.get(key) is int) or not is_finite(value[key]) or value[key]<0 or floorf(value[key])!=value[key]: return false
	for key: String in ["owned","quests","cycle_uses"]:
		if not value.get(key) is Dictionary: return false
	for key: String in ["equipped","locked","met","collected","delivered"]:
		if not value.get(key) is Array: return false
		var seen := {}
		for id: Variant in value[key]:
			if not id is String or seen.has(id): return false
			seen[id]=true
	for id: Variant in value.owned:
		var row: Variant=value.owned[id]
		if not id is String or not row is Dictionary or not row.get("broken") is bool: return false
		for key: String in ["level","hits"]:
			if not (row.get(key) is int or row.get(key) is float) or not is_finite(row[key]) or floorf(row[key])!=row[key] or row[key] < (1 if key=="level" else 0): return false
	for id: Variant in value.cycle_uses:
		var uses: Variant=value.cycle_uses[id]
		if not id is String or not (uses is int or uses is float) or not is_finite(uses) or uses<0 or floorf(uses)!=uses: return false
	for id: Variant in value.quests:
		if not id is String or value.quests[id] not in ["accepted","completed"]: return false
	for id: String in value.equipped:
		if not value.owned.has(id): return false
	for id: String in value.locked:
		if not value.owned.has(id): return false
	return true
func ledger() -> Dictionary:
	return state.value.get("services",empty_ledger())
func item(id: String) -> Dictionary:
	for row: Dictionary in definitions.get("items",[]):
		if row.id==id: return row
	return {}
func owns(id: String) -> bool: return ledger().owned.has(id)
func active(effect: String) -> bool:
	for id: String in ledger().equipped:
		if item(id).get("effect","")==effect and not ledger().owned[id].broken: return true
	return false
func used_load(proposed: Array) -> int:
	var used:=0
	for id: String in proposed: used+=int(item(id).get("load",9999))
	return used
func request(kind: String,id: String,request_id: String,revision: int) -> bool:
	error=""
	if revision!=state.revision: error="stale_revision";return false
	var source:={"kind":kind,"id":id}
	if kind in ["buy","upgrade","repair"]: source.definition=item(id)
	var key:="service:"+request_id
	var fingerprint:=MetaSaveService.canonical_json(source).sha256_text()
	if state.value.receipts.has(key):
		if state.value.receipts[key].source_hash!=fingerprint: error="receipt_conflict";return false
		return true
	var candidate:=state.value.duplicate(true)
	candidate.services=ledger().duplicate(true)
	var data: Dictionary=candidate.services
	var definition:=item(id)
	var required_service: String={"buy":"station_supply_shop","upgrade":"equipment_gold_upgrade","repair":"equipment_breakage_repair","deliver":"gear_delivery"}.get(kind,"")
	if not required_service.is_empty():
		var available:=false
		for npc: Dictionary in state.content.data.get("npcs",[]):
			if npc.room_id==candidate.room and npc.id in data.met and required_service in npc.services: available=true
		if not available: error="npc_unavailable";return false
	match kind:
		"meet":
			var found:=false
			for npc: Dictionary in state.content.data.get("npcs",[]):
				if npc.id==id and npc.room_id==candidate.room: found=true
			if not found: error="npc_not_here";return false
			if id not in data.met: data.met.append(id)
			if id==str(definitions.quest.npc_id) and not data.quests.has(definitions.quest.id): data.quests[definitions.quest.id]="accepted"
		"buy":
			if definition.is_empty() or data.owned.has(id): error="sold_out";return false
			if data.gold<int(definition.price): error="insufficient_gold";return false
			data.gold-=int(definition.price)
			data.owned[id]={"level":1,"broken":false,"hits":0}
		"equip","unequip":
			if not data.owned.has(id): error="not_owned";return false
			if id in data.locked: error="rest_required";return false
			if kind=="equip":
				if id in data.equipped: error="already_equipped";return false
				data.equipped.append(id)
				if used_load(data.equipped)>int(definitions.capacity): error="capacity_exceeded";return false
				data.locked.append(id)
			else: data.equipped.erase(id)
		"use":
			if definition.get("effect","")!="heal" or id not in data.equipped or data.owned[id].broken: error="not_equipped";return false
			if int(data.cycle_uses.get(id,0))>=int(definition.uses_per_cycle): error="cycle_exhausted";return false
			var maximum:=float(candidate.get("max_hp",5))
			if candidate.hp>=maximum: error="full_hp";return false
			candidate.hp=minf(maximum,candidate.hp+int(data.owned[id].level)*int(definition.heal_per_level))
			data.cycle_uses[id]=int(data.cycle_uses.get(id,0))+1
		"upgrade","repair":
			if not data.owned.has(id): error="not_owned";return false
			var owned: Dictionary=data.owned[id]
			var price:=int(definition.upgrade_price if kind=="upgrade" else definition.repair_price)
			if kind=="upgrade" and owned.level>=definition.max_level: error="maximum_level";return false
			if kind=="repair" and not owned.broken: error="not_broken";return false
			if data.gold<price: error="insufficient_gold";return false
			data.gold-=price
			if kind=="upgrade": owned.level+=1
			else: owned.broken=false;owned.hits=0
		"collect":
			var pickup: Dictionary={}
			for row: Dictionary in definitions.pickups:
				if row.id==id and row.room_id==candidate.room: pickup=row
			if pickup.is_empty() or id in data.collected: error="already_collected_or_wrong_room";return false
			data.collected.append(id)
			candidate.inventory[pickup.item]=int(candidate.inventory.get(pickup.item,0))+int(pickup.quantity)
		"deliver":
			var quest: Dictionary=definitions.quest
			if data.quests.get(quest.id,"")!="accepted": error="quest_unavailable";return false
			if int(candidate.inventory.get(quest.requires_item,0))<int(quest.quantity): error="missing_material";return false
			candidate.inventory[quest.requires_item]-=int(quest.quantity)
			data.delivered.assign(data.collected)
			data.quests[quest.id]="completed"
			data.gold+=int(quest.gold)
			if quest.flag not in candidate.flags: candidate.flags.append(quest.flag)
		_:
			error="unknown_service";return false
	candidate.receipts[key]={"source":key,"source_hash":fingerprint,"revision":state.revision+1}
	if prepare_candidate.is_valid():
		candidate=prepare_candidate.call(candidate)
		if candidate.is_empty(): error="invalid_effects";return false
	if not state.commit(candidate,revision): error=state.error;return false
	return true
func earned_candidate(candidate: Dictionary,id: String,amount: int) -> Dictionary:
	var key:="income:"+id
	if candidate.receipts.has(key): return candidate
	if not candidate.has("services"): candidate.services=ledger().duplicate(true)
	candidate.services.gold+=amount
	candidate.receipts[key]={"source":key,"source_hash":str(amount).sha256_text(),"revision":state.revision+1}
	return candidate
func rest_candidate(candidate: Dictionary) -> Dictionary:
	candidate.services=ledger().duplicate(true)
	candidate.services.locked=[]
	candidate.services.cycle_uses={}
	return candidate
func damage_candidate(candidate: Dictionary) -> Dictionary:
	candidate.services=ledger().duplicate(true)
	for id: String in candidate.services.equipped:
		var owned: Dictionary=candidate.services.owned[id]
		var definition:=item(id)
		if owned.broken or not definition.has("break_hits"): continue
		owned.hits+=1
		if owned.hits>=int(definition.break_hits)+int(owned.level)-1: owned.broken=true
	return candidate
func effect_sources(proposed: Dictionary={}) -> Dictionary:
	var data:=ledger() if proposed.is_empty() else proposed
	var result: Dictionary={}
	for id: String in data.equipped:
		var definition:=item(id)
		if definition.is_empty() or data.owned[id].broken or definition.get("catalog_id","").is_empty(): continue
		for base: ItemDefinition in ItemCatalogV5.all_items():
			if str(base.stable_id)!=str(definition.catalog_id): continue
			var copy:=base.duplicate(true) as ItemDefinition
			# Existing item/stat resolution; prototype level policy is explicit data.
			copy.effect_parameters.max_hp_add=float(data.owned[id].level)*float(definition.health_per_level)
			result[StringName(id)]=copy
	return result

func reason() -> String:
	return {"npc_unavailable":"请前往提供这项服务的人物处交谈。","full_hp":"生命已满，没有消耗本周期次数。","not_equipped":"请先装配这件道具。","cycle_exhausted":"本周期次数已用完，休息后刷新。","insufficient_gold":"金币不足。","sold_out":"这件物资已经买过了。","rest_required":"需要先明确休息，才能重新调整这件装备。","capacity_exceeded":"装配负荷不足，请先卸下其他装备。","not_broken":"装备完好，无需维修。","maximum_level":"已达到试制最高等级。","stale_revision":"状态已更新，请重新选择。","missing_material":"还没有找回需要的零件。","quest_unavailable":"这项委托已完成，或尚未接取。","not_owned":"尚未拥有这件装备。"}.get(error,"保存未成功，当前结果保持原样，请重试。")
