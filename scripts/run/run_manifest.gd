class_name RunManifest
extends RefCounted

const SCHEMA_VERSION := 1
var _data: Dictionary = {}

func _init(seed := "0", profile: RunProfile = null) -> void:
	if profile == null:
		profile = RunProfile.development()
	_data = {"schema_version": SCHEMA_VERSION, "root_seed": seed, "rng_algorithm": RunRandomStream.ALGORITHM, "stream_derivation_version": RunRandomStream.DERIVATION_VERSION, "run_profile": {"id": String(profile.profile_id), "version": profile.definition_version, "development_only": profile.development_only, "stages_per_biome": profile.stages_per_biome, "boss_stage": profile.boss_stage}, "versions": {"route": 1, "reward": 2, "shop": 1, "fixed_layout": 1, "damage_policy": "D028_v1", "boss_outcome_policy": "D029_v1", "run_policy": "DEMO_NO_TRANSFER_v1"}, "content_manifest": [], "config_hashes": {}, "initial_character": {}, "stages": [], "decisions": [], "end": {}}

func enable_plains_generation() -> void:
	_data.versions.erase("fixed_layout")
	_data.versions.generated_layout = "plains-run-v1"
	_data.versions.pickups = "plains-pickups-v1"
	_data.versions.run_policy = "PLAINS_BANK_NOTES_v1"

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
	var generated_versions := fixed_versions.duplicate(true)
	generated_versions.erase("fixed_layout")
	generated_versions.generated_layout = "plains-run-v1"
	generated_versions.pickups = "plains-pickups-v1"
	generated_versions.run_policy = "PLAINS_BANK_NOTES_v1"
	var versions_supported: bool = _versions_equal(data.get("versions", {}), fixed_versions) or _versions_equal(data.get("versions", {}), generated_versions)
	if _versions_equal(data.get("versions", {}), generated_versions):
		var generator := RandomStageGenerator.new()
		var tuning_keys: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/player_tuning.json"))
		for entry: Dictionary in data.stages:
			var outputs: Variant = entry.get("outputs")
			if not outputs is Dictionary or not outputs.get("stage_tuning") is Dictionary or not outputs.get("generated_layout") is Dictionary:
				return false
			if entry.get("biome_id", "") != "plains" or outputs.get("stage_generator", {}).get("version", "") != PlainsStageGenerator.VERSION or outputs.generated_layout.get("profile_id", "") != PlainsStageGenerator.new().profile_for(int(entry.stage_index), StringName(entry.type_id)):
				return false
			var tuning := PlayerTuning.load_default()
			for key: String in tuning_keys:
				if not outputs.stage_tuning.has(key):
					return false
				if key == "jump_speeds":
					if not outputs.stage_tuning[key] is Array:
						return false
					for speed: Variant in outputs.stage_tuning[key]:
						if not (speed is int or speed is float) or not is_finite(float(speed)):
							return false
					tuning.jump_speeds.assign(outputs.stage_tuning[key])
				else:
					var value: Variant = outputs.stage_tuning[key]
					if typeof(value) != typeof(tuning.get(key)) and not ((value is float or value is int) and (tuning.get(key) is float or tuning.get(key) is int)) or (value is float and not is_finite(value)):
						return false
					tuning.set(key, value)
			var checked := generator.validate_manifest(outputs.generated_layout, tuning)
			if not checked.ok:
				return false
	return versions_supported and data.get("schema_version", -1) == SCHEMA_VERSION and data.get("rng_algorithm", "") == RunRandomStream.ALGORITHM and data.get("stream_derivation_version", -1) == RunRandomStream.DERIVATION_VERSION

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
