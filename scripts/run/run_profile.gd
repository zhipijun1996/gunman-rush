class_name RunProfile
extends Resource

@export var profile_id: StringName = &"formal_ten"
@export var definition_version := 1
@export var stages_per_biome := 10
@export var boss_stage := 10
@export var development_only := false

func is_valid(formal_build := false) -> bool:
	if definition_version != 1 or profile_id.is_empty():
		return false
	if development_only:
		return not formal_build and stages_per_biome == 3 and boss_stage == 3
	return stages_per_biome == 10 and boss_stage == 10

static func development() -> RunProfile:
	var profile := RunProfile.new()
	profile.profile_id = &"development_three"
	profile.stages_per_biome = 3
	profile.boss_stage = 3
	profile.development_only = true
	return profile

static func formal() -> RunProfile:
	return RunProfile.new()
