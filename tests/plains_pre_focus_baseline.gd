extends RefCounted
## Immutable pre-.15 test consumers. Never writes runtime configuration or
## substitutes a historical tuning object into an actual playable scene.
const PROFILE := "res://tests/fixtures/root_bell/pre_focus_15_player_tuning.json"

static func historical(seed: String, deep := false) -> Dictionary:
	if FileAccess.get_sha256(PROFILE) != PlainsRegionGenerator.PRE_FOCUS_15_TUNING_HASH:
		return {"ok":false,"error":"Immutable historical tuning bytes differ"}
	var values: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILE))
	var tuning := PlayerTuning.load_default()
	for key: String in values:
		if key == "physics_hz": continue
		if key == "jump_speeds": tuning.jump_speeds.assign(values[key])
		else: tuning.set(key,values[key])
	if tuning.focus_time_scale != 0.2 or not tuning.valid_focus_configuration():
		return {"ok":false,"error":"Historical profile does not match original focus"}
	var generator := PlainsRegionGenerator.new()
	generator.root_bell_mode = "v3"
	if deep: generator.regional_art_profile = "continuous_plains_v1"
	# The sole authorized historical fingerprint API; no arbitrary hash setter.
	return generator.generate_before_focus_15(seed,tuning,false,"","intro")

static func current_errors(current: Dictionary, prior: Dictionary, deep := false) -> Array[String]:
	var errors: Array[String] = []
	if not current.get("ok",false) or not prior.get("ok",false):
		return ["current or immutable historical generation refused"]
	var tuning := PlayerTuning.load_default()
	var tuning_hash := FileAccess.get_sha256("res://config/player_tuning.json")
	if tuning.focus_time_scale != 0.15 or tuning_hash == PlainsRegionGenerator.PRE_FOCUS_15_TUNING_HASH:
		errors.append("actual default must retain authorized .15 focus")
	if current.manifest.player_tuning_hash != tuning_hash or prior.manifest.player_tuning_hash != PlainsRegionGenerator.PRE_FOCUS_15_TUNING_HASH:
		errors.append("current/historical manifest provenance differs")
	var generator := PlainsRegionGenerator.new()
	if not generator.validate(current.manifest,tuning): errors.append("entire current Manifest replay rejected")
	if current.manifest.has("joint_recoil_profile") or current.manifest.has("art_language_profile"):
		errors.append("default/nonjoint baseline activated a candidate")
	if deep:
		if current.manifest.get("regional_art_profile","") != "continuous_plains_v1": errors.append("registered deep profile missing")
	elif current.manifest.has("regional_art_profile"):
		errors.append("ordinary default activated a regional candidate")
	# Compare the complete Manifest, including all geometry, streams, enemies,
	# ledgers and attempts. Only the authorized tuning provenance and its derived
	# manifest digest can change. Original frozen hash assertions remain callers.
	var expected: Dictionary = prior.manifest.duplicate(true)
	expected.player_tuning_hash = tuning_hash
	expected.manifest_hash = generator._hash(expected)
	if JSON.stringify(current.manifest) != JSON.stringify(expected):
		errors.append("complete current Manifest differs beyond authorized tuning provenance")
	return errors
