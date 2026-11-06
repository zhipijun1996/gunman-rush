class_name FixedWorldState
extends RefCounted
## One committed world revision. Scene instances never own permanent receipts.
signal committed(revision: int)
var storage: WorldSaveService
var content: FixedWorldProvider
var revision := 0
var error := ""
var value: Dictionary = {}

func fresh(max_hp: float) -> Dictionary:
	return {"services":WorldServices.empty_ledger(),"flags":["gun"],"receipts":{},"inventory":{},"cycle":1,"enemies":{},
		"hp":max_hp,"rest":{"room":"P-R03","entry":"","point":[144,512]},
		"room":"P-R03","entry":"","explored":[],"content_version":content.data.content_version}

func restore() -> bool:
	var loaded := storage.load_profile()
	if not loaded.get("accepted",false):
		error = storage.status
		return false
	if loaded.payload.is_empty():
		error = "no_world_save"
		return false
	var candidate: Dictionary = loaded.payload.duplicate(true)
	if not valid(candidate):
		storage.blocked = true
		error = "invalid_world_payload"
		return false
	# Stable facts survive compatible content revisions; unavailable positions return
	# to an implemented registered rest, then the campaign start. Never overwrite on read.
	if content.room(str(candidate.rest.room)).is_empty():
		candidate.rest = fresh(float(candidate.hp)).rest
	if content.room(str(candidate.room)).is_empty() or not valid_entry(str(candidate.room),str(candidate.entry)):
		var rest: Dictionary = candidate.rest
		candidate.room = rest.room if not content.room(str(rest.room)).is_empty() else "P-R03"
		candidate.entry = ""
	candidate.content_version = content.data.content_version
	if not candidate.has("services"): candidate.services=WorldServices.empty_ledger()
	value = candidate
	revision = int(loaded.revision)
	return true

func valid(candidate: Dictionary) -> bool:
	if candidate.has("services") and (not candidate.services is Dictionary or not WorldServices.valid_ledger(candidate.services)): return false
	for key: String in ["flags","explored"]:
		if not candidate.get(key) is Array: return false
	for key: String in ["receipts","inventory","enemies","rest"]:
		if not candidate.get(key) is Dictionary: return false
	for id: Variant in candidate.inventory:
		var quantity: Variant=candidate.inventory[id]
		if not id is String or not (quantity is int or quantity is float) or not is_finite(quantity) or quantity<0 or floorf(quantity)!=quantity: return false
	if not candidate.get("room") is String or not candidate.get("entry") is String: return false
	if not candidate.rest.get("room") is String or not candidate.rest.get("point") is Array or candidate.rest.point.size()!=2: return false
	for v: Variant in candidate.rest.point:
		if not (v is float or v is int) or not is_finite(v): return false
	if not (candidate.get("hp") is float or candidate.get("hp") is int) or not is_finite(candidate.hp) or candidate.hp<=0: return false
	if not (candidate.get("cycle") is float or candidate.get("cycle") is int) or candidate.cycle<1 or floorf(candidate.cycle)!=candidate.cycle: return false
	for key: String in ["flags","explored"]:
		for item: Variant in candidate[key]:
			if not item is String: return false
	for id: Variant in candidate.receipts:
		var receipt: Variant = candidate.receipts[id]
		if not id is String or not receipt is Dictionary or receipt.get("source")!=id: return false
		if not receipt.get("source_hash") is String or receipt.source_hash.length()!=64: return false
		if not (receipt.get("revision") is float or receipt.get("revision") is int) or receipt.revision<1: return false
	for id: Variant in candidate.enemies:
		var enemy: Variant = candidate.enemies[id]
		if not id is String or not enemy is Dictionary: return false
		if not (enemy.get("health") is float or enemy.get("health") is int) or not is_finite(enemy.health) or enemy.health<0: return false
		for key: String in ["position","home","locked_direction","attack_goal","attack_origin"]:
			if not enemy.get(key) is Array or enemy[key].size()!=2: return false
			for coordinate: Variant in enemy[key]:
				if not (coordinate is float or coordinate is int) or not is_finite(coordinate): return false
		for key: String in ["state_time","cooldown","serial","direction"]:
			if not (enemy.get(key) is float or enemy.get(key) is int) or not is_finite(enemy[key]): return false
		if not enemy.get("state") is String: return false
	return true

func valid_entry(room_id: String, door_id: String) -> bool:
	if door_id.is_empty(): return true
	for door: Dictionary in content.room(room_id).get("doors",[]):
		if door.id == door_id: return true
	return false

func commit(candidate: Dictionary, expected_revision: int) -> bool:
	if expected_revision != revision or not valid(candidate):
		error = "invalid_or_stale_revision"
		return false
	if not storage.commit(candidate,revision+1):
		error = storage.status
		return false
	value = candidate.duplicate(true)
	revision += 1
	error = ""
	committed.emit(revision)
	return true

func has(flag: String) -> bool:
	return flag in value.get("flags",[])

func holds(requirements: Array) -> bool:
	if requirements.is_empty(): return true
	for clause: Array in requirements:
		var accepted := true
		for flag: String in clause:
			if ">=" in flag:
				var parts:=flag.split(">=")
				if int(value.inventory.get(parts[0],0))<int(parts[1]): accepted=false
			elif not has(flag): accepted = false
		if accepted: return true
	return false

func action_candidate(id: String, room_id: String) -> Dictionary:
	var action := content.action(id)
	if action.is_empty() or action.room_id != room_id or action.get("section_id","main") != "main" or not holds(action.get("requires",[])):
		error = "action_not_eligible"
		return {}
	var source_hash := MetaSaveService.canonical_json(action).sha256_text()
	if value.receipts.has(id):
		if value.receipts[id].source_hash != source_hash:
			error = "receipt_source_conflict"
			return {}
		return value.duplicate(true)
	var candidate := value.duplicate(true)
	for item: String in action.get("consumes",{}):
		var required:=int(action.consumes[item])
		if required<0 or int(candidate.inventory.get(item,0))<required:
			error="missing_inventory";return {}
		candidate.inventory[item]-=required
	for item: String in action.get("inventory_grants",{}):
		candidate.inventory[item]=int(candidate.inventory.get(item,0))+int(action.inventory_grants[item])
	for flag: String in action.get("removes",[]): candidate.flags.erase(flag)
	for flag: String in action.get("grants",[]):
		if flag not in candidate.flags: candidate.flags.append(flag)
	candidate.receipts[id] = {"source":id,"source_hash":source_hash,"revision":revision+1}
	return candidate
