class_name WorldContentCatalog
extends RefCounted
## Read-only authored content, pinned by a local lock. No HTTP, save writes,
## scene synthesis, combat simulation or currency settlement occurs here.
const FORMAT := "clock-world-content"
const SCHEMA := 1
const WORLD_ID := "clock-world"
const DEFAULT_LOCK := "res://config/imported_world/current.lock.json"
const TABLES := ["regions","rooms","doors","map_layers","abilities","rewards","encounters","events","npcs","speakers","dialogues","quests","endings","equipment","shops","coin_caches","enemy_groups","enemy_species","enemy_drop_profiles","observer_hints","flags"]
const OBJECTS := ["growth","transport","commerce"]
const CONDITION_KEYS := ["requires","excludes","visible_requires","completion_requires","minimum_abilities","reverse_requires","first_route_requires"]
const BINDING_TABLES := {"rooms":"rooms","npcs":"npcs","enemy_species":"enemy_species","equipment_effects":"equipment","event_triggers":"events"}
const MAX_BYTES := 33554432

var bundle_sha256 := ""
var content_version := ""
var source_model_sha256 := ""
var _bundle: Dictionary = {}
var _tables: Dictionary = {}
var _physical_normals: Dictionary = {}
var _bindings: Dictionary = {}
var _bindings_path := ""
var _allow_test_bindings := false

static func failure(code: String, detail: String = "") -> Dictionary:
	return {"ok":false,"error":code,"detail":detail}

