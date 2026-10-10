class_name RunProfile
extends Resource

@export var profile_id: StringName = &"formal_eight"
@export var definition_version := 2
@export var stages_per_biome := 8
@export var boss_stage := 8
@export var development_only := false

func is_valid(formal_build := false) -> bool:
	if profile_id.is_empty():
		return false
	if development_only:
		return not formal_build and profile_id == &"development_three" and definition_version == 1 and stages_per_biome == 3 and boss_stage == 3
	return profile_id == &"formal_eight" and definition_version == 2 and stages_per_biome == 8 and boss_stage == 8

static func development() -> RunProfile:
	var profile := RunProfile.new()
	profile.profile_id = &"development_three"
	profile.definition_version = 1
	profile.stages_per_biome = 3
	profile.boss_stage = 3
	profile.development_only = true
	return profile

static func formal8() -> RunProfile:
	return RunProfile.new()

# Kept for existing callers; this always returns the current eight-stage rules.
static func formal() -> RunProfile:
	return formal8()
