extends SceneTree
var failed := 0
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		printerr("FAIL: ",label)
func run() -> void:
	var provider := FixedWorldProvider.new()
	check(provider.open(),"runtime bundle loads")
	var state := FixedWorldState.new()
	state.content = provider
	state.storage = WorldSaveService.new()
	state.storage.configure("user://world_contract_test.json",false,"contracts")
	state.storage.content_version = provider.data.content_version
	state.storage.payload_validator = state.valid
	for suffix: String in ["",".backup",".tmp",".corrupt"]: DirAccess.remove_absolute(state.storage.path+suffix)
	check(state.commit(state.fresh(5),0),"initial revision persisted")
	check(state.value.cycle==1 and state.value.flags==["gun"],"no early Q/H grant")
	check(state.action_candidate("get_H","P-R14").is_empty(),"H requires real committed victory")
	check(state.action_candidate("tutorial_shoot","P-R21").is_empty(),"ordered tutorial facts")
	var candidate := state.action_candidate("tutorial_move","P-R03")
	check(state.commit(candidate,state.revision),"first tutorial transaction")
	check(not state.commit(candidate,1),"stale revision refused")
	check(state.value.receipts.size()==1,"unique receipt")
	check(state.action_candidate("tutorial_move","P-R03")==state.value,"same source retry returns committed receipt")
	var action := provider.action("tutorial_move")
	var original: Array = action.grants.duplicate()
	action.grants.append("unexpected_grant")
	check(state.action_candidate("tutorial_move","P-R03").is_empty() and state.error=="receipt_source_conflict","same ID with changed source rejected")
	action.grants = original
	var invalid := state.value.duplicate(true)
	invalid.explored = [42]
	check(not state.valid(invalid),"malformed exploration rejected before UI restoration")
	var moved := state.value.duplicate(true)
	moved.room = "removed_room"
	moved.rest.room = "removed_rest"
	check(state.commit(moved,state.revision) and state.restore() and state.value.room=="P-R03" and state.value.rest.room=="P-R03","content removal repairs both current location and later death destination")
	var before := state.value.duplicate(true)
	state.storage.blocked = true
	check(not state.commit(state.action_candidate("tutorial_shoot","P-R21"),state.revision),"write failure rejected")
	check(state.value==before,"failed transaction publishes no new state")
	state.storage.blocked = false
	check(state.commit(state.action_candidate("tutorial_shoot","P-R21"),state.revision),"retry commits")
	var primary := FileAccess.open(state.storage.path,FileAccess.WRITE)
	primary.store_string("corrupt"); primary.close()
	check(state.restore() and state.storage.status=="recovered_backup","bad main falls back to valid backup")
	check(state.has("intro_move") and not state.has("intro_shoot"),"backup restores its coherent revision")
	var backup := FileAccess.open(state.storage.path+".backup",FileAccess.WRITE)
	backup.store_string("also corrupt");backup.close()
	check(not state.restore() and state.storage.blocked,"both bad files block overwrite")
	check(FileAccess.get_file_as_string(state.storage.path)=="corrupt","original bad main retained")
	check(state.storage.web_storage_key()=="gunman_rush.fixed_world.v1.contracts","independent world Web key")
	check(state.storage.web_storage_key()!=MetaSaveService.WEB_KEY,"old key isolated")
	var request := LevelRequest.new()
	request.room_id = "P-R01";request.entry_door_id = "missing"
	check(provider.resolve(request).get("error")=="entry_missing","unknown entry refused")
	request.room_id = "K-R10";request.entry_door_id = ""
	check(provider.resolve(request).get("error")=="room_not_implemented","unbuilt room refused")
	request.room_id = "P-R03";request.expected_hash = "old"
	check(provider.resolve(request).get("error")=="content_version_mismatch","wrong content identity refused")
	print("WORLD STATE: %d assertions, %d failures" % [checks,failed])
	quit(failed)
