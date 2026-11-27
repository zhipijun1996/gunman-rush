extends SceneTree
## Exercise the three audited transitions with checksummed native slots.
## Only the additions since ad15f82b are removed to reproduce its schema-3 documents.
var checks:=0
var failures:=0
var catalog:=WorldContentCatalog.new()

func _initialize() -> void: run.call_deferred()

func check(ok: bool, info: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL old world save ",info)

func open_slot(id: String,label: String) -> PlayableWorldSave:
	var slot:=PlayableWorldSave.new()
	slot.configure_world("user://migration_%d_%s_%s.json"%[OS.get_process_id(),id,label],false,"migration")
	return slot

func clean(slot: PlayableWorldSave) -> void:
	for suffix: String in ["",".backup",".tmp",".corrupt"]:
		var path:=slot.path+suffix
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path): DirAccess.remove_absolute(path)

func historical(doc: Dictionary) -> Dictionary:
	var copy:=doc.duplicate(true)
	match copy.room_id:
		"G08": copy.sites.erase("smith")
		"P08": copy.entities.erase("town_rest")
		"Y23": copy.erase("zone_areas")
	return copy

func identity(doc: Dictionary,bundle: String) -> String:
	return (JSON.stringify(doc)+":"+bundle).sha256_text()

func write_legacy(doc: Dictionary, slot: PlayableWorldSave, source_version: String, envelope_version: String) -> Dictionary:
	var state:=FixedWorldState.new()
	state.content=FixedWorldProvider.new()
	state.content.data={"start_room":doc.room_id,"start_point":doc.root.properties.start_point,"content_version":source_version}
	var payload:=state.fresh(4)
	payload.rest.room="P01"
	payload.rest.point=[110,318]
	payload.entry=doc.exits.keys().front()
	payload.services.gold=72
	payload.flags.append("W")
	payload.inventory.attack_alloy=1
	payload.cycle=3
	payload.receipts["W"]={"source":"W","source_hash":"W".sha256_text(),"revision":3}
	slot.content_version=envelope_version
	check(slot.commit(payload,11),"write real native slot "+doc.room_id)
	return JSON.parse_string(FileAccess.get_file_as_string(slot.path)).payload

func close_host(host: WorldGameHost) -> void:
	if host.active!=null and host.active.audio_service!=null: await host.active.audio_service.shutdown()
	host.free()
	await physics_frame

func approved(id: String) -> void:
	var doc:=WorldRoomDocument.read("res://rooms/world/"+id+".json")
	var previous:=identity(historical(doc),catalog.bundle_sha256)
	var current:=identity(doc,catalog.bundle_sha256)
	check(previous==PlayableWorldSave.COMPATIBLE_ROOMS[id].from and previous!=current,id+" reproduce historical source")
	var slot:=open_slot(id,"compatible")
	var original:=write_legacy(doc,slot,previous,previous)
	var before:=FileAccess.get_file_as_bytes(slot.path)
	var host:=WorldGameHost.new()
	host.storage=slot
	root.add_child(host)
	var s:=host.active
	check(is_instance_valid(s) and s.room.room_id==id,id+" real host continues, "+host.last_error)
	if s!=null:
		check(s.state.revision==11 and s.state.value.content_version==current and s.state.value.entry==original.entry and s.state.value.rest==original.rest,id+" preserve actual doorway, rest and revision in memory")
		check(s.services.ledger().gold==72 and s.state.value.receipts==original.receipts and s.state.value.cycle==3 and s.state.value.flags==original.flags and s.state.value.inventory.attack_alloy==1,id+" preserve wallet, inventory, world facts and receipts")
		check(FileAccess.get_file_as_bytes(slot.path)==before and not FileAccess.file_exists(slot.path+".backup"),id+" merely loading leaves disk byte-identical")
		DirAccess.make_dir_absolute(slot.path+".tmp")
		check(not s.checkpoint() and s.state.revision==11 and FileAccess.get_file_as_bytes(slot.path)==before,id+" failed first checkpoint preserves historic file")
		DirAccess.remove_absolute(slot.path+".tmp")
		check(s.checkpoint() and s.state.revision==12,id+" successful ordinary checkpoint updates once")
		var reread:=slot.load_profile()
		check(reread.accepted and reread.envelope_content==current and reread.payload.content_version==current and reread.payload.receipts==original.receipts,id+" durable current checksum and payload")
		check(FileAccess.get_file_as_bytes(slot.path+".backup")==before,id+" previous slot becomes exact backup")
	await close_host(host)
	clean(slot)

func rejected(label: String, previous: String, envelope: String, doc_override: Dictionary={}) -> void:
	var doc:=WorldRoomDocument.read("res://rooms/world/G08.json")
	var slot:=open_slot("G08",label)
	write_legacy(doc,slot,previous,envelope)
	var before:=FileAccess.get_file_as_bytes(slot.path)
	var s:=OrdinaryRoomSession.new()
	root.add_child(s)
	var err:=s.open(doc if doc_override.is_empty() else doc_override,slot,null,catalog)
	check(not err.is_empty() and s.room==null and FileAccess.get_file_as_bytes(slot.path)==before,label+" remains refused and untouched")
	s.free()
	clean(slot)

func run() -> void:
	check(catalog.load_locked().ok and catalog.load_bindings("res://config/imported_world/bindings.json").ok,"current lock and bindings")
	for id: String in ["G08","P08","Y23"]: await approved(id)
	var doc:=WorldRoomDocument.read("res://rooms/world/G08.json")
	var old:=identity(historical(doc),catalog.bundle_sha256)
	var foreign:=identity(historical(doc),"other bundle".sha256_text())
	rejected("other_lock",foreign,foreign)
	rejected("unknown","unknown document".sha256_text(),"unknown document".sha256_text())
	rejected("foreign_envelope",old,foreign)
	rejected("wrong_room",PlayableWorldSave.COMPATIBLE_ROOMS.P08.from,PlayableWorldSave.COMPATIBLE_ROOMS.P08.from)
	doc.sites.smith.at[0]+=2
	rejected("unknown_target",old,old,doc)
	print("WORLD SAVE COMPATIBILITY failures=",failures," checks=",checks)
	quit(1 if failures else 0)
