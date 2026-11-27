extends SceneTree
const Catalog = preload("res://game/content/world_content_catalog.gd")
var failures: Array[String] = []
var source: Dictionary = {}
var original_manifest: Dictionary = {}
var original_lock: Dictionary = {}

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _init() -> void:
	var catalog := Catalog.new()
	var loaded := catalog.load_locked()
	check(loaded.ok,"load pinned release: "+JSON.stringify(loaded))
	if not loaded.ok:
		finish()
		return
	var lock: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Catalog.DEFAULT_LOCK))
	original_lock = lock
	original_manifest = JSON.parse_string(FileAccess.get_file_as_string("res://config/imported_world/"+str(lock.manifest_path)))
	source = JSON.parse_string(FileAccess.get_file_as_string("res://config/imported_world/"+str(lock.content_path)))
	for table_name: String in Catalog.TABLES:
		check(catalog.table(table_name).rows.size() == source.data[table_name].size(),"all "+table_name+" imported")
	var event: Dictionary = source.data.events[0]
	check(catalog.room_context(event.room).events.any(func(row: Dictionary) -> bool: return row.id == event.id),"room event context")
	var offer: Dictionary = source.data.shops[0]
	check(catalog.shop_quote(offer.id).price == int(offer.price),"source shop price")
	for shop: Dictionary in source.data.shops:
		var reward: Dictionary = catalog.lookup("rewards",shop.reward_key).row
		var expected_equipment: String = reward.catalog_id if reward.get("catalog_id") is String else ""
		check(catalog.shop_quote(shop.id).equipment_id == expected_equipment,"shop reward identity: "+shop.id)
	var upgradeable: Array = source.data.equipment.filter(func(row: Dictionary) -> bool: return row.max_level > 1)
	var equipment: Dictionary = upgradeable[0]
	check(catalog.upgrade_quote(equipment.id,2).price == int(equipment.upgrade_prices["2"]),"target-level price")
	check(not catalog.upgrade_quote(equipment.id,int(equipment.max_level)+1).ok,"unsupported target rejected")
	var group: Dictionary = source.data.enemy_groups[0]
	var drop := catalog.enemy_drop(group.id,group.enemies[0].species_id)
	check(drop.ok and drop.coin_each == int(group.enemies[0].coin_each) and drop.count == int(group.enemies[0].count) and drop.profile_id == group.enemies[0].drop_profile_id,"planning enemy drop query")
	var profile: Dictionary = source.data.enemy_drop_profiles[0]
	var actual_drop := catalog.enemy_drop_profile(profile.id)
	check(actual_drop.ok and actual_drop.coin_each == int(profile.coin_each) and actual_drop.species_id == profile.species_id and actual_drop.tier == profile.tier,"independent profile supplies runtime drop without group or room")
	check(not catalog.enemy_drop_profile("unknown_profile").ok,"unknown drop profile refused")
	check(not catalog.enemy_drop(group.id,"unknown_species").ok,"unknown enemy refused")
	check(catalog.load_bindings("res://config/imported_world/bindings.json").ok,"production room roles load from the checked lock")
	var authored: Array[String] = []
	var receivers: Array[String] = []
	for room: Dictionary in source.data.rooms:
		var binding := catalog.binding("rooms",room.id)
		if not binding.ok: continue
		var selected := catalog.room_document(room.id)
		check(selected.ok, "valid room binding "+str(room.id))
		if binding.row.status == "authored": authored.append(room.id)
		elif binding.row.status == "placeholder": receivers.append(room.id)
		else: check(false,"development binding in the playable world "+str(room.id))
	authored.sort()
	receivers.sort()
	check(authored==["P01","P02","P03"] and receivers==["F08","P04","P13","P16","P19"],"published playable scope is three rooms plus five receiving aprons")
	check(catalog.load_bindings("res://tests/content_channel_empty_bindings.json").ok,"empty authored bindings accepted")
	check(not catalog.room_document(group.room).ok,"unbuilt room cannot instantiate")
	check(not catalog.lookup("rooms","missing").ok,"unknown ID refused")
	var match_result := catalog.condition_match({"requires":["W"],"excludes":["H"]},["W"])
	check(match_result.ok and match_result.matches,"condition all/none")
	check(not catalog.condition_match({"requires":["unknown_flag"]},[]).ok,"unknown condition refused")
	for quest: Dictionary in source.data.quests:
		for step: Dictionary in quest.steps:
			var objective: Dictionary = catalog.lookup("events",step.event).row
			var early := catalog.quest_status(quest.id,[step.event])
			if objective.get("interaction_kind") == "side_quest":
				check(early.discovered and not early.accepted and early.next.id == quest.accept_event,"clue before accept: "+quest.id)
			else:
				check(not early.discovered,"shared milestone does not discover local quest: "+quest.id)
	var before_hash: String = catalog.bundle_sha256
	check(not catalog.load_locked("res://missing.lock.json").ok and catalog.bundle_sha256 == before_hash,"load failure keeps previous catalog")
	var broken: Dictionary = source.duplicate(true)
	broken.schema_version = 999
	var bad_schema := catalog.load_locked(write_fixture("schema",broken))
	check(not bad_schema.ok and bad_schema.error == "content_format_unsupported" and catalog.bundle_sha256 == before_hash,"runtime refuses unsupported schema")
	var bad_hash := catalog.load_locked(write_fixture("hash",source,true))
	check(not bad_hash.ok and bad_hash.error in ["content_hash_mismatch","content_size_mismatch"] and catalog.bundle_sha256 == before_hash,"runtime refuses corrupted content bytes")
	broken = source.duplicate(true)
	broken.data.doors[0].requires = ["unknown_runtime_condition"]
	var bad_condition := catalog.load_locked(write_fixture("condition",broken))
	check(not bad_condition.ok and bad_condition.error == "content_condition_unknown" and catalog.bundle_sha256 == before_hash,"runtime refuses signed unknown condition")
	broken = source.duplicate(true)
	broken.data.enemy_groups[0].enemies[0].drop_profile_id = "missing_runtime_profile"
	var bad_profile := catalog.load_locked(write_fixture("drop_profile",broken))
	check(not bad_profile.ok and bad_profile.error == "content_enemy_drop_profile_unknown" and catalog.bundle_sha256 == before_hash,"runtime refuses dangling drop profile")
	broken = source.duplicate(true)
	var duplicate_profile: Dictionary = broken.data.enemy_drop_profiles[0].duplicate(true)
	duplicate_profile.id = "test_duplicate_profile"
	broken.data.enemy_drop_profiles.append(duplicate_profile)
	var duplicate_pair := catalog.load_locked(write_fixture("duplicate_profile",broken))
	check(not duplicate_pair.ok and duplicate_pair.error == "content_enemy_drop_profile_duplicate" and catalog.bundle_sha256 == before_hash,"runtime refuses duplicate species-tier profile")
	var detached: Dictionary = catalog.lookup("shops",offer.id).row
	detached.price = int(offer.price)+1
	check(catalog.shop_quote(offer.id).price == int(offer.price),"query returns detached data")
	check_dialogue_tie()
	finish()

