class_name RunManifest
extends RefCounted

const SCHEMA_VERSION := 1
const FOREST_GENERATOR := preload("res://scripts/generation/thorn_forest_region_generator.gd")
var _data: Dictionary = {}

func _init(seed := "0", profile: RunProfile = null) -> void:
	if profile == null:
		profile = RunProfile.development()
	_data = {"schema_version": SCHEMA_VERSION, "root_seed": seed, "rng_algorithm": RunRandomStream.ALGORITHM, "stream_derivation_version": RunRandomStream.DERIVATION_VERSION, "run_profile": {"id": String(profile.profile_id), "version": profile.definition_version, "development_only": profile.development_only, "stages_per_biome": profile.stages_per_biome, "boss_stage": profile.boss_stage}, "versions": {"route": 1, "reward": 2, "shop": 1, "fixed_layout": 1, "damage_policy": "D028_v1", "boss_outcome_policy": "D029_v1", "run_policy": "DEMO_NO_TRANSFER_v1"}, "content_manifest": [], "config_hashes": {}, "initial_character": {}, "stages": [], "decisions": [], "end": {}}

func enable_development_generation(content_version: String) -> void:
	# Independent world candidates are live development fixtures, never old rooms.
	# Preserve their actual content identity without claiming restorable run data.
	_data.versions.erase("fixed_layout")
	_data.versions.generated_layout = content_version
	_data.versions.run_policy = "DEVELOPMENT_GENERATED_FIXTURE_v1"

func enable_plains_region(content_version: String = PlainsRegionGenerator.VERSION) -> bool:
	var campaign := int(_data.schema_version) == 2
	if content_version not in [PlainsRegionGenerator.VERSION, PlainsRootBellEncounterV2.CONTENT_VERSION, PlainsRootBellEncounterV3.CONTENT_VERSION]:
		return false
	_data.versions.erase("fixed_layout")
	_data.versions.generated_layout = content_version
	_data.versions.pickups = "plains-region-pickups-v1"
	_data.versions.encounters = content_version
	_data.versions.run_policy = "PLAINS_TWO_MAPS_BANK_NOTES_v1"
	if campaign:
		_data.legacy_versions = _data.versions.duplicate(true)
		_data.versions.run_policy = "TWO_REGION_CAMPAIGN_v1"
	return true

func enable_campaign() -> void:
	if int(_data.schema_version) == 2: return
	_data.schema_version = 2
	_data.legacy_versions = _data.versions.duplicate(true)
	_data.versions.run_policy = "TWO_REGION_CAMPAIGN_v1"

func append_stage(index: int, type_id: StringName, biome_id: StringName, offers: Array[ExitOffer]) -> void:
	var exits: Array = []
	for offer: ExitOffer in offers:
		exits.append(offer.to_data())
	_data.stages.append({"stage_index": index, "stage_id": "stage_%s" % index, "type_id": String(type_id), "biome_id": String(biome_id), "offers": exits, "outputs": {}})

func record_output(stage_index: int, category: StringName, actual_output: Variant) -> bool:
	if stage_index < 1 or stage_index > _data.stages.size() or category.is_empty():
		return false
	var outputs: Dictionary = _data.stages[stage_index - 1].outputs
	var key := String(category)
	if outputs.has(key):
		return outputs[key] == actual_output
	outputs[key] = actual_output.duplicate(true) if actual_output is Dictionary or actual_output is Array else actual_output
	return true

func record_configuration(content_manifest: Array, config_hashes: Dictionary, initial_character: Dictionary) -> void:
	_data.content_manifest = content_manifest.duplicate(true)
	_data.config_hashes = config_hashes.duplicate(true)
	_data.initial_character = initial_character.duplicate(true)

func select(offer: ExitOffer, selection_id: StringName) -> void:
	_data.decisions.append({"selection_id": String(selection_id), "offer": offer.to_data()})

func end(reason: StringName, end_id: StringName) -> void:
	if _data.end.is_empty():
		_data.end = {"reason": String(reason), "end_id": String(end_id)}

func snapshot() -> Dictionary:
	return _data.duplicate(true)

func canonical_json() -> String:
	return JSON.stringify(_data, "", true)

static func from_snapshot(data: Dictionary) -> RunManifest:
	if not compatible(data):
		return null
	var result := RunManifest.new()
	result._data = data.duplicate(true)
	return result

