class_name MachineBossDefinition
extends EnemyDefinition

@export var floor_offset := 0.0
@export var arena_half_width := 0.0
@export var reach := 0.0
@export var first_cycle: PackedStringArray
@export var second_cycle: PackedStringArray
@export var body_art: Texture2D

func is_valid() -> bool:
	return has_valid_identity() and EnemyBehaviorRegistry.validation_family(behavior_id) == &"machine" and stable_id == behavior_id and telegraph_duration >= 0.5 and attack_duration > 0 and recovery_duration >= 0.8 and floor_offset > 0 and arena_half_width > reach and reach > 0 and not first_cycle.is_empty() and not second_cycle.is_empty() and body_art != null