func check_dialogue_tie() -> void:
	var bundle: Dictionary = source.duplicate(true)
	var earlier: Dictionary = bundle.data.dialogues[0].duplicate(true)
	earlier.id = "test_dialogue_earlier"
	earlier.priority = 1000000
	earlier.requires = []
	earlier.excludes = []
	var later: Dictionary = earlier.duplicate(true)
	later.id = "test_dialogue_later"
	bundle.data.dialogues.append(earlier)
	bundle.data.dialogues.append(later)
	var candidate := Catalog.new()
	var loaded := candidate.load_locked(write_fixture("dialogue_tie",bundle))
	check(loaded.ok,"dialogue tie fixture valid")
	if not loaded.ok: return
	var selected := candidate.dialogues_for(later.room,[],[],later.get("zone"))
	check(selected.ok and selected.rows.any(func(row: Dictionary) -> bool: return row.id == later.id),"same-priority dialogue preserves source-order last match")

func write_fixture(case_name: String, bundle: Dictionary, corrupt: bool = false) -> String:
	var raw: PackedByteArray = JSON.stringify(bundle).to_utf8_buffer()
	var hash_value: String = Catalog._sha(raw)
	var base := "user://content-channel-tests/"+case_name
	var release := base+"/releases/"+hash_value
	DirAccess.make_dir_recursive_absolute(release)
	var manifest: Dictionary = original_manifest.duplicate(true)
	manifest.bundle.sha256 = hash_value
	manifest.bundle.size_bytes = raw.size()
	for table_name: String in Catalog.TABLES:
		manifest.counts[table_name] = bundle.data[table_name].size()
	var lock: Dictionary = original_lock.duplicate(true)
	lock.bundle_sha256 = hash_value
	lock.manifest_path = "releases/"+hash_value+"/manifest.json"
	lock.content_path = "releases/"+hash_value+"/content.json"
	var payload := FileAccess.open(release+"/content.json",FileAccess.WRITE)
	payload.store_buffer(raw)
	if corrupt: payload.store_string(" ")
	payload.close()
	put_json(release+"/manifest.json",manifest)
	put_json(base+"/current.lock.json",lock)
	return base+"/current.lock.json"

func put_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func finish() -> void:
	print(JSON.stringify({"ok":failures.is_empty(),"checks":"pinned catalog, independent drop profiles, data queries, conditions, quest discovery, source-order dialogue, playable rooms and receiving aprons, unbound rooms, atomic load","failures":failures}))
	print("CONTENT CHANNEL CATALOG failures="+str(failures.size()))
	quit(0 if failures.is_empty() else 1)