static func _sha(raw: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(raw)
	return hashing.finish().hex_encode()

static func _is_sha(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for letter: String in value:
		if letter not in "0123456789abcdef": return false
	return true

static func _integer(value: Variant, minimum: int = 0) -> bool:
	return (value is int or value is float) and is_finite(value) and floorf(value) == value and value >= minimum and value <= 2147483647

static func _point(value: Variant) -> bool:
	if not value is Array or value.size() != 2: return false
	for number: Variant in value:
		if not (number is int or number is float) or not is_finite(number): return false
	return true

static func _relative(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() >= 240: return false
	if value.to_utf8_buffer().has(0): return false
	for character: String in ["\\",":","?","#","%"]:
		if character in value: return false
	for part: String in value.split("/"):
		if part in ["",".",".."]: return false
	return true

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return failure("content_file_missing",path)
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return failure("content_file_unreadable",path)
	if file.get_length() > MAX_BYTES: return failure("content_file_too_large",path)
	var raw := file.get_buffer(file.get_length())
	var parser := JSON.new()
	if parser.parse(raw.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return failure("content_json_invalid",path)
	return {"ok":true,"value":parser.data,"raw":raw}

static func _envelope(value: Dictionary, format_name: String) -> bool:
	return value.get("format") == format_name and _integer(value.get("schema_version"),1) and value.schema_version == SCHEMA and value.get("world_id") == WORLD_ID and value.get("content_version") is String and not value.content_version.is_empty() and _is_sha(value.get("source_model_sha256"))

func load_locked(lock_path: String = DEFAULT_LOCK) -> Dictionary:
	var read_lock := _read(lock_path)
	if not read_lock.ok: return read_lock
	var lock: Dictionary = read_lock.value
	if lock.get("format") != "clock-world-content-lock" or not _integer(lock.get("schema_version"),1) or lock.get("schema_version") != SCHEMA or lock.get("world_id") != WORLD_ID:
		return failure("content_lock_unsupported")
	var sha: Variant = lock.get("bundle_sha256")
	if not _is_sha(sha): return failure("content_lock_hash_invalid")
	var expected_manifest := "releases/"+str(sha)+"/manifest.json"
	var expected_content := "releases/"+str(sha)+"/content.json"
	if lock.get("manifest_path") != expected_manifest or lock.get("content_path") != expected_content:
		return failure("content_lock_path_invalid")
	var directory := lock_path.get_base_dir()
	var read_manifest := _read(directory.path_join(expected_manifest))
	if not read_manifest.ok: return read_manifest
	var manifest: Dictionary = read_manifest.value
	if not _envelope(manifest,"clock-world-content-manifest"): return failure("content_manifest_unsupported")
	var descriptor: Variant = manifest.get("bundle")
	if not descriptor is Dictionary or descriptor.get("path") != "content.json" or descriptor.get("sha256") != sha or not _integer(descriptor.get("size_bytes"),1):
		return failure("content_manifest_descriptor_invalid")
	var read_content := _read(directory.path_join(expected_content))
	if not read_content.ok: return read_content
	var raw: PackedByteArray = read_content.raw
	if raw.size() != descriptor.size_bytes: return failure("content_size_mismatch")
	if _sha(raw) != sha: return failure("content_hash_mismatch")
	var proposed: Dictionary = read_content.value
	for field: String in ["world_id","content_version","source_model_sha256"]:
		if manifest.get(field) != proposed.get(field) or lock.get(field) != proposed.get(field):
			return failure("content_identity_mismatch",field)
	var checked := _index_bundle(proposed)
	if not checked.ok: return checked
	if not manifest.get("counts") is Dictionary or manifest.counts.size() != checked.counts.size(): return failure("content_counts_mismatch")
	for table_name: String in checked.counts:
		if not _integer(manifest.counts.get(table_name)) or int(manifest.counts[table_name]) != checked.counts[table_name]: return failure("content_counts_mismatch",table_name)
	# Publish only after the entire candidate has passed. A bad update keeps the
	# previously loaded catalog and bindings intact.
	_bundle = proposed
	_tables = checked.tables
	_physical_normals = checked.physical_normals
	bundle_sha256 = sha
	content_version = proposed.content_version
	source_model_sha256 = proposed.source_model_sha256
	_bindings = {}
	_bindings_path = ""
	return {"ok":true,"bundle_sha256":bundle_sha256,"content_version":content_version,"source_model_sha256":source_model_sha256,"counts":checked.counts,"required_bindings":_bundle.required_bindings.size()}

static func _json_shape(value: Variant, depth: int = 0) -> bool:
	if depth > 60: return false
	if value is Dictionary:
		for key: Variant in value:
			if not key is String or key in ["__proto__","prototype","constructor"] or not _json_shape(value[key],depth+1): return false
	elif value is Array:
		for item: Variant in value:
			if not _json_shape(item,depth+1): return false
	elif value is float and not is_finite(value): return false
	return true

static func _conditions_valid(value: Variant, indexes: Dictionary) -> bool:
	if value is Dictionary:
		for key: String in value:
			if key in CONDITION_KEYS:
				if not value[key] is Array: return false
				var seen := {}
				for flag: Variant in value[key]:
					if not flag is String or seen.has(flag): return false
					seen[flag] = true
					if flag.begins_with("equipped:"):
						if not indexes.equipment.has(flag.substr(9)): return false
					elif not indexes.flags.has(flag): return false
			elif not _conditions_valid(value[key],indexes): return false
	elif value is Array:
		for item: Variant in value:
			if not _conditions_valid(item,indexes): return false
	return true

static func _place_valid(row: Dictionary, rooms: Dictionary, zones: Dictionary) -> bool:
	if not rooms.has(row.get("room")): return false
	if row.get("zone") != null and zones.get(row.zone) != row.room: return false
	if row.has("anchor") and not _point(row.anchor): return false
	if row.has("interaction_sites"):
		if not row.interaction_sites is Array or row.interaction_sites.is_empty(): return false
		for site: Variant in row.interaction_sites:
			if not site is Dictionary or not _place_valid(site,rooms,zones): return false
	return true

static func _index_bundle(bundle: Dictionary) -> Dictionary:
	if not _envelope(bundle,FORMAT): return failure("content_format_unsupported")
	if not _json_shape(bundle): return failure("content_value_invalid")
	if bundle.get("coordinate_system") != {"layout":"planning_units","collision":false,"gameplay":"room_local_pixels"}:
		return failure("content_coordinates_unsupported")
	var rules: Variant = bundle.get("rules")
	if not rules is Dictionary or rules.get("conditions") != {"requires":"all","excludes":"none","equipped_prefix":"equipped:"}:
		return failure("content_conditions_unsupported")
	if rules.get("enemy_gold") != "per_enemy_death_then_pickup" or rules.get("enemy_group_total") != "derived_planning_estimate_only" or rules.get("enemy_counts") != "room_authored_planning_reference" or rules.get("enemy_composition") != "room_authored_from_registered_profiles" or rules.get("ordinary_respawn") != "rest_only" or rules.get("single_use_rewards") != true or rules.get("save_kind") != "game_owned_not_web_replay":
		return failure("content_semantics_unsupported")
	var data: Variant = bundle.get("data")
	if not data is Dictionary or data.size() != TABLES.size()+OBJECTS.size(): return failure("content_tables_invalid")
	var indexes := {}
	var counts := {}
	for table_name: String in TABLES:
		if not data.get(table_name) is Array: return failure("content_table_missing",table_name)
		var rows := {}
		for row: Variant in data[table_name]:
			if not row is Dictionary or not row.get("id") is String or row.id.is_empty() or rows.has(row.id):
				return failure("content_identity_invalid",table_name)
			rows[row.id] = row
		indexes[table_name] = rows
		counts[table_name] = rows.size()
	for object_name: String in OBJECTS:
		if not data.get(object_name) is Dictionary: return failure("content_object_missing",object_name)
	if indexes.rooms.is_empty() or indexes.regions.is_empty() or indexes.flags.is_empty() or not indexes.map_layers.has("world"):
		return failure("content_world_empty")
	var zones := {}
	var outlines := {}
	var normals := {}
	for room: Dictionary in indexes.rooms.values():
		if not indexes.regions.has(room.get("region")) or not indexes.map_layers.has(room.get("map_layer")):
			return failure("content_room_reference_invalid",room.id)
		var navigation: Variant = room.get("navigation")
		if not navigation is Dictionary or not navigation.get("polygon") is Array or navigation.polygon.size() < 3 or not _point(navigation.get("label_anchor")):
			return failure("content_layout_invalid",room.id)
		var outline := PackedVector2Array()
		for point: Variant in navigation.polygon:
			if not _point(point): return failure("content_layout_point_invalid",room.id)
			outline.append(Vector2(point[0], point[1]))
		outlines[room.id] = outline
		if not room.get("zones") is Array or not room.get("zone_links") is Array: return failure("content_sections_missing",room.id)
		var local := {}
		for zone: Variant in room.zones:
			if not zone is Dictionary or not zone.get("id") is String or zones.has(zone.id): return failure("content_zone_identity_invalid",room.id)
			zones[zone.id] = room.id
			local[zone.id] = true
		if (not local.is_empty() and not local.has(room.get("default_zone"))) or (local.is_empty() and room.get("default_zone") != null):
			return failure("content_default_zone_invalid",room.id)
		for link: Variant in room.zone_links:
			if not link is Dictionary or not local.has(link.get("from")) or not local.has(link.get("to")) or link.from == link.to:
				return failure("content_zone_link_invalid",room.id)
	for table_name: String in ["abilities","rewards","encounters","events","npcs","dialogues","coin_caches","enemy_groups","observer_hints"]:
		for row: Dictionary in indexes[table_name].values():
			if not _place_valid(row,indexes.rooms,zones): return failure("content_place_invalid",table_name+":"+row.id)
	for door: Dictionary in indexes.doors.values():
		if not indexes.rooms.has(door.get("a")) or not indexes.rooms.has(door.get("b")) or door.a == door.b:
			return failure("content_door_endpoint_invalid",door.id)
		if door.get("connection_type") not in ["physical","interior"] or door.get("one_way_from") not in [null,door.a,door.b]:
			return failure("content_door_kind_invalid",door.id)
		var first_open: bool = door.get("one_way_from") != null
		var has_unlock: bool = door.get("unlock_flag") != null and door.get("unlock_flag") != ""
		if (first_open and not has_unlock) or (has_unlock and not indexes.flags.has(door.unlock_flag)):
			return failure("content_door_unlock_invalid",door.id)
		for endpoint: String in door.get("zone_by_room",{}):
			var zone_id: Variant = door.zone_by_room[endpoint]
			if endpoint not in [door.a,door.b] or (zone_id != null and zones.get(zone_id) != endpoint): return failure("content_door_zone_invalid",door.id)
		if door.connection_type == "physical":
			var mouth: Variant = door.get("door")
			if indexes.rooms[door.a].map_layer != indexes.rooms[door.b].map_layer or not mouth is Dictionary or mouth.get("axis") not in ["h","v"]:
				return failure("content_door_geometry_invalid",door.id)
			for key: String in ["fixed","start","end"]:
				if not (mouth.get(key) is int or mouth.get(key) is float) or not is_finite(mouth[key]): return failure("content_door_geometry_invalid",door.id)
			if mouth.start >= mouth.end: return failure("content_door_geometry_invalid",door.id)
			var direction := _outward_normal(mouth, outlines[door.a])
			if direction == Vector2.ZERO or _outward_normal(mouth, outlines[door.b]) != -direction:
				return failure("content_door_boundary_mismatch", door.id)
			normals[door.id] = direction
		else:
			if door.get("door") != null or indexes.rooms[door.a].map_layer == indexes.rooms[door.b].map_layer or not door.get("entrances") is Dictionary:
				return failure("content_interior_door_invalid",door.id)
			for endpoint: String in [door.a,door.b]:
				if not door.entrances.get(endpoint) is Dictionary or not _point(door.entrances[endpoint].get("anchor")): return failure("content_interior_entrance_invalid",door.id)
	for reward: Dictionary in indexes.rewards.values():
		if reward.get("reward_key") != reward.id or reward.get("permanent_unique") != true: return failure("content_reward_identity_invalid",reward.id)
		if reward.get("catalog_id") != null and not indexes.equipment.has(reward.catalog_id): return failure("content_reward_equipment_invalid",reward.id)
	for event: Dictionary in indexes.events.values():
		if event.get("event") != event.id or not indexes.flags.has(event.id): return failure("content_event_identity_invalid",event.id)
		if event.get("reward_key") != null and not indexes.rewards.has(event.reward_key): return failure("content_event_reward_invalid",event.id)
		if not _integer(event.get("coin_reward",0)): return failure("content_event_coins_invalid",event.id)
		for line: Variant in event.get("dialogue",[]):
			if not line is Dictionary or not indexes.speakers.has(line.get("speaker_id")) or not line.get("text") is String: return failure("content_event_speaker_invalid",event.id)
	for encounter: Dictionary in indexes.encounters.values():
		if not indexes.flags.has(encounter.get("completion_flag")) or not _integer(encounter.get("coin_reward",0)): return failure("content_encounter_invalid",encounter.id)
		for reward_id: Variant in encounter.get("reward_refs",[]):
			if not indexes.rewards.has(reward_id): return failure("content_encounter_reward_invalid",encounter.id)
	for speaker: Dictionary in indexes.speakers.values():
		if speaker.get("kind") not in ["npc","record"] or (speaker.kind == "npc" and not indexes.npcs.has(speaker.get("npc_id"))): return failure("content_speaker_invalid",speaker.id)
	for dialogue: Dictionary in indexes.dialogues.values():
		if not indexes.speakers.has(dialogue.get("speaker_id")) or not dialogue.get("lines") is Array: return failure("content_dialogue_invalid",dialogue.id)
	for quest: Dictionary in indexes.quests.values():
		if not indexes.npcs.has(quest.get("giver_id")) or not indexes.events.has(quest.get("accept_event")) or not indexes.events.has(quest.get("completion_event")):
			return failure("content_quest_reference_invalid",quest.id)
		if not quest.get("steps") is Array or quest.steps.is_empty(): return failure("content_quest_steps_invalid",quest.id)
		for step: Variant in quest.steps:
			if not step is Dictionary or not indexes.events.has(step.get("event")) or not _place_valid(step,indexes.rooms,zones): return failure("content_quest_step_invalid",quest.id)
			var event: Dictionary = indexes.events[step.event]
			if step.room != event.room or step.get("zone") != event.get("zone"): return failure("content_quest_step_place_invalid",quest.id)
	for ending: Dictionary in indexes.endings.values():
		if not indexes.rooms.has(ending.get("target")) or ending.get("requires_explicit_terminal_interaction") != true: return failure("content_ending_invalid",ending.id)
	for item: Dictionary in indexes.equipment.values():
		if not _integer(item.get("load")) or not _integer(item.get("max_level"),1) or not item.get("upgrade_prices") is Dictionary: return failure("content_equipment_invalid",item.id)
		if item.upgrade_prices.size() != int(item.max_level)-1: return failure("content_upgrade_prices_incomplete",item.id)
		for level: int in range(2,int(item.max_level)+1):
			if not _integer(item.upgrade_prices.get(str(level)),1): return failure("content_upgrade_price_invalid",item.id)
	for offer: Dictionary in indexes.shops.values():
		if not indexes.npcs.has(offer.get("npc_id")) or not indexes.rewards.has(offer.get("reward_key")) or not _integer(offer.get("price"),1): return failure("content_shop_invalid",offer.id)
	for cache: Dictionary in indexes.coin_caches.values():
		if not _integer(cache.get("amount"),1) or cache.get("one_time") != true: return failure("content_coin_cache_invalid",cache.id)
	var profile_pairs := {}
	for profile: Dictionary in indexes.enemy_drop_profiles.values():
		if profile.size() != 4 or not indexes.enemy_species.has(profile.get("species_id")) or not _integer(profile.get("tier")) or not _integer(profile.get("coin_each"),1):
			return failure("content_enemy_drop_profile_invalid",profile.id)
		var pair: String = profile.species_id+":"+str(int(profile.tier))
		if profile_pairs.has(pair): return failure("content_enemy_drop_profile_duplicate",profile.id)
		profile_pairs[pair] = true
	for group: Dictionary in indexes.enemy_groups.values():
		if group.get("respawn") != "rest" or not _integer(group.get("fixed_drop_tier")) or not group.get("enemies") is Array or group.enemies.is_empty(): return failure("content_enemy_group_invalid",group.id)
		var total := 0
		for enemy: Variant in group.enemies:
			if not enemy is Dictionary or not indexes.enemy_species.has(enemy.get("species_id")) or not _integer(enemy.get("count"),1) or not _integer(enemy.get("coin_each"),1): return failure("content_enemy_species_invalid",group.id)
			if not indexes.enemy_drop_profiles.has(enemy.get("drop_profile_id")): return failure("content_enemy_drop_profile_unknown",group.id)
			var profile: Dictionary = indexes.enemy_drop_profiles[enemy.drop_profile_id]
			if profile.species_id != enemy.species_id or profile.coin_each != enemy.coin_each or profile.tier != group.fixed_drop_tier: return failure("content_enemy_drop_profile_mismatch",group.id)
			total += int(enemy.count)*int(enemy.coin_each)
		if group.get("coin_reward") != total: return failure("content_enemy_total_invalid",group.id)
	if not _conditions_valid(data,indexes): return failure("content_condition_unknown")
	if not bundle.get("required_bindings") is Array: return failure("content_bindings_missing")
	var kinds := {"room":"rooms","npc":"npcs","enemy_species":"enemy_species","equipment_effect":"equipment","event_trigger":"events"}
	var seen_bindings := {}
	var expected_bindings := 0
	for kind: String in kinds: expected_bindings += indexes[kinds[kind]].size()
	for required: Variant in bundle.required_bindings:
		if not required is Dictionary or not kinds.has(required.get("kind")) or not indexes[kinds[required.kind]].has(required.get("id")): return failure("content_binding_unknown")
		var key: String = required.kind+":"+required.id
		if seen_bindings.has(key): return failure("content_binding_duplicate",key)
		seen_bindings[key] = true
	if seen_bindings.size() != expected_bindings: return failure("content_binding_incomplete")
	return {"ok":true,"tables":indexes,"counts":counts,"physical_normals":normals}

func table(table_name: String) -> Dictionary:
	if _bundle.is_empty(): return failure("content_not_loaded")
	if not _tables.has(table_name): return failure("content_table_unknown",table_name)
	return {"ok":true,"rows":_tables[table_name].values().duplicate(true)}

func object(object_name: String) -> Dictionary:
	if _bundle.is_empty(): return failure("content_not_loaded")
	if object_name not in OBJECTS: return failure("content_object_unknown",object_name)
	return {"ok":true,"value":_bundle.data[object_name].duplicate(true)}

func lookup(table_name: String, id: String) -> Dictionary:
	if _bundle.is_empty(): return failure("content_not_loaded")
	if not _tables.has(table_name): return failure("content_table_unknown",table_name)
	if not _tables[table_name].has(id): return failure("content_id_unknown",table_name+":"+id)
	return {"ok":true,"row":_tables[table_name][id].duplicate(true)}

## The seam is drawn along the boundary. Its normal points out of this room;
## the endpoint order and either room's bounding-box center do not define it.
static func _outward_normal(mouth: Dictionary, outline: PackedVector2Array) -> Vector2:
	var middle := (float(mouth.start) + float(mouth.end)) * 0.5
	var horizontal: bool = mouth.axis == "h"
	var center := Vector2(middle, mouth.fixed) if horizontal else Vector2(mouth.fixed, middle)
	var normal := Vector2.DOWN if horizontal else Vector2.RIGHT
	# Sample either side, in planning units, clear of polygon boundary rounding.
	var probe := normal * minf(0.001, (float(mouth.end) - float(mouth.start)) * 0.01)
	var positive := Geometry2D.is_point_in_polygon(center + probe, outline)
	var negative := Geometry2D.is_point_in_polygon(center - probe, outline)
	if positive == negative: return Vector2.ZERO
	return normal if negative else -normal

func physical_passage(room_id: String, door_id: String) -> Dictionary:
	var row: Dictionary = _tables.get("doors", {}).get(door_id, {})
	if room_id not in [row.get("a"), row.get("b")]: return failure("content_door_not_in_room", room_id + "/" + door_id)
	if not _physical_normals.has(door_id): return failure("content_door_not_physical", room_id + "/" + door_id)
	var from_a: bool = room_id == row.a
	var normal: Vector2 = _physical_normals[door_id]
	return {"ok":true, "direction":normal if from_a else -normal, "destination":row.b if from_a else row.a, "seam":row.door.duplicate(true)}

## Walking through a held shortcut requires its committed world fact on both
## sides. Pulling its latch is a separate, side-specific action.
func passage_access(room_id: String, door_id: String, flags: Array, equipped: Array = []) -> Dictionary:
	var passage := physical_passage(room_id,door_id)
	if not passage.ok: return {"ok":false,"matches":false,"error":passage.error}
	var door: Dictionary = _tables.doors[door_id]
	var result := condition_match(door,flags,equipped)
	if not result.ok: return {"ok":false,"matches":false,"error":result.error}
	var unlock: Variant = door.get("unlock_flag")
	if unlock != null and unlock not in flags:
		if unlock not in result.missing: result.missing.append(unlock)
		result.matches = false
	return result

func shortcut_candidate(state: FixedWorldState, room_id: String, door_id: String) -> Dictionary:
	var found := lookup("doors",door_id)
	if not found.ok or state.value.room != room_id: return {}
	var door: Dictionary = found.row
	var unlock: Variant = door.get("unlock_flag")
	if door.get("one_way_from") != room_id or unlock == null or state.has(unlock): return {}
	var eligible := condition_match(door,state.value.flags,state.value.services.equipped)
	if not eligible.ok or not eligible.matches: return {}
	var candidate := state.candidate()
	candidate.flags.append(unlock)
	candidate.receipts[unlock] = {"source":unlock,"source_hash":MetaSaveService.canonical_json(door).sha256_text(),"revision":state.revision+1}
	return candidate

func connections(room_id: String) -> Dictionary:
	var checked := lookup("rooms",room_id)
	if not checked.ok: return checked
	var rows: Array = []
	for door: Dictionary in _tables.doors.values():
		if door.a == room_id or door.b == room_id: rows.append(door.duplicate(true))
	return {"ok":true,"rows":rows}

func room_context(room_id: String) -> Dictionary:
	var checked := lookup("rooms",room_id)
	if not checked.ok: return checked
	var result := {"ok":true,"room":checked.row,"connections":connections(room_id).rows,"coordinate_system":_bundle.coordinate_system.duplicate(true),"layout_authority":"locked_construction_bounds_and_openings","instance_placement_authority":"schema3_room_document","enemy_count_authority":"schema3_room_document","enemy_roster_authority":"schema3_room_document","enemy_gold_authority":"enemy_drop_profiles","bundle_sha256":bundle_sha256,"content_version":content_version}
	for table_name: String in ["abilities","rewards","encounters","events","npcs","dialogues","coin_caches","enemy_groups","observer_hints"]:
		var rows: Array = []
		for row: Dictionary in _tables[table_name].values():
			var local: bool = row.get("room") == room_id
			for site: Dictionary in row.get("interaction_sites",[]):
				local = local or site.room == room_id
			if local: rows.append(row.duplicate(true))
		result[table_name] = rows
	return result

func condition_match(row: Dictionary, flags: Array, equipped: Array = []) -> Dictionary:
	if _bundle.is_empty(): return failure("content_not_loaded")
	if not _conditions_valid(row,_tables): return failure("content_condition_unknown")
	var missing: Array = []
	var excluded: Array = []
	for flag: String in row.get("requires",[]):
		var present := flag.substr(9) in equipped if flag.begins_with("equipped:") else flag in flags
		if not present: missing.append(flag)
	for flag: String in row.get("excludes",[]):
		var present := flag.substr(9) in equipped if flag.begins_with("equipped:") else flag in flags
		if present: excluded.append(flag)
	return {"ok":true,"matches":missing.is_empty() and excluded.is_empty(),"missing":missing,"excluded":excluded}

func dialogues_for(room_id: String, flags: Array, equipped: Array = [], zone: Variant = null) -> Dictionary:
	var checked := lookup("rooms",room_id)
	if not checked.ok: return checked
	var selected := {}
	for row: Dictionary in _tables.dialogues.values():
		if row.room != room_id or (row.get("zone") != null and row.zone != zone): continue
		var match_result := condition_match(row,flags,equipped)
		if not match_result.ok: return match_result
		if not match_result.matches: continue
		var speaker: String = row.speaker_id
		if not selected.has(speaker) or row.priority >= selected[speaker].priority: selected[speaker] = row
	return {"ok":true,"rows":selected.values().duplicate(true)}

func quest_status(quest_id: String, flags: Array) -> Dictionary:
	var checked := lookup("quests",quest_id)
	if not checked.ok: return checked
	var quest: Dictionary = checked.row
	var accepted: bool = quest.accept_event in flags
	var completed: bool = quest.completion_event in flags
	var discovered: bool = accepted or completed
	var steps: Array = []
	var unfinished: Variant = null
	for step: Dictionary in quest.steps:
		var done: bool = step.event in flags
		var value := step.duplicate(true)
		value.done = done
		steps.append(value)
		if unfinished == null and not done: unfinished = value
		if done and _tables.events[step.event].get("interaction_kind") == "side_quest": discovered = true
	var next: Variant = null
	if not completed:
		if not accepted: next = _tables.events[quest.accept_event].duplicate(true)
		elif unfinished != null: next = unfinished
		else: next = _tables.events[quest.completion_event].duplicate(true)
	return {"ok":true,"quest":quest,"steps":steps,"accepted":accepted,"completed":completed,"discovered":discovered,"next":next}

func shop_quote(offer_id: String) -> Dictionary:
	var checked := lookup("shops",offer_id)
	if not checked.ok: return checked
	var offer: Dictionary = checked.row
	var reward: Dictionary = _tables.rewards[offer.reward_key]
	var equipment_id: String = reward.catalog_id if reward.get("catalog_id") is String else ""
	return {"ok":true,"offer_id":offer_id,"price":int(offer.price),"equipment_id":equipment_id,"reward_id":reward.id,"npc_id":offer.npc_id,"requires":offer.get("requires",[]).duplicate(),"bundle_sha256":bundle_sha256}

func upgrade_quote(equipment_id: String, target_level: int) -> Dictionary:
	var checked := lookup("equipment",equipment_id)
	if not checked.ok: return checked
	var item: Dictionary = checked.row
	if target_level < 2 or target_level > int(item.max_level) or not item.upgrade_prices.has(str(target_level)):
		return failure("upgrade_target_invalid",equipment_id+":"+str(target_level))
	return {"ok":true,"equipment_id":equipment_id,"target_level":target_level,"price":int(item.upgrade_prices[str(target_level)]),"bundle_sha256":bundle_sha256}

func enemy_drop_profile(profile_id: String) -> Dictionary:
	var checked := lookup("enemy_drop_profiles",profile_id)
	if not checked.ok: return checked
	var profile: Dictionary = checked.row
	return {"ok":true,"profile_id":profile.id,"species_id":profile.species_id,"tier":int(profile.tier),"coin_each":int(profile.coin_each),"bundle_sha256":bundle_sha256}

## Planning compatibility query only. Runtime entities select a drop profile
## directly; the authored room owns the roster, count and placement.
func enemy_drop(group_id: String, species_id: String) -> Dictionary:
	var checked := lookup("enemy_groups",group_id)
	if not checked.ok: return checked
	var group: Dictionary = checked.row
	var count := 0
	var amount := -1
	var profile_id := ""
	for enemy: Dictionary in group.enemies:
		if enemy.species_id != species_id: continue
		if amount >= 0 and (amount != int(enemy.coin_each) or profile_id != enemy.drop_profile_id): return failure("enemy_drop_ambiguous",group_id+":"+species_id)
		count += int(enemy.count)
		amount = int(enemy.coin_each)
		profile_id = enemy.drop_profile_id
	if count == 0: return failure("enemy_species_not_in_group",group_id+":"+species_id)
	return {"ok":true,"coin_each":amount,"profile_id":profile_id,"planned_count":count,"count":count,"count_is_planning_only":true,"room_id":group.room,"group_id":group_id,"species_id":species_id,"respawn":group.respawn,"bundle_sha256":bundle_sha256}

func load_bindings(path: String, allow_test_bindings: bool = false) -> Dictionary:
	if _bundle.is_empty(): return failure("content_not_loaded")
	var read_bindings := _read(path)
	if not read_bindings.ok: return read_bindings
	var candidate: Dictionary = read_bindings.value
	if candidate.get("format") != "clock-world-runtime-bindings" or candidate.get("schema_version") != SCHEMA or candidate.get("world_id") != WORLD_ID:
		return failure("content_bindings_unsupported")
	for section: String in BINDING_TABLES:
		if not candidate.get(section) is Dictionary: return failure("binding_section_missing",section)
		for id: String in candidate[section]:
			if not _tables[BINDING_TABLES[section]].has(id) or not candidate[section][id] is Dictionary:
				return failure("binding_unknown_id",section+":"+id)
	for room_id: String in candidate.rooms:
		var checked := _check_room_document(candidate.rooms[room_id],room_id,allow_test_bindings)
		if not checked.ok: return checked
	_bindings = candidate
	_bindings_path = path
	_allow_test_bindings = allow_test_bindings
	return {"ok":true,"rooms_bound":_bindings.rooms.size(),"path":path}

static func _check_room_document(binding: Dictionary, room_id: String, allow_tests: bool) -> Dictionary:
	var path: Variant = binding.get("document_path")
	if not path is String or not (path.begins_with("res://rooms/") or path.begins_with("res://tests/")) or not path.ends_with(".json") or not _relative(path.substr(6)):
		return failure("room_binding_path_invalid",room_id)
	var status: Variant = binding.get("status")
	if status not in ["authored","placeholder","integration_test"]: return failure("room_binding_status_invalid",room_id)
	if status == "integration_test" and not allow_tests: return failure("integration_test_binding_not_playable",room_id)
	if status == "placeholder" and path != "res://rooms/world/receivers/%s.json" % room_id:
		return failure("room_reception_path_invalid",room_id)
	if status == "authored" and path != "res://rooms/world/%s.json" % room_id:
		return failure("room_authored_path_invalid",room_id)
	var read_document := _read(path)
	if not read_document.ok: return read_document
	var document: Dictionary = read_document.value
	if document.get("schema") != 3 or document.get("room_id") != room_id or not document.get("root") is Dictionary or not document.get("entities") is Dictionary:
		return failure("room_binding_document_invalid",room_id)
	if document.get("reception",false) != (status == "placeholder"):
		return failure("room_reception_status_mismatch",room_id)
	return {"ok":true,"path":path,"status":status}

func room_document(room_id: String) -> Dictionary:
	var checked := lookup("rooms",room_id)
	if not checked.ok: return checked
	if _bindings.is_empty() or not _bindings.rooms.has(room_id): return failure("room_not_bound",room_id)
	return _check_room_document(_bindings.rooms[room_id],room_id,_allow_test_bindings)

func binding(section: String, id: String) -> Dictionary:
	if section not in BINDING_TABLES: return failure("binding_section_unknown",section)
	var checked := lookup(BINDING_TABLES[section],id)
	if not checked.ok: return checked
	if _bindings.is_empty() or not _bindings[section].has(id): return failure("content_not_bound",section+":"+id)
	return {"ok":true,"row":_bindings[section][id].duplicate(true)}

func bound_definition(section: String, id: String) -> Dictionary:
	var checked := binding(section,id)
	if not checked.ok: return checked
	var definition_id: Variant = checked.row.get("definition_id")
	if not definition_id is String or definition_id.is_empty(): return failure("binding_definition_missing",section+":"+id)
	var read_registry := _read("res://config/world_elements/index.json")
	if not read_registry.ok: return read_registry
	var registry: Dictionary = read_registry.value
	if not registry.get("definitions") is Dictionary or not registry.definitions.has(definition_id): return failure("binding_definition_unregistered",definition_id)
	var path: Variant = registry.definitions[definition_id]
	if not path is String or not path.begins_with("res://config/world_elements/definitions/") or not _relative(path.substr(6)):
		return failure("binding_definition_path_invalid",definition_id)
	var read_definition := _read(path)
	if not read_definition.ok: return read_definition
	if read_definition.value.get("id") != definition_id or not _integer(read_definition.value.get("version"),1):
		return failure("binding_definition_identity_invalid",definition_id)
	if section == "enemy_species" and not definition_id.begins_with("enemy."):
		return failure("binding_enemy_definition_required",definition_id)
	return {"ok":true,"definition_id":definition_id,"definition_version":int(read_definition.value.version)}
