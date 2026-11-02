class_name ActorResources
extends Node

# Local composition boundary. No autoload, player lookup, movement or damage policy.
@export var health_definition: HealthDefinition
var health := HealthState.new()
var stamina := StaminaState.new()

func configure(stamina_definition: StaminaDefinition) -> bool:
	if health_definition == null or not health_definition.is_valid() or stamina_definition == null or not stamina_definition.is_valid():
		return false
	return health.configure(health_definition) and stamina.configure(stamina_definition)

func reset_legacy_health() -> void:
	# Only the current explicit historical graybox restart uses this. Segment return
	# must preserve health and stamina and will have its own policy in SEGMENT-01.
	health.configure(health_definition)
