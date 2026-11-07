extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func run() -> void:
	var provider:=FixedWorldProvider.new();check(provider.open(),"latest runtime")
	var state:=FixedWorldState.new();state.content=provider;state.storage=WorldSaveService.new()
	state.storage.configure("user://plains_transactions.json",false,"plains_contracts");state.storage.content_version=provider.data.content_version;state.storage.payload_validator=state.valid
	for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(state.storage.path+suffix)
	check(state.commit(state.fresh(5),0),"fresh ledger")
	check(state.action_candidate("repair_P","P-R15").is_empty(),"cannot repair from main section")
	check(state.action_candidate("pickup_TG04","P-R19").is_empty(),"cannot take root reward from lower route")
	check(state.action_candidate("pickup_TG03","P-R18","reward:TG03").is_empty(),"old TG03 room retired")
	for id: String in ["pickup_TG01","pickup_TG02"]:
		check(state.commit(state.action_candidate(id,str(provider.action(id).room_id)),state.revision),"collect unique "+id)
	check(state.value.gear_ids.carried==["TG01","TG02"] and state.value.inventory.time_gear==2,"identity/count conservation")
	var before:=state.value.duplicate(true)
	state.storage.blocked=true
	check(not state.commit(state.action_candidate("deliver_time_gears","P-R01"),state.revision) and state.value==before,"failed delivery publishes nothing")
	state.storage.blocked=false
	check(state.commit(state.action_candidate("deliver_time_gears","P-R01"),state.revision),"atomic delivery")
	check(state.value.gear_ids.carried.is_empty() and state.value.gear_ids.delivered==["TG01","TG02"] and state.value.inventory.delivered_gears==2,"delivered IDs and cumulative count agree")
	check(state.action_candidate("deliver_time_gears","P-R01").is_empty(),"empty delivery refused")
	check(state.action_candidate("pickup_TG01","P-R04")==state.value,"delivered gear never respawns")
	check(state.commit(state.action_candidate("pickup_TG03","P-R30","reward:TG03"),state.revision),"qualified section pickup")
	check(state.commit(state.action_candidate("deliver_time_gears","P-R01"),state.revision),"later repeat delivery succeeds")
	check(state.value.inventory.delivered_gears==3 and state.value.gear_ids.delivered.size()==3,"repeat delivery preserves all IDs")
	var invalid:=state.value.duplicate(true);invalid.gear_ids.carried.append("TG01")
	check(not state.valid(invalid),"duplicate across carried/delivered refused")
	check(state.restore() and state.value.inventory.delivered_gears==3,"durable restart reconstructs gear identity")
	check(not WorldTraveler.chapter(state,"P-R23").is_empty(),"first chapter initially available")
	check(not state.value.receipts.has("story_aqi_t01"),"passing is not talking")
	check(state.commit(WorldTraveler.talk_candidate(state,"P-R23"),state.revision),"optional talk receipt")
	check(not state.has("intro_complete"),"dialogue grants no progression")
	var visited:=state.value.duplicate(true);visited.explored.append("P-R23");state.commit(visited,state.revision)
	check(WorldTraveler.identity(state,"P-R24").get("chapter")=="AQI_T01_LOOKOUT","follow-up uses same traveler identity with lookout activity")
	check(state.commit(WorldTraveler.prepare(state,state.value.duplicate(true),"P-R24"),state.revision),"move host only after leaving first room")
	check(WorldTraveler.chapter(state,"P-R23").is_empty(),"old first-chapter host cannot duplicate follow-up")
	check(state.commit(state.action_candidate("station_briefing","P-R01"),state.revision),"arrival landmark")
	check(WorldTraveler.chapter(state,"P-R23").is_empty(),"obsolete traveler placement disappears")
	check(state.commit(WorldTraveler.prepare(state,state.value.duplicate(true),"P-R27"),state.revision),"first shelter host persisted")
	check(not WorldTraveler.chapter(state,"P-R27").is_empty() and WorldTraveler.chapter(state,"P-R02").is_empty(),"chapter never appears at both shelters")
	check(not state.value.receipts.has("story_aqi_t03"),"host selection is not dialogue completion")
	check(WorldTraveler.chapter(state,"P-R01").is_empty(),"later hosted chapter never regresses to station tea")
	print("PLAINS STATE: %d assertions, %d failures" % [checks,failures]);quit(failures)
