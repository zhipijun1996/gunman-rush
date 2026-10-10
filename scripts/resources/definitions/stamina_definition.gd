class_name StaminaDefinition
extends Resource

enum ClockDomain { GAME, REAL }
@export var resource_id: StringName
@export var definition_version := 1
@export var capacity := 0.0
@export var initial_current := 0.0
@export var clock_domain: ClockDomain = ClockDomain.GAME
@export var regeneration_policy_id: StringName
@export var consumption_policy_ids: Array[StringName] = []

func is_valid() -> bool:
	return not resource_id.is_empty() and definition_version > 0 and is_finite(capacity) and capacity > 0.0 and is_finite(initial_current) and initial_current >= 0.0 and initial_current <= capacity and clock_domain in [ClockDomain.GAME, ClockDomain.REAL]

static func from_focus_prototype(tuning: PlayerTuning) -> StaminaDefinition:
	var definition := StaminaDefinition.new()
	definition.resource_id = &"prototype_focus"
	definition.capacity = tuning.focus_stamina_capacity
	definition.initial_current = tuning.focus_stamina_capacity
	definition.clock_domain = ClockDomain.REAL
	definition.regeneration_policy_id = &"prototype_focus_ground_only"
	definition.consumption_policy_ids = [&"prototype_air_focus"]
	return definition