static func compatible(data: Dictionary) -> bool:
	if int(data.get("schema_version",-1)) == 2: return _campaign_compatible(data)
	if not data.get("root_seed") is String or not data.get("stages") is Array or not data.get("decisions") is Array or not data.get("run_profile") is Dictionary:
		return false
	var stored: Dictionary = data.run_profile
	var profile := RunProfile.new()
	profile.profile_id = StringName(stored.get("id", ""))
	profile.definition_version = stored.get("version", -1)
	profile.development_only = stored.get("development_only", false)
	profile.stages_per_biome = stored.get("stages_per_biome", -1)
	profile.boss_stage = stored.get("boss_stage", -1)
	if not profile.is_valid() or data.stages.size() > profile.stages_per_biome:
		return false
	var definitions := StageTypeDefinition.registry()
	for index: int in data.stages.size():
		var entry: Variant = data.stages[index]
		if not entry is Dictionary or entry.get("stage_index", -1) != index + 1 or not definitions.has(StringName(entry.get("type_id", ""))):
			return false
		if index + 1 == profile.boss_stage and entry.type_id != "boss":
			return false
	var fixed_versions := {"route": 1, "reward": 2, "shop": 1, "fixed_layout": 1, "damage_policy": "D028_v1", "boss_outcome_policy": "D029_v1", "run_policy": "DEMO_NO_TRANSFER_v1"}
	var region_versions := fixed_versions.duplicate(true)
	region_versions.erase("fixed_layout")
	var declared_versions: Variant = data.get("versions", {})
	var region_version := PlainsRegionGenerator.VERSION
	if declared_versions is Dictionary and declared_versions.get("generated_layout") in [PlainsRootBellEncounterV2.CONTENT_VERSION, PlainsRootBellEncounterV3.CONTENT_VERSION]:
		region_version = str(declared_versions.generated_layout)
	region_versions.generated_layout = region_version
	region_versions.pickups = "plains-region-pickups-v1"
	region_versions.encounters = region_version
	region_versions.run_policy = "PLAINS_TWO_MAPS_BANK_NOTES_v1"
	if _versions_equal(data.get("versions", {}), region_versions):
		if profile.profile_id != &"formal_plains_region" or data.stages.is_empty() or not data.decisions.is_empty(): return false
		var checker:=RandomStageGenerator.new()
		var tuning_keys: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://config/player_tuning.json"))
		for entry: Dictionary in data.stages:
			var index: int=entry.stage_index
			var output: Dictionary = entry.get("outputs", {})
			var m: Dictionary = output.get("generated_layout", {})
			var tuning:=_region_tuning(output)
			if tuning==null:return false
			if entry.get("biome_id")!="plains" or entry.get("type_id")!="boss" or not entry.get("offers",[]).is_empty(): return false
			if output.get("stage_generator",{}).get("version")!=region_version or m.get("version")!=region_version: return false
			var identity: Dictionary={"version":PlainsRegionCampaign.VERSION,"map_index":index,"seed":PlainsRegionCampaign.seed_for(data.root_seed,index),"instance_prefix":PlainsRegionCampaign.prefix(index),"boss_role":PlainsRegionCampaign.role(index)}
			if not checker._same_data(output.get("region_map",{}),identity): return false
			if m.get("seed")!=identity.seed or m.get("difficulty")!=("intro" if index==1 else "advanced"): return false
			if not checker._same_data(output.get("shot_latch_layout",{}),m.get("shot_latch_plan",{})): return false
			if not checker._same_data(output.get("enemy_layout",{}),{"version":region_version,"enemies":m.get("enemies",[])}): return false
			if not output.get("stage_tuning") is Dictionary: return false
			for key: String in tuning_keys:
				if not output.stage_tuning.has(key): return false
				if not checker._same_data(output.stage_tuning[key],tuning.get(key)): return false
			if not PlainsRegionGenerator.new().validate(m,tuning): return false
			if not _plains_boss_output_compatible(output,index): return false
		if data.stages.size()==2:
			var transition: Dictionary=data.stages[0].outputs.get("map_transition",{})
			if transition.get("from_map")!=1 or transition.get("to_map")!=2 or transition.get("reason")!="mini_boss_defeated": return false
		return data.schema_version==SCHEMA_VERSION and data.rng_algorithm==RunRandomStream.ALGORITHM and data.stream_derivation_version==RunRandomStream.DERIVATION_VERSION
	return _versions_equal(data.get("versions", {}), fixed_versions) and data.get("schema_version", -1) == SCHEMA_VERSION and data.get("rng_algorithm", "") == RunRandomStream.ALGORITHM and data.get("stream_derivation_version", -1) == RunRandomStream.DERIVATION_VERSION

