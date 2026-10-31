class_name WorldDefinition
extends Resource

## Immutable configuration; per-instance state belongs to the world object.
@export var stable_id: StringName = &"world_object"
@export var definition_version := 1
@export var radius := 24.0
@export var grant_amount := 1
@export var travel := Vector2.ZERO
@export var period := 3.0
@export var initial_phase := 0.0
@export var safe_size := Vector2(96, 52)
