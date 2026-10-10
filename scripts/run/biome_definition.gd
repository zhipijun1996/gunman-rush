class_name BiomeDefinition
extends Resource

@export var biome_id: StringName = &"demo_ruins"
@export var definition_version := 1
@export var display_name := "Trial Ruins"
@export var terrain_pool: Array[StringName] = [&"fixed_demo_layout"]
@export var enemy_pool: Array[StringName] = [&"patrol_drone"]
@export var boss_pool: Array[StringName] = [&"clockwork_guardian"]
@export var hazard_pool: Array[StringName] = [&"demo_saw"]

func is_valid() -> bool:
	return not biome_id.is_empty() and definition_version == 1 and not display_name.is_empty() and not terrain_pool.is_empty() and not boss_pool.is_empty()
