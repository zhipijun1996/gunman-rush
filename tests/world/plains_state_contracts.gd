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
	check(state.action_candidate("pickup_TG01",str(provider.action("pickup_TG01").room_id))==state.value,"delivered gear never respawns")
	check(state.commit(state.action_candidate("pickup_TG03","P-R30","reward:TG03"),state.revision),"qualified section pickup")
	check(state.commit(state.action_candidate("deliver_time_gears","P-R01"),state.revision),"later repeat delivery succeeds")
	check(state.value.inventory.delivered_gears==3 and state.value.gear_ids.delivered.size()==3,"repeat delivery preserves all IDs")
	var invalid:=state.value.duplicate(true);invalid.gear_ids.carried.append("TG01")
	check(not state.valid(invalid),"duplicate across carried/delivered refused")
	check(state.restore() and state.value.inventory.delivered_gears==3,"durable restart reconstructs gear identity")
	# Traveler chapters are intentionally deferred in the current approved release.
	for room:String in ["P-R21","P-R23","P-R24","P-R27","P-R02"]:
		check(WorldTraveler.chapter(state,room).is_empty() and WorldTraveler.talk_candidate(state,room).is_empty(),"deferred traveler has no stray dialogue/receipt in "+room)
	check(not state.value.receipts.has("story_aqi_t01") and not state.has("intro_complete"),"deferred story grants no progression")
	check(state.commit(state.action_candidate("station_briefing","P-R01"),state.revision),"arrival landmark remains independent of deferred traveler")
	print("PLAINS STATE: %d assertions, %d failures" % [checks,failures]);quit(failures)