static func _plains_boss_output_compatible(output: Dictionary, index: int) -> bool:
	var definition: BossDefinition = load("res://resources/bosses/bellstrider.tres" if index==1 else "res://resources/bosses/windkeeper_storm.tres")
	var checker := RandomStageGenerator.new()
	if checker._same_data(output.get("boss_layout",{}),{"id":String(definition.stable_id),"version":definition.definition_version,"health":definition.health_definition.max_health}): return true
	# The caller has validated the full tuning, manifest and map identity. All
	# three supported Plains versions also recorded these exact Boss definitions
	# before continuous combat, under both supported focus configurations.
	# Replay that metadata unchanged; runtime still loads current definitions.
	var layout: Dictionary = output.get("generated_layout",{})
	if layout.get("version") not in [PlainsRegionGenerator.VERSION,PlainsRootBellEncounterV2.CONTENT_VERSION,PlainsRootBellEncounterV3.CONTENT_VERSION]: return false
	var historical := {"id":"plains_bellstrider","version":1,"health":16.0} if index==1 else {"id":"plains_windkeeper","version":4,"health":36.0}
	return checker._same_data(output.get("boss_layout",{}),historical)

static func _versions_equal(stored: Variant, expected: Dictionary) -> bool:
	if not stored is Dictionary or stored.size() != expected.size():
		return false
	for key: String in expected:
		if not stored.has(key):
			return false
		if expected[key] is int:
			if not (stored[key] is float or stored[key] is int) or not is_finite(float(stored[key])) or float(stored[key]) != float(expected[key]):
				return false
		elif stored[key] != expected[key]:
			return false
	return true

static func _region_tuning(output:Dictionary)->PlayerTuning:
	# Rebuild legitimate item modifiers; never trust arbitrary edited tuning.
	var capability:Variant=output.get("capability_snapshot",{})
	if not capability is Dictionary:return null
	var items:Variant=capability.get("items",[])
	if not items is Array:return null
	var tuning:=PlayerTuning.load_default()
	var stored: Variant=output.get("stage_tuning")
	var keys: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://config/player_tuning.json"))
	if not stored is Dictionary or stored.size()!=keys.size():return null
	# Keep immutable saved metadata at .2; runtime always loads current .15.
	# The sole historical exception is bound to the exact pre-change config.
	if output.get("generated_layout",{}).get("player_tuning_hash")==PlainsRegionGenerator.PRE_FOCUS_15_TUNING_HASH and stored.get("focus_time_scale")==0.2:
		tuning.focus_time_scale=0.2
	var build:=BuildState.new()
	for stat:StringName in BuildState.STATS:
		build._base[stat]=5.0 if stat==&"max_health" else tuning.get(stat)
	var sources:Dictionary={};var counts:Dictionary={}
	for index:int in items.size():
		if not (items[index] is String or items[index] is StringName) or not str(items[index]).is_valid_identifier():return null
		var path:="res://resources/items/%s.tres"%items[index]
		if not ResourceLoader.exists(path):return null
		var item:=load(path) as ItemDefinition
		if item==null or item is ResourceRewardChoice or not item.is_valid() or str(item.stable_id)!=str(items[index]):return null
		counts[item.stable_id]=int(counts.get(item.stable_id,0))+1
		if counts[item.stable_id]>item.stack_limit or (counts[item.stable_id]>1 and item.duplicate_policy==ItemDefinition.DuplicatePolicy.REJECT):return null
		sources[StringName("manifest_%08d"%index)]=item
	var values:=build._resolve(sources)
	for stat:StringName in BuildState.STATS:
		if stat==&"max_health":continue
		if not is_finite(float(values[stat])) or float(values[stat])<0:return null
		tuning.set(stat,int(values[stat]) if stat in [&"max_jumps",&"max_air_shots"] else values[stat])
	var checker:=RandomStageGenerator.new()
	for key: String in keys:
		if not stored.has(key) or not checker._same_data(stored[key],tuning.get(key)):return null
	return tuning

