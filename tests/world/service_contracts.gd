extends SceneTree
## Declared funds/material preconditions here; normal loop proves actual income and access separately.
var failures:=0
var checks:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("FAIL: ",label)
func run() -> void:
	var content:=FixedWorldProvider.new();content.open()
	var state:=FixedWorldState.new();state.content=content
	state.storage=WorldSaveService.new()
	state.storage.configure("user://world_service_contracts.json",false,"service_fixture")
	state.storage.content_version=content.data.content_version
	state.storage.payload_validator=state.valid
	for suffix: String in ["",".backup",".tmp",".corrupt"]: DirAccess.remove_absolute(state.storage.path+suffix)
	var candidate:=state.fresh(5)
	candidate.services.gold=100
	candidate.room="P-R01"
	state.commit(candidate,0)
	var service:=WorldServices.new();service.state=state;service.definitions=content.data.demo_services
	check(not service.request("buy","trial_lamp","buy:unmet",state.revision),"service requires actual met NPC in current room")
	check(service.request("meet","NPC_P_REC","meet:rec",state.revision),"real bound NPC starts finite quest")
	service.request("meet","NPC_P_WEAVER","meet:weaver",state.revision)
	check(service.request("buy","trial_lamp","buy:lamp",state.revision),"purchase atomically commits debit and ownership")
	check(service.ledger().gold==95 and service.owns("trial_lamp") and not service.active("lamp"),"ownership alone does not activate tool")
	check(not service.request("upgrade","trial_lamp","upgrade:fixed_lamp",state.revision) and service.error=="maximum_level" and service.ledger().gold==95,"fixed-level tool cannot charge a no-effect upgrade")
	var revision:=state.revision
	check(service.request("buy","trial_lamp","buy:lamp",state.revision) and state.revision==revision,"same request returns original without debit or revision")
	check(not service.request("buy","trial_filter","buy:lamp",state.revision),"different payload with same request ID rejected")
	check(service.request("equip","trial_lamp","equip:lamp",state.revision) and service.active("lamp"),"equipped lamp activates")
	check(not service.request("unequip","trial_lamp","unequip:locked",state.revision) and service.error=="rest_required","first equip locks until explicit rest")
	candidate=service.rest_candidate(state.value.duplicate(true));candidate.cycle+=1
	state.commit(candidate,state.revision)
	check(service.request("unequip","trial_lamp","unequip:rested",state.revision) and not service.active("lamp"),"explicit rest unlocks without forcing removal")
	var before:=state.value.duplicate(true)
	state.storage.blocked=true
	check(not service.request("buy","trial_filter","buy:filter:failed",state.revision) and state.value==before,"disk failure publishes neither debit nor item")
	state.storage.blocked=false
	check(service.request("buy","trial_filter","buy:filter",state.revision),"purchase retry succeeds once")
	service.request("equip","trial_filter","equip:filter",state.revision)
	for i: int in 3: state.commit(service.damage_candidate(state.value.duplicate(true)),state.revision)
	check(service.ledger().owned.trial_filter.broken and not service.active("filter"),"accepted hit count breaks and deactivates equipped filter")
	var cycle: int=state.value.cycle
	var hp: float=state.value.hp
	check(service.request("repair","trial_filter","repair:filter",state.revision) and service.active("filter"),"repair reactivates original unique item")
	check(state.value.cycle==cycle and state.value.hp==hp and "trial_filter" in service.ledger().locked,"repair neither heals nor rests nor unlocks")
	check(service.request("upgrade","trial_filter","upgrade:filter",state.revision) and service.ledger().owned.trial_filter.level==2,"upgrade persists same item level")
	service.request("buy","trial_heart","buy:heart",state.revision)
	service.request("equip","trial_heart","equip:heart",state.revision)
	before=state.value.duplicate(true)
	check(not service.request("equip","trial_lamp","equip:overload",state.revision) and state.value==before,"over-capacity rejects entire proposal")
	candidate=service.rest_candidate(state.value.duplicate(true));state.commit(candidate,state.revision)
	service.request("unequip","trial_heart","unequip:heart",state.revision)
	service.request("buy","trial_flask","buy:flask",state.revision)
	service.request("equip","trial_flask","equip:flask",state.revision)
	check(not service.request("use","trial_flask","use:full",state.revision) and service.ledger().cycle_uses.is_empty(),"full HP consumes no cycle charge")
	candidate=state.value.duplicate(true);candidate.hp=2;state.commit(candidate,state.revision)
	check(service.request("use","trial_flask","use:heal",state.revision) and state.value.hp==4,"cycle use heals in same persisted revision")
	check(not service.request("use","trial_flask","use:twice",state.revision),"same-cycle second use denied")
	candidate=service.rest_candidate(state.value.duplicate(true));candidate.cycle+=1
	state.commit(candidate,state.revision)
	check(service.ledger().cycle_uses.is_empty() and service.owns("trial_flask"),"rest refreshes allowance and preserves ownership")
	check(not service.request("deliver","trial_station_repair","deliver:empty",state.revision),"quest requires actual material")
	candidate=state.value.duplicate(true);candidate.room="P-R06";state.commit(candidate,state.revision)
	check(service.request("collect","trial_part_01","collect:part",state.revision),"stable placed pickup grants one counted material")
	check(not service.request("collect","trial_part_01","collect:duplicate",state.revision),"different request cannot duplicate unique pickup")
	candidate=state.value.duplicate(true);candidate.room="P-R01";state.commit(candidate,state.revision)
	check(service.request("deliver","trial_station_repair","deliver:part",state.revision),"material debit, quest, currency and world flag commit together")
	check(state.has("trial_station_repaired") and state.value.inventory.trial_part==0 and service.ledger().delivered==["trial_part_01"],"delivered identity set agrees with result")
	check(state.restore() and state.has("trial_station_repaired") and service.ledger().owned.trial_filter.level==2,"disk restoration retains quest and equipment state")
	var settings:=WorldSettings.new()
	var settings_path:="user://world_settings_contracts.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]: DirAccess.remove_absolute(settings_path+suffix)
	settings.open(settings_path,"settings_fixture")
	var preferences:=settings.value.duplicate(true);preferences.volume=.35;preferences.input.touch_move_mode="digital"
	check(settings.save(preferences),"preferences commit to independent durable slot")
	var settings2:=WorldSettings.new();settings2.open(settings_path,"settings_fixture")
	check(is_equal_approx(settings2.value.volume,.35) and settings2.value.input.touch_move_mode=="digital","new settings owner restores independent preference revision")
	check(settings.storage.web_storage_key()!=state.storage.web_storage_key(),"new world cannot overwrite settings key")
	print("WORLD SERVICES: %d assertions, %d failures" % [checks,failures])
	quit(failures)
