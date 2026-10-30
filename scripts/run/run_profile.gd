class_name RunProfile
extends Resource

@export var profile_id: StringName = &"formal_plains_region"
@export var definition_version := 2
@export var stages_per_biome := 2
@export var boss_stage := 2
@export var development_only := false

func is_valid(formal_build := false) -> bool:
	if profile_id.is_empty():
		return false
	if development_only:
		return not formal_build and profile_id == &"development_three" and definition_version == 1 and stages_per_biome == 3 and boss_stage == 3
	if profile_id == &"formal_plains_region":
		return definition_version == 2 and stages_per_biome == 2 and boss_stage == 2
	if profile_id == &"fixed_delivery_930001":
		return definition_version == 1 and stages_per_biome == 1 and boss_stage == 1
	return false

static func development() -> RunProfile:
	var profile := RunProfile.new()
	profile.profile_id = &"development_three"
	profile.definition_version = 1
	profile.stages_per_biome = 3
	profile.boss_stage = 3
	profile.development_only = true
	return profile

static func formal() -> RunProfile:
	var profile := RunProfile.new()
	profile.profile_id = &"formal_plains_region"
	profile.definition_version = 2
	profile.stages_per_biome = 2
	profile.boss_stage = 2
	return profile

static func fixed_delivery() -> RunProfile:
	var profile := RunProfile.new()
	profile.profile_id = &"fixed_delivery_930001"
	profile.definition_version = 1
	profile.stages_per_biome = 1
	profile.boss_stage = 1
	return profile