static func _campaign_compatible(data: Dictionary) -> bool:
	if not data.get("root_seed") is String or not data.get("stages") is Array or not data.get("decisions") is Array or not data.get("versions") is Dictionary: return false
	if data.versions.get("run_policy") != "TWO_REGION_CAMPAIGN_v1" or data.stages.is_empty() or data.stages.size() > 4 or not data.decisions.is_empty(): return false
	var formal := RunProfile.formal()
	var expected_profile := {"id":String(formal.profile_id),"version":formal.definition_version,"development_only":false,"stages_per_biome":formal.stages_per_biome,"boss_stage":formal.boss_stage}
	if not RandomStageGenerator.new()._same_data(data.get("run_profile"),expected_profile): return false
	var debug := false
	var seen_forest := false
	var forest_content_version := ""
	var plains: Array = []
	var previous_map := 0
	var previous_region := ""
	for ordinal: int in data.stages.size():
		var entry: Variant = data.stages[ordinal]
		if not entry is Dictionary or entry.get("stage_index") != ordinal+1 or entry.get("type_id") != "boss" or not entry.get("offers") is Array or not entry.offers.is_empty() or not entry.get("outputs") is Dictionary: return false
		var output: Dictionary = entry.outputs
		if ordinal == 0 and output.has("debug_entry"):
			if not output.debug_entry is Dictionary: return false
			var debug_record: Dictionary = output.debug_entry
			if debug_record.get("natural_progression") != false or debug_record.get("region") != entry.get("biome_id"): return false
			debug = true
		var region := str(entry.get("biome_id",""))
		if not output.get("region_map") is Dictionary: return false
		var identity: Dictionary = output.region_map
		var map_number: Variant = identity.get("map_index")
		if not (map_number is int or map_number is float) or not is_finite(float(map_number)) or float(map_number)!=float(int(map_number)): return false
		var map_index := int(map_number)
		if identity.get("boss_role") != PlainsRegionCampaign.role(map_index): return false
		if ordinal==0 and debug and int(output.debug_entry.get("map_index",0)) != map_index: return false
		if map_index not in [1,2] or (ordinal==0 and not debug and (region != "plains" or map_index != 1)): return false
		if ordinal > 0:
			if region == previous_region and (previous_map != 1 or map_index != 2): return false
			if region != previous_region and (previous_region != "plains" or previous_map != 2 or region != "thorn_forest" or map_index != 1): return false
			if region != previous_region:
				var prior: Dictionary = data.stages[ordinal-1].outputs
				if not prior.get("core_ability_reward") is Dictionary or not prior.get("region_transition") is Dictionary: return false
				if prior.get("core_ability_reward",{}).get("ability") != "grapple" or prior.get("region_transition",{}).get("to") != "thorn_forest": return false
		previous_region = region
		previous_map = map_index
		if region == "plains":
			if seen_forest: return false
			plains.append(entry.duplicate(true))
			if debug:
				if not output.get("generated_layout") is Dictionary: return false
				var m: Dictionary = output.generated_layout
				var tuning := _region_tuning(output)
				if tuning == null or not PlainsRegionGenerator.new().validate(m,tuning): return false
				if identity.get("seed") != PlainsRegionCampaign.seed_for(data.root_seed,map_index) or m.get("seed") != identity.get("seed"): return false
				if m.get("difficulty") != ("intro" if map_index == 1 else "advanced"): return false
		elif region == "thorn_forest":
			seen_forest = true
			if not output.get("generated_layout") is Dictionary or not output.get("stage_tuning") is Dictionary or not output.get("stage_generator") is Dictionary or not output.get("capability_snapshot") is Dictionary: return false
			var m: Dictionary = output.generated_layout
			var tuning := _region_tuning(output)
			var version: String = str(m.get("version",""))
			if not FOREST_GENERATOR.supported(version): return false
			if forest_content_version.is_empty(): forest_content_version = version
			elif forest_content_version != version: return false
			if tuning == null or output.get("stage_generator",{}).get("version") != version: return false
			if identity.get("seed") != FOREST_GENERATOR.seed_for(data.root_seed,map_index) or identity.get("instance_prefix") != "thorn_forest/map_%s/" % map_index or identity.get("version") != version: return false
			var abilities: Variant = output.get("capability_snapshot",{}).get("abilities",[])
			if not abilities is Array or abilities.size()!=1 or not (abilities[0] is String or abilities[0] is StringName) or str(abilities[0])!="grapple": return false
			if m.get("seed") != identity.get("seed") or m.get("map_index") != map_index: return false
			if not FOREST_GENERATOR.new().validate(m,tuning): return false
			var tuning_keys: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/player_tuning.json"))
			var checker := RandomStageGenerator.new()
			var boss_path: String = FOREST_GENERATOR.boss_definition_path(version,map_index,m)
			if boss_path.is_empty(): return false
			var boss_definition: BossDefinition = load(boss_path)
			if not checker._same_data(output.get("boss_layout"),{"id":String(boss_definition.stable_id),"version":boss_definition.definition_version,"health":boss_definition.health_definition.max_health}): return false
			if not checker._same_data(output.get("enemy_layout"),{"version":version,"enemies":m.enemies}): return false
			if not checker._same_data(output.get("shot_latch_layout"),m.shot_latch_plan): return false
			for key: String in tuning_keys:
				if not checker._same_data(output.get("stage_tuning",{}).get(key),tuning.get(key)): return false
		else: return false
	if not plains.is_empty() and not debug:
		var legacy := data.duplicate(true)
		legacy.schema_version = SCHEMA_VERSION
		legacy.versions = data.get("legacy_versions",{}).duplicate(true)
		legacy.stages = plains
		legacy.erase("legacy_versions")
		if not compatible(legacy): return false
	return data.get("rng_algorithm") == RunRandomStream.ALGORITHM and data.get("stream_derivation_version") == RunRandomStream.DERIVATION_VERSION
